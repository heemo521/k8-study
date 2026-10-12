import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Shown for unknown ids in a deep link, or when there's nothing to show yet.
class NotFoundView extends StatelessWidget {
  const NotFoundView({
    super.key,
    required this.message,
    this.backTo = '/',
    this.title,
    this.icon = Icons.search_off,
    this.actionLabel = 'Go back',
  });

  final String message;
  final String backTo;
  final String? title;
  final IconData icon;
  final String actionLabel;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: title == null ? null : Text(title!),
      leading: BackButton(onPressed: () => context.go(backTo)),
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go(backTo),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    ),
  );
}
