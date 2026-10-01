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

  bool gridEnabled = true;
  bool snapEnabled = false;
  double gridStep = 16;

  WebProject get project => _project;
  String? get selectedId => _selectedId;
  bool get canUndo => _historyIndex > 0;
  bool get canRedo => _historyIndex < _history.length - 1;

  WebPage get activePage => _project.pages.firstWhere(
        (page) => page.id == _project.activePageId,
      );

  WebElement? get selectedElement {
    final id = _selectedId;
    if (id == null) return null;
    for (final element in activePage.elements) {
      if (element.id == id) return element;
    }
    return null;
  }

  void replaceProject(WebProject project) {
    _project = project;
    _selectedId = null;
    _nextId = _project.pages
            .expand((page) => page.elements)
            .length +
        1;
    _history
      ..clear()
      ..add(project);
    _historyIndex = 0;
    notifyListeners();
  }

  void select(String? id) {
    _selectedId = id;
    notifyListeners();
  }

  double snap(double value) {
    if (!snapEnabled) return value;
    return (value / gridStep).round() * gridStep;
  }

  void addElement(WebElementType type, {double? x, double? y}) {
    final page = activePage;
    final element = WebElement.fresh(
      id: 'element_${_nextId++}',
      type: type,
      x: snap(x ?? math.max(24, (page.width - type.defaultWidth) / 2)),
      y: snap(y ?? 80 + page.elements.length * 28),
    );
    _replacePage(
      page.copyWith(elements: [...page.elements, element]),
      commit: true,
    );
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
    final element = _elementById(id);
    if (element == null || element.locked) return;
    updateElement(
      element.copyWith(
        x: snap(element.x + dx),
        y: snap(element.y + dy),
      ),
      commit: false,
    );
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
      final next = math.max(32, width - localDx);
      shiftX = (width - next) / 2;
      width = next;
    } else if (right) {
      final next = math.max(32, width + localDx);
      shiftX = (next - width) / 2;
      width = next;
    }

    if (top) {
      final next = math.max(24, height - localDy);
      shiftY = (height - next) / 2;
      height = next;
    } else if (bottom) {
      final next = math.max(24, height + localDy);
      shiftY = (next - height) / 2;
      height = next;
    }

    if (snapEnabled) {
      width = math.max(32, snap(width));
      height = math.max(24, snap(height));
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
    final id = _selectedId;
    if (id == null) return;
    final page = activePage;
    _replacePage(
      page.copyWith(
        elements: page.elements.where((element) => element.id != id).toList(),
      ),
      commit: true,
    );
    _selectedId = null;
    notifyListeners();
  }

  void duplicateSelected() {
    final source = selectedElement;
    if (source == null) return;
    final duplicate = WebElement.fromJson(source.toJson())
        .copyWith(x: source.x + 24, y: source.y + 24);
    final json = duplicate.toJson();
    json['id'] = 'element_${_nextId++}';
    final next = WebElement.fromJson(json);
    final page = activePage;
    _replacePage(
      page.copyWith(elements: [...page.elements, next]),
      commit: true,
    );
    _selectedId = next.id;
    notifyListeners();
  }

  void moveLayer(int delta) {
    final id = _selectedId;
    if (id == null) return;
    final page = activePage;
    final elements = [...page.elements];
    final index = elements.indexWhere((element) => element.id == id);
    if (index < 0) return;
    final target = (index + delta).clamp(0, elements.length - 1);
    if (target == index) return;
    final item = elements.removeAt(index);
    elements.insert(target, item);
    _replacePage(page.copyWith(elements: elements), commit: true);
  }

  void setPageSize(double width, double height) {
    _replacePage(
      activePage.copyWith(
        width: width.clamp(320, 4000),
        height: height.clamp(320, 12000),
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

  void _ensureSelectionExists() {
    final id = _selectedId;
    if (id != null && !activePage.elements.any((element) => element.id == id)) {
      _selectedId = null;
    }
  }
}
