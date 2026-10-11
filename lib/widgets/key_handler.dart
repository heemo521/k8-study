import 'package:material_ui/material_ui.dart';

/// Routes key presses on this screen to [onKey].
///
/// Routes (including the tab shell's nested navigator) focus their own scope
/// after being built or when a dialog above them closes, which bypasses a
/// plain `autofocus`. So while this screen is the top route, whenever primary
/// focus lands on a bare scope it's handed to this handler. Keys pressed while a child (e.g. a tapped option or a text field)
/// has focus are left alone and still bubble up here.
class KeyHandler extends StatefulWidget {
  const KeyHandler({super.key, required this.onKey, required this.child});

  final FocusOnKeyEventCallback onKey;
  final Widget child;

  @override
  State<KeyHandler> createState() => _KeyHandlerState();
}

class _KeyHandlerState extends State<KeyHandler> {
  final _node = FocusNode(debugLabel: 'KeyHandler');

  void _claim() {
    if (!mounted || _node.context == null) return;
    final primary = FocusManager.instance.primaryFocus;
    // Claim focus while this screen is the top route and nothing more
    // specific holds it (a bare scope: this route's, or one beneath it such
    // as the tab shell's nested navigator after a deep link).
    final isTop = ModalRoute.of(context)?.isCurrent ?? true;
    if (isTop && (primary == null || primary is FocusScopeNode)) {
      _node.requestFocus();
    }
  }

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_claim);
    WidgetsBinding.instance.addPostFrameCallback((_) => _claim());
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_claim);
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Focus(focusNode: _node, onKeyEvent: widget.onKey, child: widget.child);
}
