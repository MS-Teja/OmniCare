import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/omnicare_theme.dart';

/// A voice recording button with visual feedback.
///
/// Tapping starts recording, tapping again stops and returns
/// the audio as a base64-encoded string. Shows a pulsing red
/// indicator while recording with elapsed time.
class VoiceRecorder extends StatefulWidget {
  final ValueChanged<String> onRecordingComplete;
  final VoidCallback? onRecordingStarted;

  const VoiceRecorder({
    super.key,
    required this.onRecordingComplete,
    this.onRecordingStarted,
  });

  @override
  State<VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder>
    with SingleTickerProviderStateMixin {
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _hasPermission = false;
  bool _permissionDenied = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _checkPermission();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.microphone.status;
    if (mounted) {
      setState(() {
        _hasPermission = status.isGranted;
        _permissionDenied = status.isPermanentlyDenied;
      });
    }
  }

  Future<void> _requestPermission() async {
    final status = await Permission.microphone.request();
    if (mounted) {
      setState(() {
        _hasPermission = status.isGranted;
        _permissionDenied = status.isPermanentlyDenied;
      });
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    if (!_hasPermission) {
      await _requestPermission();
      if (!_hasPermission) {
        if (mounted && _permissionDenied) {
          _showPermissionDialog();
        }
        return;
      }
    }

    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/omnicare_recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

      if (await _recorder.hasPermission()) {
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _elapsed = Duration.zero;
        });

        _pulseController.repeat(reverse: true);
        widget.onRecordingStarted?.call();

        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() => _elapsed += const Duration(seconds: 1));
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not start recording. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    _pulseController.stop();
    _pulseController.reset();

    try {
      final path = await _recorder.stop();

      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final base64Audio = base64Encode(bytes);
          widget.onRecordingComplete(base64Audio);
          // Clean up temp file
          await file.delete().catchError((_) => file);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording failed. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _elapsed = Duration.zero;
        });
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmniCareTheme.surfaceWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Microphone access needed',
          style: Theme.of(ctx).textTheme.headlineMedium,
        ),
        content: Text(
          'To record voice notes, OmniCare needs access to your microphone. '
          'You can enable this in your device settings.',
          style: Theme.of(ctx).textTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_isRecording) {
      return _buildRecordingState(context);
    }
    return _buildIdleState(context);
  }

  Widget _buildIdleState(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggleRecording,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: OmniCareTheme.emeraldLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.mic_rounded,
                color: OmniCareTheme.emerald,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Record a voice note',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: OmniCareTheme.emeraldDark,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: OmniCareTheme.errorRedLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: OmniCareTheme.errorRed.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Pulsing red dot
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: OmniCareTheme.errorRed,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Timer
          Text(
            _formatDuration(_elapsed),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: OmniCareTheme.errorRed,
                  fontFeatures: [const FontFeature.tabularFigures()],
                ),
          ),
          const SizedBox(width: 8),
          Text(
            'Recording...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OmniCareTheme.slate500,
                ),
          ),

          const Spacer(),

          // Stop button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggleRecording,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: OmniCareTheme.errorRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Done',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
