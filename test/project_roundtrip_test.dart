import 'package:flutter_test/flutter_test.dart';
import 'package:web_ui_canvas/src/model/layout.dart';
import 'package:web_ui_canvas/src/model/responsive.dart';
import 'package:web_ui_canvas/src/model/web_element.dart';
import 'package:web_ui_canvas/src/model/web_page.dart';
import 'package:web_ui_canvas/src/model/web_project.dart';

void main() {
  test('web project survives json roundtrip', () {
    const element = WebElement(
      id: 'headline',
      type: WebElementType.text,
      x: 10,
      y: 20,
      width: 300,
      height: 80,
      text: 'Hello',
      fontFamily: 'Circuit Test',
      fontPath: r'C:\Fonts\CircuitTest.ttf',
      letterSpacing: 1.75,
      lineHeight: 1.45,
      imagePositionX: -.4,
      imagePositionY: .35,
      imageScale: 2.25,
      widthMode: WebSizeMode.percent,
      widthPercent: .6,
      minWidth: 220,
      maxWidth: 720,
      responsiveOverrides: {
        WebBreakpoint.tablet: WebElementBreakpointOverride(
          x: 44,
          widthPercent: .8,
        ),
        WebBreakpoint.mobile: WebElementBreakpointOverride(
          x: 18,
          widthMode: WebSizeMode.fill,
        ),
      },
    );
    const page = WebPage(
      id: 'home',
      name: 'Home',
      width: 1440,
      height: 2200,
      backgroundColor: 0xffffffff,
      elements: [element],
    );
    const project = WebProject(
      schemaVersion: WebProject.currentSchemaVersion,
      id: 'demo',
      name: 'Demo',
      activePageId: 'home',
      pages: [page],
    );

    final restored = WebProject.fromJson(project.toJson());
    expect(restored.name, 'Demo');
    expect(restored.pages.single.elements.single.text, 'Hello');
    expect(restored.pages.single.width, 1440);
    final restoredElement = restored.pages.single.elements.single;
    expect(restoredElement.fontFamily, 'Circuit Test');
    expect(restoredElement.fontPath, r'C:\Fonts\CircuitTest.ttf');
    expect(restoredElement.letterSpacing, 1.75);
    expect(restoredElement.lineHeight, 1.45);
    expect(restoredElement.imagePositionX, -.4);
    expect(restoredElement.imagePositionY, .35);
    expect(restoredElement.imageScale, 2.25);
    expect(restoredElement.widthMode, WebSizeMode.percent);
    expect(restoredElement.widthPercent, .6);
    expect(restoredElement.minWidth, 220);
    expect(restoredElement.maxWidth, 720);
    expect(
      restoredElement
          .responsiveOverrides[WebBreakpoint.tablet]!
          .widthPercent,
      .8,
    );
    expect(
      restoredElement
          .responsiveOverrides[WebBreakpoint.mobile]!
          .widthMode,
      WebSizeMode.fill,
    );
  });

  test('container layout fields survive json roundtrip', () {
    const parent = WebElement(
      id: 'layout',
      type: WebElementType.container,
      x: 100,
      y: 120,
      width: 800,
      height: 500,
      layoutMode: WebLayoutMode.grid,
      gap: 24,
      paddingTop: 12,
      paddingRight: 18,
      paddingBottom: 20,
      paddingLeft: 16,
      gridColumns: 3,
      mainAlignment: WebMainAlignment.spaceBetween,
      crossAlignment: WebCrossAlignment.stretch,
    );
    const child = WebElement(
      id: 'child',
      type: WebElementType.text,
      x: 0,
      y: 0,
      width: 200,
      height: 80,
      parentId: 'layout',
      marginTop: 4,
      marginRight: 5,
      marginBottom: 6,
      marginLeft: 7,
    );
    const page = WebPage(
      id: 'layout-page',
      name: 'Layout',
      width: 1440,
      height: 1200,
      backgroundColor: 0xffffffff,
      elements: [parent, child],
    );
    const project = WebProject(
      schemaVersion: WebProject.currentSchemaVersion,
      id: 'layout-project',
      name: 'Layout project',
      activePageId: 'layout-page',
      pages: [page],
    );

    final restored = WebProject.fromJson(project.toJson());
    final restoredParent = restored.pages.single.elements.first;
    final restoredChild = restored.pages.single.elements.last;

    expect(restoredParent.layoutMode, WebLayoutMode.grid);
    expect(restoredParent.gridColumns, 3);
    expect(restoredParent.gap, 24);
    expect(restoredParent.paddingLeft, 16);
    expect(restoredParent.mainAlignment, WebMainAlignment.spaceBetween);
    expect(restoredParent.crossAlignment, WebCrossAlignment.stretch);
    expect(restoredChild.parentId, 'layout');
    expect(restoredChild.marginLeft, 7);
    expect(restoredChild.marginBottom, 6);
  });

  test('schema v1 projects migrate to current schema', () {
    final legacy = <String, Object?>{
      'schemaVersion': 1,
      'kind': 'web-ui-canvas.project',
      'id': 'legacy',
      'name': 'Legacy',
      'activePageId': 'home',
      'pages': [
        {
          'id': 'home',
          'name': 'Home',
          'width': 1440,
          'height': 2200,
          'backgroundColor': 0xffffffff,
          'elements': [
            {
              'id': 'text',
              'type': 'text',
              'x': 10,
              'y': 20,
              'width': 300,
              'height': 80,
            },
          ],
        },
      ],
    };

    final migrated = WebProject.fromJson(legacy);
    expect(migrated.schemaVersion, WebProject.currentSchemaVersion);
    expect(migrated.pages.single.elements.single.widthMode, WebSizeMode.fixed);
    expect(
      migrated.pages.single.elements.single.responsiveOverrides,
      isEmpty,
    );
  });
}
