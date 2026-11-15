// Issue #129 — Linux share/import on the real app.
//
// Runs the real `FoxStreakApp` with `defaultTargetPlatform` switched to Linux
// (`TargetPlatformVariant`), so it works on any desktop host. `file_picker`
// is faked at its platform interface, but the fake save dialog writes the
// file to disk exactly like `file_picker_linux` does after the portal
// answers, so the saved set is re-imported from a real file. The folder
// opener is faked via its provider — no file manager opens.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations_en.dart';
import 'package:fox_streak_app/src/data/sets_repository.dart';
import 'package:fox_streak_app/src/library/share_actions.dart';
import 'package:integration_test/integration_test.dart';
import 'package:share_plus/share_plus.dart' show XFile;

import 'helpers.dart';

final class _DiskPlatformFile extends PlatformFile {
  _DiskPlatformFile(this._file);
  final File _file;

  @override
  String get name => _file.uri.pathSegments.last;

  @override
  String? get path => _file.path;

  @override
  Uri get uri => _file.uri;

  @override
  XFile get xFile => XFile(_file.path);

  @override
  int? lengthSync() => _file.lengthSync();

  @override
  Future<int?> length() => _file.length();

  @override
  Future<Uint8List> readAsBytes() => _file.readAsBytes();

  @override
  Stream<Uint8List> readAsByteStream() =>
      _file.openRead().map(Uint8List.fromList);
}

/// Stands in for the XDG desktop portal: [saveDirectory] is where the user
/// "picks" to save; [portalMissing] makes every dialog fail like a desktop
/// without a portal does.
class _FakePortalFilePicker extends FilePickerPlatform {
  _FakePortalFilePicker(this.saveDirectory);

  final Directory saveDirectory;
  bool portalMissing = false;
  File? lastSaved;

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
    if (portalMissing) throw Exception('ServiceUnknown: no desktop portal');
    final file = File('${saveDirectory.path}/$fileName');
    await file.writeAsBytes(bytes);
    lastSaved = file;
    return file.uri;
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
    if (portalMissing) throw Exception('ServiceUnknown: no desktop portal');
    return [_DiskPlatformFile(lastSaved!)];
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final l10n = AppLocalizationsEn();
  final linux = TargetPlatformVariant.only(TargetPlatform.linux);
  late Directory saveDirectory;
  late _FakePortalFilePicker picker;
  late FilePickerPlatform originalPicker;
  late List<String> openedFolders;

  setUp(() {
    saveDirectory = Directory.systemTemp.createTempSync('issue129_');
    originalPicker = FilePickerPlatform.instance;
    picker = _FakePortalFilePicker(saveDirectory);
    FilePickerPlatform.instance = picker;
    openedFolders = [];
  });

  tearDown(() {
    FilePickerPlatform.instance = originalPicker;
    saveDirectory.deleteSync(recursive: true);
  });

  Future<void> pumpAppWithSet(WidgetTester tester) async {
    final db = makeIntegrationTestDb();
    addTearDown(db.close);
    final clock = FakeClock(DateTime(2026, 11, 15, 9));
    final repo = SetsRepository(db, clock);
    final id = await repo.createSet(title: 'Animals', createdBy: 'Mama');
    await repo.addItem(
      setId: id,
      type: 'choice',
      prompt: 'Hund',
      answer: 'dog',
    );
    await pumpFoxStreakApp(
      tester,
      db: db,
      clock: clock,
      overrides: [
        folderOpenerProvider.overrideWithValue((path) async {
          openedFolders.add(path);
          return true;
        }),
      ],
    );
    await skipOnboardingAndOpenLibrary(tester);
  }

  Future<void> share(WidgetTester tester) async {
    await tester.tap(setMenuButton('Animals'));
    await settle(tester);
    await tester.tap(find.text(l10n.shareSet));
    await settle(tester);
  }

  Future<void> import(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('newSetFab')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('importSetFab')));
    await settle(tester);
  }

  testWidgets(
    'Share saves the set to a file, "Show folder" opens its folder, and the '
    'saved file re-imports into a new set',
    (tester) async {
      await pumpAppWithSet(tester);

      await share(tester);

      final saved = picker.lastSaved!;
      expect(saved.uri.pathSegments.last, 'Animals.foxstreak.json');
      expect(saved.existsSync(), isTrue);
      expect(find.text(l10n.setSavedToFile), findsOneWidget);
      await tester.tap(find.text(l10n.showFolder));
      await settle(tester);
      expect(openedFolders, [saveDirectory.path]);
      // Let the snackbar time out before the import's pack dialog.
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);

      await import(tester);
      expect(find.text(l10n.packImportTitle), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirmPackChoiceButton')));
      await settle(tester);

      expect(listTileWithText('Animals'), findsNWidgets(2));
      await openSetDetail(tester, 'Animals', index: 1);
      expect(listTileWithText('Hund'), findsOneWidget);
    },
    variant: linux,
  );

  testWidgets('without a file dialog, Share and Import both name the fix', (
    tester,
  ) async {
    picker.portalMissing = true;
    await pumpAppWithSet(tester);

    await share(tester);
    expect(find.text(l10n.fileDialogUnavailable), findsOneWidget);
    expect(find.text(l10n.shareFailed), findsNothing);
    // The message stays up longer than usual (10 s) so it can be read.
    await tester.pump(const Duration(seconds: 11));
    await settle(tester);
    expect(find.text(l10n.fileDialogUnavailable), findsNothing);

    await import(tester);
    expect(find.text(l10n.fileDialogUnavailable), findsOneWidget);
    expect(find.text(l10n.importFailed), findsNothing);
    expect(listTileWithText('Animals'), findsOneWidget);
  }, variant: linux);
}
