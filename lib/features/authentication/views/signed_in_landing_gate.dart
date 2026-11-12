import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backup/cloud_backup_service.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../navigation/views/app_shell.dart';
import '../../settings/viewmodels/cloud_backup_view_model.dart';
import '../../tracking/viewmodels/background_tracking_controller.dart';
import '../viewmodels/authentication_view_model.dart';

/// Offers cloud restore when a signed-in user has no diary on this phone.
class SignedInLandingGate extends ConsumerStatefulWidget {
  const SignedInLandingGate({
    required this.userId,
    this.displayName,
    super.key,
  });

  final String userId;
  final String? displayName;

  @override
  ConsumerState<SignedInLandingGate> createState() =>
      _SignedInLandingGateState();
}

class _SignedInLandingGateState extends ConsumerState<SignedInLandingGate> {
  late Future<_LandingCheck> _check = _checkForBackup();
  bool _openApp = false;
  bool _isRestoring = false;
  String? _restoreError;

  String get _handledSetting => 'restore_landing_handled_${widget.userId}';

  @override
  void didUpdateWidget(covariant SignedInLandingGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId == widget.userId) return;
    _openApp = false;
    _isRestoring = false;
    _restoreError = null;
    _check = _checkForBackup();
  }

  @override
  Widget build(BuildContext context) {
    if (_openApp) return const _SignedInApp();

    return FutureBuilder<_LandingCheck>(
      future: _check,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LandingLoadingPage();
        }
        if (snapshot.hasError) {
          return _LandingErrorPage(
            onRetry: _retry,
            onContinue: _startWithoutBackup,
            onSignOut: _signOut,
          );
        }

        final check = snapshot.requireData;
        if (check.openApp) return const _SignedInApp();
        return _RestoreLandingPage(
          backup: check.backup,
          displayName: widget.displayName,
          isRestoring: _isRestoring,
          progress: _restoreProgress,
          errorMessage: _restoreError,
          onRestore: check.backup == null ? null : _restore,
          onStartFresh: () =>
              _confirmStartFresh(hasCloudBackup: check.backup != null),
          onSignOut: _signOut,
        );
      },
    );
  }

  double get _restoreProgress {
    if (!_isRestoring) return 0;
    return ref.watch(cloudBackupViewModelProvider).value?.progress ?? 0;
  }

  Future<_LandingCheck> _checkForBackup() async {
    final settings = ref.read(settingsDatabaseProvider);
    if (await settings.getSetting(_handledSetting) == 'true') {
      return const _LandingCheck(openApp: true);
    }
    if (await ref.read(diaryDatabaseProvider).hasAnyEntries()) {
      return const _LandingCheck(openApp: true);
    }
    final backup = await ref.read(cloudBackupServiceProvider).getLatestBackup();
    return _LandingCheck(openApp: false, backup: backup);
  }

  void _retry() {
    setState(() {
      _restoreError = null;
      _check = _checkForBackup();
    });
  }

  Future<void> _restore() async {
    if (_isRestoring) return;
    setState(() {
      _isRestoring = true;
      _restoreError = null;
    });

    final restored = await ref
        .read(cloudBackupViewModelProvider.notifier)
        .restore();
    if (!mounted) return;
    if (!restored) {
      setState(() {
        _isRestoring = false;
        _restoreError = ref.read(cloudBackupViewModelProvider).value?.message;
      });
      return;
    }

    await _markHandled();
    if (mounted) setState(() => _openApp = true);
  }

  Future<void> _confirmStartFresh({required bool hasCloudBackup}) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Start a new diary?',
      message: hasCloudBackup
          ? 'Your cloud backup will stay available. You can restore it later from Settings.'
          : 'ChronoLoge will create a new local diary on this phone.',
      confirmLabel: 'Start fresh',
      icon: Icons.auto_stories_outlined,
    );
    if (confirmed && mounted) await _startWithoutBackup();
  }

  Future<void> _startWithoutBackup() async {
    try {
      await _markHandled();
    } catch (_) {
      // Local diary activity also prevents this offer from appearing again.
    }
    if (mounted) setState(() => _openApp = true);
  }

  Future<void> _markHandled() {
    return ref
        .read(settingsDatabaseProvider)
        .setSetting(_handledSetting, 'true');
  }

  Future<void> _signOut() async {
    await ref.read(authenticationViewModelProvider.notifier).signOut();
  }
}

class _LandingCheck {
  const _LandingCheck({required this.openApp, this.backup});

  final bool openApp;
  final CloudBackupInfo? backup;
}

class _SignedInApp extends ConsumerWidget {
  const _SignedInApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(backgroundTrackingControllerProvider);
    return const AppShell();
  }
}

class _LandingLoadingPage extends StatelessWidget {
  const _LandingLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Checking for your diary...'),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestoreLandingPage extends StatelessWidget {
  const _RestoreLandingPage({
    required this.backup,
    required this.displayName,
    required this.isRestoring,
    required this.progress,
    required this.errorMessage,
    required this.onRestore,
    required this.onStartFresh,
    required this.onSignOut,
  });

  final CloudBackupInfo? backup;
  final String? displayName;
  final bool isRestoring;
  final double progress;
  final String? errorMessage;
  final VoidCallback? onRestore;
  final VoidCallback onStartFresh;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final cleanName = displayName?.trim() ?? '';
    final hasBackup = backup != null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasBackup
                          ? Icons.cloud_download_outlined
                          : Icons.auto_stories_outlined,
                      size: 42,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    cleanName.isEmpty ? 'Welcome' : 'Welcome, $cleanName',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    hasBackup
                        ? 'We found a cloud backup for this account.'
                        : 'There is no diary on this phone yet.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (backup != null) ...[
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _BackupDetail(
                              icon: Icons.schedule_outlined,
                              label: _formatBackupTime(
                                context,
                                backup!.createdAt,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _BackupDetail(
                              icon: Icons.photo_library_outlined,
                              label: backup!.mediaCount == 1
                                  ? '1 media file'
                                  : '${backup!.mediaCount} media files',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (isRestoring) ...[
                    const SizedBox(height: 22),
                    LinearProgressIndicator(
                      value: progress > 0 ? progress : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      progress > 0
                          ? 'Downloading your diary... ${(progress * 100).round()}%'
                          : 'Preparing your download...',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (errorMessage != null) ...[
                    const SizedBox(height: 18),
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (hasBackup)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: isRestoring ? null : onRestore,
                        icon: const Icon(Icons.cloud_download_outlined),
                        label: Text(
                          isRestoring ? 'Restoring...' : 'Restore backup',
                        ),
                      ),
                    ),
                  if (hasBackup) const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: hasBackup
                        ? OutlinedButton(
                            onPressed: isRestoring ? null : onStartFresh,
                            child: const Text('Start fresh'),
                          )
                        : FilledButton(
                            onPressed: isRestoring ? null : onStartFresh,
                            child: const Text('Start a new diary'),
                          ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: isRestoring ? null : onSignOut,
                    child: const Text('Use another account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatBackupTime(BuildContext context, DateTime dateTime) {
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatMediumDate(dateTime);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(dateTime),
    );
    return '$date at $time';
  }
}

class _BackupDetail extends StatelessWidget {
  const _BackupDetail({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
      ],
    );
  }
}

class _LandingErrorPage extends StatelessWidget {
  const _LandingErrorPage({
    required this.onRetry,
    required this.onContinue,
    required this.onSignOut,
  });

  final VoidCallback onRetry;
  final VoidCallback onContinue;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 52),
                  const SizedBox(height: 16),
                  Text(
                    'Could not check for a cloud backup.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check your internet connection, or continue and restore later from Settings.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                  TextButton(
                    onPressed: onContinue,
                    child: const Text('Continue without restoring'),
                  ),
                  TextButton(
                    onPressed: onSignOut,
                    child: const Text('Use another account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
