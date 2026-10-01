import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../model/web_project.dart';

class ProjectStorage {
  const ProjectStorage();

  Future<(WebProject, String)?> openProject() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['webui'],
      allowMultiple: false,
      dialogTitle: 'Open Web UI Canvas project',
    );
    final path = result?.files.single.path;
    if (path == null) return null;
    final source = await File(path).readAsString();
    final json = jsonDecode(source) as Map<String, dynamic>;
    return (WebProject.fromJson(json.cast<String, Object?>()), path);
  }

  Future<String?> saveProject(
    WebProject project, {
    String? existingPath,
  }) async {
    var path = existingPath;
    if (path == null) {
      path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Web UI Canvas project',
        fileName: 'website.webui',
        type: FileType.custom,
        allowedExtensions: const ['webui'],
      );
    }
    if (path == null) return null;
    if (!path.toLowerCase().endsWith('.webui')) {
      path = '$path.webui';
    }
    final text = const JsonEncoder.withIndent('  ').convert(project.toJson());
    await File(path).writeAsString('$text\n', flush: true);
    return path;
  }
}
