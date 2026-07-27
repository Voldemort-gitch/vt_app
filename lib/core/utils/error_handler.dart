import 'dart:ui' as ui show PlatformDispatcher;
import 'package:flutter/foundation.dart';
import 'logger.dart';

void initGlobalErrorHandling() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    logSystem.severe('Flutter framework error', details.exception, details.stack);
  };

  ui.PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    logSystem.severe('Platform-level error', error, stack);
    return true;
  };
}
