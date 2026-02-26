"""efe_to_courses.py — Convierte el JSON EFE al formato estándar de MatriculaUp.

Input:  pdfs/matricula/2026-1/EFEs/efe_ssu_2026-1_v1.json
Output: input/efe_courses_2026-1_v1.json

Reglas de conversión:
  - tipo_sesion=CLASE → sesiones directas (añade tipo="CLASE", aula="")
  - tipo_sesion=INICIO_FIN → deriva sesiones únicas (dia, hora) de sesiones_por_dia
    Si no hay sesiones_por_dia (ej. viaje de 3 días), la sección queda con sesiones=[]
    y el detalle queda en observaciones.
  - facilitadores → docentes
  - nombre lleva prefijo "[EFE]" para distinguirse en el buscador
"""

from __future__ import annotations

import json
from collections import OrderedDict
from datetime import date
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent.parent
IN_PATH  = BASE_DIR / "pdfs" / "matricula" / "2026-1" / "EFEs" / "efe_ssu_2026-1_v1.json"
OUT_PATH = BASE_DIR / "input" / "efe_courses_2026-1_v1.json"

# Manual corrections for known PDF parsing errors.
# Format: {codigo: {seccion: {field: value}}}
_DATE_CORRECTIONS: dict[str, dict[str, dict]] = {
    "900843": {  # Senderismo en Canta (VIAJE DE 3 DÍAS) — PDF dates were garbled
        "A": {"fecha_inicio": "2026-07-07", "fecha_fin": "2026-07-09"},
    },
}


def _derive_sessions(ssu_section: dict) -> list[dict]:
    """Extrae slots únicos (dia, hora_inicio, hora_fin) de sesiones_por_dia."""
    seen: set[tuple] = set()
    result: list[dict] = []
    for day in ssu_section.get("sesiones_por_dia", []):
        dia = day["dia"]
        for ses in day["sesiones"]:
            key = (dia, ses["hora_inicio"], ses["hora_fin"])
            if key not in seen:
                seen.add(key)
                result.append({
                    "tipo":        "CLASE",
                    "dia":         dia,
                    "hora_inicio": ses["hora_inicio"],
                    "hora_fin":    ses["hora_fin"],
                    "aula":        "",
                })
    return result


def convert(efe_data: dict) -> dict:
    out_courses = []

    for c in efe_data["cursos"]:
        tipo_efe    = c.get("tipo_efe", "")
        secciones_out = []

        for s in c["secciones"]:
            tipo_sesion = s.get("tipo_sesion", "CLASE")

            # Apply manual date corrections
            sec_corr = _DATE_CORRECTIONS.get(c["codigo"], {}).get(s["seccion"], {})
            if sec_corr:
                s = {**s, **sec_corr}

            if tipo_sesion == "CLASE":
                sesiones = [
                    {
                        "tipo":        "CLASE",
                        "dia":         ses["dia"],
                        "hora_inicio": ses["hora_inicio"],
                        "hora_fin":    ses["hora_fin"],
                        "aula":        "",
                    }
                    for ses in s.get("sesiones", [])
                ]
                obs = ""
            else:
                # INICIO_FIN (SSU / viajes)
                sesiones = _derive_sessions(s)
                # Build observaciones from dates + detalle
                fi = s.get("fecha_inicio") or ""
                ff = s.get("fecha_fin") or ""
                det = s.get("detalle") or ""
                parts = [p for p in [f"{fi} → {ff}" if fi or ff else "", det] if p]
                obs = " | ".join(parts)

            secciones_out.append({
                "seccion":      s["seccion"],
                "docentes":     s.get("facilitadores", []),
                "observaciones": obs,
                "sesiones":     sesiones,
            })

        out_courses.append({
            "codigo":       c["codigo"],
            "nombre":       f"[EFE] {c['nombre']}",
            "creditos":     c.get("creditos", "1"),
            "prerequisitos": None,
            "secciones":    secciones_out,
            # Keep EFE metadata as extra field (ignored by app, useful for filtering)
            "_tipo_efe":    tipo_efe,
        })

    meta = dict(efe_data["metadata"])
    meta["version"] = "v1"
    meta["descripcion"] = "EFE + SSU 2026-I — formato estándar MatriculaUp"

    return {"metadata": meta, "cursos": out_courses}


def main() -> None:
    print(f"Leyendo: {IN_PATH.name}")
    with open(IN_PATH, encoding="utf-8") as f:
        efe_data = json.load(f)

    out_data = convert(efe_data)

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        json.dump(out_data, f, ensure_ascii=False, indent=2)

    total = len(out_data["cursos"])
    clase_secs = sum(
        1 for c in out_data["cursos"]
        for s in c["secciones"]
        if s["sesiones"]
    )
    empty_secs = sum(
        1 for c in out_data["cursos"]
        for s in c["secciones"]
        if not s["sesiones"]
    )
    print(f"[OK] {OUT_PATH.name}")
    print(f"     Cursos:            {total}")
    print(f"     Secciones con hora:{clase_secs}")
    print(f"     Secciones sin hora:{empty_secs}  (SSU sin Excel / viajes)")


if __name__ == "__main__":
    main()
