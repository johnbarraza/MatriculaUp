# Testing Patterns

**Analysis Date:** 2026-02-24

## Test Framework

**Runner:**
- Not detected - No testing framework configured or used in the codebase

**Assertion Library:**
- Not detected - No test assertions present

**Run Commands:**
```bash
# No test infrastructure found
# Manual testing required for all features
```

## Test File Organization

**Location:**
- Not applicable - No test files exist

**Naming:**
- Not applicable - No test file naming convention established

**Structure:**
- Not applicable - No test structure in place

## Test Coverage Status

**Coverage Level:** Zero (0%)

**Untested Components:**
- All application logic in `C:/Users/johnb/Documents/GitHub/MatriculaUp/scripts/matricula_app.py` - No tests
- All utility functions in `C:/Users/johnb/Documents/GitHub/MatriculaUp/scripts/schedule-builder.py` - No tests
- All converter logic in `C:/Users/johnb/Documents/GitHub/MatriculaUp/scripts/convert_excel_to_csv.py` - No tests
- MCP server in `C:/Users/johnb/Documents/GitHub/MatriculaUp/mcp-server-demo/main.py` - No tests

## Critical Untested Areas

**Data Processing (High Risk):**
- `parse_credits()` - No validation of edge cases, empty strings, non-numeric input
- `normalize_str()` - Unicode handling untested, accent removal edge cases
- `_try_read_csv()` - Multiple parsing fallback strategies without validation
- `_normalize_columns()` - Column mapping logic, missing column handling
- Dataframe filtering and grouping operations in `list_courses()`, `add_to_schedule()`

**Conflict Detection (High Risk):**
- `_detect_conflicts_with_new()` - Schedule overlap logic untested
- `_check_overlap_in_schedule()` - Time slot collision detection
- `detect_conflicts()` - Complex conflict classification by type (CLASE/EXAMEN)
- Behavior when schedules have gaps, overlapping ranges

**File I/O (High Risk):**
- `load_from_json()` in `CurriculumData` - No validation of JSON structure
- `load_excel()` method - Multiple code paths for CSV/Excel not validated
- File existence checks not tested
- Exception paths for corrupted files not tested

**UI Logic (Medium Risk):**
- `add_to_schedule()` in `MatriculaApp` - Complex schedule update logic (250+ lines)
- `draw_week_schedule()` - Image generation and visualization (not deterministic)
- Gradio UI callbacks and state management

**Caching (Medium Risk):**
- Cache invalidation in `_invalidate_all_caches()`, `_invalidate_schedule_cache()`
- Cache key generation in `list_courses()`
- No verification that cache keys correctly distinguish different parameters

**State Management (Medium Risk):**
- `update_taken_courses()` - Set updates not validated
- Multi-schedule tracking: `schedules: Dict[int, List[dict]]`
- Credit calculation and accumulation

## Why Testing is Needed

### Impact if Bugs Occur

**Data Integrity:**
- Credits parsing failure → Schedule shows wrong credit totals
- Column normalization failure → Data loading fails silently
- JSON loading exception → Curriculum data lost

**Schedule Conflicts:**
- Overlap detection bug → Users receive conflicting schedules
- Time parsing failure → Visual calendar misaligned
- Type classification error → CLASE and EXAMEN conflicts not separated

**User Experience:**
- Cache not invalidated → Stale search results shown
- UI state inconsistent → Can't add/remove courses properly
- File I/O silent failures → User unsure if operation succeeded

## Manual Testing Approach (Current State)

The codebase relies entirely on manual testing:

1. **Interactive UI Testing:**
   - `matricula_app.py` runs as Gradio web application - tested by user interaction
   - `schedule-builder.py` runs as tkinter GUI - tested by user interaction
   - Manual verification of schedule displays, conflict warnings

2. **File Conversion Testing:**
   - `convert_excel_to_csv.py` run manually with various input files
   - File size comparison logged to console
   - No automated validation of output

3. **Error Scenario Testing:**
   - Done by manually providing invalid files or corrupted data
   - Results observed in UI messagebox or console output

## Recommended Testing Strategy

### Priority 1: Unit Tests for Data Processing

```python
# Suggested test pattern (not currently implemented)
def test_parse_credits():
    assert parse_credits("5.0") == 5.0
    assert parse_credits("5,0") == 5.0
    assert parse_credits("invalid") == 0.0
    assert parse_credits("") == 0.0

def test_normalize_str():
    assert normalize_str("Económía") == "economia"
    assert normalize_str("CURSO III") == "curso iii"
    # Edge cases...

def test_conflict_detection():
    # Time overlap scenarios
    # Type-based conflict logic (CLASE vs EXAMEN)
    # Edge times (7:30, 23:30)
```

### Priority 2: Integration Tests for File I/O

```python
# Test data loading pipeline
def test_load_excel_with_valid_file():
    # Load sample Excel
    # Verify column normalization
    # Verify course count

def test_load_csv_fallback_strategies():
    # Test CSV with different delimiters
    # Test quoting styles
    # Verify fallback chain works
```

### Priority 3: State Machine Tests

```python
# Test schedule addition/removal sequences
def test_add_remove_course_sequence():
    # Add course to empty schedule
    # Add conflicting course (should prompt)
    # Remove first course
    # Verify credits updated
    # Verify cache invalidated
```

## Testing Barriers and Gaps

**No Framework Setup:**
- Would need to add pytest or unittest to requirements
- Would need to configure test discovery and runners

**UI Testing Complexity:**
- Gradio and tkinter require special testing approaches
- Would need pytest-qt or similar for tkinter
- Gradio may need mocking of HTTP requests

**Data Dependencies:**
- Tests would need sample data files (curriculum JSON, schedule CSV/Excel)
- File paths hardcoded in code, making test data injection difficult

**State Coupling:**
- `MatriculaApp` instance carries state across method calls
- Tests would need to manage state setup/teardown
- No obvious dependency injection points for mocking

## Static Analysis Gaps

**No Linting Configuration:**
- No .flake8, .pylintrc, or pyproject.toml linting section
- Could add ruff or pylint configuration to catch style issues

**No Type Checking:**
- Type hints present in code but not validated
- Could add mypy configuration for static type checking

**No Code Formatting:**
- No Black or autopep8 configuration
- Code style varies (some lines 120+ chars)

---

*Testing analysis: 2026-02-24*

## Summary

The MatriculaUp codebase currently has **zero automated testing** and relies entirely on manual UI interaction for validation. While the code has good type hints and docstrings, the lack of tests creates risk in:

1. Data processing edge cases (credit parsing, string normalization)
2. Complex conflict detection logic
3. File I/O error handling
4. Cache invalidation correctness
5. Multi-schedule state management

Recommended starting point: Add pytest infrastructure and write unit tests for utility functions (`parse_credits`, `normalize_str`, conflict detection) before adding integration tests for the full data pipeline.
