import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../model/responsive.dart';
import '../model/web_element.dart';
import '../model/web_page.dart';
import '../model/web_project.dart';

class LinkedWebsiteResult {
  const LinkedWebsiteResult({
    required this.project,
    required this.directoryPath,
    required this.projectPath,
    required this.importedFromHtml,
    required this.importedElementCount,
  });

  final WebProject project;
  final String directoryPath;
  final String projectPath;
  final bool importedFromHtml;
  final int importedElementCount;
}

class WebsiteLinkService {
  const WebsiteLinkService();

  Future<LinkedWebsiteResult?> linkExistingWebsite() async {
    final chosen = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose existing website folder',
    );
    if (chosen == null) return null;

    final directory = Directory(chosen);
    if (!await directory.exists()) {
      throw FileSystemException('Website folder does not exist', chosen);
    }

    final preferred = File(p.join(chosen, 'web-ui-canvas.webui'));
    final legacy = File(p.join(chosen, 'website.webui'));
    File? projectFile;

    if (await preferred.exists()) {
      projectFile = preferred;
    } else if (await legacy.exists()) {
      projectFile = legacy;
    } else {
      final files = await directory
          .list(followLinks: false)
          .where((entry) =>
              entry is File && entry.path.toLowerCase().endsWith('.webui'))
          .cast<File>()
          .toList();
      if (files.isNotEmpty) projectFile = files.first;
    }

    if (projectFile != null) {
      final decoded =
          jsonDecode(await projectFile.readAsString()) as Map<String, dynamic>;
      final project = WebProject.fromJson(decoded.cast<String, Object?>())
          .copyWith(linkedWebsitePath: chosen);
      return LinkedWebsiteResult(
        project: project,
        directoryPath: chosen,
        projectPath: projectFile.path,
        importedFromHtml: false,
        importedElementCount:
            project.pages.fold(0, (sum, page) => sum + page.elements.length),
      );
    }

    final htmlFile = File(p.join(chosen, 'index.html'));
    if (!await htmlFile.exists()) {
      throw const FormatException(
        'No index.html or .webui project found in this folder.',
      );
    }

    final html = await htmlFile.readAsString();
    final cssFile = await _findStylesheet(chosen, html);
    final css = cssFile == null ? '' : await cssFile.readAsString();
    final project = _importHtml(
      html,
      css,
      websiteDirectory: chosen,
    ).copyWith(linkedWebsitePath: chosen);

    return LinkedWebsiteResult(
      project: project,
      directoryPath: chosen,
      projectPath: preferred.path,
      importedFromHtml: true,
      importedElementCount: project.pages.first.elements.length,
    );
  }

  Future<File?> _findStylesheet(String directory, String html) async {
    final defaultFile = File(p.join(directory, 'styles.css'));
    if (await defaultFile.exists()) return defaultFile;

    final match = RegExp(
      r'<link\b[^>]*\bhref\s*=\s*["\x27]([^"\x27]+\.css(?:\?[^"\x27]*)?)["\x27][^>]*>',
      caseSensitive: false,
    ).firstMatch(html);
    if (match == null) return null;

    final href = match.group(1)!.split('?').first;
    if (Uri.tryParse(href)?.hasScheme == true) return null;
    final file = File(p.normalize(p.join(directory, Uri.decodeComponent(href))));
    return await file.exists() ? file : null;
  }

  WebProject _importHtml(
    String html,
    String css, {
    required String websiteDirectory,
  }) {
    final titleMatch = RegExp(
      r'<title[^>]*>([\s\S]*?)</title>',
      caseSensitive: false,
    ).firstMatch(html);
    final title = _decodeEntities(titleMatch?.group(1) ?? 'Linked Website');

    final pageRule = _classRule(css, 'webui-page');
    final pageWidth =
        _numberMatch(pageRule, r'width\s*:\s*min\(\s*100%\s*,\s*([\d.]+)px') ??
            1440;
    final pageHeight =
        _numberMatch(pageRule, r'min-height\s*:\s*([\d.]+)px') ?? 2200;
    final pageBackground =
        _colorFrom(_declaration(pageRule, 'background')) ?? 0xffffffff;

    final nodes = _parseDom(html);
    final elements = <WebElement>[];

    for (final node in nodes) {
      final rule = _idRule(css, node.id);
      final imageRule = _imageContentRule(css, node.id);
      final widthValue = _declaration(rule, 'width');
      final heightValue = _declaration(rule, 'height');
      final width = _px(widthValue) ?? node.type.defaultWidth;
      final height = _px(heightValue) ?? node.type.defaultHeight;
      final anchorX = _horizontalAnchor(rule);
      final anchorY = _verticalAnchor(rule);

      var type = node.type;
      if (type == WebElementType.text && node.hasElementChildren) {
        type = WebElementType.container;
      } else if (type == WebElementType.text && height <= 4) {
        type = WebElementType.divider;
      }

      var imagePath = node.imageSource;
      if (imagePath != null &&
          Uri.tryParse(imagePath)?.hasScheme != true &&
          !p.isAbsolute(imagePath)) {
        imagePath =
            p.normalize(p.join(websiteDirectory, Uri.decodeComponent(imagePath)));
      }

      final border = _parseBorder(_declaration(rule, 'border'));
      final widthPercent = _percent(widthValue);
      final heightPercent = _percent(heightValue);

      elements.add(
        WebElement(
          id: node.id,
          type: type,
          x: _resolvedX(rule, pageWidth, width, anchorX),
          y: _resolvedY(rule, pageHeight, height, anchorY),
          width: widthPercent == null ? width : pageWidth * widthPercent,
          height: heightPercent == null ? height : pageHeight * heightPercent,
          rotation: _rotation(rule),
          visible: _declaration(rule, 'visibility') != 'hidden',
          text: node.text.trim(),
          href: node.href ?? '',
          imagePath: imagePath,
          backgroundColor: _colorFrom(_declaration(rule, 'background')),
          foregroundColor:
              _colorFrom(_declaration(rule, 'color')) ?? 0xff202020,
          borderColor: border.$2,
          borderWidth: border.$1,
          borderRadius: _px(_declaration(rule, 'border-radius')) ?? 0,
          opacity:
              double.tryParse(_declaration(rule, 'opacity') ?? '') ?? 1,
          fontSize: _px(_declaration(rule, 'font-size')) ?? 22,
          fontWeight:
              int.tryParse(_declaration(rule, 'font-weight') ?? '') ?? 400,
          fontFamily: _fontFamily(_declaration(rule, 'font-family')),
          anchorX: anchorX,
          anchorY: anchorY,
          imageFit: _declaration(imageRule, 'object-fit') ?? 'cover',
          imageScale: _scale(imageRule),
          widthMode: widthPercent == null
              ? WebSizeMode.fixed
              : WebSizeMode.percent,
          heightMode: heightPercent == null
              ? WebSizeMode.fixed
              : WebSizeMode.percent,
          widthPercent: widthPercent ?? 1,
          heightPercent: heightPercent ?? 1,
          parentId: node.parentId,
        ),
      );
    }

    final page = WebPage(
      id: 'page_home',
      name: 'Home',
      width: pageWidth,
      height: pageHeight,
      backgroundColor: pageBackground,
      elements: elements,
    );
    return WebProject(
      schemaVersion: WebProject.currentSchemaVersion,
      id: 'web_project',
      name: title.isEmpty ? 'Linked Website' : title,
      activePageId: page.id,
      pages: [page],
      linkedWebsitePath: websiteDirectory,
    );
  }

  List<_ImportedNode> _parseDom(String html) {
    final bodyMatch = RegExp(
      r'<body\b[^>]*>([\s\S]*?)</body>',
      caseSensitive: false,
    ).firstMatch(html);
    final source = bodyMatch?.group(1) ?? html;
    final tokens = RegExp(
      r'<!--[\s\S]*?-->|<![^>]*>|</?[^>]+>|[^<]+',
      caseSensitive: false,
    );

    final nodes = <_ImportedNode>[];
    final stack = <_StackEntry>[];
    var generated = 0;

    for (final match in tokens.allMatches(source)) {
      final token = match.group(0)!;

      if (token.startsWith('</')) {
        final close = RegExp(r'^</\s*([\w-]+)', caseSensitive: false)
            .firstMatch(token);
        final tag = close?.group(1)?.toLowerCase();
        if (tag == null) continue;
        for (var i = stack.length - 1; i >= 0; i--) {
          if (stack[i].tag == tag) {
            stack.removeRange(i, stack.length);
            break;
          }
        }
        continue;
      }

      if (token.startsWith('<')) {
        final open = RegExp(r'^<\s*([\w-]+)\b', caseSensitive: false)
            .firstMatch(token);
        if (open == null) continue;
        final tag = open.group(1)!.toLowerCase();

        if (tag == 'img') {
          if (stack.isNotEmpty) {
            final src = _attr(token, 'src');
            if (src != null) stack.last.node.imageSource = src;
          }
          continue;
        }

        if (!_supportedTag(tag)) continue;

        var id = _attr(token, 'id');
        final classes = _attr(token, 'class') ?? '';
        final isWebUi = classes.split(RegExp(r'\s+')).contains('webui-element');

        if (id == null && !isWebUi) {
          if (stack.isNotEmpty) continue;
          generated += 1;
          id = 'imported_' + generated.toString();
        } else if (id == null) {
          generated += 1;
          id = 'imported_' + generated.toString();
        }

        final node = _ImportedNode(
          id: id,
          type: _typeFor(tag, classes),
          parentId: stack.isEmpty ? null : stack.last.node.id,
          href: _attr(token, 'href'),
        );
        if (tag == 'input') {
          node.text = _attr(token, 'placeholder') ?? '';
        }
        nodes.add(node);

        final isVoid = tag == 'input' || token.trimRight().endsWith('/>');
        if (!isVoid) stack.add(_StackEntry(tag, node));
        continue;
      }

      if (stack.isNotEmpty) {
        final text = _decodeEntities(token);
        if (text.isNotEmpty) stack.last.node.text += text + ' ';
      }
    }

    final parents = <String>{};
    for (final node in nodes) {
      if (node.parentId != null) parents.add(node.parentId!);
    }
    for (final node in nodes) {
      node.hasElementChildren = parents.contains(node.id);
    }
    return nodes;
  }

  bool _supportedTag(String tag) => const {
        'div',
        'section',
        'nav',
        'button',
        'a',
        'input',
        'p',
        'span',
        'h1',
        'h2',
        'h3',
        'h4',
        'h5',
        'h6',
        'label',
        'article',
        'aside',
        'header',
        'footer',
        'main',
      }.contains(tag);

  WebElementType _typeFor(String tag, String classes) {
    if (classes.contains('webui-image-frame')) return WebElementType.image;
    return switch (tag) {
      'button' || 'a' => WebElementType.button,
      'input' => WebElementType.input,
      'nav' => WebElementType.navigation,
      'section' => WebElementType.section,
      _ => WebElementType.text,
    };
  }

  String? _attr(String source, String name) {
    final pattern = '\\b' +
        RegExp.escape(name) +
        '\\s*=\\s*["\\x27]([^"\\x27]*)["\\x27]';
    return RegExp(pattern, caseSensitive: false)
        .firstMatch(source)
        ?.group(1);
  }

  String _idRule(String css, String id) {
    final pattern = '#' + RegExp.escape(id) + r'\s*\{([^}]*)\}';
    return RegExp(pattern, caseSensitive: false, multiLine: true)
            .firstMatch(css)
            ?.group(1) ??
        '';
  }

  String _imageContentRule(String css, String id) {
    final pattern = '#' +
        RegExp.escape(id) +
        r'\s*>\s*\.webui-image-content\s*\{([^}]*)\}';
    return RegExp(pattern, caseSensitive: false, multiLine: true)
            .firstMatch(css)
            ?.group(1) ??
        '';
  }

  String _classRule(String css, String className) {
    final pattern =
        r'\.' + RegExp.escape(className) + r'\s*\{([^}]*)\}';
    return RegExp(pattern, caseSensitive: false, multiLine: true)
            .firstMatch(css)
            ?.group(1) ??
        '';
  }

  String? _declaration(String rule, String property) {
    final pattern = '(?:^|;)\\s*' +
        RegExp.escape(property) +
        r'\s*:\s*([^;]+)';
    return RegExp(pattern, caseSensitive: false, multiLine: true)
        .firstMatch(rule)
        ?.group(1)
        ?.trim();
  }

  double? _numberMatch(String source, String pattern) {
    final value =
        RegExp(pattern, caseSensitive: false).firstMatch(source)?.group(1);
    return value == null ? null : double.tryParse(value);
  }

  double? _px(String? value) {
    if (value == null) return null;
    final match =
        RegExp(r'^\s*(-?[\d.]+)px\s*$', caseSensitive: false).firstMatch(value);
    return match == null ? null : double.tryParse(match.group(1)!);
  }

  double? _percent(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^\s*(-?[\d.]+)%\s*$').firstMatch(value);
    final parsed =
        match == null ? null : double.tryParse(match.group(1)!);
    return parsed == null ? null : parsed / 100;
  }

  String _horizontalAnchor(String rule) {
    final right = _declaration(rule, 'right');
    final left = _declaration(rule, 'left') ?? '';
    if (right != null && right != 'auto') return 'right';
    if (left.contains('50%')) return 'center';
    return 'left';
  }

  String _verticalAnchor(String rule) {
    final bottom = _declaration(rule, 'bottom');
    final top = _declaration(rule, 'top') ?? '';
    if (bottom != null && bottom != 'auto') return 'bottom';
    if (top.contains('50%')) return 'center';
    return 'top';
  }

  double _resolvedX(
    String rule,
    double pageWidth,
    double width,
    String anchor,
  ) {
    if (anchor == 'right') {
      final right = _px(_declaration(rule, 'right')) ?? 0;
      return pageWidth - right - width;
    }
    final left = _declaration(rule, 'left') ?? '';
    if (anchor == 'center') {
      return pageWidth / 2 + _calcOffset(left) - width / 2;
    }
    return _px(left) ?? 0;
  }

  double _resolvedY(
    String rule,
    double pageHeight,
    double height,
    String anchor,
  ) {
    if (anchor == 'bottom') {
      final bottom = _px(_declaration(rule, 'bottom')) ?? 0;
      return pageHeight - bottom - height;
    }
    final top = _declaration(rule, 'top') ?? '';
    if (anchor == 'center') {
      return pageHeight / 2 + _calcOffset(top) - height / 2;
    }
    return _px(top) ?? 0;
  }

  double _calcOffset(String value) {
    final match = RegExp(
      r'calc\(\s*50%\s*([+-])\s*([\d.]+)px\s*\)',
      caseSensitive: false,
    ).firstMatch(value);
    if (match == null) return 0;
    final amount = double.tryParse(match.group(2)!) ?? 0;
    return match.group(1) == '-' ? -amount : amount;
  }

  double _rotation(String rule) {
    final transform = _declaration(rule, 'transform') ?? '';
    final match =
        RegExp(r'rotate\(\s*(-?[\d.]+)rad\s*\)').firstMatch(transform);
    return match == null ? 0 : double.tryParse(match.group(1)!) ?? 0;
  }

  double _scale(String rule) {
    final transform = _declaration(rule, 'transform') ?? '';
    final match =
        RegExp(r'scale\(\s*([\d.]+)\s*\)').firstMatch(transform);
    return (match == null ? null : double.tryParse(match.group(1)!)) ?? 1;
  }

  (double, int?) _parseBorder(String? value) {
    if (value == null || value == 'none') return (0, null);
    final match = RegExp(r'([\d.]+)px').firstMatch(value);
    final width =
        match == null ? 0.0 : double.tryParse(match.group(1)!) ?? 0;
    return (width, _colorFrom(value));
  }

  String _fontFamily(String? value) {
    if (value == null || value.isEmpty) return 'Arial';
    var first = value.split(',').first.trim();
    if ((first.startsWith('"') && first.endsWith('"')) ||
        (first.startsWith("'") && first.endsWith("'"))) {
      first = first.substring(1, first.length - 1);
    }
    return first;
  }

  int? _colorFrom(String? value) {
    if (value == null) return null;
    final source = value.trim().toLowerCase();
    if (source == 'transparent') return 0x00000000;

    final hex =
        RegExp(r'#([0-9a-f]{6}|[0-9a-f]{8})').firstMatch(source);
    if (hex != null) {
      final raw = hex.group(1)!;
      return int.parse(raw.length == 6 ? 'ff' + raw : raw, radix: 16);
    }

    final rgba = RegExp(
      r'rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?:\s*,\s*([\d.]+))?\s*\)',
    ).firstMatch(source);
    if (rgba == null) return null;

    final red = int.parse(rgba.group(1)!).clamp(0, 255).toInt();
    final green = int.parse(rgba.group(2)!).clamp(0, 255).toInt();
    final blue = int.parse(rgba.group(3)!).clamp(0, 255).toInt();
    final alpha = ((double.tryParse(rgba.group(4) ?? '1') ?? 1)
                .clamp(0.0, 1.0) *
            255)
        .round();
    return (alpha << 24) | (red << 16) | (green << 8) | blue;
  }

  String _decodeEntities(String value) => value
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class _ImportedNode {
  _ImportedNode({
    required this.id,
    required this.type,
    required this.parentId,
    this.href,
  });

  final String id;
  final WebElementType type;
  final String? parentId;
  final String? href;
  String text = '';
  String? imageSource;
  bool hasElementChildren = false;
}

class _StackEntry {
  const _StackEntry(this.tag, this.node);

  final String tag;
  final _ImportedNode node;
}
