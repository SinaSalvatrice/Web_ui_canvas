import 'asset_library.dart';
import 'web_page.dart';

class WebProject {
  const WebProject({
    required this.schemaVersion,
    required this.id,
    required this.name,
    required this.activePageId,
    required this.pages,
    this.linkedWebsitePath,
    this.assetLibraryEnabled = true,
    this.assetLibrary = const [],
  });

  static const currentSchemaVersion = 5;

  final int schemaVersion;
  final String id;
  final String name;
  final String activePageId;
  final List<WebPage> pages;
  final String? linkedWebsitePath;
  final bool assetLibraryEnabled;
  final List<AssetLibraryItem> assetLibrary;

  factory WebProject.empty() {
    const page = WebPage(
      id: 'page_home',
      name: 'Home',
      width: 1440,
      height: 2200,
      backgroundColor: 0xffffffff,
    );
    return const WebProject(
      schemaVersion: currentSchemaVersion,
      id: 'web_project',
      name: 'Untitled Website',
      activePageId: 'page_home',
      pages: [page],
    );
  }

  WebProject copyWith({
    String? name,
    String? activePageId,
    List<WebPage>? pages,
    String? linkedWebsitePath,
    bool clearLinkedWebsitePath = false,
    bool? assetLibraryEnabled,
    List<AssetLibraryItem>? assetLibrary,
  }) {
    return WebProject(
      schemaVersion: schemaVersion,
      id: id,
      name: name ?? this.name,
      activePageId: activePageId ?? this.activePageId,
      pages: pages ?? this.pages,
      linkedWebsitePath: clearLinkedWebsitePath
          ? null
          : (linkedWebsitePath ?? this.linkedWebsitePath),
      assetLibraryEnabled: assetLibraryEnabled ?? this.assetLibraryEnabled,
      assetLibrary: assetLibrary ?? this.assetLibrary,
    );
  }

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'kind': 'web-ui-canvas.project',
        'id': id,
        'name': name,
        'activePageId': activePageId,
        'pages': pages.map((page) => page.toJson()).toList(),
        if (linkedWebsitePath != null)
          'linkedWebsitePath': linkedWebsitePath,
        'assetLibraryEnabled': assetLibraryEnabled,
        if (assetLibrary.isNotEmpty)
          'assetLibrary': assetLibrary.map((item) => item.toJson()).toList(),
      };

  factory WebProject.fromJson(Map<String, Object?> json) {
    final version = json['schemaVersion'] as int? ?? 0;
    if (version < 1 || version > currentSchemaVersion) {
      throw FormatException('Unsupported .webui schema version: $version');
    }
    return WebProject(
      schemaVersion: currentSchemaVersion,
      id: json['id'] as String? ?? 'web_project',
      name: json['name'] as String? ?? 'Website',
      activePageId: json['activePageId']! as String,
      pages: (json['pages']! as List)
          .map(
            (item) => WebPage.fromJson(Map<String, Object?>.from(item as Map)),
          )
          .toList(),
      linkedWebsitePath: json['linkedWebsitePath'] as String?,
      assetLibraryEnabled: json['assetLibraryEnabled'] as bool? ?? true,
      assetLibrary: ((json['assetLibrary'] as List?) ?? const [])
          .map((item) => AssetLibraryItem.fromJson(
                Map<String, Object?>.from(item as Map),
              ))
          .toList(),
    );
  }
}
