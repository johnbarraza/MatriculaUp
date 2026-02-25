# Plan 8.1 Summary: Search by Professor & Anti-Collision Filters
- **Block Conflicts:** The "Agregar" button is now fully disabled (`onPressed: null`) when `hasConflict` is true. No visual workaround can add a conflicting section anymore.
- **Professor Search:** The `filteredCourses` query now checks `c.secciones.any((s) => s.docentes.any(...))`, enabling results when typing a professor's name.
- **"Ocultar Cruces" Toggle:** Added a `SwitchListTile` above the list. When enabled, `filteredCourses` excludes courses where all sections conflict, and the inner `visibleSections` for each course also prunes conflicting entries from the expansion.
- **Verification:** `flutter analyze` clean.
