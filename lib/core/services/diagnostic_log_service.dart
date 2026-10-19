import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// A small temporary file log for diagnosing background diary collection.
///
/// Callers should only write technical state. Exact coordinates, diary text,
/// media paths, passwords, tokens, and encryption keys must never be logged.
class DiagnosticLogService {
  DiagnosticLogService._();

  static const _fileName = 'chronologe_diagnostics.log';
  static const _maximumBytes = 1024 * 1024;
  static Future<void> _writeQueue = Future<void>.value();

  /// Adds one timestamped line without allowing logging errors to break the app.
  static Future<void> record(String area, String message, {Object? error}) {
    final safeArea = _oneLine(area);
    final safeMessage = _oneLine(message);
    final safeError = error == null
        ? ''
        : ' | error=${error.runtimeType}: ${_oneLine(error.toString())}';
    final line =
        '${DateTime.now().toUtc().toIso8601String()} '
        '[$safeArea] $safeMessage$safeError\n';

    _writeQueue = _writeQueue.then((_) => _append(line)).catchError((_) {});
    return _writeQueue;
  }

  /// Returns the current log file, creating it if this is the first request.
  static Future<File> get file async {
    final directory = await getApplicationSupportDirectory();
    final logFile = File(path.join(directory.path, _fileName));
    if (!await logFile.exists()) {
      await logFile.create(recursive: true);
    }
    return logFile;
  }

  /// Returns basic details that can be shown safely in Settings.
  static Future<DiagnosticLogInfo> getInfo() async {
    await _writeQueue;
    final logFile = await file;
    final bytes = await logFile.length();
    final modified = bytes == 0 ? null : await logFile.lastModified();
    return DiagnosticLogInfo(bytes: bytes, lastUpdated: modified);
  }

  /// Makes a shareable copy in the app's temporary folder.
  static Future<File> createShareCopy() async {
    await record('diagnostics', 'Diagnostic log exported by the user');
    await _writeQueue;
    final source = await file;
    final temporaryDirectory = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    return source.copy(
      path.join(
        temporaryDirectory.path,
        'chronologe-diagnostics-$timestamp.log',
      ),
    );
  }

  /// Deletes all old entries and starts a fresh diagnostic session.
  static Future<void> clear() async {
    await _writeQueue;
    final logFile = await file;
    await logFile.writeAsString('', flush: true);
    await record('diagnostics', 'Diagnostic log cleared; new session started');
  }

  static Future<void> _append(String line) async {
    final logFile = await file;
    if (await logFile.length() >= _maximumBytes) {
      await logFile.writeAsString(
        '${DateTime.now().toUtc().toIso8601String()} '
        '[diagnostics] Log reached 1 MB and was restarted\n',
        flush: true,
      );
    }
    await logFile.writeAsString(line, mode: FileMode.append, flush: true);
  }

  static String _oneLine(String value) {
    return value
        .replaceAll(RegExp(r'[\r\n]+'), ' ')
        .replaceAll(
          RegExp(r'([?&](latitude|longitude)=)[^&\s]+'),
          r'$1[redacted]',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class DiagnosticLogInfo {
  const DiagnosticLogInfo({required this.bytes, required this.lastUpdated});

  final int bytes;
  final DateTime? lastUpdated;
}
