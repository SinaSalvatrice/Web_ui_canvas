import 'package:flutter_test/flutter_test.dart';
import 'package:web_ui_canvas/src/editor/editor_controller.dart';
import 'package:web_ui_canvas/src/model/web_element.dart';

void main() {
  test('single selection aligns to canvas edges and center', () {
    final controller = EditorController();
    controller.addElement(WebElementType.button, x: 100, y: 200);

    final page = controller.activePage;
    final element = controller.selectedElement!;

    controller.alignSelection(SelectionAlignment.left);
    expect(controller.selectedElement!.x, 0);

    controller.alignSelection(SelectionAlignment.horizontalCenter);
    expect(
      controller.selectedElement!.x,
      closeTo((page.width - element.width) / 2, .001),
    );

    controller.alignSelection(SelectionAlignment.bottom);
    expect(
      controller.selectedElement!.y,
      closeTo(page.height - element.height, .001),
    );
  });

  test('multiple selection aligns inside shared selection bounds', () {
    final controller = EditorController();
    controller.addElement(WebElementType.button, x: 100, y: 120);
    final first = controller.selectedId!;
    controller.addElement(WebElementType.button, x: 500, y: 420);
    final second = controller.selectedId!;

    controller.selectOnly(first);
    controller.toggleSelection(second);

    controller.alignSelection(SelectionAlignment.left);

    final elements = {
      for (final element in controller.selectedElements) element.id: element,
    };
    expect(elements[first]!.x, 100);
    expect(elements[second]!.x, 100);

    controller.alignSelection(SelectionAlignment.verticalCenter);

    final centered = {
      for (final element in controller.selectedElements) element.id: element,
    };
    expect(centered[first]!.y, centered[second]!.y);
  });

  test('horizontal distribution creates equal gaps', () {
    final controller = EditorController();
    controller.addElement(WebElementType.text, x: 0, y: 100);
    final first = controller.selectedId!;
    controller.addElement(WebElementType.text, x: 500, y: 100);
    final second = controller.selectedId!;
    controller.addElement(WebElementType.text, x: 1200, y: 100);
    final third = controller.selectedId!;

    controller.selectOnly(first);
    controller.toggleSelection(second);
    controller.toggleSelection(third);
    controller.distributeSelection(SelectionDistribution.horizontal);

    final elements = {
      for (final element in controller.selectedElements) element.id: element,
    };

    final gap1 =
        elements[second]!.x - (elements[first]!.x + elements[first]!.width);
    final gap2 =
        elements[third]!.x - (elements[second]!.x + elements[second]!.width);
    expect(gap1, closeTo(gap2, .001));
    expect(elements[first]!.x, 0);
    expect(elements[third]!.x, 1200);
  });

  test('distribution ignores locked selected elements', () {
    final controller = EditorController();
    controller.addElement(WebElementType.button, x: 0, y: 0);
    final first = controller.selectedId!;
    controller.addElement(WebElementType.button, x: 400, y: 0);
    final locked = controller.selectedId!;
    controller.updateElement(controller.selectedElement!.copyWith(locked: true));
    controller.addElement(WebElementType.button, x: 800, y: 0);
    final third = controller.selectedId!;
    controller.addElement(WebElementType.button, x: 1200, y: 0);
    final fourth = controller.selectedId!;

    controller.selectOnly(first);
    controller.toggleSelection(locked);
    controller.toggleSelection(third);
    controller.toggleSelection(fourth);

    controller.distributeSelection(SelectionDistribution.horizontal);

    final byId = {
      for (final element in controller.activePage.elements) element.id: element,
    };
    expect(byId[locked]!.x, 400);
  });
}
