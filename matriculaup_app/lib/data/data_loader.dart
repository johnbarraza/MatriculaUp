import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../models/course.dart';
import '../models/curriculum.dart';

class DataLoader {
  static Future<List<Course>?> pickAndLoadCourses() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String contents = await file.readAsString();

        // Parse JSON
        Map<String, dynamic> jsonData = jsonDecode(contents);

        List<dynamic> coursesList = jsonData['cursos'] ?? [];
        return coursesList.map((c) => Course.fromJson(c)).toList();
      }
    } catch (e) {
      debugPrint("Error loading courses: $e");
    }
    return null;
  }

  static Future<Curriculum?> pickAndLoadCurriculum() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Cargar Plan de Estudios (Curriculum)',
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String contents = await file.readAsString();

        // Parse JSON
        Map<String, dynamic> jsonData = jsonDecode(contents);
        return Curriculum.fromJson(jsonData);
      }
    } catch (e) {
      debugPrint("Error loading curriculum: $e");
    }
    return null;
  }
}
