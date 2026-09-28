import '../../db/tables.dart';

/// Single breakdown step element parsed by AI.
class AiSubstep {
  const AiSubstep({required this.title, this.sortOrder = 0});

  final String title;
  final int sortOrder;

  Map<String, dynamic> toJson() => {'title': title, 'sortOrder': sortOrder};

  factory AiSubstep.fromJson(Map<String, dynamic> json) {
    final rawTitle = json['title']?.toString().trim() ?? '';
    final rawSort = json['sortOrder'] ?? json['sort_order'];
    final sortOrder = rawSort is num ? rawSort.toInt() : 0;
    return AiSubstep(title: rawTitle, sortOrder: sortOrder);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiSubstep &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          sortOrder == other.sortOrder;

  @override
  int get hashCode => Object.hash(title, sortOrder);

  @override
  String toString() => 'AiSubstep(title: $title, sortOrder: $sortOrder)';
}

/// Structured task elements parsed from natural language.
class AiTaskParseResult {
  const AiTaskParseResult({
    required this.title,
    this.description,
    this.priority = 0,
    this.startAt,
    this.dueAt,
    this.tags = const [],
    this.substeps = const [],
    this.isFallback = false,
    this.rawResponse,
  });

  static const String defaultTitleZh = '未命名任务';
  static const String defaultTitleEn = 'Untitled Task';

  /// Task title (1-200 chars).
  final String title;

  /// Optional task description / remarks.
  final String? description;

  /// Priority 0: none, 1: low, 2: medium, 3: high (corresponds to Eisenhower quadrant).
  final int priority;

  /// Optional starting timestamp (UTC ms).
  final int? startAt;

  /// Optional due/deadline timestamp (UTC ms).
  final int? dueAt;

  /// Tag names associated with the task.
  final List<String> tags;

  /// Substeps if user requested task breakdown.
  final List<AiSubstep> substeps;

  /// Indicates if this result was produced by a fallback extractor.
  final bool isFallback;

  /// Raw response string received from LLM.
  final String? rawResponse;

  /// Convenience alias matching Task.endAt in the database.
  int? get endAt => dueAt;

  /// Domain model TaskPriority enum value.
  TaskPriority get taskPriority {
    final p = priority.clamp(0, 3);
    return TaskPriority.values[p];
  }

  AiTaskParseResult copyWith({
    String? title,
    String? description,
    bool clearDescription = false,
    int? priority,
    int? startAt,
    bool clearStartAt = false,
    int? dueAt,
    bool clearDueAt = false,
    List<String>? tags,
    List<AiSubstep>? substeps,
    bool? isFallback,
    String? rawResponse,
  }) {
    return AiTaskParseResult(
      title: title ?? this.title,
      description: clearDescription ? null : (description ?? this.description),
      priority: priority ?? this.priority,
      startAt: clearStartAt ? null : (startAt ?? this.startAt),
      dueAt: clearDueAt ? null : (dueAt ?? this.dueAt),
      tags: tags ?? this.tags,
      substeps: substeps ?? this.substeps,
      isFallback: isFallback ?? this.isFallback,
      rawResponse: rawResponse ?? this.rawResponse,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    if (description != null) 'description': description,
    'priority': priority,
    if (startAt != null) 'startAt': startAt,
    if (dueAt != null) 'dueAt': dueAt,
    if (tags.isNotEmpty) 'tags': tags,
    if (substeps.isNotEmpty)
      'substeps': substeps.map((s) => s.toJson()).toList(),
    'isFallback': isFallback,
    if (rawResponse != null) 'rawResponse': rawResponse,
  };

  factory AiTaskParseResult.fromJson(
    Map<String, dynamic> json, {
    String? rawResponse,
    String defaultTitle = defaultTitleZh,
  }) {
    // 1. Title sanitization
    var rawTitle = json['title']?.toString().trim() ?? '';
    if (rawTitle.isEmpty) {
      rawTitle = defaultTitle;
    } else if (rawTitle.length > 200) {
      rawTitle = rawTitle.substring(0, 200);
    }

    // 2. Description
    final rawDesc = json['description']?.toString().trim();
    final description = (rawDesc != null && rawDesc.isNotEmpty)
        ? rawDesc
        : null;

    // 3. Priority (0-3)
    var p = 0;
    final rawP = json['priority'];
    if (rawP is num) {
      p = rawP.toInt().clamp(0, 3);
    } else if (rawP is String) {
      final parsed = int.tryParse(rawP);
      if (parsed != null) {
        p = parsed.clamp(0, 3);
      }
    }

    // 4. Timestamps
    int? parseTime(dynamic val) {
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val);
      return null;
    }

    var startAt = parseTime(json['startAt'] ?? json['start_at']);
    var dueAt = parseTime(
      json['dueAt'] ?? json['due_at'] ?? json['endAt'] ?? json['end_at'],
    );

    // Defensive check: if startAt is later than dueAt, swap them to prevent database
    // validation failure (TodoRepository._checkTimeRange throws RepositoryException).
    if (startAt != null && dueAt != null && startAt > dueAt) {
      final temp = startAt;
      startAt = dueAt;
      dueAt = temp;
    }

    // 5. Tags (deduplicated non-empty strings)
    final tags = <String>[];
    final rawTags = json['tags'];
    if (rawTags is List) {
      for (final t in rawTags) {
        final tagStr = t?.toString().trim();
        if (tagStr != null && tagStr.isNotEmpty && !tags.contains(tagStr)) {
          tags.add(tagStr);
        }
      }
    }

    // 6. Substeps
    final substeps = <AiSubstep>[];
    final rawSubsteps = json['substeps'];
    if (rawSubsteps is List) {
      for (var i = 0; i < rawSubsteps.length; i++) {
        final item = rawSubsteps[i];
        if (item is Map<String, dynamic>) {
          final s = AiSubstep.fromJson(item);
          if (s.title.isNotEmpty) substeps.add(s);
        } else if (item is Map) {
          final s = AiSubstep.fromJson(Map<String, dynamic>.from(item));
          if (s.title.isNotEmpty) substeps.add(s);
        } else if (item is String && item.trim().isNotEmpty) {
          substeps.add(AiSubstep(title: item.trim(), sortOrder: i));
        }
      }
    }

    return AiTaskParseResult(
      title: rawTitle,
      description: description,
      priority: p,
      startAt: startAt,
      dueAt: dueAt,
      tags: tags,
      substeps: substeps,
      isFallback: false,
      rawResponse: rawResponse,
    );
  }

  factory AiTaskParseResult.fallback(
    String rawInput, {
    String? rawResponse,
    String defaultTitle = defaultTitleZh,
  }) {
    var title = rawInput.trim();
    if (title.isEmpty) {
      title = defaultTitle;
    } else if (title.length > 200) {
      title = title.substring(0, 200);
    }
    return AiTaskParseResult(
      title: title,
      priority: 0,
      tags: const [],
      substeps: const [],
      isFallback: true,
      rawResponse: rawResponse,
    );
  }
}
