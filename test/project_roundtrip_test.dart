import 'package:flutter_test/flutter_test.dart';
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
  });
}
