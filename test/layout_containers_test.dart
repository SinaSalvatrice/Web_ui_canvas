import 'package:flutter_test/flutter_test.dart';
import 'package:web_ui_canvas/src/editor/editor_controller.dart';
import 'package:web_ui_canvas/src/export/html_exporter.dart';
import 'package:web_ui_canvas/src/model/layout.dart';
import 'package:web_ui_canvas/src/model/page_layout_engine.dart';
import 'package:web_ui_canvas/src/model/responsive.dart';
import 'package:web_ui_canvas/src/model/web_element.dart';
import 'package:web_ui_canvas/src/model/web_page.dart';

void main() {
  WebElement box(
    String id, {
    double x = 0,
    double y = 0,
    double width = 100,
    double height = 50,
    String? parentId,
    WebSizeMode widthMode = WebSizeMode.fixed,
    WebSizeMode heightMode = WebSizeMode.fixed,
  }) {
    return WebElement(
      id: id,
      type: WebElementType.button,
      x: x,
      y: y,
      width: width,
      height: height,
      parentId: parentId,
      widthMode: widthMode,
      heightMode: heightMode,
    );
  }

  test('row layout positions children with padding gap and margins', () {
    final parent = WebElement(
      id: 'row',
      type: WebElementType.container,
      x: 100,
      y: 200,
      width: 500,
      height: 160,
      layoutMode: WebLayoutMode.row,
      gap: 20,
      paddingLeft: 30,
      paddingRight: 30,
      paddingTop: 10,
      paddingBottom: 10,
    );
    final first = box('a', parentId: 'row');
    final second = box('b', parentId: 'row');

    final page = WebPage(
      id: 'home',
      name: 'Home',
      width: 1440,
      height: 1200,
      backgroundColor: 0xffffffff,
      elements: [parent, first, second],
    );

    final layout = {
      for (final element
          in PageLayoutEngine.resolvePage(page, WebBreakpoint.desktop))
        element.id: element,
    };

    expect(layout['a']!.x, 130);
    expect(layout['a']!.y, 210);
    expect(layout['b']!.x, 250);
  });

  test('row fill children share remaining width', () {
    final parent = WebElement(
      id: 'row',
      type: WebElementType.container,
      x: 0,
      y: 0,
      width: 500,
      height: 100,
      layoutMode: WebLayoutMode.row,
      gap: 10,
    );
    final fixed = box('fixed', width: 100, parentId: 'row');
    final fillA = box(
      'fillA',
      parentId: 'row',
      widthMode: WebSizeMode.fill,
    );
    final fillB = box(
      'fillB',
      parentId: 'row',
      widthMode: WebSizeMode.fill,
    );

    final page = WebPage(
      id: 'home',
      name: 'Home',
      width: 1440,
      height: 1000,
      backgroundColor: 0xffffffff,
      elements: [parent, fixed, fillA, fillB],
    );

    final layout = {
      for (final element
          in PageLayoutEngine.resolvePage(page, WebBreakpoint.desktop))
        element.id: element,
    };

    expect(layout['fillA']!.width, closeTo(190, .001));
    expect(layout['fillB']!.width, closeTo(190, .001));
  });

  test('grid uses configured column count', () {
    final parent = WebElement(
      id: 'grid',
      type: WebElementType.container,
      x: 50,
      y: 50,
      width: 400,
      height: 400,
      layoutMode: WebLayoutMode.grid,
      gridColumns: 2,
      gap: 20,
      crossAlignment: WebCrossAlignment.stretch,
    );
    final children = [
      box('a', parentId: 'grid'),
      box('b', parentId: 'grid'),
      box('c', parentId: 'grid'),
    ];

    final page = WebPage(
      id: 'home',
      name: 'Home',
      width: 1440,
      height: 1000,
      backgroundColor: 0xffffffff,
      elements: [parent, ...children],
    );

    final layout = {
      for (final element
          in PageLayoutEngine.resolvePage(page, WebBreakpoint.desktop))
        element.id: element,
    };

    expect(layout['a']!.x, 50);
    expect(layout['b']!.x, 260);
    expect(layout['c']!.x, 50);
    expect(layout['a']!.width, closeTo(190, .001));
  });

  test('flow wraps children to the next line', () {
    final parent = WebElement(
      id: 'flow',
      type: WebElementType.container,
      x: 0,
      y: 0,
      width: 250,
      height: 300,
      layoutMode: WebLayoutMode.flow,
      gap: 10,
    );
    final page = WebPage(
      id: 'home',
      name: 'Home',
      width: 1440,
      height: 1000,
      backgroundColor: 0xffffffff,
      elements: [
        parent,
        box('a', width: 120, parentId: 'flow'),
        box('b', width: 120, parentId: 'flow'),
        box('c', width: 120, parentId: 'flow'),
      ],
    );

    final layout = {
      for (final element
          in PageLayoutEngine.resolvePage(page, WebBreakpoint.desktop))
        element.id: element,
    };

    expect(layout['a']!.y, 0);
    expect(layout['b']!.y, 0);
    expect(layout['c']!.y, greaterThan(0));
  });

  test('parent assignment preserves visible position and blocks cycles', () {
    final controller = EditorController();
    controller.addElement(WebElementType.container, x: 100, y: 100);
    final parentId = controller.selectedId!;
    controller.updateElement(
      controller.selectedElement!.copyWith(
        paddingLeft: 20,
        paddingTop: 30,
      ),
    );

    controller.addElement(WebElementType.button, x: 400, y: 500);
    final childId = controller.selectedId!;
    final before = controller.resolvedSelectedElement!;

    controller.setParent(childId, parentId);
    final after = controller.resolvedSelectedElement!;

    expect(after.x, closeTo(before.x, .001));
    expect(after.y, closeTo(before.y, .001));
    expect(controller.selectedElement!.parentId, parentId);

    controller.setParent(parentId, childId);
    final parent = controller.activePage.elements
        .firstWhere((element) => element.id == parentId);
    expect(parent.parentId, isNull);
  });

  test('export emits nested html and real flex grid css', () {
    const row = WebElement(
      id: 'row',
      type: WebElementType.container,
      x: 0,
      y: 0,
      width: 600,
      height: 120,
      layoutMode: WebLayoutMode.row,
      gap: 12,
      paddingLeft: 16,
      paddingRight: 16,
    );
    const child = WebElement(
      id: 'child',
      type: WebElementType.text,
      x: 0,
      y: 0,
      width: 200,
      height: 60,
      parentId: 'row',
      text: 'Hello',
    );
    const grid = WebElement(
      id: 'grid',
      type: WebElementType.container,
      x: 0,
      y: 180,
      width: 600,
      height: 300,
      layoutMode: WebLayoutMode.grid,
      gridColumns: 3,
    );
    const page = WebPage(
      id: 'home',
      name: 'Home',
      width: 1440,
      height: 1000,
      backgroundColor: 0xffffffff,
      elements: [row, child, grid],
    );

    const exporter = HtmlExporter();
    final html = exporter.buildHtmlForPage(page);
    final css = exporter.buildCssForPage(page);

    expect(
      html,
      contains(
        '<div id="row" class="webui-element"><div id="child" class="webui-element">Hello</div></div>',
      ),
    );
    expect(css, contains('display: flex;'));
    expect(css, contains('flex-direction: row;'));
    expect(css, contains('display: grid;'));
    expect(css, contains('grid-template-columns: repeat(3, minmax(0, 1fr));'));
  });
}
