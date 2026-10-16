import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backup/cloud_backup_service.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/services/media_encryption_provider.dart';
import '../../entries/viewmodels/diary_entry_view_model.dart';
import '../../entries/viewmodels/entries_view_model.dart';
import '../../today/viewmodels/today_view_model.dart';
import '../../tracking/viewmodels/background_tracking_controller.dart';
import 'settings_view_model.dart';

final cloudBackupServiceProvider = Provider<CloudBackupService>((ref) {
  return CloudBackupService(
    appDatabase: ref.watch(appDatabaseProvider),
    diaryDatabase: ref.watch(diaryDatabaseProvider),
    mediaEncryption: ref.watch(mediaEncryptionServiceProvider),
  );
});

final cloudBackupViewModelProvider =
    AsyncNotifierProvider<CloudBackupViewModel, CloudBackupState>(
      CloudBackupViewModel.new,
    );

enum CloudBackupStatus { ready, uploading, restoring, success, error }

class CloudBackupState {
  const CloudBackupState({
    this.status = CloudBackupStatus.ready,
    this.progress = 0,
    this.lastBackup,
    this.mediaCount = 0,
    this.message,
  });

  final CloudBackupStatus status;
  final double progress;
  final DateTime? lastBackup;
  final int mediaCount;
  final String? message;

  bool get isBusy =>
      status == CloudBackupStatus.uploading ||
      status == CloudBackupStatus.restoring;

  CloudBackupState copyWith({
    CloudBackupStatus? status,
    double? progress,
    DateTime? lastBackup,
    int? mediaCount,
    String? message,
    bool clearMessage = false,
  }) {
    return CloudBackupState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      lastBackup: lastBackup ?? this.lastBackup,
      mediaCount: mediaCount ?? this.mediaCount,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

/// Keeps the Settings backup card separate from upload and restore work.
class CloudBackupViewModel extends AsyncNotifier<CloudBackupState> {
  CloudBackupService get _service => ref.read(cloudBackupServiceProvider);

  @override
  Future<CloudBackupState> build() async {
    try {
      final backup = await _service.getLatestBackup();
      return CloudBackupState(
        lastBackup: backup?.createdAt,
        mediaCount: backup?.mediaCount ?? 0,
      );
    } catch (error) {
      return CloudBackupState(
        status: CloudBackupStatus.error,
        message: _friendlyError(error),
      );
    }
  }

  // Creates one latest cloud backup and discards the older cloud copy.
  Future<bool> backUp() async {
    final current = state.value ?? const CloudBackupState();
    state = AsyncData(
      current.copyWith(
        status: CloudBackupStatus.uploading,
        progress: 0,
        clearMessage: true,
      ),
    );
    await ref.read(backgroundLocationServiceProvider).stop();
    try {
      final backup = await _service.backUp(onProgress: _setProgress);
      state = AsyncData(
        CloudBackupState(
          status: CloudBackupStatus.success,
          progress: 1,
          lastBackup: backup.createdAt,
          mediaCount: backup.mediaCount,
          message: 'Cloud backup completed.',
        ),
      );
      return true;
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          status: CloudBackupStatus.error,
          progress: 0,
          message: _friendlyError(error),
        ),
      );
      return false;
    } finally {
      ref.invalidate(backgroundTrackingControllerProvider);
    }
  }

  // Restores the latest backup after the user confirms replacement.
  Future<bool> restore() async {
    final current = state.value ?? const CloudBackupState();
    state = AsyncData(
      current.copyWith(
        status: CloudBackupStatus.restoring,
        progress: 0,
        clearMessage: true,
      ),
    );
    await ref.read(backgroundLocationServiceProvider).stop();
    try {
      final backup = await _service.restore(onProgress: _setProgress);
      ref.invalidate(settingsViewModelProvider);
      ref.invalidate(todayViewModelProvider);
      ref.invalidate(entriesViewModelProvider);
      ref.invalidate(diaryEntryViewModelProvider);
      state = AsyncData(
        CloudBackupState(
          status: CloudBackupStatus.success,
          progress: 1,
          lastBackup: backup.createdAt,
          mediaCount: backup.mediaCount,
          message: 'Cloud backup restored.',
        ),
      );
      return true;
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          status: CloudBackupStatus.error,
          progress: 0,
          message: _friendlyError(error),
        ),
      );
      return false;
    } finally {
      ref.invalidate(backgroundTrackingControllerProvider);
    }
  }

  void _setProgress(double progress) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(progress: progress.clamp(0, 1).toDouble()),
    );
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    return text
        .replaceFirst('StateError: ', '')
        .replaceFirst('Invalid argument(s): ', '')
        .replaceFirst('Exception: ', '');
  }
}
