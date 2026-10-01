import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../export/html_exporter.dart';
import '../model/web_element.dart';
import '../model/web_project.dart';
import '../services/project_storage.dart';
import 'editor_controller.dart';
import 'widgets/canvas_view.dart';
import 'widgets/component_library.dart';
import 'widgets/inspector_panel.dart';
import 'widgets/layers_panel.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final EditorController _controller = EditorController();
  final ProjectStorage _storage = const ProjectStorage();
  final HtmlExporter _exporter = const HtmlExporter();
  final FocusNode _shortcuts = FocusNode(debugLabel: 'web-ui-canvas-shortcuts');

  String? _projectPath;
  bool _previewMode = false;
  bool _busy = false;
  int _rightTab = 0;

  @override
  void dispose() {
    _controller.dispose();
    _shortcuts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Focus(
          focusNode: _shortcuts,
          autofocus: true,
          onKeyEvent: _onKey,
          child: Scaffold(
            body: Column(
              children: [
                _topBar(context),
                const Divider(height: 1),
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 230,
                        child: ComponentLibrary(
                          onAdd: (type) {
                            _controller.addElement(type);
                            _shortcuts.requestFocus();
                          },
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: CanvasView(
                          controller: _controller,
                          previewMode: _previewMode,
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      SizedBox(
                        width: 310,
                        child: Column(
                          children: [
                            SegmentedButton<int>(
                              segments: const [
                                ButtonSegment(
                                  value: 0,
                                  label: Text('Properties'),
                                  icon: Icon(Icons.tune, size: 17),
                                ),
                                ButtonSegment(
                                  value: 1,
                                  label: Text('Layers'),
                                  icon: Icon(Icons.layers_outlined, size: 17),
                                ),
                              ],
                              selected: {_rightTab},
                              onSelectionChanged: (selection) {
                                setState(() => _rightTab = selection.first);
                              },
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: _rightTab == 0
                                  ? InspectorPanel(controller: _controller)
                                  : LayersPanel(controller: _controller),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _topBar(BuildContext context) {
    final page = _controller.activePage;
    return SizedBox(
      height: 58,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            const Text(
              'Web UI Canvas',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 14),
            IconButton(
              tooltip: 'Open',
              onPressed: _busy ? null : _open,
              icon: const Icon(Icons.folder_open),
            ),
            IconButton(
              tooltip: 'Save',
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.save_outlined),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Undo',
              onPressed: _controller.canUndo ? _controller.undo : null,
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: 'Redo',
              onPressed: _controller.canRedo ? _controller.redo : null,
              icon: const Icon(Icons.redo),
            ),
            const VerticalDivider(indent: 10, endIndent: 10),
            FilterChip(
              label: const Text('Grid'),
              selected: _controller.gridEnabled,
              onSelected: (value) {
                setState(() => _controller.gridEnabled = value);
              },
            ),
            const SizedBox(width: 6),
            FilterChip(
              label: const Text('Snap'),
              selected: _controller.snapEnabled,
              onSelected: (value) {
                setState(() => _controller.snapEnabled = value);
              },
            ),
            const SizedBox(width: 10),
            PopupMenuButton<String>(
              tooltip: 'Canvas size',
              onSelected: (value) {
                switch (value) {
                  case 'desktop':
                    _controller.setPageSize(1440, page.height);
                  case 'tablet':
                    _controller.setPageSize(768, page.height);
                  case 'mobile':
                    _controller.setPageSize(390, page.height);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'desktop', child: Text('Desktop · 1440')),
                PopupMenuItem(value: 'tablet', child: Text('Tablet · 768')),
                PopupMenuItem(value: 'mobile', child: Text('Mobile · 390')),
              ],
              child: Chip(
                label: Text(
                  '${page.width.toStringAsFixed(0)} × ${page.height.toStringAsFixed(0)}',
                ),
              ),
            ),
            const Spacer(),
            Text(
              _projectPath == null
                  ? _controller.project.name
                  : _projectPath!.split(RegExp(r'[\\/]')).last,
            ),
            const SizedBox(width: 14),
            FilterChip(
              label: const Text('Preview'),
              avatar: const Icon(Icons.play_arrow, size: 18),
              selected: _previewMode,
              onSelected: (value) => setState(() => _previewMode = value),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _busy ? null : _export,
              icon: const Icon(Icons.output),
              label: const Text('Export HTML/CSS'),
            ),
          ],
        ),
      ),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    final primary = keyboard.isControlPressed || keyboard.isMetaPressed;

    if (primary && event.logicalKey == LogicalKeyboardKey.keyS) {
      unawaited(_save());
      return KeyEventResult.handled;
    }
    if (primary && event.logicalKey == LogicalKeyboardKey.keyO) {
      unawaited(_open());
      return KeyEventResult.handled;
    }
    if (primary && event.logicalKey == LogicalKeyboardKey.keyZ) {
      if (keyboard.isShiftPressed) {
        _controller.redo();
      } else {
        _controller.undo();
      }
      return KeyEventResult.handled;
    }
    if (primary && event.logicalKey == LogicalKeyboardKey.keyY) {
      _controller.redo();
      return KeyEventResult.handled;
    }
    if (primary && event.logicalKey == LogicalKeyboardKey.keyD) {
      _controller.duplicateSelected();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      _controller.removeSelected();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final loaded = await _storage.openProject();
      if (loaded == null) return;
      _controller.replaceProject(loaded.$1);
      setState(() => _projectPath = loaded.$2);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final path = await _storage.saveProject(
        _controller.project,
        existingPath: _projectPath,
      );
      if (path != null && mounted) setState(() => _projectPath = path);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await _exporter.export(_controller.project);
      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported to ${result.directory.path}')),
        );
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString())),
    );
  }
}
