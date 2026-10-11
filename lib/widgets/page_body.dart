import 'package:material_ui/material_ui.dart';

/// Max content width (spec §3.1): wider screens only add margins.
const maxContentWidth = 640.0;
const pagePadding = EdgeInsets.symmetric(horizontal: 16);

/// Centres [child] and caps its width at [maxContentWidth].
class PageWidth extends StatelessWidget {
  const PageWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxContentWidth),
          child: child,
        ),
      );
}

/// A width-capped, padded, scrolling list of children.
class PageList extends StatelessWidget {
  const PageList({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 32),
    this.controller,
  });

  final List<Widget> children;
  final EdgeInsets padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) => ListView(
        controller: controller,
        padding: EdgeInsets.zero,
        children: [
          PageWidth(
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ],
      );
}
