import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/observation.dart';
import '../theme/omnicare_theme.dart';
import '../widgets/omnicare_button.dart';
import '../widgets/observation_card.dart';
import '../widgets/voice_recorder.dart';

/// The log screen — where caregivers record what they noticed.
///
/// Supports text input and voice recording. On success, shows a
/// structured breakdown of what was logged. Language is always
/// warm and non-clinical.
class LogScreen extends StatefulWidget {
  final ApiService apiService;
  final String patientId;

  const LogScreen({
    super.key,
    required this.apiService,
    required this.patientId,
  });

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  bool _isSubmitting = false;
  bool _hasSubmitted = false;
  String? _errorMessage;
  IngestResponse? _response;
  String? _audioBase64;
  bool _hasAudio = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();

    if (text.isEmpty && !_hasAudio) {
      setState(() {
        _errorMessage = 'Please write something or record a voice note first.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final response = await widget.apiService.logObservation(
        text: text,
        audioBase64: _audioBase64,
        patientId: widget.patientId,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _hasSubmitted = true;
          _response = response;
        });

        // Scroll to the result card
        await Future.delayed(const Duration(milliseconds: 100));
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.message;
        });
      }
    }
  }

  void _reset() {
    setState(() {
      _textController.clear();
      _isSubmitting = false;
      _hasSubmitted = false;
      _errorMessage = null;
      _response = null;
      _audioBase64 = null;
      _hasAudio = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log a moment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Go back',
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 8,
                  bottom: bottomInset > 0 ? 16 : bottomPadding + 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Prompt
                    if (!_hasSubmitted) ...[
                      Text(
                        'What happened?',
                        style: theme.textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Describe what you noticed — in your own words, however feels natural.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: OmniCareTheme.slate500,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Text input
                      TextField(
                        controller: _textController,
                        maxLines: 6,
                        minLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        style: theme.textTheme.bodyLarge,
                        decoration: InputDecoration(
                          hintText:
                              'e.g. "Dad was looking for his keys again, saying he needed to leave for work..."',
                          hintMaxLines: 3,
                          alignLabelWithHint: true,
                          errorText: _errorMessage,
                        ),
                        onChanged: (_) {
                          if (_errorMessage != null) {
                            setState(() => _errorMessage = null);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Voice recorder
                      VoiceRecorder(
                        onRecordingComplete: (base64) {
                          setState(() {
                            _audioBase64 = base64;
                            _hasAudio = true;
                            _errorMessage = null;
                          });
                        },
                      ),

                      // Audio attached indicator
                      if (_hasAudio) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: OmniCareTheme.emeraldLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: OmniCareTheme.emerald,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Voice note attached',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: OmniCareTheme.emeraldDark,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _audioBase64 = null;
                                    _hasAudio = false;
                                  });
                                },
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: OmniCareTheme.slate500,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 28),

                      // Submit button
                      OmniCareButton(
                        label: 'Save this note',
                        icon: Icons.save_outlined,
                        isLoading: _isSubmitting,
                        onPressed: _isSubmitting ? null : _submit,
                      ),
                    ],

                    // Success state
                    if (_hasSubmitted && _response != null) ...[
                      // Confirmation
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: OmniCareTheme.emeraldLight,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: OmniCareTheme.emerald,
                              size: 36,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Got it — this is saved.',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: OmniCareTheme.emeraldDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Here\'s what we captured:',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: OmniCareTheme.slate500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Structured observation card
                      ObservationCard(
                        observation: _response!.structuredData,
                      ),
                      const SizedBox(height: 28),

                      // Action buttons
                      OmniCareButton(
                        label: 'Log another',
                        icon: Icons.add_rounded,
                        onPressed: _reset,
                      ),
                      const SizedBox(height: 12),
                      OmniCareButton(
                        label: 'Go home',
                        isPrimary: false,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
