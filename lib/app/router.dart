import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../screens/about_screen.dart';
import '../screens/flashcards_screen.dart';
import '../screens/home_shell.dart';
import '../screens/practice_hub_screen.dart';
import '../screens/practice_result_screen.dart';
import '../screens/practice_run_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/quiz_result_screen.dart';
import '../screens/quiz_screen.dart';
import '../screens/study_notes_screen.dart';
import '../screens/topic_browser_screen.dart';
import '../screens/topic_detail_screen.dart';

/// Routes from spec §3. Hash URLs (Flutter web's default strategy), so any
/// static host works without rewrite rules. Study/quiz/test screens use the
/// root navigator so they cover the bottom navigation.
GoRouter buildRouter({String initialLocation = '/'}) {
  final rootKey = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const TopicBrowserScreen(),
              routes: [
                GoRoute(
                  path: 'topic/:topicId',
                  builder: (_, s) =>
                      TopicDetailScreen(topicId: s.pathParameters['topicId']!),
                  routes: [
                    GoRoute(
                      path: 'notes',
                      parentNavigatorKey: rootKey,
                      builder: (_, s) => StudyNotesScreen(
                          topicId: s.pathParameters['topicId']!),
                    ),
                    GoRoute(
                      path: 'cards',
                      parentNavigatorKey: rootKey,
                      builder: (_, s) => FlashcardsScreen(
                          topicId: s.pathParameters['topicId']!),
                    ),
                    GoRoute(
                      path: 'quiz',
                      parentNavigatorKey: rootKey,
                      builder: (_, s) => QuizScreen(
                        key: ValueKey(s.uri.toString()),
                        topicId: s.pathParameters['topicId']!,
                        retryMissed: s.uri.queryParameters['mode'] == 'missed',
                      ),
                    ),
                    // A sibling (not a child) of the quiz route, so the
                    // finished quiz page is not kept underneath the results.
                    GoRoute(
                      path: 'quiz/result',
                      parentNavigatorKey: rootKey,
                      builder: (_, s) => QuizResultScreen(
                          topicId: s.pathParameters['topicId']!),
                    ),
                  ],
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/practice',
              builder: (_, _) => const PracticeHubScreen(),
              routes: [
                GoRoute(
                  path: ':testId/run',
                  parentNavigatorKey: rootKey,
                  builder: (_, s) =>
                      PracticeRunScreen(testId: s.pathParameters['testId']!),
                ),
                GoRoute(
                  path: ':testId/result',
                  parentNavigatorKey: rootKey,
                  builder: (_, s) =>
                      PracticeResultScreen(testId: s.pathParameters['testId']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/progress', builder: (_, _) => const ProgressScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/about', builder: (_, _) => const AboutScreen()),
          ]),
        ],
      ),
    ],
  );
}
