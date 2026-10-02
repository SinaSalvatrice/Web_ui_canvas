import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../model/web_element.dart';
import '../editor_controller.dart';

class CanvasViewportController extends ChangeNotifier {
  CanvasViewportController() {
    transformation.addListener(_notifyTransformChanged);
  }

  final TransformationController transformation = TransformationController();

  double get zoom => transformation.value.entry(0, 0).abs();

  void zoomBy(double delta, {Offset? focalPoint}) {
    setZoom(zoom + delta, focalPoint: focalPoint);
  }

  void setZoom(double value, {Offset? focalPoint}) {
    final nextZoom = value.clamp(.20, 4.0).toDouble();
    final current = transformation.value;
    final translation = current.getTranslation();

    var tx = translation.x;
    var ty = translation.y;
    if (focalPoint != null) {
      final scene = transformation.toScene(focalPoint);
      tx = focalPoint.dx - scene.dx * nextZoom;
      ty = focalPoint.dy - scene.dy * nextZoom;
    }

    final next = Matrix4.diagonal3Values(nextZoom, nextZoom, 1)
      ..setTranslationRaw(tx, ty, 0);
    transformation.value = next;
  }

  void scrollBy(Offset scrollDelta) {
    final current = Matrix4.copy(transformation.value);
    final translation = current.getTranslation();
    current.setTranslationRaw(
      translation.x - scrollDelta.dx,
      translation.y - scrollDelta.dy,
      translation.z,
    );
    transformation.value = current;
  }

  void reset() {
    transformation.value = Matrix4.identity();
  }

  void _notifyTransformChanged() => notifyListeners();

  @override
  void dispose() {
    transformation.removeListener(_notifyTransformChanged);
    transformation.dispose();
    super.dispose();
  }
}

class CanvasView extends StatefulWidget {
  const CanvasView({
    required this.controller,
    required this.viewportController,
    required this.previewMode,
    this.exportKey,
    super.key,
  });

  final EditorController controller;
  final CanvasViewportController viewportController;
  final bool previewMode;
  final GlobalKey? exportKey;

  @override
  State<CanvasView> createState() => _CanvasViewState();
}

class _CanvasViewState extends State<CanvasView> {
  static const _margin = 420.0;

  final GlobalKey _viewportKey = GlobalKey();

  TransformationController get _transform =>
      widget.viewportController.transformation;

  double? _rotationPointerStart;
  double _rotationValueStart = 0;
  bool _didInitialFit = false;
  bool _touchElementInteraction = false;
  Offset? _touchInteractionPoint;
  Offset? _objectDragPointerStart;
  Offset? _objectDragElementStart;
  Offset? _cropDragPoint;

  double get _scale => widget.viewportController.zoom;

  WebElement? _resolvedElementById(String id) {
    for (final candidate in widget.controller.resolvedPageElements) {
      if (candidate.id == id) return candidate;
    }
    return null;
  }

  void _beginObjectDrag(WebElement element, Offset globalPosition) {
    final point = _pagePointFromGlobal(globalPosition);
    if (point == null) return;
    if (widget.controller.isCropping(element.id)) {
      _cropDragPoint = point;
      _objectDragPointerStart = null;
      _objectDragElementStart = null;
      return;
    }
    final current = _resolvedElementById(element.id) ?? element;
    _objectDragPointerStart = point;
    _objectDragElementStart = Offset(current.x, current.y);
    _cropDragPoint = null;
  }

  void _updateObjectDrag(WebElement element, Offset globalPosition) {
    final point = _pagePointFromGlobal(globalPosition);
    if (point == null) return;

    if (widget.controller.isCropping(element.id)) {
      final previous = _cropDragPoint;
      _cropDragPoint = point;
      if (previous == null) return;
      final delta = point - previous;
      widget.controller.panImage(element.id, delta.dx, delta.dy);
      return;
    }

    final pointerStart = _objectDragPointerStart;
    final elementStart = _objectDragElementStart;
    final current = _resolvedElementById(element.id);
    if (pointerStart == null || elementStart == null || current == null) return;

    final pointerDelta = point - pointerStart;
    final target = elementStart + pointerDelta;
    widget.controller.moveBy(
      element.id,
      target.dx - current.x,
      target.dy - current.y,
    );
  }

  void _endObjectDrag() {
    _objectDragPointerStart = null;
    _objectDragElementStart = null;
    _cropDragPoint = null;
  }

  void _beginTouchElementInteraction(Offset globalPosition) {
    _touchInteractionPoint = _pagePointFromGlobal(globalPosition);
    if (_touchElementInteraction || !mounted) return;
    setState(() => _touchElementInteraction = true);
  }

  Offset? _touchCanvasDelta(Offset globalPosition) {
    final current = _pagePointFromGlobal(globalPosition);
    final previous = _touchInteractionPoint;
    _touchInteractionPoint = current;
    if (current == null || previous == null) return null;
    return current - previous;
  }

  void _endTouchElementInteraction() {
    _touchInteractionPoint = null;
    if (!_touchElementInteraction || !mounted) return;
    setState(() => _touchElementInteraction = false);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final page = controller.activePage;
    final pageWidth = controller.viewportWidth;
    final pageHeight = controller.viewportHeight;
    final resolvedElements = controller.resolvedPageElements
        .where((element) => element.visible)
        .toList(growable: false);
    final touchMode = MediaQuery.sizeOf(context).shortestSide < 700;

    if (touchMode && !_didInitialFit) {
      _didInitialFit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitCanvasToViewport());
    }

    return DragTarget<WebElementType>(
      onAcceptWithDetails: (details) {
        final point = _sceneFromGlobal(details.offset);
        if (point == null) {
          controller.addElement(details.data);
          return;
        }
        controller.addElement(
          details.data,
          x: point.dx - _margin,
          y: point.dy - _margin,
        );
      },
      builder: (context, candidateData, rejectedData) {
        return Listener(
          key: _viewportKey,
          onPointerSignal: (signal) {
            if (signal is! PointerScrollEvent) return;
            GestureBinding.instance.pointerSignalResolver.register(
              signal,
              (resolved) {
                if (resolved is PointerScrollEvent) {
                  _handlePointerScroll(resolved);
                }
              },
            );
          },
          child: AnimatedBuilder(
            animation: _transform,
            builder: (context, _) {
              return InteractiveViewer(
                transformationController: _transform,
                constrained: false,
                panEnabled: touchMode && !_touchElementInteraction,
                scaleEnabled: touchMode && !_touchElementInteraction,
                minScale: .20,
                maxScale: 4,
                boundaryMargin: const EdgeInsets.all(1000),
                child: SizedBox(
                  width: pageWidth + _margin * 2,
                  height: pageHeight + _margin * 2,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: _margin,
                        top: _margin,
                        width: pageWidth,
                        height: pageHeight,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: widget.previewMode
                              ? null
                              : () => controller.select(null),
                          child: RepaintBoundary(
                            key: widget.exportKey,
                            child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(page.backgroundColor),
                              border: Border.all(color: Colors.black26),
                              boxShadow: const [
                                BoxShadow(
                                  blurRadius: 24,
                                  color: Color(0x22000000),
                                ),
                              ],
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                if (controller.gridEnabled && !widget.previewMode)
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _GridPainter(
                                        step: controller.gridStep,
                                      ),
                                    ),
                                  ),
                                for (final element in resolvedElements)
                                  _buildElement(element),
                                if (!widget.previewMode)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    height: 22,
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.resizeUpDown,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onVerticalDragUpdate: (details) =>
                                            controller.extendPage(
                                          details.delta.dy / _scale,
                                        ),
                                        child: const Center(
                                          child: SizedBox(
                                            width: 72,
                                            height: 4,
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: Colors.black26,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _handlePointerScroll(PointerScrollEvent event) {
    final keyboard = HardwareKeyboard.instance;
    final primary = keyboard.isControlPressed || keyboard.isMetaPressed;

    if (primary) {
      final amount =
          event.scrollDelta.dy != 0 ? event.scrollDelta.dy : event.scrollDelta.dx;
      if (amount == 0) return;
      widget.viewportController.zoomBy(
        amount < 0 ? .10 : -.10,
        focalPoint: event.localPosition,
      );
      return;
    }

    if (keyboard.isShiftPressed) {
      final amount =
          event.scrollDelta.dy != 0 ? event.scrollDelta.dy : event.scrollDelta.dx;
      widget.viewportController.scrollBy(Offset(amount, 0));
      return;
    }

    widget.viewportController.scrollBy(event.scrollDelta);
  }

  Widget _buildElement(WebElement element) {
    final controller = widget.controller;
    final selected =
        !widget.previewMode && controller.selectedIds.contains(element.id);
    final primary =
        selected && controller.selectedId == element.id;
    final cropping =
        primary && controller.isCropping(element.id);
    final touch = MediaQuery.sizeOf(context).shortestSide < 700;

    return Positioned(
      left: element.x,
      top: element.y,
      width: element.width,
      height: element.height,
      child: Transform.rotate(
        angle: element.rotation,
        child: MouseRegion(
          cursor: cropping
              ? SystemMouseCursors.move
              : SystemMouseCursors.basic,
          child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: widget.previewMode ||
                  element.type != WebElementType.image
              ? null
              : () => _replaceImage(element),
          onTap: widget.previewMode
              ? null
              : () {
                  final keyboard = HardwareKeyboard.instance;
                  final additive =
                      keyboard.isControlPressed || keyboard.isMetaPressed;
                  if (additive) {
                    controller.toggleSelection(element.id);
                  } else {
                    controller.selectOnly(element.id);
                  }
                },
          onSecondaryTapDown: widget.previewMode
              ? null
              : (details) => _showElementContextMenu(
                    element,
                    details.globalPosition,
                  ),
          onPanStart: widget.previewMode || element.locked
              ? null
              : (details) {
                  if (touch) {
                    _beginTouchElementInteraction(details.globalPosition);
                  }
                  if (!controller.selectedIds.contains(element.id)) {
                    final keyboard = HardwareKeyboard.instance;
                    final additive =
                        keyboard.isControlPressed || keyboard.isMetaPressed;
                    if (additive) {
                      controller.toggleSelection(element.id);
                    } else {
                      controller.selectOnly(element.id);
                    }
                  }
                  _beginObjectDrag(element, details.globalPosition);
                },
          onPanUpdate: widget.previewMode || element.locked
              ? null
              : (details) =>
                  _updateObjectDrag(element, details.globalPosition),
          onPanEnd: widget.previewMode || element.locked
              ? null
              : (_) {
                  _endObjectDrag();
                  if (touch) _endTouchElementInteraction();
                  controller.commitLiveEdit();
                },
          onPanCancel: widget.previewMode || element.locked
              ? null
              : () {
                  _endObjectDrag();
                  if (touch) _endTouchElementInteraction();
                  controller.commitLiveEdit();
                },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    border: selected
                        ? Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2 / _scale,
                          )
                        : null,
                  ),
                  child: _render(element),
                ),
              ),
              if (cropping)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.tertiary,
                          width: 3 / _scale,
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          margin: EdgeInsets.all(6 / _scale),
                          padding: EdgeInsets.symmetric(
                            horizontal: 8 / _scale,
                            vertical: 4 / _scale,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .tertiaryContainer
                                .withValues(alpha: .92),
                            borderRadius:
                                BorderRadius.circular(5 / _scale),
                          ),
                          child: Text(
                            'CROP · drag image',
                            style: TextStyle(
                              fontSize: 11 / _scale,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (primary && !element.locked && !cropping) ...[
                for (final handle in _ResizeHandle.values)
                  _resizeHandle(element, handle),
                _rotationHandle(element),
              ],
            ],
          ),
        ),
        ),
      ),
    );
  }

  Future<void> _showElementContextMenu(
    WebElement element,
    Offset globalPosition,
  ) async {
    final controller = widget.controller;
    if (!controller.selectedIds.contains(element.id)) {
      controller.selectOnly(element.id);
    }

    final overlay = Overlay.of(context).context.findRenderObject();
    if (overlay is! RenderBox) return;
    final action = await showMenu<_CanvasContextAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        if (element.type == WebElementType.image) ...[
          PopupMenuItem(
            value: _CanvasContextAction.crop,
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.crop_outlined),
              title: Text(
                controller.isCropping(element.id)
                    ? 'Finish crop'
                    : 'Crop image',
              ),
            ),
          ),
          const PopupMenuItem(
            value: _CanvasContextAction.replaceImage,
            child: ListTile(
              dense: true,
              leading: Icon(Icons.image_outlined),
              title: Text('Replace image'),
            ),
          ),
          const PopupMenuDivider(),
        ],
        const PopupMenuItem(
          value: _CanvasContextAction.copy,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.copy_outlined),
            title: Text('Copy'),
          ),
        ),
        PopupMenuItem(
          value: _CanvasContextAction.paste,
          enabled: controller.canPaste,
          child: const ListTile(
            dense: true,
            leading: Icon(Icons.content_paste_outlined),
            title: Text('Paste'),
          ),
        ),
        const PopupMenuItem(
          value: _CanvasContextAction.duplicate,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.control_point_duplicate_outlined),
            title: Text('Duplicate'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _CanvasContextAction.forward,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.flip_to_front_outlined),
            title: Text('Bring forward'),
          ),
        ),
        const PopupMenuItem(
          value: _CanvasContextAction.backward,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.flip_to_back_outlined),
            title: Text('Send backward'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _CanvasContextAction.delete,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.delete_outline),
            title: Text('Delete'),
          ),
        ),
      ],
    );

    switch (action) {
      case _CanvasContextAction.crop:
        if (controller.isCropping(element.id)) {
          controller.exitCropMode();
        } else {
          controller.enterCropMode(element.id);
        }
        break;
      case _CanvasContextAction.replaceImage:
        await _replaceImage(element);
        break;
      case _CanvasContextAction.copy:
        controller.copySelected();
        break;
      case _CanvasContextAction.paste:
        controller.pasteCopied();
        break;
      case _CanvasContextAction.duplicate:
        controller.duplicateSelected();
        break;
      case _CanvasContextAction.forward:
        controller.moveLayer(1);
        break;
      case _CanvasContextAction.backward:
        controller.moveLayer(-1);
        break;
      case _CanvasContextAction.delete:
        controller.removeSelected();
        break;
      case null:
        break;
    }
  }

  Future<void> _replaceImage(WebElement element) async {
    final file = await FilePicker.pickFile(
      type: FileType.image,
      dialogTitle: 'Choose image',
    );
    final path = file?.path;
    if (path == null) return;

    WebElement? current;
    for (final candidate in widget.controller.activePage.elements) {
      if (candidate.id == element.id) {
        current = candidate;
        break;
      }
    }
    if (current == null) return;

    widget.controller.updateElement(
      current.copyWith(
        imagePath: path,
        imagePositionX: 0,
        imagePositionY: 0,
        imageScale: 1,
      ),
    );
  }

  Widget _resizeHandle(WebElement element, _ResizeHandle handle) {
    final touch = MediaQuery.sizeOf(context).shortestSide < 700;
    final hit = (touch ? 48.0 : 30.0) / _scale;
    final visual = (touch ? 16.0 : 12.0) / _scale;
    final left = switch (handle.h) {
      -1 => -hit / 2,
      0 => element.width / 2 - hit / 2,
      _ => null,
    };
    final right = handle.h == 1 ? -hit / 2 : null;
    final top = switch (handle.v) {
      -1 => -hit / 2,
      0 => element.height / 2 - hit / 2,
      _ => null,
    };
    final bottom = handle.v == 1 ? -hit / 2 : null;

    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      width: hit,
      height: hit,
      child: MouseRegion(
        cursor: handle.cursor,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            if (touch) {
              _beginTouchElementInteraction(details.globalPosition);
            }
          },
          onPanUpdate: (details) {
            final delta = touch
                ? _touchCanvasDelta(details.globalPosition)
                : Offset(
                    details.delta.dx / _scale,
                    details.delta.dy / _scale,
                  );
            if (delta == null) return;
            widget.controller.resizeBy(
              element.id,
              dx: delta.dx,
              dy: delta.dy,
              left: handle.h == -1,
              right: handle.h == 1,
              top: handle.v == -1,
              bottom: handle.v == 1,
            );
          },
          onPanEnd: (_) {
            if (touch) _endTouchElementInteraction();
            widget.controller.commitLiveEdit();
          },
          onPanCancel: () {
            if (touch) _endTouchElementInteraction();
            widget.controller.commitLiveEdit();
          },
          child: Center(
            child: Container(
              width: visual,
              height: visual,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2 / _scale,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rotationHandle(WebElement element) {
    final touch = MediaQuery.sizeOf(context).shortestSide < 700;
    final hit = (touch ? 50.0 : 34.0) / _scale;
    final visual = (touch ? 18.0 : 14.0) / _scale;
    final offset = (touch ? 66.0 : 54.0) / _scale;
    return Positioned(
      left: element.width / 2 - hit / 2,
      top: -offset,
      width: hit,
      height: hit,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            if (touch) {
              _beginTouchElementInteraction(details.globalPosition);
            }
            final point = _pagePointFromGlobal(details.globalPosition);
            if (point == null) return;
            final center = Offset(
              element.x + element.width / 2,
              element.y + element.height / 2,
            );
            _rotationPointerStart =
                math.atan2(point.dy - center.dy, point.dx - center.dx);
            _rotationValueStart = element.rotation;
          },
          onPanUpdate: (details) {
            final start = _rotationPointerStart;
            final current = widget.controller.selectedElement;
            final point = _pagePointFromGlobal(details.globalPosition);
            if (start == null || current == null || point == null) return;
            final center = Offset(
              current.x + current.width / 2,
              current.y + current.height / 2,
            );
            final angle = math.atan2(
              point.dy - center.dy,
              point.dx - center.dx,
            );
            widget.controller.updateElement(
              current.copyWith(
                rotation: _rotationValueStart + angle - start,
              ),
              commit: false,
            );
          },
          onPanEnd: (_) {
            _rotationPointerStart = null;
            if (touch) _endTouchElementInteraction();
            widget.controller.commitLiveEdit();
          },
          onPanCancel: () {
            _rotationPointerStart = null;
            if (touch) _endTouchElementInteraction();
            widget.controller.commitLiveEdit();
          },
          child: Center(
            child: Container(
              width: visual,
              height: visual,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2 / _scale,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _render(WebElement element) {
    final background = element.backgroundColor == null
        ? Colors.transparent
        : Color(element.backgroundColor!);
    final foreground = Color(element.foregroundColor);
    final border = element.borderColor == null
        ? Colors.transparent
        : Color(element.borderColor!);

    Widget content;
    if (element.type == WebElementType.image) {
      final path = element.imagePath;
      final file = path == null ? null : File(path);
      content = file != null && file.existsSync()
          ? ClipRect(
              child: Transform.scale(
                scale: element.imageScale.clamp(.25, 5.0).toDouble(),
                alignment: Alignment.center,
                child: Image.file(
                  file,
                  width: double.infinity,
                  height: double.infinity,
                  fit: _boxFit(element.imageFit),
                  alignment: Alignment(
                    element.imagePositionX.clamp(-1.0, 1.0).toDouble(),
                    element.imagePositionY.clamp(-1.0, 1.0).toDouble(),
                  ),
                  filterQuality: FilterQuality.high,
                  isAntiAlias: true,
                  errorBuilder: (_, __, ___) => _imagePlaceholder(),
                ),
              ),
            )
          : _imagePlaceholder();
    } else if (element.type == WebElementType.divider) {
      content = Center(
        child: Container(height: 1, color: foreground.withValues(alpha: .5)),
      );
    } else if (element.type == WebElementType.toggle) {
      content = Padding(
        padding: const EdgeInsets.all(3),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: .44,
            heightFactor: .82,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
    } else if (element.type == WebElementType.input) {
      content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: _styledText(
            element,
            foreground.withValues(alpha: .55),
          ),
        ),
      );
    } else {
      content = Padding(
        padding: const EdgeInsets.all(10),
        child: Align(
          alignment: _alignment(element.textAlign),
          child: _styledText(element, foreground),
        ),
      );
    }

    final backplatePath = element.backplateEnabled ? element.backplatePath : null;
    final backplate = backplatePath == null
        ? null
        : _assetVisual(backplatePath, element.backplateFit);

    return Opacity(
      opacity: element.opacity.clamp(0.0, 1.0).toDouble(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(element.borderRadius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            border: element.borderWidth > 0
                ? Border.all(
                    color: border,
                    width: element.borderWidth,
                  )
                : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (backplate != null)
                IgnorePointer(child: backplate),
              content,
              if (element.maskEnabled && element.maskPath != null)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .54),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        child: Text(
                          'MASK',
                          style: TextStyle(color: Colors.white, fontSize: 9),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _styledText(WebElement element, Color foreground) {
    final baseStyle = TextStyle(
      color: foreground,
      fontSize: element.fontSize,
      fontWeight: _fontWeight(element.fontWeight),
      fontFamily: element.fontFamily,
      letterSpacing: element.letterSpacing,
      height: element.lineHeight,
      backgroundColor: element.textHighlightColor == null
          ? null
          : Color(element.textHighlightColor!),
    );
    final softWrap = element.textMode != 'fixedSize';
    final overflow = element.textMode == 'fixedWidth'
        ? TextOverflow.visible
        : TextOverflow.clip;

    final fill = Text(
      element.text,
      textAlign: _textAlign(element.textAlign),
      softWrap: softWrap,
      overflow: overflow,
      style: baseStyle,
    );

    if (element.textStrokeColor == null || element.textStrokeWidth <= 0) {
      return fill;
    }

    final stroke = Text(
      element.text,
      textAlign: _textAlign(element.textAlign),
      softWrap: softWrap,
      overflow: overflow,
      style: baseStyle.copyWith(
        color: null,
        backgroundColor: null,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = element.textStrokeWidth
          ..color = Color(element.textStrokeColor!),
      ),
    );

    return Stack(
      fit: StackFit.passthrough,
      children: [stroke, fill],
    );
  }

  Widget? _assetVisual(String path, String fit) {
    final file = File(path);
    if (!file.existsSync()) return null;
    if (path.toLowerCase().endsWith('.svg')) {
      return SvgPicture.file(
        file,
        fit: _boxFit(fit),
      );
    }
    return Image.file(
      file,
      fit: _boxFit(fit),
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
      errorBuilder: (_, __, ___) => _imagePlaceholder(),
    );
  }

  Widget _imagePlaceholder() => const ColoredBox(
        color: Color(0xffeeeeee),
        child: Center(
          child: Icon(Icons.image_outlined, size: 42, color: Colors.black38),
        ),
      );

  void _fitCanvasToViewport() {
    if (!mounted) return;
    final render = _viewportKey.currentContext?.findRenderObject();
    if (render is! RenderBox || !render.hasSize) return;

    final page = widget.controller.activePage;
    final viewport = render.size;
    if (viewport.width <= 0 || viewport.height <= 0) return;

    final availableWidth = math.max(40.0, viewport.width - 32);
    final availableHeight = math.max(40.0, viewport.height - 32);
    final scale = math.min(
      1.0,
      math.max(
        .20,
        math.min(
          availableWidth / page.width,
          availableHeight / page.height,
        ),
      ),
    );
    final centerX = _margin + page.width / 2;
    final centerY = _margin + page.height / 2;
    final matrix = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(
        viewport.width / 2 - centerX * scale,
        viewport.height / 2 - centerY * scale,
        0,
      );
    _transform.value = matrix;
  }

  Offset? _sceneFromGlobal(Offset global) {
    final render = _viewportKey.currentContext?.findRenderObject();
    if (render is! RenderBox) return null;
    return _transform.toScene(render.globalToLocal(global));
  }

  Offset? _pagePointFromGlobal(Offset global) {
    final point = _sceneFromGlobal(global);
    if (point == null) return null;
    return point - const Offset(_margin, _margin);
  }

  BoxFit _boxFit(String value) => switch (value) {
        'contain' => BoxFit.contain,
        'fill' => BoxFit.fill,
        'none' => BoxFit.none,
        _ => BoxFit.cover,
      };

  TextAlign _textAlign(String value) => switch (value) {
        'center' => TextAlign.center,
        'right' => TextAlign.right,
        'justify' => TextAlign.justify,
        _ => TextAlign.left,
      };

  Alignment _alignment(String value) => switch (value) {
        'center' => Alignment.center,
        'right' => Alignment.centerRight,
        _ => Alignment.centerLeft,
      };

  FontWeight _fontWeight(int value) {
    if (value >= 850) return FontWeight.w900;
    if (value >= 750) return FontWeight.w800;
    if (value >= 650) return FontWeight.w700;
    if (value >= 550) return FontWeight.w600;
    if (value >= 450) return FontWeight.w500;
    if (value >= 350) return FontWeight.w400;
    return FontWeight.w300;
  }
}

enum _CanvasContextAction {
  crop,
  replaceImage,
  copy,
  paste,
  duplicate,
  forward,
  backward,
  delete,
}

enum _ResizeHandle {
  topLeft(-1, -1, SystemMouseCursors.resizeUpLeftDownRight),
  top(0, -1, SystemMouseCursors.resizeUpDown),
  topRight(1, -1, SystemMouseCursors.resizeUpRightDownLeft),
  right(1, 0, SystemMouseCursors.resizeLeftRight),
  bottomRight(1, 1, SystemMouseCursors.resizeUpLeftDownRight),
  bottom(0, 1, SystemMouseCursors.resizeUpDown),
  bottomLeft(-1, 1, SystemMouseCursors.resizeUpRightDownLeft),
  left(-1, 0, SystemMouseCursors.resizeLeftRight);

  const _ResizeHandle(this.h, this.v, this.cursor);

  final int h;
  final int v;
  final MouseCursor cursor;
}

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.step});

  final double step;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x12000000)
      ..strokeWidth = .75;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.step != step;
}
