// Fixed icon map for the three item types (issue #003).

import 'package:flutter/material.dart';

/// Icon for an item `type` (`vocab|phone|date`).
IconData iconForItemType(String type) {
  switch (type) {
    case 'vocab':
      return Icons.translate;
    case 'phone':
      return Icons.phone;
    case 'date':
      return Icons.cake;
    default:
      return Icons.help_outline;
  }
}
