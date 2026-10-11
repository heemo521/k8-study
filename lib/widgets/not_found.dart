import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Shown for unknown ids in a deep link.
class NotFoundView extends StatelessWidget {
  const NotFoundView({super.key, required this.message, this.backTo = '/'});

  final String message;
  final String backTo;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go(backTo),
              child: const Text('Go back'),
            ),
          ],
        ),
      ),
    ),
  );
}
