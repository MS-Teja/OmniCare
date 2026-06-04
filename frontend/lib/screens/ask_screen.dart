import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/intervention.dart';
import '../theme/omnicare_theme.dart';
import '../widgets/chat_bubble.dart';

/// The ask-for-help screen — a simple chat-like Q&A interface.
///
/// NOT a full chat app. The caregiver describes what's happening,
/// and the agent responds with personalized advice drawn from
/// past logged observations. Messages accumulate during the session.
class AskScreen extends StatefulWidget {
  final ApiService apiService;
  final String patientId;

  const AskScreen({
    super.key,
    required this.apiService,
    required this.patientId,
  });

  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  final List<ChatMessage> _messages = [];
  bool _isWaiting = false;
  bool _isSubmitting = false; // debounce guard

  @override
  void initState() {
    super.initState();
    // Welcome message
    _messages.add(ChatMessage(
      text: 'Tell me what\'s going on and I\'ll look through past notes '
          'to find what might help.',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    _isSubmitting = true;

    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isWaiting = true;
    });

    _textController.clear();
    _scrollToBottom();

    try {
      final response = await widget.apiService.askForHelp(
        text,
        patientId: widget.patientId,
      );

      if (mounted) {
        setState(() {
          _isWaiting = false;
          _messages.add(
            ChatMessage.fromIntervention(response.intervention),
          );
        });
        _scrollToBottom();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isWaiting = false;
          _messages.add(ChatMessage(
            text: e.message,
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
        _scrollToBottom();
      }
    } finally {
      _isSubmitting = false;
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _clearConversation() {
    setState(() {
      _messages.clear();
      _messages.add(ChatMessage(
        text: 'Tell me what\'s going on and I\'ll look through past notes '
            'to find what might help.',
        isUser: false,
        timestamp: DateTime.now(),
      ));
      _isWaiting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask for help'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Go back',
        ),
        actions: [
          if (_messages.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _clearConversation,
                style: TextButton.styleFrom(
                  minimumSize: const Size(56, 56),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Text(
                  'Start over',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: OmniCareTheme.sapphire,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: _messages.length + (_isWaiting ? 1 : 0),
              itemBuilder: (context, index) {
                // Loading bubble
                if (_isWaiting && index == _messages.length) {
                  return const ChatBubble(
                    text: '',
                    isUser: false,
                    isLoading: true,
                  );
                }

                final message = _messages[index];
                return ChatBubble(
                  message: message,
                  text: message.text,
                  isUser: message.isUser,
                );
              },
            ),
          ),

          // Input area
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 12,
              top: 12,
              bottom: bottomPadding + 12,
            ),
            decoration: BoxDecoration(
              color: OmniCareTheme.surfaceWhite,
              border: Border(
                top: BorderSide(
                  color: OmniCareTheme.slate200,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    maxLines: 4,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    style: theme.textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'What\'s happening right now?',
                      filled: true,
                      fillColor: OmniCareTheme.scaffoldBg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: OmniCareTheme.slate200,
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: OmniCareTheme.slate200,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: OmniCareTheme.emerald,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 8),
                // Send button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isWaiting ? null : _sendMessage,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _isWaiting
                            ? OmniCareTheme.slate200
                            : OmniCareTheme.sapphire,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        'Ask',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: _isWaiting
                              ? OmniCareTheme.slate500
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
