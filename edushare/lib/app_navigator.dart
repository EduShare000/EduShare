import 'package:flutter/widgets.dart';

/// Global navigator key used by the app so screens can push/pop without
/// depending on a local BuildContext that might not include a Navigator.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
