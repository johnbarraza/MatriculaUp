"""Convert raw EFE/SSU JSON to the standard MatriculaUp course format."""

from __future__ import annotations

import argparse
import json
from collections import OrderedDict
from pathlib import Path
from typing import Any

BASE_DIR = Path(__file__).resolve().parent.parent.parent
DEFAULT_INPUT = BASE_DIR / "pdfs" / "matricula" / "2026-2" / "EFEs" / "efe_ssu_2026-2_v1.json"
DEFAULT_OUTPUT = BASE_DIR / "input" / "efe_courses_2026-2_v1.json"


def _session_key(session: dict[str, Any]) -> tuple[Any, ...]:
    return (
        session.get("dia"),
        session.get("hora_inicio"),
        session.get("hora_fin"),
        session.get("fecha"),
    )


def _with_cupos(session: dict[str, Any], cupos: int | None) -> dict[str, Any]:
    if cupos is not None:
        session["cupos"] = cupos
    return session


def _derive_excel_sessions(section: dict[str, Any]) -> list[dict[str, Any]]:
    seen: set[tuple[Any, ...]] = set()
    result: list[dict[str, Any]] = []
    cupos = section.get("cupos")
    for day in section.get("sesiones_por_dia", []):
        fecha = day.get("fecha")
        dia = day.get("dia", "")
        for item in day.get("sesiones", []):
            if not item.get("hora_inicio") or not item.get("hora_fin"):
                continue
            session = {
                "tipo": "CLASE",
                "dia": dia,
                "hora_inicio": item["hora_inicio"],
                "hora_fin": item["hora_fin"],
                "aula": "",
                "fecha": fecha,
            }
            key = _session_key(session)
            if key in seen:
                continue
            seen.add(key)
            result.append(_with_cupos(session, cupos))
    return result


def _derive_pdf_sessions(section: dict[str, Any]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    cupos = section.get("cupos")
    for item in section.get("sesiones", []):
        if not item.get("hora_inicio") or not item.get("hora_fin"):
            continue
        session = {
            "tipo": "CLASE",
            "dia": item.get("dia", ""),
            "hora_inicio": item["hora_inicio"],
            "hora_fin": item["hora_fin"],
            "aula": "",
        }
        if item.get("fecha"):
            session["fecha"] = item["fecha"]
        result.append(_with_cupos(session, cupos))
    return result


def _observaciones(section: dict[str, Any], sessions: list[dict[str, Any]]) -> str:
    parts: list[str] = []
    fecha_inicio = section.get("fecha_inicio")
    fecha_fin = section.get("fecha_fin")
    if fecha_inicio or fecha_fin:
        parts.append(f"{fecha_inicio or ''} -> {fecha_fin or ''}".strip())

    exact_dates = sorted({session["fecha"] for session in sessions if session.get("fecha")})
    if exact_dates:
        parts.append("Fechas: " + ", ".join(exact_dates))

    detail = section.get("detalle")
    if detail:
        parts.append(detail)
    return " | ".join(part for part in parts if part)


def _prerequisitos(value: Any) -> dict[str, Any] | None:
    if not value:
        return None
    return {"raw": str(value), "parsed": False}


def convert(efe_data: dict[str, Any]) -> dict[str, Any]:
    out_courses: list[dict[str, Any]] = []

    for course in efe_data["cursos"]:
        sections_out: list[dict[str, Any]] = []
        for section in course.get("secciones", []):
            if section.get("tipo_sesion") == "INICIO_FIN":
                sessions = _derive_excel_sessions(section)
            else:
                sessions = _derive_pdf_sessions(section)

            docentes = section.get("facilitadores", [])
            sections_out.append(
                {
                    "seccion": section["seccion"],
                    "docentes": docentes,
                    "docente_principal": docentes[0] if docentes else None,
                    "jps": [],
                    "observaciones": _observaciones(section, sessions),
                    "sesiones": sessions,
                }
            )

        out_courses.append(
            OrderedDict(
                [
                    ("codigo", course["codigo"]),
                    ("nombre", f"[EFE] {course['nombre']}"),
                    ("creditos", course.get("creditos", "1")),
                    ("prerequisitos", _prerequisitos(course.get("prerequisitos"))),
                    ("secciones", sections_out),
                    ("_tipo_efe", course.get("tipo_efe", "")),
                ]
            )
        )

    metadata = dict(efe_data.get("metadata", {}))
    metadata.setdefault("version", "v1")
    metadata["descripcion"] = f"EFE + SSU {metadata.get('ciclo', '')} - formato estandar MatriculaUp".strip()
    metadata["total_cursos"] = len(out_courses)

    return {"metadata": metadata, "cursos": out_courses}


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Convert EFE/SSU raw JSON to courses JSON.")
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    return parser


def main() -> None:
    args = _build_parser().parse_args()
    print(f"Leyendo: {args.input}")
    with open(args.input, encoding="utf-8") as source:
        efe_data = json.load(source)

    out_data = convert(efe_data)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as target:
        json.dump(out_data, target, ensure_ascii=False, indent=2)

    total_sections = sum(len(course["secciones"]) for course in out_data["cursos"])
    sections_with_time = sum(
        1
        for course in out_data["cursos"]
        for section in course["secciones"]
        if section["sesiones"]
    )
    sessions = sum(
        len(section["sesiones"])
        for course in out_data["cursos"]
        for section in course["secciones"]
    )
    print(f"[OK] {args.output.name}")
    print(f"     Cursos:             {len(out_data['cursos'])}")
    print(f"     Secciones:          {total_sections}")
    print(f"     Secciones con hora: {sections_with_time}")
    print(f"     Sesiones:           {sessions}")


if __name__ == "__main__":
    main()
