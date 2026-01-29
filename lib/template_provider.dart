import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'models.dart';

class TemplateProvider extends ChangeNotifier {
  List<TemplateModel> _templates = [];
  bool _isLoading = true;
  bool _isDarkMode = false;

  List<TemplateModel> get templates => _templates;
  bool get isLoading => _isLoading;
  bool get isDarkMode => _isDarkMode;

  TemplateProvider() {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await loadTemplates();
    await _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
  }

  Future<void> loadTemplates() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? templatesJson = prefs.getString('templates');
      if (templatesJson != null) {
        final List<dynamic> decoded = jsonDecode(templatesJson);
        _templates = decoded
            .map((item) => TemplateModel.fromJson(item))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading templates: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveTemplates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(
        _templates.map((t) => t.toJson()).toList(),
      );
      await prefs.setString('templates', encoded);
    } catch (e) {
      debugPrint('Error saving templates: $e');
    }
  }

  void addTemplate(TemplateModel template) {
    _templates.add(template);
    saveTemplates();
    notifyListeners();
  }

  void updateTemplate(TemplateModel template) {
    final index = _templates.indexWhere((t) => t.id == template.id);
    if (index != -1) {
      _templates[index] = template;
      saveTemplates();
      notifyListeners();
    }
  }

  void deleteTemplate(String id) {
    _templates.removeWhere((t) => t.id == id);
    saveTemplates();
    notifyListeners();
  }

  TemplateModel? getTemplateById(String id) {
    try {
      return _templates.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> exportTemplate(TemplateModel template) async {
    try {
      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Template',
        fileName: '${template.name.replaceAll(' ', '_')}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (outputFile != null) {
        final File file = File(outputFile);
        final String encoded = jsonEncode(template.toJson());
        await file.writeAsString(encoded);
      }
    } catch (e) {
      debugPrint('Export Error: $e');
    }
  }

  Future<bool> importTemplate() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final Map<String, dynamic> decoded = jsonDecode(content);
        final template = TemplateModel.fromJson(decoded);

        // Ensure unique ID for imported template to avoid collisions
        final newTemplate = template.copyWith(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
        );

        addTemplate(newTemplate);
        return true;
      }
    } catch (e) {
      debugPrint('Import Error: $e');
    }
    return false;
  }
}
