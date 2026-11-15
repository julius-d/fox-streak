// Linux share/import decisions (issue #129).
//
// Linux has no share sheet for files, so Share saves the set via a "Save
// file" dialog, confirmed by a "Set saved" snackbar whose "Show folder"
// action opens the containing folder. A missing file dialog (no XDG desktop
// portal) shows a message naming the fix instead of doing nothing. The
// platform is switched via `TargetPlatformVariant`; `file_picker` is faked at
// its platform interface and the folder opener via its provider, so no real
// dialog or file manager opens. The real save -> re-import round trip runs
// on-device in `integration_test/issue129_linux_share_test.dart`.

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/l10n/app_localizations_en.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/data/sets_repository.dart';
import 'package:fox_streak_app/src/library/library_screen.dart';
import 'package:fox_streak_app/src/library/share_actions.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

import '../data/test_helpers.dart';

class _SaveCall {
  _SaveCall(this.fileName, this.bytes, this.dialogTitle);
  final String fileName;
  final Uint8List bytes;
  final String? dialogTitle;
}

class _FakeFilePickerPlatform extends FilePickerPlatform {
  /// What the save dialog returns; throwing simulates a missing portal.
  Uri? Function() onSaveFile = () => null;

  /// What the open dialog returns; throwing simulates a missing portal.
  List<PlatformFile> Function() onPickFiles = () => [];

  final List<_SaveCall> saveCalls = [];
  int pickCalls = 0;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving, // ignore: inference_failure_on_function_return_type — must match the base method's own untyped signature to override it
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    saveCalls.add(_SaveCall(fileName, bytes, dialogTitle));
    return onSaveFile();
  }

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading, // ignore: inference_failure_on_function_return_type — must match the base method's own untyped signature to override it
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    pickCalls++;
    return onPickFiles();
  }
}

/// The error the real Linux picker raises when no desktop portal runs.
final _portalMissing = Exception(
  'org.freedesktop.DBus.Error.ServiceUnknown: The name is not activatable',
);

final _linuxOnly = TargetPlatformVariant.only(TargetPlatform.linux);

Future<void> _settle(WidgetTester tester, {int cap = 50}) async {
  for (var i = 0; i < cap; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (!tester.binding.hasScheduledFrame) return;
  }
  fail('UI did not settle after $cap frames');
}

/// Unmounts and flushes drift's stream-close timer (see
/// `library_screen_test.dart`'s note).
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  final l10n = AppLocalizationsEn();
  late _FakeFilePickerPlatform picker;
  late FilePickerPlatform originalPicker;
  late List<String> openedFolders;

  setUp(() {
    originalPicker = FilePickerPlatform.instance;
    picker = _FakeFilePickerPlatform();
    FilePickerPlatform.instance = picker;
    openedFolders = [];
  });

  tearDown(() => FilePickerPlatform.instance = originalPicker);

  /// Pumps the Library with one set titled [title] holding one item; returns
  /// the set id.
  Future<int> pumpLibraryWithSet(WidgetTester tester, String title) async {
    final clock = FakeClock(kTestToday);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = SetsRepository(db, clock);
    final id = await repo.createSet(title: title, createdBy: 'Mama');
    await repo.addItem(
      setId: id,
      type: 'choice',
      prompt: 'Hund',
      answer: 'dog',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          systemClockProvider.overrideWithValue(clock),
          folderOpenerProvider.overrideWithValue((path) async {
            openedFolders.add(path);
            return true;
          }),
        ],
        child: MaterialApp(
          theme: FoxStreakTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LibraryScreen(),
        ),
      ),
    );
    await _settle(tester);
    return id;
  }

  Future<void> tapShare(WidgetTester tester, int setId) async {
    await tester.tap(find.byKey(Key('setMenu-$setId')));
    await _settle(tester);
    await tester.tap(find.text(l10n.shareSet));
    await _settle(tester);
  }

  Future<void> tapImport(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('newSetFab')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('importSetFab')));
    await _settle(tester);
  }

  group('sharesViaSaveDialog', () {
    test('only Linux saves via a dialog; the rest keep the share sheet', () {
      for (final platform in TargetPlatform.values) {
        expect(
          sharesViaSaveDialog(platform),
          platform == TargetPlatform.linux,
          reason: '$platform',
        );
      }
    });
  });

  testWidgets(
    'Share on Linux opens the save dialog with the suggested filename and '
    'confirms with "Set saved" + "Show folder"',
    (tester) async {
      picker.onSaveFile = () =>
          Uri.file('/home/fox/Downloads/Animals.foxstreak.json');
      final id = await pumpLibraryWithSet(tester, 'Animals');

      await tapShare(tester, id);

      final call = picker.saveCalls.single;
      expect(call.fileName, 'Animals.foxstreak.json');
      expect(call.dialogTitle, l10n.saveSetDialogTitle);
      final saved = jsonDecode(utf8.decode(call.bytes)) as Map<String, dynamic>;
      expect(saved['title'], 'Animals');
      expect((saved['items'] as List).single['prompt'], 'Hund');

      expect(find.text(l10n.setSavedToFile), findsOneWidget);
      await tester.tap(find.byKey(const Key('showSavedSetFolderAction')));
      await _settle(tester);
      expect(openedFolders, ['/home/fox/Downloads']);
      await _unmount(tester);
    },
    variant: _linuxOnly,
  );

  testWidgets('the "Set saved" confirmation times out on its own', (
    tester,
  ) async {
    picker.onSaveFile = () =>
        Uri.file('/home/fox/Downloads/Animals.foxstreak.json');
    final id = await pumpLibraryWithSet(tester, 'Animals');

    await tapShare(tester, id);
    expect(find.text(l10n.setSavedToFile), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await _settle(tester);

    expect(find.text(l10n.setSavedToFile), findsNothing);
    expect(openedFolders, isEmpty);
    await _unmount(tester);
  }, variant: _linuxOnly);

  testWidgets('cancelling the Linux save dialog is a no-op', (tester) async {
    picker.onSaveFile = () => null;
    final id = await pumpLibraryWithSet(tester, 'Animals');

    await tapShare(tester, id);

    expect(picker.saveCalls, hasLength(1));
    expect(find.byType(SnackBar), findsNothing);
    expect(openedFolders, isEmpty);
    await _unmount(tester);
  }, variant: _linuxOnly);

  testWidgets('Share on Linux without a file dialog names the fix', (
    tester,
  ) async {
    picker.onSaveFile = () => throw _portalMissing;
    final id = await pumpLibraryWithSet(tester, 'Animals');

    await tapShare(tester, id);

    expect(find.text(l10n.fileDialogUnavailable), findsOneWidget);
    expect(find.text(l10n.shareFailed), findsNothing);
    await _unmount(tester);
  }, variant: _linuxOnly);

  testWidgets(
    'a failed write of the chosen file on Linux is a share error, not a '
    'missing dialog',
    (tester) async {
      picker.onSaveFile = () => throw const FileSystemException(
        'Cannot open file',
        '/root/Animals.foxstreak.json',
      );
      final id = await pumpLibraryWithSet(tester, 'Animals');

      await tapShare(tester, id);

      expect(find.text(l10n.shareFailed), findsOneWidget);
      expect(find.text(l10n.fileDialogUnavailable), findsNothing);
      await _unmount(tester);
    },
    variant: _linuxOnly,
  );

  testWidgets('Import on Linux without a file dialog names the fix', (
    tester,
  ) async {
    picker.onPickFiles = () => throw _portalMissing;
    await pumpLibraryWithSet(tester, 'Animals');

    await tapImport(tester);

    expect(picker.pickCalls, 1);
    expect(find.text(l10n.fileDialogUnavailable), findsOneWidget);
    expect(find.text(l10n.importFailed), findsNothing);
    await _unmount(tester);
  }, variant: _linuxOnly);

  testWidgets('a failing picker elsewhere keeps the generic import error', (
    tester,
  ) async {
    picker.onPickFiles = () => throw _portalMissing;
    await pumpLibraryWithSet(tester, 'Animals');

    await tapImport(tester);

    expect(find.text(l10n.importFailed), findsOneWidget);
    expect(find.text(l10n.fileDialogUnavailable), findsNothing);
    await _unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('Share off Linux never opens the save dialog', (tester) async {
    final id = await pumpLibraryWithSet(tester, 'Animals');

    await tapShare(tester, id);

    // No share_plus plugin under `flutter test`: the share sheet attempt
    // fails into the existing error snackbar, but never the save dialog.
    expect(picker.saveCalls, isEmpty);
    expect(find.text(l10n.setSavedToFile), findsNothing);
    await _unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
