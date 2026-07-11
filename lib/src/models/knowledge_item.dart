import 'dart:convert';

/// The kind of thing the user captured. Used for display and, later, to tell
/// the AI layer how to expand a bare capture and what review formats fit.
enum KnowledgeType {
  fact,
  concept,
  command,
  code,
  question;

  String get label => switch (this) {
        KnowledgeType.fact => 'Fact',
        KnowledgeType.concept => 'Concept',
        KnowledgeType.command => 'Command',
        KnowledgeType.code => 'Code',
        KnowledgeType.question => 'Question',
      };
}

/// A single unit of knowledge the user wants to keep alive.
///
/// [front] is what the app shows first when quizzing (a question, a concept
/// name, a command). [back] is the answer/details — it may be null when the
/// user only jotted a fragment and hasn't filled it in (later the AI layer can
/// populate it). Scheduling fields follow the SM-2 spaced-repetition algorithm.
class KnowledgeItem {
  KnowledgeItem({
    required this.id,
    required this.front,
    this.back,
    required this.type,
    this.category,
    required this.createdAt,
    required this.dueDate,
    this.lastReviewedAt,
    this.repetitions = 0,
    this.easeFactor = 2.5,
    this.intervalDays = 0,
    DateTime? updatedAt,
    this.lastCorrect,
    this.lapses = 0,
    this.hasImage = false,
  }) : updatedAt = updatedAt ?? createdAt;

  final String id;
  final String front;
  final String? back;
  final KnowledgeType type;
  final String? category;
  final DateTime createdAt;

  // --- Spaced-repetition state (SM-2) ---
  final DateTime dueDate;
  final DateTime? lastReviewedAt;
  final int repetitions;
  final double easeFactor;
  final int intervalDays;

  // --- Sync + review-history state ---
  /// Last local mutation time; drives last-write-wins during Telegram sync.
  final DateTime updatedAt;

  /// Whether the most recent recall was correct. Colors the tree-view leaf:
  /// true → green, false → red, null (never reviewed) → neutral/amber.
  final bool? lastCorrect;

  /// How many times recall has lapsed (graded `again`). Kept for the tree
  /// color rule and future difficulty surfacing.
  final int lapses;

  /// Whether an image is attached (bytes live in the [ImageStore] keyed by id).
  final bool hasImage;

  bool get hasAnswer => back != null && back!.trim().isNotEmpty;

  bool isDue(DateTime now) => !dueDate.isAfter(now);

  KnowledgeItem copyWith({
    String? front,
    String? back,
    KnowledgeType? type,
    String? category,
    DateTime? dueDate,
    DateTime? lastReviewedAt,
    int? repetitions,
    double? easeFactor,
    int? intervalDays,
    DateTime? updatedAt,
    bool? lastCorrect,
    int? lapses,
    bool? hasImage,
  }) {
    return KnowledgeItem(
      id: id,
      front: front ?? this.front,
      back: back ?? this.back,
      type: type ?? this.type,
      category: category ?? this.category,
      createdAt: createdAt,
      dueDate: dueDate ?? this.dueDate,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      repetitions: repetitions ?? this.repetitions,
      easeFactor: easeFactor ?? this.easeFactor,
      intervalDays: intervalDays ?? this.intervalDays,
      updatedAt: updatedAt ?? this.updatedAt,
      lastCorrect: lastCorrect ?? this.lastCorrect,
      lapses: lapses ?? this.lapses,
      hasImage: hasImage ?? this.hasImage,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'front': front,
        'back': back,
        'type': type.name,
        'category': category,
        'createdAt': createdAt.toIso8601String(),
        'dueDate': dueDate.toIso8601String(),
        'lastReviewedAt': lastReviewedAt?.toIso8601String(),
        'repetitions': repetitions,
        'easeFactor': easeFactor,
        'intervalDays': intervalDays,
        'updatedAt': updatedAt.toIso8601String(),
        'lastCorrect': lastCorrect,
        'lapses': lapses,
        'hasImage': hasImage,
      };

  factory KnowledgeItem.fromMap(Map<String, dynamic> map) => KnowledgeItem(
        id: map['id'] as String,
        front: map['front'] as String,
        back: map['back'] as String?,
        type: KnowledgeType.values.firstWhere(
          (t) => t.name == map['type'],
          orElse: () => KnowledgeType.fact,
        ),
        category: map['category'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
        dueDate: DateTime.parse(map['dueDate'] as String),
        lastReviewedAt: map['lastReviewedAt'] == null
            ? null
            : DateTime.parse(map['lastReviewedAt'] as String),
        repetitions: (map['repetitions'] as num?)?.toInt() ?? 0,
        easeFactor: (map['easeFactor'] as num?)?.toDouble() ?? 2.5,
        intervalDays: (map['intervalDays'] as num?)?.toInt() ?? 0,
        updatedAt: map['updatedAt'] == null
            ? DateTime.parse(map['createdAt'] as String)
            : DateTime.parse(map['updatedAt'] as String),
        lastCorrect: map['lastCorrect'] as bool?,
        lapses: (map['lapses'] as num?)?.toInt() ?? 0,
        hasImage: map['hasImage'] as bool? ?? false,
      );

  String toJson() => jsonEncode(toMap());

  factory KnowledgeItem.fromJson(String source) =>
      KnowledgeItem.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
