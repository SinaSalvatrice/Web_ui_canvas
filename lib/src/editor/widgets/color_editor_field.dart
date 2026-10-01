import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ColorEditorField extends StatelessWidget {
  const ColorEditorField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.allowTransparent = false,
    super.key,
  });

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;
  final bool allowTransparent;

  @override
  Widget build(BuildContext context) {
    final color = value == null ? Colors.transparent : Color(value!);
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.colorize_outlined),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: Colors.black26),
              ),
              child: value == null
                  ? const Icon(Icons.block, size: 17)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value == null ? 'transparent' : _hex(value!),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final result = await showDialog<_ColorDialogResult>(
      context: context,
      builder: (context) => _ColorPickerDialog(
        initialValue: value,
        allowTransparent: allowTransparent,
      ),
    );
    if (result == null) return;
    onChanged(result.transparent ? null : result.value);
  }

  static String _hex(int value) =>
      '#${(value & 0xffffffff).toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

class _ColorDialogResult {
  const _ColorDialogResult(this.value, {this.transparent = false});

  final int value;
  final bool transparent;
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({
    required this.initialValue,
    required this.allowTransparent,
  });

  final int? initialValue;
  final bool allowTransparent;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor _hsv;
  late double _alpha;
  late final TextEditingController _hexController;
  late final List<TextEditingController> _rgbaControllers;

  Color get _color => _hsv.toColor().withValues(alpha: _alpha);
  int get _argb => _color.toARGB32();

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue == null
        ? const Color(0xffffffff)
        : Color(widget.initialValue!);
    _hsv = HSVColor.fromColor(initial.withValues(alpha: 1));
    _alpha = initial.a;
    _hexController = TextEditingController();
    _rgbaControllers = List.generate(4, (_) => TextEditingController());
    _syncFields();
  }

  @override
  void dispose() {
    _hexController.dispose();
    for (final controller in _rgbaControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Color'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 260,
                height: 260,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanDown: (details) => _setWheel(details.localPosition),
                  onPanUpdate: (details) => _setWheel(details.localPosition),
                  child: CustomPaint(
                    painter: _HsvWheelPainter(
                      hue: _hsv.hue,
                      saturation: _hsv.saturation,
                      value: _hsv.value,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _slider(
                label: 'Brightness',
                value: _hsv.value,
                onChanged: (value) {
                  setState(() => _hsv = _hsv.withValue(value));
                  _syncFields();
                },
              ),
              _slider(
                label: 'Alpha',
                value: _alpha,
                onChanged: (value) {
                  setState(() => _alpha = value);
                  _syncFields();
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _hexController,
                decoration: const InputDecoration(
                  labelText: 'Hex · AARRGGBB or RRGGBB',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
                ],
                onSubmitted: _applyHex,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: _rgbaControllers[i],
                        decoration: InputDecoration(
                          labelText: const ['R', 'G', 'B', 'A'][i],
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        onSubmitted: (_) => _applyRgba(),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: Colors.black26),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.allowTransparent)
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(
              const _ColorDialogResult(0, transparent: true),
            ),
            icon: const Icon(Icons.block),
            label: const Text('Transparent'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(_ColorDialogResult(_argb)),
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 84, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: 1,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 42,
          child: Text('${(value * 100).round()}%'),
        ),
      ],
    );
  }

  void _setWheel(Offset position) {
    const size = 260.0;
    const radius = size / 2;
    final delta = position - const Offset(radius, radius);
    final distance = delta.distance.clamp(0.0, radius);
    final saturation = (distance / radius).clamp(0.0, 1.0);
    var hue = math.atan2(delta.dy, delta.dx) * 180 / math.pi;
    hue = (hue + 360) % 360;
    setState(() {
      _hsv = HSVColor.fromAHSV(1, hue, saturation, _hsv.value);
    });
    _syncFields();
  }

  void _applyHex(String raw) {
    var value = raw.trim().replaceFirst('#', '');
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8) {
      _syncFields();
      return;
    }
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) {
      _syncFields();
      return;
    }
    _setFromColor(Color(parsed));
  }

  void _applyRgba() {
    final channels = _rgbaControllers.map((controller) {
      final parsed = int.tryParse(controller.text);
      return parsed?.clamp(0, 255).toInt();
    }).toList();
    if (channels.any((value) => value == null)) {
      _syncFields();
      return;
    }
    final color = Color.fromARGB(
      channels[3]!,
      channels[0]!,
      channels[1]!,
      channels[2]!,
    );
    _setFromColor(color);
  }

  void _setFromColor(Color color) {
    setState(() {
      _hsv = HSVColor.fromColor(color.withValues(alpha: 1));
      _alpha = color.a;
    });
    _syncFields();
  }

  void _syncFields() {
    final color = _color;
    final value = color.toARGB32();
    _hexController.text =
        '#${(value & 0xffffffff).toRadixString(16).padLeft(8, '0').toUpperCase()}';
    final channels = [
      (color.r * 255).round(),
      (color.g * 255).round(),
      (color.b * 255).round(),
      (color.a * 255).round(),
    ];
    for (var i = 0; i < channels.length; i++) {
      _rgbaControllers[i].text = channels[i].toString();
    }
  }
}

class _HsvWheelPainter extends CustomPainter {
  const _HsvWheelPainter({
    required this.hue,
    required this.saturation,
    required this.value,
  });

  final double hue;
  final double saturation;
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    const colors = [
      Color(0xffff0000),
      Color(0xffffff00),
      Color(0xff00ff00),
      Color(0xff00ffff),
      Color(0xff0000ff),
      Color(0xffff00ff),
      Color(0xffff0000),
    ];
    final huePaint = Paint()
      ..shader = const SweepGradient(colors: colors).createShader(rect);
    canvas.drawCircle(center, radius, huePaint);

    final saturationPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Colors.white, Color(0x00ffffff)],
      ).createShader(rect);
    canvas.drawCircle(center, radius, saturationPaint);

    if (value < 1) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = Colors.black.withValues(alpha: 1 - value),
      );
    }

    final radians = hue * math.pi / 180;
    final marker = center +
        Offset(math.cos(radians), math.sin(radians)) *
            (radius * saturation);
    canvas.drawCircle(marker, 7, Paint()..color = Colors.white);
    canvas.drawCircle(
      marker,
      7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.black87,
    );
  }

  @override
  bool shouldRepaint(covariant _HsvWheelPainter oldDelegate) =>
      hue != oldDelegate.hue ||
      saturation != oldDelegate.saturation ||
      value != oldDelegate.value;
}
