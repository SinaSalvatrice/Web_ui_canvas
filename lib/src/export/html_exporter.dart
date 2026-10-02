import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../model/layout.dart';
import '../model/page_layout_engine.dart';
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
    this.backupDirectory,
  });

  final Directory directory;
  final File htmlFile;
  final File cssFile;
  final Directory? backupDirectory;
}

class HtmlExporter {
  const HtmlExporter();

  Future<HtmlExportResult?> export(
    WebProject project, {
    String? targetDirectory,
  }) async {
    final chosen = targetDirectory ??
        project.linkedWebsitePath ??
        await FilePicker.getDirectoryPath(
          dialogTitle: 'Choose export folder',
        );
    if (chosen == null) return null;

    final root = Directory(chosen);
    await root.create(recursive: true);
    final backupDirectory = await _backupExisting(root);
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

    final linkedProject = project.copyWith(linkedWebsitePath: root.path);
    final projectFile = File(p.join(root.path, 'web-ui-canvas.webui'));
    final projectText =
        const JsonEncoder.withIndent('  ').convert(linkedProject.toJson());
    await projectFile.writeAsString(projectText + '\n', flush: true);

    return HtmlExportResult(
      directory: root,
      htmlFile: htmlFile,
      cssFile: cssFile,
      backupDirectory: backupDirectory,
    );
  }

  Future<Map<String, String>> _copyAssets(
    WebPage page,
    Directory assets,
  ) async {
    final map = <String, String>{};
    final used = <String>{};
    for (final element in page.elements) {
      for (final sourcePath in [
        element.imagePath,
        element.fontPath,
        element.backplatePath,
        element.maskPath,
      ]) {
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
    final ids = page.elements.map((element) => element.id).toSet();
    final roots = page.elements.where(
      (element) =>
          element.parentId == null || !ids.contains(element.parentId),
    );
    final body = roots
        .map(
          (element) => _elementHtmlTree(
            element,
            page,
            assets,
            <String>{},
          ),
        )
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
  <script>
    document.querySelectorAll('[data-webui-toggle]').forEach((element) => {
      element.addEventListener('click', () => {
        const active = element.getAttribute('aria-checked') === 'true';
        element.setAttribute('aria-checked', (!active).toString());
      });
    });
  </script>
</body>
</html>
''';
  }

  String _elementHtmlTree(
    WebElement element,
    WebPage page,
    Map<String, String> assets,
    Set<String> visiting,
  ) {
    if (!visiting.add(element.id)) return '';

    final children = page.elements
        .where((candidate) => candidate.parentId == element.id)
        .map(
          (child) => _elementHtmlTree(
            child,
            page,
            assets,
            visiting,
          ),
        )
        .where((html) => html.isNotEmpty)
        .join('\n');

    visiting.remove(element.id);
    return _elementHtml(element, assets, children);
  }

  String _elementHtml(
    WebElement element,
    Map<String, String> assets,
    String children,
  ) {
    final id = _escapeAttribute(element.id);
    final text = _escape(element.text);
    final hasChildren = children.isNotEmpty;
    final textContent = '<span class="webui-text">$text</span>';
    final content = hasChildren ? children : textContent;
    final backplateAsset = assets[element.backplatePath];
    final backplate = element.backplateEnabled && backplateAsset != null
        ? '<img class="webui-backplate" src="${_escapeAttribute(backplateAsset)}" alt="" aria-hidden="true">'
        : '';

    return switch (element.type) {
      WebElementType.image =>
        '<div id="$id" class="webui-element webui-image-frame">$backplate<img class="webui-image-content" src="${_escapeAttribute(assets[element.imagePath] ?? '')}" alt=""></div>',
      WebElementType.button => element.href.trim().isNotEmpty
          ? '<a id="$id" class="webui-element" href="${_escapeAttribute(element.href)}">$backplate$content</a>'
          : '<button id="$id" class="webui-element" type="button">$backplate$content</button>',
      WebElementType.input =>
        '<label id="$id" class="webui-element webui-input-frame">$backplate<input class="webui-input-control" placeholder="${_escapeAttribute(element.text)}"></label>',
      WebElementType.toggle =>
        '<button id="$id" class="webui-element webui-toggle" type="button" role="switch" aria-checked="false" data-webui-toggle>$backplate<span class="webui-toggle-knob"></span></button>',
      WebElementType.navigation =>
        '<nav id="$id" class="webui-element">$backplate$content</nav>',
      WebElementType.section =>
        '<section id="$id" class="webui-element">$backplate$content</section>',
      WebElementType.divider =>
        '<div id="$id" class="webui-element" aria-hidden="true"></div>',
      _ => '<div id="$id" class="webui-element">$backplate$content</div>',
    };
  }

  String buildHtmlForPage(
    WebPage page, {
    Map<String, String> assets = const {},
    String title = 'Test',
  }) =>
      _html(
        WebProject(
          schemaVersion: WebProject.currentSchemaVersion,
          id: 'test',
          name: title,
          activePageId: page.id,
          pages: [page],
        ),
        page,
        assets,
      );

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
      ..writeln('.webui-element { box-sizing: border-box; position: absolute; }')
      ..writeln('.webui-backplate { position: absolute; inset: 0; width: 100%; height: 100%; pointer-events: none; z-index: 0; }')
      ..writeln('.webui-text, .webui-input-control, .webui-toggle-knob { position: relative; z-index: 1; }')
      ..writeln('.webui-input-control { box-sizing: border-box; width: 100%; height: 100%; border: 0; background: transparent; color: inherit; font: inherit; }')
      ..writeln('.webui-toggle { padding: 0; cursor: pointer; }')
      ..writeln('.webui-toggle-knob { display: block; width: 44%; aspect-ratio: 1; border-radius: 50%; background: currentColor; margin: 3px; transition: transform 180ms ease; }')
      ..writeln('.webui-toggle[aria-checked="true"] .webui-toggle-knob { transform: translateX(100%); }')
      ..writeln('@keyframes webui-slide-left { from { opacity: 0; translate: -32px 0; } to { opacity: 1; translate: 0 0; } }')
      ..writeln('@keyframes webui-slide-right { from { opacity: 0; translate: 32px 0; } to { opacity: 1; translate: 0 0; } }')
      ..writeln('@keyframes webui-slide-up { from { opacity: 0; translate: 0 -32px; } to { opacity: 1; translate: 0 0; } }')
      ..writeln('@keyframes webui-slide-down { from { opacity: 0; translate: 0 32px; } to { opacity: 1; translate: 0 0; } }')
      ..writeln('@keyframes webui-fade { from { opacity: 0; } to { opacity: 1; } }')
      ..writeln('@keyframes webui-bounce { 0% { scale: .86; } 55% { scale: 1.06; } 100% { scale: 1; } }');

    final rawById = {
      for (final element in page.elements) element.id: element,
    };

    final desktopLayout = _layoutMap(page, WebBreakpoint.desktop);
    for (final element in page.elements) {
      _writeElementRule(
        buffer,
        page,
        element,
        WebBreakpoint.desktop,
        rawById,
        desktopLayout,
        assets,
      );
      if (element.backplateEnabled && assets[element.backplatePath] != null) {
        buffer
          ..writeln('#${element.id} > .webui-backplate {')
          ..writeln('  object-fit: ${element.backplateFit};')
          ..writeln('}');
      }
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
      final layout = _layoutMap(page, breakpoint);
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
          rawById,
          layout,
          assets,
          indent: '  ',
        );
      }
      buffer.writeln('}');
    }
    return buffer.toString();
  }

  Map<String, WebElement> _layoutMap(
    WebPage page,
    WebBreakpoint breakpoint,
  ) => {
        for (final element in PageLayoutEngine.resolvePage(page, breakpoint))
          element.id: element,
      };

  void _writeElementRule(
    StringBuffer buffer,
    WebPage page,
    WebElement element,
    WebBreakpoint breakpoint,
    Map<String, WebElement> rawById,
    Map<String, WebElement> layout,
    Map<String, String> assets, {
    String indent = '',
  }) {
    final resolved = layout[element.id] ??
        ResponsiveLayoutResolver.resolve(element, page, breakpoint);
    final parent = element.parentId == null ? null : rawById[element.parentId];
    final parentResolved =
        element.parentId == null ? null : layout[element.parentId];
    final autoManaged =
        parent != null && parent.layoutMode != WebLayoutMode.free;
    final nestedFree =
        parent != null && parent.layoutMode == WebLayoutMode.free;
    final targetWidth = breakpoint == WebBreakpoint.desktop
        ? page.width
        : breakpoint.previewWidth;
    final targetHeight = page.height;

    buffer.writeln('$indent#${element.id} {');

    if (autoManaged) {
      buffer
        ..writeln('$indent  position: relative;')
        ..writeln('$indent  left: auto;')
        ..writeln('$indent  right: auto;')
        ..writeln('$indent  top: auto;')
        ..writeln('$indent  bottom: auto;')
        ..writeln(
          '$indent  margin: ${element.marginTop}px ${element.marginRight}px ${element.marginBottom}px ${element.marginLeft}px;',
        );
    } else if (nestedFree && parentResolved != null) {
      final localX = resolved.x - parentResolved.x - parent!.paddingLeft;
      final localY = resolved.y - parentResolved.y - parent.paddingTop;
      buffer
        ..writeln('$indent  position: absolute;')
        ..writeln('$indent  left: ${localX}px;')
        ..writeln('$indent  top: ${localY}px;')
        ..writeln('$indent  right: auto;')
        ..writeln('$indent  bottom: auto;');
    } else {
      for (final declaration in
          _horizontalPositionDeclarations(resolved, targetWidth)) {
        buffer.writeln('$indent  $declaration');
      }
      for (final declaration in
          _verticalPositionDeclarations(resolved, targetHeight)) {
        buffer.writeln('$indent  $declaration');
      }
    }

    buffer
      ..writeln('$indent  width: ${_widthCss(resolved, parent, autoManaged)};')
      ..writeln('$indent  height: ${_heightCss(resolved, parent, autoManaged)};');

    if (autoManaged &&
        parent?.layoutMode == WebLayoutMode.row &&
        resolved.widthMode == WebSizeMode.fill) {
      buffer.writeln('$indent  flex: 1 1 0;');
    }
    if (autoManaged &&
        parent?.layoutMode == WebLayoutMode.column &&
        resolved.heightMode == WebSizeMode.fill) {
      buffer.writeln('$indent  flex: 1 1 0;');
    }

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
    if (!autoManaged && !nestedFree) {
      if (resolved.widthMode != WebSizeMode.fill &&
          resolved.anchorX == 'center') {
        transforms.add('translateX(-50%)');
      }
      if (resolved.heightMode != WebSizeMode.fill &&
          resolved.anchorY == 'center') {
        transforms.add('translateY(-50%)');
      }
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

    if (resolved.maskEnabled && assets[resolved.maskPath] != null) {
      final mask = assets[resolved.maskPath]!;
      buffer
        ..writeln('$indent  -webkit-mask-image: url("$mask");')
        ..writeln('$indent  mask-image: url("$mask");')
        ..writeln('$indent  -webkit-mask-size: cover;')
        ..writeln('$indent  mask-size: cover;')
        ..writeln('$indent  -webkit-mask-repeat: no-repeat;')
        ..writeln('$indent  mask-repeat: no-repeat;');
    }

    final animation = _animationName(resolved);
    if (animation != null) {
      buffer.writeln(
        '$indent  animation: $animation ${resolved.transitionDurationMs}ms cubic-bezier(.2,.8,.2,1) both;',
      );
    }

    if (resolved.textMode == 'fixedSize') {
      buffer
        ..writeln('$indent  white-space: pre;')
        ..writeln('$indent  overflow-wrap: normal;');
    } else {
      buffer
        ..writeln('$indent  white-space: pre-wrap;')
        ..writeln('$indent  overflow-wrap: anywhere;');
      if (resolved.textMode == 'fixedWidth' &&
          resolved.type != WebElementType.image) {
        buffer.writeln('$indent  height: auto;');
      }
    }

    final hasTextEffect = resolved.textHighlightColor != null ||
        resolved.textStrokeColor != null ||
        resolved.textStrokeWidth > 0;

    _writeContainerLayout(buffer, element, indent);

    if (resolved.type == WebElementType.image) {
      buffer.writeln('$indent  overflow: hidden;');
    }
    buffer.writeln('$indent}');

    if (hasTextEffect) {
      buffer.writeln('$indent#${resolved.id} > .webui-text {');
      if (resolved.textHighlightColor != null) {
        buffer.writeln(
          '$indent  background: ${_color(resolved.textHighlightColor!)};',
        );
      }
      if (resolved.textStrokeColor != null && resolved.textStrokeWidth > 0) {
        buffer
          ..writeln(
            '$indent  -webkit-text-stroke: ${resolved.textStrokeWidth}px ${_color(resolved.textStrokeColor!)};',
          )
          ..writeln('$indent  paint-order: stroke fill;');
      }
      buffer.writeln('$indent}');
    }

    if (resolved.pressScaleEnabled) {
      buffer
        ..writeln('$indent#${resolved.id}:active {')
        ..writeln('$indent  scale: ${resolved.pressScale.clamp(.5, 1.0)};')
        ..writeln('$indent}');
    }
  }

  String? _animationName(WebElement element) {
    if (!element.transitionEnabled || element.transition == 'none') return null;
    return switch (element.transition) {
      'slideLeft' => 'webui-slide-left',
      'slideRight' => 'webui-slide-right',
      'slideUp' => 'webui-slide-up',
      'slideDown' => 'webui-slide-down',
      'fade' => 'webui-fade',
      'bounce' => 'webui-bounce',
      _ => null,
    };
  }

  Future<Directory?> _backupExisting(Directory root) async {
    final candidates = <FileSystemEntity>[
      File(p.join(root.path, 'index.html')),
      File(p.join(root.path, 'styles.css')),
      File(p.join(root.path, 'web-ui-canvas.webui')),
      Directory(p.join(root.path, 'assets')),
    ];
    final existing = <FileSystemEntity>[];
    for (final entity in candidates) {
      if (await entity.exists()) existing.add(entity);
    }
    if (existing.isEmpty) return null;

    final stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-');
    final backup = Directory(p.join(root.path, '.webui-backups', stamp));
    await backup.create(recursive: true);

    for (final entity in existing) {
      final name = p.basename(entity.path);
      if (entity is File) {
        await entity.copy(p.join(backup.path, name));
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(p.join(backup.path, name)));
      }
    }
    return backup;
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final entity in source.list(recursive: false, followLinks: false)) {
      final destination = p.join(target.path, p.basename(entity.path));
      if (entity is File) {
        await entity.copy(destination);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(destination));
      }
    }
  }

  String _widthCss(
    WebElement element,
    WebElement? parent,
    bool autoManaged,
  ) {
    if (autoManaged && element.widthMode == WebSizeMode.fill) {
      if (parent?.layoutMode == WebLayoutMode.row) return 'auto';
      return '100%';
    }
    return switch (element.widthMode) {
      WebSizeMode.percent =>
        '${(element.widthPercent * 100).toStringAsFixed(4)}%',
      WebSizeMode.hug => 'max-content',
      WebSizeMode.fill => 'auto',
      WebSizeMode.fixed => '${element.width}px',
    };
  }

  String _heightCss(
    WebElement element,
    WebElement? parent,
    bool autoManaged,
  ) {
    if (autoManaged && element.heightMode == WebSizeMode.fill) {
      if (parent?.layoutMode == WebLayoutMode.column) return 'auto';
      return '100%';
    }
    return switch (element.heightMode) {
      WebSizeMode.percent =>
        '${(element.heightPercent * 100).toStringAsFixed(4)}%',
      WebSizeMode.hug => 'max-content',
      WebSizeMode.fill => 'auto',
      WebSizeMode.fixed => '${element.height}px',
    };
  }

  void _writeContainerLayout(
    StringBuffer buffer,
    WebElement element,
    String indent,
  ) {
    if (!element.canContainChildren) return;
    buffer.writeln(
      '$indent  padding: ${element.paddingTop}px ${element.paddingRight}px ${element.paddingBottom}px ${element.paddingLeft}px;',
    );

    switch (element.layoutMode) {
      case WebLayoutMode.free:
        return;
      case WebLayoutMode.row:
        buffer
          ..writeln('$indent  display: flex;')
          ..writeln('$indent  flex-direction: row;')
          ..writeln('$indent  flex-wrap: nowrap;');
        break;
      case WebLayoutMode.column:
        buffer
          ..writeln('$indent  display: flex;')
          ..writeln('$indent  flex-direction: column;')
          ..writeln('$indent  flex-wrap: nowrap;');
        break;
      case WebLayoutMode.flow:
        buffer
          ..writeln('$indent  display: flex;')
          ..writeln('$indent  flex-direction: row;')
          ..writeln('$indent  flex-wrap: wrap;');
        break;
      case WebLayoutMode.grid:
        buffer
          ..writeln('$indent  display: grid;')
          ..writeln(
            '$indent  grid-template-columns: repeat(${element.gridColumns.clamp(1, 12)}, minmax(0, 1fr));',
          );
        break;
    }

    buffer
      ..writeln('$indent  gap: ${element.gap}px;')
      ..writeln(
        '$indent  justify-content: ${_mainAlignmentCss(element.mainAlignment)};',
      )
      ..writeln(
        '$indent  align-items: ${_crossAlignmentCss(element.crossAlignment)};',
      );
  }

  String _mainAlignmentCss(WebMainAlignment value) => switch (value) {
        WebMainAlignment.center => 'center',
        WebMainAlignment.end => 'flex-end',
        WebMainAlignment.spaceBetween => 'space-between',
        WebMainAlignment.start => 'flex-start',
      };

  String _crossAlignmentCss(WebCrossAlignment value) => switch (value) {
        WebCrossAlignment.center => 'center',
        WebCrossAlignment.end => 'flex-end',
        WebCrossAlignment.stretch => 'stretch',
        WebCrossAlignment.start => 'flex-start',
      };

  List<String> _horizontalPositionDeclarations(
    WebElement element,
    double targetWidth,
  ) {
    if (element.widthMode == WebSizeMode.fill) {
      final right = math.max(0.0, targetWidth - (element.x + element.width));
      return [
        'left: ${element.x}px;',
        'right: ${right}px;',
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
      final bottom = math.max(0.0, targetHeight - (element.y + element.height));
      return [
        'top: ${element.y}px;',
        'bottom: ${bottom}px;',
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
