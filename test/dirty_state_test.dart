import 'package:flutter_test/flutter_test.dart';
import 'package:web_ui_canvas/src/editor/editor_controller.dart';
import 'package:web_ui_canvas/src/model/web_element.dart';

void main() {
  test('project fingerprint changes only with project content', () {
    final controller = EditorController();
    final clean = controller.projectFingerprint;

    controller.selectAll();
    expect(controller.projectFingerprint, clean);

    controller.addElement(WebElementType.text, x: 10, y: 20);
    final dirty = controller.projectFingerprint;
    expect(dirty, isNot(clean));

    controller.undo();
    expect(controller.projectFingerprint, clean);

    controller.redo();
    expect(controller.projectFingerprint, dirty);
  });
}
