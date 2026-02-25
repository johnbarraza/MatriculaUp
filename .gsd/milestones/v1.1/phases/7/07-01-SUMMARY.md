# Plan 7.1 Summary: Advanced Views: Regular vs Exam

- **Schedule View Toggle**: Converted `HomePage` to a `StatefulWidget` to maintain `_showExams` state. Added a `SegmentedButton` directly above the `TimetableGrid` to switch between "Semana Regular" and "Exámenes".
- **Filter Sessions by Type**: Updated `TimetableGrid` to accept `showExams` as a boolean parameter. In the render loop, it now filters out `SessionType.finalExam` and `SessionType.parcial` sessions when in Regular view, and exclusively shows them in the Exam view.
- **Verification**: `flutter analyze` runs without issues. Visual logic properly segregates session layout by exam condition.
