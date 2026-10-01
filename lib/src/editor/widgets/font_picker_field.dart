import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/font_catalog.dart';

class FontPickerField extends StatelessWidget {
  const FontPickerField({
    required this.family,
    required this.path,
    required this.onSelected,
    super.key,
  });

  final String family;
  final String? path;
  final void Function(String family, String? path) onSelected;

  @override
  Widget build(BuildContext context) {
    final catalog = FontCatalog.instance;
    return ListenableBuilder(
      listenable: catalog,
      builder: (context, _) {
        return InkWell(
          onTap: () => _showPicker(context),
          borderRadius: BorderRadius.circular(8),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Font family',
              suffixIcon: Icon(Icons.arrow_drop_down),
            ),
            child: Text(
              family,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: family),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final catalog = FontCatalog.instance;
    await catalog.discoverSystemFonts();
    if (!context.mounted) return;

    final selected = await showDialog<FontEntry>(
      context: context,
      builder: (dialogContext) => _FontPickerDialog(catalog: catalog),
    );
    if (selected == null) return;

    await catalog.ensureLoaded(
      family: selected.family,
      path: selected.path,
    );
    onSelected(selected.family, selected.path);
  }
}

class _FontPickerDialog extends StatefulWidget {
  const _FontPickerDialog({required this.catalog});

  final FontCatalog catalog;

  @override
  State<_FontPickerDialog> createState() => _FontPickerDialogState();
}

class _FontPickerDialogState extends State<_FontPickerDialog> {
  String _query = '';
  bool _addingFolder = false;

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final entries = widget.catalog.entries
        .where(
          (entry) =>
              query.isEmpty ||
              entry.family.toLowerCase().contains(query) ||
              entry.source.toLowerCase().contains(query),
        )
        .toList();

    return AlertDialog(
      title: const Text('Choose font'),
      content: SizedBox(
        width: 520,
        height: 560,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search fonts',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: _addingFolder ? null : _addFolder,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Add font folder'),
                ),
                const SizedBox(width: 10),
                Text('${entries.length} fonts'),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      entry.family,
                      style: TextStyle(fontFamily: entry.family),
                    ),
                    subtitle: Text(
                      entry.path == null
                          ? entry.source
                          : '${entry.source} · ${entry.path}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.of(context).pop(entry),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Future<void> _addFolder() async {
    setState(() => _addingFolder = true);
    try {
      final folder = await FilePicker.getDirectoryPath(
        dialogTitle: 'Choose font folder',
      );
      if (folder == null) return;
      await widget.catalog.addFolder(folder);
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _addingFolder = false);
    }
  }
}
