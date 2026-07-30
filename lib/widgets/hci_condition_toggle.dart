import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/hci_mode.dart';
class HciConditionToggle extends StatefulWidget {
  const HciConditionToggle({super.key});

  @override
  State<HciConditionToggle> createState() => _HciConditionToggleState();
}

class _HciConditionToggleState extends State<HciConditionToggle> {
  void _handleTap() {
    final flipped = HciMode.instance.toggle();
    if (flipped) {
      setState(() {});
    } else {
      // Locked — briefly acknowledge the tap without changing anything.
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGestalt = HciMode.instance.useGestalt;
    final locked = HciMode.instance.sessionActive;

    final accent = locked
        ? AppTheme.text600
        : (isGestalt ? AppTheme.mana : AppTheme.text400);

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: locked
              ? AppTheme.bg800
              : (isGestalt
                  ? AppTheme.mana.withValues(alpha: 0.12)
                  : AppTheme.bg700),
          border: Border.all(
            color: locked
                ? AppTheme.borderDim
                : (isGestalt ? AppTheme.mana : AppTheme.borderDim),
            width: !locked && isGestalt ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (locked)
            const Icon(Icons.lock_outline, size: 10, color: AppTheme.text600)
          else
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isGestalt ? AppTheme.mana : AppTheme.text600,
              ),
            ),
          const SizedBox(width: 8),
          Text(
            isGestalt ? 'MODE B  ·  GESTALT ON' : 'MODE A  ·  BASELINE',
            style: AppTheme.monoFont(size: 9, color: accent, letterSpacing: 1),
          ),
          const SizedBox(width: 8),
          Text(
            locked ? 'LOCKED — IN SESSION' : 'TAP TO SWITCH',
            style: AppTheme.monoFont(
                size: 8, color: AppTheme.text600, letterSpacing: 1),
          ),
        ]),
      ),
    );
  }
}
