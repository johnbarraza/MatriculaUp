class CurriculumNode {
  final String codigo;
  final String nombre;
  final int nivel; // Level or semester (sometimes 1-10)
  final String creditos;

  CurriculumNode({
    required this.codigo,
    required this.nombre,
    required this.nivel,
    required this.creditos,
  });

  factory CurriculumNode.fromJson(Map<String, dynamic> json) {
    return CurriculumNode(
      codigo: json['codigo'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      nivel: json['nivel'] as int? ?? 0,
      creditos: json['creditos']?.toString() ?? '',
    );
  }
}

class Curriculum {
  final String title;
  final String year;
  final String career;
  final List<CurriculumNode> courses;

  Curriculum({
    required this.title,
    required this.year,
    required this.career,
    required this.courses,
  });

  factory Curriculum.fromJson(Map<String, dynamic> json) {
    return Curriculum(
      title: json['metadata']?['plan'] as String? ?? '',
      year: json['metadata']?['ano']?.toString() ?? '',
      career: json['metadata']?['carrera'] as String? ?? '',
      courses:
          (json['cursos'] as List<dynamic>?)
              ?.map((e) => CurriculumNode.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  bool isMandatory(String courseCode) {
    return courses.any((c) => c.codigo == courseCode);
  }
}
