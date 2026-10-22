import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Fail loudly at launch, rather than shipping an app that sends logins and payments over http.
  if (kReleaseMode && !AppConfig.isSecure) {
    throw StateError(
      'Release builds must use an https:// backend. '
      'Build with --dart-define=API_BASE_URL=https://your-domain',
    );
  }

  runApp(const ProviderScope(child: DostiApp()));
}
