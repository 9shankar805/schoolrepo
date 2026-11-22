# Nepal School Hub (NSHLMS) — School Admin Command Center

Executive mobile and tablet application built with Flutter for School Principals, Directors, and Administrative In-Charges.

## Core Capabilities
- **Executive Command Center**: Live attendance rates (students & staff), today's cash collections, total outstanding dues, and 7-day attendance trends.
- **Urgent Approvals Queue**: 1-tap review and sign-off for Staff Leave Requests, Expense Vouchers & Petty Cash, and Student Admission Applications.
- **Student 360° Directory**: Predictive search across 1,800+ students, guardian contact speeds (direct Phone Call, WhatsApp, SMS), attendance history, and fee clearance status.
- **Finance & Cash Counter**: Real-time counter receipts, fee dues breakdown, and bulk push/SMS payment reminders to parents.
- **Routine & Timetable Studio**: Universal class routine builder with automated bell schedule generator (custom periods, recess intervals), live schedule clash & conflict detection (section overlap, teacher double-booking, room clash) with force override, 1-tap section routine cloning, and faculty workload inspection.
- **Staff & Teacher Roster**: Live biometric clock-in feed, absent teacher alerts, and quick timetable substitution tools.
- **Broadcast & Emergency Alerts**: Dispatch instant multi-channel alerts (FCM Push Notifications & Notices) filtered by audience (All Campus, Parents, Teachers, Students).
- **Campus Gate QR Scanner**: Phone camera ID and gate pass checkout verification with immediate fee defaulter badges.
- **Front Desk & Campus Visitor Management**: Real-time active visitor headcount ribbon, quick check-in sheet with badge generation, 1-tap exit checkout with duration calculation, and instant Emergency Evacuation Roll Call.
- **Student Pastoral Care, Discipline & Merit Tracking**:
  - Behavioral incident logging with severity tags (`Minor`, `Moderate`, `Severe / Major`).
  - Positive Commendations & Merits (Academic, Sports & Athletics, Leadership, Science/STEM, Arts) with competition levels (School to International) and Merit Leaderboard.
  - Action Taken & Suspension Tracker (detention, counseling referrals, in-school/out-of-school suspension filters and tracking).
  - Executive Disciplinary Sign-Off for Principal/Director formal review, directive notes, and case resolution.
  - 1-tap guardian outreach with direct phone calling for incident follow-up.
- **Institutional Academic Calendar & Event Planner**:
  - Interactive campus calendar with monthly navigation and agenda feed across exams, PTMs, sports, and celebrations.
  - Public & national holiday planner highlighting school closures and working day adjustments.
  - Quick event scheduling from mobile with automated push notification & notice broadcasting to parents and staff.
- **Staff HR, Contracts & Payroll Overview**:
  - Monthly payroll disbursement snapshot with gross/net totals, paid vs. pending staff counts, TDS withholding, and disbursement progress.
  - Digital salary slips review for both teachers and non-teaching staff with 1-tap payment confirmation (Bank Transfer, Cash, Cheque, Digital).
  - Staff employment contract & probation alerts visually flagging contracts expiring within 30 days.
  - Faculty professional development & certification logs tracking workshops and training hours.
- **Official Certificates & Document Issuance Center**:
  - Transfer Certificate (TC) Manager for departing students with executive authorization and automatic serial number generation (`TC-yymm-xxxx`).
  - 1-tap generation of Character Certificates, Bonafide Study Certificates, Recommendation Letters, and Admission Proofs.
  - Digital school seal stamp and principal signature verification flags with QR-ready verification tokens.
- **Campus Infirmary & Medical Health Records**:
  - Daily sick bay / clinic roster displaying resting students, admitted time, symptoms reported, temperature reading (°C), assigned bed number, and treatment administered.
  - Quick student clinic admission check-in sheet and discharge workflows (`Returned to Class`, `Sent Home`, `Referred to Hospital`).
  - High-visibility red emergency badges on the Student 360 profile for critical medical conditions (asthma, food allergies, epilepsy, diabetes).
  - 1-tap emergency quick-dial to parents/guardians, campus nurse, and family doctor.
  - Encrypted Protected Health Information (AES-256-CBC) adhering to student health privacy.
- **Academic Syllabus Coverage & Homework Radar**:
  - Grade-wise syllabus progress tracker comparing actual completed curriculum % against expected academic year velocity pace.
  - Color-coded pace indicator badges (`On Track`, `Ahead of Schedule`, `Behind Pace`) with unit completion counters.
  - Real-time homework load monitor with automated overload warnings for classes scheduled with $\ge 3$ assignments on the same date to avoid student fatigue.
  - 1-tap homework assignment dispatch modal directly from the executive app.
  - Weekly faculty lesson plan verification queue with learning objectives, teaching methodologies, and 1-tap Principal sign-off (`Approve & Endorse`, `Request Revision`, `Reject`).
- **Executive Security, Biometric App Lock & Privacy**:
  - Biometric App Lock (FaceID / Fingerprint / 4-Digit Master PIN) safeguarding sensitive payrolls, financial collections, and student health records.
  - Automatic background timeout lock after 2 minutes of app inactivity.
  - Multi-Campus / Branch Switcher in the top header enabling school owners, trustees, and directors to switch between institutions without re-login.
- **Crisis Alert & Emergency Lockdown SOS Protocol**:
  - One-tap emergency broadcast with pre-configured crisis templates (*Severe Weather / Flood Closure, Full Campus Lockdown & Shelter-in-Place, Bus Route Breakdown & Transit Delay, Power Outage / Utility Hazard Evacuation, Medical Quarantine Alert*).
  - Immediate high-priority multi-channel dispatch bypassing background queues (Loud Push Notification alarm override, instant SMS gateway broadcast to verified mobile numbers, persistent urgent Notice Board pin).
  - Active Campus Crisis Banner across executive apps, Parent App, and Teacher App with live countdown and incident commander tracking.
  - 1-tap "Declare All-Clear / Resolve Crisis" broadcast to notify community once the situation is resolved.
  - Direct integration with Emergency Campus Visitor & Attendance Roll Call headcounts.

## Getting Started

### Prerequisites
- Flutter SDK (>= 3.0.0)
- Backend ERP server running Laravel (`/api/admin-app/`)

### Run Application
```bash
cd flutter_apps/admin_app
flutter pub get
flutter run
```

### Backend API Configuration
The app includes a server selector at login:
- **Production Cloud**: `https://nshlms.com/api/admin-app`
- **Local Development**: `http://127.0.0.1:8000/api/admin-app`
- **Android Emulator**: `http://10.0.2.2:8000/api/admin-app`
