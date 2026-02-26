"""
JSON Schema validators for MatriculaUp extraction output.
Uses jsonschema library for declarative schema validation.
"""
from jsonschema import validate, ValidationError, Draft7Validator
from typing import List
import logging

logger = logging.getLogger(__name__)

# --- Courses Schema -------------------------------------------------------

SESSION_SCHEMA = {
    "type": "object",
    "properties": {
        "tipo": {
            "type": "string",
            "enum": ["CLASE", "PRÁCTICA", "FINAL", "PARCIAL", "PRACDIRIGIDA",
                     "PRACCALIFICADA", "CANCELADA", "LABORATORIO", "TALLER"]
        },
        "dia": {"type": "string", "minLength": 2},
        "hora_inicio": {"type": "string", "pattern": r"^\d{2}:\d{2}$"},
        "hora_fin": {"type": "string", "pattern": r"^\d{2}:\d{2}$"},
        "aula": {"type": ["string", "null"]},
    },
    "required": ["tipo", "dia", "hora_inicio", "hora_fin"],
}

SECTION_SCHEMA = {
    "type": "object",
    "properties": {
        "seccion": {"type": "string", "minLength": 1},
        "docentes": {"type": "array", "items": {"type": "string"}},
        "observaciones": {"type": ["string", "null"]},
        "sesiones": {"type": "array", "items": SESSION_SCHEMA, "minItems": 0},
    },
    "required": ["seccion", "sesiones"],
}

PREREQUISITE_SCHEMA = {
    "oneOf": [
        {"type": "null"},
        {"type": "string"},
        {
            "type": "object",
            "properties": {
                "raw": {"type": "string"},
                "parsed": {"type": "boolean", "enum": [False]},
            },
            "required": ["raw", "parsed"],
        },
        {
            "type": "object",
            "properties": {
                "op": {"type": "string", "enum": ["AND", "OR"]},
                "items": {"type": "array"},
            },
            "required": ["items"],
        },
    ]
}

COURSE_SCHEMA = {
    "type": "object",
    "properties": {
        "codigo": {"type": "string", "pattern": r"^[A-Za-z0-9]{6}$"},
        "nombre": {"type": "string", "minLength": 1},
        "creditos": {"type": ["string", "number", "null"]},
        "prerequisitos": PREREQUISITE_SCHEMA,
        "secciones": {"type": "array", "items": SECTION_SCHEMA},
    },
    "required": ["codigo", "nombre", "creditos", "secciones"],
}

COURSES_SCHEMA = {
    "type": "object",
    "properties": {
        "metadata": {
            "type": "object",
            "properties": {
                "ciclo": {"type": "string"},
                "fecha_extraccion": {"type": "string"},
            },
            "required": ["ciclo", "fecha_extraccion"],
        },
        "cursos": {
            "type": "array",
            "items": COURSE_SCHEMA,
            "minItems": 1,
        },
    },
    "required": ["metadata", "cursos"],
}

# --- Curriculum Schema ----------------------------------------------------

CURRICULUM_COURSE_SCHEMA = {
    "type": "object",
    "properties": {
        "codigo": {"type": "string"},
        "nombre": {"type": "string"},
        "creditos": {"type": ["string", "number", "null"]},
        "tipo": {
            "type": "string",
            "enum": ["obligatorio", "electivo", "obligatorio_concentracion", "other"]
        },
    },
    "required": ["codigo", "nombre"],
}

# Regular ciclo (integer, 0-10)
CICLO_INT_SCHEMA = {
    "type": "object",
    "properties": {
        "ciclo": {"type": ["integer", "number"], "minimum": 0},
        "cursos": {"type": "array", "items": CURRICULUM_COURSE_SCHEMA, "minItems": 1},
    },
    "required": ["ciclo", "cursos"],
}

# Special ciclo groups (string key: "concentracion", "electivos", etc.)
CICLO_STR_SCHEMA = {
    "type": "object",
    "properties": {
        "ciclo": {"type": "string", "minLength": 1},
        "nombre": {"type": "string"},
        "cursos": {"type": "array", "items": CURRICULUM_COURSE_SCHEMA, "minItems": 1},
    },
    "required": ["ciclo", "cursos"],
}

# Ciclo schema accepts either integer or string ciclo key
CICLO_SCHEMA = {
    "oneOf": [CICLO_INT_SCHEMA, CICLO_STR_SCHEMA]
}

CURRICULUM_SCHEMA = {
    "type": "object",
    "properties": {
        "metadata": {
            "type": "object",
            "properties": {
                "plan": {"type": "string"},
                "carrera": {"type": "string"},
                "fecha_extraccion": {"type": "string"},
            },
            "required": ["plan", "carrera", "fecha_extraccion"],
        },
        "ciclos": {
            "type": "array",
            "items": CICLO_SCHEMA,
            "minItems": 1,
        },
    },
    "required": ["metadata", "ciclos"],
}

# --- Validator Functions --------------------------------------------------


def validate_courses_json(data: dict) -> List[str]:
    """
    Validate courses extraction output against COURSES_SCHEMA.
    Returns list of error messages (empty list = valid).
    """
    validator = Draft7Validator(COURSES_SCHEMA)
    errors = sorted(validator.iter_errors(data), key=lambda e: list(e.path))
    if not errors:
        return []
    return [f"{'.'.join(str(p) for p in e.path)}: {e.message}" for e in errors]


def validate_curriculum_json(data: dict) -> List[str]:
    """
    Validate curriculum extraction output against CURRICULUM_SCHEMA.
    Returns list of error messages (empty list = valid).
    """
    validator = Draft7Validator(CURRICULUM_SCHEMA)
    errors = sorted(validator.iter_errors(data), key=lambda e: list(e.path))
    if not errors:
        return []
    return [f"{'.'.join(str(p) for p in e.path)}: {e.message}" for e in errors]
