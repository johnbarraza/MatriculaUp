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
    final upperValue = value.toUpperCase().trim();
    // Use partial matching where possible for robustness
    if (upperValue.contains("CLASE")) {
      return SessionType.clase;
    }
    if (upperValue.contains("PRÁCTICA") || upperValue.contains("PRACTICA")) {
      return SessionType.practica;
    }
    if (upperValue.contains("LABORATORIO")) {
      return SessionType.laboratorio;
    }
    if (upperValue.contains("FINAL")) {
      return SessionType.finalExam;
    }
    if (upperValue.contains("PARCIAL")) {
      return SessionType.parcial;
    }
    if (upperValue.contains("CANCELADA")) {
      return SessionType.cancelada;
    }
    if (upperValue.contains("PRACDIRIGIDA") ||
        upperValue.contains("DIRIGIDA")) {
      return SessionType.pracDirigida;
    }
    if (upperValue.contains("PRACCALIFICADA") ||
        upperValue.contains("CALIFICADA")) {
      return SessionType.pracCalificada;
    }
    if (upperValue.contains("EXSUSTITUTORIO") ||
        upperValue.contains("SUSTITUTORIO")) {
      return SessionType.exSustitutorio;
    }
    if (upperValue.contains("EXREZAGADO") || upperValue.contains("REZAGADO")) {
      return SessionType.exRezagado;
    }

    return SessionType.unknown;
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
