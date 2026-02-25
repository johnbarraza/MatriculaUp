# Architecture Research: PDF-to-JSON Pipeline + Desktop App

**Domain:** Educational course scheduling app with PDF extraction pipeline
**Researched:** 2026-02-24
**Confidence:** HIGH (for component separation and bundling), MEDIUM (for JSON schema design details)

## Executive Summary

MatriculaUp requires a **three-layer architecture** separating concerns between extraction, data management, and UI:

1. **Extraction Layer (Python CLI)** — Stateless PDF→JSON converter, decoupled from the app
2. **Data Layer (Bundled JSON)** — Pre-extracted course data versioned with the app distribution
3. **UI Layer (Tauri Desktop)** — Read-only consumer of bundled JSON data

This separation means the extractor runs once per semester (offline), producing validated JSON, while the app distributes without Python dependencies. Build order: **Schema first (defines contracts), then fix extractor, then build UI.**

---

## Recommended Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────────────┐
│                           UI LAYER (Tauri)                              │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐            │
│  │ Course Search  │  │ Schedule View   │  │ Plan Tracker   │            │
│  │ & Filter       │  │ & Conflict      │  │ & Progress     │            │
│  │                │  │ Detection       │  │                │            │
│  └────────┬───────┘  └────────┬───────┘  └────────┬───────┘            │
│           │                    │                    │                    │
├───────────┴────────────────────┴────────────────────┴────────────────────┤
│                         DATA ACCESS LAYER                                │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ JSON Data Store (Embedded / Loaded at Startup)                 │   │
│  │ • courses.json (courses, sections, sessions)                  │   │
│  │ • prerequisites.json (course dependencies + AND/OR logic)     │   │
│  │ • curricula.json (study plans by program & year)              │   │
│  └──────────────────────────────────────────────────────────────────┘   │
├───────────────────────────────────────────────────────────────────────────┤
│              EXTRACTION LAYER (Separate Python CLI)                       │
│  ┌─────────────────────────────────────────────────────────────────┐     │
│  │ PDF Extractor (pdfplumber)                                      │     │
│  │ ├── PDF Parser → structured text extraction                    │     │
│  │ ├── Course Builder (course ID, name, credits, prerequisites)  │     │
│  │ ├── Section Builder (section number, capacity)                │     │
│  │ ├── Session Mapper (day, time, room, instructor, type)        │     │
│  │ └── JSON Output (versioned, one file per semester)            │     │
│  └─────────────────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────────────────┘

KEY: UI never touches PDFs | Extraction never touches UI | Data Layer is source of truth
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|---|---|
| **UI Layer (Tauri)** | Render UI, handle user interactions, detect schedule conflicts | TypeScript/React + Tauri; reads from embedded JSON |
| **Data Access** | Load, cache, and query bundled course/prerequisite data | In-memory store loaded once at app startup; no database |
| **Extraction Layer (CLI)** | Parse PDFs, validate course structure, output versioned JSON | Python CLI tool; runs offline, invoked by build script; not shipped with app |
| **JSON Storage (Bundled)** | Pre-extracted course data distributed with app release | Static JSON files embedded in Tauri resources/ directory |
| **Prerequisite Resolver** | Evaluate AND/OR prerequisite logic to determine course eligibility | Tauri-side logic (simple tree evaluation) or embedded in prerequisites.json metadata |

---

## Data Layer: JSON Schema Design

### Top-Level Structure

```json
{
  "metadata": {
    "semester": "2026-1",
    "program": "economia",
    "plan_year": "2017",
    "extracted_date": "2026-02-15",
    "extractor_version": "2.0.0",
    "data_version": "2026-1.v1"
  },
  "courses": [...],
  "prerequisites": {...},
  "curricula": {...}
}
```

### Course Entity Schema

```json
{
  "courseId": "138201",
  "name": "Microeconomía I",
  "credits": 4,
  "department": "Economía",
  "sections": [
    {
      "sectionId": "138201-01",
      "sectionNumber": 1,
      "capacity": 40,
      "instructor": "García López, Rosa María",
      "sessions": [
        {
          "sessionId": "138201-01-CLASE-1",
          "type": "CLASE",
          "day": "Monday",
          "startTime": "09:00",
          "endTime": "11:00",
          "room": "A302",
          "building": "Pabellón A"
        },
        {
          "sessionId": "138201-01-CLASE-2",
          "type": "CLASE",
          "day": "Wednesday",
          "startTime": "09:00",
          "endTime": "11:00",
          "room": "A302",
          "building": "Pabellón A"
        },
        {
          "sessionId": "138201-01-PRACTICA-1",
          "type": "PRACTICA",
          "day": "Friday",
          "startTime": "14:00",
          "endTime": "15:30",
          "room": "A305",
          "building": "Pabellón A"
        }
      ]
    }
  ],
  "prerequisiteId": "prereq_138201"
}
```

**Design rationale:**
- **Flat session list within section:** Easier to query "all sessions for this section," simpler conflict detection
- **Session types as enum:** CLASE, PRACTICA, PRACDIRIGIDA, PRACCALIFICADA, FINAL, PARCIAL, CANCELADA — normalized, searchable
- **Time as HH:MM (24-hour):** ISO-like format for parsing; no timezone ambiguity (all times are Lima local)
- **Building + Room:** Allows future "building distance" optimization for between-class navigation

### Prerequisite Schema (Complex Logic Handling)

```json
{
  "prerequisites": {
    "prereq_138201": {
      "courseId": "138201",
      "logic": {
        "type": "AND",
        "conditions": [
          {
            "type": "course",
            "courseId": "137102",
            "courseName": "Introducción a la Economía",
            "requiredGrade": null,
            "status": "required"
          },
          {
            "type": "OR",
            "conditions": [
              {
                "type": "course",
                "courseId": "166097",
                "courseName": "Contabilidad Financiera I"
              },
              {
                "type": "course",
                "courseId": "166098",
                "courseName": "Contabilidad Financiera II"
              }
            ]
          }
        ]
      },
      "notes": "Puede inscribirse si ha aprobado Introducción a la Economía Y (Contabilidad I O Contabilidad II)"
    }
  }
}
```

**Design rationale:**
- **Recursive nested structure:** Native representation of AND/OR logic without truncation
- **Type discriminators (AND/OR/course):** Parser-friendly; enables tree-walking evaluation algorithm
- **courseId + courseName:** Redundancy allows UI to show human-readable prerequisite chains without separate lookup
- **status field:** Flags co-requisites, recommended vs. required (future expansion)

**Evaluation algorithm (pseudo-code, Tauri side):**

```typescript
function meetsPrerequisites(logic: PrereqLogic, completedCourses: Set<string>): boolean {
  if (logic.type === 'course') {
    return completedCourses.has(logic.courseId);
  }

  const results = logic.conditions.map(c => meetsPrerequisites(c, completedCourses));

  if (logic.type === 'AND') return results.every(r => r);
  if (logic.type === 'OR') return results.some(r => r);

  return false;
}
```

### Curricula (Study Plan) Schema

```json
{
  "curricula": [
    {
      "programId": "economia",
      "programName": "Economía",
      "planYear": 2017,
      "semesters": [
        {
          "semester": 1,
          "courses": [
            {
              "courseId": "137102",
              "name": "Introducción a la Economía",
              "credits": 4,
              "type": "required"
            }
          ]
        },
        {
          "semester": 2,
          "courses": [
            {
              "courseId": "138201",
              "name": "Microeconomía I",
              "credits": 4,
              "type": "required"
            }
          ]
        }
      ]
    }
  ]
}
```

**Design rationale:**
- **Flat semesters array:** Linear progression through curriculum; easy to query "what should I take in semester 3?"
- **courseId references:** Links back to course definitions in the courses array; enables UI to show prerequisites for curriculum courses
- **type field:** Distinguishes required, elective, concentration, etc. for future UI filtering

---

## Recommended Project Structure

```
MatriculaUp/
├── .planning/
│   ├── research/
│   │   └── ARCHITECTURE.md        # (this file)
│   └── roadmap/                   # Generated by orchestrator
│
├── extractor/                     # Python CLI — NOT shipped with app
│   ├── src/
│   │   ├── main.py               # Entry point: python -m extractor --pdf <path> --output <path>
│   │   ├── pdf_parser.py         # pdfplumber-based parsing
│   │   ├── course_builder.py     # Course → Section → Session mapping
│   │   ├── prerequisite_builder.py # Logic tree construction (AND/OR handling)
│   │   ├── models.py             # Pydantic models for validation
│   │   ├── validators.py         # Data quality checks
│   │   └── json_serializer.py    # Output formatting & versioning
│   ├── tests/
│   │   ├── test_pdf_parser.py
│   │   ├── test_prerequisite_logic.py
│   │   └── fixtures/             # Sample PDFs for testing
│   ├── requirements.txt
│   ├── setup.py                  # For running as CLI tool
│   └── README.md                 # "Run this to extract PDFs"
│
├── app/                           # Tauri desktop app (shipped with bundled data)
│   ├── src/
│   │   ├── main.rs              # Tauri window setup
│   │   ├── lib.rs               # Tauri commands (Rust backend)
│   │   ├── commands/
│   │   │   ├── courses.rs       # List, search, filter courses
│   │   │   ├── sections.rs      # Get sections for course
│   │   │   ├── conflicts.rs     # Detect schedule conflicts
│   │   │   └── curriculum.rs    # Get study plan for program/year
│   │   └── models/              # Shared types (mirrors JSON schema)
│   │
│   ├── src-tauri/
│   │   ├── tauri.conf.json      # Bundle config (points to resources/)
│   │   ├── capabilities/
│   │   └── permissions/
│   │
│   ├── src-ui/                  # TypeScript/React frontend
│   │   ├── components/
│   │   │   ├── CourseSearch.tsx
│   │   │   ├── SectionSelector.tsx
│   │   │   ├── ScheduleView.tsx
│   │   │   ├── ConflictAlert.tsx
│   │   │   └── PlanTracker.tsx
│   │   ├── hooks/
│   │   │   ├── useLoadCourses.ts    # Load bundled JSON on mount
│   │   │   ├── useScheduleConflicts.ts
│   │   │   └── usePrerequisites.ts  # Prerequisite evaluation
│   │   ├── types/
│   │   │   └── index.ts            # TypeScript mirrors of JSON schema
│   │   ├── App.tsx
│   │   └── main.tsx
│   │
│   ├── resources/                # Bundled data (embedded in final .exe)
│   │   ├── 2026-1/              # One folder per semester/cycle
│   │   │   ├── courses.json     # ← Extracted by CLI, committed to repo
│   │   │   ├── prerequisites.json
│   │   │   └── curricula.json
│   │   └── latest-version.txt   # Version string for update checks (v2)
│   │
│   ├── package.json
│   ├── Cargo.toml
│   └── vite.config.ts
│
├── docs/
│   ├── EXTRACTION_GUIDE.md      # How to run extractor for new semester
│   ├── JSON_SCHEMA.md           # Detailed schema docs
│   └── ARCHITECTURE.md
│
└── README.md
```

### Structure Rationale

- **`extractor/` (separate):** Python extraction tool lives in its own module with independent testing. Not installed in Tauri app; run as a build step.
- **`app/src-tauri/`:** Rust backend for Tauri commands (courses lookup, conflict detection).
- **`app/src-ui/`:** TypeScript/React frontend; components mirror UI mockups.
- **`app/resources/`:** Bundled JSON files. Tauri includes these in the final executable using the `resources` bundle configuration.
- **`docs/`:** Clear instructions for extracting new semesters and understanding the schema.

---

## Architectural Patterns

### Pattern 1: Extract-Once, Distribute-Many

**What:** PDF extraction happens offline, once per semester. Output is committed to version control. The desktop app distributes pre-extracted JSON; no extraction happens on user machines.

**When to use:** Educational apps, catalog-based systems, publish-subscribe data models.

**Trade-offs:**
- ✅ Users get instant startup (no PDF parsing delay)
- ✅ No Python runtime dependency in distributed app
- ✅ Extraction bugs caught before distribution
- ✅ Easy to test extraction separately
- ❌ Updates require new app release (mitigated in v2 with GitHub-based updates)
- ❌ Storage overhead for large catalogs (acceptable for course data)

**Example workflow:**

```bash
# Step 1: Run extraction (dev machine, once per semester)
cd extractor
python -m extractor --pdf ../pdfs/matricula/2026-1/Oferta.pdf \
  --output ../app/resources/2026-1/courses.json \
  --prerequisites-output ../app/resources/2026-1/prerequisites.json

# Step 2: Validate output
python -m pytest tests/

# Step 3: Commit JSON to repo
git add app/resources/2026-1/
git commit -m "Extract 2026-1 course data"

# Step 4: Build Tauri app (JSON automatically bundled)
cd app
npm run build

# Result: app.exe contains embedded JSON, ready to distribute
```

### Pattern 2: Read-Only Data Access with In-Memory Caching

**What:** At app startup, load all bundled JSON into memory. All queries (search, filter, conflict detection) operate on in-memory structures. No database, no writes.

**When to use:** Catalog-style apps, single-semester workflows, offline-first tools.

**Trade-offs:**
- ✅ No database complexity
- ✅ Instant queries (no I/O)
- ✅ Serializes well to JSON; easy to debug and inspect
- ❌ Large datasets (>100K courses) need memory optimization
- ❌ No multi-user sync (but not a requirement for v1)

**Example (Tauri command):**

```rust
// src/commands/courses.rs
use serde_json::Value;

static COURSES_DATA: Lazy<Value> = Lazy::new(|| {
  let json_str = include_str!("../../resources/2026-1/courses.json");
  serde_json::from_str(json_str).expect("courses.json is invalid")
});

#[tauri::command]
fn search_courses(query: String) -> Vec<Course> {
  COURSES_DATA
    .get("courses")
    .and_then(|c| c.as_array())
    .unwrap_or(&vec![])
    .iter()
    .filter(|course| {
      let name = course.get("name").and_then(|n| n.as_str()).unwrap_or("");
      let code = course.get("courseId").and_then(|c| c.as_str()).unwrap_or("");
      name.to_lowercase().contains(&query.to_lowercase()) ||
      code.contains(&query)
    })
    .map(|course| serde_json::from_value(course.clone()).unwrap())
    .collect()
}
```

### Pattern 3: Hierarchical Prerequisite Logic as Composable Trees

**What:** Represent AND/OR prerequisite chains as nested objects. Evaluate recursively via depth-first traversal.

**When to use:** Course prerequisites, access control rules, boolean permission logic.

**Trade-offs:**
- ✅ Handles arbitrary complexity (AND within OR within AND, etc.)
- ✅ Human-readable and debuggable
- ✅ No truncation issues (flat CSV was the problem)
- ❌ Requires tree-walking code (not trivial, but well-established pattern)
- ❌ More verbose JSON than flat strings

**Example (TypeScript prerequisite evaluator):**

```typescript
// src-ui/hooks/usePrerequisites.ts
type PrereqLogic =
  | { type: 'AND'; conditions: PrereqLogic[] }
  | { type: 'OR'; conditions: PrereqLogic[] }
  | { type: 'course'; courseId: string; courseName: string };

export function evaluatePrerequisites(
  logic: PrereqLogic,
  completedCourses: Set<string>
): boolean {
  if (logic.type === 'course') {
    return completedCourses.has(logic.courseId);
  }

  const results = logic.conditions.map(cond =>
    evaluatePrerequisites(cond, completedCourses)
  );

  return logic.type === 'AND'
    ? results.every(r => r)
    : results.some(r => r);
}

// Usage in component
export function CourseEligibility({ courseId, completedCourses }: Props) {
  const prereqLogic = prerequisites[courseId]?.logic;
  const isEligible = evaluatePrerequisites(prereqLogic, new Set(completedCourses));
  return <span>{isEligible ? '✓ Eligible' : '✗ Missing prerequisites'}</span>;
}
```

### Pattern 4: Separation of Extraction, Validation, and UI Concerns

**What:** Keep extraction logic, data validation, and UI rendering in separate modules with minimal coupling.

**When to use:** Complex data pipelines, multi-stage transformations, testing requirements.

**Trade-offs:**
- ✅ Easy to test each layer independently
- ✅ Extraction bugs don't break the app
- ✅ Can refactor UI without touching data layer
- ❌ More files and boilerplate
- ❌ Requires discipline to maintain boundaries

**Example structure:**

```
extractor/
└── src/
    ├── pdf_parser.py          # Takes PDF → List[PageData]
    ├── course_builder.py      # Takes PageData → List[Course]
    ├── prerequisite_builder.py # Takes Course → PrereqTree
    ├── validators.py          # Validates Course objects
    └── json_serializer.py     # Writes to JSON

Each module has clear input/output contracts.
Unit tests for each module independently.
Integration test for the full pipeline.
```

---

## Data Flow

### Extract Phase (Quarterly, Offline)

```
PDF File
    ↓
PDFPlumber Parser (extract tables, text blocks)
    ↓
Course Builder (match patterns: code, name, credits, sections)
    ↓
Session Mapper (parse day, time, room, instructor, type)
    ↓
Prerequisite Builder (recursive AND/OR logic tree)
    ↓
Data Validators (detect truncation, missing fields, inconsistencies)
    ↓
JSON Serializer (write courses.json, prerequisites.json, curricula.json)
    ↓
courses.json (committed to repo, bundled with app)
```

### Runtime Phase (App Startup)

```
Tauri App Launch
    ↓
Load courses.json into memory (static data)
    ↓
UI Ready (in-memory store populated)
    ↓
User searches courses
    ↓
Search command filters in-memory array (instant)
    ↓
User selects sections
    ↓
Conflict detection runs on selected sessions (instant)
    ↓
Prerequisite check against student's completed courses (tree evaluation)
    ↓
Display schedule with conflict warnings
```

### Query Examples (In-Memory Access)

1. **Search courses by name or code:**
   - Filter `courses[]` by name/courseId substring

2. **Get sections for a course:**
   - Access `courses[i].sections[]`

3. **Detect conflicts between two sessions:**
   - Compare day + time ranges of sessions in different sections

4. **Check prerequisites for a course:**
   - Look up `prerequisites[courseId].logic`
   - Evaluate tree against `completedCourses: Set<string>`

---

## Build Order & Roadmap Implications

### Phase 1: Define JSON Schema

**Why first:** The schema is a contract between the extractor and the app. Once locked, both can develop independently.

**Deliverables:**
- `docs/JSON_SCHEMA.md` (detailed spec with examples)
- TypeScript types generated from schema (`app/src-ui/types/index.ts`)
- Pydantic models in extractor (`extractor/src/models.py`)

**Duration:** 2-3 days
**Risk:** Low (design-time only; no dependencies yet)

### Phase 2: Fix & Harden Extractor

**Why second:** Extraction logic is independent; can be fully tested before touching the app.

**Deliverables:**
- Fix prerequisite truncation (recursive AND/OR logic)
- Fix instructor name truncation (handle compound surnames)
- Generate courses.json, prerequisites.json, curricula.json for 2026-1
- Unit tests for each module
- Integration tests with sample PDFs

**Duration:** 1-2 weeks (depends on PDF complexity)
**Risk:** Medium (PDF text extraction can be fragile; needs rigorous testing)

### Phase 3: Build UI Layer (Tauri App)

**Why third:** Once extractor outputs validated JSON, UI can consume it directly.

**Deliverables:**
- Tauri app structure with bundled JSON
- Course search & filter component
- Section selector with capacity display
- Schedule conflict detector
- Study plan tracker (optional for v1)

**Duration:** 2-3 weeks
**Risk:** Low (UI is read-only; no extraction complexity)

### Phase 4: Distribution & User Testing

**Deliverables:**
- Packaged .exe for Windows
- Installation & first-run guide
- User feedback loop for UI refinements

---

## Scaling Considerations

| Scale | Approach | When to Adjust |
|-------|----------|---|
| **v1 (500-5K students)** | Single JSON file per semester; in-memory load | Keep as-is |
| **v2 (5K-50K students)** | Multiple programs' JSON; lazy-load by program | Data size exceeds available RAM |
| **v3 (50K+ students)** | Sqlite bundled with app; indexed queries | Search performance degrades |

### Priorities

1. **First bottleneck:** Large prerequisite trees → tree evaluation becomes slow
   - **Fix:** Memoize prerequisite evaluations; cache results per student

2. **Second bottleneck:** Large course lists (e.g., 10K courses across all programs)
   - **Fix:** Lazy-load by program; keep only current semester in active memory

---

## Anti-Patterns

### Anti-Pattern 1: Embedding PDF Parsing Logic in the App

**What people do:** Include pdfplumber + extraction code in Tauri app; let users extract PDFs themselves.

**Why it's wrong:**
- Bloats app size (pdfplumber + dependencies = 50+ MB)
- Forces Python runtime into distribution (breaks "no dependencies" goal)
- Users mess up extraction, produce invalid data
- App startup time suffers

**Do this instead:** Extraction as separate offline CLI tool; commit validated JSON to repo.

### Anti-Pattern 2: Storing Unvalidated Prerequisite Text

**What people do:** Raw prerequisite strings from PDF: `"138201 Microeconomía I Y (166097 Contabilidad..."`

**Why it's wrong:**
- Cannot evaluate prerequisites programmatically
- Truncation issues evident and unfixable at runtime
- UI has to do string parsing (fragile, error-prone)

**Do this instead:** Parse prerequisites into structured logic trees during extraction; validate before JSON output.

### Anti-Pattern 3: Database for Static Catalog Data

**What people do:** Use Sqlite/PostgreSQL to store courses, prerequisites, curricula.

**Why it's wrong:**
- Adds deployment complexity (database migrations, backup)
- Overkill for read-only, versioned-once-per-semester data
- Harder to version control; harder to roll back
- Slower queries than in-memory arrays (no cold-start penalty, but general overhead)

**Do this instead:** Bundled JSON for v1 (simple, zero-dependency); upgrade to database only if data changes frequently or grows beyond available RAM.

### Anti-Pattern 4: Tight Coupling Between Extractor and UI

**What people do:** Extraction logic hardcoded in the app; changes to PDF format require app rebuild & redistribution.

**Why it's wrong:**
- Every PDF parsing fix = new app release
- Slow iteration on extraction bugs
- Users stuck with broken extraction until they update

**Do this instead:** Extraction as separate, independently versionable tool. Update extraction, regenerate JSON, commit to repo, and re-bundle only when needed.

---

## Integration Points

### External Services (v2 & Beyond)

| Service | Pattern | Notes |
|---------|---------|-------|
| GitHub Releases (v2) | Download updated `courses.json` by semester | Allow users to fetch latest data without app update |
| Universidad del Pacífico API (future) | Fetch live course availability | Requires authentication; out of scope for v1 |
| Authentication (future) | OAuth/SSO with UP system | For syncing selected courses; out of scope for v1 |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---|---|
| **Extraction ↔ JSON Output** | File I/O | Extractor writes to `app/resources/*/`; committed to git |
| **Tauri Backend ↔ Frontend** | IPC Commands | Rust commands called from TypeScript; results serialized as JSON |
| **App ↔ Bundled Data** | Static include! macro | Tauri embeds JSON at compile time; no runtime file I/O |

---

## Sources

- Layered Architecture & Separation of Concerns: [Layered Architecture & Dependency Injection: A Recipe for Clean and Testable FastAPI Code](https://dev.to/markoulis/layered-architecture-dependency-injection-a-recipe-for-clean-and-testable-fastapi-code-3ioo)
- Data Extraction Patterns: [Data Pipeline Design Patterns](https://www.startdataengineering.com/post/design-patterns/)
- Repository Pattern for Data Access: [The Repository Pattern](https://klaviyo.tech/the-repository-pattern-e321a9929f82)
- Course Prerequisites & Boolean Logic: [Course-Prerequisite Networks for Analyzing and Understanding Academic Curricula](https://appliednetsci.springeropen.com/articles/10.1007/s41109-024-00637-z)
- Prerequisite Representation in Coursedog: [JSON Data Structure for Simple Requirements](https://coursedog.freshdesk.com/support/solutions/articles/48001237503-requirements-json-data-structure-for-simple-requirements)
- Tauri Bundled Resources: [Embedding Additional Files | Tauri](https://v2.tauri.app/develop/resources/)
- Schema.org Course Schema: [Course - Schema.org Type](https://schema.org/Course) | [CourseInstance - Schema.org Type](https://schema.org/CourseInstance)
- CLI Tool Design Patterns: [UX patterns for CLI tools](https://www.lucasfcosta.com/blog/ux-patterns-cli-tools)
- PDF Extraction Pipeline Approaches: [Approaches to PDF Data Extraction for Information Retrieval](https://developer.nvidia.com/blog/approaches-to-pdf-data-extraction-for-information-retrieval/)

---

*Architecture research for: Educational course scheduling + PDF extraction pipeline*
*Researched: 2026-02-24*
