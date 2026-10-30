import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'web_bridge.dart';

/// Flutter's web engine doesn't report the iPhone notch / home-indicator
/// insets, so in the web app we read them from CSS and feed them to
/// MediaQuery. The app's own SafeAreas then work as they do natively.
Widget withWebSafeArea(Widget app) => kIsWeb ? _WebSafeArea(child: app) : app;

class _WebSafeArea extends StatelessWidget {
  const _WebSafeArea({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery.fromView(
        view: View.of(context),
        child: Builder(builder: (context) {
          final data = MediaQuery.of(context);
          final s = webSafeInsets();
          final view = EdgeInsets.fromLTRB(
            math.max(data.viewPadding.left, s[3]),
            math.max(data.viewPadding.top, s[0]),
            math.max(data.viewPadding.right, s[1]),
            math.max(data.viewPadding.bottom, s[2]),
          );
          final pad = EdgeInsets.fromLTRB(
            view.left,
            view.top,
            view.right,
            math.max(0.0, view.bottom - data.viewInsets.bottom),
          );
          return MediaQuery(data: data.copyWith(viewPadding: view, padding: pad), child: child);
        }),
      );
}
