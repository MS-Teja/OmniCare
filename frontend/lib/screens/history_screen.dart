import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/observation.dart';
import '../theme/omnicare_theme.dart';
import '../widgets/observation_card.dart';
import '../widgets/loading_indicator.dart';

/// A lightweight timeline of past observations.
///
/// This is a reference feature, not the main focus.
/// Pull-to-refresh supported. Tap to expand.
class HistoryScreen extends StatefulWidget {
  final ApiService apiService;
  final String patientId;

  const HistoryScreen({
    super.key,
    required this.apiService,
    required this.patientId,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Observation>? _observations;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final observations = await widget.apiService.getHistory(
        patientId: widget.patientId,
      );
      if (mounted) {
        setState(() {
          _observations = observations;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Past notes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Go back',
        ),
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: LoadingIndicator(message: 'Loading your notes...'),
      );
    }

    if (_errorMessage != null) {
      return _buildError(theme);
    }

    if (_observations == null || _observations!.isEmpty) {
      return _buildEmpty(theme);
    }

    return RefreshIndicator(
      color: OmniCareTheme.emerald,
      onRefresh: _loadHistory,
      child: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: _observations!.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final obs = _observations![index];
          return _ExpandableObservation(observation: obs);
        },
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.note_alt_outlined,
              size: 56,
              color: OmniCareTheme.slate200,
            ),
            const SizedBox(height: 20),
            Text(
              'No notes yet',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: OmniCareTheme.slate500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When you log moments, they\'ll show up here.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: OmniCareTheme.slate500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
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
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact observation that expands to show full details.
class _ExpandableObservation extends StatefulWidget {
  final Observation observation;

  const _ExpandableObservation({required this.observation});

  @override
  State<_ExpandableObservation> createState() => _ExpandableObservationState();
}

class _ExpandableObservationState extends State<_ExpandableObservation> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: ObservationCard(
          observation: widget.observation,
          isCompact: !_isExpanded,
        ),
      ),
    );
  }
}
