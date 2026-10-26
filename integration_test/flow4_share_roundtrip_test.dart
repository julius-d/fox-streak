// Flow 4 — Share round-trip (issue #016, builds on #002/#008; entry points
// reworked by #074).
//
// Drives the real app's export/import wiring (`share_actions.dart`) through
// the Library screen: Share via a set card's three-dot menu, Import via the
// `newSetFab` speed-dial's "Import" mini-FAB. Native `share_plus` /
// `file_picker` calls are stubbed at the platform-interface level
// (`SharePlatform`/`FilePickerPlatform`) — no real share sheet or file
// dialog ever opens.

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

import 'package:fox_streak_app/l10n/app_localizations_en.dart';

import 'helpers.dart';

class _FakeSharePlatform extends SharePlatform {
  final List<ShareParams> shared = [];

  @override
  Future<ShareResult> share(ShareParams params) async {
    shared.add(params);
    return const ShareResult('', ShareResultStatus.success);
  }
}

final class _FakePlatformFile extends PlatformFile {
  _FakePlatformFile(this._name, this._bytes);
  final String _name;
  final Uint8List _bytes;

  @override
  String get name => _name;

  @override
  Uri get uri => Uri.file('/tmp/$_name');

  @override
  XFile get xFile => XFile.fromData(_bytes, name: _name);

  @override
  int? lengthSync() => _bytes.length;

  @override
  Future<int?> length() async => _bytes.length;

  @override
  Future<Uint8List> readAsBytes() async => _bytes;

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(_bytes);
}

class _FakeFilePickerPlatform extends FilePickerPlatform {
  List<PlatformFile> Function()? onPickFiles;

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
  }) async => onPickFiles?.call() ?? <PlatformFile>[];
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSharePlatform fakeShare;
  late _FakeFilePickerPlatform fakeFilePicker;

  setUp(() {
    // `FilePickerPlatform.instance` is re-read on every `FilePicker.pickFiles`
    // call, so reassigning it fresh per test is safe. `SharePlatform` is NOT
    // symmetric: `share_plus`'s `SharePlus.instance` is a `static final`
    // that captures `SharePlatform.instance` on its own first-ever access in
    // the whole test process, not per-test — reassigning `SharePlatform
    // .instance` in a later test's `setUp` has no effect on an already-
    // capped `SharePlus.instance`. This file only calls `shareSet` (which
    // reads `SharePlus.instance`) from the first `testWidgets` below, so the
    // one-time capture lines up with this `fakeShare`; a second share-
    // exercising test added to this file would silently race for whichever
    // fake was live at that first access.
    fakeShare = _FakeSharePlatform();
    SharePlatform.instance = fakeShare;
    fakeFilePicker = _FakeFilePickerPlatform();
    FilePickerPlatform.instance = fakeFilePicker;
  });

  final l10n = AppLocalizationsEn();

  testWidgets(
    'export writes a valid .foxstreak.json and opens the (stubbed) share '
    'sheet; importing it back round-trips the items into a new set',
    (tester) async {
      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 14, 9));

      await pumpFoxStreakApp(tester, db: db, clock: clock);
      await skipOnboardingAndOpenLibrary(tester);

      // Create a set with one item to export.
      await openNewSetEditor(tester);
      await tester.enterText(find.byKey(const Key('titleField')), 'Animals');
      await tester.enterText(find.byKey(const Key('creatorField')), 'Mama');
      await tester.tap(find.byKey(const Key('saveSetButton')));
      await settle(tester);
      await openSetDetail(tester, 'Animals');
      await tester.tap(find.byKey(const Key('addItemFab')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('itemPromptField')), 'Hund');
      await tester.enterText(find.byKey(const Key('itemAnswerField')), 'dog');
      await tester.tap(find.byKey(const Key('saveItemButton')));
      await settle(tester);
      await tester.pageBack();
      await settle(tester);

      // Share (export) from the card's three-dot menu: the fake platform
      // captures what would have gone to the real share sheet.
      await tester.tap(setMenuButton('Animals'));
      await settle(tester);
      await tester.tap(find.text(l10n.shareSet));
      await settle(tester);

      expect(fakeShare.shared, hasLength(1));
      final exportedFile = fakeShare.shared.single.files!.single;
      final exportedJson =
          jsonDecode(await exportedFile.readAsString()) as Map<String, dynamic>;
      expect(exportedJson['title'], 'Animals');
      final exportedItems = (exportedJson['items'] as List)
          .cast<Map<String, dynamic>>();
      expect(exportedItems.single['prompt'], 'Hund');
      expect(exportedItems.single['answer'], 'dog');

      // Import it back via the newSetFab speed-dial: picker returns the
      // exported JSON bytes as a file.
      fakeFilePicker.onPickFiles = () => [
        _FakePlatformFile(
          'Animals.foxstreak.json',
          utf8.encode(jsonEncode(exportedJson)),
        ),
      ];
      await tester.tap(find.byKey(const Key('newSetFab')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('importSetFab')));
      await settle(tester);

      expect(
        listTileWithText('Animals'),
        findsNWidgets(2),
      ); // original + import
      await openSetDetail(tester, 'Animals', index: 1);
      expect(listTileWithText('Hund'), findsOneWidget);
    },
  );

  testWidgets(
    'bad JSON on import surfaces SetImportException as a snackbar, not a '
    'crash; a cancelled picker (empty list) is a no-op',
    (tester) async {
      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 14, 9));

      await pumpFoxStreakApp(tester, db: db, clock: clock);
      await skipOnboardingAndOpenLibrary(tester);

      await openNewSetEditor(tester);
      await tester.enterText(find.byKey(const Key('titleField')), 'Scratch');
      await tester.enterText(find.byKey(const Key('creatorField')), 'Mama');
      await tester.tap(find.byKey(const Key('saveSetButton')));
      await settle(tester);

      // Bad JSON: not even a map.
      fakeFilePicker.onPickFiles = () => [
        _FakePlatformFile('bad.foxstreak.json', utf8.encode('"just a string"')),
      ];
      await tester.tap(find.byKey(const Key('newSetFab')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('importSetFab')));
      await settle(tester);
      expect(find.byType(SnackBar), findsOneWidget);
      // Advance past the snackbar's auto-dismiss duration before the next
      // check, so it doesn't linger into the cancel-is-a-no-op assertion.
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);

      // Cancelled picker: no snackbar, no crash, same screen; the
      // speed-dial collapses either way.
      fakeFilePicker.onPickFiles = () => [];
      await tester.tap(find.byKey(const Key('newSetFab')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('importSetFab')));
      await settle(tester);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byKey(const Key('importSetFab')), findsNothing);
      expect(listTileWithText('Scratch'), findsOneWidget);
    },
  );
}
