import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../model/web_element.dart';
import '../model/web_page.dart';
import '../model/web_project.dart';

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

  bool gridEnabled = true;
  bool snapEnabled = false;
  double gridStep = 16;

  WebProject get project => _project;
  String get projectFingerprint => jsonEncode(_project.toJson());
  String? get selectedId => _selectedId;
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);
  bool get hasSelection => _selectedIds.isNotEmpty;
  bool get canPaste => _clipboard.isNotEmpty;
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

  void replaceProject(WebProject project) {
    _project = project;
    _clearSelectionState();
    _clipboard = const <WebElement>[];
    _pasteGeneration = 0;
    _nextId = _project.pages.expand((page) => page.elements).length + 1;
    _history
      ..clear()
      ..add(project);
    _historyIndex = 0;
    notifyListeners();
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
    notifyListeners();
  }

  void toggleSelection(String id) {
    if (!activePage.elements.any((element) => element.id == id)) return;
    if (_selectedIds.remove(id)) {
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
    notifyListeners();
  }

  double snap(double value) {
    if (!snapEnabled) return value;
    return (value / gridStep).round() * gridStep;
  }

  void addElement(WebElementType type, {double? x, double? y}) {
    final page = activePage;
    final defaultX =
        math.max(24.0, (page.width - type.defaultWidth) / 2).toDouble();
    final element = WebElement.fresh(
      id: 'element_${_nextId++}',
      type: type,
      x: snap(x ?? defaultX),
      y: snap(y ?? 80.0 + page.elements.length * 28.0),
    );
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
    final anchor = _elementById(id);
    if (anchor == null || anchor.locked) return;
    if (!_selectedIds.contains(id)) {
      _selectedIds
        ..clear()
        ..add(id);
      _selectedId = id;
    }

    final nextX = snap(anchor.x + dx);
    final nextY = snap(anchor.y + dy);
    final effectiveDx = nextX - anchor.x;
    final effectiveDy = nextY - anchor.y;
    if (effectiveDx == 0 && effectiveDy == 0) return;

    final page = activePage;
    final movingIds = _selectedIds;
    final elements = page.elements.map((element) {
      if (!movingIds.contains(element.id) || element.locked) return element;
      return element.copyWith(
        x: element.x + effectiveDx,
        y: element.y + effectiveDy,
      );
    }).toList();
    _replacePage(page.copyWith(elements: elements), commit: false);
  }

  void nudgeSelection(double dx, double dy) {
    if (_selectedIds.isEmpty) return;
    final page = activePage;
    final elements = page.elements.map((element) {
      if (!_selectedIds.contains(element.id) || element.locked) return element;
      return element.copyWith(x: element.x + dx, y: element.y + dy);
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
    final element = _elementById(id);
    if (element == null || element.locked) return;

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

    updateElement(
      element.copyWith(
        x: element.x + screenShiftX,
        y: element.y + screenShiftY,
        width: width,
        height: height,
      ),
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
    if (_selectedId != null && !_selectedIds.contains(_selectedId)) {
      _selectedId = _selectedIds.isEmpty ? null : _selectedIds.last;
    }
  }
}
