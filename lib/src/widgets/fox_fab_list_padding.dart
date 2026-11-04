// Bottom clearance for scrollable lists sitting under a FAB (issue #104).
//
// Library, Set Detail, and Marketplace Sources each pair a plain
// `ListView.builder` with one or more floating action buttons; without
// reserved bottom space, the last row's trailing action(s) can end up
// scrolled directly underneath the FAB — or, on edge-to-edge Android 15+,
// underneath the platform's bottom system UI inset — making them hard or
// impossible to tap.

import 'package:flutter/material.dart';

/// Reserved space above the system inset for the FAB itself.
///
/// Deliberately generous: enough to clear Set Detail's two stacked FABs
/// (small "Add item" + extended "Start lesson"), the tallest FAB
/// arrangement in the app, plus Scaffold's own FAB margin and a safety
/// buffer. Library and Marketplace Sources each have a single, shorter
/// FAB and so need less — reusing the same value there just leaves a bit
/// of extra empty space below a short list's last row, which issue #104
/// accepts as a consistent trade-off rather than tuning this per screen.
const double kFabListClearance = 160;

/// Bottom padding for a `ListView` under a FAB: [kFabListClearance] plus
/// the platform's bottom system UI inset (Android nav bar/gesture handle,
/// iOS home indicator), so the last row clears both.
EdgeInsets fabListBottomPadding(BuildContext context) {
  return EdgeInsets.only(
    bottom: kFabListClearance + MediaQuery.paddingOf(context).bottom,
  );
}
