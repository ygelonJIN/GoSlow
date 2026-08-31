#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""GoSlow 词库转换脚本：ECDICT CSV + lemma → assets/dict.db (SQLite)。

用法（Python 直接跑，不涉及 flutter 工具链，Cursor 内/Terminal 均可）：
    python3 tool/build_dict.py

输出：
    assets/dict.db  —— 内置离线词库（App 首次启动复制到应用目录）。

策略：
    1. 解析 ecdict.csv，筛选出至少带一个考纲 tag（zk/gk/cet4/cet6/ky/ielts/toefl/gre）
       的词条，外加少量常用词（柯林斯星级 / 牛津3000 / 高频），保证释义展示质量。
    2. 拆出 word_tags（一词可属多个考纲）。
    3. 用 lemma.en.txt 构建 inflected -> lemma 映射；对 lemma 不在 ECDICT 的
       词，用 exchange 字段反向推导补全。
    4. 可选增强字段（数据源存在才写入，缺失自动跳过，不影响主流程）：
       - example   例句        ← detail.json（ECDICT-master 可选附件，word -> detail）
       - tenses    时态 JSON   ← ecdict.csv 的 exchange 字段（解析版）
       - synonyms  近义词辨析  ← resemble.txt（ECDICT-master 可选附件）
       - etymology 词根词缀    ← wordroot.txt（ECDICT-master 可选附件，JSON）

    解析函数移植自旧项目 `cursor_wordsmemory-cursor/scripts/init_db.py`
    （parse_exchange / parse_resemble / load_wordroot / build_etymology）。

数据来源：
    /Users/jinfeiqing/Downloads/ECDICT-master/ecdict.csv
    /Users/jinfeiqing/Downloads/ECDICT-master/lemma.en.txt
"""

import csv
import json
import os
import re
import sqlite3
import sys

# ---------------------------------------------------------------------------
# 配置
# ---------------------------------------------------------------------------
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ECDICT_DIR = os.path.expanduser("~/Downloads/ECDICT-master")
ECDICT_CSV = os.path.join(ECDICT_DIR, "ecdict.csv")
LEMMA_TXT = os.path.join(ECDICT_DIR, "lemma.en.txt")
DETAILS_JSON = os.path.join(ECDICT_DIR, "detail.json")
RESEMBLE_TXT = os.path.join(ECDICT_DIR, "resemble.txt")
WORDROOT_JSON = os.path.join(ECDICT_DIR, "wordroot.txt")
OUT_DB = os.path.join(ROOT, "assets", "dict.db")

# 考纲标签（同时是 ECDICT tag 字段的合法取值，已验证）
TAGS = ["zk", "gk", "cet4", "cet6", "ky", "ielts", "toefl", "gre"]

# 无 tag 但以下条件满足其一即收录（便于释义展示 / 高亮常用词）
KEEP_COLLINS_GE = 3          # 柯林斯 3 星以上
KEEP_OXFORD = 1              # 牛津 3000
KEEP_FRQ_GE = 1000           # 当代词频 >= 1000（约前几千高频词）

# 短前缀黑名单（易被误匹配的短前缀，需特殊处理）
SHORT_PREFIX_BLACKLIST = {"i-", "a-", "e-", "o-", "u-"}


def main() -> int:
    if not os.path.exists(ECDICT_CSV):
        print(f"[error] 找不到 ECDICT 数据：{ECDICT_CSV}")
        return 1
    if not os.path.exists(LEMMA_TXT):
        print(f"[error] 找不到 lemma 数据：{LEMMA_TXT}")
        return 1

    os.makedirs(os.path.dirname(OUT_DB), exist_ok=True)

    # 1. 收集考纲词 + 常用词
    words = {}          # word -> dict(字段)
    word_tags = {}      # word -> set(tag)
    tag_hits = {t: 0 for t in TAGS}

    with open(ECDICT_CSV, encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            word = row["word"].strip()
            if not word:
                continue

            tags = {t for t in row["tag"].strip().split() if t in TAGS}
            keep = bool(tags)
            if not keep:
                try:
                    collins = int(row["collins"] or 0)
                    oxford = int(row["oxford"] or 0)
                    frq = int(row["frq"] or 0)
                except ValueError:
                    collins = oxford = frq = 0
                keep = (
                    collins >= KEEP_COLLINS_GE
                    or oxford >= KEEP_OXFORD
                    or frq >= KEEP_FRQ_GE
                )
            if not keep:
                continue

            words[word] = {
                "word": word,
                "phonetic": row["phonetic"].strip(),
                "translation": row["translation"].strip(),
                "definition": row["definition"].strip(),
                "pos": row["pos"].strip(),
                "collins": _safe_int(row["collins"]),
                "oxford": _safe_int(row["oxford"]),
                "bnc": _safe_int(row["bnc"]),
                "frq": _safe_int(row["frq"]),
                "exchange": row["exchange"].strip(),
                "example": "",
                "tenses": json.dumps(_parse_exchange(row["exchange"].strip()),
                                     ensure_ascii=False),
                "synonyms": "",
                "etymology": "",
            }
            if tags:
                word_tags[word] = tags
                for t in tags:
                    tag_hits[t] += 1

    print(f"[1/5] 词条筛选完成：收录 {len(words)} 条（考纲词 {len(word_tags)} 条）")
    for t in TAGS:
        print(f"      {t:>6}: {tag_hits[t]}")

    # 2. 可选增强字段（数据源缺失时跳过，不影响主流程）
    _attach_details(words)
    _attach_resemble(words)
    _attach_wordroot(words)

    # 3. 构建 lemma 映射
    lemma_map = _build_lemma_map(words, word_tags)

    # 4. 写 SQLite
    _write_db(words, word_tags, lemma_map)

    size_mb = os.path.getsize(OUT_DB) / (1024 * 1024)
    print(f"[5/5] 完成：{OUT_DB}（{size_mb:.1f} MB）")
    return 0


# ---------------------------------------------------------------------------
# 增强字段：例句（detail.json）
# ---------------------------------------------------------------------------

def _safe_int(v) -> int:
    try:
        return int(v or 0)
    except ValueError:
        return 0


def _attach_details(words: dict) -> None:
    """从 detail.json（word -> 长文本）提取例句写入 words['example']。"""
    if not os.path.exists(DETAILS_JSON):
        print("      [skip] detail.json 不存在，例句列为空")
        return
    with open(DETAILS_JSON, encoding="utf-8") as f:
        details = json.load(f)
    hit = 0
    for word, rec in words.items():
        detail = details.get(word, "").strip()
        if not detail:
            continue
        example = _extract_example(detail)
        if example:
            rec["example"] = example
            hit += 1
    print(f"      [ok] detail.json 例句命中 {hit}/{len(words)} 条")


def _extract_example(detail: str) -> str:
    """从 ECDICT detail 长文本里提取一条例句。

    detail 形如：
        * 音标\n* 词义\n* 例证\n例：The apple fell from the tree. It rolled away.
    策略：优先取第一个「例：」后的第一句（按中英文句号/问叹号截断）；
    没有「例：」时，取最后一个以大写字母开头的完整句子行
    （避免误取音标/词性行）。
    """
    if not detail:
        return ""
    # 优先：第一个「例：」后的第一句话（到句号/问号/叹号为止）。
    m = re.search(r"例[：:]\s*(.*?[。！？.!?])(?=\s|$)", detail)
    if not m:
        m = re.search(r"例[：:]\s*(.+)", detail)
    if m:
        example = m.group(1).strip().strip('"\'')
        if len(example) >= 4:
            return example
    # 回退：以大写字母开头的长句行
    for line in detail.splitlines():
        line = line.strip().lstrip("*#- \t")
        if not line:
            continue
        if re.match(r"^[A-Z]", line) and len(line) >= 12 and line.count(" ") >= 3:
            return line[:200]
    return ""


# ---------------------------------------------------------------------------
# 增强字段：时态（exchange，移植自旧项目 parse_exchange）
# ---------------------------------------------------------------------------

def _parse_exchange(s: str) -> dict:
    """解析 ECDICT exchange 字段（'s:runs/d:ran/i:running/p:run'）→ 时态字典。"""
    result = {
        "past_tense": None, "past_participle": None, "present_participle": None,
        "third_person": None, "comparative": None, "superlative": None,
        "plural": None, "lemma": None, "lemma_variant": None,
    }
    if not s:
        return result
    type_map = {
        "p": "past_tense", "d": "past_participle", "i": "present_participle",
        "3": "third_person", "r": "comparative", "t": "superlative",
        "s": "plural", "0": "lemma", "1": "lemma_variant",
    }
    for item in s.split("/"):
        item = item.strip()
        if len(item) < 2:
            continue
        key, val = item[0], item[2:].strip()
        if key in type_map:
            result[type_map[key]] = val
    return result


# ---------------------------------------------------------------------------
# 增强字段：近义词辨析（resemble.txt，移植自旧项目 parse_resemble）
# ---------------------------------------------------------------------------

def _attach_resemble(words: dict) -> None:
    """解析 resemble.txt，为命中词写入近义词辨析 JSON。"""
    if not os.path.exists(RESEMBLE_TXT):
        print("      [skip] resemble.txt 不存在，近义词列为空")
        return

    word_to_json = {}
    groups = []
    cur_wl, cur_title, cur_detail = None, "", {}
    with open(RESEMBLE_TXT, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n").rstrip("\r")
            if line.startswith("% "):
                if cur_wl is not None:
                    groups.append((cur_wl, cur_title, cur_detail))
                cur_wl = line[2:].strip()
                cur_title, cur_detail = "", {}
            elif line.startswith("- "):
                rest = line[2:]
                if ":" in rest:
                    w, d = rest.split(":", 1)
                    cur_detail[w.strip().lower()] = d.strip()
            elif not line.startswith(("%", "-")):
                s = line.strip()
                if s and cur_wl is not None:
                    cur_title = (cur_title + "\n" + s).strip()
    if cur_wl is not None:
        groups.append((cur_wl, cur_title, cur_detail))

    for wl, title, det in groups:
        payload = json.dumps({"title": title, "words": det}, ensure_ascii=False)
        for w in det:
            word_to_json[w.strip().lower()] = payload

    hit = 0
    for word, rec in words.items():
        if word in word_to_json:
            rec["synonyms"] = word_to_json[word]
            hit += 1
    print(f"      [ok] resemble.txt 近义词命中 {hit}/{len(words)} 条（共 {len(groups)} 组）")


# ---------------------------------------------------------------------------
# 增强字段：词根词缀（wordroot.txt，移植自旧项目 load_wordroot + build_etymology）
# ---------------------------------------------------------------------------

def _attach_wordroot(words: dict) -> None:
    """解析 wordroot.txt（JSON），为命中词构建词根词缀 JSON。"""
    if not os.path.exists(WORDROOT_JSON):
        print("      [skip] wordroot.txt 不存在，词根词缀列为空")
        return

    with open(WORDROOT_JSON, encoding="utf-8") as f:
        root_data = json.load(f)

    roots, prefixes, suffixes = {}, {}, {}
    for root_id, data in root_data.items():
        if re.search(r"-\d+$", root_id):
            continue  # 过滤变体词根条目（"a-1"、"an-2"）
        meaning = data.get("meaning", "")
        if root_id.startswith("-"):
            suffixes[root_id] = meaning
        elif root_id.endswith("-"):
            prefixes[root_id] = meaning
        else:
            roots[root_id] = meaning

    hit = 0
    for word, rec in words.items():
        etymology = _build_etymology(word, roots, prefixes, suffixes)
        if etymology:
            rec["etymology"] = json.dumps(etymology, ensure_ascii=False)
            hit += 1
    print(f"      [ok] wordroot.txt 词根词缀命中 {hit}/{len(words)} 条（词根 {len(roots)} / 前缀 {len(prefixes)} / 后缀 {len(suffixes)}）")


def _build_etymology(word: str, roots: dict, prefixes: dict, suffixes: dict) -> dict:
    """按「前缀 → 后缀 → 中间区间找词根」的严格匹配策略构建词根词缀。"""
    result = {}
    word_lower = word.lower()

    matched_prefix = None
    for pf in sorted(prefixes.keys(), key=len, reverse=True):
        pf_clean = pf.rstrip("-")
        if word_lower.startswith(pf_clean):
            if pf in SHORT_PREFIX_BLACKLIST:
                rest = word_lower[len(pf_clean):]
                if rest and rest[0].isalpha():
                    continue  # in- 不会被 i- 误匹配
            matched_prefix = pf
            break
    if matched_prefix:
        result["prefix"] = matched_prefix
        result["prefixMeaning"] = prefixes[matched_prefix]

    matched_suffix = None
    for sf in sorted(suffixes.keys(), key=len, reverse=True):
        sf_clean = sf.lstrip("-")
        if word_lower.endswith(sf_clean):
            matched_suffix = sf
            break
    if matched_suffix:
        result["suffix"] = matched_suffix
        result["suffixMeaning"] = suffixes[matched_suffix]

    start = len(matched_prefix.rstrip("-")) if matched_prefix else 0
    end = len(word_lower) - (len(matched_suffix.lstrip("-")) if matched_suffix else 0)
    remaining = word_lower[start:end]

    matched_root = None
    for rt in sorted(roots.keys(), key=len, reverse=True):
        if rt in remaining:
            matched_root = rt
            break
    if not matched_root:  # 回退：整词搜索（降低精度）
        for rt in sorted(roots.keys(), key=len, reverse=True):
            if rt in word_lower:
                matched_root = rt
                break
    if matched_root:
        result["root"] = matched_root
        result["rootMeaning"] = roots[matched_root]

    return result


# ---------------------------------------------------------------------------
# Lemma 映射
# ---------------------------------------------------------------------------

def _build_lemma_map(words: dict, word_tags: dict) -> dict:
    """返回 {inflected: lemma}，来源 lemma.en.txt（首选）+ exchange 反向（补全）。"""
    lemma_map: dict = {}

    with open(LEMMA_TXT, encoding="utf-8", newline="") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith(";"):
                continue
            # 格式：get/212569 -> got,getting,gets,gotten
            head, _, tail = line.partition("->")
            lemma = head.split("/", 1)[0].strip().lower()
            if not lemma or lemma not in words:
                continue  # 只保留 lemma 在词库内的映射（考纲词 + 常用词）
            for inf in tail.split(","):
                inf = inf.strip().strip("'").lower()
                if inf and inf != lemma:
                    lemma_map.setdefault(inf, lemma)

    # exchange 反向补全：ran -> run（run 在词库但 lemma.en.txt 未覆盖）
    for word, rec in words.items():
        for form in _exchange_forms(rec.get("exchange", "")):
            if form and form != word and form not in lemma_map:
                lemma_map.setdefault(form, word)

    print(f"[3/5] 词形还原映射：{len(lemma_map)} 条")
    return lemma_map


def _exchange_forms(exchange: str):
    """从 ECDICT exchange 字段提取变形词。格式如 's:runs/d:ran/i:running/p:run'。"""
    if not exchange:
        return
    for part in exchange.split("/"):
        _, _, forms = part.partition(":")
        for form in forms.split(","):
            form = form.strip().lower()
            if form:
                yield form


# ---------------------------------------------------------------------------
# SQLite 写入
# ---------------------------------------------------------------------------

def _write_db(words: dict, word_tags: dict, lemma_map: dict) -> None:
    if os.path.exists(OUT_DB):
        os.remove(OUT_DB)
    con = sqlite3.connect(OUT_DB)
    cur = con.cursor()

    cur.executescript(
        """
        CREATE TABLE words (
          id          INTEGER PRIMARY KEY,
          word        TEXT NOT NULL UNIQUE,
          phonetic    TEXT,
          translation TEXT,
          definition  TEXT,
          pos         TEXT,
          collins     INTEGER,
          oxford      INTEGER,
          bnc         INTEGER,
          frq         INTEGER,
          exchange    TEXT,
          example     TEXT,
          tenses      TEXT,
          synonyms    TEXT,
          etymology   TEXT
        );
        CREATE TABLE word_tags (
          word_id INTEGER REFERENCES words(id),
          tag     TEXT,
          PRIMARY KEY (word_id, tag)
        );
        CREATE TABLE lemma_map (
          inflected TEXT PRIMARY KEY,
          lemma     TEXT NOT NULL
        );
        CREATE INDEX idx_words_word ON words(word);
        CREATE INDEX idx_words_frq ON words(frq);
        CREATE INDEX idx_lemma_map_inflected ON lemma_map(inflected);
        """
    )

    # 批量插入 words（含四个增强列，缺失时为空串）
    rows = [(w["word"], w["phonetic"], w["translation"], w["definition"],
             w["pos"], w["collins"], w["oxford"], w["bnc"], w["frq"], w["exchange"],
             w.get("example", ""), w.get("tenses", ""),
             w.get("synonyms", ""), w.get("etymology", ""))
            for w in words.values()]
    cur.executemany(
        "INSERT INTO words (word, phonetic, translation, definition, pos,"
        " collins, oxford, bnc, frq, exchange, example, tenses, synonyms, etymology)"
        " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        rows,
    )

    # word_id 反查（word 唯一）
    word_id = {row[0]: row[1] for row in cur.execute("SELECT word, id FROM words")}

    tag_rows = [(word_id[w], t) for w, ts in word_tags.items() for t in ts]
    cur.executemany("INSERT INTO word_tags (word_id, tag) VALUES (?,?)", tag_rows)

    lemma_rows = [(inf, lemma) for inf, lemma in lemma_map.items()]
    cur.executemany("INSERT INTO lemma_map (inflected, lemma) VALUES (?,?)", lemma_rows)

    con.commit()
    con.close()
    print(f"[4/5] 写入完成：words={len(rows)} word_tags={len(tag_rows)} lemma_map={len(lemma_rows)}")


if __name__ == "__main__":
    sys.exit(main())
