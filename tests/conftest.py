import pytest
from tests.fixtures.sample_rows import (
    COURSE_HEADER_ROW, PREREQ_ROW_TRUNCATED, PREREQ_ROW_CONTINUATION,
    SECTION_ROW_CLASE, PROFESSOR_COMPOUND_ROW
)


@pytest.fixture
def sample_truncated_prereq_rows():
    """Multi-row prerequisite that truncates mid-expression."""
    return [COURSE_HEADER_ROW, PREREQ_ROW_TRUNCATED]


@pytest.fixture
def sample_complete_prereq_rows():
    """Multi-row prerequisite that spans continuation and completes properly."""
    return [COURSE_HEADER_ROW, PREREQ_ROW_TRUNCATED, PREREQ_ROW_CONTINUATION]


@pytest.fixture
def sample_professor_text():
    return PROFESSOR_COMPOUND_ROW


@pytest.fixture
def minimal_valid_course():
    """Minimal course dict that satisfies courses JSON schema."""
    return {
        "codigo": "138201",
        "nombre": "Microeconomia I",
        "creditos": "4",
        "prerequisitos": None,
        "secciones": [
            {
                "seccion": "A",
                "docentes": ["CASTROMATTA, Milagros Del Rosario"],
                "observaciones": "",
                "sesiones": [
                    {
                        "tipo": "CLASE",
                        "dia": "LUN",
                        "hora_inicio": "07:30",
                        "hora_fin": "09:30",
                        "aula": "A-301"
                    }
                ]
            }
        ]
    }
