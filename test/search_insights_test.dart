import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k8_study/content/content_loader.dart';
import 'package:k8_study/content/models.dart';
import 'package:k8_study/content/search.dart';
import 'package:k8_study/engine/quiz.dart';
import 'package:k8_study/progress/insights.dart';
import 'package:k8_study/progress/progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentBundle content;

  setUpAll(() async {
    content = (await ContentLoader(rootBundle).load()).subjects.first;
  });

  Future<ProgressStore> fresh() async {
    SharedPreferences.setMockInitialValues({});
    return ProgressStore(await SharedPreferences.getInstance());
  }

  test('search ranks topic titles first and requires every term', () {
    final hits = search(content, 'namespaces');
    expect(hits.first.kind, SearchKind.topic);
    expect(hits.first.topic.id, 'namespaces');
    expect(search(content, 'kube-node-lease heartbeats'), isNotEmpty);
    expect(search(content, 'zzqx-nothing'), isEmpty);
    expect(search(content, 'a'), isEmpty, reason: 'single letters ignored');
  });

  test('snippet centres on the match', () {
    final s = snippetAround('${'x' * 300} etcd snapshot ${'y' * 300}', 'etcd');
    expect(s, contains('etcd snapshot'));
    expect(s.startsWith('…'), isTrue);
  });

  test(
    'nextAction: start, resume, then move forward past completed topics',
    () async {
      final p = await fresh();
      expect(nextAction(content, p)!.topic, content.topics.first);
      expect(nextAction(content, p)!.step, TopicStep.notes);

      final t = content.topics[4];
      p.markTopicVisited(content.subject.id, t.id);
      expect(nextAction(content, p)!.topic, t);
      expect(nextAction(content, p)!.resuming, isTrue);

      // Complete it: the next suggestion is the following topic, not topic 1.
      for (final s in t.sections) {
        p.markSectionRead(t.id, s.id);
      }
      p.recordQuiz(t.id, 100, {});
      expect(nextAction(content, p)!.topic, content.topics[5]);
    },
  );

  test('competency gaps: answered-wrong competency ranks first', () async {
    final p = await fresh();
    final q = content.allQuestions.firstWhere((q) => q.competencyId != null);
    p.recordAnswers(
      QuizAttempt([PresentedQuestion(q, q.options)])
        ..answer(q.id, {q.options.firstWhere((o) => !o.correct).id}),
    );
    final gaps = competencyGaps(content, p);
    expect(gaps.first.competency.id, q.competencyId);
    expect(gaps.first.accuracy, 0);
    expect(gaps.first.isGap, isTrue);
    expect(missedQuestions(content, p).single.id, q.id);
    expect(
      reviewPool(content, p, kind: 'competency', id: q.competencyId),
      contains(q),
    );
  });

  test('skipped questions are not recorded as evidence', () async {
    final p = await fresh();
    final q = content.allQuestions.first;
    p.recordAnswers(QuizAttempt([PresentedQuestion(q, q.options)]));
    expect(p.answerStats(q.id), isNull);
    expect(missedQuestions(content, p), isEmpty);
  });

  test('domain readiness covers every domain with topics', () async {
    final p = await fresh();
    final r = domainReadiness(content, p).where((r) => r.hasContent);
    expect(
      r.length,
      content.domains.length,
      reason: 'all five CKA domains plus foundations have topics',
    );
    expect(r.every((d) => d.accuracy == null), isTrue);
  });
}
