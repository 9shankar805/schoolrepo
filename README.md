# schoolrepo

Flutter mobile applications for Nepal School Hub management system.

## Applications Included
- **`admin_app/`**: Executive Flutter mobile application for school directors and principals (Command Center KPIs, 1-tap approvals for leaves/vouchers/admissions, Student 360 search, cashier monitor, urgent broadcasts, gate QR scanner).
- **`teacher_apps/`**: Flutter mobile application for teachers and class in-charges (attendance, daily diary, speed call, marks entry ledger, syllabus/lesson planning, leave requests, routine schedule).
- **`parent_app/`**: Flutter mobile application for parents, guardians, and students with dynamic role-based authentication. If a student logs in (via email, credentials, or student Gmail), the app navigates into the Student Portal (attendance, homework, exams, grades, routine, notices, ask teacher, fees); if a parent logs in (via parent email or parent Gmail), it navigates into the Parent/Guardian Portal (multi-child switcher, academic overview, fees, live bus tracking, meetings, leave requests, direct teacher messaging).

## Getting Started
Ensure you have Flutter installed (`flutter --version` >= 3.x).

### Admin App
```bash
cd admin_app
flutter pub get
flutter run
```

### Teacher App
```bash
cd teacher_apps
flutter pub get
flutter run
```

### Parent App
```bash
cd parent_app
flutter pub get
flutter run
```

