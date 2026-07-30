import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karmax/main.dart';
import 'package:karmax/theme/app_theme.dart';
import 'package:karmax/widgets/quest_card.dart';
import 'package:karmax/widgets/xp_bar.dart';

void main() {
  testWidgets('App builds and shows splash screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const KarmaXApp());
    // Allow the splash boot sequence timers to complete and navigate.
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('QuestCard renders title and XP reward',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: const Scaffold(
          body: QuestCard(
            title: 'Wake up 30 mins early',
            xpReward: '10',
            category: 'discipline',
            index: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Wake up 30 mins early'), findsOneWidget);
    expect(find.text('+10 XP'), findsOneWidget);
    expect(find.text('DISCIPLINE'), findsOneWidget);
  });

  testWidgets('QuestCard marks complete on tap', (WidgetTester tester) async {
    bool completed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: QuestCard(
            title: 'Test quest',
            xpReward: '15',
            category: 'health',
            index: 0,
            onComplete: () => completed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(QuestCard));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
  });

  testWidgets('XpBar renders label and value', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: const Scaffold(
          body: XpBar(
            current: 340,
            max: 500,
            label: 'KARMA XP',
            animate: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('KARMA XP'), findsOneWidget);
    expect(find.text('340 / 500'), findsOneWidget);
  });

  testWidgets('AppTheme copper color is correct', (WidgetTester tester) async {
    expect(AppTheme.copper, const Color(0xFFFFC857));
  });

  testWidgets('AppTheme bg900 scaffold color is correct',
      (WidgetTester tester) async {
    expect(AppTheme.bg900, const Color(0xFF070818));
  });
}
