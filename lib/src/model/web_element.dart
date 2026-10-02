import 'layout.dart';
import 'responsive.dart';

enum WebElementType {
  text,
  image,
  button,
  divider,
  container,
  section,
  navigation,
  input,
  toggle,
  card;

  String get label => switch (this) {
        WebElementType.text => 'Text',
        WebElementType.image => 'Image',
        WebElementType.button => 'Button',
        WebElementType.divider => 'Divider',
        WebElementType.container => 'Container',
        WebElementType.section => 'Section',
        WebElementType.navigation => 'Navigation',
        WebElementType.input => 'Input',
        WebElementType.toggle => 'Switch',
        WebElementType.card => 'Card',
      };
}

extension WebElementTypeX on WebElementType {
  String get category => switch (this) {
        WebElementType.text || WebElementType.image => 'Content',
        WebElementType.button ||
        WebElementType.input ||
        WebElementType.toggle => 'Controls',
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
        WebElementType.toggle => 64,
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
        WebElementType.toggle => 36,
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
        WebElementType.toggle => '',
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
    this.backplatePath,
    this.backplateEnabled = false,
    this.backplateFit = 'cover',
    this.maskPath,
    this.maskEnabled = false,
    this.backgroundColor,
    this.foregroundColor = 0xff202020,
    this.borderColor,
    this.borderWidth = 0,
    this.borderRadius = 0,
    this.opacity = 1,
    this.fontSize = 22,
    this.fontWeight = 400,
    this.fontFamily = 'Arial',
    this.fontPath,
    this.letterSpacing = 0,
    this.lineHeight = 1.2,
    this.textAlign = 'left',
    this.textMode = 'wrap',
    this.textHighlightColor,
    this.textStrokeColor,
    this.textStrokeWidth = 0,
    this.transition = 'none',
    this.transitionEnabled = false,
    this.transitionDurationMs = 420,
    this.pressScaleEnabled = false,
    this.pressScale = .96,
    this.anchorX = 'left',
    this.anchorY = 'top',
    this.imageFit = 'cover',
    this.imagePositionX = 0,
    this.imagePositionY = 0,
    this.imageScale = 1,
    this.widthMode = WebSizeMode.fixed,
    this.heightMode = WebSizeMode.fixed,
    this.widthPercent = 1,
    this.heightPercent = 1,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    this.responsiveOverrides = const {},
    this.parentId,
    this.layoutMode = WebLayoutMode.free,
    this.gap = 16,
    this.paddingTop = 0,
    this.paddingRight = 0,
    this.paddingBottom = 0,
    this.paddingLeft = 0,
    this.marginTop = 0,
    this.marginRight = 0,
    this.marginBottom = 0,
    this.marginLeft = 0,
    this.gridColumns = 2,
    this.mainAlignment = WebMainAlignment.start,
    this.crossAlignment = WebCrossAlignment.start,
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
  final String? backplatePath;
  final bool backplateEnabled;
  final String backplateFit;
  final String? maskPath;
  final bool maskEnabled;
  final int? backgroundColor;
  final int foregroundColor;
  final int? borderColor;
  final double borderWidth;
  final double borderRadius;
  final double opacity;
  final double fontSize;
  final int fontWeight;
  final String fontFamily;
  final String? fontPath;
  final double letterSpacing;
  final double lineHeight;
  final String textAlign;
  final String textMode;
  final int? textHighlightColor;
  final int? textStrokeColor;
  final double textStrokeWidth;
  final String transition;
  final bool transitionEnabled;
  final int transitionDurationMs;
  final bool pressScaleEnabled;
  final double pressScale;
  final String anchorX;
  final String anchorY;
  final String imageFit;
  final double imagePositionX;
  final double imagePositionY;
  final double imageScale;
  final WebSizeMode widthMode;
  final WebSizeMode heightMode;
  final double widthPercent;
  final double heightPercent;
  final double? minWidth;
  final double? maxWidth;
  final double? minHeight;
  final double? maxHeight;
  final Map<WebBreakpoint, WebElementBreakpointOverride> responsiveOverrides;
  final String? parentId;
  final WebLayoutMode layoutMode;
  final double gap;
  final double paddingTop;
  final double paddingRight;
  final double paddingBottom;
  final double paddingLeft;
  final double marginTop;
  final double marginRight;
  final double marginBottom;
  final double marginLeft;
  final int gridColumns;
  final WebMainAlignment mainAlignment;
  final WebCrossAlignment crossAlignment;

  bool get canContainChildren =>
      type == WebElementType.container ||
      type == WebElementType.section ||
      type == WebElementType.card ||
      type == WebElementType.navigation;

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
      WebElementType.toggle => 0xffd0d0d0,
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
      borderRadius: type == WebElementType.button
          ? 8
          : type == WebElementType.toggle
              ? 999
              : 0,
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
    String? backplatePath,
    bool clearBackplatePath = false,
    bool? backplateEnabled,
    String? backplateFit,
    String? maskPath,
    bool clearMaskPath = false,
    bool? maskEnabled,
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
    String? fontFamily,
    String? fontPath,
    bool clearFontPath = false,
    double? letterSpacing,
    double? lineHeight,
    String? textAlign,
    String? textMode,
    int? textHighlightColor,
    bool clearTextHighlightColor = false,
    int? textStrokeColor,
    bool clearTextStrokeColor = false,
    double? textStrokeWidth,
    String? transition,
    bool? transitionEnabled,
    int? transitionDurationMs,
    bool? pressScaleEnabled,
    double? pressScale,
    String? anchorX,
    String? anchorY,
    String? imageFit,
    double? imagePositionX,
    double? imagePositionY,
    double? imageScale,
    WebSizeMode? widthMode,
    WebSizeMode? heightMode,
    double? widthPercent,
    double? heightPercent,
    double? minWidth,
    bool clearMinWidth = false,
    double? maxWidth,
    bool clearMaxWidth = false,
    double? minHeight,
    bool clearMinHeight = false,
    double? maxHeight,
    bool clearMaxHeight = false,
    Map<WebBreakpoint, WebElementBreakpointOverride>? responsiveOverrides,
    String? parentId,
    bool clearParentId = false,
    WebLayoutMode? layoutMode,
    double? gap,
    double? paddingTop,
    double? paddingRight,
    double? paddingBottom,
    double? paddingLeft,
    double? marginTop,
    double? marginRight,
    double? marginBottom,
    double? marginLeft,
    int? gridColumns,
    WebMainAlignment? mainAlignment,
    WebCrossAlignment? crossAlignment,
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
      backplatePath: clearBackplatePath
          ? null
          : (backplatePath ?? this.backplatePath),
      backplateEnabled: backplateEnabled ?? this.backplateEnabled,
      backplateFit: backplateFit ?? this.backplateFit,
      maskPath: clearMaskPath ? null : (maskPath ?? this.maskPath),
      maskEnabled: maskEnabled ?? this.maskEnabled,
      backgroundColor:
          clearBackgroundColor ? null : (backgroundColor ?? this.backgroundColor),
      foregroundColor: foregroundColor ?? this.foregroundColor,
      borderColor: clearBorderColor ? null : (borderColor ?? this.borderColor),
      borderWidth: borderWidth ?? this.borderWidth,
      borderRadius: borderRadius ?? this.borderRadius,
      opacity: opacity ?? this.opacity,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      fontFamily: fontFamily ?? this.fontFamily,
      fontPath: clearFontPath ? null : (fontPath ?? this.fontPath),
      letterSpacing: letterSpacing ?? this.letterSpacing,
      lineHeight: lineHeight ?? this.lineHeight,
      textAlign: textAlign ?? this.textAlign,
      textMode: textMode ?? this.textMode,
      textHighlightColor: clearTextHighlightColor
          ? null
          : (textHighlightColor ?? this.textHighlightColor),
      textStrokeColor: clearTextStrokeColor
          ? null
          : (textStrokeColor ?? this.textStrokeColor),
      textStrokeWidth: textStrokeWidth ?? this.textStrokeWidth,
      transition: transition ?? this.transition,
      transitionEnabled: transitionEnabled ?? this.transitionEnabled,
      transitionDurationMs: transitionDurationMs ?? this.transitionDurationMs,
      pressScaleEnabled: pressScaleEnabled ?? this.pressScaleEnabled,
      pressScale: pressScale ?? this.pressScale,
      anchorX: anchorX ?? this.anchorX,
      anchorY: anchorY ?? this.anchorY,
      imageFit: imageFit ?? this.imageFit,
      imagePositionX: imagePositionX ?? this.imagePositionX,
      imagePositionY: imagePositionY ?? this.imagePositionY,
      imageScale: imageScale ?? this.imageScale,
      widthMode: widthMode ?? this.widthMode,
      heightMode: heightMode ?? this.heightMode,
      widthPercent: widthPercent ?? this.widthPercent,
      heightPercent: heightPercent ?? this.heightPercent,
      minWidth: clearMinWidth ? null : (minWidth ?? this.minWidth),
      maxWidth: clearMaxWidth ? null : (maxWidth ?? this.maxWidth),
      minHeight: clearMinHeight ? null : (minHeight ?? this.minHeight),
      maxHeight: clearMaxHeight ? null : (maxHeight ?? this.maxHeight),
      responsiveOverrides: responsiveOverrides ?? this.responsiveOverrides,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      layoutMode: layoutMode ?? this.layoutMode,
      gap: gap ?? this.gap,
      paddingTop: paddingTop ?? this.paddingTop,
      paddingRight: paddingRight ?? this.paddingRight,
      paddingBottom: paddingBottom ?? this.paddingBottom,
      paddingLeft: paddingLeft ?? this.paddingLeft,
      marginTop: marginTop ?? this.marginTop,
      marginRight: marginRight ?? this.marginRight,
      marginBottom: marginBottom ?? this.marginBottom,
      marginLeft: marginLeft ?? this.marginLeft,
      gridColumns: gridColumns ?? this.gridColumns,
      mainAlignment: mainAlignment ?? this.mainAlignment,
      crossAlignment: crossAlignment ?? this.crossAlignment,
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
        'backplatePath': backplatePath,
        'backplateEnabled': backplateEnabled,
        'backplateFit': backplateFit,
        'maskPath': maskPath,
        'maskEnabled': maskEnabled,
        'backgroundColor': backgroundColor,
        'foregroundColor': foregroundColor,
        'borderColor': borderColor,
        'borderWidth': borderWidth,
        'borderRadius': borderRadius,
        'opacity': opacity,
        'fontSize': fontSize,
        'fontWeight': fontWeight,
        'fontFamily': fontFamily,
        'fontPath': fontPath,
        'letterSpacing': letterSpacing,
        'lineHeight': lineHeight,
        'textAlign': textAlign,
        'textMode': textMode,
        'textHighlightColor': textHighlightColor,
        'textStrokeColor': textStrokeColor,
        'textStrokeWidth': textStrokeWidth,
        'transition': transition,
        'transitionEnabled': transitionEnabled,
        'transitionDurationMs': transitionDurationMs,
        'pressScaleEnabled': pressScaleEnabled,
        'pressScale': pressScale,
        'anchorX': anchorX,
        'anchorY': anchorY,
        'imageFit': imageFit,
        'imagePositionX': imagePositionX,
        'imagePositionY': imagePositionY,
        'imageScale': imageScale,
        'widthMode': widthMode.name,
        'heightMode': heightMode.name,
        'widthPercent': widthPercent,
        'heightPercent': heightPercent,
        'minWidth': minWidth,
        'maxWidth': maxWidth,
        'minHeight': minHeight,
        'maxHeight': maxHeight,
        if (responsiveOverrides.isNotEmpty)
          'responsiveOverrides': {
            for (final entry in responsiveOverrides.entries)
              entry.key.name: entry.value.toJson(),
          },
        'parentId': parentId,
        'layoutMode': layoutMode.name,
        'gap': gap,
        'paddingTop': paddingTop,
        'paddingRight': paddingRight,
        'paddingBottom': paddingBottom,
        'paddingLeft': paddingLeft,
        'marginTop': marginTop,
        'marginRight': marginRight,
        'marginBottom': marginBottom,
        'marginLeft': marginLeft,
        'gridColumns': gridColumns,
        'mainAlignment': mainAlignment.name,
        'crossAlignment': crossAlignment.name,
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
        backplatePath: json['backplatePath'] as String?,
        backplateEnabled: json['backplateEnabled'] as bool? ?? false,
        backplateFit: json['backplateFit'] as String? ?? 'cover',
        maskPath: json['maskPath'] as String?,
        maskEnabled: json['maskEnabled'] as bool? ?? false,
        backgroundColor: json['backgroundColor'] as int?,
        foregroundColor: json['foregroundColor'] as int? ?? 0xff202020,
        borderColor: json['borderColor'] as int?,
        borderWidth: (json['borderWidth'] as num?)?.toDouble() ?? 0,
        borderRadius: (json['borderRadius'] as num?)?.toDouble() ?? 0,
        opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 22,
        fontWeight: (json['fontWeight'] as num?)?.toInt() ?? 400,
        fontFamily: json['fontFamily'] as String? ?? 'Arial',
        fontPath: json['fontPath'] as String?,
        letterSpacing: (json['letterSpacing'] as num?)?.toDouble() ?? 0,
        lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.2,
        textAlign: json['textAlign'] as String? ?? 'left',
        textMode: json['textMode'] as String? ?? 'wrap',
        textHighlightColor: json['textHighlightColor'] as int?,
        textStrokeColor: json['textStrokeColor'] as int?,
        textStrokeWidth: (json['textStrokeWidth'] as num?)?.toDouble() ?? 0,
        transition: json['transition'] as String? ?? 'none',
        transitionEnabled: json['transitionEnabled'] as bool? ?? false,
        transitionDurationMs: (json['transitionDurationMs'] as num?)?.toInt() ?? 420,
        pressScaleEnabled: json['pressScaleEnabled'] as bool? ?? false,
        pressScale: (json['pressScale'] as num?)?.toDouble() ?? .96,
        anchorX: json['anchorX'] as String? ?? 'left',
        anchorY: json['anchorY'] as String? ?? 'top',
        imageFit: json['imageFit'] as String? ?? 'cover',
        imagePositionX:
            (json['imagePositionX'] as num?)?.toDouble() ?? 0,
        imagePositionY:
            (json['imagePositionY'] as num?)?.toDouble() ?? 0,
        imageScale: (json['imageScale'] as num?)?.toDouble() ?? 1,
        widthMode: WebSizeMode.values.byName(
          json['widthMode'] as String? ?? WebSizeMode.fixed.name,
        ),
        heightMode: WebSizeMode.values.byName(
          json['heightMode'] as String? ?? WebSizeMode.fixed.name,
        ),
        widthPercent: (json['widthPercent'] as num?)?.toDouble() ?? 1,
        heightPercent: (json['heightPercent'] as num?)?.toDouble() ?? 1,
        minWidth: (json['minWidth'] as num?)?.toDouble(),
        maxWidth: (json['maxWidth'] as num?)?.toDouble(),
        minHeight: (json['minHeight'] as num?)?.toDouble(),
        maxHeight: (json['maxHeight'] as num?)?.toDouble(),
        responsiveOverrides: {
          for (final entry
              in ((json['responsiveOverrides'] as Map?) ?? const {}).entries)
            WebBreakpoint.values.byName(entry.key as String):
                WebElementBreakpointOverride.fromJson(
              Map<String, Object?>.from(entry.value as Map),
            ),
        },
        parentId: json['parentId'] as String?,
        layoutMode: WebLayoutMode.values.byName(
          json['layoutMode'] as String? ?? WebLayoutMode.free.name,
        ),
        gap: (json['gap'] as num?)?.toDouble() ?? 16,
        paddingTop: (json['paddingTop'] as num?)?.toDouble() ?? 0,
        paddingRight: (json['paddingRight'] as num?)?.toDouble() ?? 0,
        paddingBottom: (json['paddingBottom'] as num?)?.toDouble() ?? 0,
        paddingLeft: (json['paddingLeft'] as num?)?.toDouble() ?? 0,
        marginTop: (json['marginTop'] as num?)?.toDouble() ?? 0,
        marginRight: (json['marginRight'] as num?)?.toDouble() ?? 0,
        marginBottom: (json['marginBottom'] as num?)?.toDouble() ?? 0,
        marginLeft: (json['marginLeft'] as num?)?.toDouble() ?? 0,
        gridColumns: (json['gridColumns'] as num?)?.toInt() ?? 2,
        mainAlignment: WebMainAlignment.values.byName(
          json['mainAlignment'] as String? ?? WebMainAlignment.start.name,
        ),
        crossAlignment: WebCrossAlignment.values.byName(
          json['crossAlignment'] as String? ?? WebCrossAlignment.start.name,
        ),
      );
}
