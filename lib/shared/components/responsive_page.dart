import 'package:flutter/material.dart';

/// Content-width guard.
///
/// AppShell locks the whole experience to a ~460px phone column, so on the
/// live layout this widget simply returns its child unchanged — structurally
/// identical to the student Home screen body, which renders correctly.
///
/// It must never introduce a `LayoutBuilder`, `Align`, or `Center` at the top
/// level: those are laid out with the enclosing `SingleChildScrollView`'s
/// unbounded height and either assert (`LayoutBuilder`) or collapse the body
/// to zero size, leaving the page blank while the nav still renders. Passing
/// the child straight through avoids all of that.
///
/// [maxWidth] is retained for API compatibility; it is only honoured through
/// the optional [horizontalPadding] gutter, never via a constraint-reading
/// wrapper.
class ResponsivePage extends StatelessWidget {
  const ResponsivePage({
    super.key,
    required this.child,
    this.maxWidth = 720,
    this.horizontalPadding = 0,
  });

  final Widget child;
  final double maxWidth;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    if (horizontalPadding <= 0) {
      return child;
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: child,
    );
  }
}
