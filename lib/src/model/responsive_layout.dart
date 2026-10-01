import 'dart:math' as math;

import 'responsive.dart';
import 'web_element.dart';
import 'web_page.dart';

class ResponsiveLayoutResolver {
  const ResponsiveLayoutResolver._();

  static WebElementBreakpointOverride effectiveOverride(
    WebElement element,
    WebBreakpoint breakpoint,
  ) {
    var result = const WebElementBreakpointOverride();
    if (breakpoint == WebBreakpoint.desktop) return result;

    final tablet = element.responsiveOverrides[WebBreakpoint.tablet];
    if (tablet != null) result = result.merge(tablet);

    if (breakpoint == WebBreakpoint.mobile) {
      final mobile = element.responsiveOverrides[WebBreakpoint.mobile];
      if (mobile != null) result = result.merge(mobile);
    }
    return result;
  }

  static WebElement resolve(
    WebElement element,
    WebPage page,
    WebBreakpoint breakpoint,
  ) {
    final targetWidth = breakpoint == WebBreakpoint.desktop
        ? page.width
        : breakpoint.previewWidth;
    final targetHeight = page.height;
    final override = effectiveOverride(element, breakpoint);

    final widthMode = override.widthMode ?? element.widthMode;
    final heightMode = override.heightMode ?? element.heightMode;
    final widthPercent = override.widthPercent ?? element.widthPercent;
    final heightPercent = override.heightPercent ?? element.heightPercent;
    final anchorX = override.anchorX ?? element.anchorX;
    final anchorY = override.anchorY ?? element.anchorY;

    final baseRight =
        math.max(0.0, page.width - (element.x + element.width));
    final baseBottom =
        math.max(0.0, page.height - (element.y + element.height));

    final explicitX = override.x;
    final explicitY = override.y;
    final rawWidth = override.width ?? element.width;
    final rawHeight = override.height ?? element.height;

    var resolvedWidth = switch (widthMode) {
      WebSizeMode.fixed => rawWidth,
      WebSizeMode.percent => targetWidth * widthPercent,
      WebSizeMode.fill => math.max(
          32.0,
          targetWidth - (explicitX ?? element.x) - baseRight,
        ).toDouble(),
      WebSizeMode.hug => _hugWidth(element, targetWidth),
    };

    var resolvedHeight = switch (heightMode) {
      WebSizeMode.fixed => rawHeight,
      WebSizeMode.percent => targetHeight * heightPercent,
      WebSizeMode.fill => math.max(
          24.0,
          targetHeight - (explicitY ?? element.y) - baseBottom,
        ).toDouble(),
      WebSizeMode.hug => _hugHeight(element),
    };

    final minWidth = override.minWidth ?? element.minWidth;
    final maxWidth = override.maxWidth ?? element.maxWidth;
    final minHeight = override.minHeight ?? element.minHeight;
    final maxHeight = override.maxHeight ?? element.maxHeight;

    if (minWidth != null) resolvedWidth = math.max(resolvedWidth, minWidth);
    if (maxWidth != null) resolvedWidth = math.min(resolvedWidth, maxWidth);
    if (minHeight != null) resolvedHeight = math.max(resolvedHeight, minHeight);
    if (maxHeight != null) resolvedHeight = math.min(resolvedHeight, maxHeight);

    final resolvedX = explicitX ??
        switch (widthMode) {
          WebSizeMode.fill => element.x,
          _ => switch (anchorX) {
              'center' => targetWidth / 2 +
                  (element.x + element.width / 2 - page.width / 2) -
                  resolvedWidth / 2,
              'right' => targetWidth - baseRight - resolvedWidth,
              _ => element.x,
            },
        };

    final resolvedY = explicitY ??
        switch (heightMode) {
          WebSizeMode.fill => element.y,
          _ => switch (anchorY) {
              'center' => targetHeight / 2 +
                  (element.y + element.height / 2 - page.height / 2) -
                  resolvedHeight / 2,
              'bottom' => targetHeight - baseBottom - resolvedHeight,
              _ => element.y,
            },
        };

    return element.copyWith(
      x: resolvedX,
      y: resolvedY,
      width: resolvedWidth,
      height: resolvedHeight,
      widthMode: widthMode,
      heightMode: heightMode,
      widthPercent: widthPercent,
      heightPercent: heightPercent,
      minWidth: minWidth,
      clearMinWidth: minWidth == null,
      maxWidth: maxWidth,
      clearMaxWidth: maxWidth == null,
      minHeight: minHeight,
      clearMinHeight: minHeight == null,
      maxHeight: maxHeight,
      clearMaxHeight: maxHeight == null,
      anchorX: anchorX,
      anchorY: anchorY,
      visible: override.visible ?? element.visible,
    );
  }

  static double _hugWidth(WebElement element, double availableWidth) {
    if (element.type == WebElementType.image ||
        element.type == WebElementType.container ||
        element.type == WebElementType.section ||
        element.type == WebElementType.card) {
      return math.min(element.width, availableWidth);
    }
    final textWidth =
        element.text.runes.length * element.fontSize * .58 +
        math.max(20.0, element.letterSpacing * element.text.length) +
        24;
    return textWidth.clamp(32.0, availableWidth).toDouble();
  }

  static double _hugHeight(WebElement element) {
    if (element.type == WebElementType.image ||
        element.type == WebElementType.container ||
        element.type == WebElementType.section ||
        element.type == WebElementType.card) {
      return element.height;
    }
    final lines = math.max(1, '\n'.allMatches(element.text).length + 1);
    return math.max(
      24.0,
      lines * element.fontSize * element.lineHeight + 20,
    ).toDouble();
  }
}
