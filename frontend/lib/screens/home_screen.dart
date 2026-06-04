import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/omnicare_theme.dart';
import 'log_screen.dart';
import 'ask_screen.dart';
import 'history_screen.dart';

/// The home screen — the emotional anchor of the app.
///
/// Two large, unmistakable choices: "Log a moment" and "Ask for help".
/// No hamburger menus, no tabs, no bottom nav. Just clarity.
class HomeScreen extends StatefulWidget {
  final ApiService apiService;
  final String patientId;

  const HomeScreen({
    super.key,
    required this.apiService,
    required this.patientId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation1;
  late final Animation<Offset> _slideAnimation2;
  bool _backendOnline = true;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _slideAnimation1 = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.15, 0.7, curve: Curves.easeOutBack), // Springier entrance
    ));

    _slideAnimation2 = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.3, 0.85, curve: Curves.easeOutBack), // Springier entrance
    ));

    _animController.forward();
    _checkBackend();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkBackend() async {
    final online = await widget.apiService.healthCheck();
    if (mounted) {
      setState(() => _backendOnline = online);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),

              // Greeting
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Caring for ${widget.patientId}',
                        style: theme.textTheme.displayLarge,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'What would you like to do?',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: OmniCareTheme.slate500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Action cards
              Expanded(
                child: Column(
                  children: [
                    // Log a moment
                    Expanded(
                      child: SlideTransition(
                        position: _slideAnimation1,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _ActionCard(
                            title: 'Log a moment',
                            subtitle: 'Write or record what you noticed',
                            icon: Icons.edit_note_rounded,
                            color: OmniCareTheme.emerald,
                            backgroundColor: OmniCareTheme.emeraldLight,
                            onTap: () => Navigator.push(
                              context,
                              _gentleRoute(LogScreen(
                                apiService: widget.apiService,
                                patientId: widget.patientId,
                              )),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Ask for help
                    Expanded(
                      child: SlideTransition(
                        position: _slideAnimation2,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _ActionCard(
                            title: 'Ask for help',
                            subtitle: 'Get advice from past experiences',
                            icon: Icons.chat_bubble_outline_rounded,
                            color: OmniCareTheme.sapphire,
                            backgroundColor: OmniCareTheme.sapphireLight,
                            onTap: () => Navigator.push(
                              context,
                              _gentleRoute(AskScreen(
                                apiService: widget.apiService,
                                patientId: widget.patientId,
                              )),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Past notes link (subtle, not prominent)
              FadeTransition(
                opacity: _fadeAnimation,
                child: Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      _gentleRoute(HistoryScreen(
                        apiService: widget.apiService,
                        patientId: widget.patientId,
                      )),
                    ),
                    icon: const Icon(Icons.history_rounded, size: 20),
                    label: const Text('View past notes'),
                  ),
                ),
              ),

              // Backend status (only if offline)
              if (!_backendOnline)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: OmniCareTheme.errorRedLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          size: 18,
                          color: OmniCareTheme.errorRed,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Can\'t connect to OmniCare. Check that the backend is running.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: OmniCareTheme.errorRed,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _checkBackend,
                          child: const Icon(
                            Icons.refresh_rounded,
                            size: 20,
                            color: OmniCareTheme.errorRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              SizedBox(height: bottomPadding + 16),
            ],
          ),
        ),
      ),
    );
  }

  Route _gentleRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.03, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }
}

class _ActionCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutExpo), // Firmer, punchier press
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28), // Asymmetric padding
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(32), // Dramatically round
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64, // Larger icon container
                height: 64,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.2), // Darker tint
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.color,
                  size: 34, // Bolder icon
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.displayMedium?.copyWith(
                  color: OmniCareTheme.slate900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: OmniCareTheme.slate500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
