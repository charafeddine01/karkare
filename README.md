# CarLog — Vehicle & Motorcycle Maintenance Platform
**Offline-First, 100% Metric (km, L, Bar), Single Currency ($ USD)**

CarLog is a production-grade, offline-first vehicle maintenance and garage management platform built for cars, motorcycles, and trucks.

---

## 1. Architecture Overview

### Frontend Client (Flutter Dart 3.x)
- **Platforms:** Android, Web (WASM SQLite support), iOS-ready.
- **Offline-First Source of Truth:** SQLite via `drift` and `drift_flutter`. All UI interactions write and read from local SQLite first with `sync_status = 'pending_insert' | 'pending_update' | 'pending_delete'`.
- **State Management:** Riverpod (`flutter_riverpod`).
- **Networking & Guards:** `dio` with JWT & token refresh interceptors, `connectivity_plus`, `internet_connection_checker_plus`, and `ConnectivityGuard` displaying exact failure reason toasts.
- **On-Device Hardware & OCR:** `google_mlkit_text_recognition` for offline scanning of VIN, Odometer readings, and Part numbers. `record` and `audioplayers` for 10-second diagnostic audio clips (`.m4a`). `pdf` and `printing` for official service resale reports. `qr_flutter` for digital service book sharing.

### Backend API (PHP 8.2+ on Shared Hosting)
- **Environment:** Shared hosting cPanel / LiteSpeed Apache with `.htaccess` rewrite rules.
- **Database:** MariaDB 10.6+ InnoDB with client UUID v4 primary keys and `trg_learn_part_number` automatic learning trigger.
- **Security:** Bcrypt password hashing, 6-digit OTP email verification via SMTP (15-min expiry), Google ID Token verification, Bearer JWT access & refresh tokens.
- **Bidirectional Delta Sync:** `POST /api/sync/push` and `GET /api/sync/pull?since={timestamp}` with atomic transactions.
- **Public Web View:** `GET /v/{public_share_token}` provides a responsive, verified digital service book web view with optional price hiding.

---

## 2. Global Constraints
1. **Single Currency:** Strictly USD (`$`) across MariaDB, SQLite, API, and UI.
2. **100% Metric Units:**
   - Distance: Kilometers (`km`)
   - Fluids: Liters (`L`) or Milliliters (`mL`)
   - Displacement: Cubic Centimeters (`cc`) and Liters (`L`)
   - Power: Kilowatts (`kW`)
   - Torque: Newton-meters (`Nm`)
   - Tire Pressure: Bar (`Bar`)
   - Dimensions & Tread/Pads: Millimeters (`mm`)
3. **Immediate Conversion:** NHTSA imperial data is converted immediately before saving or displaying. Inline helper chips (`PSI -> Bar`, `Qt -> L`, `lb-ft -> Nm`, `in -> mm`, `gal -> L`, `ci -> cc`) are provided next to numeric inputs.

---

## 3. Directory Layout

```
.
├── database/
│   ├── schema.sql                 # MariaDB DDL, constraints, indexes & learning trigger
│   └── seed_tasks_and_obd.sql     # Seed categories, tasks, OBD-II codes & community fitments
├── backend/
│   ├── .htaccess                  # Apache/LiteSpeed routing to public/index.php & public/view.php
│   ├── composer.json              # PSR-4 autoloading & dependencies
│   ├── config/
│   │   ├── config.php             # Database credentials, JWT, SMTP, upload settings
│   │   └── Database.php           # PDO connection singleton
│   ├── src/
│   │   ├── Auth/                  # AuthService, JwtHandler, Mailer
│   │   ├── Controllers/           # AuthController, SyncController, UploadController, etc.
│   │   ├── Middleware/            # AuthMiddleware (Bearer token validation)
│   │   └── Router/                # Request, Response, Router
│   ├── public/
│   │   ├── index.php              # REST API front controller
│   │   ├── view.php               # Public QR Code service book web view
│   │   └── not_found.html         # 404 page
│   └── uploads/                   # Secured directory for user vehicle media & audio clips
└── frontend/
    ├── pubspec.yaml               # Flutter dependencies & assets
    ├── assets/
    │   ├── wmi_manufacturers.json # Bundled offline WMI database
    │   └── obd_codes.json         # Bundled offline OBD-II diagnostic trouble codes
    ├── lib/
    │   ├── main.dart              # Flutter application entry point
    │   ├── core/                  # Constants, theme, network client, conversion utilities
    │   ├── data/                  # Drift SQLite schema, DAOs, Sync engine
    │   ├── providers/             # Riverpod state management providers
    │   ├── widgets/               # Offline banner, wheel diagram, quick specs card, OCR button
    │   └── screens/               # Auth, Dashboard, Vehicles, Maintenance, Symptoms, Fuel, Export
    └── web/
        └── index.html             # Flutter Web index
```

---

## 4. Setup & Deployment Instructions

### Database Setup
1. In cPanel / MariaDB, import `database/schema.sql`.
2. Import `database/seed_tasks_and_obd.sql`.

### Backend API Setup (Shared Hosting)
1. Upload the `backend/` directory to your web root or subdomain (e.g. `public_html/` or `subdomains/carlog/`).
2. Update database credentials and SMTP parameters in `backend/config/config.php` (or via environment variables).
3. Ensure `backend/uploads/` is writable (`chmod 755`).

### Flutter Client Setup
1. Navigate to `frontend/`:
   ```bash
   cd frontend
   flutter pub get
   ```
2. Run on Android:
   ```bash
   flutter run -d android
   ```
3. Run on Web:
   ```bash
   flutter run -d chrome
   ```
