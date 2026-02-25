# Domain Pitfalls

**Domain:** PDF table extraction + Python desktop app distribution
**Researched:** 2026-02-24
**Confidence:** MEDIUM-HIGH (pdfplumber issues from GitHub; PyInstaller from official docs; distribution patterns from 2026 comparisons)

---

## Critical Pitfalls

### Pitfall 1: Multi-line Cell Text Truncation in pdfplumber

**What goes wrong:**
Text spanning multiple lines within a single table cell gets split or truncated. The prerequisite field "138201 Microeconomía I Y (166097 Contabilidad Financiera I O [continues next row]" cuts off mid-sentence instead of capturing the full compound logical expression (AND/OR chains).

**Why it happens:**
- pdfplumber's default table detection uses line-based boundaries (`vertical_strategy="lines"`, `horizontal_strategy="lines"`)
- When a cell's content wraps to the next line but there's no horizontal line separating cells in that column, the library treats the continuation as a new row
- The `.crop()` function includes any object with ANY overlap but doesn't track characters already assigned to previous cells, leading to incomplete captures
- When text_y_tolerance is too strict, vertically close but multi-line content within the same cell gets segmented

**How to avoid:**
1. **Before extraction:** Inspect the PDF's table structure. Use `page.find_tables()` with `vertical_strategy="text"` (not just "lines") if cells contain wrapped text
2. **Preserve cell context:** After extraction, post-process cells to detect incomplete sentences (e.g., prerequisite fields ending with "Y (" or "O (" indicate truncation). Implement a "continuation buffer" that checks if the next row's first column is empty — if so, concatenate to the previous row's cell
3. **Tune extraction parameters:** Increase `text_y_tolerance` to group vertically-close text within the same cell boundary. Example:
   ```python
   table_settings = {
       "vertical_strategy": "text",
       "horizontal_strategy": "text",
       "text_y_tolerance": 10,  # Increase from default to capture wrapped lines
       "text_keep_blank_chars": True  # Preserve spacing alignment
   }
   tables = page.extract_tables(table_settings=table_settings)
   ```
4. **Validate completeness:** Check extracted cells for incomplete logical expressions. Prerequisite fields must end with a course code or closing parenthesis, never with "Y ", "O ", or "Y (".

**Warning signs:**
- Extracted prerequisite text ends mid-token (e.g., "Contabilidad Financiera I O")
- Row count increases unexpectedly after extraction (wrapped cell lines treated as separate rows)
- Student data has NULL values in prerequisite field while visual PDF clearly shows text
- Regex validators fail on prerequisite strings (AND/OR chains incomplete)

**Phase to address:** Phase 1 (Extractor Fix) — this must be resolved before distribution, as it directly causes data corruption

---

### Pitfall 2: Regex Failure on Compound Spanish Surnames (Del, De, La)

**What goes wrong:**
Professor names with multi-word surnames using Spanish prepositions (de, del, de la, la) are truncated. "CASTROMATTA, Milagros Del Rosario" appears as "CASTROMATTA, Milagros" or just "CASTROMATTA". The regex pattern expecting `[A-Z][a-z]+` fails when a lowercase preposition (`del`, `de`) appears mid-name.

**Why it happens:**
- Standard name regex patterns assume: `LASTNAME, Firstname Middlename` format where each part is capitalized
- Spanish names often use lowercase prepositions that break the capitalization assumption: "Del Rosario" has a lowercase "el" after the space
- The regex `([A-Z][a-z]*\s)+` stops matching at the lowercase "d" in "del"
- No lookahead validation to detect incomplete name parsing (e.g., missing the suffix)

**How to avoid:**
1. **Use locale-aware name parsing:** Replace naive regex with a proper approach:
   ```python
   import re

   # Account for Spanish prepositions: de, del, de la, de los, la, las, y
   # Pattern: (LASTNAME, Firstname [Prefix]+ Suffix)*
   spanish_prepositions = {'de', 'del', 'de la', 'de los', 'da', 'la', 'las', 'y'}

   def parse_professor_name(raw_text):
       # Remove extra whitespace
       raw_text = re.sub(r'\s+', ' ', raw_text.strip())

       # Split on comma
       if ',' not in raw_text:
           return {'lastname': raw_text.strip()}

       lastname, rest = raw_text.split(',', 1)
       parts = rest.strip().split()

       # Reconstruct firstname respecting prepositions
       firstname_parts = []
       for part in parts:
           # Check if part is a Spanish preposition (case-insensitive)
           if part.lower() in spanish_prepositions or part == 'y':
               firstname_parts.append(part)
           # Check if it starts uppercase (name component) or is short (middle initial)
           elif part[0].isupper() or len(part) == 1:
               firstname_parts.append(part)
           else:
               break

       return {
           'lastname': lastname.strip(),
           'firstname': ' '.join(firstname_parts)
       }

   # Test
   name = "CASTROMATTA, Milagros Del Rosario"
   print(parse_professor_name(name))
   # Output: {'lastname': 'CASTROMATTA', 'firstname': 'Milagros Del Rosario'}
   ```
2. **Validate parsed names:** After extraction, check for incomplete names (e.g., fewer than 2 words in firstname, missing capitalization pattern). Flag for manual review.
3. **Store raw PDF text:** Keep original PDF text alongside parsed data for comparison/recovery.
4. **Document edge cases:** Create a lookup table of known professor names with special characters to validate against.

**Warning signs:**
- Extracted professor names are shorter than expected (e.g., 2 words instead of 3+)
- Names ending with lowercase letters like "del", "de", "la"
- Student schedules show professor names inconsistently (some entries truncated, others complete)
- Professor name fields have orphaned prepositions (e.g., just "del" or "de")

**Phase to address:** Phase 1 (Extractor Fix) — affects data integrity

---

### Pitfall 3: Missing or Incorrect Table Boundaries in pdfplumber

**What goes wrong:**
Entire rows at the top or bottom of a table are dropped. The first row of a course list disappears, or the last prerequisite row is cut off. This happens because pdfplumber misses the table's boundary line.

**Why it happens:**
- pdfplumber defaults to `vertical_strategy="lines"` and `horizontal_strategy="lines"`, meaning it searches for explicit vector graphics (drawn lines) to define table boundaries
- PDFs generated by different software (e.g., LibreOffice vs. Adobe) may use thin lines, dashed borders, or no borders at all
- When the top or bottom horizontal line is faint, missing, or rendered as a different element type, the table detection algorithm ignores it
- `find_tables()` returns the table without the missing boundary row, silently losing data

**How to avoid:**
1. **Inspect boundary lines before extraction:**
   ```python
   # Visualize what pdfplumber sees
   table_settings = {"vertical_strategy": "lines", "horizontal_strategy": "lines"}
   tables = page.find_tables(table_settings=table_settings)

   # Check if table top/bottom align with document geometry
   if tables:
       first_table = tables[0]
       bbox = first_table.bbox  # (x0, y0, x1, y1)
       print(f"Table bbox: {bbox}")

       # Verify top row exists
       first_row = first_table.rows[0] if first_table.rows else None
       if first_row and first_row.y0 > bbox[1] + 5:  # Large gap = missing top row
           print("WARNING: Possible missing top row")
   ```
2. **Use explicit line definitions when boundaries are faint:**
   ```python
   # Manually define horizontal lines if not detected
   explicit_settings = {
       "vertical_strategy": "text",
       "horizontal_strategy": "text",
       "explicit_horizontal_lines": [page.bbox[1], page.bbox[3]],  # Top and bottom of page
       "explicit_vertical_lines": [page.bbox[0], page.bbox[2]],    # Left and right
   }
   ```
3. **Fall back to text-based detection:** If line-based detection fails, use character positioning:
   ```python
   table_settings = {
       "vertical_strategy": "text",
       "horizontal_strategy": "text",
       "min_words_vertical": 1,
       "min_words_horizontal": 1,
   }
   tables = page.extract_tables(table_settings=table_settings)
   ```
4. **Validate row count:** After extraction, compare expected row count (from known data) with extracted row count. Missing rows should trigger a detailed inspection.

**Warning signs:**
- Extracted table row count is less than visually counted rows in PDF
- First or last row contains NULL or empty values while adjacent rows have data
- Table structure appears incomplete in visual inspection vs. extraction
- `page.find_tables()` returns fewer tables than expected

**Phase to address:** Phase 1 (Extractor Fix) — critical for data integrity

---

### Pitfall 4: Hidden Import Dependencies in PyInstaller Bundle

**What goes wrong:**
When bundling the app with PyInstaller, the executable starts but crashes immediately with `ModuleNotFoundError` for pdfplumber, pandas, or cryptic sub-module imports like `pdfplumber._utils` or `pandas._libs.tslibs`. The app works fine in development but fails in the frozen executable.

**Why it happens:**
- PyInstaller uses static analysis to find imports by parsing the AST (Abstract Syntax Tree) of Python files
- pdfplumber and pandas use dynamic imports (e.g., `__import__()`, `importlib.import_module()`) that PyInstaller cannot detect
- pandas specifically loads C extensions from `pandas._libs` dynamically; PyInstaller misses these
- The `.spec` file does not include `collect_submodules('pandas')` or explicit hidden imports
- On non-Windows systems (Linux, macOS), symbolic links in the bundle directory can be destroyed by the archive tool (zip), duplicating files and causing import issues

**How to avoid:**
1. **Create a PyInstaller spec file with explicit hidden imports:**
   ```python
   # pyinstaller_spec.py
   a = Analysis(
       ['scripts/matricula_app.py'],
       pathex=[],
       binaries=[],
       datas=[('data/courses.json', 'data')],  # Include bundled JSON
       hiddenimports=[
           'pdfplumber',
           'pdfplumber.utils',
           'pdfplumber.table',
           'pdfplumber.convert',
           'pdfplumber.pdf',
           'pdfplumber.page',
           'pandas',
           'pandas._libs.tslibs',
           'pandas.core.arrays.datetimes',
       ],
       hookspath=[],
       hooksconfig={},
       runtimeHooks=[],
       excludedimports=[],
       win_no_prefer_redirects=False,
       win_private_assemblies=False,
       cipher=None,
       noarchive=False,
   )
   ```
2. **Use collect_submodules() for dynamic imports:**
   ```python
   from PyInstaller.utils.hooks import collect_submodules

   a = Analysis(
       ['scripts/matricula_app.py'],
       hiddenimports=collect_submodules('pandas') + collect_submodules('pdfplumber'),
   )
   ```
3. **Test in virtual environment before bundling:**
   ```bash
   python -m venv test_bundle
   source test_bundle/bin/activate  # Windows: test_bundle\Scripts\activate
   pip install pdfplumber pandas gradio
   pyinstaller --onefile scripts/matricula_app.py --hidden-import=pdfplumber --hidden-import=pandas
   dist/matricula_app.exe  # Test the executable
   ```
4. **Document all dependencies explicitly:** Create a `requirements-freeze.txt` with exact versions to ensure reproducible bundles.

**Warning signs:**
- App works in dev, crashes on `import pdfplumber` in frozen executable
- Error: `ModuleNotFoundError: No module named 'pandas._libs.tslibs'`
- Tests pass locally but fail after PyInstaller bundling
- Spec file has empty `hiddenimports` list

**Phase to address:** Phase 2 (Desktop App Bundle) — must be resolved before distribution

---

### Pitfall 5: PyInstaller One-File Bundle Performance Degradation

**What goes wrong:**
The frozen executable built with `--onefile` flag runs very slowly on each startup, sometimes taking 30+ seconds to initialize. The app works but feels unresponsive compared to development.

**Why it happens:**
- `--onefile` creates a single-file bundle, but internally it extracts everything to a temporary directory on each run
- The operating system (especially Windows Defender) performs full antivirus scans on the temporary extraction directory
- Each startup requires unpacking the entire bundle (pdfplumber, pandas, JSON data files) before the app can initialize
- macOS similarly penalizes one-file bundles with Gatekeeper scanning and code-signing delays

**How to avoid:**
1. **Use `--onedir` instead of `--onefile`:**
   ```bash
   pyinstaller --onedir --windowed --name "MatriculaUp" scripts/matricula_app.py
   # Result: dist/MatriculaUp/ directory (not a single exe)
   ```
   **Trade-off:** Larger footprint for distribution (directory vs. single file) but much faster startup.

2. **If one-file is required, optimize the bundle:**
   ```bash
   pyinstaller --onefile \
       --upx-dir=/path/to/upx \
       --noupx  # Actually, disable UPX compression—it often breaks things
   ```

3. **For Windows distribution, create an installer:**
   Instead of distributing a bare `.exe`, use NSIS or InnoSetup to create an installer that extracts the onedir bundle to the user's Program Files. This avoids repeated extraction and allows proper caching:
   ```bash
   # Build onedir
   pyinstaller --onedir scripts/matricula_app.py

   # User installs once via installer
   # App runs fast every time (already extracted)
   ```

4. **Test startup time before shipping:**
   ```bash
   time ./dist/MatriculaUp/MatriculaUp.exe  # Measure cold startup
   ```

**Warning signs:**
- Executable with `--onefile` takes >5 seconds to show UI on first run
- Antivirus software slows startup to 20+ seconds
- Users report "app is hanging" when launching
- macOS app bundle rejected by Gatekeeper on first run

**Phase to address:** Phase 2 (Desktop App Bundle) — affects user experience

---

### Pitfall 6: File Path Hardcoding in Bundled Data

**What goes wrong:**
The frozen app includes course data in `data/courses.json`, but the code has hardcoded paths like `C:\Users\johnb\Documents\MatriculaUp\data\courses.json` or absolute paths. When distributed, the path is invalid and the app crashes trying to load course data.

**Why it happens:**
- Development setup uses absolute file paths that are specific to the developer's machine
- When bundled, PyInstaller changes the working directory and file locations
- Hardcoded paths don't account for the `--onedir` vs `--onefile` directory structure difference
- Windows and Linux have different path separators (`\` vs. `/`), leading to platform-specific bugs

**How to avoid:**
1. **Use `sys._MEIPASS` in PyInstaller-bundled apps to find data files:**
   ```python
   import sys
   import os
   import json

   def get_resource_path(filename):
       """
       Return path to a bundled resource file.
       In dev: returns relative path
       In PyInstaller bundle: returns path relative to _internal directory
       """
       if getattr(sys, 'frozen', False):
           # Running in PyInstaller bundle
           base_path = sys._MEIPASS
       else:
           # Running in dev
           base_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

       return os.path.join(base_path, 'data', filename)

   # Usage
   courses_file = get_resource_path('courses.json')
   with open(courses_file) as f:
       courses = json.load(f)
   ```

2. **Declare data files in PyInstaller spec:**
   ```python
   a = Analysis(
       ['scripts/matricula_app.py'],
       datas=[('data/courses.json', 'data'), ('data/2017_plan.json', 'data')],
   )
   ```

3. **Test paths in both dev and bundled contexts:**
   ```bash
   # Dev test
   python scripts/matricula_app.py

   # Bundled test
   pyinstaller --onedir scripts/matricula_app.py
   ./dist/MatriculaUp/MatriculaUp
   ```

4. **Use pathlib for cross-platform compatibility:**
   ```python
   from pathlib import Path

   courses_file = Path(sys._MEIPASS) / 'data' / 'courses.json'
   # or in dev:
   courses_file = Path(__file__).parent.parent / 'data' / 'courses.json'
   ```

**Warning signs:**
- App works in development, crashes on startup in bundled version with FileNotFoundError
- Error message: `No such file or directory: C:\Users\johnb\...`
- Course data fails to load (app shows empty course list)
- Different behavior on Windows vs. macOS/Linux

**Phase to address:** Phase 2 (Desktop App Bundle) — must be fixed before release

---

## Moderate Pitfalls

### Pitfall 7: PDF Encoding and Character Set Mismatches

**What goes wrong:**
Special characters in professor names or course descriptions are mangled. "Microeconomía" appears as "Microeconom?a" or corrupted Unicode. Spanish accents are lost.

**Why it happens:**
- PDFs may use different encodings (UTF-8, Latin-1, Windows-1252)
- pdfplumber doesn't always auto-detect encoding correctly
- Extracted text has encoding mismatches when written to JSON

**How to avoid:**
- Always specify encoding when writing output: `open(file, encoding='utf-8')`
- Validate extracted text for common encoding issues and log warnings
- Test with sample PDFs containing special characters early in Phase 1

---

### Pitfall 8: Regex Lookahead/Lookbehind Performance with Large Text

**What goes wrong:**
Extracting and validating 1000+ courses with complex regex patterns causes the extraction phase to take minutes instead of seconds.

**Why it happens:**
- Nested regex with lookahead/lookbehind (`(?<=...)`, `(?=...)`) has exponential backtracking on large strings
- Prerequisite chains can be very long (50+ character OR/AND chains)

**How to avoid:**
- Use simpler regex or split/join logic instead of complex patterns
- Profile regex performance: `import timeit; timeit.timeit(lambda: pattern.search(text), number=1000)`
- For prerequisite parsing, use tokenization instead of regex:
  ```python
  tokens = prerequisite_text.split()  # Split on whitespace
  # Parse tokens sequentially (course code, operator, etc.)
  ```

**Phase to address:** Phase 1 (Extractor optimization)

---

### Pitfall 9: Tkinter/Gradio Thread Safety in Bundled App

**What goes wrong:**
If the app uses threading to load courses while the UI updates, the frozen executable crashes with "thread safety" errors that don't occur in development.

**Why it happens:**
- PyInstaller may change threading behavior due to module loading timing
- Tkinter is not thread-safe; GUI updates from non-main threads crash in bundled context

**How to avoid:**
- Use `queue.Queue` to communicate between threads and main UI thread
- Move all file I/O and PDF extraction to background threads, post results to GUI via queue
- Test threading behavior before bundling

**Phase to address:** Phase 2 (Desktop App Bundle)

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcoded table settings for one PDF | Quick extraction | Fails on different PDF layouts or new cycles | Never—use learned parameters from Phase 1 testing |
| Skip prerequisite validation | Faster extraction | Data corruption, student confusion | Never—prerequisites are core data |
| Extract to CSV instead of JSON | Easier to inspect | Can't represent hierarchical data (N sessions per course) | Only for Phase 1 prototyping, must migrate to JSON |
| Distribute as `--onefile` without installer | Simpler distribution (one file) | Slow startup, antivirus delays, user frustration | For internal testing only; use installer or `--onedir` for release |
| Skip testing bundle on target machines | Saves time | App fails on end-user Windows/Mac | Never—always test on target platform |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| pdfplumber ↔ pandas | Assuming `extract_tables()` returns clean DataFrames | Post-process: validate cell types, handle multi-line cells, check for NULLs |
| JSON data ↔ Desktop app | Bundling JSON as-is without versioning | Include version field in JSON; validate on app startup; alert if mismatch |
| PDF extraction ↔ GitHub releases | Generating extraction each release cycle | Extract once per stable cycle; commit JSON to releases; only regenerate if PDF changes |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Loading all courses into memory at startup | App is sluggish, uses 200+ MB RAM | Lazy-load or paginate course list; index by course code | >5000 courses or on low-memory systems |
| Regex validation on every course load | Each course load triggers expensive regex | Pre-compile regex patterns; validate once at extraction time, not on every app load | >1000 courses; startup time >3 seconds |
| PyInstaller `--onefile` without UPX | Slow first startup (20+ seconds on antivirus scan) | Use `--onedir` or distribute installer; disable UPX | Every user launch |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Bundling academic plan data without tamper detection | Users can modify JSON to fake course completion | Add file hash validation on app startup; compare with known-good hash from GitHub |
| Storing extracted professor contact info in plaintext JSON | Privacy risk if JSON is shared | Don't extract email/phone; only include name + office (already public in PDF) |
| Signed PyInstaller executable from unknown source | Users unsure if app is legitimate | Code-sign the executable with development org certificate; document signature process |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| "Loading courses..." with no progress bar while extracting large PDF | User thinks app is frozen | Show loading animation; provide cancel button; extract in background thread |
| Error messages from pdfplumber are opaque ("ValueError in table detection") | User confused, no clear action | Catch exceptions and show user-friendly message: "Failed to read course data. Check PDF is up to date." |
| Prerequisite display in raw form (e.g., "138201 Y (166097 O 166098)") | Hard for students to parse | Display as human-readable text: "Microeconomics I AND (Accounting I OR Accounting II)" |

---

## "Looks Done But Isn't" Checklist

- [ ] **Extractor**: Extracted data for all 7 careers (admin, derecho, economía, finanzas, humanidades_digitales, ingre_empre, polit_filo_eco) — verify at least one course from each has prerequisites with AND/OR
- [ ] **Professor names**: Sampled 50 professor names for truncation (e.g., names ending in lowercase prepositions) — none should be cut off
- [ ] **Desktop app**: Executable runs on clean Windows 10/11 machine without Python installed — test on VM
- [ ] **Data bundling**: JSON file is readable from bundled app on all target platforms (Windows/macOS/Linux if supporting) — no hardcoded paths
- [ ] **Edge case curricula**: Tested with 2017, 2020, 2023 plan versions — no crashes on older/newer data formats

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Truncated prerequisite discovered after release | MEDIUM | Re-extract with fixed settings; rebuild executable; push GitHub release with corrected JSON |
| Multi-line professor names truncated in live data | MEDIUM | Patch JSON manually for known names; regenerate extractor; update bundle |
| Bundled JSON path hardcoded, app crashes on user machine | HIGH | Rebuild executable with sys._MEIPASS fix; re-distribute; notify users |
| Hidden import (pandas._libs) missing, executable won't start | HIGH | Update .spec file; rebuild; re-test on clean machine; re-distribute |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Multi-line cell text truncation | Phase 1 (Extractor Fix) | Extract all courses, verify no prerequisites end mid-token |
| Spanish compound surname regex failure | Phase 1 (Extractor Fix) | Manual review of 50+ extracted professor names; check for truncation |
| Missing table boundaries | Phase 1 (Extractor Fix) | Compare row count: visual vs. extracted (should match ±1) |
| Hidden imports in PyInstaller | Phase 2 (Desktop App Bundle) | Run bundled executable on clean test machine; check for ModuleNotFoundError |
| One-file startup performance | Phase 2 (Desktop App Bundle) | Measure startup time: must be <5 seconds on target hardware |
| Hardcoded file paths in bundle | Phase 2 (Desktop App Bundle) | Test with `sys._MEIPASS`; verify same code runs in dev and bundled contexts |
| PDF encoding mismatches | Phase 1 (Extractor Fix) | Sample UTF-8 special characters from output; no "?" or garbled text |
| Regex performance on large datasets | Phase 1 (Extractor optimization) | Profile extraction time; must complete <30 seconds for full 2026-1 cycle |
| Thread safety in bundled app | Phase 2 (Desktop App Bundle) | Run bundled app with heavy concurrent operations; no thread-safety crashes |
| File path hardcoding in bundles | Phase 2 (Desktop App Bundle) | Distribute executable without source; verify course data loads correctly |

---

## Sources

**pdfplumber-specific:**
- [pdfplumber GitHub Issues — Multirows in one Cell](https://github.com/jsvine/pdfplumber/issues/19)
- [pdfplumber GitHub Discussion — Text extraction in combination with tables](https://github.com/jsvine/pdfplumber/discussions/1026)
- [pdfplumber GitHub Discussion — Table extraction settings](https://github.com/jsvine/pdfplumber/discussions/1071)
- [pdfplumber Official Docs — Can PDFPlumber Extract Tables from PDFs?](https://www.pdfplumber.com/can-pdfplumber-extract-tables-from-pdfs/)
- [pdfplumber GitHub Issue — Multirows in one Cell](https://github.com/jsvine/pdfplumber/issues/19)
- [pdfplumber GitHub Discussion — Missed table top horizontal line](https://github.com/jsvine/pdfplumber/discussions/1243)

**PyInstaller and distribution:**
- [PyInstaller 6.19.0 Official Documentation — Common Issues and Pitfalls](https://pyinstaller.org/en/stable/common-issues-and-pitfalls.html)
- [PyInstaller with Pandas — Problems, solutions, and workflow with code examples (Medium)](https://medium.com/@lironsoffer/pyinstaller-with-pandas-problems-solutions-and-workflow-with-code-examples-c72973e1e23f)
- [How to package and distribute your Python Desktop App (Medium)](https://medium.com/@saschaschwarz_8182/how-to-package-and-distribute-your-python-desktop-app-f47f44855a37)
- [2026 Showdown: PyInstaller vs. cx_Freeze vs. Nuitka For Python EXE Builds](https://ahmedsyntax.com/2026-comparison-pyinstaller-vs-cx-freeze-vs-nui/)
- [From Python Script to Stand-Alone EXE: A Practical Guide with PyInstaller and Nuitka (Medium)](https://medium.com/@jasonyang.algo/from-python-script-to-stand-alone-exe-a-practical-guide-with-pyinstaller-and-nuitka-cf0dd81271dc)

**Spanish naming conventions:**
- [The Correct Order for Spanish Surnames — Family Tree Magazine](https://familytreemagazine.com/heritage/central-south-american/how-to-list-spanish-surnames/)
- [Parsing names — Marco Barisione's blog](https://blog.barisione.org/2009/06/18/parsing-names/)
- [Parse Name and Address: Regex vs NER, with Code Examples — DEV Community](https://dev.to/oursky/parse-name-and-address-regex-vs-ner-with-code-examples-3gdp)
- [Spanish naming customs — Wikipedia](https://en.wikipedia.org/wiki/Spanish_naming_customs)

---

*Pitfalls research for: PDF table extraction + Python desktop app distribution*
*Researched: 2026-02-24*
*Confidence: MEDIUM-HIGH (official docs + GitHub issues + community patterns)*
