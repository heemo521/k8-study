/// Local progress persistence (spec §6). One key per concern, JSON values.
/// Corrupt data in a key resets that key; it never stops the app starting.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ads/frequency_cap.dart';
import '../content/models.dart';
import '../engine/clock.dart';
import '../engine/flashcards.dart';
import '../engine/practice.dart';
import '../engine/question_review.dart';
import '../engine/quiz.dart';
import 'rewards.dart';

const schemaVersion = 1;
const maxPracticeHistory = 50;

abstract final class StorageKeys {
  static const schema = 'k8s.schema';
  static const notes = 'k8s.notes';
  static const cards = 'k8s.cards';
  static const quiz = 'k8s.quiz';
  static const practice = 'k8s.practice';
  static const ads = 'k8s.ads';
  static const settings = 'k8s.settings';
  static const answers = 'k8s.answers';
  static const recent = 'k8s.recent';
  static const activity = 'k8s.activity';
  static const plans = 'k8s.plans';
  static const labs = 'k8s.labs';
  static const rewards = 'k8s.rewards';
}

/// One competency an exam showed as weak, with the exam's result for it.
class GapItem {
  const GapItem({
    required this.competencyId,
    required this.examCorrect,
    required this.examTotal,
  });

  final String competencyId;
  final int examCorrect;
  final int examTotal;

  Map<String, dynamic> toJson() => {
    'c': competencyId,
    'ok': examCorrect,
    'n': examTotal,
  };

  factory GapItem.fromJson(Map<String, dynamic> j) => GapItem(
    competencyId: j['c'] as String,
    examCorrect: j['ok'] as int,
    examTotal: j['n'] as int,
  );
}

/// A study plan built from an exam result: the competencies to fix. Step
/// completion and "fixed" are derived from other progress, not stored.
class GapPlan {
  const GapPlan({
    required this.testId,
    required this.createdAt,
    required this.items,
  });

  final String testId;
  final DateTime createdAt;
  final List<GapItem> items;

  Map<String, dynamic> toJson() => {
    'test': testId,
    'at': createdAt.toIso8601String(),
    'items': [for (final i in items) i.toJson()],
  };

  factory GapPlan.fromJson(Map<String, dynamic> j) => GapPlan(
    testId: j['test'] as String,
    createdAt: DateTime.parse(j['at'] as String),
    items: [
      for (final i in j['items'] as List<dynamic>)
        GapItem.fromJson(i as Map<String, dynamic>),
    ],
  );
}

/// Answer history for one question across quizzes, reviews and tests,
/// plus its place in the question review schedule (spec §15.1–14.2).
class AnswerStats {
  const AnswerStats({
    required this.seen,
    required this.correct,
    required this.lastCorrect,
    required this.lastAt,
    this.lastSure = true,
    this.review,
  });

  final int seen;
  final int correct;
  final bool lastCorrect;
  final DateTime lastAt;

  /// Whether the latest answer was given with "Sure".
  final bool lastSure;

  /// Review schedule; null when the question isn't scheduled.
  final ReviewSlot? review;

  /// Right and sure: the only answer that counts as known.
  bool get solid => lastCorrect && lastSure;

  bool isDue(DateTime now) => review?.isDue(now) ?? false;

  Map<String, dynamic> toJson() => {
    'n': seen,
    'c': correct,
    'last': lastCorrect,
    'at': lastAt.toIso8601String(),
    if (!lastSure) 'sure': false,
    if (review != null) ...{
      'box': review!.box,
      'due': formatDate(review!.dueAt),
    },
  };

  static AnswerStats fromJson(Map<String, dynamic> j) {
    final lastCorrect = j['last'] as bool;
    final lastAt = DateTime.parse(j['at'] as String);
    final box = j['box'] as int?;
    final due = j['due'] as String?;
    if (box != null && (box < 1 || box > maxBox)) {
      throw FormatException('bad box: $box');
    }
    return AnswerStats(
      seen: j['n'] as int,
      correct: j['c'] as int,
      lastCorrect: lastCorrect,
      lastAt: lastAt,
      lastSure: j['sure'] as bool? ?? true,
      review: box != null && due != null
          ? ReviewSlot(box: box, dueAt: dateOnly(DateTime.parse(due)))
          // Saved before the schedule existed: a wrong answer is due now.
          : lastCorrect
          ? null
          : ReviewSlot(box: 1, dueAt: dateOnly(lastAt)),
    );
  }
}

class QuizStats {
  const QuizStats({
    required this.attempts,
    required this.bestPct,
    required this.lastPct,
    required this.lastAt,
    required this.missed,
  });

  final int attempts;
  final int bestPct;
  final int lastPct;
  final DateTime lastAt;

  /// Questions missed in the most recent run, prioritised in the next draw.
  final List<String> missed;

  Map<String, dynamic> toJson() => {
    'attempts': attempts,
    'bestPct': bestPct,
    'lastPct': lastPct,
    'lastAt': lastAt.toIso8601String(),
    'missed': missed,
  };

  static QuizStats fromJson(Map<String, dynamic> j) => QuizStats(
    attempts: j['attempts'] as int,
    bestPct: j['bestPct'] as int,
    lastPct: j['lastPct'] as int,
    lastAt: DateTime.parse(j['lastAt'] as String),
    missed: [for (final m in (j['missed'] as List? ?? const [])) m as String],
  );
}

class PracticeRecord {
  const PracticeRecord({
    required this.testId,
    required this.pct,
    required this.perDomain,
    required this.durationSec,
    required this.at,
  });

  final String testId;
  final int pct;
  final Map<String, DomainScore> perDomain;
  final int durationSec;
  final DateTime at;

  Map<String, dynamic> toJson() => {
    'testId': testId,
    'pct': pct,
    'perDomain': {for (final e in perDomain.entries) e.key: e.value.toJson()},
    'durationSec': durationSec,
    'at': at.toIso8601String(),
  };

  static PracticeRecord fromJson(Map<String, dynamic> j) => PracticeRecord(
    testId: j['testId'] as String,
    pct: j['pct'] as int,
    perDomain: {
      for (final e in (j['perDomain'] as Map<String, dynamic>).entries)
        e.key: DomainScore(
          (e.value as Map<String, dynamic>)['correct'] as int,
          (e.value as Map<String, dynamic>)['total'] as int,
        ),
    },
    durationSec: j['durationSec'] as int,
    at: DateTime.parse(j['at'] as String),
  );
}

class ProgressStore extends ChangeNotifier implements AdCapStore {
  ProgressStore(this._prefs, {this.clock = const SystemClock()}) {
    _load();
  }

  final SharedPreferences _prefs;
  final Clock clock;

  Map<String, Set<String>> _notes = {};
  Map<String, CardState> _cards = {};
  Map<String, QuizStats> _quiz = {};
  List<PracticeRecord> _practice = [];
  AdCapState _ads = AdCapState.initial;
  bool _practiceTimerOn = true;
  String? _subjectId;
  bool _introDismissed = false;
  Map<String, AnswerStats> _answers = {};
  Map<String, String> _recent = {};

  /// Per-day counts: {'yyyy-mm-dd': {'sections': n, 'cards': n, 'quizzes': n}}.
  Map<String, Map<String, int>> _activity = {};
  Map<String, GapPlan> _plans = {};
  RewardsState _rewards = RewardsState.initial;

  /// Completed runs per lab id (spec §15.8).
  Map<String, int> _labs = {};

  // ---- loading -------------------------------------------------------------

  T _read<T>(String key, T fallback, T Function(dynamic json) parse) {
    final raw = _prefs.getString(key);
    if (raw == null) return fallback;
    try {
      return parse(jsonDecode(raw));
    } catch (e) {
      debugPrint('ProgressStore: resetting corrupt "$key": $e');
      _prefs.remove(key);
      return fallback;
    }
  }

  // Parsers for each stored key. Shared by loading and backup validation;
  // they throw on any malformed value.
  static Map<String, Set<String>> _parseNotes(dynamic j) => {
    for (final e in (j as Map<String, dynamic>).entries)
      e.key: {for (final s in e.value as List) s as String},
  };
  static Map<String, CardState> _parseCards(dynamic j) => {
    for (final e in (j as Map<String, dynamic>).entries)
      e.key: CardState.fromJson(e.value as Map<String, dynamic>),
  };
  static Map<String, QuizStats> _parseQuiz(dynamic j) => {
    for (final e in (j as Map<String, dynamic>).entries)
      e.key: QuizStats.fromJson(e.value as Map<String, dynamic>),
  };
  static List<PracticeRecord> _parsePractice(dynamic j) => [
    for (final r in j as List)
      PracticeRecord.fromJson(r as Map<String, dynamic>),
  ];
  static AdCapState _parseAds(dynamic j) =>
      AdCapState.fromJson(j as Map<String, dynamic>);
  static Map<String, dynamic> _parseSettings(dynamic j) {
    final m = j as Map<String, dynamic>;
    m['practiceTimerOn'] as bool?;
    m['subjectId'] as String?;
    return m;
  }

  static Map<String, AnswerStats> _parseAnswers(dynamic j) => {
    for (final e in (j as Map<String, dynamic>).entries)
      e.key: AnswerStats.fromJson(e.value as Map<String, dynamic>),
  };
  static Map<String, String> _parseRecent(dynamic j) => {
    for (final e in (j as Map<String, dynamic>).entries)
      e.key: e.value as String,
  };

  static Map<String, Map<String, int>> _parseActivity(dynamic j) => {
    for (final e in (j as Map<String, dynamic>).entries)
      e.key: {
        for (final c in (e.value as Map<String, dynamic>).entries)
          c.key: c.value as int,
      },
  };

  static Map<String, GapPlan> _parsePlans(dynamic j) => {
    for (final e in (j as Map<String, dynamic>).entries)
      e.key: GapPlan.fromJson(e.value as Map<String, dynamic>),
  };

  static Map<String, int> _parseLabs(dynamic j) => {
    for (final e in (j as Map<String, dynamic>).entries) e.key: e.value as int,
  };

  static RewardsState _parseRewards(dynamic j) =>
      RewardsState.fromJson(j as Map<String, dynamic>);

  static final Map<String, Object Function(dynamic)> _parsers = {
    StorageKeys.labs: _parseLabs,
    StorageKeys.rewards: _parseRewards,
    StorageKeys.plans: _parsePlans,
    StorageKeys.activity: _parseActivity,
    StorageKeys.notes: _parseNotes,
    StorageKeys.cards: _parseCards,
    StorageKeys.quiz: _parseQuiz,
    StorageKeys.practice: _parsePractice,
    StorageKeys.ads: _parseAds,
    StorageKeys.settings: _parseSettings,
    StorageKeys.answers: _parseAnswers,
    StorageKeys.recent: _parseRecent,
  };

  void _load() {
    final stored = _prefs.getInt(StorageKeys.schema);
    if (stored != schemaVersion) _migrate(stored);

    _notes = _read(StorageKeys.notes, {}, _parseNotes);
    _cards = _read(StorageKeys.cards, {}, _parseCards);
    _quiz = _read(StorageKeys.quiz, {}, _parseQuiz);
    _practice = _read(StorageKeys.practice, [], _parsePractice);
    _ads = _read(StorageKeys.ads, AdCapState.initial, _parseAds);
    final settings = _read<Map<String, dynamic>>(
      StorageKeys.settings,
      const {},
      _parseSettings,
    );
    _practiceTimerOn = settings['practiceTimerOn'] as bool? ?? true;
    _subjectId = settings['subjectId'] as String?;
    _introDismissed = settings['introDismissed'] as bool? ?? false;
    _answers = _read(StorageKeys.answers, {}, _parseAnswers);
    _recent = _read(StorageKeys.recent, {}, _parseRecent);
    _activity = _read(StorageKeys.activity, {}, _parseActivity);
    _plans = _read(StorageKeys.plans, {}, _parsePlans);
    _labs = _read(StorageKeys.labs, {}, _parseLabs);
    final rewards = _read<RewardsState?>(
      StorageKeys.rewards,
      null,
      _parseRewards,
    );
    if (rewards != null) {
      _rewards = rewards;
    } else {
      _rewards = _seedRewards();
      _write(StorageKeys.rewards, _rewards.toJson());
    }
  }

  /// Rewards for progress made before XP existed (or restored from a backup
  /// without them): XP for what's already done, and the streak from the
  /// daily activity log.
  RewardsState _seedRewards() {
    var xp = 0;
    for (final s in _notes.values) {
      xp += s.length * Xp.sectionRead;
    }
    xp += _cards.length * Xp.cardReviewed;
    for (final a in _answers.values) {
      xp +=
          a.correct * Xp.correctAnswer + (a.seen - a.correct) * Xp.wrongAnswer;
    }
    xp +=
        _quiz.values.where((q) => q.bestPct >= masteryPercent).length *
        Xp.quizMastered;

    final days = _activity.keys.toList()..sort();
    if (days.isEmpty) return RewardsState(xp: xp);
    var day = DateTime.parse(days.last);
    var streak = 0;
    while (_activity.containsKey(formatDate(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return RewardsState(
      xp: xp,
      streak: streak,
      streakDay: days.last,
      bestStreak: streak,
    );
  }

  // ---- labs ----------------------------------------------------------------

  /// How many times the lab [labId] has been completed.
  int labRuns(String labId) => _labs[labId] ?? 0;

  void recordLabRun(String labId) {
    _labs[labId] = labRuns(labId) + 1;
    _bump('labs');
    _write(StorageKeys.labs, _labs);
    notifyListeners();
  }

  // ---- gap plans -----------------------------------------------------------

  /// The current gap plan for [subjectId], if any.
  GapPlan? gapPlan(String subjectId) => _plans[subjectId];

  void setGapPlan(String subjectId, GapPlan plan) {
    _plans[subjectId] = plan;
    _savePlans();
  }

  void clearGapPlan(String subjectId) {
    if (_plans.remove(subjectId) != null) _savePlans();
  }

  void _savePlans() {
    _write(StorageKeys.plans, {
      for (final e in _plans.entries) e.key: e.value.toJson(),
    });
    notifyListeners();
  }

  /// Schema migrations. v1 is the first schema, so an unknown or missing
  /// version just gets stamped; future versions transform data here.
  void _migrate(int? from) {
    _prefs.setInt(StorageKeys.schema, schemaVersion);
  }

  void _write(String key, Object json) =>
      _prefs.setString(key, jsonEncode(json));

  // ---- notes ---------------------------------------------------------------

  Set<String> readSections(String topicId) => _notes[topicId] ?? const {};

  void markSectionRead(String topicId, String sectionId) {
    final set = _notes.putIfAbsent(topicId, () => {});
    if (!set.add(sectionId)) return;
    _bump('sections', xp: Xp.sectionRead);
    _write(StorageKeys.notes, {
      for (final e in _notes.entries) e.key: e.value.toList(),
    });
    notifyListeners();
  }

  /// Read count, ignoring ids that no longer exist in the content.
  int readCount(Topic topic) {
    final read = readSections(topic.id);
    return topic.sections.where((s) => read.contains(s.id)).length;
  }

  bool notesComplete(Topic topic) => readCount(topic) == topic.sections.length;

  // ---- flashcards ----------------------------------------------------------

  Map<String, CardState> get cardStates => Map.unmodifiable(_cards);

  CardState? cardState(String cardId) => _cards[cardId];

  void setCardState(String cardId, CardState state) {
    _bump('cards', xp: Xp.cardReviewed);
    _cards[cardId] = state;
    _write(StorageKeys.cards, {
      for (final e in _cards.entries) e.key: e.value.toJson(),
    });
    notifyListeners();
  }

  int masteredCount(Iterable<Flashcard> cards) =>
      cards.where((c) => _cards[c.id]?.mastered ?? false).length;

  // ---- quizzes -------------------------------------------------------------

  QuizStats? quizStats(String topicId) => _quiz[topicId];

  void _saveQuiz() => _write(StorageKeys.quiz, {
    for (final e in _quiz.entries) e.key: e.value.toJson(),
  });

  /// A full quiz attempt finished: counts toward attempts and best score.
  /// Returns the bonus XP earned (for mastering the topic the first time).
  int recordQuiz(String topicId, int pct, Set<String> missed) {
    final prev = _quiz[topicId];
    final firstMastery =
        pct >= masteryPercent && (prev?.bestPct ?? 0) < masteryPercent;
    _quiz[topicId] = QuizStats(
      attempts: (prev?.attempts ?? 0) + 1,
      bestPct: prev == null ? pct : (pct > prev.bestPct ? pct : prev.bestPct),
      lastPct: pct,
      lastAt: clock.now(),
      missed: missed.toList(),
    );
    _saveQuiz();
    final bonus = firstMastery ? Xp.quizMastered : 0;
    if (bonus > 0) _saveRewards(_rewards.addXp(bonus));
    notifyListeners();
    return bonus;
  }

  /// A "retry missed" run finished: only updates the missed set.
  void recordRetryMissed(String topicId, Set<String> stillMissed) {
    final prev = _quiz[topicId];
    if (prev == null) return;
    _quiz[topicId] = QuizStats(
      attempts: prev.attempts,
      bestPct: prev.bestPct,
      lastPct: prev.lastPct,
      lastAt: prev.lastAt,
      missed: stillMissed.toList(),
    );
    _saveQuiz();
    notifyListeners();
  }

  bool quizPassed(String topicId) =>
      (_quiz[topicId]?.bestPct ?? 0) >= masteryPercent;

  // ---- topic status --------------------------------------------------------

  /// Complete = all sections read and quiz best ≥ mastery threshold.
  bool topicComplete(Topic topic) =>
      notesComplete(topic) && quizPassed(topic.id);

  bool topicStarted(Topic topic) =>
      readCount(topic) > 0 ||
      _quiz.containsKey(topic.id) ||
      topic.flashcards.any((c) => _cards.containsKey(c.id));

  /// 0..1 progress used by rings: notes (50%) + quiz mastery (50%).
  double topicProgress(Topic topic) {
    final notes = topic.sections.isEmpty
        ? 1.0
        : readCount(topic) / topic.sections.length;
    final best = (_quiz[topic.id]?.bestPct ?? 0) / masteryPercent;
    return (notes * 0.5 + (best > 1 ? 1 : best) * 0.5).clamp(0, 1).toDouble();
  }

  DateTime? lastActivity(Topic topic) {
    DateTime? latest;
    void consider(DateTime? t) {
      if (t != null && (latest == null || t.isAfter(latest!))) latest = t;
    }

    consider(_quiz[topic.id]?.lastAt);
    for (final c in topic.flashcards) {
      consider(_cards[c.id]?.lastReviewedAt);
    }
    return latest;
  }

  // ---- practice ------------------------------------------------------------

  List<PracticeRecord> get practiceHistory => List.unmodifiable(_practice);

  /// Attempts at [testId], newest first.
  List<PracticeRecord> practiceAttempts(String testId) => [
    for (final r in _practice)
      if (r.testId == testId) r,
  ];

  int? bestPracticePct(String testId) {
    int? best;
    for (final r in _practice) {
      if (r.testId == testId && (best == null || r.pct > best)) best = r.pct;
    }
    return best;
  }

  void recordPractice(PracticeRecord record) {
    _practice = [record, ..._practice].take(maxPracticeHistory).toList();
    _write(StorageKeys.practice, [for (final r in _practice) r.toJson()]);
    notifyListeners();
  }

  // ---- ads frequency cap ---------------------------------------------------

  @override
  AdCapState get adCapState => _ads;

  @override
  set adCapState(AdCapState value) {
    _ads = value;
    _write(StorageKeys.ads, value.toJson());
  }

  // ---- answer history ------------------------------------------------------

  AnswerStats? answerStats(String questionId) => _answers[questionId];

  Map<String, AnswerStats> get answerHistory => Map.unmodifiable(_answers);

  /// Records the answered questions of a finished attempt. Skipped ones
  /// (a practice test finished early) are no evidence either way, so they
  /// don't count towards accuracy or gaps. Returns the XP earned.
  int recordAnswers(QuizAttempt attempt) {
    final now = clock.now();
    var xp = 0;
    for (final p in attempt.questions) {
      final id = p.question.id;
      if (!attempt.isAnswered(id)) continue;
      final ok = attempt.correct(p);
      final sure = attempt.isSure(id);
      xp += ok ? Xp.correctAnswer : Xp.wrongAnswer;
      final prev = _answers[id];
      _answers[id] = AnswerStats(
        seen: (prev?.seen ?? 0) + 1,
        correct: (prev?.correct ?? 0) + (ok ? 1 : 0),
        lastCorrect: ok,
        lastAt: now,
        lastSure: sure,
        review: nextSlot(prev?.review, correct: ok, sure: sure, now: now),
      );
    }
    _write(StorageKeys.answers, {
      for (final e in _answers.entries) e.key: e.value.toJson(),
    });
    _bump('quizzes', xp: xp);
    notifyListeners();
    return xp;
  }

  // ---- where the learner is ------------------------------------------------

  /// Most recently opened topic in [subjectId].
  String? recentTopic(String subjectId) => _recent[subjectId];

  void markTopicVisited(String subjectId, String topicId) {
    if (_recent[subjectId] == topicId) return;
    _recent[subjectId] = topicId;
    _write(StorageKeys.recent, _recent);
    // Called from initState; notify after the current build completes.
    Future.microtask(notifyListeners);
  }

  // ---- settings ------------------------------------------------------------

  void _saveSettings() => _write(StorageKeys.settings, {
    'practiceTimerOn': _practiceTimerOn,
    if (_subjectId != null) 'subjectId': _subjectId,
    if (_introDismissed) 'introDismissed': true,
  });

  bool get practiceTimerOn => _practiceTimerOn;

  set practiceTimerOn(bool value) {
    _practiceTimerOn = value;
    _saveSettings();
    notifyListeners();
  }

  /// Whether the first-run "how it works" card was dismissed.
  bool get introDismissed => _introDismissed;

  void dismissIntro() {
    _introDismissed = true;
    _saveSettings();
    notifyListeners();
  }

  /// Selected subject (null = first in catalog).
  String? get subjectId => _subjectId;

  set subjectId(String? value) {
    if (value == _subjectId) return;
    _subjectId = value;
    _saveSettings();
    notifyListeners();
  }

  // ---- daily activity ------------------------------------------------------

  static const _activityDays = 60;

  /// Logs a study action for today, keeps the streak going and awards [xp].
  void _bump(String kind, {int xp = 0}) {
    _saveRewards(_rewards.studiedOn(clock.now()).addXp(xp));
    final today = formatDate(clock.now());
    final day = _activity.putIfAbsent(today, () => {});
    day[kind] = (day[kind] ?? 0) + 1;
    if (_activity.length > _activityDays) {
      final keys = _activity.keys.toList()..sort();
      for (final k in keys.take(_activity.length - _activityDays)) {
        _activity.remove(k);
      }
    }
    _write(StorageKeys.activity, _activity);
  }

  /// Counts for today (sections, cards, quizzes).
  Map<String, int> get today => Map.unmodifiable(
    _activity[formatDate(clock.now())] ?? const <String, int>{},
  );

  // ---- rewards -------------------------------------------------------------

  void _saveRewards(RewardsState value) {
    _rewards = value;
    _write(StorageKeys.rewards, value.toJson());
  }

  /// Total XP earned.
  int get xp => _rewards.xp;

  LevelInfo get level => LevelInfo.fromXp(_rewards.xp);

  /// Consecutive days with any study activity, ending today — or yesterday,
  /// so the streak isn't shown as broken before today's first session.
  int get streak => _rewards.currentStreak(clock.now());

  /// Longest streak so far.
  int get bestStreak => _rewards.bestStreak;

  // ---- backup ----------------------------------------------------------------

  static const _backupKeys = [
    StorageKeys.notes,
    StorageKeys.cards,
    StorageKeys.quiz,
    StorageKeys.practice,
    StorageKeys.answers,
    StorageKeys.recent,
    StorageKeys.activity,
    StorageKeys.plans,
    StorageKeys.labs,
    StorageKeys.rewards,
    StorageKeys.settings,
  ];

  /// All progress as a JSON document (for copy/paste backup).
  String exportJson() => jsonEncode({
    'app': 'k8-study',
    'schema': schemaVersion,
    'exportedAt': clock.now().toIso8601String(),
    'data': {
      for (final k in _backupKeys)
        if (_prefs.getString(k) != null) k: jsonDecode(_prefs.getString(k)!),
    },
  });

  /// Replaces all progress with a backup from [exportJson]. Throws
  /// [FormatException] if it isn't a K8 Study backup; nothing changes then.
  Future<void> importJson(String text) async {
    final Object? doc;
    try {
      doc = jsonDecode(text);
    } on FormatException {
      throw const FormatException('Not valid JSON.');
    }
    if (doc is! Map<String, dynamic> ||
        doc['app'] != 'k8-study' ||
        doc['data'] is! Map<String, dynamic>) {
      throw const FormatException('This is not a K8 Study backup.');
    }
    final schema = doc['schema'];
    if (schema is! int?) {
      throw const FormatException('This is not a K8 Study backup.');
    }
    if ((schema ?? 0) > schemaVersion) {
      throw const FormatException('Backup is from a newer app version.');
    }
    final data = doc['data'] as Map<String, dynamic>;
    // Validate everything before touching stored progress.
    for (final k in _backupKeys) {
      if (data[k] == null) continue;
      try {
        _parsers[k]!(data[k]);
      } catch (_) {
        throw const FormatException(
          'The backup is damaged; nothing was changed.',
        );
      }
    }
    for (final k in _backupKeys) {
      await _prefs.remove(k);
      if (data[k] != null) await _prefs.setString(k, jsonEncode(data[k]));
    }
    _load();
    notifyListeners();
  }

  // ---- reset ---------------------------------------------------------------

  /// Clears all progress. Settings are kept.
  Future<void> resetProgress() async {
    for (final key in [
      StorageKeys.notes,
      StorageKeys.cards,
      StorageKeys.quiz,
      StorageKeys.practice,
      StorageKeys.ads,
      StorageKeys.answers,
      StorageKeys.recent,
      StorageKeys.activity,
      StorageKeys.plans,
      StorageKeys.labs,
      StorageKeys.rewards,
    ]) {
      await _prefs.remove(key);
    }
    _rewards = RewardsState.initial;
    _plans = {};
    _labs = {};
    _answers = {};
    _recent = {};
    _activity = {};
    _notes = {};
    _cards = {};
    _quiz = {};
    _practice = [];
    _ads = AdCapState.initial;
    notifyListeners();
  }
}
