enum WebElementType {
  text,
  image,
  button,
  divider,
  container,
  section,
  navigation,
  input,
  card,
}

extension WebElementTypeX on WebElementType {
  String get label => switch (this) {
        WebElementType.text => 'Text',
        WebElementType.image => 'Image',
        WebElementType.button => 'Button',
        WebElementType.divider => 'Divider',
        WebElementType.container => 'Container',
        WebElementType.section => 'Section',
        WebElementType.navigation => 'Navigation',
        WebElementType.input => 'Input',
        WebElementType.card => 'Card',
      };

  String get category => switch (this) {
        WebElementType.text || WebElementType.image => 'Content',
        WebElementType.button || WebElementType.input => 'Controls',
        WebElementType.divider => 'Content',
        WebElementType.container ||
        WebElementType.section ||
        WebElementType.card =>
          'Layout',
        WebElementType.navigation => 'Navigation',
      };

  double get defaultWidth => switch (this) {
        WebElementType.text => 420,
        WebElementType.image => 420,
        WebElementType.button => 180,
        WebElementType.divider => 520,
        WebElementType.container => 420,
        WebElementType.section => 960,
        WebElementType.navigation => 960,
        WebElementType.input => 300,
        WebElementType.card => 340,
      };

  double get defaultHeight => switch (this) {
        WebElementType.text => 120,
        WebElementType.image => 280,
        WebElementType.button => 52,
        WebElementType.divider => 8,
        WebElementType.container => 260,
        WebElementType.section => 360,
        WebElementType.navigation => 72,
        WebElementType.input => 52,
        WebElementType.card => 300,
      };

  String get defaultText => switch (this) {
        WebElementType.text => 'Text block',
        WebElementType.image => '',
        WebElementType.button => 'Button',
        WebElementType.divider => '',
        WebElementType.container => '',
        WebElementType.section => 'Section',
        WebElementType.navigation => 'Home    About    Contact',
        WebElementType.input => 'Input',
        WebElementType.card => 'Card',
      };
}

class WebElement {
  const WebElement({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0,
    this.locked = false,
    this.visible = true,
    this.text = '',
    this.href = '',
    this.imagePath,
    this.backgroundColor,
    this.foregroundColor = 0xff202020,
    this.borderColor,
    this.borderWidth = 0,
    this.borderRadius = 0,
    this.opacity = 1,
    this.fontSize = 22,
    this.fontWeight = 400,
    this.textAlign = 'left',
    this.anchorX = 'left',
    this.anchorY = 'top',
    this.imageFit = 'cover',
    this.imagePositionX = 0,
    this.imagePositionY = 0,
    this.imageScale = 1,
  });

  final String id;
  final WebElementType type;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final bool locked;
  final bool visible;
  final String text;
  final String href;
  final String? imagePath;
  final int? backgroundColor;
  final int foregroundColor;
  final int? borderColor;
  final double borderWidth;
  final double borderRadius;
  final double opacity;
  final double fontSize;
  final int fontWeight;
  final String textAlign;
  final String anchorX;
  final String anchorY;
  final String imageFit;
  final double imagePositionX;
  final double imagePositionY;
  final double imageScale;

  factory WebElement.fresh({
    required String id,
    required WebElementType type,
    required double x,
    required double y,
  }) {
    final background = switch (type) {
      WebElementType.button => 0xff202020,
      WebElementType.card => 0xfff4f4f4,
      WebElementType.navigation => 0xfff7f7f7,
      WebElementType.input => 0xffffffff,
      _ => null,
    };
    final foreground =
        type == WebElementType.button ? 0xffffffff : 0xff202020;
    final borderWidth = switch (type) {
      WebElementType.card || WebElementType.input => 1.0,
      WebElementType.divider => 0.0,
      _ => 0.0,
    };

    return WebElement(
      id: id,
      type: type,
      x: x,
      y: y,
      width: type.defaultWidth,
      height: type.defaultHeight,
      text: type.defaultText,
      backgroundColor: background,
      foregroundColor: foreground,
      borderColor: borderWidth > 0 ? 0xffbdbdbd : null,
      borderWidth: borderWidth,
      borderRadius: type == WebElementType.button ? 8 : 0,
      fontSize: type == WebElementType.navigation ? 18 : 22,
      fontWeight: type == WebElementType.button ? 600 : 400,
    );
  }

  WebElement copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    bool? locked,
    bool? visible,
    String? text,
    String? href,
    String? imagePath,
    bool clearImagePath = false,
    int? backgroundColor,
    bool clearBackgroundColor = false,
    int? foregroundColor,
    int? borderColor,
    bool clearBorderColor = false,
    double? borderWidth,
    double? borderRadius,
    double? opacity,
    double? fontSize,
    int? fontWeight,
    String? textAlign,
    String? anchorX,
    String? anchorY,
    String? imageFit,
    double? imagePositionX,
    double? imagePositionY,
    double? imageScale,
  }) {
    return WebElement(
      id: id,
      type: type,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      locked: locked ?? this.locked,
      visible: visible ?? this.visible,
      text: text ?? this.text,
      href: href ?? this.href,
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      backgroundColor:
          clearBackgroundColor ? null : (backgroundColor ?? this.backgroundColor),
      foregroundColor: foregroundColor ?? this.foregroundColor,
      borderColor: clearBorderColor ? null : (borderColor ?? this.borderColor),
      borderWidth: borderWidth ?? this.borderWidth,
      borderRadius: borderRadius ?? this.borderRadius,
      opacity: opacity ?? this.opacity,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      textAlign: textAlign ?? this.textAlign,
      anchorX: anchorX ?? this.anchorX,
      anchorY: anchorY ?? this.anchorY,
      imageFit: imageFit ?? this.imageFit,
      imagePositionX: imagePositionX ?? this.imagePositionX,
      imagePositionY: imagePositionY ?? this.imagePositionY,
      imageScale: imageScale ?? this.imageScale,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type.name,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'rotation': rotation,
        'locked': locked,
        'visible': visible,
        'text': text,
        'href': href,
        'imagePath': imagePath,
        'backgroundColor': backgroundColor,
        'foregroundColor': foregroundColor,
        'borderColor': borderColor,
        'borderWidth': borderWidth,
        'borderRadius': borderRadius,
        'opacity': opacity,
        'fontSize': fontSize,
        'fontWeight': fontWeight,
        'textAlign': textAlign,
        'anchorX': anchorX,
        'anchorY': anchorY,
        'imageFit': imageFit,
        'imagePositionX': imagePositionX,
        'imagePositionY': imagePositionY,
        'imageScale': imageScale,
      };

  factory WebElement.fromJson(Map<String, Object?> json) => WebElement(
        id: json['id']! as String,
        type: WebElementType.values.byName(json['type']! as String),
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
        locked: json['locked'] as bool? ?? false,
        visible: json['visible'] as bool? ?? true,
        text: json['text'] as String? ?? '',
        href: json['href'] as String? ?? '',
        imagePath: json['imagePath'] as String?,
        backgroundColor: json['backgroundColor'] as int?,
        foregroundColor: json['foregroundColor'] as int? ?? 0xff202020,
        borderColor: json['borderColor'] as int?,
        borderWidth: (json['borderWidth'] as num?)?.toDouble() ?? 0,
        borderRadius: (json['borderRadius'] as num?)?.toDouble() ?? 0,
        opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 22,
        fontWeight: (json['fontWeight'] as num?)?.toInt() ?? 400,
        textAlign: json['textAlign'] as String? ?? 'left',
        anchorX: json['anchorX'] as String? ?? 'left',
        anchorY: json['anchorY'] as String? ?? 'top',
        imageFit: json['imageFit'] as String? ?? 'cover',
        imagePositionX:
            (json['imagePositionX'] as num?)?.toDouble() ?? 0,
        imagePositionY:
            (json['imagePositionY'] as num?)?.toDouble() ?? 0,
        imageScale: (json['imageScale'] as num?)?.toDouble() ?? 1,
      );
}
