import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:web_ui_canvas/src/editor/editor_controller.dart';
import 'package:web_ui_canvas/src/export/html_exporter.dart';
import 'package:web_ui_canvas/src/model/asset_library.dart';
import 'package:web_ui_canvas/src/model/web_element.dart';
import 'package:web_ui_canvas/src/model/web_page.dart';
import 'package:web_ui_canvas/src/model/web_project.dart';

void main() {
  test('project round-trips asset library and element effects', () {
    const element = WebElement(
      id: 'button',
      type: WebElementType.button,
      x: 10,
      y: 20,
      width: 180,
      height: 52,
      text: 'Go',
      backplatePath: 'frame.svg',
      backplateEnabled: true,
      maskPath: 'mask.svg',
      maskEnabled: true,
      textMode: 'fixedWidth',
      textHighlightColor: 0x44ffff00,
      textStrokeColor: 0xff000000,
      textStrokeWidth: 1.5,
      transition: 'slideLeft',
      transitionEnabled: true,
      pressScaleEnabled: true,
    );
    const project = WebProject(
      schemaVersion: WebProject.currentSchemaVersion,
      id: 'p',
      name: 'Test',
      activePageId: 'home',
      pages: [
        WebPage(
          id: 'home',
          name: 'Home',
          width: 1440,
          height: 900,
          backgroundColor: 0xffffffff,
          elements: [element],
        ),
      ],
      assetLibrary: [
        AssetLibraryItem(
          id: 'asset_frame',
          label: 'Frame',
          category: AssetCategory.frames,
          path: 'frame.svg',
        ),
      ],
    );

    final restored = WebProject.fromJson(project.toJson());
    expect(restored.assetLibrary.single.category, AssetCategory.frames);
    final restoredElement = restored.pages.single.elements.single;
    expect(restoredElement.backplateEnabled, isTrue);
    expect(restoredElement.maskEnabled, isTrue);
    expect(restoredElement.textMode, 'fixedWidth');
    expect(restoredElement.transition, 'slideLeft');
    expect(restoredElement.pressScaleEnabled, isTrue);
  });

  test('controller fits page to visible content', () {
    final controller = EditorController();
    controller.addElement(WebElementType.text, x: 50, y: 70);
    final first = controller.selectedElement!;
    controller.updateElement(first.copyWith(width: 200, height: 100));
    controller.addElement(WebElementType.button, x: 500, y: 600);
    final second = controller.selectedElement!;
    controller.updateElement(second.copyWith(width: 250, height: 80));

    controller.fitPageToContent(padding: 40);

    expect(controller.activePage.width, 790);
    expect(controller.activePage.height, 720);
  });

  test('HTML/CSS export emits backplate, mask and interaction effects', () {
    const page = WebPage(
      id: 'home',
      name: 'Home',
      width: 800,
      height: 600,
      backgroundColor: 0xffffffff,
      elements: [
        WebElement(
          id: 'cta',
          type: WebElementType.button,
          x: 20,
          y: 30,
          width: 200,
          height: 60,
          text: 'Click',
          backplatePath: 'frame.svg',
          backplateEnabled: true,
          maskPath: 'mask.svg',
          maskEnabled: true,
          textHighlightColor: 0x66ffff00,
          textStrokeColor: 0xff000000,
          textStrokeWidth: 1,
          transition: 'bounce',
          transitionEnabled: true,
          pressScaleEnabled: true,
          pressScale: .94,
        ),
        WebElement(
          id: 'switch',
          type: WebElementType.toggle,
          x: 20,
          y: 120,
          width: 64,
          height: 36,
        ),
      ],
    );
    const exporter = HtmlExporter();
    const assets = {
      'frame.svg': 'assets/frame.svg',
      'mask.svg': 'assets/mask.svg',
    };

    final html = exporter.buildHtmlForPage(page, assets: assets);
    final css = exporter.buildCssForPage(page, assets: assets);

    expect(html, contains('class="webui-backplate"'));
    expect(html, contains('data-webui-toggle'));
    expect(css, contains('mask-image: url("assets/mask.svg")'));
    expect(css, contains('animation: webui-bounce'));
    expect(css, contains('-webkit-text-stroke: 1.0px'));
    expect(css, contains('#cta:active'));
  });

  test('updating an existing export creates an automatic backup', () async {
    final root = await Directory.systemTemp.createTemp('webui_backup_test_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    final oldHtml = File('${root.path}${Platform.pathSeparator}index.html');
    final oldCss = File('${root.path}${Platform.pathSeparator}styles.css');
    await oldHtml.writeAsString('old html');
    await oldCss.writeAsString('old css');

    final project = WebProject.empty();
    const exporter = HtmlExporter();
    final result = await exporter.export(
      project,
      targetDirectory: root.path,
    );

    expect(result, isNotNull);
    expect(result!.backupDirectory, isNotNull);
    final backup = result.backupDirectory!;
    expect(
      await File('${backup.path}${Platform.pathSeparator}index.html')
          .readAsString(),
      'old html',
    );
    expect(
      await File('${backup.path}${Platform.pathSeparator}styles.css')
          .readAsString(),
      'old css',
    );
  });
}
