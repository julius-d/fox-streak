// GStreamer probe for Linux sound (issue #129).
//
// `audioplayers_linux` aborts the whole app (an uncaught C++ exception in its
// `create` handler) when GStreamer's `playbin` element is missing, e.g.
// without the gst-plugins-base package. No Dart error handling can catch
// that, so on Linux [foxSoundPlayerProvider] asks GStreamer itself before
// creating any player.
import 'dart:ffi';

import 'package:ffi/ffi.dart';

typedef _InitCheckC = Int32 Function(
  Pointer<Void>,
  Pointer<Void>,
  Pointer<Void>,
);
typedef _InitCheck = int Function(Pointer<Void>, Pointer<Void>, Pointer<Void>);
typedef _FactoryFindC = Pointer<Void> Function(Pointer<Utf8>);
typedef _ObjectUnrefC = Void Function(Pointer<Void>);
typedef _ObjectUnref = void Function(Pointer<Void>);

/// Whether GStreamer ([library]) can create the [element] `audioplayers_linux`
/// plays through. False when the library, its init or the element is missing.
bool gstreamerCanPlay({
  String library = 'libgstreamer-1.0.so.0',
  String element = 'playbin',
}) {
  try {
    final gst = DynamicLibrary.open(library);
    // `gst_init_check(argc, argv, error)`: idempotent; the plugin calls
    // `gst_init` itself later.
    final initCheck = gst.lookupFunction<_InitCheckC, _InitCheck>(
      'gst_init_check',
    );
    if (initCheck(nullptr, nullptr, nullptr) == 0) return false;
    final findFactory = gst.lookupFunction<_FactoryFindC, _FactoryFindC>(
      'gst_element_factory_find',
    );
    final unref = gst.lookupFunction<_ObjectUnrefC, _ObjectUnref>(
      'gst_object_unref',
    );
    final name = element.toNativeUtf8();
    try {
      final factory = findFactory(name);
      if (factory == nullptr) return false;
      unref(factory);
      return true;
    } finally {
      malloc.free(name);
    }
  } on Object {
    return false;
  }
}
