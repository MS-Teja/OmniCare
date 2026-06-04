import 'package:flutter/material.dart';
import '../models/observation.dart';
import '../theme/omnicare_theme.dart';

/// Displays a structured observation in a warm, readable card.
///
/// Uses human-friendly labels: "What triggered it", "What helped",
/// "What didn't help" — never field names like "failed_interventions".
class ObservationCard extends StatelessWidget {
  final Observation observation;
  final bool isCompact;

  const ObservationCard({
    super.key,
    required this.observation,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: OmniCareTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OmniCareTheme.slate200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: type badge + sentiment
            Row(
              children: [
                _TypeBadge(label: observation.typeLabel),
                const Spacer(),
                Text(
                  '${observation.sentimentEmoji} ${observation.sentimentLabel}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Content
            Text(
              observation.content,
              style: theme.textTheme.bodyLarge,
              maxLines: isCompact ? 3 : null,
              overflow: isCompact ? TextOverflow.ellipsis : null,
            ),

            if (!isCompact) ...[
              // Triggers
              if (observation.triggers.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionLabel(
                  icon: Icons.flash_on_rounded,
                  label: 'What triggered it',
                  color: OmniCareTheme.sapphire,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: observation.triggers
                      .map((t) => _Tag(text: t, color: OmniCareTheme.sapphireLight))
                      .toList(),
                ),
              ],

              // Successful interventions
              if (observation.successfulInterventions.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionLabel(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'What helped',
                  color: OmniCareTheme.emerald,
                ),
                const SizedBox(height: 6),
                ...observation.successfulInterventions.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: OmniCareTheme.emerald,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(s, style: theme.textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Failed interventions
              if (observation.failedInterventions.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionLabel(
                  icon: Icons.highlight_off_rounded,
                  label: 'What didn\'t help',
                  color: OmniCareTheme.errorRed,
                ),
                const SizedBox(height: 6),
                ...observation.failedInterventions.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: OmniCareTheme.errorRed,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(f, style: theme.textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],

            // Timestamp
            if (observation.timestamp.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                _formatTimestamp(observation.timestamp),
                style: theme.textTheme.labelSmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays} days ago';

      return '${dt.month}/${dt.day}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

class _TypeBadge extends StatelessWidget {
  final String label;

  const _TypeBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: OmniCareTheme.emeraldLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: OmniCareTheme.emeraldDark,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;

  const _Tag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: OmniCareTheme.slate900,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}
