import pytest
import re

# These imports will FAIL until Plan 02 creates the modules -- that is correct RED state
try:
    from scripts.extractors.courses import extract_prerequisites_with_continuation, is_truncated_prerequisite
    from scripts.extractors.courses import extract_professors_spanish
    MODULES_AVAILABLE = True
except ImportError:
    MODULES_AVAILABLE = False

skip_if_no_modules = pytest.mark.skipif(not MODULES_AVAILABLE, reason="Implementation not yet written")


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
