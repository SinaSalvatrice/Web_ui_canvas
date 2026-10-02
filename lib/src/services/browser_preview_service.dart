import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../export/html_exporter.dart';
import '../model/web_project.dart';

class BrowserPreviewService {
  const BrowserPreviewService({
    this.exporter = const HtmlExporter(),
  });

  final HtmlExporter exporter;

  Future<String> open(WebProject project) async {
    final root = Directory(
      p.join(
        Directory.systemTemp.path,
        'web_ui_canvas_preview',
        DateTime.now().microsecondsSinceEpoch.toString(),
      ),
    );
    await root.create(recursive: true);

    final result = await exporter.export(
      project.copyWith(clearLinkedWebsitePath: true),
      targetDirectory: root.path,
    );
    if (result == null) {
      throw StateError('Browser preview could not be generated.');
    }

    final uri = Uri.file(result.htmlFile.path);
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      throw StateError('The system browser could not be opened.');
    }
    return result.htmlFile.path;
  }
}
