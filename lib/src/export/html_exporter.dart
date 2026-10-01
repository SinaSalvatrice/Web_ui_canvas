import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../model/web_element.dart';
import '../model/web_page.dart';
import '../model/web_project.dart';
import '../model/responsive.dart';
import '../model/responsive_layout.dart';

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
    final chosen = await FilePicker.getDirectoryPath(
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
    await cssFile.writeAsString(_css(page, assetMap), flush: true);

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
      for (final sourcePath in [element.imagePath, element.fontPath]) {
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
    }
    return map;
  }

  String _html(
    WebProject project,
    WebPage page,
    Map<String, String> assets,
  ) {
    final body = page.elements
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
        '<div id="$id" class="webui-element webui-image-frame"><img class="webui-image-content" src="${_escapeAttribute(assets[element.imagePath] ?? '')}" alt=""></div>',
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

  String buildCssForPage(
    WebPage page, {
    Map<String, String> assets = const {},
  }) =>
      _css(page, assets);

  String _css(WebPage page, Map<String, String> assets) {
    final buffer = StringBuffer();

    final emittedFonts = <String>{};
    for (final element in page.elements) {
      final fontPath = element.fontPath;
      final asset = fontPath == null ? null : assets[fontPath];
      if (asset == null) continue;
      final key = '${element.fontFamily}|$asset';
      if (!emittedFonts.add(key)) continue;
      buffer
        ..writeln('@font-face {')
        ..writeln('  font-family: ${_cssString(element.fontFamily)};')
        ..writeln('  src: url("$asset");')
        ..writeln('  font-display: swap;')
        ..writeln('}')
        ..writeln();
    }

    buffer
      ..writeln('html, body { margin: 0; min-height: 100%; }')
      ..writeln('body { font-family: Arial, sans-serif; }')
      ..writeln('.webui-page {')
      ..writeln('  position: relative;')
      ..writeln('  width: min(100%, ${page.width}px);')
      ..writeln('  min-height: ${page.height}px;')
      ..writeln('  margin: 0 auto;')
      ..writeln('  overflow: hidden;')
      ..writeln('  background: ${_color(page.backgroundColor)};')
      ..writeln('}')
      ..writeln('.webui-element { box-sizing: border-box; position: absolute; }');

    for (final element in page.elements) {
      _writeElementRule(
        buffer,
        page,
        element,
        WebBreakpoint.desktop,
      );
      if (element.type == WebElementType.image) {
        buffer
          ..writeln('#${element.id} > .webui-image-content {')
          ..writeln('  display: block;')
          ..writeln('  width: 100%;')
          ..writeln('  height: 100%;')
          ..writeln('  object-fit: ${element.imageFit};')
          ..writeln(
            '  object-position: ${50 + element.imagePositionX * 50}% ${50 + element.imagePositionY * 50}%;',
          )
          ..writeln(
            '  transform: scale(${element.imageScale.clamp(.25, 5.0)});',
          )
          ..writeln('  transform-origin: center;')
          ..writeln('}');
      }
    }

    for (final breakpoint in [
      WebBreakpoint.tablet,
      WebBreakpoint.mobile,
    ]) {
      buffer
        ..writeln()
        ..writeln(
          '@media (max-width: ${breakpoint.maxViewportWidth!.toStringAsFixed(0)}px) {',
        );
      for (final element in page.elements) {
        _writeElementRule(
          buffer,
          page,
          element,
          breakpoint,
          indent: '  ',
        );
      }
      buffer.writeln('}');
    }

    return buffer.toString();
  }

  void _writeElementRule(
    StringBuffer buffer,
    WebPage page,
    WebElement element,
    WebBreakpoint breakpoint, {
    String indent = '',
  }) {
    final resolved = ResponsiveLayoutResolver.resolve(
      element,
      page,
      breakpoint,
    );
    final targetWidth = breakpoint == WebBreakpoint.desktop
        ? page.width
        : breakpoint.previewWidth;
    final targetHeight = page.height;

    buffer.writeln('$indent#${element.id} {');

    final horizontal = _horizontalPositionDeclarations(
      resolved,
      targetWidth,
    );
    for (final declaration in horizontal) {
      buffer.writeln('$indent  $declaration');
    }

    final vertical = _verticalPositionDeclarations(
      resolved,
      targetHeight,
    );
    for (final declaration in vertical) {
      buffer.writeln('$indent  $declaration');
    }

    final width = switch (resolved.widthMode) {
      WebSizeMode.percent =>
        '${(resolved.widthPercent * 100).toStringAsFixed(4)}%',
      WebSizeMode.hug => 'max-content',
      WebSizeMode.fill => 'auto',
      WebSizeMode.fixed => '${resolved.width}px',
    };
    final height = switch (resolved.heightMode) {
      WebSizeMode.percent =>
        '${(resolved.heightPercent * 100).toStringAsFixed(4)}%',
      WebSizeMode.hug => 'max-content',
      WebSizeMode.fill => 'auto',
      WebSizeMode.fixed => '${resolved.height}px',
    };

    buffer
      ..writeln('$indent  width: $width;')
      ..writeln('$indent  height: $height;');

    if (resolved.minWidth != null) {
      buffer.writeln('$indent  min-width: ${resolved.minWidth}px;');
    } else {
      buffer.writeln('$indent  min-width: 0;');
    }
    if (resolved.maxWidth != null) {
      buffer.writeln('$indent  max-width: ${resolved.maxWidth}px;');
    } else {
      buffer.writeln('$indent  max-width: none;');
    }
    if (resolved.minHeight != null) {
      buffer.writeln('$indent  min-height: ${resolved.minHeight}px;');
    } else {
      buffer.writeln('$indent  min-height: 0;');
    }
    if (resolved.maxHeight != null) {
      buffer.writeln('$indent  max-height: ${resolved.maxHeight}px;');
    } else {
      buffer.writeln('$indent  max-height: none;');
    }

    final transforms = <String>[];
    if (resolved.widthMode != WebSizeMode.fill &&
        resolved.anchorX == 'center') {
      transforms.add('translateX(-50%)');
    }
    if (resolved.heightMode != WebSizeMode.fill &&
        resolved.anchorY == 'center') {
      transforms.add('translateY(-50%)');
    }
    transforms.add('rotate(${resolved.rotation}rad)');

    buffer
      ..writeln('$indent  transform: ${transforms.join(' ')};')
      ..writeln('$indent  opacity: ${resolved.opacity};')
      ..writeln(
        '$indent  visibility: ${resolved.visible ? 'visible' : 'hidden'};',
      )
      ..writeln(
        '$indent  pointer-events: ${resolved.visible ? 'auto' : 'none'};',
      )
      ..writeln('$indent  color: ${_color(resolved.foregroundColor)};')
      ..writeln('$indent  font-size: ${resolved.fontSize}px;')
      ..writeln('$indent  font-weight: ${resolved.fontWeight};')
      ..writeln(
        '$indent  font-family: ${_cssString(resolved.fontFamily)}, sans-serif;',
      )
      ..writeln('$indent  letter-spacing: ${resolved.letterSpacing}px;')
      ..writeln('$indent  line-height: ${resolved.lineHeight};')
      ..writeln('$indent  text-align: ${resolved.textAlign};')
      ..writeln('$indent  border-radius: ${resolved.borderRadius}px;')
      ..writeln(
        '$indent  background: ${resolved.backgroundColor == null ? 'transparent' : _color(resolved.backgroundColor!)};',
      )
      ..writeln(
        '$indent  border: ${resolved.borderWidth}px solid ${resolved.borderColor == null ? 'transparent' : _color(resolved.borderColor!)};',
      );
    if (resolved.type == WebElementType.image) {
      buffer.writeln('$indent  overflow: hidden;');
    }
    buffer.writeln('$indent}');
  }

  List<String> _horizontalPositionDeclarations(
    WebElement element,
    double targetWidth,
  ) {
    if (element.widthMode == WebSizeMode.fill) {
      final right = math.max(
        0.0,
        targetWidth - (element.x + element.width),
      );
      return [
        'left: ${element.x}px;',
        'right: $right px;'.replaceAll(' ', ''),
      ];
    }

    return switch (element.anchorX) {
      'center' => [
          'left: calc(50% + ${element.x + element.width / 2 - targetWidth / 2}px);',
          'right: auto;',
        ],
      'right' => [
          'left: auto;',
          'right: ${math.max(0.0, targetWidth - (element.x + element.width))}px;',
        ],
      _ => [
          'left: ${element.x}px;',
          'right: auto;',
        ],
    };
  }

  List<String> _verticalPositionDeclarations(
    WebElement element,
    double targetHeight,
  ) {
    if (element.heightMode == WebSizeMode.fill) {
      final bottom = math.max(
        0.0,
        targetHeight - (element.y + element.height),
      );
      return [
        'top: ${element.y}px;',
        'bottom: $bottom px;'.replaceAll(' ', ''),
      ];
    }

    return switch (element.anchorY) {
      'center' => [
          'top: calc(50% + ${element.y + element.height / 2 - targetHeight / 2}px);',
          'bottom: auto;',
        ],
      'bottom' => [
          'top: auto;',
          'bottom: ${math.max(0.0, targetHeight - (element.y + element.height))}px;',
        ],
      _ => [
          'top: ${element.y}px;',
          'bottom: auto;',
        ],
    };
  }

  String _color(int argb) {
    final a = ((argb >> 24) & 0xff) / 255;
    final r = (argb >> 16) & 0xff;
    final g = (argb >> 8) & 0xff;
    final b = argb & 0xff;
    return 'rgba($r,$g,$b,${a.toStringAsFixed(3)})';
  }

  String _cssString(String value) {
    final escaped = value
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'");
    return "'$escaped'";
  }

  String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  String _escapeAttribute(String value) =>
      _escape(value).replaceAll('"', '&quot;');
}
