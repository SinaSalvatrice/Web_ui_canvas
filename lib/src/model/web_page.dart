import 'web_element.dart';

class WebPage {
  const WebPage({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    required this.backgroundColor,
    this.elements = const [],
  });

  final String id;
  final String name;
  final double width;
  final double height;
  final int backgroundColor;
  final List<WebElement> elements;

  WebPage copyWith({
    String? name,
    double? width,
    double? height,
    int? backgroundColor,
    List<WebElement>? elements,
  }) {
    return WebPage(
      id: id,
      name: name ?? this.name,
      width: width ?? this.width,
      height: height ?? this.height,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      elements: elements ?? this.elements,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'width': width,
        'height': height,
        'backgroundColor': backgroundColor,
        'elements': elements.map((element) => element.toJson()).toList(),
      };

  factory WebPage.fromJson(Map<String, Object?> json) => WebPage(
        id: json['id']! as String,
        name: json['name']! as String,
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
        backgroundColor: json['backgroundColor'] as int? ?? 0xffffffff,
        elements: ((json['elements'] as List?) ?? const [])
            .map(
              (item) =>
                  WebElement.fromJson(Map<String, Object?>.from(item as Map)),
            )
            .toList(),
      );
}
