import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../model/web_element.dart';
import '../editor_controller.dart';

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
                element.x,
                (value) => _update(element.copyWith(x: value)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _number(
                'Y',
                element.y,
                (value) => _update(element.copyWith(y: value)),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _number(
                'Width',
                element.width,
                (value) => _update(element.copyWith(width: math.max(32.0, value).toDouble())),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _number(
                'Height',
                element.height,
                (value) => _update(element.copyWith(height: math.max(24.0, value).toDouble())),
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
          FilledButton.tonalIcon(
            onPressed: () => _pickImage(element),
            icon: const Icon(Icons.folder_open),
            label: const Text('Choose image'),
          ),
          DropdownButtonFormField<String>(
            initialValue: element.imageFit,
            decoration: const InputDecoration(labelText: 'Image fit'),
            items: const [
              DropdownMenuItem(value: 'cover', child: Text('Cover')),
              DropdownMenuItem(value: 'contain', child: Text('Contain')),
              DropdownMenuItem(value: 'fill', child: Text('Fill')),
              DropdownMenuItem(value: 'none', child: Text('None')),
            ],
            onChanged: (value) {
              if (value != null) _update(element.copyWith(imageFit: value));
            },
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
          _number(
            'Font size',
            element.fontSize,
            (value) => _update(element.copyWith(fontSize: math.max(6.0, value).toDouble())),
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
        _colorField(
          'Text color',
          element.foregroundColor,
          (value) => _update(element.copyWith(foregroundColor: value)),
        ),
        _colorField(
          'Background',
          element.backgroundColor,
          (value) => value == null
              ? _update(element.copyWith(clearBackgroundColor: true))
              : _update(element.copyWith(backgroundColor: value)),
          allowTransparent: true,
        ),
        _colorField(
          'Border',
          element.borderColor,
          (value) => value == null
              ? _update(element.copyWith(clearBorderColor: true))
              : _update(element.copyWith(borderColor: value)),
          allowTransparent: true,
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
                initialValue: element.anchorX,
                decoration: const InputDecoration(labelText: 'Horizontal'),
                items: const [
                  DropdownMenuItem(value: 'left', child: Text('Left')),
                  DropdownMenuItem(value: 'center', child: Text('Center')),
                  DropdownMenuItem(value: 'right', child: Text('Right')),
                ],
                onChanged: (value) {
                  if (value != null) _update(element.copyWith(anchorX: value));
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: element.anchorY,
                decoration: const InputDecoration(labelText: 'Vertical'),
                items: const [
                  DropdownMenuItem(value: 'top', child: Text('Top')),
                  DropdownMenuItem(value: 'center', child: Text('Center')),
                  DropdownMenuItem(value: 'bottom', child: Text('Bottom')),
                ],
                onChanged: (value) {
                  if (value != null) _update(element.copyWith(anchorY: value));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _section(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge),
      );

  Widget _number(
    String label,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return Listener(
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent) return;
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

  Widget _colorField(
    String label,
    int? value,
    ValueChanged<int?> onChanged, {
    bool allowTransparent = false,
  }) {
    return TextFormField(
      key: ValueKey('$label-$value'),
      initialValue: value == null ? 'transparent' : _hex(value),
      decoration: InputDecoration(labelText: label),
      onFieldSubmitted: (text) {
        final trimmed = text.trim().toLowerCase();
        if (allowTransparent && (trimmed.isEmpty || trimmed == 'transparent')) {
          onChanged(null);
          return;
        }
        final parsed = _parseHex(trimmed);
        if (parsed != null) onChanged(parsed);
      },
    );
  }

  Future<void> _pickImage(WebElement element) async {
    final file = await FilePicker.pickFile(
      type: FileType.image,
      dialogTitle: 'Choose image',
    );
    final path = file?.path;
    if (path != null) {
      _update(element.copyWith(imagePath: path));
    }
  }

  void _update(WebElement element) => controller.updateElement(element);

  String _pretty(double value) {
    final rounded = value.roundToDouble();
    return value == rounded ? rounded.toInt().toString() : value.toStringAsFixed(2);
  }

  String _hex(int value) =>
      '#${(value & 0xffffffff).toRadixString(16).padLeft(8, '0').toUpperCase()}';

  int? _parseHex(String raw) {
    var value = raw.replaceFirst('#', '');
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8) return null;
    return int.tryParse(value, radix: 16);
  }
}
