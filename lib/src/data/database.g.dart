// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $QuestionSetsTable extends QuestionSets
    with TableInfo<$QuestionSetsTable, QuestionSet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuestionSetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    description,
    createdBy,
    createdAt,
    updatedAt,
    category,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'question_sets';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuestionSet> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QuestionSet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuestionSet(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
    );
  }

  @override
  $QuestionSetsTable createAlias(String alias) {
    return $QuestionSetsTable(attachedDatabase, alias);
  }
}

class QuestionSet extends DataClass implements Insertable<QuestionSet> {
  final int id;
  final String title;
  final String description;
  final String createdBy;
  final int createdAt;
  final int updatedAt;
  final String? category;
  const QuestionSet({
    required this.id,
    required this.title,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.category,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['created_by'] = Variable<String>(createdBy);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    return map;
  }

  QuestionSetsCompanion toCompanion(bool nullToAbsent) {
    return QuestionSetsCompanion(
      id: Value(id),
      title: Value(title),
      description: Value(description),
      createdBy: Value(createdBy),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
    );
  }

  factory QuestionSet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuestionSet(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      category: serializer.fromJson<String?>(json['category']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'createdBy': serializer.toJson<String>(createdBy),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'category': serializer.toJson<String?>(category),
    };
  }

  QuestionSet copyWith({
    int? id,
    String? title,
    String? description,
    String? createdBy,
    int? createdAt,
    int? updatedAt,
    Value<String?> category = const Value.absent(),
  }) => QuestionSet(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    category: category.present ? category.value : this.category,
  );
  QuestionSet copyWithCompanion(QuestionSetsCompanion data) {
    return QuestionSet(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      category: data.category.present ? data.category.value : this.category,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuestionSet(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('category: $category')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    createdBy,
    createdAt,
    updatedAt,
    category,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuestionSet &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.createdBy == this.createdBy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.category == this.category);
}

class QuestionSetsCompanion extends UpdateCompanion<QuestionSet> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> description;
  final Value<String> createdBy;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String?> category;
  const QuestionSetsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.category = const Value.absent(),
  });
  QuestionSetsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    this.description = const Value.absent(),
    required String createdBy,
    required int createdAt,
    required int updatedAt,
    this.category = const Value.absent(),
  }) : title = Value(title),
       createdBy = Value(createdBy),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<QuestionSet> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? createdBy,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? category,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (category != null) 'category': category,
    });
  }

  QuestionSetsCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? description,
    Value<String>? createdBy,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String?>? category,
  }) {
    return QuestionSetsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      category: category ?? this.category,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuestionSetsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('category: $category')
          ..write(')'))
        .toString();
  }
}

class $ItemsTable extends Items with TableInfo<$ItemsTable, Item> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _setIdMeta = const VerificationMeta('setId');
  @override
  late final GeneratedColumn<int> setId = GeneratedColumn<int>(
    'set_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES question_sets (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _promptMeta = const VerificationMeta('prompt');
  @override
  late final GeneratedColumn<String> prompt = GeneratedColumn<String>(
    'prompt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answerMeta = const VerificationMeta('answer');
  @override
  late final GeneratedColumn<String> answer = GeneratedColumn<String>(
    'answer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _promptLangMeta = const VerificationMeta(
    'promptLang',
  );
  @override
  late final GeneratedColumn<String> promptLang = GeneratedColumn<String>(
    'prompt_lang',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _answerLangMeta = const VerificationMeta(
    'answerLang',
  );
  @override
  late final GeneratedColumn<String> answerLang = GeneratedColumn<String>(
    'answer_lang',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _choicesMeta = const VerificationMeta(
    'choices',
  );
  @override
  late final GeneratedColumn<String> choices = GeneratedColumn<String>(
    'choices',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hintMeta = const VerificationMeta('hint');
  @override
  late final GeneratedColumn<String> hint = GeneratedColumn<String>(
    'hint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    setId,
    type,
    prompt,
    answer,
    promptLang,
    answerLang,
    choices,
    hint,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'items';
  @override
  VerificationContext validateIntegrity(
    Insertable<Item> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('set_id')) {
      context.handle(
        _setIdMeta,
        setId.isAcceptableOrUnknown(data['set_id']!, _setIdMeta),
      );
    } else if (isInserting) {
      context.missing(_setIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('prompt')) {
      context.handle(
        _promptMeta,
        prompt.isAcceptableOrUnknown(data['prompt']!, _promptMeta),
      );
    } else if (isInserting) {
      context.missing(_promptMeta);
    }
    if (data.containsKey('answer')) {
      context.handle(
        _answerMeta,
        answer.isAcceptableOrUnknown(data['answer']!, _answerMeta),
      );
    } else if (isInserting) {
      context.missing(_answerMeta);
    }
    if (data.containsKey('prompt_lang')) {
      context.handle(
        _promptLangMeta,
        promptLang.isAcceptableOrUnknown(data['prompt_lang']!, _promptLangMeta),
      );
    }
    if (data.containsKey('answer_lang')) {
      context.handle(
        _answerLangMeta,
        answerLang.isAcceptableOrUnknown(data['answer_lang']!, _answerLangMeta),
      );
    }
    if (data.containsKey('choices')) {
      context.handle(
        _choicesMeta,
        choices.isAcceptableOrUnknown(data['choices']!, _choicesMeta),
      );
    }
    if (data.containsKey('hint')) {
      context.handle(
        _hintMeta,
        hint.isAcceptableOrUnknown(data['hint']!, _hintMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Item map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Item(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      setId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}set_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      prompt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prompt'],
      )!,
      answer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer'],
      )!,
      promptLang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prompt_lang'],
      ),
      answerLang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer_lang'],
      ),
      choices: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}choices'],
      ),
      hint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hint'],
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $ItemsTable createAlias(String alias) {
    return $ItemsTable(attachedDatabase, alias);
  }
}

class Item extends DataClass implements Insertable<Item> {
  final int id;
  final int setId;
  final String type;
  final String prompt;
  final String answer;
  final String? promptLang;
  final String? answerLang;
  final String? choices;
  final String? hint;
  final int position;
  const Item({
    required this.id,
    required this.setId,
    required this.type,
    required this.prompt,
    required this.answer,
    this.promptLang,
    this.answerLang,
    this.choices,
    this.hint,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['set_id'] = Variable<int>(setId);
    map['type'] = Variable<String>(type);
    map['prompt'] = Variable<String>(prompt);
    map['answer'] = Variable<String>(answer);
    if (!nullToAbsent || promptLang != null) {
      map['prompt_lang'] = Variable<String>(promptLang);
    }
    if (!nullToAbsent || answerLang != null) {
      map['answer_lang'] = Variable<String>(answerLang);
    }
    if (!nullToAbsent || choices != null) {
      map['choices'] = Variable<String>(choices);
    }
    if (!nullToAbsent || hint != null) {
      map['hint'] = Variable<String>(hint);
    }
    map['position'] = Variable<int>(position);
    return map;
  }

  ItemsCompanion toCompanion(bool nullToAbsent) {
    return ItemsCompanion(
      id: Value(id),
      setId: Value(setId),
      type: Value(type),
      prompt: Value(prompt),
      answer: Value(answer),
      promptLang: promptLang == null && nullToAbsent
          ? const Value.absent()
          : Value(promptLang),
      answerLang: answerLang == null && nullToAbsent
          ? const Value.absent()
          : Value(answerLang),
      choices: choices == null && nullToAbsent
          ? const Value.absent()
          : Value(choices),
      hint: hint == null && nullToAbsent ? const Value.absent() : Value(hint),
      position: Value(position),
    );
  }

  factory Item.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Item(
      id: serializer.fromJson<int>(json['id']),
      setId: serializer.fromJson<int>(json['setId']),
      type: serializer.fromJson<String>(json['type']),
      prompt: serializer.fromJson<String>(json['prompt']),
      answer: serializer.fromJson<String>(json['answer']),
      promptLang: serializer.fromJson<String?>(json['promptLang']),
      answerLang: serializer.fromJson<String?>(json['answerLang']),
      choices: serializer.fromJson<String?>(json['choices']),
      hint: serializer.fromJson<String?>(json['hint']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'setId': serializer.toJson<int>(setId),
      'type': serializer.toJson<String>(type),
      'prompt': serializer.toJson<String>(prompt),
      'answer': serializer.toJson<String>(answer),
      'promptLang': serializer.toJson<String?>(promptLang),
      'answerLang': serializer.toJson<String?>(answerLang),
      'choices': serializer.toJson<String?>(choices),
      'hint': serializer.toJson<String?>(hint),
      'position': serializer.toJson<int>(position),
    };
  }

  Item copyWith({
    int? id,
    int? setId,
    String? type,
    String? prompt,
    String? answer,
    Value<String?> promptLang = const Value.absent(),
    Value<String?> answerLang = const Value.absent(),
    Value<String?> choices = const Value.absent(),
    Value<String?> hint = const Value.absent(),
    int? position,
  }) => Item(
    id: id ?? this.id,
    setId: setId ?? this.setId,
    type: type ?? this.type,
    prompt: prompt ?? this.prompt,
    answer: answer ?? this.answer,
    promptLang: promptLang.present ? promptLang.value : this.promptLang,
    answerLang: answerLang.present ? answerLang.value : this.answerLang,
    choices: choices.present ? choices.value : this.choices,
    hint: hint.present ? hint.value : this.hint,
    position: position ?? this.position,
  );
  Item copyWithCompanion(ItemsCompanion data) {
    return Item(
      id: data.id.present ? data.id.value : this.id,
      setId: data.setId.present ? data.setId.value : this.setId,
      type: data.type.present ? data.type.value : this.type,
      prompt: data.prompt.present ? data.prompt.value : this.prompt,
      answer: data.answer.present ? data.answer.value : this.answer,
      promptLang: data.promptLang.present
          ? data.promptLang.value
          : this.promptLang,
      answerLang: data.answerLang.present
          ? data.answerLang.value
          : this.answerLang,
      choices: data.choices.present ? data.choices.value : this.choices,
      hint: data.hint.present ? data.hint.value : this.hint,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Item(')
          ..write('id: $id, ')
          ..write('setId: $setId, ')
          ..write('type: $type, ')
          ..write('prompt: $prompt, ')
          ..write('answer: $answer, ')
          ..write('promptLang: $promptLang, ')
          ..write('answerLang: $answerLang, ')
          ..write('choices: $choices, ')
          ..write('hint: $hint, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    setId,
    type,
    prompt,
    answer,
    promptLang,
    answerLang,
    choices,
    hint,
    position,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Item &&
          other.id == this.id &&
          other.setId == this.setId &&
          other.type == this.type &&
          other.prompt == this.prompt &&
          other.answer == this.answer &&
          other.promptLang == this.promptLang &&
          other.answerLang == this.answerLang &&
          other.choices == this.choices &&
          other.hint == this.hint &&
          other.position == this.position);
}

class ItemsCompanion extends UpdateCompanion<Item> {
  final Value<int> id;
  final Value<int> setId;
  final Value<String> type;
  final Value<String> prompt;
  final Value<String> answer;
  final Value<String?> promptLang;
  final Value<String?> answerLang;
  final Value<String?> choices;
  final Value<String?> hint;
  final Value<int> position;
  const ItemsCompanion({
    this.id = const Value.absent(),
    this.setId = const Value.absent(),
    this.type = const Value.absent(),
    this.prompt = const Value.absent(),
    this.answer = const Value.absent(),
    this.promptLang = const Value.absent(),
    this.answerLang = const Value.absent(),
    this.choices = const Value.absent(),
    this.hint = const Value.absent(),
    this.position = const Value.absent(),
  });
  ItemsCompanion.insert({
    this.id = const Value.absent(),
    required int setId,
    required String type,
    required String prompt,
    required String answer,
    this.promptLang = const Value.absent(),
    this.answerLang = const Value.absent(),
    this.choices = const Value.absent(),
    this.hint = const Value.absent(),
    required int position,
  }) : setId = Value(setId),
       type = Value(type),
       prompt = Value(prompt),
       answer = Value(answer),
       position = Value(position);
  static Insertable<Item> custom({
    Expression<int>? id,
    Expression<int>? setId,
    Expression<String>? type,
    Expression<String>? prompt,
    Expression<String>? answer,
    Expression<String>? promptLang,
    Expression<String>? answerLang,
    Expression<String>? choices,
    Expression<String>? hint,
    Expression<int>? position,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (setId != null) 'set_id': setId,
      if (type != null) 'type': type,
      if (prompt != null) 'prompt': prompt,
      if (answer != null) 'answer': answer,
      if (promptLang != null) 'prompt_lang': promptLang,
      if (answerLang != null) 'answer_lang': answerLang,
      if (choices != null) 'choices': choices,
      if (hint != null) 'hint': hint,
      if (position != null) 'position': position,
    });
  }

  ItemsCompanion copyWith({
    Value<int>? id,
    Value<int>? setId,
    Value<String>? type,
    Value<String>? prompt,
    Value<String>? answer,
    Value<String?>? promptLang,
    Value<String?>? answerLang,
    Value<String?>? choices,
    Value<String?>? hint,
    Value<int>? position,
  }) {
    return ItemsCompanion(
      id: id ?? this.id,
      setId: setId ?? this.setId,
      type: type ?? this.type,
      prompt: prompt ?? this.prompt,
      answer: answer ?? this.answer,
      promptLang: promptLang ?? this.promptLang,
      answerLang: answerLang ?? this.answerLang,
      choices: choices ?? this.choices,
      hint: hint ?? this.hint,
      position: position ?? this.position,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (setId.present) {
      map['set_id'] = Variable<int>(setId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (prompt.present) {
      map['prompt'] = Variable<String>(prompt.value);
    }
    if (answer.present) {
      map['answer'] = Variable<String>(answer.value);
    }
    if (promptLang.present) {
      map['prompt_lang'] = Variable<String>(promptLang.value);
    }
    if (answerLang.present) {
      map['answer_lang'] = Variable<String>(answerLang.value);
    }
    if (choices.present) {
      map['choices'] = Variable<String>(choices.value);
    }
    if (hint.present) {
      map['hint'] = Variable<String>(hint.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemsCompanion(')
          ..write('id: $id, ')
          ..write('setId: $setId, ')
          ..write('type: $type, ')
          ..write('prompt: $prompt, ')
          ..write('answer: $answer, ')
          ..write('promptLang: $promptLang, ')
          ..write('answerLang: $answerLang, ')
          ..write('choices: $choices, ')
          ..write('hint: $hint, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }
}

class $AttemptsTable extends Attempts with TableInfo<$AttemptsTable, Attempt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttemptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<int> itemId = GeneratedColumn<int>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _okMeta = const VerificationMeta('ok');
  @override
  late final GeneratedColumn<bool> ok = GeneratedColumn<bool>(
    'ok',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("ok" IN (0, 1))',
    ),
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<int> at = GeneratedColumn<int>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, itemId, ok, at];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attempts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Attempt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('ok')) {
      context.handle(_okMeta, ok.isAcceptableOrUnknown(data['ok']!, _okMeta));
    } else if (isInserting) {
      context.missing(_okMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Attempt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Attempt(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_id'],
      )!,
      ok: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}ok'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at'],
      )!,
    );
  }

  @override
  $AttemptsTable createAlias(String alias) {
    return $AttemptsTable(attachedDatabase, alias);
  }
}

class Attempt extends DataClass implements Insertable<Attempt> {
  final int id;
  final int itemId;
  final bool ok;
  final int at;
  const Attempt({
    required this.id,
    required this.itemId,
    required this.ok,
    required this.at,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['item_id'] = Variable<int>(itemId);
    map['ok'] = Variable<bool>(ok);
    map['at'] = Variable<int>(at);
    return map;
  }

  AttemptsCompanion toCompanion(bool nullToAbsent) {
    return AttemptsCompanion(
      id: Value(id),
      itemId: Value(itemId),
      ok: Value(ok),
      at: Value(at),
    );
  }

  factory Attempt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Attempt(
      id: serializer.fromJson<int>(json['id']),
      itemId: serializer.fromJson<int>(json['itemId']),
      ok: serializer.fromJson<bool>(json['ok']),
      at: serializer.fromJson<int>(json['at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'itemId': serializer.toJson<int>(itemId),
      'ok': serializer.toJson<bool>(ok),
      'at': serializer.toJson<int>(at),
    };
  }

  Attempt copyWith({int? id, int? itemId, bool? ok, int? at}) => Attempt(
    id: id ?? this.id,
    itemId: itemId ?? this.itemId,
    ok: ok ?? this.ok,
    at: at ?? this.at,
  );
  Attempt copyWithCompanion(AttemptsCompanion data) {
    return Attempt(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      ok: data.ok.present ? data.ok.value : this.ok,
      at: data.at.present ? data.at.value : this.at,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Attempt(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('ok: $ok, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, itemId, ok, at);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Attempt &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.ok == this.ok &&
          other.at == this.at);
}

class AttemptsCompanion extends UpdateCompanion<Attempt> {
  final Value<int> id;
  final Value<int> itemId;
  final Value<bool> ok;
  final Value<int> at;
  const AttemptsCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.ok = const Value.absent(),
    this.at = const Value.absent(),
  });
  AttemptsCompanion.insert({
    this.id = const Value.absent(),
    required int itemId,
    required bool ok,
    required int at,
  }) : itemId = Value(itemId),
       ok = Value(ok),
       at = Value(at);
  static Insertable<Attempt> custom({
    Expression<int>? id,
    Expression<int>? itemId,
    Expression<bool>? ok,
    Expression<int>? at,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (ok != null) 'ok': ok,
      if (at != null) 'at': at,
    });
  }

  AttemptsCompanion copyWith({
    Value<int>? id,
    Value<int>? itemId,
    Value<bool>? ok,
    Value<int>? at,
  }) {
    return AttemptsCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      ok: ok ?? this.ok,
      at: at ?? this.at,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<int>(itemId.value);
    }
    if (ok.present) {
      map['ok'] = Variable<bool>(ok.value);
    }
    if (at.present) {
      map['at'] = Variable<int>(at.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttemptsCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('ok: $ok, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }
}

class $ProfileStatsTable extends ProfileStats
    with TableInfo<$ProfileStatsTable, ProfileStat> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfileStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _xpTotalMeta = const VerificationMeta(
    'xpTotal',
  );
  @override
  late final GeneratedColumn<int> xpTotal = GeneratedColumn<int>(
    'xp_total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _streakCountMeta = const VerificationMeta(
    'streakCount',
  );
  @override
  late final GeneratedColumn<int> streakCount = GeneratedColumn<int>(
    'streak_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastActiveDayMeta = const VerificationMeta(
    'lastActiveDay',
  );
  @override
  late final GeneratedColumn<String> lastActiveDay = GeneratedColumn<String>(
    'last_active_day',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dailyGoalXpMeta = const VerificationMeta(
    'dailyGoalXp',
  );
  @override
  late final GeneratedColumn<int> dailyGoalXp = GeneratedColumn<int>(
    'daily_goal_xp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(100),
  );
  static const VerificationMeta _todayXpMeta = const VerificationMeta(
    'todayXp',
  );
  @override
  late final GeneratedColumn<int> todayXp = GeneratedColumn<int>(
    'today_xp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hasOnboardedMeta = const VerificationMeta(
    'hasOnboarded',
  );
  @override
  late final GeneratedColumn<bool> hasOnboarded = GeneratedColumn<bool>(
    'has_onboarded',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_onboarded" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _equippedMascotIdMeta = const VerificationMeta(
    'equippedMascotId',
  );
  @override
  late final GeneratedColumn<String> equippedMascotId = GeneratedColumn<String>(
    'equipped_mascot_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(kDefaultMascotId),
  );
  static const VerificationMeta _lessonsCompletedTodayMeta =
      const VerificationMeta('lessonsCompletedToday');
  @override
  late final GeneratedColumn<int> lessonsCompletedToday = GeneratedColumn<int>(
    'lessons_completed_today',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lessonsCompletedDayMeta =
      const VerificationMeta('lessonsCompletedDay');
  @override
  late final GeneratedColumn<String> lessonsCompletedDay =
      GeneratedColumn<String>(
        'lessons_completed_day',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    xpTotal,
    streakCount,
    lastActiveDay,
    dailyGoalXp,
    todayXp,
    displayName,
    hasOnboarded,
    equippedMascotId,
    lessonsCompletedToday,
    lessonsCompletedDay,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profile_stats';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProfileStat> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('xp_total')) {
      context.handle(
        _xpTotalMeta,
        xpTotal.isAcceptableOrUnknown(data['xp_total']!, _xpTotalMeta),
      );
    }
    if (data.containsKey('streak_count')) {
      context.handle(
        _streakCountMeta,
        streakCount.isAcceptableOrUnknown(
          data['streak_count']!,
          _streakCountMeta,
        ),
      );
    }
    if (data.containsKey('last_active_day')) {
      context.handle(
        _lastActiveDayMeta,
        lastActiveDay.isAcceptableOrUnknown(
          data['last_active_day']!,
          _lastActiveDayMeta,
        ),
      );
    }
    if (data.containsKey('daily_goal_xp')) {
      context.handle(
        _dailyGoalXpMeta,
        dailyGoalXp.isAcceptableOrUnknown(
          data['daily_goal_xp']!,
          _dailyGoalXpMeta,
        ),
      );
    }
    if (data.containsKey('today_xp')) {
      context.handle(
        _todayXpMeta,
        todayXp.isAcceptableOrUnknown(data['today_xp']!, _todayXpMeta),
      );
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('has_onboarded')) {
      context.handle(
        _hasOnboardedMeta,
        hasOnboarded.isAcceptableOrUnknown(
          data['has_onboarded']!,
          _hasOnboardedMeta,
        ),
      );
    }
    if (data.containsKey('equipped_mascot_id')) {
      context.handle(
        _equippedMascotIdMeta,
        equippedMascotId.isAcceptableOrUnknown(
          data['equipped_mascot_id']!,
          _equippedMascotIdMeta,
        ),
      );
    }
    if (data.containsKey('lessons_completed_today')) {
      context.handle(
        _lessonsCompletedTodayMeta,
        lessonsCompletedToday.isAcceptableOrUnknown(
          data['lessons_completed_today']!,
          _lessonsCompletedTodayMeta,
        ),
      );
    }
    if (data.containsKey('lessons_completed_day')) {
      context.handle(
        _lessonsCompletedDayMeta,
        lessonsCompletedDay.isAcceptableOrUnknown(
          data['lessons_completed_day']!,
          _lessonsCompletedDayMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProfileStat map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProfileStat(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      xpTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}xp_total'],
      )!,
      streakCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}streak_count'],
      )!,
      lastActiveDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_active_day'],
      ),
      dailyGoalXp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}daily_goal_xp'],
      )!,
      todayXp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}today_xp'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      hasOnboarded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_onboarded'],
      )!,
      equippedMascotId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}equipped_mascot_id'],
      )!,
      lessonsCompletedToday: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lessons_completed_today'],
      )!,
      lessonsCompletedDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lessons_completed_day'],
      ),
    );
  }

  @override
  $ProfileStatsTable createAlias(String alias) {
    return $ProfileStatsTable(attachedDatabase, alias);
  }
}

class ProfileStat extends DataClass implements Insertable<ProfileStat> {
  final int id;
  final int xpTotal;
  final int streakCount;
  final String? lastActiveDay;
  final int dailyGoalXp;
  final int todayXp;
  final String? displayName;
  final bool hasOnboarded;
  final String equippedMascotId;
  final int lessonsCompletedToday;
  final String? lessonsCompletedDay;
  const ProfileStat({
    required this.id,
    required this.xpTotal,
    required this.streakCount,
    this.lastActiveDay,
    required this.dailyGoalXp,
    required this.todayXp,
    this.displayName,
    required this.hasOnboarded,
    required this.equippedMascotId,
    required this.lessonsCompletedToday,
    this.lessonsCompletedDay,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['xp_total'] = Variable<int>(xpTotal);
    map['streak_count'] = Variable<int>(streakCount);
    if (!nullToAbsent || lastActiveDay != null) {
      map['last_active_day'] = Variable<String>(lastActiveDay);
    }
    map['daily_goal_xp'] = Variable<int>(dailyGoalXp);
    map['today_xp'] = Variable<int>(todayXp);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    map['has_onboarded'] = Variable<bool>(hasOnboarded);
    map['equipped_mascot_id'] = Variable<String>(equippedMascotId);
    map['lessons_completed_today'] = Variable<int>(lessonsCompletedToday);
    if (!nullToAbsent || lessonsCompletedDay != null) {
      map['lessons_completed_day'] = Variable<String>(lessonsCompletedDay);
    }
    return map;
  }

  ProfileStatsCompanion toCompanion(bool nullToAbsent) {
    return ProfileStatsCompanion(
      id: Value(id),
      xpTotal: Value(xpTotal),
      streakCount: Value(streakCount),
      lastActiveDay: lastActiveDay == null && nullToAbsent
          ? const Value.absent()
          : Value(lastActiveDay),
      dailyGoalXp: Value(dailyGoalXp),
      todayXp: Value(todayXp),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      hasOnboarded: Value(hasOnboarded),
      equippedMascotId: Value(equippedMascotId),
      lessonsCompletedToday: Value(lessonsCompletedToday),
      lessonsCompletedDay: lessonsCompletedDay == null && nullToAbsent
          ? const Value.absent()
          : Value(lessonsCompletedDay),
    );
  }

  factory ProfileStat.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProfileStat(
      id: serializer.fromJson<int>(json['id']),
      xpTotal: serializer.fromJson<int>(json['xpTotal']),
      streakCount: serializer.fromJson<int>(json['streakCount']),
      lastActiveDay: serializer.fromJson<String?>(json['lastActiveDay']),
      dailyGoalXp: serializer.fromJson<int>(json['dailyGoalXp']),
      todayXp: serializer.fromJson<int>(json['todayXp']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      hasOnboarded: serializer.fromJson<bool>(json['hasOnboarded']),
      equippedMascotId: serializer.fromJson<String>(json['equippedMascotId']),
      lessonsCompletedToday: serializer.fromJson<int>(
        json['lessonsCompletedToday'],
      ),
      lessonsCompletedDay: serializer.fromJson<String?>(
        json['lessonsCompletedDay'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'xpTotal': serializer.toJson<int>(xpTotal),
      'streakCount': serializer.toJson<int>(streakCount),
      'lastActiveDay': serializer.toJson<String?>(lastActiveDay),
      'dailyGoalXp': serializer.toJson<int>(dailyGoalXp),
      'todayXp': serializer.toJson<int>(todayXp),
      'displayName': serializer.toJson<String?>(displayName),
      'hasOnboarded': serializer.toJson<bool>(hasOnboarded),
      'equippedMascotId': serializer.toJson<String>(equippedMascotId),
      'lessonsCompletedToday': serializer.toJson<int>(lessonsCompletedToday),
      'lessonsCompletedDay': serializer.toJson<String?>(lessonsCompletedDay),
    };
  }

  ProfileStat copyWith({
    int? id,
    int? xpTotal,
    int? streakCount,
    Value<String?> lastActiveDay = const Value.absent(),
    int? dailyGoalXp,
    int? todayXp,
    Value<String?> displayName = const Value.absent(),
    bool? hasOnboarded,
    String? equippedMascotId,
    int? lessonsCompletedToday,
    Value<String?> lessonsCompletedDay = const Value.absent(),
  }) => ProfileStat(
    id: id ?? this.id,
    xpTotal: xpTotal ?? this.xpTotal,
    streakCount: streakCount ?? this.streakCount,
    lastActiveDay: lastActiveDay.present
        ? lastActiveDay.value
        : this.lastActiveDay,
    dailyGoalXp: dailyGoalXp ?? this.dailyGoalXp,
    todayXp: todayXp ?? this.todayXp,
    displayName: displayName.present ? displayName.value : this.displayName,
    hasOnboarded: hasOnboarded ?? this.hasOnboarded,
    equippedMascotId: equippedMascotId ?? this.equippedMascotId,
    lessonsCompletedToday: lessonsCompletedToday ?? this.lessonsCompletedToday,
    lessonsCompletedDay: lessonsCompletedDay.present
        ? lessonsCompletedDay.value
        : this.lessonsCompletedDay,
  );
  ProfileStat copyWithCompanion(ProfileStatsCompanion data) {
    return ProfileStat(
      id: data.id.present ? data.id.value : this.id,
      xpTotal: data.xpTotal.present ? data.xpTotal.value : this.xpTotal,
      streakCount: data.streakCount.present
          ? data.streakCount.value
          : this.streakCount,
      lastActiveDay: data.lastActiveDay.present
          ? data.lastActiveDay.value
          : this.lastActiveDay,
      dailyGoalXp: data.dailyGoalXp.present
          ? data.dailyGoalXp.value
          : this.dailyGoalXp,
      todayXp: data.todayXp.present ? data.todayXp.value : this.todayXp,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      hasOnboarded: data.hasOnboarded.present
          ? data.hasOnboarded.value
          : this.hasOnboarded,
      equippedMascotId: data.equippedMascotId.present
          ? data.equippedMascotId.value
          : this.equippedMascotId,
      lessonsCompletedToday: data.lessonsCompletedToday.present
          ? data.lessonsCompletedToday.value
          : this.lessonsCompletedToday,
      lessonsCompletedDay: data.lessonsCompletedDay.present
          ? data.lessonsCompletedDay.value
          : this.lessonsCompletedDay,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProfileStat(')
          ..write('id: $id, ')
          ..write('xpTotal: $xpTotal, ')
          ..write('streakCount: $streakCount, ')
          ..write('lastActiveDay: $lastActiveDay, ')
          ..write('dailyGoalXp: $dailyGoalXp, ')
          ..write('todayXp: $todayXp, ')
          ..write('displayName: $displayName, ')
          ..write('hasOnboarded: $hasOnboarded, ')
          ..write('equippedMascotId: $equippedMascotId, ')
          ..write('lessonsCompletedToday: $lessonsCompletedToday, ')
          ..write('lessonsCompletedDay: $lessonsCompletedDay')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    xpTotal,
    streakCount,
    lastActiveDay,
    dailyGoalXp,
    todayXp,
    displayName,
    hasOnboarded,
    equippedMascotId,
    lessonsCompletedToday,
    lessonsCompletedDay,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileStat &&
          other.id == this.id &&
          other.xpTotal == this.xpTotal &&
          other.streakCount == this.streakCount &&
          other.lastActiveDay == this.lastActiveDay &&
          other.dailyGoalXp == this.dailyGoalXp &&
          other.todayXp == this.todayXp &&
          other.displayName == this.displayName &&
          other.hasOnboarded == this.hasOnboarded &&
          other.equippedMascotId == this.equippedMascotId &&
          other.lessonsCompletedToday == this.lessonsCompletedToday &&
          other.lessonsCompletedDay == this.lessonsCompletedDay);
}

class ProfileStatsCompanion extends UpdateCompanion<ProfileStat> {
  final Value<int> id;
  final Value<int> xpTotal;
  final Value<int> streakCount;
  final Value<String?> lastActiveDay;
  final Value<int> dailyGoalXp;
  final Value<int> todayXp;
  final Value<String?> displayName;
  final Value<bool> hasOnboarded;
  final Value<String> equippedMascotId;
  final Value<int> lessonsCompletedToday;
  final Value<String?> lessonsCompletedDay;
  const ProfileStatsCompanion({
    this.id = const Value.absent(),
    this.xpTotal = const Value.absent(),
    this.streakCount = const Value.absent(),
    this.lastActiveDay = const Value.absent(),
    this.dailyGoalXp = const Value.absent(),
    this.todayXp = const Value.absent(),
    this.displayName = const Value.absent(),
    this.hasOnboarded = const Value.absent(),
    this.equippedMascotId = const Value.absent(),
    this.lessonsCompletedToday = const Value.absent(),
    this.lessonsCompletedDay = const Value.absent(),
  });
  ProfileStatsCompanion.insert({
    this.id = const Value.absent(),
    this.xpTotal = const Value.absent(),
    this.streakCount = const Value.absent(),
    this.lastActiveDay = const Value.absent(),
    this.dailyGoalXp = const Value.absent(),
    this.todayXp = const Value.absent(),
    this.displayName = const Value.absent(),
    this.hasOnboarded = const Value.absent(),
    this.equippedMascotId = const Value.absent(),
    this.lessonsCompletedToday = const Value.absent(),
    this.lessonsCompletedDay = const Value.absent(),
  });
  static Insertable<ProfileStat> custom({
    Expression<int>? id,
    Expression<int>? xpTotal,
    Expression<int>? streakCount,
    Expression<String>? lastActiveDay,
    Expression<int>? dailyGoalXp,
    Expression<int>? todayXp,
    Expression<String>? displayName,
    Expression<bool>? hasOnboarded,
    Expression<String>? equippedMascotId,
    Expression<int>? lessonsCompletedToday,
    Expression<String>? lessonsCompletedDay,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (xpTotal != null) 'xp_total': xpTotal,
      if (streakCount != null) 'streak_count': streakCount,
      if (lastActiveDay != null) 'last_active_day': lastActiveDay,
      if (dailyGoalXp != null) 'daily_goal_xp': dailyGoalXp,
      if (todayXp != null) 'today_xp': todayXp,
      if (displayName != null) 'display_name': displayName,
      if (hasOnboarded != null) 'has_onboarded': hasOnboarded,
      if (equippedMascotId != null) 'equipped_mascot_id': equippedMascotId,
      if (lessonsCompletedToday != null)
        'lessons_completed_today': lessonsCompletedToday,
      if (lessonsCompletedDay != null)
        'lessons_completed_day': lessonsCompletedDay,
    });
  }

  ProfileStatsCompanion copyWith({
    Value<int>? id,
    Value<int>? xpTotal,
    Value<int>? streakCount,
    Value<String?>? lastActiveDay,
    Value<int>? dailyGoalXp,
    Value<int>? todayXp,
    Value<String?>? displayName,
    Value<bool>? hasOnboarded,
    Value<String>? equippedMascotId,
    Value<int>? lessonsCompletedToday,
    Value<String?>? lessonsCompletedDay,
  }) {
    return ProfileStatsCompanion(
      id: id ?? this.id,
      xpTotal: xpTotal ?? this.xpTotal,
      streakCount: streakCount ?? this.streakCount,
      lastActiveDay: lastActiveDay ?? this.lastActiveDay,
      dailyGoalXp: dailyGoalXp ?? this.dailyGoalXp,
      todayXp: todayXp ?? this.todayXp,
      displayName: displayName ?? this.displayName,
      hasOnboarded: hasOnboarded ?? this.hasOnboarded,
      equippedMascotId: equippedMascotId ?? this.equippedMascotId,
      lessonsCompletedToday:
          lessonsCompletedToday ?? this.lessonsCompletedToday,
      lessonsCompletedDay: lessonsCompletedDay ?? this.lessonsCompletedDay,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (xpTotal.present) {
      map['xp_total'] = Variable<int>(xpTotal.value);
    }
    if (streakCount.present) {
      map['streak_count'] = Variable<int>(streakCount.value);
    }
    if (lastActiveDay.present) {
      map['last_active_day'] = Variable<String>(lastActiveDay.value);
    }
    if (dailyGoalXp.present) {
      map['daily_goal_xp'] = Variable<int>(dailyGoalXp.value);
    }
    if (todayXp.present) {
      map['today_xp'] = Variable<int>(todayXp.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (hasOnboarded.present) {
      map['has_onboarded'] = Variable<bool>(hasOnboarded.value);
    }
    if (equippedMascotId.present) {
      map['equipped_mascot_id'] = Variable<String>(equippedMascotId.value);
    }
    if (lessonsCompletedToday.present) {
      map['lessons_completed_today'] = Variable<int>(
        lessonsCompletedToday.value,
      );
    }
    if (lessonsCompletedDay.present) {
      map['lessons_completed_day'] = Variable<String>(
        lessonsCompletedDay.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfileStatsCompanion(')
          ..write('id: $id, ')
          ..write('xpTotal: $xpTotal, ')
          ..write('streakCount: $streakCount, ')
          ..write('lastActiveDay: $lastActiveDay, ')
          ..write('dailyGoalXp: $dailyGoalXp, ')
          ..write('todayXp: $todayXp, ')
          ..write('displayName: $displayName, ')
          ..write('hasOnboarded: $hasOnboarded, ')
          ..write('equippedMascotId: $equippedMascotId, ')
          ..write('lessonsCompletedToday: $lessonsCompletedToday, ')
          ..write('lessonsCompletedDay: $lessonsCompletedDay')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hapticsEnabledMeta = const VerificationMeta(
    'hapticsEnabled',
  );
  @override
  late final GeneratedColumn<bool> hapticsEnabled = GeneratedColumn<bool>(
    'haptics_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("haptics_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _soundEnabledMeta = const VerificationMeta(
    'soundEnabled',
  );
  @override
  late final GeneratedColumn<bool> soundEnabled = GeneratedColumn<bool>(
    'sound_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sound_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [id, hapticsEnabled, soundEnabled];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('haptics_enabled')) {
      context.handle(
        _hapticsEnabledMeta,
        hapticsEnabled.isAcceptableOrUnknown(
          data['haptics_enabled']!,
          _hapticsEnabledMeta,
        ),
      );
    }
    if (data.containsKey('sound_enabled')) {
      context.handle(
        _soundEnabledMeta,
        soundEnabled.isAcceptableOrUnknown(
          data['sound_enabled']!,
          _soundEnabledMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      hapticsEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}haptics_enabled'],
      )!,
      soundEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sound_enabled'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final int id;
  final bool hapticsEnabled;
  final bool soundEnabled;
  const AppSetting({
    required this.id,
    required this.hapticsEnabled,
    required this.soundEnabled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['haptics_enabled'] = Variable<bool>(hapticsEnabled);
    map['sound_enabled'] = Variable<bool>(soundEnabled);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      id: Value(id),
      hapticsEnabled: Value(hapticsEnabled),
      soundEnabled: Value(soundEnabled),
    );
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      id: serializer.fromJson<int>(json['id']),
      hapticsEnabled: serializer.fromJson<bool>(json['hapticsEnabled']),
      soundEnabled: serializer.fromJson<bool>(json['soundEnabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'hapticsEnabled': serializer.toJson<bool>(hapticsEnabled),
      'soundEnabled': serializer.toJson<bool>(soundEnabled),
    };
  }

  AppSetting copyWith({int? id, bool? hapticsEnabled, bool? soundEnabled}) =>
      AppSetting(
        id: id ?? this.id,
        hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
        soundEnabled: soundEnabled ?? this.soundEnabled,
      );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      id: data.id.present ? data.id.value : this.id,
      hapticsEnabled: data.hapticsEnabled.present
          ? data.hapticsEnabled.value
          : this.hapticsEnabled,
      soundEnabled: data.soundEnabled.present
          ? data.soundEnabled.value
          : this.soundEnabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('id: $id, ')
          ..write('hapticsEnabled: $hapticsEnabled, ')
          ..write('soundEnabled: $soundEnabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, hapticsEnabled, soundEnabled);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.id == this.id &&
          other.hapticsEnabled == this.hapticsEnabled &&
          other.soundEnabled == this.soundEnabled);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<int> id;
  final Value<bool> hapticsEnabled;
  final Value<bool> soundEnabled;
  const AppSettingsCompanion({
    this.id = const Value.absent(),
    this.hapticsEnabled = const Value.absent(),
    this.soundEnabled = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.hapticsEnabled = const Value.absent(),
    this.soundEnabled = const Value.absent(),
  });
  static Insertable<AppSetting> custom({
    Expression<int>? id,
    Expression<bool>? hapticsEnabled,
    Expression<bool>? soundEnabled,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (hapticsEnabled != null) 'haptics_enabled': hapticsEnabled,
      if (soundEnabled != null) 'sound_enabled': soundEnabled,
    });
  }

  AppSettingsCompanion copyWith({
    Value<int>? id,
    Value<bool>? hapticsEnabled,
    Value<bool>? soundEnabled,
  }) {
    return AppSettingsCompanion(
      id: id ?? this.id,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (hapticsEnabled.present) {
      map['haptics_enabled'] = Variable<bool>(hapticsEnabled.value);
    }
    if (soundEnabled.present) {
      map['sound_enabled'] = Variable<bool>(soundEnabled.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('id: $id, ')
          ..write('hapticsEnabled: $hapticsEnabled, ')
          ..write('soundEnabled: $soundEnabled')
          ..write(')'))
        .toString();
  }
}

class $OwnedMascotsTable extends OwnedMascots
    with TableInfo<$OwnedMascotsTable, OwnedMascot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OwnedMascotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mascotIdMeta = const VerificationMeta(
    'mascotId',
  );
  @override
  late final GeneratedColumn<String> mascotId = GeneratedColumn<String>(
    'mascot_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _acquiredAtMeta = const VerificationMeta(
    'acquiredAt',
  );
  @override
  late final GeneratedColumn<int> acquiredAt = GeneratedColumn<int>(
    'acquired_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [mascotId, acquiredAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'owned_mascots';
  @override
  VerificationContext validateIntegrity(
    Insertable<OwnedMascot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('mascot_id')) {
      context.handle(
        _mascotIdMeta,
        mascotId.isAcceptableOrUnknown(data['mascot_id']!, _mascotIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mascotIdMeta);
    }
    if (data.containsKey('acquired_at')) {
      context.handle(
        _acquiredAtMeta,
        acquiredAt.isAcceptableOrUnknown(data['acquired_at']!, _acquiredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_acquiredAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mascotId};
  @override
  OwnedMascot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OwnedMascot(
      mascotId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mascot_id'],
      )!,
      acquiredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}acquired_at'],
      )!,
    );
  }

  @override
  $OwnedMascotsTable createAlias(String alias) {
    return $OwnedMascotsTable(attachedDatabase, alias);
  }
}

class OwnedMascot extends DataClass implements Insertable<OwnedMascot> {
  final String mascotId;
  final int acquiredAt;
  const OwnedMascot({required this.mascotId, required this.acquiredAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['mascot_id'] = Variable<String>(mascotId);
    map['acquired_at'] = Variable<int>(acquiredAt);
    return map;
  }

  OwnedMascotsCompanion toCompanion(bool nullToAbsent) {
    return OwnedMascotsCompanion(
      mascotId: Value(mascotId),
      acquiredAt: Value(acquiredAt),
    );
  }

  factory OwnedMascot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OwnedMascot(
      mascotId: serializer.fromJson<String>(json['mascotId']),
      acquiredAt: serializer.fromJson<int>(json['acquiredAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mascotId': serializer.toJson<String>(mascotId),
      'acquiredAt': serializer.toJson<int>(acquiredAt),
    };
  }

  OwnedMascot copyWith({String? mascotId, int? acquiredAt}) => OwnedMascot(
    mascotId: mascotId ?? this.mascotId,
    acquiredAt: acquiredAt ?? this.acquiredAt,
  );
  OwnedMascot copyWithCompanion(OwnedMascotsCompanion data) {
    return OwnedMascot(
      mascotId: data.mascotId.present ? data.mascotId.value : this.mascotId,
      acquiredAt: data.acquiredAt.present
          ? data.acquiredAt.value
          : this.acquiredAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OwnedMascot(')
          ..write('mascotId: $mascotId, ')
          ..write('acquiredAt: $acquiredAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(mascotId, acquiredAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OwnedMascot &&
          other.mascotId == this.mascotId &&
          other.acquiredAt == this.acquiredAt);
}

class OwnedMascotsCompanion extends UpdateCompanion<OwnedMascot> {
  final Value<String> mascotId;
  final Value<int> acquiredAt;
  final Value<int> rowid;
  const OwnedMascotsCompanion({
    this.mascotId = const Value.absent(),
    this.acquiredAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OwnedMascotsCompanion.insert({
    required String mascotId,
    required int acquiredAt,
    this.rowid = const Value.absent(),
  }) : mascotId = Value(mascotId),
       acquiredAt = Value(acquiredAt);
  static Insertable<OwnedMascot> custom({
    Expression<String>? mascotId,
    Expression<int>? acquiredAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mascotId != null) 'mascot_id': mascotId,
      if (acquiredAt != null) 'acquired_at': acquiredAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OwnedMascotsCompanion copyWith({
    Value<String>? mascotId,
    Value<int>? acquiredAt,
    Value<int>? rowid,
  }) {
    return OwnedMascotsCompanion(
      mascotId: mascotId ?? this.mascotId,
      acquiredAt: acquiredAt ?? this.acquiredAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mascotId.present) {
      map['mascot_id'] = Variable<String>(mascotId.value);
    }
    if (acquiredAt.present) {
      map['acquired_at'] = Variable<int>(acquiredAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OwnedMascotsCompanion(')
          ..write('mascotId: $mascotId, ')
          ..write('acquiredAt: $acquiredAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $QuestionSetsTable questionSets = $QuestionSetsTable(this);
  late final $ItemsTable items = $ItemsTable(this);
  late final $AttemptsTable attempts = $AttemptsTable(this);
  late final $ProfileStatsTable profileStats = $ProfileStatsTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $OwnedMascotsTable ownedMascots = $OwnedMascotsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    questionSets,
    items,
    attempts,
    profileStats,
    appSettings,
    ownedMascots,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'question_sets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('attempts', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$QuestionSetsTableCreateCompanionBuilder =
    QuestionSetsCompanion Function({
      Value<int> id,
      required String title,
      Value<String> description,
      required String createdBy,
      required int createdAt,
      required int updatedAt,
      Value<String?> category,
    });
typedef $$QuestionSetsTableUpdateCompanionBuilder =
    QuestionSetsCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String> description,
      Value<String> createdBy,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<String?> category,
    });

final class $$QuestionSetsTableReferences
    extends BaseReferences<_$AppDatabase, $QuestionSetsTable, QuestionSet> {
  $$QuestionSetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ItemsTable, List<Item>> _itemsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.items,
    aliasName: 'question_sets__id__items__set_id',
  );

  $$ItemsTableProcessedTableManager get itemsRefs {
    final manager = $$ItemsTableTableManager(
      $_db,
      $_db.items,
    ).filter((f) => f.setId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_itemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$QuestionSetsTableFilterComposer
    extends Composer<_$AppDatabase, $QuestionSetsTable> {
  $$QuestionSetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> itemsRefs(
    Expression<bool> Function($$ItemsTableFilterComposer f) f,
  ) {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.setId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableFilterComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$QuestionSetsTableOrderingComposer
    extends Composer<_$AppDatabase, $QuestionSetsTable> {
  $$QuestionSetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QuestionSetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuestionSetsTable> {
  $$QuestionSetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  Expression<T> itemsRefs<T extends Object>(
    Expression<T> Function($$ItemsTableAnnotationComposer a) f,
  ) {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.setId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$QuestionSetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QuestionSetsTable,
          QuestionSet,
          $$QuestionSetsTableFilterComposer,
          $$QuestionSetsTableOrderingComposer,
          $$QuestionSetsTableAnnotationComposer,
          $$QuestionSetsTableCreateCompanionBuilder,
          $$QuestionSetsTableUpdateCompanionBuilder,
          (QuestionSet, $$QuestionSetsTableReferences),
          QuestionSet,
          PrefetchHooks Function({bool itemsRefs})
        > {
  $$QuestionSetsTableTableManager(_$AppDatabase db, $QuestionSetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuestionSetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuestionSetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuestionSetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String?> category = const Value.absent(),
              }) => QuestionSetsCompanion(
                id: id,
                title: title,
                description: description,
                createdBy: createdBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                category: category,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                Value<String> description = const Value.absent(),
                required String createdBy,
                required int createdAt,
                required int updatedAt,
                Value<String?> category = const Value.absent(),
              }) => QuestionSetsCompanion.insert(
                id: id,
                title: title,
                description: description,
                createdBy: createdBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                category: category,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$QuestionSetsTable, QuestionSet>(table),
                  $$QuestionSetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (itemsRefs) db.items],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (itemsRefs)
                    await $_getPrefetchedData<
                      QuestionSet,
                      $QuestionSetsTable,
                      Item
                    >(
                      currentTable: table,
                      referencedTable: $$QuestionSetsTableReferences
                          ._itemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$QuestionSetsTableReferences(
                            db,
                            table,
                            p0,
                          ).itemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.setId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$QuestionSetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QuestionSetsTable,
      QuestionSet,
      $$QuestionSetsTableFilterComposer,
      $$QuestionSetsTableOrderingComposer,
      $$QuestionSetsTableAnnotationComposer,
      $$QuestionSetsTableCreateCompanionBuilder,
      $$QuestionSetsTableUpdateCompanionBuilder,
      (QuestionSet, $$QuestionSetsTableReferences),
      QuestionSet,
      PrefetchHooks Function({bool itemsRefs})
    >;
typedef $$ItemsTableCreateCompanionBuilder = ItemsCompanion Function({
  Value<int> id,
  required int setId,
  required String type,
  required String prompt,
  required String answer,
  Value<String?> promptLang,
  Value<String?> answerLang,
  Value<String?> choices,
  Value<String?> hint,
  required int position,
});
typedef $$ItemsTableUpdateCompanionBuilder = ItemsCompanion Function({
  Value<int> id,
  Value<int> setId,
  Value<String> type,
  Value<String> prompt,
  Value<String> answer,
  Value<String?> promptLang,
  Value<String?> answerLang,
  Value<String?> choices,
  Value<String?> hint,
  Value<int> position,
});

final class $$ItemsTableReferences
    extends BaseReferences<_$AppDatabase, $ItemsTable, Item> {
  $$ItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $QuestionSetsTable _setIdTable(_$AppDatabase db) =>
      db.questionSets.createAlias('items__set_id__question_sets__id');

  $$QuestionSetsTableProcessedTableManager get setId {
    final $_column = $_itemColumn<int>('set_id')!;

    final manager = $$QuestionSetsTableTableManager(
      $_db,
      $_db.questionSets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_setIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$AttemptsTable, List<Attempt>> _attemptsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.attempts,
    aliasName: 'items__id__attempts__item_id',
  );

  $$AttemptsTableProcessedTableManager get attemptsRefs {
    final manager = $$AttemptsTableTableManager(
      $_db,
      $_db.attempts,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_attemptsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ItemsTableFilterComposer extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prompt => $composableBuilder(
    column: $table.prompt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answer => $composableBuilder(
    column: $table.answer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get promptLang => $composableBuilder(
    column: $table.promptLang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answerLang => $composableBuilder(
    column: $table.answerLang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get choices => $composableBuilder(
    column: $table.choices,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hint => $composableBuilder(
    column: $table.hint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$QuestionSetsTableFilterComposer get setId {
    final $$QuestionSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.questionSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionSetsTableFilterComposer(
            $db: $db,
            $table: $db.questionSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> attemptsRefs(
    Expression<bool> Function($$AttemptsTableFilterComposer f) f,
  ) {
    final $$AttemptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attempts,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttemptsTableFilterComposer(
            $db: $db,
            $table: $db.attempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prompt => $composableBuilder(
    column: $table.prompt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answer => $composableBuilder(
    column: $table.answer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get promptLang => $composableBuilder(
    column: $table.promptLang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answerLang => $composableBuilder(
    column: $table.answerLang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get choices => $composableBuilder(
    column: $table.choices,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hint => $composableBuilder(
    column: $table.hint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$QuestionSetsTableOrderingComposer get setId {
    final $$QuestionSetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.questionSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionSetsTableOrderingComposer(
            $db: $db,
            $table: $db.questionSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get prompt =>
      $composableBuilder(column: $table.prompt, builder: (column) => column);

  GeneratedColumn<String> get answer =>
      $composableBuilder(column: $table.answer, builder: (column) => column);

  GeneratedColumn<String> get promptLang => $composableBuilder(
    column: $table.promptLang,
    builder: (column) => column,
  );

  GeneratedColumn<String> get answerLang => $composableBuilder(
    column: $table.answerLang,
    builder: (column) => column,
  );

  GeneratedColumn<String> get choices =>
      $composableBuilder(column: $table.choices, builder: (column) => column);

  GeneratedColumn<String> get hint =>
      $composableBuilder(column: $table.hint, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$QuestionSetsTableAnnotationComposer get setId {
    final $$QuestionSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.questionSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.questionSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> attemptsRefs<T extends Object>(
    Expression<T> Function($$AttemptsTableAnnotationComposer a) f,
  ) {
    final $$AttemptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attempts,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttemptsTableAnnotationComposer(
            $db: $db,
            $table: $db.attempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ItemsTable,
          Item,
          $$ItemsTableFilterComposer,
          $$ItemsTableOrderingComposer,
          $$ItemsTableAnnotationComposer,
          $$ItemsTableCreateCompanionBuilder,
          $$ItemsTableUpdateCompanionBuilder,
          (Item, $$ItemsTableReferences),
          Item,
          PrefetchHooks Function({bool setId, bool attemptsRefs})
        > {
  $$ItemsTableTableManager(_$AppDatabase db, $ItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> setId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> prompt = const Value.absent(),
                Value<String> answer = const Value.absent(),
                Value<String?> promptLang = const Value.absent(),
                Value<String?> answerLang = const Value.absent(),
                Value<String?> choices = const Value.absent(),
                Value<String?> hint = const Value.absent(),
                Value<int> position = const Value.absent(),
              }) => ItemsCompanion(
                id: id,
                setId: setId,
                type: type,
                prompt: prompt,
                answer: answer,
                promptLang: promptLang,
                answerLang: answerLang,
                choices: choices,
                hint: hint,
                position: position,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int setId,
                required String type,
                required String prompt,
                required String answer,
                Value<String?> promptLang = const Value.absent(),
                Value<String?> answerLang = const Value.absent(),
                Value<String?> choices = const Value.absent(),
                Value<String?> hint = const Value.absent(),
                required int position,
              }) => ItemsCompanion.insert(
                id: id,
                setId: setId,
                type: type,
                prompt: prompt,
                answer: answer,
                promptLang: promptLang,
                answerLang: answerLang,
                choices: choices,
                hint: hint,
                position: position,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ItemsTable, Item>(table),
                  $$ItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({setId = false, attemptsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (attemptsRefs) db.attempts],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (setId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.setId,
                        referencedTable: $$ItemsTableReferences._setIdTable(db),
                        referencedColumn: $$ItemsTableReferences
                            ._setIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (attemptsRefs)
                    await $_getPrefetchedData<Item, $ItemsTable, Attempt>(
                      currentTable: table,
                      referencedTable: $$ItemsTableReferences
                          ._attemptsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ItemsTableReferences(db, table, p0).attemptsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.itemId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ItemsTable,
      Item,
      $$ItemsTableFilterComposer,
      $$ItemsTableOrderingComposer,
      $$ItemsTableAnnotationComposer,
      $$ItemsTableCreateCompanionBuilder,
      $$ItemsTableUpdateCompanionBuilder,
      (Item, $$ItemsTableReferences),
      Item,
      PrefetchHooks Function({bool setId, bool attemptsRefs})
    >;
typedef $$AttemptsTableCreateCompanionBuilder = AttemptsCompanion Function({
  Value<int> id,
  required int itemId,
  required bool ok,
  required int at,
});
typedef $$AttemptsTableUpdateCompanionBuilder = AttemptsCompanion Function({
  Value<int> id,
  Value<int> itemId,
  Value<bool> ok,
  Value<int> at,
});

final class $$AttemptsTableReferences
    extends BaseReferences<_$AppDatabase, $AttemptsTable, Attempt> {
  $$AttemptsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ItemsTable _itemIdTable(_$AppDatabase db) =>
      db.items.createAlias('attempts__item_id__items__id');

  $$ItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<int>('item_id')!;

    final manager = $$ItemsTableTableManager(
      $_db,
      $_db.items,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AttemptsTableFilterComposer
    extends Composer<_$AppDatabase, $AttemptsTable> {
  $$AttemptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get ok => $composableBuilder(
    column: $table.ok,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  $$ItemsTableFilterComposer get itemId {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableFilterComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttemptsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttemptsTable> {
  $$AttemptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get ok => $composableBuilder(
    column: $table.ok,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  $$ItemsTableOrderingComposer get itemId {
    final $$ItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableOrderingComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttemptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttemptsTable> {
  $$AttemptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get ok =>
      $composableBuilder(column: $table.ok, builder: (column) => column);

  GeneratedColumn<int> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  $$ItemsTableAnnotationComposer get itemId {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttemptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttemptsTable,
          Attempt,
          $$AttemptsTableFilterComposer,
          $$AttemptsTableOrderingComposer,
          $$AttemptsTableAnnotationComposer,
          $$AttemptsTableCreateCompanionBuilder,
          $$AttemptsTableUpdateCompanionBuilder,
          (Attempt, $$AttemptsTableReferences),
          Attempt,
          PrefetchHooks Function({bool itemId})
        > {
  $$AttemptsTableTableManager(_$AppDatabase db, $AttemptsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttemptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttemptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttemptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> itemId = const Value.absent(),
            Value<bool> ok = const Value.absent(),
            Value<int> at = const Value.absent(),
          }) => AttemptsCompanion(id: id, itemId: itemId, ok: ok, at: at),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int itemId,
                required bool ok,
                required int at,
              }) => AttemptsCompanion.insert(
                id: id,
                itemId: itemId,
                ok: ok,
                at: at,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AttemptsTable, Attempt>(table),
                  $$AttemptsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (itemId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.itemId,
                        referencedTable: $$AttemptsTableReferences._itemIdTable(
                          db,
                        ),
                        referencedColumn: $$AttemptsTableReferences
                            ._itemIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AttemptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttemptsTable,
      Attempt,
      $$AttemptsTableFilterComposer,
      $$AttemptsTableOrderingComposer,
      $$AttemptsTableAnnotationComposer,
      $$AttemptsTableCreateCompanionBuilder,
      $$AttemptsTableUpdateCompanionBuilder,
      (Attempt, $$AttemptsTableReferences),
      Attempt,
      PrefetchHooks Function({bool itemId})
    >;
typedef $$ProfileStatsTableCreateCompanionBuilder =
    ProfileStatsCompanion Function({
      Value<int> id,
      Value<int> xpTotal,
      Value<int> streakCount,
      Value<String?> lastActiveDay,
      Value<int> dailyGoalXp,
      Value<int> todayXp,
      Value<String?> displayName,
      Value<bool> hasOnboarded,
      Value<String> equippedMascotId,
      Value<int> lessonsCompletedToday,
      Value<String?> lessonsCompletedDay,
    });
typedef $$ProfileStatsTableUpdateCompanionBuilder =
    ProfileStatsCompanion Function({
      Value<int> id,
      Value<int> xpTotal,
      Value<int> streakCount,
      Value<String?> lastActiveDay,
      Value<int> dailyGoalXp,
      Value<int> todayXp,
      Value<String?> displayName,
      Value<bool> hasOnboarded,
      Value<String> equippedMascotId,
      Value<int> lessonsCompletedToday,
      Value<String?> lessonsCompletedDay,
    });

class $$ProfileStatsTableFilterComposer
    extends Composer<_$AppDatabase, $ProfileStatsTable> {
  $$ProfileStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get xpTotal => $composableBuilder(
    column: $table.xpTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get streakCount => $composableBuilder(
    column: $table.streakCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastActiveDay => $composableBuilder(
    column: $table.lastActiveDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dailyGoalXp => $composableBuilder(
    column: $table.dailyGoalXp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get todayXp => $composableBuilder(
    column: $table.todayXp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasOnboarded => $composableBuilder(
    column: $table.hasOnboarded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get equippedMascotId => $composableBuilder(
    column: $table.equippedMascotId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lessonsCompletedToday => $composableBuilder(
    column: $table.lessonsCompletedToday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lessonsCompletedDay => $composableBuilder(
    column: $table.lessonsCompletedDay,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProfileStatsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProfileStatsTable> {
  $$ProfileStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get xpTotal => $composableBuilder(
    column: $table.xpTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get streakCount => $composableBuilder(
    column: $table.streakCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastActiveDay => $composableBuilder(
    column: $table.lastActiveDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dailyGoalXp => $composableBuilder(
    column: $table.dailyGoalXp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get todayXp => $composableBuilder(
    column: $table.todayXp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasOnboarded => $composableBuilder(
    column: $table.hasOnboarded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get equippedMascotId => $composableBuilder(
    column: $table.equippedMascotId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lessonsCompletedToday => $composableBuilder(
    column: $table.lessonsCompletedToday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lessonsCompletedDay => $composableBuilder(
    column: $table.lessonsCompletedDay,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfileStatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProfileStatsTable> {
  $$ProfileStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get xpTotal =>
      $composableBuilder(column: $table.xpTotal, builder: (column) => column);

  GeneratedColumn<int> get streakCount => $composableBuilder(
    column: $table.streakCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastActiveDay => $composableBuilder(
    column: $table.lastActiveDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dailyGoalXp => $composableBuilder(
    column: $table.dailyGoalXp,
    builder: (column) => column,
  );

  GeneratedColumn<int> get todayXp =>
      $composableBuilder(column: $table.todayXp, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasOnboarded => $composableBuilder(
    column: $table.hasOnboarded,
    builder: (column) => column,
  );

  GeneratedColumn<String> get equippedMascotId => $composableBuilder(
    column: $table.equippedMascotId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lessonsCompletedToday => $composableBuilder(
    column: $table.lessonsCompletedToday,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lessonsCompletedDay => $composableBuilder(
    column: $table.lessonsCompletedDay,
    builder: (column) => column,
  );
}

class $$ProfileStatsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProfileStatsTable,
          ProfileStat,
          $$ProfileStatsTableFilterComposer,
          $$ProfileStatsTableOrderingComposer,
          $$ProfileStatsTableAnnotationComposer,
          $$ProfileStatsTableCreateCompanionBuilder,
          $$ProfileStatsTableUpdateCompanionBuilder,
          (
            ProfileStat,
            BaseReferences<_$AppDatabase, $ProfileStatsTable, ProfileStat>,
          ),
          ProfileStat,
          PrefetchHooks Function()
        > {
  $$ProfileStatsTableTableManager(_$AppDatabase db, $ProfileStatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfileStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfileStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfileStatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> xpTotal = const Value.absent(),
                Value<int> streakCount = const Value.absent(),
                Value<String?> lastActiveDay = const Value.absent(),
                Value<int> dailyGoalXp = const Value.absent(),
                Value<int> todayXp = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<bool> hasOnboarded = const Value.absent(),
                Value<String> equippedMascotId = const Value.absent(),
                Value<int> lessonsCompletedToday = const Value.absent(),
                Value<String?> lessonsCompletedDay = const Value.absent(),
              }) => ProfileStatsCompanion(
                id: id,
                xpTotal: xpTotal,
                streakCount: streakCount,
                lastActiveDay: lastActiveDay,
                dailyGoalXp: dailyGoalXp,
                todayXp: todayXp,
                displayName: displayName,
                hasOnboarded: hasOnboarded,
                equippedMascotId: equippedMascotId,
                lessonsCompletedToday: lessonsCompletedToday,
                lessonsCompletedDay: lessonsCompletedDay,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> xpTotal = const Value.absent(),
                Value<int> streakCount = const Value.absent(),
                Value<String?> lastActiveDay = const Value.absent(),
                Value<int> dailyGoalXp = const Value.absent(),
                Value<int> todayXp = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<bool> hasOnboarded = const Value.absent(),
                Value<String> equippedMascotId = const Value.absent(),
                Value<int> lessonsCompletedToday = const Value.absent(),
                Value<String?> lessonsCompletedDay = const Value.absent(),
              }) => ProfileStatsCompanion.insert(
                id: id,
                xpTotal: xpTotal,
                streakCount: streakCount,
                lastActiveDay: lastActiveDay,
                dailyGoalXp: dailyGoalXp,
                todayXp: todayXp,
                displayName: displayName,
                hasOnboarded: hasOnboarded,
                equippedMascotId: equippedMascotId,
                lessonsCompletedToday: lessonsCompletedToday,
                lessonsCompletedDay: lessonsCompletedDay,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProfileStatsTable, ProfileStat>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ProfileStatsTable,
                    ProfileStat
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProfileStatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProfileStatsTable,
      ProfileStat,
      $$ProfileStatsTableFilterComposer,
      $$ProfileStatsTableOrderingComposer,
      $$ProfileStatsTableAnnotationComposer,
      $$ProfileStatsTableCreateCompanionBuilder,
      $$ProfileStatsTableUpdateCompanionBuilder,
      (
        ProfileStat,
        BaseReferences<_$AppDatabase, $ProfileStatsTable, ProfileStat>,
      ),
      ProfileStat,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<bool> hapticsEnabled,
      Value<bool> soundEnabled,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<bool> hapticsEnabled,
      Value<bool> soundEnabled,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hapticsEnabled => $composableBuilder(
    column: $table.hapticsEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get soundEnabled => $composableBuilder(
    column: $table.soundEnabled,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hapticsEnabled => $composableBuilder(
    column: $table.hapticsEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get soundEnabled => $composableBuilder(
    column: $table.soundEnabled,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get hapticsEnabled => $composableBuilder(
    column: $table.hapticsEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get soundEnabled => $composableBuilder(
    column: $table.soundEnabled,
    builder: (column) => column,
  );
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> hapticsEnabled = const Value.absent(),
                Value<bool> soundEnabled = const Value.absent(),
              }) => AppSettingsCompanion(
                id: id,
                hapticsEnabled: hapticsEnabled,
                soundEnabled: soundEnabled,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> hapticsEnabled = const Value.absent(),
                Value<bool> soundEnabled = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                id: id,
                hapticsEnabled: hapticsEnabled,
                soundEnabled: soundEnabled,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppSettingsTable, AppSetting>(table),
                  BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $$OwnedMascotsTableCreateCompanionBuilder =
    OwnedMascotsCompanion Function({
      required String mascotId,
      required int acquiredAt,
      Value<int> rowid,
    });
typedef $$OwnedMascotsTableUpdateCompanionBuilder =
    OwnedMascotsCompanion Function({
      Value<String> mascotId,
      Value<int> acquiredAt,
      Value<int> rowid,
    });

class $$OwnedMascotsTableFilterComposer
    extends Composer<_$AppDatabase, $OwnedMascotsTable> {
  $$OwnedMascotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get mascotId => $composableBuilder(
    column: $table.mascotId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get acquiredAt => $composableBuilder(
    column: $table.acquiredAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OwnedMascotsTableOrderingComposer
    extends Composer<_$AppDatabase, $OwnedMascotsTable> {
  $$OwnedMascotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get mascotId => $composableBuilder(
    column: $table.mascotId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get acquiredAt => $composableBuilder(
    column: $table.acquiredAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OwnedMascotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OwnedMascotsTable> {
  $$OwnedMascotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get mascotId =>
      $composableBuilder(column: $table.mascotId, builder: (column) => column);

  GeneratedColumn<int> get acquiredAt => $composableBuilder(
    column: $table.acquiredAt,
    builder: (column) => column,
  );
}

class $$OwnedMascotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OwnedMascotsTable,
          OwnedMascot,
          $$OwnedMascotsTableFilterComposer,
          $$OwnedMascotsTableOrderingComposer,
          $$OwnedMascotsTableAnnotationComposer,
          $$OwnedMascotsTableCreateCompanionBuilder,
          $$OwnedMascotsTableUpdateCompanionBuilder,
          (
            OwnedMascot,
            BaseReferences<_$AppDatabase, $OwnedMascotsTable, OwnedMascot>,
          ),
          OwnedMascot,
          PrefetchHooks Function()
        > {
  $$OwnedMascotsTableTableManager(_$AppDatabase db, $OwnedMascotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OwnedMascotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OwnedMascotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OwnedMascotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> mascotId = const Value.absent(),
                Value<int> acquiredAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OwnedMascotsCompanion(
                mascotId: mascotId,
                acquiredAt: acquiredAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String mascotId,
                required int acquiredAt,
                Value<int> rowid = const Value.absent(),
              }) => OwnedMascotsCompanion.insert(
                mascotId: mascotId,
                acquiredAt: acquiredAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OwnedMascotsTable, OwnedMascot>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $OwnedMascotsTable,
                    OwnedMascot
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OwnedMascotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OwnedMascotsTable,
      OwnedMascot,
      $$OwnedMascotsTableFilterComposer,
      $$OwnedMascotsTableOrderingComposer,
      $$OwnedMascotsTableAnnotationComposer,
      $$OwnedMascotsTableCreateCompanionBuilder,
      $$OwnedMascotsTableUpdateCompanionBuilder,
      (
        OwnedMascot,
        BaseReferences<_$AppDatabase, $OwnedMascotsTable, OwnedMascot>,
      ),
      OwnedMascot,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$QuestionSetsTableTableManager get questionSets =>
      $$QuestionSetsTableTableManager(_db, _db.questionSets);
  $$ItemsTableTableManager get items =>
      $$ItemsTableTableManager(_db, _db.items);
  $$AttemptsTableTableManager get attempts =>
      $$AttemptsTableTableManager(_db, _db.attempts);
  $$ProfileStatsTableTableManager get profileStats =>
      $$ProfileStatsTableTableManager(_db, _db.profileStats);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$OwnedMascotsTableTableManager get ownedMascots =>
      $$OwnedMascotsTableTableManager(_db, _db.ownedMascots);
}
