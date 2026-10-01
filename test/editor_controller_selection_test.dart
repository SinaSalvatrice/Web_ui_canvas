import 'package:flutter_test/flutter_test.dart';
import 'package:web_ui_canvas/src/editor/editor_controller.dart';
import 'package:web_ui_canvas/src/model/web_element.dart';

void main() {
  test('multi-selection moves, nudges and deletes as a group', () {
    final controller = EditorController();
    controller.addElement(WebElementType.text, x: 10, y: 20);
    final first = controller.selectedId!;
    controller.addElement(WebElementType.button, x: 100, y: 120);
    final second = controller.selectedId!;

    controller.selectOnly(first);
    controller.toggleSelection(second);

    expect(controller.selectedIds, {first, second});

    controller.moveBy(first, 5, 7);
    controller.commitLiveEdit();

    final moved = {
      for (final element in controller.activePage.elements) element.id: element,
    };
    expect(moved[first]!.x, 15);
    expect(moved[first]!.y, 27);
    expect(moved[second]!.x, 105);
    expect(moved[second]!.y, 127);

    controller.nudgeSelection(1, -1);
    final nudged = {
      for (final element in controller.activePage.elements) element.id: element,
    };
    expect(nudged[first]!.x, 16);
    expect(nudged[first]!.y, 26);
    expect(nudged[second]!.x, 106);
    expect(nudged[second]!.y, 126);

    controller.removeSelected();
    expect(controller.activePage.elements, isEmpty);
    expect(controller.selectedIds, isEmpty);
  });

  test('copy paste preserves a complete multi-selection', () {
    final controller = EditorController();
    controller.addElement(WebElementType.text, x: 10, y: 20);
    final first = controller.selectedId!;
    controller.addElement(WebElementType.image, x: 100, y: 120);
    final second = controller.selectedId!;

    controller.selectOnly(first);
    controller.toggleSelection(second);
    controller.copySelected();

    expect(controller.canPaste, isTrue);

    controller.pasteCopied();

    expect(controller.activePage.elements, hasLength(4));
    expect(controller.selectedIds, hasLength(2));
    expect(controller.selectedIds.contains(first), isFalse);
    expect(controller.selectedIds.contains(second), isFalse);

    final pasted = controller.selectedElements;
    expect(pasted[0].x, 34);
    expect(pasted[0].y, 44);
    expect(pasted[1].x, 124);
    expect(pasted[1].y, 144);
  });

  test('duplicate keeps relative group geometry', () {
    final controller = EditorController();
    controller.addElement(WebElementType.text, x: 20, y: 30);
    final first = controller.selectedId!;
    controller.addElement(WebElementType.button, x: 80, y: 130);
    final second = controller.selectedId!;

    controller.selectOnly(first);
    controller.toggleSelection(second);
    controller.duplicateSelected();

    expect(controller.activePage.elements, hasLength(4));
    expect(controller.selectedElements, hasLength(2));

    final duplicate = controller.selectedElements;
    expect(duplicate[0].x, 44);
    expect(duplicate[0].y, 54);
    expect(duplicate[1].x, 104);
    expect(duplicate[1].y, 154);
  });

  test('select all and clear selection update primary selection', () {
    final controller = EditorController();
    controller.addElement(WebElementType.text);
    controller.addElement(WebElementType.button);

    controller.selectAll();
    expect(controller.selectedIds, hasLength(2));
    expect(controller.selectedId, isNotNull);

    controller.clearSelection();
    expect(controller.selectedIds, isEmpty);
    expect(controller.selectedId, isNull);
  });
}
