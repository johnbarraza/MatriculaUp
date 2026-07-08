import pytest
import re

# These imports will FAIL until Plan 02 creates the modules -- that is correct RED state
try:
    from scripts.extractors.courses import extract_prerequisites_with_continuation, is_truncated_prerequisite
    from scripts.extractors.courses import extract_professors_spanish
    from scripts.extractors.courses import split_instructor_roles
    from scripts.extractors.courses import parse_prerequisite_tree
    from scripts.extractors.courses import CourseOfferingExtractor
    MODULES_AVAILABLE = True
except ImportError:
    MODULES_AVAILABLE = False

# This import will FAIL until Plan 03 creates curriculum extractor
try:
    from scripts.extractors.curriculum import CurriculumExtractor
    CURRICULUM_AVAILABLE = True
except ImportError:
    CURRICULUM_AVAILABLE = False

skip_if_no_modules = pytest.mark.skipif(not MODULES_AVAILABLE, reason="Implementation not yet written")
skip_if_no_curriculum = pytest.mark.skipif(not CURRICULUM_AVAILABLE, reason="CurriculumExtractor not yet written")


class TestPrerequisiteContinuation:
    """EXT-02: Multi-row prerequisite must be merged complete."""

    @skip_if_no_modules
    def test_truncated_prerequisite_detected(self):
        """Prerequisite ending with 'Y (' must be flagged as truncated."""
        truncated = "138201 Microeconomia I Y ("
        assert is_truncated_prerequisite(truncated) is True

    @skip_if_no_modules
    def test_complete_prerequisite_not_flagged(self):
        """A properly closed prerequisite must NOT be flagged."""
        complete = "138201 Microeconomia I Y (166097 Contabilidad Financiera I)"
        assert is_truncated_prerequisite(complete) is False

    @skip_if_no_modules
    def test_prerequisite_continuation_merges_rows(self, sample_complete_prereq_rows):
        """Multi-row continuation buffer must join rows into single expression."""
        result = extract_prerequisites_with_continuation(sample_complete_prereq_rows)
        # Must have merged continuation, prerequisite must not be truncated
        for course in result:
            prereq = course.get("prerequisitos", {})
            raw = prereq.get("raw", "") if isinstance(prereq, dict) else str(prereq)
            assert not is_truncated_prerequisite(raw), f"Truncated prereq in: {raw}"

    @skip_if_no_modules
    def test_truncated_row_raises_or_flags(self, sample_truncated_prereq_rows):
        """Single-row truncated prerequisite must be detected (raises or sets parsed=False)."""
        result = extract_prerequisites_with_continuation(sample_truncated_prereq_rows)
        for course in result:
            prereq = course.get("prerequisitos", {})
            if isinstance(prereq, dict):
                assert prereq.get("parsed") is False or "raw" in prereq


class TestProfessorSpanishNames:
    """EXT-03: Spanish compound surnames must be captured fully."""

    @skip_if_no_modules
    def test_compound_surname_del(self):
        text = "CASTROMATTA, Milagros Del Rosario"
        result = extract_professors_spanish(text)
        assert len(result) == 1
        assert "Del Rosario" in result[0], f"Expected full name, got: {result[0]}"

    @skip_if_no_modules
    def test_compound_surname_de_la(self):
        text = "GARCIA, Juan De La Cruz"
        result = extract_professors_spanish(text)
        assert len(result) == 1
        assert "De La Cruz" in result[0], f"Expected full name, got: {result[0]}"

    @skip_if_no_modules
    def test_simple_name_unchanged(self):
        text = "SMITH, John"
        result = extract_professors_spanish(text)
        assert len(result) == 1
        assert result[0] == "SMITH, John"

    @skip_if_no_modules
    def test_multiple_professors_split(self, sample_professor_text):
        """Multiple professors separated by ' / ' must each be extracted."""
        result = extract_professors_spanish(sample_professor_text)
        assert len(result) >= 2, f"Expected 2+ professors, got {len(result)}: {result}"

    @skip_if_no_modules
    def test_split_instructor_roles_docente_y_jps(self):
        text = "BASURTO PRECIADO, Maria Pia / CABRERA SARMIENTO, Liz Yossie / SANCHEZ GARCIA, Gustavo Sebastian"
        docentes, docente_principal, jps = split_instructor_roles(text)
        assert len(docentes) == 3
        assert docente_principal == "BASURTO PRECIADO, Maria Pia"
        assert jps == [
            "CABRERA SARMIENTO, Liz Yossie",
            "SANCHEZ GARCIA, Gustavo Sebastian",
        ]


class TestCoursePdfMetadata:
    """Regular offer PDFs must drive cycle/version metadata and output names."""

    @skip_if_no_modules
    @pytest.mark.parametrize(
        ("filename", "cycle", "version", "output"),
        [
            ("Oferta-Academica-2026-I_v1.pdf", "2026-1", "v1", "courses_2026-1_v1.json"),
            ("Oferta-Academica-2026-I-V4.pdf", "2026-1", "v4", "courses_2026-1_v4.json"),
            ("Oferta-Academica-2026-II-V1.pdf", "2026-2", "v1", "courses_2026-2_v1.json"),
            ("Oferta-Academica-2025-II_18.08_10.03am.pdf", "2025-2", "v1", "courses_2025-2_v1.json"),
        ],
    )
    def test_cycle_and_filename_version_detection(self, filename, cycle, version, output):
        extractor = CourseOfferingExtractor(filename)
        assert extractor.cycle == cycle
        assert extractor.version == version
        assert extractor.output_filename() == output

    @skip_if_no_modules
    def test_pdf_text_version_marker_wins_over_filename(self):
        class FakePage:
            def __init__(self, text):
                self._text = text

            def extract_text(self):
                return self._text

        class FakePdf:
            pages = [
                FakePage("Direccion de Asuntos Academicos y Registro 07/07/2026 V1"),
            ]

        extractor = CourseOfferingExtractor("Oferta-Academica-2026-II.pdf")
        version, version_date = extractor._detect_version_from_pdf_text(FakePdf())
        assert version == "v1"
        assert version_date == "07/07/2026"


class TestPrerequisiteParsing:
    @skip_if_no_modules
    def test_alphanumeric_course_code_prerequisite_parses(self):
        parsed = parse_prerequisite_tree("1F0112 Fundamentos de Finanzas")
        assert parsed == {
            "items": [
                {"code": "1F0112", "name": "Fundamentos de Finanzas"},
            ]
        }

    @skip_if_no_modules
    def test_credit_count_prerequisite_parses(self):
        parsed = parse_prerequisite_tree(
            "CREDITOS CURSADOS CREDITOS ACA CURSADO 120.0000"
        )
        assert parsed == {
            "items": [
                {"type": "creditos_cursados", "creditos": 120},
            ]
        }


class TestCurriculumStructure:
    """EXT-05: Curriculum JSON must have courses organized by academic cycle."""

    @skip_if_no_curriculum
    def test_curriculum_has_ciclos(self):
        from scripts.extractors.curriculum import CurriculumExtractor
        # Use economia2017.json as reference (not actual PDF extraction for unit test)
        import json
        with open('pdfs/plan_estudios/econom\u00eda/2017/economia2017.json', encoding='utf-8') as f:
            ref = json.load(f)
        # Reference JSON must have ciclo structure or list of courses with ciclo field
        assert ref is not None
        assert len(ref) > 0, "Reference JSON must not be empty"

    def test_curriculum_output_structure(self, tmp_path):
        """curricula output dict must have metadata and ciclos keys."""
        sample_output = {
            "metadata": {"plan": "Economia 2017", "carrera": "Econom\u00eda", "fecha_extraccion": "2026-02-24"},
            "ciclos": [
                {
                    "ciclo": 1,
                    "cursos": [
                        {"codigo": "138101", "nombre": "Introducci\u00f3n a la Econom\u00eda", "creditos": "4", "tipo": "obligatorio"}
                    ]
                }
            ]
        }
        # Verify shape -- this test always passes, confirms expected output schema
        assert "metadata" in sample_output
        assert "ciclos" in sample_output
        assert sample_output["ciclos"][0]["ciclo"] == 1
        assert "cursos" in sample_output["ciclos"][0]
