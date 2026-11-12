import 'dart:io';

/// Deletes a local file when it exists and ignores stale or locked paths.
Future<void> deleteFileIfPresent(String filePath) async {
  if (filePath.trim().isEmpty) return;
  try {
    final file = File(filePath);
    if (await file.exists()) await file.delete();
  } on FileSystemException {
    // The operating system can clean up a stale file later.
  }
}

/// Deletes each unique local file in a collection.
Future<void> deleteFilesIfPresent(Iterable<String> filePaths) async {
  for (final filePath in filePaths.toSet()) {
    await deleteFileIfPresent(filePath);
  }
}
