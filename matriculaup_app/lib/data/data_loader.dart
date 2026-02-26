import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../models/course.dart';
import '../models/curriculum.dart';
import '../models/calendar_event.dart';

/// Result of loading a courses JSON: the parsed courses plus a human-readable
/// label describing the source (e.g. "2026-1 · v1 · 2026-02-25").
class CoursesResult {
  final List<Course> courses;
  final String label;

  const CoursesResult({required this.courses, required this.label});
}

class DataLoader {
  /// Builds a display label from JSON metadata fields.
  /// Falls back to [fallback] (e.g. filename) when metadata is absent.
  static String _buildLabel(Map<String, dynamic>? meta, String fallback) {
    if (meta == null) return fallback;
    final parts = <String>[];
    final ciclo = meta['ciclo'] as String?;
    final version = meta['version'] as String?;
    final fecha = meta['fecha_extraccion'] as String?;
    if (ciclo != null && ciclo.isNotEmpty) parts.add(ciclo);
    if (version != null && version.isNotEmpty) parts.add(version);
    if (fecha != null && fecha.isNotEmpty) parts.add(fecha);
    return parts.isEmpty ? fallback : parts.join(' · ');
  }

  /// Loads the bundled default EFE courses asset.
  static Future<CoursesResult?> loadDefaultEfeCourses() async {
    try {
      final contents = await rootBundle.loadString('assets/efe_courses_2026-1_v1.json');
      final jsonData = jsonDecode(contents) as Map<String, dynamic>;
      final coursesList = jsonData['cursos'] as List<dynamic>? ?? [];
      final courses = coursesList.map((c) => Course.fromJson(c)).toList();
      final label = _buildLabel(
        jsonData['metadata'] as Map<String, dynamic>?,
        'EFE default',
      );
      return CoursesResult(courses: courses, label: label);
    } catch (e) {
      debugPrint("Error loading default EFE courses: $e");
      return null;
    }
  }

  /// Loads the bundled default courses asset.
  static Future<CoursesResult?> loadDefaultCourses() async {
    try {
      final contents = await rootBundle.loadString('assets/default_courses.json');
      final jsonData = jsonDecode(contents) as Map<String, dynamic>;
      final coursesList = jsonData['cursos'] as List<dynamic>? ?? [];
      final courses = coursesList.map((c) => Course.fromJson(c)).toList();
      final label = _buildLabel(
        jsonData['metadata'] as Map<String, dynamic>?,
        'default',
      );
      return CoursesResult(courses: courses, label: label);
    } catch (e) {
      debugPrint("Error loading default courses: $e");
      return null;
    }
  }

  /// Opens a file picker so the user can load a custom courses JSON.
  static Future<CoursesResult?> pickAndLoadCourses() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final contents = utf8.decode(result.files.single.bytes!);
        final jsonData = jsonDecode(contents) as Map<String, dynamic>;
        final coursesList = jsonData['cursos'] as List<dynamic>? ?? [];
        final courses = coursesList.map((c) => Course.fromJson(c)).toList();
        final label = _buildLabel(
          jsonData['metadata'] as Map<String, dynamic>?,
          result.files.single.name,
        );
        return CoursesResult(courses: courses, label: label);
      }
    } catch (e) {
      debugPrint("Error loading courses: $e");
    }
    return null;
  }

  /// Loads the bundled academic calendar asset.
  static Future<AcademicCalendar?> loadCalendar() async {
    try {
      final contents = await rootBundle.loadString('assets/calendar_2026-1.json');
      final jsonData = jsonDecode(contents) as Map<String, dynamic>;
      return AcademicCalendar.fromJson(jsonData);
    } catch (e) {
      debugPrint("Error loading calendar: $e");
      return null;
    }
  }

  static Future<Curriculum?> pickAndLoadCurriculum() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Cargar Plan de Estudios (Curriculum)',
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final contents = utf8.decode(result.files.single.bytes!);
        final jsonData = jsonDecode(contents) as Map<String, dynamic>;
        return Curriculum.fromJson(jsonData);
      }
    } catch (e) {
      debugPrint("Error loading curriculum: $e");
    }
    return null;
  }
}
