import 'dart:math' as math;

import 'layout.dart';
import 'responsive.dart';
import 'responsive_layout.dart';
import 'web_element.dart';
import 'web_page.dart';

class PageLayoutEngine {
  const PageLayoutEngine._();

  static List<WebElement> resolvePage(
    WebPage page,
    WebBreakpoint breakpoint,
  ) {
    final rawById = {
      for (final element in page.elements) element.id: element,
    };
    final resolved = {
      for (final element in page.elements)
        element.id: ResponsiveLayoutResolver.resolve(
          element,
          page,
          breakpoint,
        ),
    };

    final existingIds = rawById.keys.toSet();
    final roots = page.elements.where(
      (element) =>
          element.parentId == null || !existingIds.contains(element.parentId),
    );

    final visited = <String>{};
    for (final root in roots) {
      _layoutDescendants(
        page,
        breakpoint,
        rawById,
        resolved,
        root.id,
        visited,
      );
    }

    for (final element in page.elements) {
      if (!visited.contains(element.id)) {
        _layoutDescendants(
          page,
          breakpoint,
          rawById,
          resolved,
          element.id,
          visited,
        );
      }
    }

    return page.elements
        .map((element) => resolved[element.id] ?? element)
        .toList(growable: false);
  }

  static void _layoutDescendants(
    WebPage page,
    WebBreakpoint breakpoint,
    Map<String, WebElement> rawById,
    Map<String, WebElement> resolved,
    String parentId,
    Set<String> visited,
  ) {
    if (!visited.add(parentId)) return;

    final rawParent = rawById[parentId];
    final parent = resolved[parentId];
    if (rawParent == null || parent == null) return;

    final children = page.elements
        .where((element) => element.parentId == parentId)
        .toList(growable: false);
    if (children.isEmpty) return;

    final contentLeft = parent.x + rawParent.paddingLeft;
    final contentTop = parent.y + rawParent.paddingTop;
    final contentWidth = math.max(
      0.0,
      parent.width - rawParent.paddingLeft - rawParent.paddingRight,
    );
    final contentHeight = math.max(
      0.0,
      parent.height - rawParent.paddingTop - rawParent.paddingBottom,
    );

    switch (rawParent.layoutMode) {
      case WebLayoutMode.free:
        for (final rawChild in children) {
          final child = _localResolvedChild(
            rawChild,
            page,
            breakpoint,
            contentWidth,
            contentHeight,
          );
          resolved[rawChild.id] = child.copyWith(
            x: contentLeft + child.x + rawChild.marginLeft,
            y: contentTop + child.y + rawChild.marginTop,
          );
        }
        break;
      case WebLayoutMode.row:
        _layoutRow(
          rawParent,
          children,
          page,
          breakpoint,
          resolved,
          contentLeft,
          contentTop,
          contentWidth,
          contentHeight,
        );
        break;
      case WebLayoutMode.column:
        _layoutColumn(
          rawParent,
          children,
          page,
          breakpoint,
          resolved,
          contentLeft,
          contentTop,
          contentWidth,
          contentHeight,
        );
        break;
      case WebLayoutMode.grid:
        _layoutGrid(
          rawParent,
          children,
          page,
          breakpoint,
          resolved,
          contentLeft,
          contentTop,
          contentWidth,
          contentHeight,
        );
        break;
      case WebLayoutMode.flow:
        _layoutFlow(
          rawParent,
          children,
          page,
          breakpoint,
          resolved,
          contentLeft,
          contentTop,
          contentWidth,
          contentHeight,
        );
        break;
    }

    for (final child in children) {
      _layoutDescendants(
        page,
        breakpoint,
        rawById,
        resolved,
        child.id,
        visited,
      );
    }
  }

  static WebElement _localResolvedChild(
    WebElement raw,
    WebPage page,
    WebBreakpoint breakpoint,
    double contentWidth,
    double contentHeight,
  ) {
    final global = ResponsiveLayoutResolver.resolve(raw, page, breakpoint);
    final override =
        ResponsiveLayoutResolver.effectiveOverride(raw, breakpoint);

    final widthMode = override.widthMode ?? raw.widthMode;
    final heightMode = override.heightMode ?? raw.heightMode;
    final widthPercent = override.widthPercent ?? raw.widthPercent;
    final heightPercent = override.heightPercent ?? raw.heightPercent;

    var width = switch (widthMode) {
      WebSizeMode.percent => contentWidth * widthPercent,
      WebSizeMode.fill => contentWidth - raw.marginLeft - raw.marginRight,
      _ => global.width,
    };
    var height = switch (heightMode) {
      WebSizeMode.percent => contentHeight * heightPercent,
      WebSizeMode.fill => contentHeight - raw.marginTop - raw.marginBottom,
      _ => global.height,
    };

    final minWidth = override.minWidth ?? raw.minWidth;
    final maxWidth = override.maxWidth ?? raw.maxWidth;
    final minHeight = override.minHeight ?? raw.minHeight;
    final maxHeight = override.maxHeight ?? raw.maxHeight;

    if (minWidth != null) width = math.max(width, minWidth);
    if (maxWidth != null) width = math.min(width, maxWidth);
    if (minHeight != null) height = math.max(height, minHeight);
    if (maxHeight != null) height = math.min(height, maxHeight);

    return global.copyWith(
      x: override.x ?? raw.x,
      y: override.y ?? raw.y,
      width: math.max(0.0, width).toDouble(),
      height: math.max(0.0, height).toDouble(),
    );
  }

  static void _layoutRow(
    WebElement parent,
    List<WebElement> children,
    WebPage page,
    WebBreakpoint breakpoint,
    Map<String, WebElement> resolved,
    double left,
    double top,
    double width,
    double height,
  ) {
    final items = children
        .map(
          (raw) => (
            raw: raw,
            element: _localResolvedChild(
              raw,
              page,
              breakpoint,
              width,
              height,
            ),
          ),
        )
        .toList();

    final fill = items
        .where((item) => item.element.widthMode == WebSizeMode.fill)
        .length;
    final margins = items.fold<double>(
      0,
      (sum, item) =>
          sum + item.raw.marginLeft + item.raw.marginRight,
    );
    final fixed = items
        .where((item) => item.element.widthMode != WebSizeMode.fill)
        .fold<double>(0, (sum, item) => sum + item.element.width);
    var gap = parent.gap;
    final baseGaps = gap * math.max(0, items.length - 1);
    final remaining = math.max(0.0, width - margins - fixed - baseGaps);
    final fillWidth = fill == 0 ? 0.0 : remaining / fill;

    var occupied = margins + fixed + baseGaps + fillWidth * fill;
    var startOffset = 0.0;
    final free = math.max(0.0, width - occupied);
    switch (parent.mainAlignment) {
      case WebMainAlignment.center:
        startOffset = free / 2;
        break;
      case WebMainAlignment.end:
        startOffset = free;
        break;
      case WebMainAlignment.spaceBetween:
        if (items.length > 1 && fill == 0) {
          gap += free / (items.length - 1);
          occupied = width;
        }
        break;
      case WebMainAlignment.start:
        break;
    }

    var cursor = left + startOffset;
    for (final item in items) {
      final raw = item.raw;
      var child = item.element;
      final childWidth =
          child.widthMode == WebSizeMode.fill ? fillWidth : child.width;
      var childHeight = child.height;

      if (parent.crossAlignment == WebCrossAlignment.stretch ||
          child.heightMode == WebSizeMode.fill) {
        childHeight =
            math.max(0.0, height - raw.marginTop - raw.marginBottom);
      }

      final y = switch (parent.crossAlignment) {
        WebCrossAlignment.center =>
          top + (height - childHeight) / 2 +
              (raw.marginTop - raw.marginBottom) / 2,
        WebCrossAlignment.end =>
          top + height - childHeight - raw.marginBottom,
        WebCrossAlignment.stretch || WebCrossAlignment.start =>
          top + raw.marginTop,
      };

      cursor += raw.marginLeft;
      child = child.copyWith(
        x: cursor,
        y: y,
        width: math.max(0.0, childWidth).toDouble(),
        height: math.max(0.0, childHeight).toDouble(),
      );
      resolved[raw.id] = child;
      cursor += childWidth + raw.marginRight + gap;
    }
  }

  static void _layoutColumn(
    WebElement parent,
    List<WebElement> children,
    WebPage page,
    WebBreakpoint breakpoint,
    Map<String, WebElement> resolved,
    double left,
    double top,
    double width,
    double height,
  ) {
    final items = children
        .map(
          (raw) => (
            raw: raw,
            element: _localResolvedChild(
              raw,
              page,
              breakpoint,
              width,
              height,
            ),
          ),
        )
        .toList();

    final fill = items
        .where((item) => item.element.heightMode == WebSizeMode.fill)
        .length;
    final margins = items.fold<double>(
      0,
      (sum, item) =>
          sum + item.raw.marginTop + item.raw.marginBottom,
    );
    final fixed = items
        .where((item) => item.element.heightMode != WebSizeMode.fill)
        .fold<double>(0, (sum, item) => sum + item.element.height);
    var gap = parent.gap;
    final baseGaps = gap * math.max(0, items.length - 1);
    final remaining = math.max(0.0, height - margins - fixed - baseGaps);
    final fillHeight = fill == 0 ? 0.0 : remaining / fill;

    final occupied = margins + fixed + baseGaps + fillHeight * fill;
    var startOffset = 0.0;
    final free = math.max(0.0, height - occupied);
    switch (parent.mainAlignment) {
      case WebMainAlignment.center:
        startOffset = free / 2;
        break;
      case WebMainAlignment.end:
        startOffset = free;
        break;
      case WebMainAlignment.spaceBetween:
        if (items.length > 1 && fill == 0) {
          gap += free / (items.length - 1);
        }
        break;
      case WebMainAlignment.start:
        break;
    }

    var cursor = top + startOffset;
    for (final item in items) {
      final raw = item.raw;
      var child = item.element;
      final childHeight =
          child.heightMode == WebSizeMode.fill ? fillHeight : child.height;
      var childWidth = child.width;

      if (parent.crossAlignment == WebCrossAlignment.stretch ||
          child.widthMode == WebSizeMode.fill) {
        childWidth =
            math.max(0.0, width - raw.marginLeft - raw.marginRight);
      }

      final x = switch (parent.crossAlignment) {
        WebCrossAlignment.center =>
          left + (width - childWidth) / 2 +
              (raw.marginLeft - raw.marginRight) / 2,
        WebCrossAlignment.end =>
          left + width - childWidth - raw.marginRight,
        WebCrossAlignment.stretch || WebCrossAlignment.start =>
          left + raw.marginLeft,
      };

      cursor += raw.marginTop;
      child = child.copyWith(
        x: x,
        y: cursor,
        width: math.max(0.0, childWidth).toDouble(),
        height: math.max(0.0, childHeight).toDouble(),
      );
      resolved[raw.id] = child;
      cursor += childHeight + raw.marginBottom + gap;
    }
  }

  static void _layoutGrid(
    WebElement parent,
    List<WebElement> children,
    WebPage page,
    WebBreakpoint breakpoint,
    Map<String, WebElement> resolved,
    double left,
    double top,
    double width,
    double height,
  ) {
    final columns = parent.gridColumns.clamp(1, 12).toInt();
    final cellWidth = math.max(
      0.0,
      (width - parent.gap * (columns - 1)) / columns,
    );
    var y = top;

    for (var rowStart = 0;
        rowStart < children.length;
        rowStart += columns) {
      final row = children.skip(rowStart).take(columns).toList();
      final rowItems = <({WebElement raw, WebElement element})>[];
      var rowHeight = 0.0;

      for (final raw in row) {
        var child = _localResolvedChild(
          raw,
          page,
          breakpoint,
          cellWidth,
          height,
        );
        final available =
            math.max(0.0, cellWidth - raw.marginLeft - raw.marginRight);
        if (child.widthMode == WebSizeMode.fill ||
            parent.crossAlignment == WebCrossAlignment.stretch) {
          child = child.copyWith(width: available);
        }
        rowHeight = math.max(
          rowHeight,
          child.height + raw.marginTop + raw.marginBottom,
        );
        rowItems.add((raw: raw, element: child));
      }

      for (var column = 0; column < rowItems.length; column++) {
        final item = rowItems[column];
        final cellLeft = left + column * (cellWidth + parent.gap);
        final available =
            math.max(0.0, cellWidth - item.raw.marginLeft - item.raw.marginRight);
        final x = switch (parent.crossAlignment) {
          WebCrossAlignment.center =>
            cellLeft + (cellWidth - item.element.width) / 2,
          WebCrossAlignment.end =>
            cellLeft + cellWidth - item.element.width - item.raw.marginRight,
          WebCrossAlignment.start || WebCrossAlignment.stretch =>
            cellLeft + item.raw.marginLeft,
        };
        resolved[item.raw.id] = item.element.copyWith(
          x: x,
          y: y + item.raw.marginTop,
          width: parent.crossAlignment == WebCrossAlignment.stretch
              ? available
              : item.element.width,
        );
      }

      y += rowHeight + parent.gap;
    }
  }

  static void _layoutFlow(
    WebElement parent,
    List<WebElement> children,
    WebPage page,
    WebBreakpoint breakpoint,
    Map<String, WebElement> resolved,
    double left,
    double top,
    double width,
    double height,
  ) {
    var x = left;
    var y = top;
    var rowHeight = 0.0;

    for (final raw in children) {
      final child = _localResolvedChild(
        raw,
        page,
        breakpoint,
        width,
        height,
      );
      final totalWidth =
          raw.marginLeft + child.width + raw.marginRight;
      final totalHeight =
          raw.marginTop + child.height + raw.marginBottom;

      if (x > left && x + totalWidth > left + width) {
        x = left;
        y += rowHeight + parent.gap;
        rowHeight = 0;
      }

      resolved[raw.id] = child.copyWith(
        x: x + raw.marginLeft,
        y: y + raw.marginTop,
      );
      x += totalWidth + parent.gap;
      rowHeight = math.max(rowHeight, totalHeight);
    }
  }
}
