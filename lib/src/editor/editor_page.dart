import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../export/html_exporter.dart';
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

class _EditorPageState extends State<EditorPage> with WindowListener {
  final EditorController _controller = EditorController();
  final ProjectStorage _storage = const ProjectStorage();
  final HtmlExporter _exporter = const HtmlExporter();
  final CanvasViewportController _viewportController = CanvasViewportController();
  final FocusNode _shortcuts = FocusNode(debugLabel: 'web-ui-canvas-shortcuts');

  String? _projectPath;
  late String _cleanFingerprint;
  bool _previewMode = false;
  bool _busy = false;
  bool _handlingWindowClose = false;
  int _rightTab = 0;

  bool get _isDirty => _controller.projectFingerprint != _cleanFingerprint;

  @override
  void initState() {
    super.initState();
    _cleanFingerprint = _controller.projectFingerprint;
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _controller.dispose();
    _viewportController.dispose();
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
                          viewportController: _viewportController,
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
                    break;
                  case 'tablet':
                    _controller.setPageSize(900, page.height);
                    break;
                  case 'mobile':
                    _controller.setPageSize(390, page.height);
                    break;
                  case 'custom':
                    unawaited(_editCanvasSize());
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'desktop', child: Text('Desktop · 1440')),
                PopupMenuItem(value: 'tablet', child: Text('Tablet · 900')),
                PopupMenuItem(value: 'mobile', child: Text('Mobile · 390')),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'custom',
                  child: Text('Custom size…'),
                ),
              ],
              child: Chip(
                label: Text(
                  '${page.width.toStringAsFixed(0)} × ${page.height.toStringAsFixed(0)}',
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: _viewportController,
              builder: (context, _) {
                final percent = (_viewportController.zoom * 100).round();
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Zoom out',
                      onPressed: () => _viewportController.zoomBy(-.10),
                      icon: const Icon(Icons.remove, size: 18),
                    ),
                    TextButton(
                      onPressed: _viewportController.reset,
                      child: Text('$percent%'),
                    ),
                    IconButton(
                      tooltip: 'Zoom in',
                      onPressed: () => _viewportController.zoomBy(.10),
                      icon: const Icon(Icons.add, size: 18),
                    ),
                  ],
                );
              },
            ),
            const Spacer(),
            Text(
              _isDirty
                  ? '${_projectLabel()} *'
                  : _projectLabel(),
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

  Future<void> _editCanvasSize() async {
    final page = _controller.activePage;
    final widthController =
        TextEditingController(text: page.width.toStringAsFixed(0));
    final heightController =
        TextEditingController(text: page.height.toStringAsFixed(0));

    final result = await showDialog<Size>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Canvas size'),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 130,
              child: TextField(
                controller: widthController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Width'),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 130,
              child: TextField(
                controller: heightController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Height'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final width =
                  double.tryParse(widthController.text.replaceAll(',', '.'));
              final height =
                  double.tryParse(heightController.text.replaceAll(',', '.'));
              if (width == null || height == null) return;
              Navigator.of(dialogContext).pop(Size(width, height));
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    widthController.dispose();
    heightController.dispose();

    if (result != null) {
      _controller.setPageSize(result.width, result.height);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    final primary = keyboard.isControlPressed || keyboard.isMetaPressed;
    final shift = keyboard.isShiftPressed;
    final editingText =
        FocusManager.instance.primaryFocus?.context?.widget is EditableText;

    if (editingText &&
        (event.logicalKey == LogicalKeyboardKey.delete ||
            event.logicalKey == LogicalKeyboardKey.backspace ||
            event.logicalKey == LogicalKeyboardKey.arrowLeft ||
            event.logicalKey == LogicalKeyboardKey.arrowRight ||
            event.logicalKey == LogicalKeyboardKey.arrowUp ||
            event.logicalKey == LogicalKeyboardKey.arrowDown ||
            (primary &&
                (event.logicalKey == LogicalKeyboardKey.keyZ ||
                    event.logicalKey == LogicalKeyboardKey.keyY ||
                    event.logicalKey == LogicalKeyboardKey.keyD ||
                    event.logicalKey == LogicalKeyboardKey.keyC ||
                    event.logicalKey == LogicalKeyboardKey.keyV ||
                    event.logicalKey == LogicalKeyboardKey.keyA)))) {
      return KeyEventResult.ignored;
    }

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
    if (primary && event.logicalKey == LogicalKeyboardKey.keyC) {
      _controller.copySelected();
      return KeyEventResult.handled;
    }
    if (primary && event.logicalKey == LogicalKeyboardKey.keyV) {
      _controller.pasteCopied();
      return KeyEventResult.handled;
    }
    if (primary && event.logicalKey == LogicalKeyboardKey.keyA) {
      _controller.selectAll();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape && !editingText) {
      _controller.clearSelection();
      return KeyEventResult.handled;
    }
    final nudge = shift ? 10.0 : 1.0;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _controller.nudgeSelection(-nudge, 0);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _controller.nudgeSelection(nudge, 0);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _controller.nudgeSelection(0, -nudge);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _controller.nudgeSelection(0, nudge);
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
    if (!await _resolveUnsavedChanges()) return;
    if (!mounted) return;

    setState(() => _busy = true);
    try {
      final loaded = await _storage.openProject();
      if (loaded == null) return;
      _controller.replaceProject(loaded.$1);
      if (!mounted) return;
      setState(() {
        _projectPath = loaded.$2;
        _cleanFingerprint = _controller.projectFingerprint;
      });
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    await _saveInternal();
  }

  Future<bool> _saveInternal() async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      final path = await _storage.saveProject(
        _controller.project,
        existingPath: _projectPath,
      );
      if (path == null) return false;
      if (!mounted) return false;
      setState(() {
        _projectPath = path;
        _cleanFingerprint = _controller.projectFingerprint;
      });
      return true;
    } catch (error) {
      _showError(error);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _projectLabel() => _projectPath == null
      ? _controller.project.name
      : _projectPath!.split(RegExp(r'[\\/]')).last;

  Future<bool> _resolveUnsavedChanges() async {
    if (!_isDirty) return true;

    final action = await showDialog<_UnsavedAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text(
          'The project has changes that have not been saved yet.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_UnsavedAction.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_UnsavedAction.discard),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_UnsavedAction.save),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    switch (action) {
      case _UnsavedAction.save:
        return _saveInternal();
      case _UnsavedAction.discard:
        return true;
      case _UnsavedAction.cancel:
      case null:
        return false;
    }
  }

  @override
  void onWindowClose() {
    unawaited(_handleWindowClose());
  }

  Future<void> _handleWindowClose() async {
    if (_handlingWindowClose) return;
    _handlingWindowClose = true;
    try {
      if (await _resolveUnsavedChanges()) {
        await windowManager.destroy();
      }
    } finally {
      _handlingWindowClose = false;
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


enum _UnsavedAction {
  save,
  discard,
  cancel,
}
