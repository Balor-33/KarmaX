import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glitch_text.dart';
import '../widgets/scanline_overlay.dart';

class StoryFeedWidget extends StatefulWidget {
  const StoryFeedWidget({super.key});

  @override
  State<StoryFeedWidget> createState() => _StoryFeedWidgetState();
}

class _StoryFeedWidgetState extends State<StoryFeedWidget> {
  final List<Map<String, dynamic>> _feedItems = [
    {
      'type': 'ai_feedback',
      'time': '2 hrs ago',
      'text':
          'You stayed consistent for 4 days straight. Your Discipline stat has increased. The system is adapting your quest difficulty upward.',
      'stat': '+5 DISCIPLINE',
    },
    {
      'type': 'level_up',
      'time': 'Yesterday',
      'text':
          'LEVEL 7 REACHED. New daily quest slots unlocked. Weekly missions updated.',
      'stat': 'LVL 7',
    },
    {
      'type': 'ai_feedback',
      'time': '2 days ago',
      'text':
          'Morning sessions are improving your consistency. The KarmaX engine has detected a pattern — keep this routine for 3 more days to unlock a bonus mission.',
      'stat': '+8 HEALTH',
    },
    {
      'type': 'warning',
      'time': '3 days ago',
      'text':
          'Skipping tasks slows your progression. You missed 2 quests yesterday. Discipline stat temporarily frozen.',
      'stat': '! WARNING',
    },
    {
      'type': 'ai_feedback',
      'time': '4 days ago',
      'text':
          'You completed your first weekly mission. Your profile has been flagged as high-potential in the KarmaX matrix.',
      'stat': '+40 XP',
    },
  ];

  bool _isGenerating = false;
  Timer? _typeTimer;
  String _typedText = '';
  final String _newFeedback =
      'Your sleep pattern has improved over 3 days. The KarmaX engine recommends increasing workout intensity to advance your Health stat faster.';

  @override
  void dispose() {
    _typeTimer?.cancel();
    super.dispose();
  }

  void _generateFeedback() {
    setState(() {
      _isGenerating = true;
      _typedText = '';
    });

    int i = 0;
    _typeTimer = Timer.periodic(const Duration(milliseconds: 28), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (i < _newFeedback.length) {
        setState(() {
          _typedText += _newFeedback[i];
          i++;
        });
      } else {
        t.cancel();
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          setState(() {
            _isGenerating = false;
            _feedItems.insert(0, {
              'type': 'ai_feedback',
              'time': 'Just now',
              'text': _newFeedback,
              'stat': '+6 HEALTH',
            });
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: GestureDetector(
            onTap: _isGenerating ? null : _generateFeedback,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _isGenerating ? AppTheme.bg700 : AppTheme.text100,
                border: Border.all(
                  color: _isGenerating ? AppTheme.borderDim : AppTheme.copper,
                ),
              ),
              child: Center(
                child: Text(
                  _isGenerating ? 'GENERATING...' : '+ GENERATE AI FEEDBACK',
                  style: AppTheme.displayFont(
                    size: 11,
                    color: _isGenerating ? AppTheme.text400 : AppTheme.bg900,
                  ),
                ),
              ),
            ),
          ),
        ),

        if (_isGenerating && _typedText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bg800,
                border: Border.all(color: AppTheme.borderBright),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '> ',
                    style: AppTheme.monoFont(size: 12, color: AppTheme.text400),
                  ),
                  Expanded(
                    child: Text(
                      _typedText,
                      style: AppTheme.monoFont(size: 12, color: AppTheme.text100),
                    ),
                  ),
                  Container(width: 2, height: 14, color: AppTheme.text100),
                ],
              ),
            ),
          ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
            itemCount: _feedItems.length,
            itemBuilder: (_, i) => _FeedCard(item: _feedItems[i], index: i),
          ),
        ),
      ],
    );
  }
}

class _FeedCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final int index;
  const _FeedCard({required this.item, required this.index});

  @override
  State<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<_FeedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: 80 * widget.index), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.item['type'] as String;
    final isWarning = type == 'warning';
    final isLevelUp = type == 'level_up';

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isWarning
                ? AppTheme.bg900
                : isLevelUp
                ? AppTheme.bg700
                : AppTheme.bg800,
            border: Border.all(
              color: isLevelUp
                  ? AppTheme.text100
                  : isWarning
                  ? AppTheme.bg600
                  : AppTheme.borderDim,
              width: isLevelUp ? 1.5 : 1,
            ),
            boxShadow: isLevelUp
                ? [
                    BoxShadow(
                      color: AppTheme.text100.withValues(alpha: 0.08),
                      blurRadius: 20,
                    ),
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isLevelUp
                        ? '// SYSTEM EVENT'
                        : isWarning
                        ? '// SYSTEM WARNING'
                        : '// AI FEEDBACK',
                    style: AppTheme.monoFont(
                      size: 9,
                      color: isWarning ? AppTheme.text400 : AppTheme.text200,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    widget.item['time'] as String,
                    style: AppTheme.monoFont(size: 9, color: AppTheme.text400),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.item['text'] as String,
                style: AppTheme.monoFont(
                  size: 12,
                  color: isWarning ? AppTheme.text200 : AppTheme.text100,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isWarning ? AppTheme.bg600 : AppTheme.text100,
                  ),
                ),
                child: Text(
                  widget.item['stat'] as String,
                  style: AppTheme.displayFont(
                    size: 10,
                    color: isWarning ? AppTheme.text400 : AppTheme.text100,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StoryFeedScreen extends StatelessWidget {
  const StoryFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.bg900,
      body: ScanlineOverlay(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: GlitchText(
                  text: 'STORY FEED',
                  fontSize: 22,
                  useDisplay: true,
                ),
              ),
              Expanded(child: StoryFeedWidget()),
            ],
          ),
        ),
      ),
    );
  }
}