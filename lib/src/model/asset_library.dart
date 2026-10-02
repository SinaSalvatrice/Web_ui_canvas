enum AssetCategory {
  icons,
  frames,
  textures,
  fonts,
  objects,
  masks;

  String get label => switch (this) {
        AssetCategory.icons => 'Icons',
        AssetCategory.frames => 'Frames',
        AssetCategory.textures => 'Textures',
        AssetCategory.fonts => 'Fonts',
        AssetCategory.objects => 'Objects',
        AssetCategory.masks => 'Masks',
      };
}

class AssetLibraryItem {
  const AssetLibraryItem({
    required this.id,
    required this.label,
    required this.category,
    required this.path,
    this.enabled = true,
  });

  final String id;
  final String label;
  final AssetCategory category;
  final String path;
  final bool enabled;

  AssetLibraryItem copyWith({
    String? label,
    AssetCategory? category,
    String? path,
    bool? enabled,
  }) =>
      AssetLibraryItem(
        id: id,
        label: label ?? this.label,
        category: category ?? this.category,
        path: path ?? this.path,
        enabled: enabled ?? this.enabled,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'label': label,
        'category': category.name,
        'path': path,
        'enabled': enabled,
      };

  factory AssetLibraryItem.fromJson(Map<String, Object?> json) =>
      AssetLibraryItem(
        id: json['id'] as String,
        label: json['label'] as String? ?? '',
        category: AssetCategory.values.byName(
          json['category'] as String? ?? AssetCategory.objects.name,
        ),
        path: json['path'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? true,
      );
}
