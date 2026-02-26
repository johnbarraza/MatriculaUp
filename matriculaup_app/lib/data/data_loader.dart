import 'dart:convert';

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
        withData:
            true, // This flag ensures bytes are loaded into memory (critical for Web)
      );

      if (result != null && result.files.single.bytes != null) {
        // Read file contents from raw bytes (works on Web, Desktop, Mobile)
        String contents = utf8.decode(result.files.single.bytes!);

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
        withData: true, // Load into memory for Web support
      );

      if (result != null && result.files.single.bytes != null) {
        String contents = utf8.decode(result.files.single.bytes!);

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
