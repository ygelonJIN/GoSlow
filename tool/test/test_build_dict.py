#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""build_dict.py 解析函数单测（纯 Python，直接跑：python3 tool/test/test_build_dict.py）。"""

import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import build_dict as bd  # noqa: E402


class ParseExchangeTest(unittest.TestCase):
    def test_full_exchange(self):
        result = bd._parse_exchange("3:takes/d:taken/i:taking/p:took")
        self.assertEqual(result["third_person"], "takes")
        self.assertEqual(result["past_tense"], "took")
        self.assertEqual(result["present_participle"], "taking")
        self.assertEqual(result["past_participle"], "taken")
        self.assertIsNone(result["comparative"])

    def test_plural_and_comparative(self):
        result = bd._parse_exchange("s:children/r:happier/t:happiest")
        self.assertEqual(result["plural"], "children")
        self.assertEqual(result["comparative"], "happier")
        self.assertEqual(result["superlative"], "happiest")

    def test_empty(self):
        result = bd._parse_exchange("")
        self.assertIsNone(result["past_tense"])
        self.assertIsNone(result["lemma"])


class ExtractExampleTest(unittest.TestCase):
    def test_li_colon_priority(self):
        detail = "* 音标\n* n. 苹果\n* 例证\n例：The apple fell from the tree. It rolled away."
        self.assertEqual(bd._extract_example(detail), "The apple fell from the tree.")

    def test_zh_colon_variant(self):
        detail = "* v. 放弃\n例：Never abandon your dreams."
        self.assertEqual(bd._extract_example(detail), "Never abandon your dreams.")

    def test_fallback_capital_sentence_line(self):
        detail = "* /əˈbændən/\n* v. 放弃\nAbandon all hope, ye who enter here."
        self.assertEqual(bd._extract_example(detail), "Abandon all hope, ye who enter here.")

    def test_empty(self):
        self.assertEqual(bd._extract_example(""), "")


class BuildEtymologyTest(unittest.TestCase):
    ROOTS = {"sure": "使确信", "view": "看"}
    PREFIXES = {"re-": "again, back", "in-": "not, into"}
    SUFFIXES = {"-tion": "名词后缀", "-less": "无…的"}

    def test_prefix_root(self):
        result = bd._build_etymology("reassure", self.ROOTS, self.PREFIXES, self.SUFFIXES)
        self.assertEqual(result.get("prefix"), "re-")
        self.assertEqual(result.get("prefixMeaning"), "again, back")
        self.assertEqual(result.get("root"), "sure")

    def test_suffix(self):
        result = bd._build_etymology("endless", self.ROOTS, self.PREFIXES, self.SUFFIXES)
        self.assertEqual(result.get("suffix"), "-less")
        self.assertEqual(result.get("root"), "end" if "end" in self.ROOTS else None)

    def test_short_prefix_blacklist(self):
        # in- 不会被 i- 误匹配
        prefixes = {"i-": "short", "in-": "not"}
        result = bd._build_etymology("insight", self.ROOTS, prefixes, self.SUFFIXES)
        self.assertEqual(result.get("prefix"), "in-")

    def test_no_match(self):
        result = bd._build_etymology("zzzqqq", {}, {}, {})
        self.assertEqual(result, {})


class AttachResembleTest(unittest.TestCase):
    def test_group_parsing(self):
        with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False, encoding="utf-8") as f:
            f.write("% 放弃/abandon\n"
                    "abandon, desert, quit\n"
                    "- abandon: 放弃；抛弃\n"
                    "- desert: 抛弃；遗弃\n")
            path = f.name
        old_path = bd.RESEMBLE_TXT
        bd.RESEMBLE_TXT = path  # 钉到临时文件，避免读到真实 ECDICT 数据
        try:
            words = {
                "abandon": {"example": "", "synonyms": "", "tenses": "", "etymology": ""},
                "desert": {"example": "", "synonyms": "", "tenses": "", "etymology": ""},
                "other": {"example": "", "synonyms": "", "tenses": "", "etymology": ""},
            }
            bd._attach_resemble(words)
            import json
            payload = json.loads(words["abandon"]["synonyms"])
            self.assertEqual(payload["title"], "abandon, desert, quit")
            self.assertIn("desert", payload["words"])
            self.assertEqual(payload["words"]["desert"], "抛弃；遗弃")
            self.assertEqual(words["other"]["synonyms"], "")
        finally:
            bd.RESEMBLE_TXT = old_path
            os.unlink(path)


if __name__ == "__main__":
    unittest.main()
