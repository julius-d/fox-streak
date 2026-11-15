// Test-view setup for edge-to-edge / large-font layout checks (issue #133).
//
// Edge-to-edge Android reports the status bar and the system navigation
// bar (3-button nav ~48dp, gesture handle ~24dp) as view padding; FABs
// and lists must clear them. Values are logical px.

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pixel 9-ish portrait phone, in logical px.
const Size kPhonePortrait = Size(412, 915);

/// Small phone in landscape, in logical px.
const Size kPhoneLandscape = Size(640, 360);

/// 3-button navigation bar height.
const double kNavBarInset = 48;

/// Sets the test view to [size] with [top]/[bottom] system insets, a
/// [textScale] and optionally the OS reduce-motion flag; resets on
/// teardown.
void simulateEdgeToEdgeView(
  WidgetTester tester, {
  Size size = kPhonePortrait,
  double top = 0,
  double bottom = kNavBarInset,
  double textScale = 1,
  bool disableAnimations = false,
}) {
  final dpr = tester.view.devicePixelRatio;
  final padding = FakeViewPadding(top: top * dpr, bottom: bottom * dpr);
  tester.view
    ..physicalSize = size * dpr
    ..padding = padding
    ..viewPadding = padding;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  if (disableAnimations) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  }
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

/// Logical size of the test view.
Size viewSize(WidgetTester tester) =>
    tester.view.physicalSize / tester.view.devicePixelRatio;
