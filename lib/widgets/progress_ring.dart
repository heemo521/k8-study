import 'package:material_ui/material_ui.dart';

class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.value, this.size = 36});

  /// 0..1
  final double value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '${(value * 100).round()} percent',
      child: SizedBox.square(
        dimension: size,
        child: CircularProgressIndicator(
          value: value,
          strokeWidth: 4,
          backgroundColor: scheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}
