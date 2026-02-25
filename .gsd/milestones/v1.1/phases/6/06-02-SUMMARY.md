# Plan 6.2 Summary: Conflict Prevention & Validation

- **Duplicate Prevention**: Updated `ScheduleState.addSection` to iterate over selected sections and throw an exception if the newly requested `Course` shares a code with an already added section.
- **Overlap Logic**: Created `TimeUtils.hasOverlap` to check intersecting intervals. Added `ScheduleState.conflictsWithSchedule` to evaluate if a `Section` overlaps with any existing sessions on the same day.
- **Visual Hints**: Wired `CourseSearchList` to check `conflictsWithSchedule(section)`. If true, the `ListTile` flashes a red tint `TileColor`, the font turns bold red, and the Add button text changes to "Cruza" (Overlaps). 
- **User Feedback**: Handled the duplicate exception in the `CourseSearchList` Add button using `ScaffoldMessenger.of(context).showSnackBar` to display an instant, non-blocking error prompt.
- **Verification**: `flutter analyze` passes. Logic is fully implemented in Dart.
