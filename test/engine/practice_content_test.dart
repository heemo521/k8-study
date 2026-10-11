import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k8_study/content/content_loader.dart';
import 'package:k8_study/engine/practice.dart';
import 'package:k8_study/engine/quiz.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('practice tests draw the configured count from their pool', () async {
    final content = (await ContentLoader(rootBundle).load()).subjects.first;
    for (final test in content.practiceTests) {
      final drawn = drawPractice(test: test, content: content, random: Random(7));
      final ids = drawn.map((p) => p.question.id).toSet();
      expect(drawn.length, test.questionCount, reason: test.id);
      expect(ids.length, drawn.length, reason: '${test.id}: no duplicates');
      final pool = practicePool(test, content).map((q) => q.id).toSet();
      expect(pool.containsAll(ids), isTrue, reason: test.id);
    }
  });

  test('domain breakdown groups by primary domain', () async {
    final content = (await ContentLoader(rootBundle).load()).subjects.first;
    final test = content.practiceTest('mixed')!;
    final attempt = QuizAttempt(
        drawPractice(test: test, content: content, random: Random(2)));
    for (final p in attempt.questions) {
      attempt.answer(p.question.id, p.question.correctIds);
    }
    final breakdown = domainBreakdown(attempt, content);
    expect(breakdown.values.fold<int>(0, (a, s) => a + s.total),
        test.questionCount);
    expect(breakdown.values.every((s) => s.correct == s.total), isTrue);
  });
}
