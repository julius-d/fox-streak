// Platform bridge to the Android home-screen widget (issue #115).
//
// A plain `MethodChannel` to our own Kotlin code instead of a pub plugin:
// the usual widget plugin (`home_widget`) lacks desktop support, which
// AGENTS.md requires for every dependency. On every other platform the
// bridge is a no-op.
import 'dart:io';

import 'package:flutter/services.dart';

import 'home_widget_payload.dart';

abstract class HomeWidgetBridge {
  /// Hands [payload] to the widget and asks it to redraw.
  Future<void> update(HomeWidgetPayload payload);
}

/// Used everywhere except Android.
class NoopHomeWidgetBridge implements HomeWidgetBridge {
  const NoopHomeWidgetBridge();

  @override
  Future<void> update(HomeWidgetPayload payload) async {}
}

class MethodChannelHomeWidgetBridge implements HomeWidgetBridge {
  static const MethodChannel channel = MethodChannel(
    'io.github.juliusd.foxstreak/home_widget',
  );

  const MethodChannelHomeWidgetBridge();

  @override
  Future<void> update(HomeWidgetPayload payload) async {
    try {
      await channel.invokeMethod<void>('update', payload.toMap());
    } on PlatformException {
      // The widget is a best-effort extra; never break the app over it.
    } on MissingPluginException {
      // Same, e.g. when the native side isn't registered (tests, hot restart).
    }
  }
}

HomeWidgetBridge platformHomeWidgetBridge() => Platform.isAndroid
    ? const MethodChannelHomeWidgetBridge()
    : const NoopHomeWidgetBridge();
