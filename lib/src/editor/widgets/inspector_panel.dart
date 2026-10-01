import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../model/layout.dart';
import '../../model/responsive.dart';
import '../../model/web_element.dart';
import '../editor_controller.dart';
import 'color_editor_field.dart';
import 'font_picker_field.dart';

class InspectorPanel extends StatelessWidget {
  const InspectorPanel({
    required this.controller,
    super.key,
  });

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final element = controller.selectedElement;
    if (element == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Select an element to edit its properties.'),
        ),
      );
    }

    final layoutElement = controller.resolvedSelectedElement ?? element;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                element.type.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Duplicate',
              onPressed: controller.duplicateSelected,
              icon: const Icon(Icons.copy_outlined),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: controller.removeSelected,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        Text(element.id, style: Theme.of(context).textTheme.labelSmall),
        const Divider(height: 24),
        _section(context, 'Geometry'),
        Row(
          children: [
            Expanded(
              child: _number(
                'X',
                layoutElement.x,
                (value) => controller.updateResolvedGeometry(
                  element.id,
                  x: value,
                ),
                enabled: !controller.isAutoLayoutManaged(element.id),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _number(
                'Y',
                layoutElement.y,
                (value) => controller.updateResolvedGeometry(
                  element.id,
                  y: value,
                ),
                enabled: !controller.isAutoLayoutManaged(element.id),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _number(
                'Width',
                layoutElement.width,
                (value) => controller.updateResolvedGeometry(
                  element.id,
                  width: math.max(32.0, value).toDouble(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _number(
                'Height',
                layoutElement.height,
                (value) => controller.updateResolvedGeometry(
                  element.id,
                  height: math.max(24.0, value).toDouble(),
                ),
              ),
            ),
          ],
        ),
        _number(
          'Rotation °',
          element.rotation * 180 / math.pi,
          (value) => _update(element.copyWith(rotation: value * math.pi / 180)),
        ),
        _number(
          'Opacity %',
          element.opacity * 100,
          (value) => _update(
            element.copyWith(opacity: (value / 100).clamp(0.0, 1.0).toDouble()),
          ),
        ),
        const Divider(height: 26),
        _section(context, 'Hierarchy'),
        DropdownButtonFormField<String>(
          initialValue: element.parentId ?? '__page__',
          decoration: const InputDecoration(labelText: 'Parent'),
          items: [
            const DropdownMenuItem(
              value: '__page__',
              child: Text('Page'),
            ),
            ...controller.parentCandidatesFor(element.id).map(
                  (candidate) => DropdownMenuItem(
                    value: candidate.id,
                    child: Text(
                      '${candidate.type.label} · ${candidate.id}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
          ],
          onChanged: (value) {
            if (value == null) return;
            controller.setParent(
              element.id,
              value == '__page__' ? null : value,
            );
          },
        ),
        if (element.parentId != null) ...[
          const SizedBox(height: 8),
          Text(
            controller.isAutoLayoutManaged(element.id)
                ? 'Position is managed by the parent layout.'
                : 'Position is relative to the parent container.',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          Row(
            children: [
              Expanded(
                child: _number(
                  'Margin T',
                  element.marginTop,
                  (value) => controller.updateMargins(
                    element.id,
                    top: math.max(0, value).toDouble(),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _number(
                  'Margin R',
                  element.marginRight,
                  (value) => controller.updateMargins(
                    element.id,
                    right: math.max(0, value).toDouble(),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _number(
                  'Margin B',
                  element.marginBottom,
                  (value) => controller.updateMargins(
                    element.id,
                    bottom: math.max(0, value).toDouble(),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _number(
                  'Margin L',
                  element.marginLeft,
                  (value) => controller.updateMargins(
                    element.id,
                    left: math.max(0, value).toDouble(),
                  ),
                ),
              ),
            ],
          ),
        ],
        if (element.canContainChildren) ...[
          const Divider(height: 26),
          _section(context, 'Container layout'),
          DropdownButtonFormField<WebLayoutMode>(
            initialValue: element.layoutMode,
            decoration: const InputDecoration(labelText: 'Layout'),
            items: WebLayoutMode.values
                .map(
                  (mode) => DropdownMenuItem(
                    value: mode,
                    child: Text(mode.label),
                  ),
                )
                .toList(),
            onChanged: (mode) {
              if (mode != null) {
                controller.setLayoutMode(element.id, mode);
              }
            },
          ),
          if (element.layoutMode != WebLayoutMode.free) ...[
            Row(
              children: [
                Expanded(
                  child: _number(
                    'Gap',
                    element.gap,
                    (value) => controller.updateContainerLayout(
                      element.id,
                      gap: math.max(0, value).toDouble(),
                    ),
                  ),
                ),
                if (element.layoutMode == WebLayoutMode.grid) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _number(
                      'Columns',
                      element.gridColumns.toDouble(),
                      (value) => controller.updateContainerLayout(
                        element.id,
                        gridColumns: value.round().clamp(1, 12).toInt(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<WebMainAlignment>(
                    initialValue: element.mainAlignment,
                    decoration: const InputDecoration(labelText: 'Main'),
                    items: WebMainAlignment.values
                        .map(
                          (alignment) => DropdownMenuItem(
                            value: alignment,
                            child: Text(alignment.label),
                          ),
                        )
                        .toList(),
                    onChanged: (alignment) {
                      if (alignment != null) {
                        controller.updateContainerLayout(
                          element.id,
                          mainAlignment: alignment,
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<WebCrossAlignment>(
                    initialValue: element.crossAlignment,
                    decoration: const InputDecoration(labelText: 'Cross'),
                    items: WebCrossAlignment.values
                        .map(
                          (alignment) => DropdownMenuItem(
                            value: alignment,
                            child: Text(alignment.label),
                          ),
                        )
                        .toList(),
                    onChanged: (alignment) {
                      if (alignment != null) {
                        controller.updateContainerLayout(
                          element.id,
                          crossAlignment: alignment,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
          Row(
            children: [
              Expanded(
                child: _number(
                  'Padding T',
                  element.paddingTop,
                  (value) => controller.updateContainerLayout(
                    element.id,
                    paddingTop: math.max(0, value).toDouble(),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _number(
                  'Padding R',
                  element.paddingRight,
                  (value) => controller.updateContainerLayout(
                    element.id,
                    paddingRight: math.max(0, value).toDouble(),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _number(
                  'Padding B',
                  element.paddingBottom,
                  (value) => controller.updateContainerLayout(
                    element.id,
                    paddingBottom: math.max(0, value).toDouble(),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _number(
                  'Padding L',
                  element.paddingLeft,
                  (value) => controller.updateContainerLayout(
                    element.id,
                    paddingLeft: math.max(0, value).toDouble(),
                  ),
                ),
              ),
            ],
          ),
        ],
        const Divider(height: 26),
        _section(context, 'Responsive'),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<WebSizeMode>(
                initialValue: layoutElement.widthMode,
                decoration: const InputDecoration(labelText: 'Width'),
                items: WebSizeMode.values
                    .map(
                      (mode) => DropdownMenuItem(
                        value: mode,
                        child: Text(mode.label),
                      ),
                    )
                    .toList(),
                onChanged: (mode) {
                  if (mode != null) {
                    controller.setWidthMode(element.id, mode);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<WebSizeMode>(
                initialValue: layoutElement.heightMode,
                decoration: const InputDecoration(labelText: 'Height'),
                items: WebSizeMode.values
                    .map(
                      (mode) => DropdownMenuItem(
                        value: mode,
                        child: Text(mode.label),
                      ),
                    )
                    .toList(),
                onChanged: (mode) {
                  if (mode != null) {
                    controller.setHeightMode(element.id, mode);
                  }
                },
              ),
            ),
          ],
        ),
        if (layoutElement.widthMode == WebSizeMode.percent)
          _number(
            'Width %',
            layoutElement.widthPercent * 100,
            (value) => controller.setWidthPercent(
              element.id,
              value / 100,
            ),
          ),
        if (layoutElement.heightMode == WebSizeMode.percent)
          _number(
            'Height %',
            layoutElement.heightPercent * 100,
            (value) => controller.setHeightPercent(
              element.id,
              value / 100,
            ),
          ),
        Row(
          children: [
            Expanded(
              child: _optionalNumber(
                'Min width',
                layoutElement.minWidth,
                (value) => controller.setSizeConstraints(
                  element.id,
                  minWidth: value,
                  clearMinWidth: value == null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _optionalNumber(
                'Max width',
                layoutElement.maxWidth,
                (value) => controller.setSizeConstraints(
                  element.id,
                  maxWidth: value,
                  clearMaxWidth: value == null,
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _optionalNumber(
                'Min height',
                layoutElement.minHeight,
                (value) => controller.setSizeConstraints(
                  element.id,
                  minHeight: value,
                  clearMinHeight: value == null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _optionalNumber(
                'Max height',
                layoutElement.maxHeight,
                (value) => controller.setSizeConstraints(
                  element.id,
                  maxHeight: value,
                  clearMaxHeight: value == null,
                ),
              ),
            ),
          ],
        ),
        if (controller.activeBreakpoint != WebBreakpoint.desktop)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  controller.resetActiveBreakpointOverrides(element.id),
              icon: const Icon(Icons.restart_alt),
              label: Text(
                'Reset ${controller.activeBreakpoint.label} overrides',
              ),
            ),
          ),
        const Divider(height: 26),
        _section(context, 'Arrange'),
        Text(
          controller.selectedIds.length == 1
              ? 'Align to canvas'
              : 'Align selected elements',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            _arrangeButton(
              context,
              tooltip: 'Align left',
              icon: Icons.align_horizontal_left,
              onPressed: () =>
                  controller.alignSelection(SelectionAlignment.left),
            ),
            _arrangeButton(
              context,
              tooltip: 'Align horizontal center',
              icon: Icons.align_horizontal_center,
              onPressed: () => controller.alignSelection(
                SelectionAlignment.horizontalCenter,
              ),
            ),
            _arrangeButton(
              context,
              tooltip: 'Align right',
              icon: Icons.align_horizontal_right,
              onPressed: () =>
                  controller.alignSelection(SelectionAlignment.right),
            ),
            _arrangeButton(
              context,
              tooltip: 'Align top',
              icon: Icons.align_vertical_top,
              onPressed: () =>
                  controller.alignSelection(SelectionAlignment.top),
            ),
            _arrangeButton(
              context,
              tooltip: 'Align vertical center',
              icon: Icons.align_vertical_center,
              onPressed: () => controller.alignSelection(
                SelectionAlignment.verticalCenter,
              ),
            ),
            _arrangeButton(
              context,
              tooltip: 'Align bottom',
              icon: Icons.align_vertical_bottom,
              onPressed: () =>
                  controller.alignSelection(SelectionAlignment.bottom),
            ),
          ],
        ),
        if (controller.selectedIds.length >= 3) ...[
          const SizedBox(height: 8),
          Text(
            'Distribute',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            children: [
              _arrangeButton(
                context,
                tooltip: 'Distribute horizontally',
                icon: Icons.space_bar,
                onPressed: () => controller.distributeSelection(
                  SelectionDistribution.horizontal,
                ),
              ),
              _arrangeButton(
                context,
                tooltip: 'Distribute vertically',
                icon: Icons.swap_vert,
                onPressed: () => controller.distributeSelection(
                  SelectionDistribution.vertical,
                ),
              ),
            ],
          ),
        ],
        const Divider(height: 26),
        _section(context, 'Content'),
        if (element.type != WebElementType.image &&
            element.type != WebElementType.divider)
          TextFormField(
            key: ValueKey('text-${element.id}-${element.text}'),
            initialValue: element.text,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Text'),
            onFieldSubmitted: (value) => _update(element.copyWith(text: value)),
          ),
        if (element.type == WebElementType.image) ...[
          Text(
            element.imagePath ?? 'No image selected',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _pickImage(element),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Replace'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: element.locked
                      ? null
                      : () {
                          if (controller.isCropping(element.id)) {
                            controller.exitCropMode();
                          } else {
                            controller.enterCropMode(element.id);
                          }
                        },
                  icon: Icon(
                    controller.isCropping(element.id)
                        ? Icons.check
                        : Icons.crop_outlined,
                  ),
                  label: Text(
                    controller.isCropping(element.id)
                        ? 'Done'
                        : 'Crop',
                  ),
                ),
              ),
            ],
          ),
          if (controller.isCropping(element.id))
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Drag the image directly on the canvas to move the crop.',
              ),
            ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: element.imageFit,
            decoration: const InputDecoration(labelText: 'Image fit'),
            items: const [
              DropdownMenuItem(value: 'cover', child: Text('Cover')),
              DropdownMenuItem(value: 'contain', child: Text('Contain')),
              DropdownMenuItem(value: 'fill', child: Text('Fill')),
              DropdownMenuItem(value: 'none', child: Text('Original')),
            ],
            onChanged: (value) {
              if (value != null) _update(element.copyWith(imageFit: value));
            },
          ),
          const SizedBox(height: 10),
          Text(
            'Image zoom · ${(element.imageScale * 100).round()}%',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          Slider(
            value: element.imageScale.clamp(.25, 5.0).toDouble(),
            min: .25,
            max: 5,
            divisions: 95,
            onChanged: element.locked
                ? null
                : (value) => controller.updateElement(
                      element.copyWith(imageScale: value),
                      commit: false,
                    ),
            onChangeEnd: element.locked
                ? null
                : (_) => controller.commitLiveEdit(),
          ),
          _number(
            'Image zoom %',
            element.imageScale * 100,
            (value) => _update(
              element.copyWith(
                imageScale: (value / 100).clamp(.25, 5.0).toDouble(),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _number(
                  'Focus X %',
                  element.imagePositionX * 100,
                  (value) => _update(
                    element.copyWith(
                      imagePositionX:
                          (value / 100).clamp(-1.0, 1.0).toDouble(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _number(
                  'Focus Y %',
                  element.imagePositionY * 100,
                  (value) => _update(
                    element.copyWith(
                      imagePositionY:
                          (value / 100).clamp(-1.0, 1.0).toDouble(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => controller.resetImageCrop(element.id),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset crop'),
            ),
          ),
        ],
        if (element.type == WebElementType.button ||
            element.type == WebElementType.navigation ||
            element.type == WebElementType.card)
          TextFormField(
            key: ValueKey('href-${element.id}-${element.href}'),
            initialValue: element.href,
            decoration: const InputDecoration(labelText: 'Link / href'),
            onFieldSubmitted: (value) => _update(element.copyWith(href: value)),
          ),
        const Divider(height: 26),
        _section(context, 'Style'),
        if (element.type != WebElementType.image &&
            element.type != WebElementType.divider) ...[
          FontPickerField(
            family: element.fontFamily,
            path: element.fontPath,
            onSelected: (family, path) => _update(
              element.copyWith(
                fontFamily: family,
                fontPath: path,
                clearFontPath: path == null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _number(
            'Font size',
            element.fontSize,
            (value) => _update(
              element.copyWith(
                fontSize: math.max(6.0, value).toDouble(),
              ),
            ),
          ),
          DropdownButtonFormField<int>(
            initialValue: element.fontWeight,
            decoration: const InputDecoration(labelText: 'Font weight'),
            items: const [300, 400, 500, 600, 700, 800, 900]
                .map(
                  (weight) => DropdownMenuItem(
                    value: weight,
                    child: Text('$weight'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) _update(element.copyWith(fontWeight: value));
            },
          ),
          Row(
            children: [
              Expanded(
                child: _number(
                  'Letter spacing',
                  element.letterSpacing,
                  (value) =>
                      _update(element.copyWith(letterSpacing: value)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _number(
                  'Line height',
                  element.lineHeight,
                  (value) => _update(
                    element.copyWith(
                      lineHeight: value.clamp(.5, 4.0).toDouble(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          DropdownButtonFormField<String>(
            initialValue: element.textAlign,
            decoration: const InputDecoration(labelText: 'Text align'),
            items: const [
              DropdownMenuItem(value: 'left', child: Text('Left')),
              DropdownMenuItem(value: 'center', child: Text('Center')),
              DropdownMenuItem(value: 'right', child: Text('Right')),
            ],
            onChanged: (value) {
              if (value != null) _update(element.copyWith(textAlign: value));
            },
          ),
        ],
        ColorEditorField(
          label: 'Text color',
          value: element.foregroundColor,
          onChanged: (value) {
            if (value != null) {
              _update(element.copyWith(foregroundColor: value));
            }
          },
        ),
        ColorEditorField(
          label: 'Background',
          value: element.backgroundColor,
          allowTransparent: true,
          onChanged: (value) => value == null
              ? _update(element.copyWith(clearBackgroundColor: true))
              : _update(element.copyWith(backgroundColor: value)),
        ),
        ColorEditorField(
          label: 'Border',
          value: element.borderColor,
          allowTransparent: true,
          onChanged: (value) => value == null
              ? _update(element.copyWith(clearBorderColor: true))
              : _update(element.copyWith(borderColor: value)),
        ),
        _number(
          'Border width',
          element.borderWidth,
          (value) => _update(element.copyWith(borderWidth: math.max(0.0, value).toDouble())),
        ),
        _number(
          'Corner radius',
          element.borderRadius,
          (value) => _update(element.copyWith(borderRadius: math.max(0.0, value).toDouble())),
        ),
        const Divider(height: 26),
        _section(context, 'Anchors'),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: layoutElement.anchorX,
                decoration: const InputDecoration(labelText: 'Horizontal'),
                items: const [
                  DropdownMenuItem(value: 'left', child: Text('Left')),
                  DropdownMenuItem(value: 'center', child: Text('Center')),
                  DropdownMenuItem(value: 'right', child: Text('Right')),
                ],
                onChanged: (value) {
                  if (value != null) controller.setAnchorX(element.id, value);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: layoutElement.anchorY,
                decoration: const InputDecoration(labelText: 'Vertical'),
                items: const [
                  DropdownMenuItem(value: 'top', child: Text('Top')),
                  DropdownMenuItem(value: 'center', child: Text('Center')),
                  DropdownMenuItem(value: 'bottom', child: Text('Bottom')),
                ],
                onChanged: (value) {
                  if (value != null) controller.setAnchorY(element.id, value);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _arrangeButton(
    BuildContext context, {
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton.filledTonal(
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
      ),
    );
  }

  Widget _section(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge),
      );

  Widget _optionalNumber(
    String label,
    double? value,
    ValueChanged<double?> onChanged,
  ) {
    return TextFormField(
      key: ValueKey('$label-${value?.toStringAsFixed(3) ?? 'none'}'),
      initialValue: value == null ? '' : _pretty(value),
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Auto',
      ),
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: false,
      ),
      onFieldSubmitted: (text) {
        final trimmed = text.trim();
        if (trimmed.isEmpty) {
          onChanged(null);
          return;
        }
        final parsed = double.tryParse(trimmed.replaceAll(',', '.'));
        if (parsed != null) onChanged(math.max(0, parsed).toDouble());
      },
    );
  }

  Widget _number(
    String label,
    double value,
    ValueChanged<double> onChanged, {
    bool enabled = true,
  }) {
    return Listener(
      onPointerSignal: (event) {
        if (!enabled || event is! PointerScrollEvent) return;
        GestureBinding.instance.pointerSignalResolver.register(
          event,
          (resolved) {
            if (resolved is! PointerScrollEvent) return;
            final amount = resolved.scrollDelta.dy != 0
                ? resolved.scrollDelta.dy
                : resolved.scrollDelta.dx;
            if (amount == 0) return;
            onChanged(value + (amount < 0 ? 1 : -1));
          },
        );
      },
      child: TextFormField(
        enabled: enabled,
        key: ValueKey('$label-${value.toStringAsFixed(3)}'),
        initialValue: _pretty(value),
        decoration: InputDecoration(labelText: label),
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        onFieldSubmitted: (text) {
          final parsed = double.tryParse(text.replaceAll(',', '.'));
          if (parsed != null) onChanged(parsed);
        },
      ),
    );
  }

  Future<void> _pickImage(WebElement element) async {
    final file = await FilePicker.pickFile(
      type: FileType.image,
      dialogTitle: 'Choose image',
    );
    final path = file?.path;
    if (path != null) {
      _update(
        element.copyWith(
          imagePath: path,
          imagePositionX: 0,
          imagePositionY: 0,
          imageScale: 1,
        ),
      );
    }
  }

  void _update(WebElement element) => controller.updateElement(element);

  String _pretty(double value) {
    final rounded = value.roundToDouble();
    return value == rounded ? rounded.toInt().toString() : value.toStringAsFixed(2);
  }

}
