// CRUD + sharing repository for question sets and items (issue #002).

import 'dart:convert';

import 'package:drift/drift.dart';

import 'clock.dart';
import 'database.dart';
import 'set_json_codec.dart';
import 'validation.dart';

/// Repository for `question_sets` + `items`.
///
/// All writes are validated in Dart (phone/date/language-pair rules from
/// `validation.dart`); the DB enforces FK cascades. Timestamps come from the
/// injected [Clock] so tests can freeze time.
///
/// Sharing: [exportSetToJson] / [importSetFromJson] use the v1
/// `.foxstreak.json` codec. Import always creates a *new* set with fresh ids.
class SetsRepository {
  final AppDatabase _db;
  final Clock _clock;

  SetsRepository(AppDatabase db, [Clock? clock])
    : _db = db,
      _clock = clock ?? SystemClock();

  // -- Sets ---------------------------------------------------------------

  Future<List<QuestionSet>> getAllSets() => (_db.select(
    _db.questionSets,
  )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

  Stream<List<QuestionSet>> watchAllSets() => (_db.select(
    _db.questionSets,
  )..orderBy([(t) => OrderingTerm.asc(t.id)])).watch();

  Future<QuestionSet?> getSetById(int id) => (_db.select(
    _db.questionSets,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> createSet({
    required String title,
    String description = '',
    required String createdBy,
    String? category,
  }) {
    _checkSetFields(title: title, createdBy: createdBy, category: category);
    final nowMs = _clock.now().millisecondsSinceEpoch;
    return _db
        .into(_db.questionSets)
        .insert(
          QuestionSetsCompanion.insert(
            title: title.trim(),
            description: Value(description),
            createdBy: createdBy.trim(),
            createdAt: nowMs,
            updatedAt: nowMs,
            category: Value(category),
          ),
        );
  }

  Future<void> updateSet({
    required int id,
    String? title,
    String? description,
    String? createdBy,
    String? category,
  }) async {
    if (title != null && title.trim().isEmpty) {
      throw ArgumentError('title must be non-empty');
    }
    if (createdBy != null && validateCreatorName(createdBy) != null) {
      throw ArgumentError(validateCreatorName(createdBy));
    }
    _checkCategory(category);
    await (_db.update(_db.questionSets)..where((t) => t.id.equals(id))).write(
      QuestionSetsCompanion(
        title: title == null ? const Value.absent() : Value(title.trim()),
        description: description == null
            ? const Value.absent()
            : Value(description),
        createdBy: createdBy == null
            ? const Value.absent()
            : Value(createdBy.trim()),
        category: category == null ? const Value.absent() : Value(category),
        updatedAt: Value(_clock.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// Deletes the set; its items (and their attempts) cascade away.
  Future<void> deleteSet(int id) =>
      (_db.delete(_db.questionSets)..where((t) => t.id.equals(id))).go();

  // -- Items --------------------------------------------------------------

  Future<List<Item>> getItemsForSet(int setId) =>
      (_db.select(_db.items)
            ..where((t) => t.setId.equals(setId))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .get();

  Stream<List<Item>> watchItemsForSet(int setId) =>
      (_db.select(_db.items)
            ..where((t) => t.setId.equals(setId))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .watch();

  Future<Item?> getItemById(int id) =>
      (_db.select(_db.items)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> addItem({
    required int setId,
    required String type,
    required String prompt,
    required String answer,
    String? promptLang,
    String? answerLang,
    List<String>? choices,
    String? hint,
  }) async {
    final set = await getSetById(setId);
    if (set == null) throw ArgumentError('unknown setId $setId');
    final clean = _checkItemFields(
      type: type,
      prompt: prompt,
      answer: answer,
      promptLang: promptLang,
      answerLang: answerLang,
      choices: choices,
    );
    final siblings = await getItemsForSet(setId);
    final nextPos = siblings.isEmpty
        ? 0
        : siblings.map((e) => e.position).reduce((a, b) => a > b ? a : b) + 1;
    final id = await _db
        .into(_db.items)
        .insert(
          ItemsCompanion.insert(
            setId: setId,
            type: type,
            prompt: clean.prompt,
            answer: clean.answer,
            promptLang: Value(clean.promptLang),
            answerLang: Value(clean.answerLang),
            choices: Value(clean.choicesJson),
            hint: Value(hint ?? ''),
            position: nextPos,
          ),
        );
    await _touchSet(setId);
    return id;
  }

  Future<void> updateItem({
    required int id,
    String? type,
    String? prompt,
    String? answer,
    ({String? promptLang, String? answerLang})? Function()? languagePairUpdate,
    List<String>? Function()? choicesUpdate,
    String? hint,
  }) async {
    final existing = await (_db.select(
      _db.items,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) throw ArgumentError('unknown item id $id');

    final newType = type ?? existing.type;
    String? newPromptLang = existing.promptLang;
    String? newAnswerLang = existing.answerLang;
    if (languagePairUpdate != null) {
      final pair = languagePairUpdate();
      newPromptLang = pair?.promptLang;
      newAnswerLang = pair?.answerLang;
    }
    if (type != null &&
        languagePairUpdate == null &&
        type != existing.type &&
        newType != 'choice' &&
        newType != 'freeText') {
      // Switching to phone/date without an explicit pair: the new type
      // forbids one, so clear it.
      newPromptLang = null;
      newAnswerLang = null;
    }

    List<String>? newChoices = existing.choices == null
        ? null
        : List<String>.from(
            (jsonDecode(existing.choices!) as List).cast<String>(),
          );
    if (choicesUpdate != null) newChoices = choicesUpdate();
    if (type != null && choicesUpdate == null && type != existing.type) {
      if (newType != 'choice') newChoices = null;
    }

    final clean = _checkItemFields(
      type: newType,
      prompt: prompt ?? existing.prompt,
      answer: answer ?? existing.answer,
      promptLang: newPromptLang,
      answerLang: newAnswerLang,
      choices: newChoices,
    );
    await (_db.update(_db.items)..where((t) => t.id.equals(id))).write(
      ItemsCompanion(
        type: type == null ? const Value.absent() : Value(type),
        prompt: prompt == null ? const Value.absent() : Value(clean.prompt),
        answer: answer == null ? const Value.absent() : Value(clean.answer),
        promptLang: languagePairUpdate == null && type == null
            ? const Value.absent()
            : Value(clean.promptLang),
        answerLang: languagePairUpdate == null && type == null
            ? const Value.absent()
            : Value(clean.answerLang),
        choices: choicesUpdate == null && type == null
            ? const Value.absent()
            : Value(clean.choicesJson),
        hint: hint == null ? const Value.absent() : Value(hint),
      ),
    );
    await _touchSet(existing.setId);
  }

  Future<void> deleteItem(int id) async {
    final existing = await (_db.select(
      _db.items,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) return;
    await (_db.delete(_db.items)..where((t) => t.id.equals(id))).go();
    await _touchSet(existing.setId);
  }

  /// Reorders items; [orderedIds] must contain exactly the set's item ids.
  Future<void> reorderItems(int setId, List<int> orderedIds) async {
    final current = await getItemsForSet(setId);
    final currentIds = current.map((e) => e.id).toSet();
    if (currentIds.length != orderedIds.length ||
        !currentIds.containsAll(orderedIds)) {
      throw ArgumentError('orderedIds must match the set items exactly');
    }
    await _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.items)..where((t) => t.id.equals(orderedIds[i])))
            .write(ItemsCompanion(position: Value(i)));
      }
      await _touchSet(setId);
    });
  }

  /// Duplicates a set (deep copy of items) and returns the new set id.
  Future<int> duplicateSet(int id) async {
    final source = await getSetById(id);
    if (source == null) throw ArgumentError('unknown set id $id');
    final items = await getItemsForSet(id);
    final nowMs = _clock.now().millisecondsSinceEpoch;
    return _db.transaction(() async {
      final newId = await _db
          .into(_db.questionSets)
          .insert(
            QuestionSetsCompanion.insert(
              title: '${source.title} (copy)',
              description: Value(source.description),
              createdBy: source.createdBy,
              createdAt: nowMs,
              updatedAt: nowMs,
              category: Value(source.category),
            ),
          );
      for (final item in items) {
        await _db
            .into(_db.items)
            .insert(
              ItemsCompanion.insert(
                setId: newId,
                type: item.type,
                prompt: item.prompt,
                answer: item.answer,
                promptLang: Value(item.promptLang),
                answerLang: Value(item.answerLang),
                choices: Value(item.choices),
                hint: Value(item.hint ?? ''),
                position: item.position,
              ),
            );
      }
      return newId;
    });
  }

  // -- Sharing ------------------------------------------------------------

  /// Exports a set to the v1 share map.
  Future<Map<String, dynamic>> exportSetToJson(
    int id, {
    DateTime? today,
  }) async {
    final set = await getSetById(id);
    if (set == null) throw ArgumentError('unknown set id $id');
    final items = await getItemsForSet(id);
    return encodeSetToJson(
      title: set.title,
      description: set.description,
      createdBy: set.createdBy,
      category: effectiveSetCategory(set.category),
      items: [
        for (final item in items)
          ShareItem(
            type: item.type,
            prompt: item.prompt,
            answer: item.answer,
            promptLang: item.promptLang,
            answerLang: item.answerLang,
            choices: item.choices == null
                ? null
                : List<String>.from(
                    (jsonDecode(item.choices!) as List).cast<String>(),
                  ),
            hint: item.hint ?? '',
          ),
      ],
      today: today,
    );
  }

  /// Imports a v1 share map as a *new* set; returns the new set id.
  ///
  /// Throws [SetImportException] on bad schema / unknown version.
  Future<int> importSetFromJson(
    Map<dynamic, dynamic> json, {
    DateTime? today,
  }) async {
    final share = decodeSetFromJson(json, today: today);
    final nowMs = (_clock.now()).millisecondsSinceEpoch;
    return _db.transaction(() async {
      final newId = await _db
          .into(_db.questionSets)
          .insert(
            QuestionSetsCompanion.insert(
              title: share.title,
              description: Value(share.description),
              createdBy: share.createdBy,
              createdAt: nowMs,
              updatedAt: nowMs,
              category: Value(share.category),
            ),
          );
      for (var i = 0; i < share.items.length; i++) {
        final item = share.items[i];
        await _db
            .into(_db.items)
            .insert(
              ItemsCompanion.insert(
                setId: newId,
                type: item.type,
                prompt: item.prompt,
                answer: item.answer,
                promptLang: Value(item.promptLang),
                answerLang: Value(item.answerLang),
                choices: Value(
                  item.choices == null ? null : jsonEncode(item.choices),
                ),
                hint: Value(item.hint),
                position: i,
              ),
            );
      }
      return newId;
    });
  }

  // -- Internals ----------------------------------------------------------

  void _checkSetFields({
    required String title,
    required String createdBy,
    String? category,
  }) {
    if (title.trim().isEmpty) throw ArgumentError('title must be non-empty');
    final creatorError = validateCreatorName(createdBy);
    if (creatorError != null) throw ArgumentError(creatorError);
    _checkCategory(category);
  }

  void _checkCategory(String? category) {
    if (category != null && !kSetCategories.contains(category)) {
      throw ArgumentError('unknown category "$category"');
    }
  }

  _CleanItem _checkItemFields({
    required String type,
    required String prompt,
    required String answer,
    String? promptLang,
    String? answerLang,
    List<String>? choices,
  }) {
    if (!kItemTypes.contains(type)) {
      throw ArgumentError('unknown type "$type"');
    }
    if (!isNonEmptyContent(prompt)) {
      throw ArgumentError('prompt must be non-empty');
    }
    if (!isNonEmptyContent(answer)) {
      throw ArgumentError('answer must be non-empty');
    }
    final languageError = validateLanguagePair(type, promptLang, answerLang);
    if (languageError != null) throw ArgumentError(languageError);
    final choicesError = validateChoices(type, choices);
    if (choicesError != null) throw ArgumentError(choicesError);
    if (type == 'phone' && !isValidPhoneAnswer(answer)) {
      throw ArgumentError(
        'phone answer must be 3-15 digits after normalisation',
      );
    }
    if (type == 'date' && !isValidDateAnswer(answer, today: _clock.now())) {
      throw ArgumentError(
        'date answer must be ISO YYYY-MM-DD in $kMinDateDay..today',
      );
    }
    final cleanAnswer = type == 'phone'
        ? normalizePhone(answer.trim())
        : answer.trim();
    return _CleanItem(
      prompt: prompt.trim(),
      answer: cleanAnswer,
      promptLang: promptLang,
      answerLang: answerLang,
      choicesJson: choices == null ? null : jsonEncode(choices),
    );
  }

  Future<void> _touchSet(int setId) async {
    await (_db.update(
      _db.questionSets,
    )..where((t) => t.id.equals(setId))).write(
      QuestionSetsCompanion(
        updatedAt: Value(_clock.now().millisecondsSinceEpoch),
      ),
    );
  }
}

class _CleanItem {
  final String prompt;
  final String answer;
  final String? promptLang;
  final String? answerLang;
  final String? choicesJson;
  _CleanItem({
    required this.prompt,
    required this.answer,
    required this.promptLang,
    required this.answerLang,
    required this.choicesJson,
  });
}
