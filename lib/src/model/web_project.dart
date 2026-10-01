import 'web_page.dart';

class WebProject {
  const WebProject({
    required this.schemaVersion,
    required this.id,
    required this.name,
    required this.activePageId,
    required this.pages,
  });

  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final String id;
  final String name;
  final String activePageId;
  final List<WebPage> pages;

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
  }) {
    return WebProject(
      schemaVersion: schemaVersion,
      id: id,
      name: name ?? this.name,
      activePageId: activePageId ?? this.activePageId,
      pages: pages ?? this.pages,
    );
  }

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'kind': 'web-ui-canvas.project',
        'id': id,
        'name': name,
        'activePageId': activePageId,
        'pages': pages.map((page) => page.toJson()).toList(),
      };

  factory WebProject.fromJson(Map<String, Object?> json) {
    final version = json['schemaVersion'] as int? ?? 0;
    if (version != currentSchemaVersion) {
      throw FormatException('Unsupported .webui schema version: $version');
    }
    return WebProject(
      schemaVersion: version,
      id: json['id'] as String? ?? 'web_project',
      name: json['name'] as String? ?? 'Website',
      activePageId: json['activePageId']! as String,
      pages: (json['pages']! as List)
          .map(
            (item) => WebPage.fromJson(Map<String, Object?>.from(item as Map)),
          )
          .toList(),
    );
  }
}
