// Share / import wiring for sets (issue #003).
//
// Buttons + dialog hook live here. Verifiable export-warning criteria (real
// privacy dialog copy, `SetImportException` snackbar copy, picker-cancel
// behavior) are owned and tested in #008 — this file only wires
// `share_plus` + `file_picker` to `exportSetToJson`/`importSetFromJson` with
// `.foxstreak.json` filenames.

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../data/providers.dart';
import '../data/set_json_codec.dart';

/// Exports [setId] to a temp `.foxstreak.json` file and opens the share sheet.
///
/// Returns the exported file path, or null when the set no longer exists.
Future<String?> shareSet(WidgetRef ref, int setId, String title) async {
  final repo = ref.read(setsRepositoryProvider);
  late final Map<String, dynamic> payload;
  try {
    payload = await repo.exportSetToJson(setId);
  } on ArgumentError {
    return null;
  } on SetImportException {
    return null;
  }
  final safeTitle = title.trim().isEmpty
      ? 'set'
      : title.trim().replaceAll(RegExp(r'[^\w\- ]+'), '').trim();
  final fileName = '${safeTitle.isEmpty ? 'set' : safeTitle}.foxstreak.json';
  final file = File('${Directory.systemTemp.path}/$fileName');
  await file.writeAsString(jsonEncode(payload));
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], fileNameOverrides: [fileName]),
  );
  return file.path;
}

/// Picks a `.foxstreak.json` file and imports it as a new set.
///
/// Returns the new set id, or null when the picker was cancelled (no-op).
/// Throws [SetImportException] on bad content so callers can show a snackbar
/// (copy owned by #008).
Future<int?> importSetFromPicker(WidgetRef ref) async {
  final picked = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json'],
  );
  if (picked.isEmpty) return null; // cancel = no-op
  final file = picked.first;
  final bytes = await file.readAsBytes();
  final decoded = jsonDecode(utf8.decode(bytes));
  if (decoded is! Map) {
    throw const SetImportException('picked file is not a set object');
  }
  return ref
      .read(setsRepositoryProvider)
      .importSetFromJson(Map<dynamic, dynamic>.from(decoded));
}
