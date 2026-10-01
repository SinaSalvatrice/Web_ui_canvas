import 'package:flutter_test/flutter_test.dart';

import 'package:web_ui_canvas/src/model/web_element.dart';

void main() {
  test('every WebElementType exposes a native label', () {
    expect(
      WebElementType.values.map((type) => type.label),
      [
        'Text',
        'Image',
        'Button',
        'Divider',
        'Container',
        'Section',
        'Navigation',
        'Input',
        'Card',
      ],
    );
  });
}
