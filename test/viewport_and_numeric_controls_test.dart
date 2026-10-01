import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_ui_canvas/src/editor/editor_controller.dart';
import 'package:web_ui_canvas/src/editor/widgets/canvas_view.dart';
import 'package:web_ui_canvas/src/editor/widgets/inspector_panel.dart';
import 'package:web_ui_canvas/src/model/web_element.dart';

void main() {
  test('viewport controller clamps zoom and resets transform', () {
    final viewport = CanvasViewportController();

    viewport.setZoom(2);
    expect(viewport.zoom, 2);

    viewport.setZoom(99);
    expect(viewport.zoom, 4);

    viewport.setZoom(.01);
    expect(viewport.zoom, .20);

    viewport.scrollBy(const Offset(30, 40));
    final moved = viewport.transformation.value.getTranslation();
    expect(moved.x, -30);
    expect(moved.y, -40);

    viewport.reset();
    expect(viewport.zoom, 1);
    final reset = viewport.transformation.value.getTranslation();
    expect(reset.x, 0);
    expect(reset.y, 0);

    viewport.dispose();
  });

  testWidgets('numeric inspector field changes by one per wheel step',
      (tester) async {
    final controller = EditorController();
    controller.addElement(WebElementType.text, x: 10, y: 20);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: controller,
            builder: (context, _) => SizedBox(
              width: 360,
              height: 800,
              child: InspectorPanel(controller: controller),
            ),
          ),
        ),
      ),
    );

    final field = find.byKey(const ValueKey('X-10.000'));
    expect(field, findsOneWidget);

    tester.binding.handlePointerEvent(
      PointerScrollEvent(
        position: tester.getCenter(field),
        scrollDelta: const Offset(0, -100),
      ),
    );
    await tester.pump();

    expect(controller.selectedElement!.x, 11);
  });
}
