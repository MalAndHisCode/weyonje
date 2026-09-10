import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SmsCandidate {
  const SmsCandidate(this.challengeId, this.code);
  final String challengeId;
  final String code;
}

/// Only candidate digits and a challenge reference cross the native boundary.
/// No SMS body, candidate or reference is written to persistent storage.
class SmsRetrieval extends ChangeNotifier {
  static const _channel = MethodChannel('weyonje/sms_retriever');
  SmsCandidate? candidate;
  final _candidates = <String, SmsCandidate>{};
  final _consumed = <String>{};
  bool _closed = false;
  int _generation = 0;
  int get generation => _generation;

  Future<void> stopIfCurrent(int generation) async {
    if (generation == _generation) await stop();
  }

  SmsRetrieval() {
    _channel.setMethodCallHandler((call) async {
      if (_closed || call.method != 'candidate') return;
      final data = call.arguments;
      if (data is! Map || data['generation'] != _generation) return;
      final id = data['challengeId'];
      final code = data['code'];
      if (id is String &&
          code is String &&
          !_consumed.contains(id) &&
          RegExp(r'^\d{6}$').hasMatch(code)) {
        candidate = SmsCandidate(id, code);
        _candidates[id] = candidate!;
        if (_candidates.length > 4) _candidates.remove(_candidates.keys.first);
        notifyListeners();
      }
    });
  }

  Future<void> start() async {
    candidate = null;
    _candidates.clear();
    _consumed.clear();
    final generation = ++_generation;
    try {
      await _channel
          .invokeMethod<void>('start', {'generation': generation})
          .timeout(const Duration(seconds: 3));
    } on Exception {
      // Unavailable services/platform or timeout never prevents manual entry.
    }
  }

  Future<void> stop() async {
    candidate = null;
    _candidates.clear();
    _consumed.clear();
    ++_generation;
    try {
      await _channel.invokeMethod<void>('stop');
    } on Exception {
      // Optional integration; manual entry is always available.
    }
  }

  SmsCandidate? takeCandidate(String challengeId) {
    final value =
        _candidates.remove(challengeId) ??
        (candidate?.challengeId == challengeId ? candidate : null);
    if (candidate?.challengeId == challengeId) candidate = null;
    // A duplicate delivery must not overwrite a later deliberate edit.
    if (value != null) _consumed.add(challengeId);
    return value;
  }

  @override
  void dispose() {
    _closed = true;
    unawaited(stop());
    _channel.setMethodCallHandler(null);
    super.dispose();
  }
}

final smsRetrievalProvider = Provider<SmsRetrieval>((ref) {
  final retrieval = SmsRetrieval();
  ref.onDispose(retrieval.dispose);
  return retrieval;
});
