import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/avatar_affinity.dart';

class QuestCard extends StatefulWidget {
  final String title;
  final String xpReward;
  final String category;
  final bool completed;
  final VoidCallback? onComplete;
  final int index;
  final String? description;

  /// Optional sub-steps rendered as an interactive checklist when expanded.
  final List<String>? steps;

  /// The avatar's dominant stat (e.g. 'health', 'knowledge'). When this
  /// matches [category], an affinity bonus badge is shown and the boosted
  /// XP value is displayed.
  final String? avatarAffinityStat;

  const QuestCard({
    super.key,
    required this.title,
    required this.xpReward,
    required this.category,
    this.completed = false,
    this.onComplete,
    this.index = 0,
    this.description,
    this.steps,
    this.avatarAffinityStat,
  });

  @override
  State<QuestCard> createState() => _QuestCardState();
}

class _QuestCardState extends State<QuestCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;
  bool _localCompleted = false;
  bool _expanded = false;
  late List<bool> _stepChecked;

  @override
  void initState() {
    super.initState();
    _localCompleted = widget.completed;
    _stepChecked = List.filled(widget.steps?.length ?? 0, false);

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideIn = Tween<Offset>(
      begin: const Offset(0.08, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: 100 * widget.index), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleComplete() {
    setState(() => _localCompleted = true);
    widget.onComplete?.call();
  }

  void _toggleExpand() {
    setState(() => _expanded = !_expanded);
  }

  void _showFullPreview(BuildContext context) {
    final categoryColor = _categoryColor(widget.category);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _QuestPreviewSheet(
        title: widget.title,
        description: widget.description,
        category: widget.category,
        categoryColor: categoryColor,
        xpReward: widget.xpReward,
        steps: widget.steps,
        stepChecked: List<bool>.from(_stepChecked),
        onStepToggled: (i, val) => setState(() => _stepChecked[i] = val),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = _categoryColor(widget.category);
    final hasDescription =
        widget.description != null && widget.description!.trim().isNotEmpty;
    final hasSteps = widget.steps != null && widget.steps!.isNotEmpty;
    final isExpandable = hasDescription || hasSteps;
    final hasAffinity = AvatarAffinity.isAffinity(
        widget.avatarAffinityStat, widget.category);
    final baseXp = int.tryParse(widget.xpReward) ?? 0;
    final displayXp = hasAffinity
        ? AvatarAffinity.computeXp(baseXp, widget.avatarAffinityStat, widget.category)
        : baseXp;

    return FadeTransition(
      opacity: _fadeIn,
      child: SlideTransition(
        position: _slideIn,
        child: GestureDetector(
          onLongPress: isExpandable ? () => _showFullPreview(context) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: AppTheme.questCard(completed: _localCompleted),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Main row ──
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Status circle
                      GestureDetector(
                        onTap: _localCompleted ? null : _handleComplete,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _localCompleted
                                ? AppTheme.copper
                                : categoryColor.withValues(alpha: 0.12),
                            border: Border.all(
                              color: _localCompleted
                                  ? AppTheme.copper
                                  : categoryColor.withValues(alpha: 0.58),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (_localCompleted
                                            ? AppTheme.copper
                                            : categoryColor)
                                        .withValues(alpha: 0.16),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: _localCompleted
                              ? const Icon(Icons.check,
                                  size: 15, color: AppTheme.bg900)
                              : Icon(Icons.auto_awesome,
                                  size: 15, color: categoryColor),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Title + description preview + category
                      Expanded(
                        child: GestureDetector(
                          onTap: isExpandable ? _toggleExpand : null,
                          behavior: HitTestBehavior.opaque,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.title,
                                      style: AppTheme.uiFont(
                                        size: 14,
                                        weight: FontWeight.w700,
                                        color: _localCompleted
                                            ? AppTheme.text400
                                            : AppTheme.text100,
                                      ).copyWith(
                                        decoration: _localCompleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                        decorationColor: AppTheme.text400,
                                      ),
                                    ),
                                  ),
                                  // Expand chevron
                                  if (isExpandable) ...[
                                    const SizedBox(width: 6),
                                    AnimatedRotation(
                                      turns: _expanded ? 0.5 : 0,
                                      duration:
                                          const Duration(milliseconds: 250),
                                      child: Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 18,
                                        color: categoryColor
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              // Collapsed description preview
                              if (hasDescription && !_expanded) ...[
                                const SizedBox(height: 4),
                                Text(
                                  widget.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.uiFont(
                                    size: 11.5,
                                    weight: FontWeight.w500,
                                    color: _localCompleted
                                        ? AppTheme.text600
                                        : AppTheme.text400,
                                  ).copyWith(height: 1.3),
                                ),
                              ],
                              const SizedBox(height: 5),
                              // Category pill
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: categoryColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: categoryColor
                                              .withValues(alpha: 0.45),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _categoryLabel(widget.category),
                                    style: AppTheme.uiFont(
                                      size: 11,
                                      weight: FontWeight.w600,
                                      color: categoryColor,
                                    ),
                                  ),
                                  if (isExpandable) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      _expanded
                                          ? 'tap to collapse'
                                          : 'tap to expand · hold to preview',
                                      style: AppTheme.uiFont(
                                        size: 10,
                                        color:
                                            AppTheme.text600.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // XP badge (+ affinity indicator)
                      AnimatedOpacity(
                        opacity: _localCompleted ? 0.35 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ⚡ Affinity pill
                            if (hasAffinity && !_localCompleted)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: categoryColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: categoryColor.withValues(alpha: 0.5),
                                      width: 0.8,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: categoryColor.withValues(alpha: 0.25),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.bolt_rounded,
                                          size: 9,
                                          color: categoryColor),
                                      const SizedBox(width: 2),
                                      Text(
                                        'AFFINITY',
                                        style: AppTheme.monoFont(
                                          size: 7.5,
                                          color: categoryColor,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            // XP badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: _localCompleted
                                    ? AppTheme.bg700
                                    : hasAffinity
                                        ? categoryColor.withValues(alpha: 0.9)
                                        : AppTheme.copper.withValues(alpha: 0.96),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: (hasAffinity
                                            ? categoryColor
                                            : AppTheme.copper)
                                        .withValues(alpha: 0.22),
                                    blurRadius: hasAffinity ? 16 : 12,
                                  ),
                                ],
                              ),
                              child: Text(
                                hasAffinity
                                    ? '+$displayXp XP ⚡'
                                    : '+${widget.xpReward} XP',
                                style: AppTheme.uiFont(
                                  size: 11,
                                  weight: FontWeight.w800,
                                  color: _localCompleted
                                      ? AppTheme.text400
                                      : AppTheme.bg900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Expanded section ──
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _expanded
                      ? _buildExpandedSection(categoryColor)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedSection(Color categoryColor) {
    final hasDescription =
        widget.description != null && widget.description!.trim().isNotEmpty;
    final hasSteps = widget.steps != null && widget.steps!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: categoryColor.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full description
          if (hasDescription) ...[
            Text(
              widget.description!,
              style: AppTheme.uiFont(
                size: 12.5,
                weight: FontWeight.w500,
                color: _localCompleted ? AppTheme.text600 : AppTheme.text400,
              ).copyWith(height: 1.55),
            ),
          ],

          // Steps checklist
          if (hasSteps) ...[
            if (hasDescription) const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.checklist_rounded,
                    size: 13, color: categoryColor.withValues(alpha: 0.8)),
                const SizedBox(width: 6),
                Text(
                  'STEPS',
                  style: AppTheme.monoFont(
                    size: 10,
                    color: categoryColor.withValues(alpha: 0.8),
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(widget.steps!.length, (i) {
              final done = _stepChecked[i];
              return GestureDetector(
                onTap: () => setState(() => _stepChecked[i] = !done),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.only(top: 1),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: done
                              ? categoryColor
                              : categoryColor.withValues(alpha: 0.08),
                          border: Border.all(
                            color: done
                                ? categoryColor
                                : categoryColor.withValues(alpha: 0.4),
                            width: 1.2,
                          ),
                        ),
                        child: done
                            ? const Icon(Icons.check_rounded,
                                size: 12, color: Colors.black)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.steps![i],
                          style: AppTheme.uiFont(
                            size: 12,
                            weight: FontWeight.w500,
                            color: done ? AppTheme.text600 : AppTheme.text400,
                          ).copyWith(
                            decoration:
                                done ? TextDecoration.lineThrough : null,
                            decorationColor: AppTheme.text600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            // Progress bar if steps exist
            const SizedBox(height: 4),
            _buildStepProgress(categoryColor),
          ],
        ],
      ),
    );
  }

  Widget _buildStepProgress(Color color) {
    final total = _stepChecked.length;
    final done = _stepChecked.where((b) => b).length;
    final ratio = total == 0 ? 0.0 : done / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$done / $total steps',
              style: AppTheme.monoFont(size: 10, color: AppTheme.text600),
            ),
            Text(
              '${(ratio * 100).round()}%',
              style: AppTheme.monoFont(
                  size: 10,
                  color: ratio == 1.0 ? color : AppTheme.text600),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              minHeight: 3,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'health':
        return AppTheme.danger;
      case 'knowledge':
        return AppTheme.xpBlue;
      case 'discipline':
        return AppTheme.copper;
      case 'social':
        return AppTheme.mana;
      case 'focus':
        return const Color(0xFF9B6DFF); // violet/purple
      default:
        return AppTheme.text200;
    }
  }

  String _categoryLabel(String category) {
    if (category.isEmpty) return 'General';
    return '${category[0].toUpperCase()}${category.substring(1).toLowerCase()}';
  }
}

// ── Full preview bottom sheet ─────────────────────────────────────────────────

class _QuestPreviewSheet extends StatefulWidget {
  final String title;
  final String? description;
  final String category;
  final Color categoryColor;
  final String xpReward;
  final List<String>? steps;
  final List<bool> stepChecked;
  final void Function(int, bool) onStepToggled;

  const _QuestPreviewSheet({
    required this.title,
    required this.description,
    required this.category,
    required this.categoryColor,
    required this.xpReward,
    required this.steps,
    required this.stepChecked,
    required this.onStepToggled,
  });

  @override
  State<_QuestPreviewSheet> createState() => _QuestPreviewSheetState();
}

class _QuestPreviewSheetState extends State<_QuestPreviewSheet> {
  late List<bool> _checked;

  @override
  void initState() {
    super.initState();
    _checked = List<bool>.from(widget.stepChecked);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.categoryColor;
    final hasDesc =
        widget.description != null && widget.description!.trim().isNotEmpty;
    final hasSteps = widget.steps != null && widget.steps!.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: AppTheme.bg800,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 16),
                width: 38,
                height: 3,
                decoration: BoxDecoration(
                  color: AppTheme.bg600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: color.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                  color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              widget.category.toUpperCase(),
                              style: AppTheme.monoFont(
                                  size: 10,
                                  color: color,
                                  letterSpacing: 1.5),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.copper.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '+${widget.xpReward} XP',
                          style: AppTheme.uiFont(
                            size: 12,
                            weight: FontWeight.w800,
                            color: AppTheme.bg900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.title,
                    style: AppTheme.uiFont(
                      size: 18,
                      weight: FontWeight.w700,
                      color: AppTheme.text100,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(color: color.withValues(alpha: 0.15), height: 1),
            // Scrollable body
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  if (hasDesc) ...[
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 13, color: color.withValues(alpha: 0.7)),
                        const SizedBox(width: 6),
                        Text(
                          'WHY THIS MATTERS',
                          style: AppTheme.monoFont(
                              size: 10,
                              color: color.withValues(alpha: 0.7),
                              letterSpacing: 2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.description!,
                      style: AppTheme.uiFont(
                        size: 13.5,
                        weight: FontWeight.w500,
                        color: AppTheme.text400,
                      ).copyWith(height: 1.6),
                    ),
                  ],
                  if (hasSteps) ...[
                    if (hasDesc) const SizedBox(height: 24),
                    Row(
                      children: [
                        Icon(Icons.checklist_rounded,
                            size: 13, color: color.withValues(alpha: 0.8)),
                        const SizedBox(width: 6),
                        Text(
                          'STEPS',
                          style: AppTheme.monoFont(
                              size: 10,
                              color: color.withValues(alpha: 0.8),
                              letterSpacing: 2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(widget.steps!.length, (i) {
                      final done = _checked[i];
                      return GestureDetector(
                        onTap: () {
                          setState(() => _checked[i] = !done);
                          widget.onStepToggled(i, !done);
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 20,
                                height: 20,
                                margin: const EdgeInsets.only(top: 1),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  color: done
                                      ? color
                                      : color.withValues(alpha: 0.08),
                                  border: Border.all(
                                    color: done
                                        ? color
                                        : color.withValues(alpha: 0.4),
                                    width: 1.2,
                                  ),
                                ),
                                child: done
                                    ? const Icon(Icons.check_rounded,
                                        size: 13, color: Colors.black)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  widget.steps![i],
                                  style: AppTheme.uiFont(
                                    size: 13,
                                    weight: FontWeight.w500,
                                    color: done
                                        ? AppTheme.text600
                                        : AppTheme.text200,
                                  ).copyWith(
                                    decoration: done
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: AppTheme.text600,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 6),
                    // Progress
                    Builder(builder: (_) {
                      final done = _checked.where((b) => b).length;
                      final total = _checked.length;
                      final ratio = total == 0 ? 0.0 : done / total;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('$done / $total steps',
                                  style: AppTheme.monoFont(
                                      size: 10, color: AppTheme.text600)),
                              Text('${(ratio * 100).round()}%',
                                  style: AppTheme.monoFont(
                                      size: 10,
                                      color: ratio == 1.0
                                          ? color
                                          : AppTheme.text600)),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: ratio),
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOut,
                              builder: (_, v, __) => LinearProgressIndicator(
                                value: v,
                                minHeight: 4,
                                backgroundColor:
                                    color.withValues(alpha: 0.12),
                                valueColor: AlwaysStoppedAnimation(color),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
