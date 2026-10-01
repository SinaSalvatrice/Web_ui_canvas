enum WebBreakpoint {
  desktop('Desktop', 1440, null),
  tablet('Tablet', 900, 1024),
  mobile('Mobile', 390, 600);

  const WebBreakpoint(this.label, this.previewWidth, this.maxViewportWidth);

  final String label;
  final double previewWidth;
  final double? maxViewportWidth;
}

enum WebSizeMode {
  fixed('Fixed'),
  percent('Percent'),
  fill('Fill'),
  hug('Hug');

  const WebSizeMode(this.label);

  final String label;
}

class WebElementBreakpointOverride {
  const WebElementBreakpointOverride({
    this.x,
    this.y,
    this.width,
    this.height,
    this.widthMode,
    this.heightMode,
    this.widthPercent,
    this.heightPercent,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    this.anchorX,
    this.anchorY,
    this.visible,
  });

  final double? x;
  final double? y;
  final double? width;
  final double? height;
  final WebSizeMode? widthMode;
  final WebSizeMode? heightMode;
  final double? widthPercent;
  final double? heightPercent;
  final double? minWidth;
  final double? maxWidth;
  final double? minHeight;
  final double? maxHeight;
  final String? anchorX;
  final String? anchorY;
  final bool? visible;

  bool get isEmpty =>
      x == null &&
      y == null &&
      width == null &&
      height == null &&
      widthMode == null &&
      heightMode == null &&
      widthPercent == null &&
      heightPercent == null &&
      minWidth == null &&
      maxWidth == null &&
      minHeight == null &&
      maxHeight == null &&
      anchorX == null &&
      anchorY == null &&
      visible == null;

  WebElementBreakpointOverride copyWith({
    double? x,
    bool clearX = false,
    double? y,
    bool clearY = false,
    double? width,
    bool clearWidth = false,
    double? height,
    bool clearHeight = false,
    WebSizeMode? widthMode,
    bool clearWidthMode = false,
    WebSizeMode? heightMode,
    bool clearHeightMode = false,
    double? widthPercent,
    bool clearWidthPercent = false,
    double? heightPercent,
    bool clearHeightPercent = false,
    double? minWidth,
    bool clearMinWidth = false,
    double? maxWidth,
    bool clearMaxWidth = false,
    double? minHeight,
    bool clearMinHeight = false,
    double? maxHeight,
    bool clearMaxHeight = false,
    String? anchorX,
    bool clearAnchorX = false,
    String? anchorY,
    bool clearAnchorY = false,
    bool? visible,
    bool clearVisible = false,
  }) {
    return WebElementBreakpointOverride(
      x: clearX ? null : (x ?? this.x),
      y: clearY ? null : (y ?? this.y),
      width: clearWidth ? null : (width ?? this.width),
      height: clearHeight ? null : (height ?? this.height),
      widthMode: clearWidthMode ? null : (widthMode ?? this.widthMode),
      heightMode: clearHeightMode ? null : (heightMode ?? this.heightMode),
      widthPercent:
          clearWidthPercent ? null : (widthPercent ?? this.widthPercent),
      heightPercent:
          clearHeightPercent ? null : (heightPercent ?? this.heightPercent),
      minWidth: clearMinWidth ? null : (minWidth ?? this.minWidth),
      maxWidth: clearMaxWidth ? null : (maxWidth ?? this.maxWidth),
      minHeight: clearMinHeight ? null : (minHeight ?? this.minHeight),
      maxHeight: clearMaxHeight ? null : (maxHeight ?? this.maxHeight),
      anchorX: clearAnchorX ? null : (anchorX ?? this.anchorX),
      anchorY: clearAnchorY ? null : (anchorY ?? this.anchorY),
      visible: clearVisible ? null : (visible ?? this.visible),
    );
  }

  WebElementBreakpointOverride merge(WebElementBreakpointOverride other) {
    return WebElementBreakpointOverride(
      x: other.x ?? x,
      y: other.y ?? y,
      width: other.width ?? width,
      height: other.height ?? height,
      widthMode: other.widthMode ?? widthMode,
      heightMode: other.heightMode ?? heightMode,
      widthPercent: other.widthPercent ?? widthPercent,
      heightPercent: other.heightPercent ?? heightPercent,
      minWidth: other.minWidth ?? minWidth,
      maxWidth: other.maxWidth ?? maxWidth,
      minHeight: other.minHeight ?? minHeight,
      maxHeight: other.maxHeight ?? maxHeight,
      anchorX: other.anchorX ?? anchorX,
      anchorY: other.anchorY ?? anchorY,
      visible: other.visible ?? visible,
    );
  }

  Map<String, Object?> toJson() => {
        if (x != null) 'x': x,
        if (y != null) 'y': y,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (widthMode != null) 'widthMode': widthMode!.name,
        if (heightMode != null) 'heightMode': heightMode!.name,
        if (widthPercent != null) 'widthPercent': widthPercent,
        if (heightPercent != null) 'heightPercent': heightPercent,
        if (minWidth != null) 'minWidth': minWidth,
        if (maxWidth != null) 'maxWidth': maxWidth,
        if (minHeight != null) 'minHeight': minHeight,
        if (maxHeight != null) 'maxHeight': maxHeight,
        if (anchorX != null) 'anchorX': anchorX,
        if (anchorY != null) 'anchorY': anchorY,
        if (visible != null) 'visible': visible,
      };

  factory WebElementBreakpointOverride.fromJson(Map<String, Object?> json) {
    WebSizeMode? mode(String key) {
      final raw = json[key] as String?;
      return raw == null ? null : WebSizeMode.values.byName(raw);
    }

    return WebElementBreakpointOverride(
      x: (json['x'] as num?)?.toDouble(),
      y: (json['y'] as num?)?.toDouble(),
      width: (json['width'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      widthMode: mode('widthMode'),
      heightMode: mode('heightMode'),
      widthPercent: (json['widthPercent'] as num?)?.toDouble(),
      heightPercent: (json['heightPercent'] as num?)?.toDouble(),
      minWidth: (json['minWidth'] as num?)?.toDouble(),
      maxWidth: (json['maxWidth'] as num?)?.toDouble(),
      minHeight: (json['minHeight'] as num?)?.toDouble(),
      maxHeight: (json['maxHeight'] as num?)?.toDouble(),
      anchorX: json['anchorX'] as String?,
      anchorY: json['anchorY'] as String?,
      visible: json['visible'] as bool?,
    );
  }
}
