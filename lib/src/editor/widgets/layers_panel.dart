import 'package:flutter/material.dart';

import '../editor_controller.dart';

class LayersPanel extends StatelessWidget {
  const LayersPanel({
    required this.controller,
    super.key,
  });

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final elements = controller.activePage.elements;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: Row(
            children: [
              Text('Layers', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(
                tooltip: 'Bring forward',
                onPressed: controller.selectedElement == null
                    ? null
                    : () => controller.moveLayer(1),
                icon: const Icon(Icons.arrow_upward, size: 18),
              ),
              IconButton(
                tooltip: 'Send backward',
                onPressed: controller.selectedElement == null
                    ? null
                    : () => controller.moveLayer(-1),
                icon: const Icon(Icons.arrow_downward, size: 18),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            children: [
              for (final element in elements.reversed)
                ListTile(
                  dense: true,
                  selected: element.id == controller.selectedId,
                  leading: IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: element.visible ? 'Hide' : 'Show',
                    onPressed: () => controller.updateElement(
                      element.copyWith(visible: !element.visible),
                    ),
                    icon: Icon(
                      element.visible ? Icons.visibility : Icons.visibility_off,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    element.text.trim().isEmpty
                        ? element.type.label
                        : element.text.split('\n').first,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(element.type.label),
                  trailing: IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: element.locked ? 'Unlock' : 'Lock',
                    onPressed: () => controller.updateElement(
                      element.copyWith(locked: !element.locked),
                    ),
                    icon: Icon(
                      element.locked ? Icons.lock : Icons.lock_open,
                      size: 17,
                    ),
                  ),
                  onTap: () => controller.select(element.id),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
