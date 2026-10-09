import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// The possible stages of the voice recorder popup.
enum VoiceMemoStage {
  ready,
  preparing,
  recording,
  paused,
  stopping,
  preview,
  error,
}

/// Starts, pauses, stops, previews, and saves one recording.
class VoiceMemoViewModel extends ChangeNotifier {
  VoiceMemoViewModel({required this.dateKey}) {
    _playerStateSubscription = _player.playerStateStream.listen((_) {
      if (!_closed) notifyListeners();
    });
  }

  final String dateKey;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final Stopwatch _stopwatch = Stopwatch();

  late final StreamSubscription<PlayerState> _playerStateSubscription;
  Timer? _timer;
  Future<void>? _startOperation;
  Future<void>? _stopOperation;
  String? _draftPath;
  bool _closed = false;
  bool _recordingActive = false;

  VoiceMemoStage stage = VoiceMemoStage.ready;
  Duration elapsed = Duration.zero;
  String? errorMessage;

  bool get isPlaying => _player.playing;
  String? get recordedPath =>
      stage == VoiceMemoStage.preview ? _draftPath : null;

  Future<void> start() {
    if (stage != VoiceMemoStage.ready) return Future<void>.value();
    stage = VoiceMemoStage.preparing;
    notifyListeners();
    final operation = _start();
    _startOperation = operation;
    return operation;
  }

  Future<void> _start() async {
    try {
      if (!await _recorder.hasPermission()) {
        throw StateError('Microphone permission was not granted.');
      }
      if (_closed) return;

      final documentsDirectory = await getApplicationDocumentsDirectory();
      final memoDirectory = Directory(
        path.join(documentsDirectory.path, 'diary_voice_memos', dateKey),
      );
      await memoDirectory.create(recursive: true);
      if (_closed) return;
      _draftPath = path.join(
        memoDirectory.path,
        '${DateTime.now().microsecondsSinceEpoch}.m4a',
      );

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: _draftPath!,
      );
      _recordingActive = true;
      if (_closed) {
        await _recorder.cancel();
        _recordingActive = false;
        return;
      }
      _stopwatch.start();
      _startTimer();
      stage = VoiceMemoStage.recording;
      notifyListeners();
    } catch (_) {
      if (_closed) return;
      stage = VoiceMemoStage.error;
      errorMessage = 'ChronoLoge could not start the microphone.';
      notifyListeners();
    }
  }

  Future<void> pauseOrResume() async {
    try {
      if (stage == VoiceMemoStage.recording) {
        await _recorder.pause();
        _stopwatch.stop();
        stage = VoiceMemoStage.paused;
      } else if (stage == VoiceMemoStage.paused) {
        await _recorder.resume();
        _stopwatch.start();
        stage = VoiceMemoStage.recording;
      }
      elapsed = _stopwatch.elapsed;
      if (!_closed) notifyListeners();
    } catch (_) {
      if (_closed) return;
      stage = VoiceMemoStage.error;
      errorMessage = 'The recording controls are unavailable.';
      notifyListeners();
    }
  }

  Future<void> stop() {
    final operation = _stop();
    _stopOperation = operation;
    return operation;
  }

  Future<void> _stop() async {
    if (stage != VoiceMemoStage.recording && stage != VoiceMemoStage.paused) {
      return;
    }

    stage = VoiceMemoStage.stopping;
    _stopwatch.stop();
    _timer?.cancel();
    elapsed = _stopwatch.elapsed;
    notifyListeners();
    try {
      final recordedPath = await _recorder.stop();
      _recordingActive = false;
      if (recordedPath == null) {
        stage = VoiceMemoStage.error;
        errorMessage = 'The recording could not be saved.';
      } else {
        _draftPath = recordedPath;
        await _player.setFilePath(recordedPath);
        stage = VoiceMemoStage.preview;
      }
    } catch (_) {
      if (_closed) return;
      stage = VoiceMemoStage.error;
      errorMessage = 'The recording could not be saved.';
    }
    if (!_closed) notifyListeners();
  }

  Future<void> replay() async {
    final recordedPath = _draftPath;
    if (stage != VoiceMemoStage.preview || recordedPath == null) return;

    if (_player.playing) {
      await _player.pause();
      return;
    }
    await _player.seek(Duration.zero);
    unawaited(_player.play());
  }

  Future<void> close({required bool keepRecording}) async {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    _stopwatch.stop();
    await _startOperation;
    await _stopOperation;

    if (_recordingActive) {
      await _recorder.cancel();
      _recordingActive = false;
    }
    await _player.stop();
    await _playerStateSubscription.cancel();
    await _player.dispose();
    await _recorder.dispose();

    if (!keepRecording) {
      final draftPath = _draftPath;
      if (draftPath != null) {
        final draft = File(draftPath);
        if (await draft.exists()) await draft.delete();
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_closed) return;
      elapsed = _stopwatch.elapsed;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    if (!_closed) unawaited(close(keepRecording: false));
    super.dispose();
  }
}
