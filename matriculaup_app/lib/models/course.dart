enum SessionType {
  clase("CLASE"),
  practica("PRÁCTICA"),
  laboratorio("LABORATORIO"),
  finalExam("FINAL"),
  parcial("PARCIAL"),
  cancelada("CANCELADA"),
  pracDirigida("PRACDIRIGIDA"),
  pracCalificada("PRACCALIFICADA"),
  exSustitutorio("EXSUSTITUTORIO"),
  exRezagado("EXREZAGADO"),
  unknown("UNKNOWN");

  final String value;
  const SessionType(this.value);

  factory SessionType.fromString(String value) {
    return SessionType.values.firstWhere(
      (e) => e.value.toUpperCase() == value.toUpperCase(),
      orElse: () => SessionType.unknown,
    );
  }
}

class Session {
  final SessionType tipo;
  final String dia;
  final String horaInicio;
  final String horaFin;
  final String aula;

  Session({
    required this.tipo,
    required this.dia,
    required this.horaInicio,
    required this.horaFin,
    required this.aula,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      tipo: SessionType.fromString(json['tipo'] as String),
      dia: json['dia'] as String,
      horaInicio: json['hora_inicio'] as String,
      horaFin: json['hora_fin'] as String,
      aula: json['aula'] as String? ?? "",
    );
  }
}

class Section {
  final String seccion;
  final List<String> docentes;
  final String observaciones;
  final List<Session> sesiones;

  Section({
    required this.seccion,
    required this.docentes,
    required this.observaciones,
    required this.sesiones,
  });

  factory Section.fromJson(Map<String, dynamic> json) {
    return Section(
      seccion: json['seccion'] as String,
      docentes:
          (json['docentes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      observaciones: json['observaciones'] as String? ?? "",
      sesiones:
          (json['sesiones'] as List<dynamic>?)
              ?.map((e) => Session.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class Course {
  final String codigo;
  final String nombre;
  final String creditos;
  final Map<String, dynamic>? prerequisitos;
  final List<Section> secciones;

  Course({
    required this.codigo,
    required this.nombre,
    required this.creditos,
    this.prerequisitos,
    required this.secciones,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      codigo: json['codigo'] as String,
      nombre: json['nombre'] as String,
      creditos: json['creditos'] as String,
      prerequisitos: json['prerequisitos'] as Map<String, dynamic>?,
      secciones:
          (json['secciones'] as List<dynamic>?)
              ?.map((e) => Section.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
