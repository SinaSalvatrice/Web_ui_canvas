import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../model/web_element.dart';
import '../model/web_page.dart';
import '../model/web_project.dart';

class HtmlExportResult {
  const HtmlExportResult({
    required this.directory,
    required this.htmlFile,
    required this.cssFile,
  });

  final Directory directory;
  final File htmlFile;
  final File cssFile;
}

class HtmlExporter {
  const HtmlExporter();

  Future<HtmlExportResult?> export(WebProject project) async {
    final chosen = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose export folder',
    );
    if (chosen == null) return null;

    final root = Directory(chosen);
    await root.create(recursive: true);
    final assets = Directory(p.join(root.path, 'assets'));
    await assets.create(recursive: true);

    final page = project.pages.firstWhere(
      (candidate) => candidate.id == project.activePageId,
    );
    final assetMap = await _copyAssets(page, assets);
    final htmlFile = File(p.join(root.path, 'index.html'));
    final cssFile = File(p.join(root.path, 'styles.css'));

    await htmlFile.writeAsString(_html(project, page, assetMap), flush: true);
    await cssFile.writeAsString(_css(page), flush: true);

    return HtmlExportResult(
      directory: root,
      htmlFile: htmlFile,
      cssFile: cssFile,
    );
  }

  Future<Map<String, String>> _copyAssets(
    WebPage page,
    Directory assets,
  ) async {
    final map = <String, String>{};
    final used = <String>{};
    for (final element in page.elements) {
      final sourcePath = element.imagePath;
      if (sourcePath == null || map.containsKey(sourcePath)) continue;
      final source = File(sourcePath);
      if (!await source.exists()) continue;

      final base = p.basename(sourcePath);
      final stem = p.basenameWithoutExtension(base);
      final ext = p.extension(base);
      var name = base;
      var counter = 2;
      while (!used.add(name.toLowerCase())) {
        name = '${stem}_${counter++}$ext';
      }
      await source.copy(p.join(assets.path, name));
      map[sourcePath] = 'assets/${Uri.encodeComponent(name)}';
    }
    return map;
  }

  String _html(
    WebProject project,
    WebPage page,
    Map<String, String> assets,
  ) {
    final body = page.elements
        .where((element) => element.visible)
        .map((element) => _elementHtml(element, assets))
        .join('\n');

    return '''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${_escape(project.name)}</title>
  <link rel="stylesheet" href="styles.css">
</head>
<body>
  <main class="webui-page">
$body
  </main>
</body>
</html>
''';
  }

  String _elementHtml(WebElement element, Map<String, String> assets) {
    final id = _escapeAttribute(element.id);
    final text = _escape(element.text);
    return switch (element.type) {
      WebElementType.image =>
        '<img id="$id" class="webui-element" src="${_escapeAttribute(assets[element.imagePath] ?? '')}" alt="">',
      WebElementType.button => element.href.trim().isNotEmpty
          ? '<a id="$id" class="webui-element" href="${_escapeAttribute(element.href)}">$text</a>'
          : '<button id="$id" class="webui-element" type="button">$text</button>',
      WebElementType.input =>
        '<input id="$id" class="webui-element" placeholder="${_escapeAttribute(element.text)}">',
      WebElementType.navigation =>
        '<nav id="$id" class="webui-element">$text</nav>',
      WebElementType.section =>
        '<section id="$id" class="webui-element">$text</section>',
      WebElementType.divider =>
        '<div id="$id" class="webui-element" aria-hidden="true"></div>',
      _ => '<div id="$id" class="webui-element">$text</div>',
    };
  }

  String _css(WebPage page) {
    final buffer = StringBuffer()
      ..writeln('html, body { margin: 0; min-height: 100%; }')
      ..writeln('body { font-family: Arial, sans-serif; }')
      ..writeln('.webui-page {')
      ..writeln('  position: relative;')
      ..writeln('  width: ${page.width}px;')
      ..writeln('  min-height: ${page.height}px;')
      ..writeln('  margin: 0 auto;')
      ..writeln('  overflow: hidden;')
      ..writeln('  background: ${_color(page.backgroundColor)};')
      ..writeln('}')
      ..writeln('.webui-element { box-sizing: border-box; position: absolute; }');

    for (final element in page.elements.where((element) => element.visible)) {
      buffer
        ..writeln('#${element.id} {')
        ..writeln('  left: ${element.x}px;')
        ..writeln('  top: ${element.y}px;')
        ..writeln('  width: ${element.width}px;')
        ..writeln('  height: ${element.height}px;')
        ..writeln('  transform: rotate(${element.rotation}rad);')
        ..writeln('  opacity: ${element.opacity};')
        ..writeln('  color: ${_color(element.foregroundColor)};')
        ..writeln('  font-size: ${element.fontSize}px;')
        ..writeln('  font-weight: ${element.fontWeight};')
        ..writeln('  text-align: ${element.textAlign};')
        ..writeln('  border-radius: ${element.borderRadius}px;')
        ..writeln(
          '  background: ${element.backgroundColor == null ? 'transparent' : _color(element.backgroundColor!)};',
        )
        ..writeln(
          '  border: ${element.borderWidth}px solid ${element.borderColor == null ? 'transparent' : _color(element.borderColor!)};',
        );
      if (element.type == WebElementType.image) {
        buffer
          ..writeln('  object-fit: ${element.imageFit};')
          ..writeln(
            '  object-position: ${50 + element.imagePositionX * 50}% ${50 + element.imagePositionY * 50}%;',
          );
      }
      buffer.writeln('}');
    }

    return buffer.toString();
  }

  String _color(int argb) {
    final a = ((argb >> 24) & 0xff) / 255;
    final r = (argb >> 16) & 0xff;
    final g = (argb >> 8) & 0xff;
    final b = argb & 0xff;
    return 'rgba($r,$g,$b,${a.toStringAsFixed(3)})';
  }

  String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  String _escapeAttribute(String value) =>
      _escape(value).replaceAll('"', '&quot;');
}
