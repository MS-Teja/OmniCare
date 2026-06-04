import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/omnicare_theme.dart';
import '../widgets/loading_indicator.dart';
import 'home_screen.dart';

/// The patient picker — shown on app launch.
///
/// "Who are you caring for today?" Lists known patients and
/// lets the caregiver add a new one. No auth, no accounts —
/// just a name.
class PatientScreen extends StatefulWidget {
  final ApiService apiService;

  const PatientScreen({super.key, required this.apiService});

  @override
  State<PatientScreen> createState() => _PatientScreenState();
}

class _PatientScreenState extends State<PatientScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;

  List<String>? _patients;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _animController.forward();
    _loadPatients();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final patients = await widget.apiService.getPatients();
      if (mounted) {
        setState(() {
          _patients = patients;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.message;
        });
      }
    }
  }

  void _selectPatient(String patientId) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => HomeScreen(
          apiService: widget.apiService,
          patientId: patientId,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  void _showAddPatientDialog() {
    final controller = TextEditingController();
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: OmniCareTheme.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 28,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add a new patient',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'What\'s the patient\'s name?',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: OmniCareTheme.slate500,
                        ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    style: Theme.of(context).textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'e.g. Mr. Roy, Mrs. Sharma',
                      errorText: errorText,
                    ),
                    onSubmitted: (_) {
                      final name = controller.text.trim();
                      if (name.isEmpty) {
                        setSheetState(() => errorText = 'Please enter a name.');
                        return;
                      }
                      Navigator.pop(context);
                      _selectPatient(name);
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        final name = controller.text.trim();
                        if (name.isEmpty) {
                          setSheetState(
                              () => errorText = 'Please enter a name.');
                          return;
                        }
                        Navigator.pop(context);
                        _selectPatient(name);
                      },
                      child: const Text('Start caring'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
              const SizedBox(height: 48),

              // Heading
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Who are you\ncaring for today?',
                      style: theme.textTheme.displayLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select a patient or add a new one.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: OmniCareTheme.slate500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Content
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildContent(theme),
                ),
              ),

              // Add new patient button
              if (!_isLoading && _errorMessage == null)
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottomPadding + 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: _showAddPatientDialog,
                        icon: const Icon(Icons.person_add_rounded, size: 22),
                        label: const Text('Add a new patient'),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: LoadingIndicator(message: 'Finding your patients...'),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: OmniCareTheme.slate500,
            ),
            const SizedBox(height: 20),
            Text(
              _errorMessage!,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: OmniCareTheme.slate500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: _loadPatients,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    if (_patients == null || _patients!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 56,
              color: OmniCareTheme.slate200,
            ),
            const SizedBox(height: 20),
            Text(
              'No patients yet',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: OmniCareTheme.slate500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap below to add your first patient.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: OmniCareTheme.slate500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _patients!.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final name = _patients![index];
        return _PatientCard(
          name: name,
          onTap: () => _selectPatient(name),
        );
      },
    );
  }
}

class _PatientCard extends StatelessWidget {
  final String name;
  final VoidCallback onTap;

  const _PatientCard({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: OmniCareTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: OmniCareTheme.slate200,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: OmniCareTheme.emeraldLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: OmniCareTheme.emerald,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: OmniCareTheme.slate500,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
