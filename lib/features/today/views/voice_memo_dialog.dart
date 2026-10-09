import 'dart:async';

import 'package:flutter/material.dart';

import '../viewmodels/voice_memo_view_model.dart';

/// Opens the recorder and returns the saved audio path, or null on cancel.
Future<String?> showVoiceMemoDialog(
  BuildContext context, {
  required String dateKey,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _VoiceMemoDialog(dateKey: dateKey),
  );
}

// Owns the recorder view model for as long as the popup is open.
class _VoiceMemoDialog extends StatefulWidget {
  const _VoiceMemoDialog({required this.dateKey});

  final String dateKey;

  @override
  State<_VoiceMemoDialog> createState() => _VoiceMemoDialogState();
}

class _VoiceMemoDialogState extends State<_VoiceMemoDialog> {
  late final VoiceMemoViewModel _viewModel;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _viewModel = VoiceMemoViewModel(dateKey: widget.dateKey)
      ..addListener(_onChanged);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_discard());
      },
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: SizedBox(
          width: 340,
          height: 360,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
                child: Column(
                  children: [
                    Text(
                      'Voice memo',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          layoutBuilder: (currentChild, previousChildren) =>
                              Stack(
                                alignment: Alignment.center,
                                children: [...previousChildren, ?currentChild],
                              ),
                          child: _buildStage(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  tooltip: 'Discard voice memo',
                  onPressed: _isClosing ? null : _discard,
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStage() {
    return switch (_viewModel.stage) {
      VoiceMemoStage.ready => _ReadyView(
        key: const ValueKey(VoiceMemoStage.ready),
        onStart: _viewModel.start,
      ),
      VoiceMemoStage.preparing => const _PreparingView(
        key: ValueKey(VoiceMemoStage.preparing),
        message: 'Preparing microphone...',
      ),
      VoiceMemoStage.stopping => const _PreparingView(
        key: ValueKey(VoiceMemoStage.stopping),
        message: 'Preparing your preview...',
      ),
      VoiceMemoStage.recording || VoiceMemoStage.paused => _RecordingView(
        key: const ValueKey('recording'),
        elapsed: _viewModel.elapsed,
        isPaused: _viewModel.stage == VoiceMemoStage.paused,
        onPauseOrResume: _viewModel.pauseOrResume,
        onStop: _viewModel.stop,
      ),
      VoiceMemoStage.preview => _PreviewView(
        key: const ValueKey(VoiceMemoStage.preview),
        elapsed: _viewModel.elapsed,
        isPlaying: _viewModel.isPlaying,
        onReplay: _viewModel.replay,
        onAdd: _add,
      ),
      VoiceMemoStage.error => _ErrorView(
        key: const ValueKey(VoiceMemoStage.error),
        message: _viewModel.errorMessage ?? 'The microphone is unavailable.',
        onClose: _discard,
      ),
    };
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _discard() async {
    if (_isClosing) return;
    setState(() => _isClosing = true);
    await _viewModel.close(keepRecording: false);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _add() async {
    if (_isClosing) return;
    final recordedPath = _viewModel.recordedPath;
    if (recordedPath == null) return;

    setState(() => _isClosing = true);
    await _viewModel.close(keepRecording: true);
    if (mounted) Navigator.pop(context, recordedPath);
  }
}

class _PreparingView extends StatelessWidget {
  const _PreparingView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(message),
      ],
    );
  }
}

// First recorder screen: one play-shaped button starts recording.
class _ReadyView extends StatelessWidget {
  const _ReadyView({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.mic_none_rounded,
            color: colors.onPrimaryContainer,
            size: 40,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '00:00.0',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 26),
        IconButton.filled(
          tooltip: 'Start recording',
          onPressed: onStart,
          iconSize: 30,
          padding: const EdgeInsets.all(18),
          icon: const Icon(Icons.play_arrow_rounded),
        ),
      ],
    );
  }
}

// Active recorder screen: timer plus pause and stop controls.
class _RecordingView extends StatelessWidget {
  const _RecordingView({
    super.key,
    required this.elapsed,
    required this.isPaused,
    required this.onPauseOrResume,
    required this.onStop,
  });

  final Duration elapsed;
  final bool isPaused;
  final VoidCallback onPauseOrResume;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            color: isPaused
                ? colors.surfaceContainerHighest
                : colors.errorContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isPaused ? Icons.mic_off_outlined : Icons.mic_rounded,
            color: isPaused ? colors.onSurfaceVariant : colors.error,
            size: 38,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _formatTimer(elapsed),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(isPaused ? 'Paused' : 'Recording...'),
        const SizedBox(height: 26),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RoundControl(
              icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              tooltip: isPaused ? 'Resume recording' : 'Pause recording',
              onPressed: onPauseOrResume,
            ),
            const SizedBox(width: 28),
            _RoundControl(
              icon: Icons.stop_rounded,
              tooltip: 'Stop recording',
              onPressed: onStop,
              isDestructive: true,
            ),
          ],
        ),
      ],
    );
  }
}

// Final recorder screen: replay the memo or add it to the diary.
class _PreviewView extends StatelessWidget {
  const _PreviewView({
    super.key,
    required this.elapsed,
    required this.isPlaying,
    required this.onReplay,
    required this.onAdd,
  });

  final Duration elapsed;
  final bool isPlaying;
  final VoidCallback onReplay;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.graphic_eq_rounded,
            color: colors.onPrimaryContainer,
            size: 40,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _formatTimer(elapsed, showTenths: false),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        const Text('Ready to add'),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RoundControl(
              icon: isPlaying ? Icons.pause_rounded : Icons.replay_rounded,
              tooltip: isPlaying ? 'Pause replay' : 'Replay voice memo',
              onPressed: onReplay,
            ),
            const SizedBox(width: 28),
            _RoundControl(
              icon: Icons.add_rounded,
              tooltip: 'Add voice memo',
              onPressed: onAdd,
              isPrimary: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({super.key, required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.mic_off_outlined, size: 52),
        const SizedBox(height: 14),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        FilledButton.tonal(onPressed: onClose, child: const Text('Close')),
      ],
    );
  }
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isDestructive = false,
    this.isPrimary = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isDestructive;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      style: isDestructive
          ? IconButton.styleFrom(
              backgroundColor: colors.errorContainer,
              foregroundColor: colors.onErrorContainer,
            )
          : isPrimary
          ? IconButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
            )
          : null,
      iconSize: 28,
      padding: const EdgeInsets.all(16),
      icon: Icon(icon),
    );
  }
}

String _formatTimer(Duration duration, {bool showTenths = true}) {
  final minutes = duration.inMinutes.toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  if (!showTenths) return '$minutes:$seconds';
  final tenths = (duration.inMilliseconds % 1000) ~/ 100;
  return '$minutes:$seconds.$tenths';
}
