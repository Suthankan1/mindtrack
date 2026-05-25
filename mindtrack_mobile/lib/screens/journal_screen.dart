import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/mood_provider.dart';
import '../services/dio_service.dart';
import '../widgets/constellation_canvas.dart';
import '../widgets/custom_score_slider.dart';

/// The Journal tab — displays the animated [ConstellationCanvas] of mood stars
/// and a scrollable list of [_ExpandableJournalEntryCard] entries.
///
/// Provides a FAB and inline button to open the [_MoodLoggingBottomSheet]
/// for creating new mood entries with a note, score, and tags.
class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  // Helper to format date beautifully
  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[local.month - 1];
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month ${local.day}, ${local.year} • $hour:$minute $ampm';
  }

  // Determine score color
  Color _getScoreColor(int score) {
    return Color.lerp(
      AppColors.errorColor,
      AppColors.primaryColor,
      (score.toDouble().clamp(1.0, 5.0) - 1.0) / 4.0,
    )!;
  }

  // Open details bottom sheet when a constellation star is tapped
  void _showMoodDetailsBottomSheet(BuildContext context, MoodEntry entry) {
    final scoreColor = _getScoreColor(entry.moodScore);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: AppColors.borderOverlay, width: 1.5),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bottom Sheet handle
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.borderOverlay,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title and Score Pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Star Log Details',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTime(entry.timestamp),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: scoreColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, color: scoreColor, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${entry.moodScore}.0',
                          style: TextStyle(
                            color: scoreColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Divider
              const Divider(color: AppColors.borderOverlay),
              const SizedBox(height: 20),

              // Journal Note Content
              Text(
                'COSMIC REFLECTION',
                style: TextStyle(
                  color: AppColors.primaryColor.withOpacity(0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.borderOverlay.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.borderOverlay.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  entry.note.isEmpty
                      ? 'No notes recorded for this star.'
                      : entry.note,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Tags
              if (entry.tags.isNotEmpty) ...[
                Text(
                  'ASSOCIATED CONSTELLATIONS',
                  style: TextStyle(
                    color: AppColors.primaryColor.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: entry.tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primaryColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: AppColors.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // Open the mood logger bottom sheet
  void _showMoodLoggingBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _MoodLoggingBottomSheet(
          onSaved: () {
            // Trigger local refresh or immediate state synchronization
            ref.read(moodHistoryProvider.notifier).refresh();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moodHistoryAsync = ref.watch(moodHistoryProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMoodLoggingBottomSheet(context),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.backgroundColor,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, size: 28),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(moodHistoryProvider.notifier).refresh();
          },
          color: AppColors.primaryColor,
          backgroundColor: AppColors.surfaceColor,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Mind Journal',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Track your emotional trajectory over the week.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 28),

                // Constellation Canvas Section
                moodHistoryAsync.when(
                  data: (entries) {
                    return ConstellationCanvas(
                      entries: entries,
                      onDotTapped: (entry) =>
                          _showMoodDetailsBottomSheet(context, entry),
                    );
                  },
                  loading: () => Container(
                    height: 260,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.borderOverlay),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ),
                  error: (err, stack) => Container(
                    height: 260,
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.borderOverlay),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.errorColor,
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Failed to load celestial map.',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () =>
                              ref.read(moodHistoryProvider.notifier).refresh(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            foregroundColor: AppColors.backgroundColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Recent Logs Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Entries',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showMoodLoggingBottomSheet(context),
                      icon: const Icon(
                        Icons.add,
                        color: AppColors.primaryColor,
                        size: 18,
                      ),
                      label: const Text(
                        'Log state',
                        style: TextStyle(
                          color: AppColors.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Recent Logs List
                moodHistoryAsync.when(
                  data: (entries) {
                    if (entries.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.borderOverlay),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.star_border_rounded,
                              color: AppColors.textMuted.withOpacity(0.5),
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Your sky is waiting to be filled.',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tap + below to log your first mood star.',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return _ExpandableJournalEntryCard(
                          entry: entry,
                          formattedDate: _formatDateTime(entry.timestamp),
                          scoreColor: _getScoreColor(entry.moodScore),
                        );
                      },
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.only(top: 32.0),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ),
                  error: (err, stack) => const SizedBox(),
                ),
                const SizedBox(
                  height: 80,
                ), // extra padding to avoid floating button overlap
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An animated, expandable card that represents a single mood journal entry.
///
/// In collapsed state shows a 2-line preview of the note and a score pill.
/// Tapping expands the card to reveal the full note body and associated tags.
// Expandable Card for individual journal entry
class _ExpandableJournalEntryCard extends ConsumerStatefulWidget {
  final MoodEntry entry;
  final String formattedDate;
  final Color scoreColor;

  const _ExpandableJournalEntryCard({
    required this.entry,
    required this.formattedDate,
    required this.scoreColor,
  });

  @override
  ConsumerState<_ExpandableJournalEntryCard> createState() =>
      _ExpandableJournalEntryCardState();
}

class _ExpandableJournalEntryCardState
    extends ConsumerState<_ExpandableJournalEntryCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _rotationController;

  // AI Sentiment state variables
  bool _isAnalyzing = false;
  Map<String, dynamic>? _sentimentResult;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _rotationController.forward();
      } else {
        _rotationController.reverse();
      }
    });
  }

  Future<void> _analyzeSentiment() async {
    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final dio = ref.read(dioServiceProvider);
      final result = await dio.getSentimentAnalysis(widget.entry.id.toString().toLowerCase());
      setState(() {
        _sentimentResult = result;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isAnalyzing = false;
      });
    }
  }

  Widget _buildShimmerLoading() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOverlay.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.borderOverlay.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 60,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.borderOverlay.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.borderOverlay.withOpacity(0.3),
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 200,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.borderOverlay.withOpacity(0.3),
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentimentResultCard() {
    final sentiment = (_sentimentResult!['sentiment'] ?? 'neutral').toString().toLowerCase();
    final tone = _sentimentResult!['emotionalTone'] ?? 'neutral';
    final supportMessage = _sentimentResult!['supportMessage'] ?? '';
    final themes = List<String>.from(_sentimentResult!['themes'] ?? []);

    Color sentimentColor = AppColors.textMuted;
    if (sentiment == 'positive') {
      sentimentColor = AppColors.primaryColor;
    } else if (sentiment == 'negative') {
      sentimentColor = AppColors.errorColor;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Sentiment Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: sentimentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: sentimentColor.withOpacity(0.35),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    sentiment == 'positive'
                        ? Icons.mood_rounded
                        : sentiment == 'negative'
                            ? Icons.mood_bad_rounded
                            : Icons.sentiment_neutral_rounded,
                    color: sentimentColor,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    sentiment.toUpperCase(),
                    style: TextStyle(
                      color: sentimentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Tone Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.borderOverlay,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.borderOverlay.withOpacity(0.8),
                  width: 1,
                ),
              ),
              child: Text(
                tone.toString().toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        if (themes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: themes.map((theme) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.borderOverlay.withOpacity(0.4),
                  ),
                ),
                child: Text(
                  '#$theme',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        if (supportMessage.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: sentimentColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sentimentColor.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Text(
              supportMessage,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12.5,
                height: 1.45,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isExpanded
              ? AppColors.primaryColor.withOpacity(0.4)
              : AppColors.borderOverlay,
          width: _isExpanded ? 1.5 : 1,
        ),
        boxShadow: _isExpanded
            ? [
                BoxShadow(
                  color: AppColors.primaryColor.withOpacity(0.06),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggleExpanded,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.formattedDate,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // Glowing Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: widget.scoreColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: widget.scoreColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              color: widget.scoreColor,
                              size: 14,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${widget.entry.moodScore}.0',
                              style: TextStyle(
                                color: widget.scoreColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Expandable Note View
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 250),
                    firstCurve: Curves.easeInOut,
                    secondCurve: Curves.easeInOut,
                    crossFadeState: _isExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: Text(
                      widget.entry.note.isEmpty
                          ? 'No notes recorded.'
                          : widget.entry.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.85),
                        height: 1.4,
                      ),
                    ),
                    secondChild: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.entry.note.isEmpty
                              ? 'No notes recorded.'
                              : widget.entry.note,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            height: 1.45,
                          ),
                        ),
                        if (widget.entry.tags.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: widget.entry.tags.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.borderOverlay,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.borderOverlay.withOpacity(
                                      0.8,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        // AI Sentiment Analysis Section
                        if (widget.entry.note.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Divider(color: AppColors.borderOverlay, height: 1),
                          const SizedBox(height: 16),
                          if (_sentimentResult == null && !_isAnalyzing) ...[
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _analyzeSentiment,
                                icon: const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: AppColors.primaryColor,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Analyze Vibe with AI',
                                  style: TextStyle(
                                    color: AppColors.primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  backgroundColor: AppColors.primaryColor.withOpacity(0.08),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: AppColors.primaryColor.withOpacity(0.2),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: AppColors.errorColor,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ] else if (_isAnalyzing) ...[
                            _buildShimmerLoading(),
                          ] else if (_sentimentResult != null) ...[
                            _buildSentimentResultCard(),
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Expand/Collapse Chevron Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      RotationTransition(
                        turns: Tween<double>(
                          begin: 0,
                          end: 0.5,
                        ).animate(_rotationController),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A full-screen bottom sheet for composing a new mood entry.
///
/// Includes:
/// - [CustomScoreSlider] for selecting a score from 1–5
/// - A text field for free-form journal notes
/// - Tag chips (Work, Sleep, Exercise, Social, Other)
/// - A save button that calls [moodActionsProvider] and triggers [onSaved]
// Mood Logging Modal Bottom Sheet
class _MoodLoggingBottomSheet extends ConsumerStatefulWidget {
  final VoidCallback onSaved;

  const _MoodLoggingBottomSheet({required this.onSaved});

  @override
  ConsumerState<_MoodLoggingBottomSheet> createState() =>
      _MoodLoggingBottomSheetState();
}

class _MoodLoggingBottomSheetState
    extends ConsumerState<_MoodLoggingBottomSheet> {
  double _score = 3.0; // Default centered score
  final TextEditingController _noteController = TextEditingController();
  final List<String> _selectedTags = [];
  bool _isSaving = false;

  bool _isGeneratingPrompt = false;
  Map<String, dynamic>? _promptResult;

  final List<String> _availableTags = [
    'Work',
    'Sleep',
    'Exercise',
    'Social',
    'Other',
  ];

  Future<void> _generatePrompt() async {
    setState(() {
      _isGeneratingPrompt = true;
      _promptResult = null;
    });

    try {
      final dio = ref.read(dioServiceProvider);
      final result = await dio.generateJournalPrompt(
        moodScore: _score.round(),
        tags: _selectedTags,
      );
      setState(() {
        _promptResult = result;
        _isGeneratingPrompt = false;
      });
    } catch (e) {
      // Local fallback in case of no network / server error
      setState(() {
        _promptResult = _getLocalFallbackPrompt(_score.round());
        _isGeneratingPrompt = false;
      });
    }
  }

  Map<String, dynamic> _getLocalFallbackPrompt(int score) {
    switch (score) {
      case 1:
        return {
          'promptTitle': 'Calming the Storm',
          'promptQuestion': 'What is currently demanding the most energy from you, and how can you take one step back to breathe?',
          'followUpQuestions': [
            'Where do you feel this tension in your body?',
            'What is one thing you can say "no" to today?',
            'Who is someone you can lean on for support?'
          ],
          'estimatedMinutes': 3,
          'tone': 'Empathetic and grounding',
          'aiAvailable': false
        };
      case 2:
        return {
          'promptTitle': 'Gentle Refueling',
          'promptQuestion': 'When your energy is low, what is the smallest, most comforting thing you can do for yourself right now?',
          'followUpQuestions': [
            'How has your sleep or rest been lately?',
            'What is a gentle activity that usually restores you?',
            'How can you show yourself kindness today?'
          ],
          'estimatedMinutes': 3,
          'tone': 'Soft and supportive',
          'aiAvailable': false
        };
      case 4:
        return {
          'promptTitle': 'Anchoring the Good',
          'promptQuestion': 'What brought a sense of peace, accomplishment, or quiet joy to your day, even if it was tiny?',
          'followUpQuestions': [
            'How can you carry this pleasant feeling into tomorrow?',
            'What activity contributed most to this stable mood?',
            'What are you feeling grateful for right now?'
          ],
          'estimatedMinutes': 5,
          'tone': 'Warm and appreciative',
          'aiAvailable': false
        };
      case 5:
        return {
          'promptTitle': 'Celebrating Clarity',
          'promptQuestion': 'Your energy feels radiant today. What is flowing well in your life right now that you want to celebrate?',
          'followUpQuestions': [
            'How can you capture and remember this feeling of expansion?',
            'How can you share this positive energy with others?',
            'What dreams or hopes feel closest to you today?'
          ],
          'estimatedMinutes': 5,
          'tone': 'Uplifting and vibrant',
          'aiAvailable': false
        };
      default:
        return {
          'promptTitle': 'Checking In',
          'promptQuestion': 'How would you describe the transition of your energy today from morning until this very moment?',
          'followUpQuestions': [
            'What felt stable or balanced today?',
            'Is there any subtle emotion waiting to be noticed?',
            'What is one word that sums up your current state?'
          ],
          'estimatedMinutes': 5,
          'tone': 'Mindful and observant',
          'aiAvailable': false
        };
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveEntry() async {
    setState(() => _isSaving = true);
    try {
      final note = _noteController.text.trim();
      final scoreVal = _score.round();

      // Submit request to local and remote via Riverpod
      await ref
          .read(moodActionsProvider)
          .logMood(
            scoreVal,
            note: note.isEmpty ? 'Logged via mobile app' : note,
            tags: _selectedTags,
          );

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceColor,
            elevation: 4,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.primaryColor, width: 1.5),
            ),
            content: Row(
              children: [
                const Icon(Icons.star_rounded, color: AppColors.primaryColor),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Mood log committed to the cosmos!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.errorColor, width: 1.5),
            ),
            content: Text(
              'Failed to log mood: $e',
              style: const TextStyle(
                color: AppColors.errorColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppColors.borderOverlay, width: 1.5),
        ),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: 32 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bottom Sheet handle
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.borderOverlay,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Header Title
            Text(
              'Log Mood Star',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Map a new point in your emotional trajectory.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // Custom Slider
            CustomScoreSlider(
              value: _score,
              onChanged: (newVal) {
                setState(() => _score = newVal);
              },
            ),
            const SizedBox(height: 28),

            // Notes Title and AI Prompt Trigger Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cosmic Notes',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (_promptResult == null && !_isGeneratingPrompt)
                  TextButton.icon(
                    onPressed: _generatePrompt,
                    icon: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.primaryColor,
                      size: 15,
                    ),
                    label: const Text(
                      'AI Prompt',
                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      backgroundColor: AppColors.primaryColor.withOpacity(0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: AppColors.primaryColor.withOpacity(0.2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // AI Loading Shimmer
            if (_isGeneratingPrompt) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceColor.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.borderOverlay.withOpacity(0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 100,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.borderOverlay.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.borderOverlay.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // AI Prompt Result Card
            if (_promptResult != null) ...[
              GestureDetector(
                onTap: () {
                  final question = _promptResult!['promptQuestion'] ?? '';
                  if (question.isNotEmpty) {
                    setState(() {
                      _noteController.text = _noteController.text.isEmpty
                          ? '$question\n\n'
                          : '$question\n\n${_noteController.text}';
                      _noteController.selection = TextSelection.fromPosition(
                        TextPosition(offset: _noteController.text.length),
                      );
                    });
                  }
                },
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primaryColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            (_promptResult!['promptTitle'] ?? '').toString().toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.primaryColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.borderOverlay,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '⏱️ ${_promptResult!['estimatedMinutes'] ?? 3}m',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.borderOverlay,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  (_promptResult!['tone'] ?? 'Gentle').toString().toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _promptResult!['promptQuestion'] ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '✨ Tap to insert prompt into notes field',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_promptResult!['followUpQuestions'] != null &&
                          (_promptResult!['followUpQuestions'] as List).isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.only(top: 10),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: AppColors.borderOverlay,
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'FOLLOW-UP CONSIDERATIONS:',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ...(_promptResult!['followUpQuestions'] as List).map((q) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '• ',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          q.toString(),
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.7),
                                            fontSize: 11,
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            // Note Text Field
            TextField(
              controller: _noteController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Describe the gravity of this moment...',
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: AppColors.borderOverlay.withOpacity(0.3),
                contentPadding: const EdgeInsets.all(16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.borderOverlay),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.primaryColor,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Activity Tags Section
            const Text(
              'Activity Constellations',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                  selectedColor: AppColors.primaryColor.withValues(alpha: 0.12),
                  checkmarkColor: AppColors.primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textMuted,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 12,
                  ),
                  backgroundColor: AppColors.borderOverlay.withOpacity(0.4),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primaryColor
                        : AppColors.borderOverlay,
                    width: isSelected ? 1.2 : 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveEntry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: AppColors.backgroundColor,
                  disabledBackgroundColor: AppColors.primaryColor.withOpacity(
                    0.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(
                        color: AppColors.backgroundColor,
                      )
                    : const Text(
                        'Commit to Cosmos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
