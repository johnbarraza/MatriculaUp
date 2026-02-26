enum CalendarEventType {
  libre,
  examen,
  matricula,
  prematricula,
  academico,
  plazo,
  administrativo;

  factory CalendarEventType.fromString(String value) {
    return switch (value.toLowerCase()) {
      'libre'          => CalendarEventType.libre,
      'examen'         => CalendarEventType.examen,
      'matricula'      => CalendarEventType.matricula,
      'prematricula'   => CalendarEventType.prematricula,
      'academico'      => CalendarEventType.academico,
      'plazo'          => CalendarEventType.plazo,
      'administrativo' => CalendarEventType.administrativo,
      _                => CalendarEventType.administrativo,
    };
  }

  String get label => switch (this) {
    CalendarEventType.libre          => 'Día libre',
    CalendarEventType.examen         => 'Examen',
    CalendarEventType.matricula      => 'Matrícula',
    CalendarEventType.prematricula   => 'Prematrícula',
    CalendarEventType.academico      => 'Académico',
    CalendarEventType.plazo          => 'Plazo',
    CalendarEventType.administrativo => 'Administrativo',
  };
}

class AcademicCalendar {
  final String ciclo;
  final String semestre;
  final String inicioClases;
  final String finClases;
  final List<CalendarEvent> eventos;

  const AcademicCalendar({
    required this.ciclo,
    required this.semestre,
    required this.inicioClases,
    required this.finClases,
    required this.eventos,
  });

  factory AcademicCalendar.fromJson(Map<String, dynamic> json) {
    final raw = (json['eventos'] as List<dynamic>? ?? []);
    final eventos = raw
        .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.inicio.compareTo(b.inicio));
    return AcademicCalendar(
      ciclo:        json['ciclo'] as String,
      semestre:     json['semestre'] as String,
      inicioClases: json['inicio_clases'] as String,
      finClases:    json['fin_clases'] as String,
      eventos:      eventos,
    );
  }
}

class CalendarEvent {
  final CalendarEventType tipo;
  final String descripcion;
  final String inicio; // ISO date
  final String fin;    // ISO date (same as inicio for single-day events)

  const CalendarEvent({
    required this.tipo,
    required this.descripcion,
    required this.inicio,
    required this.fin,
  });

  bool get isSingleDay => inicio == fin;

  /// Returns the month number (1–12) of the start date.
  int get mes => int.parse(inicio.substring(5, 7));

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    final ini = json['inicio'] as String;
    return CalendarEvent(
      tipo:        CalendarEventType.fromString(json['tipo'] as String),
      descripcion: json['descripcion'] as String,
      inicio:      ini,
      fin:         json['fin'] as String? ?? ini,
    );
  }
}
