import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../model/web_project.dart';

class ProjectStorage {
  const ProjectStorage();

  Future<(WebProject, String)?> openProject() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['webui'],
      dialogTitle: 'Open Web UI Canvas project',
    );
    if (file == null) return null;

    final source = utf8.decode(await file.readAsBytes());
    final json = jsonDecode(source) as Map<String, dynamic>;
    final location = file.path ?? file.uri.toString();
    return (WebProject.fromJson(json.cast<String, Object?>()), location);
  }

  Future<String?> saveProject(
    WebProject project, {
    String? existingPath,
  }) async {
    final text = const JsonEncoder.withIndent('  ').convert(project.toJson());
    final bytes = Uint8List.fromList(utf8.encode('$text\n'));

    if (existingPath != null) {
      final existingUri = Uri.tryParse(existingPath);
      final isDirectFile = existingUri == null ||
          !existingUri.hasScheme ||
          existingUri.scheme == 'file';

      if (isDirectFile) {
        var path = existingUri?.scheme == 'file'
            ? existingUri!.toFilePath()
            : existingPath;
        if (!path.toLowerCase().endsWith('.webui')) {
          path = '$path.webui';
        }
        await File(path).writeAsBytes(bytes, flush: true);
        return path;
      }
    }

    final uri = await FilePicker.saveFile(
      dialogTitle: 'Save Web UI Canvas project',
      fileName: 'website.webui',
      bytes: bytes,
      mimeType: 'application/json',
      type: FileType.custom,
      allowedExtensions: const ['webui'],
    );
    if (uri == null) return null;
    return uri.scheme == 'file' ? uri.toFilePath() : uri.toString();
  }
}
