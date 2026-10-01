import 'package:flutter_test/flutter_test.dart';
import 'package:web_ui_canvas/src/editor/editor_controller.dart';
import 'package:web_ui_canvas/src/export/html_exporter.dart';
import 'package:web_ui_canvas/src/model/responsive.dart';
import 'package:web_ui_canvas/src/model/responsive_layout.dart';
import 'package:web_ui_canvas/src/model/web_element.dart';
import 'package:web_ui_canvas/src/model/web_page.dart';

void main() {
  const page = WebPage(
    id: 'home',
    name: 'Home',
    width: 1440,
    height: 2200,
    backgroundColor: 0xffffffff,
  );

  test('mobile inherits tablet override then applies mobile changes', () {
    const element = WebElement(
      id: 'hero',
      type: WebElementType.text,
      x: 100,
      y: 80,
      width: 600,
      height: 120,
      widthPercent: .5,
      responsiveOverrides: {
        WebBreakpoint.tablet: WebElementBreakpointOverride(
          x: 60,
          widthMode: WebSizeMode.percent,
          widthPercent: .5,
        ),
        WebBreakpoint.mobile: WebElementBreakpointOverride(
          x: 20,
        ),
      },
    );

    final tablet = ResponsiveLayoutResolver.resolve(
      element,
      page,
      WebBreakpoint.tablet,
    );
    final mobile = ResponsiveLayoutResolver.resolve(
      element,
      page,
      WebBreakpoint.mobile,
    );

    expect(tablet.x, 60);
    expect(tablet.width, 450);
    expect(tablet.widthMode, WebSizeMode.percent);

    expect(mobile.x, 20);
    expect(mobile.width, 195);
    expect(mobile.widthMode, WebSizeMode.percent);
  });

  test('right anchor keeps the desktop right inset on mobile', () {
    const element = WebElement(
      id: 'button',
      type: WebElementType.button,
      x: 1200,
      y: 80,
      width: 200,
      height: 52,
      anchorX: 'right',
    );

    final mobile = ResponsiveLayoutResolver.resolve(
      element,
      page,
      WebBreakpoint.mobile,
    );

    expect(mobile.x, 150);
    expect(390 - (mobile.x + mobile.width), 40);
  });

  test('fill preserves left and right insets', () {
    const element = WebElement(
      id: 'section',
      type: WebElementType.section,
      x: 24,
      y: 100,
      width: 1392,
      height: 300,
      widthMode: WebSizeMode.fill,
    );

    final mobile = ResponsiveLayoutResolver.resolve(
      element,
      page,
      WebBreakpoint.mobile,
    );

    expect(mobile.x, 24);
    expect(mobile.width, 342);
  });

  test('moving on mobile writes only a mobile override', () {
    final controller = EditorController();
    controller.addElement(WebElementType.button, x: 100, y: 120);
    final id = controller.selectedId!;
    final desktop = controller.selectedElement!;

    controller.setActiveBreakpoint(WebBreakpoint.mobile);
    final before = controller.resolvedSelectedElement!;
    controller.moveBy(id, 10, 15);
    controller.commitLiveEdit();

    final raw = controller.selectedElement!;
    final mobile = controller.resolvedSelectedElement!;

    expect(raw.x, desktop.x);
    expect(raw.y, desktop.y);
    expect(raw.responsiveOverrides[WebBreakpoint.mobile], isNotNull);
    expect(mobile.x, before.x + 10);
    expect(mobile.y, before.y + 15);
  });

  test('single alignment uses active breakpoint viewport', () {
    final controller = EditorController();
    controller.addElement(WebElementType.button, x: 100, y: 100);
    controller.setActiveBreakpoint(WebBreakpoint.mobile);

    controller.alignSelection(SelectionAlignment.right);

    final mobile = controller.resolvedSelectedElement!;
    expect(mobile.x + mobile.width, closeTo(390, .001));
  });

  test('export emits responsive media queries and percent sizing', () {
    const element = WebElement(
      id: 'copy',
      type: WebElementType.text,
      x: 40,
      y: 60,
      width: 500,
      height: 100,
      responsiveOverrides: {
        WebBreakpoint.tablet: WebElementBreakpointOverride(
          widthMode: WebSizeMode.percent,
          widthPercent: .5,
        ),
      },
    );
    const exportPage = WebPage(
      id: 'home',
      name: 'Home',
      width: 1440,
      height: 2200,
      backgroundColor: 0xffffffff,
      elements: [element],
    );

    final css = const HtmlExporter().buildCssForPage(exportPage);

    expect(css, contains('@media (max-width: 1024px)'));
    expect(css, contains('@media (max-width: 600px)'));
    expect(css, contains('width: 50.0000%;'));
    expect(css, contains('width: min(100%, 1440.0px);'));
  });
}
