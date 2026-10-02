import 'package:flutter/material.dart';

import '../../model/web_element.dart';

class ComponentLibrary extends StatelessWidget {
  const ComponentLibrary({
    required this.onAdd,
    super.key,
  });

  final ValueChanged<WebElementType> onAdd;

  @override
  Widget build(BuildContext context) {
    final categories = <String, List<WebElementType>>{};
    for (final type in WebElementType.values) {
      categories.putIfAbsent(type.category, () => []).add(type);
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('Elements', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final entry in categories.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              entry.key,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          for (final type in entry.value)
            Draggable<WebElementType>(
              data: type,
              feedback: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(type.label),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: .35,
                child: _ElementTile(type: type, onTap: () {}),
              ),
              child: _ElementTile(
                type: type,
                onTap: () => onAdd(type),
              ),
            ),
        ],
      ],
    );
  }
}

class _ElementTile extends StatelessWidget {
  const _ElementTile({
    required this.type,
    required this.onTap,
  });

  final WebElementType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(_icon(type), size: 19),
      title: Text(type.label),
      onTap: onTap,
    );
  }

  IconData _icon(WebElementType type) => switch (type) {
        WebElementType.text => Icons.text_fields,
        WebElementType.image => Icons.image_outlined,
        WebElementType.button => Icons.smart_button_outlined,
        WebElementType.divider => Icons.horizontal_rule,
        WebElementType.container => Icons.crop_square,
        WebElementType.section => Icons.web_asset_outlined,
        WebElementType.navigation => Icons.menu,
        WebElementType.input => Icons.input,
        WebElementType.toggle => Icons.toggle_on_outlined,
        WebElementType.card => Icons.view_agenda_outlined,
      };
}
