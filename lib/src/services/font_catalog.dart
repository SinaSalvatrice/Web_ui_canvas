import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class FontEntry {
  const FontEntry({
    required this.family,
    this.path,
    required this.source,
  });

  final String family;
  final String? path;
  final String source;
}

class FontCatalog extends ChangeNotifier {
  FontCatalog._();

  static final FontCatalog instance = FontCatalog._();

  final Map<String, FontEntry> _entries = <String, FontEntry>{
    'Arial': const FontEntry(family: 'Arial', source: 'Default'),
    'Segoe UI': const FontEntry(family: 'Segoe UI', source: 'System'),
  };
  final Set<String> _loadedPaths = <String>{};
  bool _systemScanned = false;

  List<FontEntry> get entries {
    final values = _entries.values.toList()
      ..sort((a, b) => a.family.toLowerCase().compareTo(b.family.toLowerCase()));
    return values;
  }

  Future<void> discoverSystemFonts() async {
    if (_systemScanned) return;
    _systemScanned = true;
    if (!Platform.isWindows) {
      notifyListeners();
      return;
    }

    final windows = Platform.environment['WINDIR'];
    final local = Platform.environment['LOCALAPPDATA'];
    final dirs = <Directory>[
      if (windows != null) Directory(p.join(windows, 'Fonts')),
      if (local != null)
        Directory(p.join(local, 'Microsoft', 'Windows', 'Fonts')),
    ];

    for (final directory in dirs) {
      await _scanDirectory(directory, source: 'System', recursive: false);
    }
    notifyListeners();
  }

  Future<int> addFolder(String folderPath) async {
    final before = _entries.length;
    await _scanDirectory(
      Directory(folderPath),
      source: 'Custom',
      recursive: true,
    );
    notifyListeners();
    return _entries.length - before;
  }

  Future<void> ensureLoaded({
    required String family,
    String? path,
  }) async {
    if (path == null || path.isEmpty || _loadedPaths.contains(path)) return;
    final file = File(path);
    if (!await file.exists()) return;

    final bytes = await file.readAsBytes();
    final loader = FontLoader(family)
      ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
    _loadedPaths.add(path);
  }

  Future<void> _scanDirectory(
    Directory directory, {
    required String source,
    required bool recursive,
  }) async {
    if (!await directory.exists()) return;

    await for (final entity in directory.list(
      recursive: recursive,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).toLowerCase();
      if (ext != '.ttf' && ext != '.otf') continue;

      final family = _familyFromFile(entity.path);
      final key = '${family.toLowerCase()}|${entity.path.toLowerCase()}';
      _entries.putIfAbsent(
        key,
        () => FontEntry(
          family: family,
          path: entity.path,
          source: source,
        ),
      );
    }
  }

  String _familyFromFile(String path) {
    var name = p.basenameWithoutExtension(path)
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .trim();
    name = name.replaceFirst(
      RegExp(
        r'\s+(thin|extralight|ultralight|light|regular|medium|semibold|demibold|bold|extrabold|ultrabold|black|heavy|italic|oblique)$',
        caseSensitive: false,
      ),
      '',
    );
    return name.trim().isEmpty ? p.basenameWithoutExtension(path) : name.trim();
  }
}
