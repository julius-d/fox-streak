// Share / import wiring for sets (issue #003).
//
// Buttons + dialog hook live here. Verifiable export-warning criteria (real
// privacy dialog copy, `SetImportException` snackbar copy, picker-cancel
// behavior) are owned and tested in #008 — this file only wires
// `share_plus` + `file_picker` to `exportSetToJson`/`importSetFromJson` with
// `.foxstreak.json` filenames.
//
// Linux (issue #129) has no share sheet for files, so Share saves the file
// via a "Save file" dialog instead. Its file dialogs go through the XDG
// desktop portal; without one they fail, which surfaces as
// [FileDialogUnavailableException] so the UI can name the fix. The platform
// comes from `defaultTargetPlatform` (`debugDefaultTargetPlatformOverride`
// in tests).

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/providers.dart';
import '../data/set_json_codec.dart';

/// Builds the `.foxstreak.json` share filename for a set [title].
///
/// Pure (no I/O) so it is unit-testable. Keeps Unicode letters/digits
/// (German umlauts included), `_`, `-` and spaces; strips everything else.
/// Blank titles fall back to `set`.
String shareFileNameForTitle(String title) {
  final trimmed = title.trim();
  final safeTitle = trimmed.isEmpty
      ? 'set'
      : trimmed
            .replaceAll(RegExp(r'[^\p{L}\p{N}\-_ ]+', unicode: true), '')
            .trim();
  return '${safeTitle.isEmpty ? 'set' : safeTitle}.foxstreak.json';
}

/// Whether Share saves the set via a "Save file" dialog instead of opening
/// the share sheet: Linux has no share sheet for files (issue #129).
bool sharesViaSaveDialog(TargetPlatform platform) =>
    platform == TargetPlatform.linux;

/// The system can't show a file dialog: on Linux, no XDG desktop portal (or
/// none with a file chooser) is installed (issue #129).
class FileDialogUnavailableException implements Exception {
  const FileDialogUnavailableException(this.cause);

  /// The error the file dialog failed with.
  final Object cause;

  @override
  String toString() => 'FileDialogUnavailableException: $cause';
}

/// What [shareSet] did.
sealed class ShareSetOutcome {
  const ShareSetOutcome(this.path);

  /// The exported `.foxstreak.json` file.
  final String path;
}

/// The share sheet was opened with a temp export at [path].
final class SetSharedViaSheet extends ShareSetOutcome {
  const SetSharedViaSheet(super.path);
}

/// Linux: the user saved the export to [path] via the save dialog.
final class SetSavedToFile extends ShareSetOutcome {
  const SetSavedToFile(super.path);
}

/// Exports [setId] as `<title>.foxstreak.json`: to a temp file handed to the
/// share sheet, or — on Linux — to wherever the user picks in a "Save file"
/// dialog. Pass the localized [saveDialogTitle] for that dialog.
///
/// Returns null when the set no longer exists or the save dialog was
/// cancelled (no-op). Throws [FileDialogUnavailableException] when Linux
/// can't show the save dialog.
Future<ShareSetOutcome?> shareSet(
  WidgetRef ref,
  int setId,
  String title, {
  String? saveDialogTitle,
}) async {
  final repo = ref.read(setsRepositoryProvider);
  late final Map<String, dynamic> payload;
  try {
    payload = await repo.exportSetToJson(setId);
  } on ArgumentError {
    return null;
  } on SetImportException {
    return null;
  }
  final fileName = shareFileNameForTitle(title);
  final json = jsonEncode(payload);
  if (sharesViaSaveDialog(defaultTargetPlatform)) {
    final saved = await _fileDialog(
      () => FilePicker.saveFile(
        dialogTitle: saveDialogTitle,
        fileName: fileName,
        bytes: utf8.encode(json),
        mimeType: 'application/json',
      ),
    );
    return saved == null ? null : SetSavedToFile(saved.toFilePath());
  }
  final file = File('${Directory.systemTemp.path}/$fileName');
  await file.writeAsString(json);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], fileNameOverrides: [fileName]),
  );
  return SetSharedViaSheet(file.path);
}

/// Runs a file-dialog call. On Linux a failing dialog means no desktop
/// portal is available, rethrown as [FileDialogUnavailableException];
/// a failed write of the chosen file stays a [FileSystemException].
Future<T> _fileDialog<T>(Future<T> Function() dialog) async {
  try {
    return await dialog();
  } on FileSystemException {
    rethrow;
  } on Object catch (error) {
    if (defaultTargetPlatform != TargetPlatform.linux) rethrow;
    // Logged so a misclassified failure can still be diagnosed.
    debugPrint('File dialog unavailable: $error');
    throw FileDialogUnavailableException(error);
  }
}

/// Opens a folder in the system file manager; returns whether it did.
typedef FolderOpener = Future<bool> Function(String directoryPath);

/// Opens the folder a saved set landed in ("Show folder", issue #129).
/// Override in tests so no real file manager opens.
final Provider<FolderOpener> folderOpenerProvider = Provider<FolderOpener>(
  (ref) =>
      (directoryPath) => launchUrl(Uri.directory(directoryPath)),
);

/// Picks a `.foxstreak.json` file and imports it as a new set into the pack
/// chosen by [choosePack] (issue #121; null = cancelled, nothing imported).
/// Without [choosePack] the default own pack is used.
///
/// Returns the new set id, or null when the picker or the pack choice was
/// cancelled (no-op).
/// Throws [SetImportException] on bad content so callers can show a snackbar
/// (copy owned by #008), and [FileDialogUnavailableException] when Linux
/// can't show the file dialog.
Future<int?> importSetFromPicker(
  WidgetRef ref, {
  Future<int?> Function()? choosePack,
  String? dialogTitle,
}) async {
  final picked = await _fileDialog(
    () => FilePicker.pickFiles(
      dialogTitle: dialogTitle,
      type: FileType.custom,
      allowedExtensions: ['json'],
    ),
  );
  if (picked.isEmpty) return null; // cancel = no-op
  final file = picked.first;
  final bytes = await file.readAsBytes();
  final decoded = jsonDecode(utf8.decode(bytes));
  if (decoded is! Map) {
    throw const SetImportException('picked file is not a set object');
  }
  final json = Map<dynamic, dynamic>.from(decoded);
  int? packId;
  if (choosePack != null) {
    packId = await choosePack();
    if (packId == null) return null; // cancel = no-op
  }
  return ref
      .read(setsRepositoryProvider)
      .importSetFromJson(json, packId: packId);
}
