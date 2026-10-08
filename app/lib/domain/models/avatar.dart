/// Engine-independent avatar metadata. Never store engine-specific
/// preparation data here — see AvatarPreparationResult / avatar cache dirs.
class Avatar {
  final String id;
  final String name;
  final String sourceImagePath;
  final DateTime createdAt;
  final bool isFavorite;
  final List<String> preparedEngineIds;

  const Avatar({
    required this.id,
    required this.name,
    required this.sourceImagePath,
    required this.createdAt,
    this.isFavorite = false,
    this.preparedEngineIds = const [],
  });

  Avatar copyWith({
    String? name,
    bool? isFavorite,
    List<String>? preparedEngineIds,
  }) =>
      Avatar(
        id: id,
        name: name ?? this.name,
        sourceImagePath: sourceImagePath,
        createdAt: createdAt,
        isFavorite: isFavorite ?? this.isFavorite,
        preparedEngineIds: preparedEngineIds ?? this.preparedEngineIds,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sourceImage': sourceImagePath,
        'createdAt': createdAt.toIso8601String(),
        'isFavorite': isFavorite,
        'preparedEngines': preparedEngineIds,
      };

  factory Avatar.fromJson(Map<String, dynamic> json) => Avatar(
        id: json['id'] as String,
        name: json['name'] as String,
        sourceImagePath: json['sourceImage'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        isFavorite: json['isFavorite'] as bool? ?? false,
        preparedEngineIds:
            (json['preparedEngines'] as List?)?.cast<String>() ?? const [],
      );
}

/// A source image + optional per-engine hints, handed to AvatarEngine.prepareAvatar.
class AvatarSource {
  final String imagePath;
  final Map<String, dynamic> engineHints;
  const AvatarSource({required this.imagePath, this.engineHints = const {}});
}

/// Result of AvatarEngine.prepareAvatar. cacheData is opaque to the rest of
/// the app and is stored per-engine, never merged into Avatar itself.
class AvatarPreparationResult {
  final bool success;
  final String engineId;
  final Map<String, dynamic> cacheData;
  final String? errorMessage;

  const AvatarPreparationResult({
    required this.success,
    required this.engineId,
    this.cacheData = const {},
    this.errorMessage,
  });
}
