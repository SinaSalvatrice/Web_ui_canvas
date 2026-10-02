import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../model/asset_library.dart';
import '../../services/font_catalog.dart';
import '../editor_controller.dart';

class AssetLibraryPanel extends StatefulWidget {
  const AssetLibraryPanel({
    required this.controller,
    super.key,
  });

  final EditorController controller;

  @override
  State<AssetLibraryPanel> createState() => _AssetLibraryPanelState();
}

class _AssetLibraryPanelState extends State<AssetLibraryPanel> {
  AssetCategory? _filter;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final project = widget.controller.project;
    final query = _query.trim().toLowerCase();
    final items = project.assetLibrary.where((item) {
      if (_filter != null && item.category != _filter) return false;
      if (query.isEmpty) return true;
      return ('${item.label} ${item.path} ${item.category.label}')
          .toLowerCase()
          .contains(query);
    }).toList()
      ..sort((a, b) {
        final category = a.category.index.compareTo(b.category.index);
        return category != 0
            ? category
            : a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });

    return Column(
      children: [
        SwitchListTile(
          dense: true,
          title: const Text('Asset library'),
          subtitle: const Text('Disable without removing stored assets'),
          value: project.assetLibraryEnabled,
          onChanged: widget.controller.setAssetLibraryEnabled,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: TextField(
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search),
              hintText: 'Search assets',
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            scrollDirection: Axis.horizontal,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _filter == null,
                onSelected: (_) => setState(() => _filter = null),
              ),
              const SizedBox(width: 6),
              for (final category in AssetCategory.values) ...[
                ChoiceChip(
                  label: Text(category.label),
                  selected: _filter == category,
                  onSelected: (_) => setState(() => _filter = category),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _addAssets,
                  icon: const Icon(Icons.library_add_outlined),
                  label: const Text('Add assets'),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No assets yet. Add icons, frames, textures, fonts, objects or masks.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _AssetTile(
                      item: item,
                      libraryEnabled: project.assetLibraryEnabled,
                      onToggle: (enabled) => widget.controller
                          .updateLibraryAsset(item.copyWith(enabled: enabled)),
                      onUse: () async {
                        if (item.category == AssetCategory.fonts) {
                          await FontCatalog.instance.ensureLoaded(
                            family: item.label,
                            path: item.path,
                          );
                        }
                        widget.controller.applyLibraryAsset(item);
                      },
                      onRemove: () =>
                          widget.controller.removeLibraryAsset(item.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _addAssets() async {
    final category = await showDialog<AssetCategory>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Asset category'),
        children: [
          for (final value in AssetCategory.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(value),
              child: ListTile(
                dense: true,
                leading: Icon(_categoryIcon(value)),
                title: Text(value.label),
              ),
            ),
        ],
      ),
    );
    if (category == null || !mounted) return;

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: category == AssetCategory.fonts
          ? const ['ttf', 'otf']
          : const ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'svg'],
      dialogTitle: 'Add ${category.label.toLowerCase()}',
    );
    if (result.isEmpty) return;

    for (final file in result) {
      final path = file.path;
      if (path == null || !File(path).existsSync()) continue;
      final normalized = p.normalize(path);
      final id = 'asset_${category.name}_${normalized.hashCode.abs()}';
      widget.controller.addLibraryAsset(
        AssetLibraryItem(
          id: id,
          label: p.basenameWithoutExtension(path),
          category: category,
          path: path,
        ),
      );
    }
  }

  IconData _categoryIcon(AssetCategory category) => switch (category) {
        AssetCategory.icons => Icons.auto_awesome_mosaic_outlined,
        AssetCategory.frames => Icons.crop_free,
        AssetCategory.textures => Icons.texture,
        AssetCategory.fonts => Icons.font_download_outlined,
        AssetCategory.objects => Icons.category_outlined,
        AssetCategory.masks => Icons.layers_outlined,
      };
}

class _AssetTile extends StatelessWidget {
  const _AssetTile({
    required this.item,
    required this.libraryEnabled,
    required this.onToggle,
    required this.onUse,
    required this.onRemove,
  });

  final AssetLibraryItem item;
  final bool libraryEnabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback onUse;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      enabled: libraryEnabled,
      leading: Switch(
        value: item.enabled,
        onChanged: libraryEnabled ? onToggle : null,
      ),
      title: Text(
        item.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        item.category.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Wrap(
        spacing: 2,
        children: [
          IconButton(
            tooltip: 'Use on selected element',
            onPressed: libraryEnabled && item.enabled ? onUse : null,
            icon: const Icon(Icons.add_circle_outline, size: 19),
          ),
          IconButton(
            tooltip: 'Remove from library',
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline, size: 19),
          ),
        ],
      ),
    );
  }
}
