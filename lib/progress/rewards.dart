/// XP, levels and the daily streak (gamification). Pure rules; the
/// [ProgressStore] persists [RewardsState] and awards XP as you study.
library;

import '../engine/clock.dart';

/// XP for each study action.
abstract final class Xp {
  /// A note section read for the first time.
  static const sectionRead = 10;

  /// A flashcard reviewed (right or wrong).
  static const cardReviewed = 2;

  /// A question answered correctly in any quiz, review or practice test.
  static const correctAnswer = 5;

  /// A question answered wrongly: effort still counts a little.
  static const wrongAnswer = 1;

  /// A topic quiz reaching mastery for the first time.
  static const quizMastered = 50;
}

/// XP needed to go from [level] to the next one: 100, 200, 300…
int xpForLevel(int level) => 100 * level;

/// Where a total XP puts the learner: level (from 1), XP into that level,
/// and XP that level needs.
class LevelInfo {
  const LevelInfo(this.level, this.into, this.needed);

  final int level;
  final int into;
  final int needed;

  double get fraction => needed == 0 ? 0 : into / needed;

  factory LevelInfo.fromXp(int xp) {
    var level = 1;
    var rest = xp < 0 ? 0 : xp;
    while (rest >= xpForLevel(level)) {
      rest -= xpForLevel(level);
      level++;
    }
    return LevelInfo(level, rest, xpForLevel(level));
  }
}

/// Stored rewards: total XP and the streak as of its last study day.
/// The streak is kept here rather than derived from daily activity, which
/// only keeps 60 days.
class RewardsState {
  const RewardsState({
    this.xp = 0,
    this.streak = 0,
    this.streakDay,
    this.bestStreak = 0,
  });

  static const initial = RewardsState();

  final int xp;

  /// Consecutive study days ending on [streakDay].
  final int streak;

  /// Last day with study activity, as `yyyy-mm-dd`.
  final String? streakDay;
  final int bestStreak;

  /// The streak as seen on [now]: it holds through today and yesterday, so
  /// it isn't shown as broken before today's first session.
  int currentStreak(DateTime now) {
    final day = streakDay;
    if (day == null) return 0;
    final today = dateOnly(now);
    if (day == formatDate(today) ||
        day == formatDate(today.subtract(const Duration(days: 1)))) {
      return streak;
    }
    return 0;
  }

  /// State after studying on [now]: extends, keeps or restarts the streak.
  RewardsState studiedOn(DateTime now) {
    final today = dateOnly(now);
    final key = formatDate(today);
    if (streakDay == key) return this;
    final next = currentStreak(now) + 1;
    return RewardsState(
      xp: xp,
      streak: next,
      streakDay: key,
      bestStreak: next > bestStreak ? next : bestStreak,
    );
  }

  RewardsState addXp(int amount) => RewardsState(
    xp: xp + amount,
    streak: streak,
    streakDay: streakDay,
    bestStreak: bestStreak,
  );

  Map<String, dynamic> toJson() => {
    'xp': xp,
    'streak': streak,
    if (streakDay != null) 'day': streakDay,
    'best': bestStreak,
  };

  factory RewardsState.fromJson(Map<String, dynamic> j) {
    final day = j['day'] as String?;
    if (day != null) DateTime.parse(day);
    return RewardsState(
      xp: j['xp'] as int,
      streak: j['streak'] as int,
      streakDay: day,
      bestStreak: j['best'] as int,
    );
  }
}
