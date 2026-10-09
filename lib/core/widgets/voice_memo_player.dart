import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../services/media_encryption_provider.dart';

/// Plays one encrypted voice memo.
///
/// The saved file stays encrypted. A temporary decrypted copy is created only
/// while the user is listening, then deleted when this widget closes.
class VoiceMemoPlayer extends ConsumerStatefulWidget {
  const VoiceMemoPlayer({
    required this.audioLocation,
    required this.memoNumber,
    this.onDelete,
    this.showProgress = false,
    super.key,
  });

  final String audioLocation;
  final int memoNumber;
  final VoidCallback? onDelete;
  final bool showProgress;

  @override
  ConsumerState<VoiceMemoPlayer> createState() => _VoiceMemoPlayerState();
}

class _VoiceMemoPlayerState extends ConsumerState<VoiceMemoPlayer> {
  final AudioPlayer _player = AudioPlayer();

  bool _isPreparing = false;
  bool _isLoaded = false;
  String? _temporaryPlaybackPath;

  @override
  void dispose() {
    // dispose cannot be async, so cleanup continues in the background.
    unawaited(_cleanUpPlayer());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: StreamBuilder<PlayerState>(
        stream: _player.playerStateStream,
        builder: (context, snapshot) {
          final isPlaying = snapshot.data?.playing ?? false;

          if (widget.showProgress) {
            return _buildDetailedPlayer(context, isPlaying);
          }
          return _buildSimplePlayer(isPlaying);
        },
      ),
    );
  }

  // A small player used inside timeline cards and entry pages.
  Widget _buildSimplePlayer(bool isPlaying) {
    return ListTile(
      dense: true,
      leading: _playButton(isPlaying),
      title: Text('Voice memo ${widget.memoNumber}'),
      trailing: widget.onDelete == null
          ? null
          : IconButton(
              tooltip: 'Delete voice memo',
              onPressed: widget.onDelete,
              icon: const Icon(Icons.close_rounded),
            ),
    );
  }

  // A larger player used on Today, including seek and duration controls.
  Widget _buildDetailedPlayer(BuildContext context, bool isPlaying) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          _playButton(isPlaying),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Voice memo ${widget.memoNumber}'),
                StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final duration = _player.duration ?? Duration.zero;
                    return _progressRow(context, position, duration);
                  },
                ),
              ],
            ),
          ),
          if (widget.onDelete != null)
            IconButton(
              tooltip: 'Delete voice memo',
              onPressed: widget.onDelete,
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
    );
  }

  Widget _playButton(bool isPlaying) {
    return IconButton.filledTonal(
      tooltip: isPlaying ? 'Pause' : 'Play',
      onPressed: _isPreparing ? null : _togglePlayback,
      icon: _isPreparing
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
    );
  }

  Widget _progressRow(
    BuildContext context,
    Duration position,
    Duration duration,
  ) {
    final maximum = duration.inMilliseconds.clamp(1, 1 << 31).toDouble();
    final current = position.inMilliseconds
        .clamp(0, maximum.toInt())
        .toDouble();

    return Row(
      children: [
        Expanded(
          child: Slider(
            value: current,
            max: maximum,
            onChanged: _isLoaded
                ? (value) => _player.seek(Duration(milliseconds: value.round()))
                : null,
          ),
        ),
        Text(
          _formatDuration(duration == Duration.zero ? position : duration),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  // Loads the temporary clear file once, then toggles play and pause.
  Future<void> _togglePlayback() async {
    try {
      if (!_isLoaded) {
        setState(() => _isPreparing = true);
        _temporaryPlaybackPath = await ref
            .read(mediaEncryptionServiceProvider)
            .createPlaybackCopy(widget.audioLocation);
        await _player.setFilePath(_temporaryPlaybackPath!);
        _isLoaded = true;
      }

      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }

      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This voice memo could not be played.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPreparing = false);
    }
  }

  // Releases the player and removes its temporary decrypted file.
  Future<void> _cleanUpPlayer() async {
    await _player.dispose();
    final path = _temporaryPlaybackPath;
    if (path == null) return;

    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // The operating system also clears old temporary files.
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
