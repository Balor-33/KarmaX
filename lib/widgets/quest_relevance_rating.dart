import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/hci_study_service.dart';
class QuestRelevanceRating extends StatefulWidget {
  const QuestRelevanceRating({super.key});

  @override
  State<QuestRelevanceRating> createState() => _QuestRelevanceRatingState();
}

class _QuestRelevanceRatingState extends State<QuestRelevanceRating> {
  int? _rating;
  bool _saved = false;

  Future<void> _rate(int value) async {
    setState(() {
      _rating = value;
      _saved = false;
    });
    try {
      await HciStudyService().submitQuestRating(value);
      if (mounted) setState(() => _saved = true);
    } catch (_) {
      // Non-fatal — never block the product flow on study logging.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderDim),
        color: AppTheme.bg800,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Do these quests match your real life?',
            style: AppTheme.monoFont(size: 11, color: AppTheme.text100),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (i) {
              final value = i + 1;
              final isSelected = _rating == value;
              return GestureDetector(
                onTap: () => _rate(value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppTheme.copper : Colors.transparent,
                    border: Border.all(
                      color:
                          isSelected ? AppTheme.copper : AppTheme.borderBright,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$value',
                      style: AppTheme.monoFont(
                        size: 13,
                        color: isSelected ? AppTheme.bg900 : AppTheme.text400,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          if (_rating != null) ...[
            const SizedBox(height: 8),
            Text(
              _saved ? '✓ SAVED' : 'SAVING...',
              style: AppTheme.monoFont(
                size: 9,
                color: _saved ? AppTheme.mana : AppTheme.text600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
