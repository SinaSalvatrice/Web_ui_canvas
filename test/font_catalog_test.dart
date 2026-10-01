import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:web_ui_canvas/src/services/font_catalog.dart';

void main() {
  test('custom font folders are scanned recursively', () async {
    final root = await Directory.systemTemp.createTemp('webui-fonts-');
    addTearDown(() => root.delete(recursive: true));

    final nested = Directory('${root.path}${Platform.pathSeparator}nested');
    await nested.create(recursive: true);
    final font = File(
      '${nested.path}${Platform.pathSeparator}Circuit-Sans-Bold.ttf',
    );
    await font.writeAsBytes(const [0, 1, 2, 3]);

    final before = FontCatalog.instance.entries.length;
    final added = await FontCatalog.instance.addFolder(root.path);
    final entries = FontCatalog.instance.entries;

    expect(added, greaterThanOrEqualTo(1));
    expect(entries.length, greaterThan(before));
    expect(
      entries.any(
        (entry) =>
            entry.family == 'Circuit Sans' &&
            entry.path == font.path &&
            entry.source == 'Custom',
      ),
      isTrue,
    );
  });
}
