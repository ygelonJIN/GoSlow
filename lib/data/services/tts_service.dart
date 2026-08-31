import 'package:flutter_tts/flutter_tts.dart';

/// 单词朗读服务（本地 TTS）。
class TtsService {
  TtsService._();

  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _inited = false;

  Future<void> _ensureInit() async {
    if (_inited) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _inited = true;
  }

  Future<void> speak(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await _ensureInit();
    await _tts.stop();
    await _tts.speak(t);
  }

  Future<void> stop() => _tts.stop();
}
