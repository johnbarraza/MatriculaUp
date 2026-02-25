# Feature Landscape: University Course Schedule Planner

**Domain:** Desktop course registration planner for Peruvian university students
**Researched:** 2026-02-24
**Confidence:** MEDIUM (ecosystem research HIGH, MatriculaUp-specific application MEDIUM)

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete compared to Excel spreadsheets or manual planning.

| Feature | Why Expected | Complexity | Notes | Offline Ready |
|---------|--------------|------------|-------|---|
| **Course Search & Filter** | Users must find courses from hundreds offered; manual scrolling through PDFs is painful | LOW | Text search by course name, code, instructor; essential for navigability | ✓ Yes |
| **Section Selection** | Each course has multiple sections (times, instructors); users must choose one | LOW | Display all available sections with day, time, instructor, capacity info | ✓ Yes |
| **Visual Timetable** | Users need to see if their schedule looks reasonable; hours per day, compressed vs. spread out | MEDIUM | Week view (Mon-Fri) with time grid; color-coded courses; printable | ✓ Yes |
| **Conflict Detection** | Schedule conflicts (overlapping times) are unacceptable; discovering after registration is costly | LOW | Real-time detection when adding sections; highlight conflicts in red; show exact overlap details | ✓ Yes |
| **Save/Load Schedules** | Users need to compare multiple options; lost work on app close is fatal | LOW | Save up to 3 tentative schedules; quick switch between them; persist to disk between sessions | ✓ Yes |
| **Schedule Export** | Users share tentative schedules with peers, advisors before registering; need portable format | LOW | Export to image (PNG), print-to-PDF; include course names, times, instructor names | ✓ Yes |

**Why these are table stakes:** University students already use Excel spreadsheets or manual note-taking to plan courses. MatriculaUp must do what spreadsheets do (search, organize, detect conflicts) with less manual work. Missing any of these makes users revert to Excel or live with blind spots.

---

### Differentiators (Competitive Advantage)

Features that set MatriculaUp apart from generic spreadsheets or other planners. Aligned with project's core value: "see all courses, plan without PDFs, detect conflicts."

| Feature | Value Proposition | Complexity | Notes | Offline Ready |
|---------|-------------------|------------|-------|---|
| **Curriculum Integration** | Show which courses are required for your program/year; highlight pending courses; track progress | MEDIUM | After user selects career + year, filter to show only required courses; mark completed; show credits required vs. earned | ✓ Yes |
| **Prerequisite Validation** | Warn before selecting a course you haven't completed prerequisites for; prevent registration mistakes | MEDIUM | Parse prerequisite chains from data; highlight missing prerequisites in search results; block conflicting selections | ✓ Yes |
| **Multi-Semester Planning** | Plan ahead across multiple semesters; see course dependencies; spot bottlenecks early | HIGH | Load multiple term offerings; allow drag-and-drop courses across term tabs; validate prerequisites chain | ✓ Yes |
| **Schedule Optimization Hints** | Suggest schedule patterns (all mornings, 4-day week, etc.) instead of forcing manual tweaking | HIGH | Algorithm to generate multiple valid schedules for a given course selection; rank by user preference (compact vs. spread) | ✓ Yes |
| **Shared Schedule Comparison** | Compare your schedule side-by-side with a friend's to see if you can study together | MEDIUM | Import peer's schedule from file/share link; overlay two timetables; highlight shared courses | ✓ Partial (with file sharing) |
| **UP-Specific Data Context** | Data bundled with app (no login, no internet needed); pre-extracted from official PDFs; updated once per term | LOW | Offline-first design; JSON data bundled; no server dependency; distributable as single executable | ✓ Yes |

**Strategic focus:** These are where MatriculaUp competes. The curriculum integration + offline model is unique among free student tools. Most competitors (Coursicle, uAchieve) are web-based and require school integration. MatriculaUp's niche is Peruvian students at UP who want instant, offline planning without registration infrastructure.

---

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create disproportionate complexity or don't align with MVP scope.

| Feature | Why Requested | Why Problematic | Better Alternative |
|---------|---------------|-----------------|-------------|
| **Real-Time Registration Integration** | "Wouldn't it be cool to register directly from the app?" | Requires authentication with UP's system (scope creep); only works for UP; creates liability if registration fails; v1 is offline planning tool | Keep as separate step: plan in MatriculaUp, then go to autoservicio.up.edu.pe to register. Document this in UI. |
| **Automatic Schedule Recommendation** | "Just suggest the best schedule for me" | "Best" is subjective (some prefer early morning, others late; some want 4-day weeks, others spread out). No clear ranking without user preferences. | Constraint-based filtering (time range, max hours/day) + ranking by user-selected criteria. Manual final selection. |
| **Sync with Personal Calendar (Google Calendar, Outlook)** | "I want this in my calendar app" | Requires authentication, token management, handling sync failures. Offline-first app can't reliably sync. | Export to iCal file (.ics); user imports manually or drops into calendar app. One-direction, no bidirectional sync. |
| **Dark Mode / Theming** | "The UI is too bright" | Adds 3-4 phases of dev work (CSS variables, testing all views, accessibility); not core to scheduling logic. | Launch v1 with light theme optimized for readability. Defer theming to v2 based on user demand. |
| **Mobile App** | "I want to plan on my phone" | Separate codebase, testing, deployment. Desktop-first makes sense for detailed schedule tinkering. | Responsive web version (v2+) or mobile web wrapper. Desktop app is primary v1 delivery. |
| **Course Recommendations Based on Major** | "Suggest courses I might need this semester" | Requires modeling course prerequisites, dependencies, typical progression. Hard to get right. Risk of steering students wrong. | Provide filtered view of "recommended for this cycle" from curriculum JSON. Let student decide. Safer than recommendations. |

**Philosophy:** These are requests that sound good but would delay launch or over-engineer v1. Better to solve the core problem (find + schedule + detect conflicts) excellently than add half-implemented features.

---

## Feature Dependencies

```
Core Search
    └──requires──> JSON data loaded from disk
    └──requires──> Course DataFrame indexed for fast lookup

Visual Timetable (Rendering)
    └──requires──> Schedule created (1+ courses selected)
    └──requires──> Valid time parsing (day + start_time + end_time)

Conflict Detection
    └──requires──> 2+ courses in same schedule
    └──requires──> Visual Timetable (highlights show conflicts)
    └──enhances──> Course Selection (warns before adding conflicting course)

Save/Load Schedules
    └──requires──> Conflict Detection working
    └──requires──> Persistent storage (JSON file on disk)
    └──enhances──> Core workflow (switch between 3 plans)

Export to Image/PDF
    └──requires──> Visual Timetable rendering complete
    └──requires──> PNG/PDF generation library (PIL or similar)

Curriculum Integration
    └──requires──> Curriculum JSON for selected career loaded
    └──requires──> Course-to-curriculum mapping (code or name match)
    └──enhances──> Course Search (filter to required courses)
    └──enhances──> Save/Load (remember selected career + completed courses)

Prerequisite Validation
    └──requires──> Curriculum JSON includes prerequisite chains
    └──requires──> Conflict Detection logic (to block circular prerequisites)
    └──enhances──> Course Selection (warn before adding course with unmet prerequisites)

Multi-Semester Planning
    └──requires──> Support for multiple term JSON files (2026-1, 2026-2, etc.)
    └──requires──> Visual Timetable capable of showing multiple semesters
    └──enhances──> Prerequisite Validation (check across semesters)

Schedule Optimization Hints
    └──requires──> Algorithm to generate valid schedule combinations
    └──requires──> User input for preferences (time range, max days, clustering)
    └──enhances──> Course Selection (suggest 3-4 alternatives automatically)

Shared Schedule Comparison
    └──requires──> Export/Import working
    └──requires──> Ability to load two schedules simultaneously
```

### Dependency Notes

- **Core Search requires JSON + DataFrame:** Without data loaded, search is impossible. This is a hard dependency for launch.
- **Conflict Detection enhances Course Selection:** Ideally, when a user adds a course, the app warns "This conflicts with X" before they confirm. But detection must work independently first.
- **Curriculum Integration is optional for v1:** Could launch with just course search + schedule building. Curriculum filter is a v1.1 feature.
- **Prerequisite Validation is separate from Conflict Detection:** They both check constraints, but prerequisites are forward-looking ("Can I take this later?") while conflicts are immediate ("Does this overlap today?").
- **Multi-Semester and Optimization are v2+:** Require significant new UI (semester tabs, algorithm design). Defer unless early validation shows demand.

---

## MVP Definition

### Launch With (v1)

Minimum viable product — what's needed to validate the concept. Focus: "Better than Excel for one term at one university."

- [ ] **Course Search & Filter** — Students can find courses offered in 2026-1 for Economía. Types "microeconomía" or "RODRÍGUEZ" and see matching courses. **Why essential:** Without search, browsing 500+ offerings is unusable.

- [ ] **Section Selection & Visual Timetable** — Select a course section, see it appear on week grid (Mon-Fri, 7:30-23:30). Can see at a glance: hours per day, which days packed/free. **Why essential:** Core value prop—see your schedule visually without printing PDFs.

- [ ] **Conflict Detection** — When adding a section, app detects if it overlaps with existing courses. Shows "CONFLICT: Microeconomía I (Mon 10-12) overlaps with Estadística (Mon 11-13)." Can prevent add or ask "replace?" **Why essential:** Users cite conflict discovery as #1 reason to use a tool; without it they use pen-and-paper checking.

- [ ] **Save 3 Tentative Schedules** — User can create/switch between 3 plans (e.g., "Plan A: Morning heavy", "Plan B: 4-day week", "Plan C: Backup"). Data persists to disk between app sessions. **Why essential:** Students always compare 2-3 options before committing. Without this, every session restart erases work.

- [ ] **Export to PNG** — Button to download current schedule as image (with course names, times, instructors). Can share via email or Telegram. **Why essential:** Social proof/planning with peers is real use case; lack of export means users screenshot or recreate manually.

- [ ] **Curriculum Filter (Basic)** — After user selects "Economía 2017" from dropdown, show which courses are required. Checkbox to mark as completed. Show progress: "10 of 48 required courses selected." **Why essential:** Differentiator vs. blank spreadsheet; helps prevent "Why am I taking electives when I have prerequisites pending?" mistakes.

**NOT in v1:**
- Multi-semester planning (too many new screens)
- Prerequisite validation (nice to have; can manually check plan against curriculum for first term)
- Schedule optimization algorithm (users can manually create multiple plans)
- Mobile app
- Real-time registration integration

---

### Add After Validation (v1.x)

Features to add once core is working and real usage shows demand.

- [ ] **Prerequisite Validation** — After collecting real user feedback ("I didn't realize Eco I was required for Eco II"), add warning system. Requires JSON metadata expansion but logic is straightforward. Estimated: 1-2 sprints.

- [ ] **Multi-Semester View** — If users ask "Can I plan 2026-1 and 2026-2 together?" then add term switching. Requires UI rework but data model is ready. Estimated: 2-3 sprints.

- [ ] **Schedule Generation Algorithm** — If users spend >15min manually tweaking for "perfect" schedule, invest in auto-generator. Requires algorithm design but clear ROI. Estimated: 2-3 sprints.

- [ ] **Shared Schedule Comparison** — If early adopters ask "Can I see if my friend and I have overlapping schedules?" add import/overlay. Estimated: 1 sprint.

- [ ] **Expanded Course Data** — If users ask "Why is there no room number?" add missing fields from PDF once data quality improves. Estimated: 1 sprint data cleanup.

---

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] **Mobile App** — Desktop planning is superior UX for schedule tinkering. Mobile matters after proving PMF. Estimated: 3-4 sprints for responsive web + mobile native.

- [ ] **Real-Time Registration Integration** — After winning hearts with offline tool, could integrate with UP's autoservicio. Requires API access, auth, error handling. Estimated: 4-5 sprints + UP IT coordination.

- [ ] **All UP Careers** — v1 ships with Economía only. After 2026-1 launch, expand to Finanzas, Administración, Derecho if demand exists. Estimated: 1 sprint per career (data extraction + testing).

- [ ] **Dark Mode / Advanced Theming** — Not core to scheduling. Polish feature for maturity phase. Estimated: 2 sprints if pursued.

- [ ] **Accessibility (WCAG AA)** — Important for inclusivity; not critical for v1 MVP. Add after PMF. Estimated: 2-3 sprints for audit + fixes.

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Phase | Priority |
|---------|------------|---------------------|-------|----------|
| Course Search & Filter | HIGH | LOW | v1 | **P1** |
| Section Selection | HIGH | LOW | v1 | **P1** |
| Visual Timetable | HIGH | MEDIUM | v1 | **P1** |
| Conflict Detection | HIGH | MEDIUM | v1 | **P1** |
| Save/Load Schedules (3 plans) | HIGH | LOW | v1 | **P1** |
| Export to Image | HIGH | LOW | v1 | **P1** |
| Curriculum Filter (Basic) | MEDIUM | LOW | v1 | **P1** |
| Prerequisite Validation | MEDIUM | MEDIUM | v1.x | **P2** |
| Multi-Semester Planning | MEDIUM | HIGH | v2 | **P3** |
| Schedule Optimization Algorithm | MEDIUM | HIGH | v1.x | **P2** |
| Shared Schedule Comparison | LOW | MEDIUM | v1.x | **P2** |
| Mobile App | LOW | HIGH | v2 | **P3** |
| Real-Time Registration | LOW | HIGH | v2+ | **P3** |
| Dark Mode | LOW | MEDIUM | v2+ | **P3** |

**Priority key:**
- **P1: Must have for launch** — Without these, product doesn't solve the core problem (schedule planning).
- **P2: Should have, add when possible** — Significant value; don't block launch but add in 1-2 sprints after.
- **P3: Nice to have, future consideration** — Polish or expansion; defer until PMF validated.

---

## Feature Context for MatriculaUp

### University of the Pacific (UP) Context

- **Existing infrastructure:** Students already use autoservicio.up.edu.pe for actual registration. MatriculaUp is *pre-registration planning*, not registration itself.
- **Target user:** Economía 2017 plan students (up to 48 courses over 10 semesters). Use case: "Before I lock in my registration, let me see if this schedule works."
- **Data source:** Official PDFs (already extracted to JSON; extraction pipeline separate). No API integration planned for v1.
- **Distribution:** Standalone desktop app (Windows first) with bundled JSON data. No internet required after download.
- **Peer sharing:** Common workflow: "My friend made a schedule, let me check if we overlap." Export + file sharing are important.

### Offline-First Implication

All P1 features must work 100% without internet:
- Search: Indexed local DataFrame ✓
- Selection & Timetable: In-memory data ✓
- Conflict detection: O(n²) local algorithm ✓
- Save/Load: Local JSON/SQLite ✓
- Export: PIL/reportlab on disk ✓

**Cloud sync (v2+):** If v2 adds Google Drive backup or centralized schedule sharing, design as **optional** sync layer that doesn't break app if offline.

---

## Competitor Feature Analysis

| Feature | Coursicle | uAchieve | MyStudyLife | MatriculaUp (v1) |
|---------|-----------|----------|-------------|---|
| **Search & Filter** | ✓ (school-aware) | ✓ (school-aware) | ✓ | ✓ (basic, course/instructor) |
| **Visual Timetable** | ✓ | ✓ | ✓ | ✓ |
| **Conflict Detection** | ✓ | ✓ | ✓ | ✓ |
| **Save Multiple Schedules** | Unlimited | Yes | Unlimited | ✓ (3 limit) |
| **Export to Image/PDF** | ✓ | ✓ | ✓ | ✓ (PNG) |
| **Curriculum Tracking** | ✗ | ✓ (DegreeWorks integration) | ✓ | ✓ (basic v1) |
| **Prerequisite Validation** | ✗ | ✓ | Partial | ✗ (v1.x) |
| **Sync to Google Calendar** | ✓ | Partial | ✓ | ✗ (export .ics v1.x) |
| **Requires Internet** | ✓ | ✓ | ✓ | ✗ |
| **Free** | ✓ | Via institution | ✓ | ✓ |
| **Works without school integration** | ✓ | ✗ | ✓ | ✓ (data bundled) |

**Key differentiation:**
- **Offline-first:** No competitors stress offline. This is MatriculaUp's moat for Peruvian students without reliable internet.
- **Bundled data:** Competitors fetch data from school systems or crowdsource. MatriculaUp extracts once, ships data with app.
- **Peruvian context:** Competitors are US-focused (Coursicle, uAchieve). MatriculaUp is designed for UP's calendar, course codes, career structures.
- **Limited schedules (3):** Competitors allow unlimited. MatriculaUp's constraint is deliberate: MVP scope. Can expand later.

---

## Scope Boundaries for v1

### What MatriculaUp Is NOT

- **Not a full degree audit tool** — Doesn't track GPA, grades, or degree progress beyond course completion. uAchieve does this; too much scope.
- **Not a real registration system** — Students still go to autoservicio.up.edu.pe to enroll. MatriculaUp is planning + validation.
- **Not a study schedule optimizer** — Doesn't suggest what time to study, or assign study blocks. MyStudyLife does this; different tool.
- **Not a social network** — No messaging, group schedules, or community features. Stays focused.
- **Not a multi-university platform** — Economía 2017 at UP, initially. Other universities / years added post-PMF.

### What MatriculaUp IS

- **A fast, offline course planner** — Search + select + detect conflicts in seconds, no login, no sync, no ads.
- **Personalized to UP** — Uses UP's course codes, career structures, term calendar.
- **A pre-registration validation tool** — Check if your schedule is feasible before committing in autoservicio.
- **A study planning aid for peers** — Export and share to coordinate with classmates.

---

## MVP Success Metrics

**How to know v1 is working:**

1. **Adoption:** >20% of Economía 2017 cohort (estimate: ~500 students) downloads + opens app by end of 2026-1.
2. **Engagement:** Average user creates 2+ schedules (using the 3-plan save feature).
3. **Viral:** >30% of users export a schedule (signal for peer sharing).
4. **Retention:** >15% of users open app again in 2026-2 (repeat user intent).
5. **Pain relief:** Post-launch survey shows >70% agree: "This is faster than Excel."

**Early warning signs (pivot trigger):**
- <5% adoption (platform distribution issue or too complex UI).
- 0 exports (sharing isn't happening; feature not valuable).
- Low retention (<5%); users try once, don't return (problem not solved).

---

## Sources

**University Schedule Planner Ecosystem:**
- [Mizzou Schedule Planner](https://registrar.missouri.edu/registration-classes/registration/schedule-planner/)
- [CSUN Registration Planner Features](https://www.csun.edu/current-students/registration-planner-features)
- [Coursicle Course Schedule Maker](https://www.coursicle.com/college-schedule-maker/)
- [uAchieve Schedule Builder](https://collegesource.com/degree-planning-tools/uachieve-schedule-builder/)
- [Modern Campus Navigate Student Schedule Optimization](https://moderncampus.com/products/student-schedule-optimization.html)
- [Rutgers Course Schedule Planner Known Issues](https://sims.rutgers.edu/csp/known_issues.html)

**Student Pain Points & Usability:**
- [UT Austin Law Schedule Planner UX Case Study](https://law.utexas.edu/ux-case-studies/schedule-planner/)
- [NYU Albert Registration Usability Lab](https://sites.google.com/nyu.edu/nyuusabilitylab/usability-services/case-studies/nyu-albert-student-course-registration)
- [Modern Campus: Streamlining Course Scheduling Challenges](https://moderncampus.com/blog/streamlining-course-scheduling-for-universities-challenges-and-solutions.html)

**Prerequisite & Curriculum Context:**
- [American River College Prerequisites, Corequisites](https://arc.losrios.edu/2025-2026-official-catalog/programs-of-study/description-of-courses/prerequisites-corequisites-and-advisories)
- [uAchieve Planner Curriculum Integration](https://collegesource.com/degree-planning-tools/uachieve-planner/)
- [University of Melbourne My Course Planner](https://students.unimelb.edu.au/your-course/manage-your-course/planning-your-course-and-subjects/faculty-course-planning-resources/my-course-planner/)

**UP-Specific Context:**
- [UP Autoservicio Matrícula Guide](https://campusvirtual.up.edu.pe/matricula/guia-matricula-autoservicio/index.html)
- [MatriculaUp Project Spec](../PROJECT.md)
- [Existing codebase improvements (MEJORAS.md)](../MEJORAS.md)

---

**Feature landscape research for: University course schedule planner (MatriculaUp)**
**Researched: 2026-02-24**
