import 'package:flutter/material.dart';
import '../models/intervention.dart';
import '../theme/omnicare_theme.dart';

/// A chat message bubble for the ask-for-help screen.
///
/// User messages: right-aligned, sage background.
/// Assistant messages: left-aligned, with optional structured layout —
/// a prominent action card on top, then the detailed context below.
class ChatBubble extends StatelessWidget {
  final ChatMessage? message;

  // Legacy fields for simple text / loading bubbles
  final String? text;
  final bool isUser;
  final bool isLoading;

  const ChatBubble({
    super.key,
    this.message,
    this.text,
    this.isUser = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isUserMessage = message?.isUser ?? isUser;
    final displayText = message?.text ?? text ?? '';

    if (isLoading) {
      return _buildContainer(
        context,
        isUser: false,
        child: _LoadingDots(),
      );
    }

    // Structured assistant response with ACTION + CONTEXT
    if (message != null && !isUserMessage && message!.hasStructuredResponse) {
      return _buildStructuredResponse(context, message!);
    }

    // Plain text bubble (user message or unstructured response)
    return _buildContainer(
      context,
      isUser: isUserMessage,
      child: Text(
        displayText,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: isUserMessage ? Colors.white : OmniCareTheme.slate900,
              height: 1.5,
            ),
      ),
    );
  }

  /// Builds the structured two-part response:
  /// 1. A prominent action card (what to do NOW)
  /// 2. The context explanation below (why)
  Widget _buildStructuredResponse(BuildContext context, ChatMessage msg) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.88,
        ),
        margin: const EdgeInsets.only(right: 24, bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Action Card ─────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: OmniCareTheme.emeraldLight,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(6),
                  bottomRight: Radius.circular(6),
                ),
                border: Border.all(
                  color: OmniCareTheme.emerald.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: OmniCareTheme.emerald,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Try this',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    msg.action!,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: OmniCareTheme.slate900,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // ── Context Section ─────────────────────────
            if (msg.context != null && msg.context!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: OmniCareTheme.surfaceWhite,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                    bottomLeft: Radius.circular(6),
                    bottomRight: Radius.circular(20),
                  ),
                  border: Border.all(
                    color: OmniCareTheme.slate200,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Why',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: OmniCareTheme.slate500,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      msg.context!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: OmniCareTheme.slate500,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContainer(
    BuildContext context, {
    required bool isUser,
    required Widget child,
  }) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        margin: EdgeInsets.only(
          left: isUser ? 48 : 0,
          right: isUser ? 0 : 48,
          bottom: 12,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isUser ? OmniCareTheme.sapphire : OmniCareTheme.surfaceWhite,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 20),
          ),
          border: isUser
              ? null
              : Border.all(color: OmniCareTheme.slate200, width: 1),
        ),
        child: child,
      ),
    );
  }
}

/// Animated three-dot loading indicator for assistant "thinking" state.
class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      return AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
    });

    _animations = _controllers.map((c) {
      return Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(parent: c, curve: Curves.easeOutQuad),
      );
    }).toList();

    for (var i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Finding past notes that might help',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: OmniCareTheme.slate500,
                fontStyle: FontStyle.italic,
              ),
        ),
        const SizedBox(width: 8),
        ...List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _animations[i],
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _animations[i].value),
                child: child,
              );
            },
            child: Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: OmniCareTheme.emerald.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
      ],
    );
  }
}
