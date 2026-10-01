import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../model/web_element.dart';
import '../model/web_page.dart';
import '../model/web_project.dart';
import '../model/layout.dart';
import '../model/page_layout_engine.dart';
import '../model/responsive.dart';
import '../model/responsive_layout.dart';

enum SelectionAlignment {
  left,
  horizontalCenter,
  right,
  top,
  verticalCenter,
  bottom,
}

enum SelectionDistribution {
  horizontal,
  vertical,
}

class EditorController extends ChangeNotifier {
  EditorController([WebProject? project]) : _project = project ?? WebProject.empty() {
    _history.add(_project);
  }

  WebProject _project;
  final List<WebProject> _history = [];
  int _historyIndex = 0;
  int _nextId = 1;
  String? _selectedId;
  final Set<String> _selectedIds = <String>{};
  List<WebElement> _clipboard = const <WebElement>[];
  int _pasteGeneration = 0;
  String? _cropElementId;
  WebBreakpoint _activeBreakpoint = WebBreakpoint.desktop;

  bool gridEnabled = true;
  bool snapEnabled = false;
  double gridStep = 16;

  WebProject get project => _project;
  String get projectFingerprint => jsonEncode(_project.toJson());
  String? get selectedId => _selectedId;
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);
  bool get hasSelection => _selectedIds.isNotEmpty;
  bool get canPaste => _clipboard.isNotEmpty;
  String? get cropElementId => _cropElementId;
  bool get isCropMode => _cropElementId != null;
  WebBreakpoint get activeBreakpoint => _activeBreakpoint;
  double get viewportWidth => _activeBreakpoint == WebBreakpoint.desktop
      ? activePage.width
      : _activeBreakpoint.previewWidth;
  double get viewportHeight => activePage.height;
  bool get canUndo => _historyIndex > 0;
  bool get canRedo => _historyIndex < _history.length - 1;

  WebPage get activePage => _project.pages.firstWhere(
        (page) => page.id == _project.activePageId,
      );

  WebElement? get selectedElement {
    final id = _selectedId;
    if (id == null) return null;
    return _elementById(id);
  }

  List<WebElement> get selectedElements => activePage.elements
      .where((element) => _selectedIds.contains(element.id))
      .toList(growable: false);

  List<WebElement> get resolvedPageElements =>
      PageLayoutEngine.resolvePage(activePage, _activeBreakpoint);

  WebElement? get resolvedSelectedElement {
    final id = _selectedId;
    if (id == null) return null;
    for (final element in resolvedPageElements) {
      if (element.id == id) return element;
    }
    return null;
  }

  List<WebElement> get resolvedSelectedElements {
    final ids = _selectedIds;
    return resolvedPageElements
        .where((element) => ids.contains(element.id))
        .toList(growable: false);
  }

  void replaceProject(WebProject project) {
    _project = project;
    _clearSelectionState();
    _cropElementId = null;
    _clipboard = const <WebElement>[];
    _pasteGeneration = 0;
    _activeBreakpoint = WebBreakpoint.desktop;
    _nextId = _project.pages.expand((page) => page.elements).length + 1;
    _history
      ..clear()
      ..add(project);
    _historyIndex = 0;
    notifyListeners();
  }

  void setActiveBreakpoint(WebBreakpoint breakpoint) {
    if (_activeBreakpoint == breakpoint) return;
    _activeBreakpoint = breakpoint;
    _cropElementId = null;
    notifyListeners();
  }

  WebElementBreakpointOverride effectiveOverride(
    WebElement element, [
    WebBreakpoint? breakpoint,
  ]) =>
      ResponsiveLayoutResolver.effectiveOverride(
        element,
        breakpoint ?? _activeBreakpoint,
      );

  WebElement resolveElement(
    WebElement element, {
    WebBreakpoint? breakpoint,
  }) =>
      ResponsiveLayoutResolver.resolve(
        element,
        activePage,
        breakpoint ?? _activeBreakpoint,
      );

  void resetActiveBreakpointOverrides(String id) {
    if (_activeBreakpoint == WebBreakpoint.desktop) return;
    final element = _elementById(id);
    if (element == null) return;
    final map = Map<WebBreakpoint, WebElementBreakpointOverride>.from(
      element.responsiveOverrides,
    )..remove(_activeBreakpoint);
    updateElement(element.copyWith(responsiveOverrides: map));
  }

  void setAnchorX(String id, String value) {
    final raw = _elementById(id);
    if (raw == null) return;
    if (_activeBreakpoint == WebBreakpoint.desktop) {
      updateElement(raw.copyWith(anchorX: value));
      return;
    }
    _updateBreakpointOverride(
      raw,
      (override) => override.copyWith(anchorX: value),
    );
  }

  void setAnchorY(String id, String value) {
    final raw = _elementById(id);
    if (raw == null) return;
    if (_activeBreakpoint == WebBreakpoint.desktop) {
      updateElement(raw.copyWith(anchorY: value));
      return;
    }
    _updateBreakpointOverride(
      raw,
      (override) => override.copyWith(anchorY: value),
    );
  }

  void setWidthMode(String id, WebSizeMode mode) {
    final raw = _elementById(id);
    if (raw == null) return;
    final resolved = resolveElement(raw);
    if (_activeBreakpoint == WebBreakpoint.desktop) {
      updateElement(
        raw.copyWith(
          widthMode: mode,
          widthPercent: mode == WebSizeMode.percent
              ? resolved.width / math.max(1.0, viewportWidth)
              : raw.widthPercent,
        ),
      );
      return;
    }
    _updateBreakpointOverride(
      raw,
      (override) => override.copyWith(
        widthMode: mode,
        widthPercent: mode == WebSizeMode.percent
            ? resolved.width / math.max(1.0, viewportWidth)
            : null,
      ),
    );
  }

  void setHeightMode(String id, WebSizeMode mode) {
    final raw = _elementById(id);
    if (raw == null) return;
    final resolved = resolveElement(raw);
    if (_activeBreakpoint == WebBreakpoint.desktop) {
      updateElement(
        raw.copyWith(
          heightMode: mode,
          heightPercent: mode == WebSizeMode.percent
              ? resolved.height / math.max(1.0, viewportHeight)
              : raw.heightPercent,
        ),
      );
      return;
    }
    _updateBreakpointOverride(
      raw,
      (override) => override.copyWith(
        heightMode: mode,
        heightPercent: mode == WebSizeMode.percent
            ? resolved.height / math.max(1.0, viewportHeight)
            : null,
      ),
    );
  }

  void setWidthPercent(String id, double value) {
    final raw = _elementById(id);
    if (raw == null) return;
    final percent = value.clamp(.01, 2.0).toDouble();
    if (_activeBreakpoint == WebBreakpoint.desktop) {
      updateElement(raw.copyWith(widthPercent: percent));
    } else {
      _updateBreakpointOverride(
        raw,
        (override) => override.copyWith(widthPercent: percent),
      );
    }
  }

  void setHeightPercent(String id, double value) {
    final raw = _elementById(id);
    if (raw == null) return;
    final percent = value.clamp(.01, 2.0).toDouble();
    if (_activeBreakpoint == WebBreakpoint.desktop) {
      updateElement(raw.copyWith(heightPercent: percent));
    } else {
      _updateBreakpointOverride(
        raw,
        (override) => override.copyWith(heightPercent: percent),
      );
    }
  }

  void setSizeConstraints(
    String id, {
    double? minWidth,
    bool clearMinWidth = false,
    double? maxWidth,
    bool clearMaxWidth = false,
    double? minHeight,
    bool clearMinHeight = false,
    double? maxHeight,
    bool clearMaxHeight = false,
  }) {
    final raw = _elementById(id);
    if (raw == null) return;
    if (_activeBreakpoint == WebBreakpoint.desktop) {
      updateElement(
        raw.copyWith(
          minWidth: minWidth,
          clearMinWidth: clearMinWidth,
          maxWidth: maxWidth,
          clearMaxWidth: clearMaxWidth,
          minHeight: minHeight,
          clearMinHeight: clearMinHeight,
          maxHeight: maxHeight,
          clearMaxHeight: clearMaxHeight,
        ),
      );
      return;
    }
    _updateBreakpointOverride(
      raw,
      (override) => override.copyWith(
        minWidth: minWidth,
        clearMinWidth: clearMinWidth,
        maxWidth: maxWidth,
        clearMaxWidth: clearMaxWidth,
        minHeight: minHeight,
        clearMinHeight: clearMinHeight,
        maxHeight: maxHeight,
        clearMaxHeight: clearMaxHeight,
      ),
    );
  }

  void updateResolvedGeometry(
    String id, {
    double? x,
    double? y,
    double? width,
    double? height,
    bool commit = true,
  }) {
    final raw = _elementById(id);
    if (raw == null || raw.locked) return;
    final resolved = resolveElement(raw);
    _writeResolvedGeometry(
      raw,
      x: x ?? resolved.x,
      y: y ?? resolved.y,
      width: width ?? resolved.width,
      height: height ?? resolved.height,
      commit: commit,
    );
  }

  void _writeResolvedGeometry(
    WebElement raw, {
    required double x,
    required double y,
    required double width,
    required double height,
    required bool commit,
  }) {
    if (_activeBreakpoint == WebBreakpoint.desktop) {
      updateElement(
        raw.copyWith(
          x: x,
          y: y,
          width: width,
          height: height,
        ),
        commit: commit,
      );
      return;
    }

    _updateBreakpointOverride(
      raw,
      (override) => override.copyWith(
        x: x,
        y: y,
        width: width,
        height: height,
      ),
      commit: commit,
    );
  }

  WebElement _withResolvedGeometry(
    WebElement raw, {
    required double x,
    required double y,
    required double width,
    required double height,
  }) {
    if (_activeBreakpoint == WebBreakpoint.desktop) {
      return raw.copyWith(
        x: x,
        y: y,
        width: width,
        height: height,
      );
    }

    final map = Map<WebBreakpoint, WebElementBreakpointOverride>.from(
      raw.responsiveOverrides,
    );
    final current =
        map[_activeBreakpoint] ?? const WebElementBreakpointOverride();
    map[_activeBreakpoint] = current.copyWith(
      x: x,
      y: y,
      width: width,
      height: height,
    );
    return raw.copyWith(responsiveOverrides: map);
  }

  void _updateBreakpointOverride(
    WebElement raw,
    WebElementBreakpointOverride Function(
      WebElementBreakpointOverride override,
    ) update, {
    bool commit = true,
  }) {
    if (_activeBreakpoint == WebBreakpoint.desktop) return;
    final map = Map<WebBreakpoint, WebElementBreakpointOverride>.from(
      raw.responsiveOverrides,
    );
    final current =
        map[_activeBreakpoint] ?? const WebElementBreakpointOverride();
    final next = update(current);
    if (next.isEmpty) {
      map.remove(_activeBreakpoint);
    } else {
      map[_activeBreakpoint] = next;
    }
    updateElement(
      raw.copyWith(responsiveOverrides: map),
      commit: commit,
    );
  }

  bool isAutoLayoutManaged(String id) {
    final element = _elementById(id);
    final parentId = element?.parentId;
    if (parentId == null) return false;
    final parent = _elementById(parentId);
    return parent != null && parent.layoutMode != WebLayoutMode.free;
  }

  List<WebElement> parentCandidatesFor(String id) {
    final blocked = <String>{id, ..._descendantIds(id)};
    return activePage.elements
        .where(
          (element) =>
              element.canContainChildren && !blocked.contains(element.id),
        )
        .toList(growable: false);
  }

  void setParent(String id, String? parentId) {
    final raw = _elementById(id);
    if (raw == null || raw.parentId == parentId) return;
    if (parentId == id || _descendantIds(id).contains(parentId)) return;

    WebElement? currentResolved;
    for (final element in resolvedPageElements) {
      if (element.id == id) {
        currentResolved = element;
        break;
      }
    }
    if (currentResolved == null) return;

    if (parentId == null) {
      updateElement(
        raw.copyWith(
          clearParentId: true,
          x: currentResolved.x,
          y: currentResolved.y,
          width: currentResolved.width,
          height: currentResolved.height,
        ),
      );
      return;
    }

    final parentRaw = _elementById(parentId);
    WebElement? parentResolved;
    for (final element in resolvedPageElements) {
      if (element.id == parentId) {
        parentResolved = element;
        break;
      }
    }
    if (parentRaw == null ||
        parentResolved == null ||
        !parentRaw.canContainChildren) {
      return;
    }

    final localX = currentResolved.x -
        parentResolved.x -
        parentRaw.paddingLeft -
        raw.marginLeft;
    final localY = currentResolved.y -
        parentResolved.y -
        parentRaw.paddingTop -
        raw.marginTop;

    updateElement(
      raw.copyWith(
        parentId: parentId,
        x: localX,
        y: localY,
        width: currentResolved.width,
        height: currentResolved.height,
      ),
    );
  }

  Set<String> _descendantIds(String id) {
    final result = <String>{};
    void collect(String parentId) {
      for (final element in activePage.elements) {
        if (element.parentId == parentId && result.add(element.id)) {
          collect(element.id);
        }
      }
    }

    collect(id);
    return result;
  }

  void setLayoutMode(String id, WebLayoutMode mode) {
    final raw = _elementById(id);
    if (raw == null || !raw.canContainChildren) return;
    updateElement(raw.copyWith(layoutMode: mode));
  }

  void updateContainerLayout(
    String id, {
    double? gap,
    double? paddingTop,
    double? paddingRight,
    double? paddingBottom,
    double? paddingLeft,
    int? gridColumns,
    WebMainAlignment? mainAlignment,
    WebCrossAlignment? crossAlignment,
  }) {
    final raw = _elementById(id);
    if (raw == null || !raw.canContainChildren) return;
    updateElement(
      raw.copyWith(
        gap: gap,
        paddingTop: paddingTop,
        paddingRight: paddingRight,
        paddingBottom: paddingBottom,
        paddingLeft: paddingLeft,
        gridColumns: gridColumns,
        mainAlignment: mainAlignment,
        crossAlignment: crossAlignment,
      ),
    );
  }

  void updateMargins(
    String id, {
    double? top,
    double? right,
    double? bottom,
    double? left,
  }) {
    final raw = _elementById(id);
    if (raw == null) return;
    updateElement(
      raw.copyWith(
        marginTop: top,
        marginRight: right,
        marginBottom: bottom,
        marginLeft: left,
      ),
    );
  }

  void select(String? id) => selectOnly(id);

  void selectOnly(String? id) {
    _selectedIds.clear();
    if (id == null || !activePage.elements.any((element) => element.id == id)) {
      _selectedId = null;
    } else {
      _selectedIds.add(id);
      _selectedId = id;
    }
    if (_cropElementId != id) _cropElementId = null;
    notifyListeners();
  }

  void toggleSelection(String id) {
    if (!activePage.elements.any((element) => element.id == id)) return;
    if (_selectedIds.remove(id)) {
      if (_cropElementId == id) _cropElementId = null;
      if (_selectedId == id) {
        _selectedId = _selectedIds.isEmpty ? null : _selectedIds.last;
      }
    } else {
      _selectedIds.add(id);
      _selectedId = id;
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedIds
      ..clear()
      ..addAll(activePage.elements.map((element) => element.id));
    _selectedId = activePage.elements.isEmpty ? null : activePage.elements.last.id;
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedIds.isEmpty && _selectedId == null) return;
    _clearSelectionState();
    _cropElementId = null;
    notifyListeners();
  }

  bool isCropping(String id) => _cropElementId == id;

  void enterCropMode(String id) {
    final element = _elementById(id);
    if (element == null || element.type != WebElementType.image || element.locked) {
      return;
    }
    _selectedIds
      ..clear()
      ..add(id);
    _selectedId = id;
    _cropElementId = id;
    notifyListeners();
  }

  void exitCropMode() {
    if (_cropElementId == null) return;
    _cropElementId = null;
    notifyListeners();
  }

  void panImage(String id, double dx, double dy) {
    final element = _elementById(id);
    if (element == null ||
        element.type != WebElementType.image ||
        element.locked ||
        element.width <= 0 ||
        element.height <= 0) {
      return;
    }
    final scale = math.max(.25, element.imageScale);
    final nextX =
        (element.imagePositionX - (dx * 2 / (element.width * scale)))
            .clamp(-1.0, 1.0)
            .toDouble();
    final nextY =
        (element.imagePositionY - (dy * 2 / (element.height * scale)))
            .clamp(-1.0, 1.0)
            .toDouble();
    updateElement(
      element.copyWith(
        imagePositionX: nextX,
        imagePositionY: nextY,
      ),
      commit: false,
    );
  }

  void resetImageCrop(String id) {
    final element = _elementById(id);
    if (element == null || element.type != WebElementType.image) return;
    updateElement(
      element.copyWith(
        imagePositionX: 0,
        imagePositionY: 0,
        imageScale: 1,
      ),
    );
  }

  double snap(double value) {
    if (!snapEnabled) return value;
    return (value / gridStep).round() * gridStep;
  }

  void addElement(WebElementType type, {double? x, double? y}) {
    final page = activePage;
    final desktopX =
        math.max(24.0, (page.width - type.defaultWidth) / 2).toDouble();
    final targetWidth = viewportWidth;
    final targetX = snap(
      x ?? math.max(24.0, (targetWidth - type.defaultWidth) / 2).toDouble(),
    );
    final targetY = snap(y ?? 80.0 + page.elements.length * 28.0);

    var element = WebElement.fresh(
      id: 'element_${_nextId++}',
      type: type,
      x: _activeBreakpoint == WebBreakpoint.desktop ? targetX : desktopX,
      y: targetY,
    );

    if (_activeBreakpoint != WebBreakpoint.desktop) {
      final fittedWidth =
          math.min(type.defaultWidth, math.max(32.0, targetWidth - 48));
      element = element.copyWith(
        responsiveOverrides: {
          _activeBreakpoint: WebElementBreakpointOverride(
            x: targetX,
            y: targetY,
            width: fittedWidth,
          ),
        },
      );
    }

    _replacePage(
      page.copyWith(elements: [...page.elements, element]),
      commit: true,
    );
    _selectedIds
      ..clear()
      ..add(element.id);
    _selectedId = element.id;
    notifyListeners();
  }

  void updateElement(WebElement next, {bool commit = true}) {
    final page = activePage;
    final elements = page.elements
        .map((element) => element.id == next.id ? next : element)
        .toList();
    _replacePage(page.copyWith(elements: elements), commit: commit);
  }

  void moveBy(String id, double dx, double dy) {
    final anchorRaw = _elementById(id);
    if (anchorRaw == null || anchorRaw.locked || isAutoLayoutManaged(id)) return;
    if (!_selectedIds.contains(id)) {
      _selectedIds
        ..clear()
        ..add(id);
      _selectedId = id;
    }

    final anchor = resolveElement(anchorRaw);
    final nextX = snap(anchor.x + dx);
    final nextY = snap(anchor.y + dy);
    final effectiveDx = nextX - anchor.x;
    final effectiveDy = nextY - anchor.y;
    if (effectiveDx == 0 && effectiveDy == 0) return;

    final page = activePage;
    final elements = page.elements.map((raw) {
      if (!_selectedIds.contains(raw.id) ||
          raw.locked ||
          isAutoLayoutManaged(raw.id)) {
        return raw;
      }
      final resolved = resolveElement(raw);
      return _withResolvedGeometry(
        raw,
        x: resolved.x + effectiveDx,
        y: resolved.y + effectiveDy,
        width: resolved.width,
        height: resolved.height,
      );
    }).toList();
    _replacePage(page.copyWith(elements: elements), commit: false);
  }

  void nudgeSelection(double dx, double dy) {
    if (_selectedIds.isEmpty) return;
    final page = activePage;
    final elements = page.elements.map((raw) {
      if (!_selectedIds.contains(raw.id) || raw.locked) return raw;
      final resolved = resolveElement(raw);
      return _withResolvedGeometry(
        raw,
        x: resolved.x + dx,
        y: resolved.y + dy,
        width: resolved.width,
        height: resolved.height,
      );
    }).toList();
    _replacePage(page.copyWith(elements: elements), commit: true);
  }

  void resizeBy(
    String id, {
    required double dx,
    required double dy,
    required bool left,
    required bool right,
    required bool top,
    required bool bottom,
  }) {
    final raw = _elementById(id);
    if (raw == null || raw.locked) return;
    final element = resolvedPageElements.firstWhere(
      (candidate) => candidate.id == id,
      orElse: () => resolveElement(raw),
    );

    final c = math.cos(element.rotation);
    final s = math.sin(element.rotation);
    final localDx = dx * c + dy * s;
    final localDy = -dx * s + dy * c;

    var width = element.width;
    var height = element.height;
    var shiftX = 0.0;
    var shiftY = 0.0;

    if (left) {
      final next = math.max(32.0, width - localDx).toDouble();
      shiftX = (width - next) / 2;
      width = next;
    } else if (right) {
      final next = math.max(32.0, width + localDx).toDouble();
      shiftX = (next - width) / 2;
      width = next;
    }

    if (top) {
      final next = math.max(24.0, height - localDy).toDouble();
      shiftY = (height - next) / 2;
      height = next;
    } else if (bottom) {
      final next = math.max(24.0, height + localDy).toDouble();
      shiftY = (next - height) / 2;
      height = next;
    }

    if (snapEnabled) {
      width = math.max(32.0, snap(width)).toDouble();
      height = math.max(24.0, snap(height)).toDouble();
    }

    final screenShiftX = shiftX * c - shiftY * s;
    final screenShiftY = shiftX * s + shiftY * c;

    _writeResolvedGeometry(
      raw,
      x: isAutoLayoutManaged(id) ? element.x : element.x + screenShiftX,
      y: isAutoLayoutManaged(id) ? element.y : element.y + screenShiftY,
      width: width,
      height: height,
      commit: false,
    );
  }

  void commitLiveEdit() {
    _pushHistory();
    notifyListeners();
  }

  void removeSelected() {
    if (_selectedIds.isEmpty) return;
    final ids = Set<String>.of(_selectedIds);
    final page = activePage;
    _replacePage(
      page.copyWith(
        elements: page.elements.where((element) => !ids.contains(element.id)).toList(),
      ),
      commit: true,
    );
    _clearSelectionState();
    _cropElementId = null;
    notifyListeners();
  }

  void copySelected() {
    if (_selectedIds.isEmpty) return;
    _clipboard = selectedElements
        .map((element) => WebElement.fromJson(element.toJson()))
        .toList(growable: false);
    _pasteGeneration = 0;
    notifyListeners();
  }

  void pasteCopied() {
    if (_clipboard.isEmpty) return;
    _pasteGeneration += 1;
    final offset = 24.0 * _pasteGeneration;
    final created = _clipboard
        .map((source) => _cloneWithNewId(source, dx: offset, dy: offset))
        .toList(growable: false);
    final page = activePage;
    _replacePage(
      page.copyWith(elements: [...page.elements, ...created]),
      commit: true,
    );
    _selectCreated(created);
  }

  void duplicateSelected() {
    if (_selectedIds.isEmpty) return;
    final created = selectedElements
        .map((source) => _cloneWithNewId(source, dx: 24, dy: 24))
        .toList(growable: false);
    final page = activePage;
    _replacePage(
      page.copyWith(elements: [...page.elements, ...created]),
      commit: true,
    );
    _selectCreated(created);
  }

  void alignSelection(SelectionAlignment alignment) {
    final selected = resolvedSelectedElements;
    if (selected.isEmpty) return;

    final page = activePage;
    final targetLeft = selected.length == 1
        ? 0.0
        : selected.map((element) => element.x).reduce(math.min);
    final targetTop = selected.length == 1
        ? 0.0
        : selected.map((element) => element.y).reduce(math.min);
    final targetRight = selected.length == 1
        ? viewportWidth
        : selected
            .map((element) => element.x + element.width)
            .reduce(math.max);
    final targetBottom = selected.length == 1
        ? viewportHeight
        : selected
            .map((element) => element.y + element.height)
            .reduce(math.max);
    final targetCenterX = (targetLeft + targetRight) / 2;
    final targetCenterY = (targetTop + targetBottom) / 2;

    final ids = _selectedIds;
    final elements = page.elements.map((raw) {
      if (!ids.contains(raw.id) || raw.locked) return raw;
      final element = resolveElement(raw);

      final next = switch (alignment) {
        SelectionAlignment.left => element.copyWith(x: targetLeft),
        SelectionAlignment.horizontalCenter => element.copyWith(
            x: targetCenterX - element.width / 2,
          ),
        SelectionAlignment.right => element.copyWith(
            x: targetRight - element.width,
          ),
        SelectionAlignment.top => element.copyWith(y: targetTop),
        SelectionAlignment.verticalCenter => element.copyWith(
            y: targetCenterY - element.height / 2,
          ),
        SelectionAlignment.bottom => element.copyWith(
            y: targetBottom - element.height,
          ),
      };
      return _withResolvedGeometry(
        raw,
        x: next.x,
        y: next.y,
        width: next.width,
        height: next.height,
      );
    }).toList();

    _replacePage(page.copyWith(elements: elements), commit: true);
  }

  void distributeSelection(SelectionDistribution distribution) {
    final selected = resolvedSelectedElements
        .where((element) => !element.locked)
        .toList(growable: false);
    if (selected.length < 3) return;

    final page = activePage;
    final replacements = <String, WebElement>{};

    switch (distribution) {
      case SelectionDistribution.horizontal:
        final sorted = [...selected]..sort((a, b) => a.x.compareTo(b.x));
        final left = sorted.first.x;
        final right =
            sorted.last.x + sorted.last.width;
        final occupied =
            sorted.fold<double>(0, (sum, element) => sum + element.width);
        final gap = (right - left - occupied) / (sorted.length - 1);
        var cursor = left;
        for (final element in sorted) {
          replacements[element.id] = element.copyWith(x: cursor);
          cursor += element.width + gap;
        }
        break;
      case SelectionDistribution.vertical:
        final sorted = [...selected]..sort((a, b) => a.y.compareTo(b.y));
        final top = sorted.first.y;
        final bottom =
            sorted.last.y + sorted.last.height;
        final occupied =
            sorted.fold<double>(0, (sum, element) => sum + element.height);
        final gap = (bottom - top - occupied) / (sorted.length - 1);
        var cursor = top;
        for (final element in sorted) {
          replacements[element.id] = element.copyWith(y: cursor);
          cursor += element.height + gap;
        }
        break;
    }

    final elements = page.elements.map((raw) {
      final next = replacements[raw.id];
      if (next == null) return raw;
      return _withResolvedGeometry(
        raw,
        x: next.x,
        y: next.y,
        width: next.width,
        height: next.height,
      );
    }).toList();
    _replacePage(page.copyWith(elements: elements), commit: true);
  }

  void moveLayer(int delta) {
    if (_selectedIds.isEmpty || delta == 0) return;
    final page = activePage;
    final elements = [...page.elements];
    var changed = false;

    if (delta > 0) {
      for (var i = elements.length - 2; i >= 0; i--) {
        if (_selectedIds.contains(elements[i].id) &&
            !_selectedIds.contains(elements[i + 1].id)) {
          final item = elements[i];
          elements[i] = elements[i + 1];
          elements[i + 1] = item;
          changed = true;
        }
      }
    } else {
      for (var i = 1; i < elements.length; i++) {
        if (_selectedIds.contains(elements[i].id) &&
            !_selectedIds.contains(elements[i - 1].id)) {
          final item = elements[i];
          elements[i] = elements[i - 1];
          elements[i - 1] = item;
          changed = true;
        }
      }
    }

    if (changed) {
      _replacePage(page.copyWith(elements: elements), commit: true);
    }
  }

  void setPageSize(double width, double height) {
    _replacePage(
      activePage.copyWith(
        width: width.clamp(320.0, 4000.0).toDouble(),
        height: height.clamp(320.0, 12000.0).toDouble(),
      ),
      commit: true,
    );
  }

  void extendPage(double delta) {
    setPageSize(activePage.width, activePage.height + delta);
  }

  void undo() {
    if (!canUndo) return;
    _historyIndex -= 1;
    _project = _history[_historyIndex];
    _ensureSelectionExists();
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    _historyIndex += 1;
    _project = _history[_historyIndex];
    _ensureSelectionExists();
    notifyListeners();
  }

  WebElement? _elementById(String id) {
    for (final element in activePage.elements) {
      if (element.id == id) return element;
    }
    return null;
  }

  void _replacePage(WebPage page, {required bool commit}) {
    _project = _project.copyWith(
      pages: _project.pages
          .map((candidate) => candidate.id == page.id ? page : candidate)
          .toList(),
    );
    if (commit) _pushHistory();
    notifyListeners();
  }

  void _pushHistory() {
    final current = jsonEncode(_project.toJson());
    if (jsonEncode(_history[_historyIndex].toJson()) == current) return;
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(_project);
    if (_history.length > 100) {
      _history.removeAt(0);
    }
    _historyIndex = _history.length - 1;
  }

  WebElement _cloneWithNewId(
    WebElement source, {
    required double dx,
    required double dy,
  }) {
    final json = source.copyWith(
      x: source.x + dx,
      y: source.y + dy,
      locked: false,
    ).toJson();
    json['id'] = 'element_${_nextId++}';
    return WebElement.fromJson(json);
  }

  void _selectCreated(List<WebElement> created) {
    _selectedIds
      ..clear()
      ..addAll(created.map((element) => element.id));
    _selectedId = created.isEmpty ? null : created.last.id;
    notifyListeners();
  }

  void _clearSelectionState() {
    _selectedIds.clear();
    _selectedId = null;
  }

  void _ensureSelectionExists() {
    final validIds = activePage.elements.map((element) => element.id).toSet();
    _selectedIds.removeWhere((id) => !validIds.contains(id));
    if (_cropElementId != null && !validIds.contains(_cropElementId)) {
      _cropElementId = null;
    }
    if (_selectedId != null && !_selectedIds.contains(_selectedId)) {
      _selectedId = _selectedIds.isEmpty ? null : _selectedIds.last;
    }
  }
}
