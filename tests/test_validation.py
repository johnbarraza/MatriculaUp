import pytest

try:
    from scripts.extractors.validators import validate_courses_json, validate_curriculum_json
    VALIDATORS_AVAILABLE = True
except ImportError:
    VALIDATORS_AVAILABLE = False

skip_if_no_validators = pytest.mark.skipif(not VALIDATORS_AVAILABLE, reason="Implementation not yet written")


class TestJsonSchemaCompliance:
    """EXT-04: JSON output must validate against defined schema."""

    @skip_if_no_validators
    def test_valid_course_passes(self, minimal_valid_course):
        errors = validate_courses_json({"metadata": {"ciclo": "2026-1", "fecha_extraccion": "2026-02-24"}, "cursos": [minimal_valid_course]})
        assert errors == [], f"Valid course should pass, got: {errors}"

    @skip_if_no_validators
    def test_missing_codigo_fails(self, minimal_valid_course):
        bad = dict(minimal_valid_course)
        del bad["codigo"]
        errors = validate_courses_json({"metadata": {"ciclo": "2026-1", "fecha_extraccion": "2026-02-24"}, "cursos": [bad]})
        assert len(errors) > 0, "Missing 'codigo' should fail schema validation"

    @skip_if_no_validators
    def test_invalid_session_type_fails(self, minimal_valid_course):
        bad = dict(minimal_valid_course)
        bad["secciones"][0]["sesiones"][0]["tipo"] = "UNKNOWN_TYPE"
        errors = validate_courses_json({"metadata": {"ciclo": "2026-1", "fecha_extraccion": "2026-02-24"}, "cursos": [bad]})
        assert len(errors) > 0, "Unknown session type should fail schema validation"

    @skip_if_no_validators
    def test_missing_hora_inicio_fails(self, minimal_valid_course):
        bad = dict(minimal_valid_course)
        del bad["secciones"][0]["sesiones"][0]["hora_inicio"]
        errors = validate_courses_json({"metadata": {"ciclo": "2026-1", "fecha_extraccion": "2026-02-24"}, "cursos": [bad]})
        assert len(errors) > 0, "Missing 'hora_inicio' should fail"
