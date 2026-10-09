import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/backup/cloud_backup_providers.dart';
import 'core/backup/cloud_backup_service.dart';

class CloudBackupDemoPage extends ConsumerStatefulWidget {
  const CloudBackupDemoPage({required this.firebaseUid, super.key});

  final String firebaseUid;

  @override
  ConsumerState<CloudBackupDemoPage> createState() =>
      _CloudBackupDemoPageState();
}

class _CloudBackupDemoPageState extends ConsumerState<CloudBackupDemoPage> {
  DateTime? _lastBackedUpAt;
  bool _hasStartedLoadingTimestamp = false;
  bool _isLoadingTimestamp = true;
  bool _isBackingUp = false;
  double _uploadProgress = 0;
  String? _errorMessage;

  Future<void> _loadLastBackupTime(CloudBackupService service) async {
    try {
      final lastBackedUpAt = await service.getLastBackupAt();
      if (!mounted) return;
      setState(() {
        _lastBackedUpAt = lastBackedUpAt;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isLoadingTimestamp = false);
    }
  }

  Future<void> _backUpNow(CloudBackupService service) async {
    setState(() {
      _isBackingUp = true;
      _uploadProgress = 0;
      _errorMessage = null;
    });

    try {
      final backedUpAt = await service.uploadCurrentDatabase(
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _uploadProgress = progress.clamp(0, 1));
        },
      );
      if (!mounted) return;
      setState(() {
        _lastBackedUpAt = backedUpAt;
        _uploadProgress = 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Database uploaded successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    return timestamp.toLocal().toString().split('.').first;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backupService = ref.watch(
      cloudBackupServiceProvider(widget.firebaseUid),
    );

    if (!_hasStartedLoadingTimestamp) {
      _hasStartedLoadingTimestamp = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadLastBackupTime(backupService);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Cloud backup demo')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Current backup',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            _isLoadingTimestamp
                ? 'Checking backup time...'
                : _lastBackedUpAt == null
                ? 'Last backed up: Never'
                : 'Last backed up: ${_formatTimestamp(_lastBackedUpAt!)}',
          ),
          const SizedBox(height: 8),
          const Text('Cloud path: users/<your uid>/backups/latest.db'),
          const SizedBox(height: 24),
          LinearProgressIndicator(value: _uploadProgress),
          const SizedBox(height: 8),
          Text(
            'Upload progress: ${(_uploadProgress * 100).round()}%',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isBackingUp ? null : () => _backUpNow(backupService),
            icon: _isBackingUp
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(_isBackingUp ? 'Uploading...' : 'Back up now'),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(_errorMessage!, style: TextStyle(color: colorScheme.error)),
          ],
        ],
      ),
    );
  }
}
