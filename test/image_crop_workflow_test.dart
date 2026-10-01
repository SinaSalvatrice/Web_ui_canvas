import 'package:flutter_test/flutter_test.dart';
import 'package:web_ui_canvas/src/editor/editor_controller.dart';
import 'package:web_ui_canvas/src/model/web_element.dart';

void main() {
  test('crop mode pans image content without moving the frame', () {
    final controller = EditorController();
    controller.addElement(WebElementType.image, x: 50, y: 60);
    final id = controller.selectedId!;
    final original = controller.selectedElement!;

    controller.updateElement(
      original.copyWith(imageScale: 2),
    );
    final cleanFrame = controller.selectedElement!;

    controller.enterCropMode(id);
    final beforeFingerprint = controller.projectFingerprint;

    controller.panImage(id, 42, 28);
    controller.commitLiveEdit();

    final cropped = controller.selectedElement!;
    expect(cropped.x, cleanFrame.x);
    expect(cropped.y, cleanFrame.y);
    expect(cropped.width, cleanFrame.width);
    expect(cropped.height, cleanFrame.height);
    expect(cropped.imagePositionX, closeTo(-.1, .0001));
    expect(cropped.imagePositionY, closeTo(-.1, .0001));
    expect(controller.isCropping(id), isTrue);
    expect(controller.projectFingerprint, isNot(beforeFingerprint));
  });

  test('crop pan is clamped and reset restores neutral crop', () {
    final controller = EditorController();
    controller.addElement(WebElementType.image, x: 0, y: 0);
    final id = controller.selectedId!;

    controller.enterCropMode(id);
    controller.panImage(id, 100000, -100000);
    controller.commitLiveEdit();

    final clamped = controller.selectedElement!;
    expect(clamped.imagePositionX, -1);
    expect(clamped.imagePositionY, 1);

    controller.updateElement(clamped.copyWith(imageScale: 4));
    controller.resetImageCrop(id);

    final reset = controller.selectedElement!;
    expect(reset.imagePositionX, 0);
    expect(reset.imagePositionY, 0);
    expect(reset.imageScale, 1);
  });

  test('crop editor mode itself does not dirty the project', () {
    final controller = EditorController();
    controller.addElement(WebElementType.image);
    final id = controller.selectedId!;
    final fingerprint = controller.projectFingerprint;

    controller.enterCropMode(id);
    expect(controller.projectFingerprint, fingerprint);

    controller.exitCropMode();
    expect(controller.projectFingerprint, fingerprint);
  });

  test('selecting another element exits crop mode', () {
    final controller = EditorController();
    controller.addElement(WebElementType.image);
    final imageId = controller.selectedId!;
    controller.addElement(WebElementType.text);
    final textId = controller.selectedId!;

    controller.enterCropMode(imageId);
    expect(controller.isCropping(imageId), isTrue);

    controller.selectOnly(textId);
    expect(controller.isCropMode, isFalse);
  });
}
