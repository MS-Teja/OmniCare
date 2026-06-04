# OmniCare Frontend

The mobile application for OmniCare — a Flutter app designed with extreme empathy for stressed, often elderly, dementia caregivers. It provides an accessible, calming interface to log care observations and receive AI-powered, history-aware guidance.

---

## Table of Contents

- [Design System: Warm Sanctuary](#design-system-warm-sanctuary)
  - [Color Palette](#color-palette)
  - [Typography](#typography)
  - [Interaction Design](#interaction-design)
- [Screens](#screens)
- [Widgets](#widgets)
- [Services & Models](#services--models)
- [Prerequisites](#prerequisites)
- [Setup & Running](#setup--running)
- [Configuration](#configuration)
- [File Structure](#file-structure)

---

## Design System: Warm Sanctuary

The entire UI is built on a custom design system defined in `lib/theme/omnicare_theme.dart`. It prioritizes clarity, calm, and accessibility over visual novelty.

### Core Principles

| Principle | Implementation |
|-----------|---------------|
| **Light Mode Only** | Dark mode adds cognitive load for elderly users. A single bright, high-contrast theme reduces confusion. |
| **Accessible Touch Targets** | All interactive elements have a minimum size of 56–60dp, well above the recommended 48dp. |
| **Empathetic Microcopy** | No tech jargon. "Log a moment" instead of "Submit observation". "Ask for help" instead of "Query AI". |
| **Action-Oriented Responses** | AI responses split into a prominent **"Try this"** card (what to do NOW) and a softer **"Why"** section (context). The action is what a panicking caregiver reads first. |
| **Minimal Navigation** | No hamburger menus, no tab bars, no bottom navigation. Two large action cards on the home screen. That's it. |

### Color Palette

| Token | Hex | Role |
|-------|-----|------|
| `scaffoldBg` | `#F8FAFC` | Page background (Slate 50 — clean, modern depth) |
| `surfaceWhite` | `#FFFFFF` | Cards, inputs, containers |
| `emerald` | `#10B981` | Primary actions — "Log a moment", success states |
| `emeraldDark` | `#047857` | Pressed/active primary states |
| `emeraldLight` | `#D1FAE5` | Action card backgrounds, light fills |
| `sapphire` | `#3B82F6` | Secondary actions — "Ask for help", user message bubbles |
| `sapphireDark` | `#1D4ED8` | Pressed/active secondary states |
| `sapphireLight` | `#DBEAFE` | Ask-for-help card backgrounds |
| `slate900` | `#0F172A` | Maximum contrast heading text |
| `slate500` | `#64748B` | Secondary body text, muted labels |
| `slate200` | `#E2E8F0` | Borders, dividers |
| `errorRed` | `#EF4444` | Error states, offline indicator |
| `errorRedLight` | `#FEE2E2` | Error background fills |

### Typography

Two typeface families for warmth + readability:

| Family | Usage | Source |
|--------|-------|--------|
| **Source Serif 4** | Headings and display text — adds warmth and humanity | Google Fonts |
| **DM Sans** | Body text, labels, inputs — clean and highly readable | Google Fonts |

Key scale points:

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| `displayLarge` | 48px | w800 | Hero text ("Caring for Mr. Roy") |
| `displayMedium` | 32px | w800 | Action card titles |
| `headlineLarge` | 26px | w700 | Screen headers |
| `bodyLarge` | 17px | w500 | Primary body text |
| `bodyMedium` | 15px | w400 | Secondary body text |
| `labelLarge` | 16px | w700 | Button labels |

### Interaction Design

- **Press Feedback:** Action cards use `ScaleTransition` (scale to 0.94) with `easeOutExpo` curve for a firm, tactile press feel
- **Page Transitions:** Custom `PageRouteBuilder` with combined fade + subtle horizontal slide (3% offset), 350ms `easeOutCubic`
- **Staggered Entrance:** Home screen cards animate in with offset delays (0.15–0.85 interval) using `easeOutBack` for a springy feel
- **Loading State:** Three-dot bounce animation with "Finding past notes that might help" message — informative and calming
- **Backend Offline:** Red banner with `cloud_off` icon and manual refresh tap. Only shown when the health check fails.

---

## Screens

### `PatientScreen` — Landing Page
**File:** `lib/screens/patient_screen.dart`

The first screen the user sees. Select an existing patient from the database or create a new one. This sets the `patient_id` used in all subsequent API calls.

### `HomeScreen` — Main Dashboard
**File:** `lib/screens/home_screen.dart`

Two large, unmistakable action cards:
- **"Log a moment"** (Emerald) — Navigate to the logging screen
- **"Ask for help"** (Sapphire) — Navigate to the intervention chat

Plus a subtle "View past notes" text button at the bottom. Backend health check runs on mount; offline banner appears only if it fails.

### `LogScreen` — Log an Observation
**File:** `lib/screens/log_screen.dart`

Text input area + voice recorder. Caregivers can type, record audio, or both. Submissions are sent to `POST /ingest`. On success, shows the AI's structured extraction as confirmation.

### `AskScreen` — Ask for Help
**File:** `lib/screens/ask_screen.dart`

A chat-style interface where the caregiver describes their situation. Messages are sent to `POST /query`. Responses are displayed in the structured `ChatBubble` widget with the **ACTION/CONTEXT** split layout.

### `HistoryScreen` — Past Observations
**File:** `lib/screens/history_screen.dart`

A scrollable timeline of past observations for the selected patient, fetched from `GET /history`. Each entry is rendered as an `ObservationCard`.

---

## Widgets

### `ChatBubble`
**File:** `lib/widgets/chat_bubble.dart`

Handles three display modes:
1. **User message** — Right-aligned, sapphire background, white text
2. **Plain assistant message** — Left-aligned, white background with border
3. **Structured response** — Two-part layout:
   - Green `"Try this"` action card (emerald background, bold text)
   - White `"Why"` context section below (muted text, softer border)

Parses the agent's `ACTION:` / `CONTEXT:` format automatically via the `ChatMessage` model.

### `VoiceRecorder`
**File:** `lib/widgets/voice_recorder.dart`

Built on the `record` package. Records audio, converts to base64, and passes it to the parent screen for submission. Large, accessible record button.

### `ObservationCard`
**File:** `lib/widgets/observation_card.dart`

Renders a single care log entry with type badge, content preview, triggers, interventions, sentiment, and timestamp.

### `LoadingIndicator`
**File:** `lib/widgets/loading_indicator.dart`

A themed loading animation used during API calls.

### `OmniCareButton`
**File:** `lib/widgets/omnicare_button.dart`

A reusable themed button with consistent sizing and styling.

---

## Services & Models

### `ApiService`
**File:** `lib/services/api_service.dart`

HTTP client wrapper that communicates with the FastAPI backend. All methods return typed results or throw an `ApiException` with a **user-friendly message** — never raw HTTP status codes or stack traces.

| Method | Endpoint | Returns |
|--------|----------|---------|
| `healthCheck()` | `GET /` | `bool` |
| `logObservation(text, audioBase64?, patientId)` | `POST /ingest` | `IngestResponse` |
| `askForHelp(question, patientId)` | `POST /query` | `InterventionResponse` |
| `getHistory(patientId, limit)` | `GET /history` | `List<Observation>` |
| `getPatients()` | `GET /patients` | `List<String>` |

**Error handling philosophy:** Timeouts, connection failures, and certificate errors are mapped to empathetic, plain-English messages (e.g., *"This is taking longer than usual — the AI might be busy"*).

### `Observation` Model
**File:** `lib/models/observation.dart`

Data model for a structured care observation. Parsed from the `/history` and `/ingest` response JSON.

### `Intervention` Model
**File:** `lib/models/intervention.dart`

Data model for intervention responses. Includes `ChatMessage` class that parses the raw `ACTION: ... CONTEXT: ...` text into structured `action` and `context` fields for the `ChatBubble` widget.

---

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Flutter SDK | 3.10+ | Framework |
| Dart | 3.10+ | Language (bundled with Flutter) |
| Android SDK | — | Android builds |
| Xcode | — | iOS builds (macOS only) |
| Running OmniCare Backend | — | API server on the same network |

---

## Setup & Running

```bash
# Install dependencies
flutter pub get

# Run on emulator (uses localhost by default)
flutter run

# Run on physical device (replace with your machine's IP)
flutter run --dart-define=API_HOST=192.168.x.x

# Run on Android emulator (10.0.2.2 maps to host's localhost)
flutter run --dart-define=API_HOST=10.0.2.2
```

> **Finding your IP:** On macOS, run `ifconfig | grep "inet "` and use your local network IP (e.g., `192.168.0.x`).

---

## Configuration

**File:** `lib/config.dart`

API connection is configured entirely via compile-time `--dart-define` flags — no settings screen needed.

| Flag | Default | Description |
|------|---------|-------------|
| `API_HOST` | `localhost` | Backend hostname or IP |
| `API_PORT` | `8000` | Backend port |

The base URL is constructed as: `http://{API_HOST}:{API_PORT}`

Request timeout is set to **45 seconds** to accommodate Gemini's response time under load.

---

## File Structure

```
frontend/
├── pubspec.yaml                         # Dependencies and app metadata
├── analysis_options.yaml                # Lint configuration
│
├── assets/
│   └── icon.png                         # App launcher icon
│
└── lib/
    ├── main.dart                        # App entry point, MaterialApp setup
    ├── config.dart                      # API host/port compile-time config
    │
    ├── models/
    │   ├── observation.dart             # Observation data model (from /history, /ingest)
    │   └── intervention.dart            # Intervention response + ChatMessage parser
    │
    ├── screens/
    │   ├── patient_screen.dart          # Patient selection (landing page)
    │   ├── home_screen.dart             # Main dashboard (Log / Ask)
    │   ├── log_screen.dart              # Log observation (text + voice)
    │   ├── ask_screen.dart              # Ask for help (intervention chat)
    │   └── history_screen.dart          # Past observations timeline
    │
    ├── services/
    │   └── api_service.dart             # HTTP client + friendly error handling
    │
    ├── theme/
    │   └── omnicare_theme.dart          # "Warm Sanctuary" design system
    │
    └── widgets/
        ├── chat_bubble.dart             # ACTION/CONTEXT structured response display
        ├── voice_recorder.dart          # Audio recording (record package)
        ├── observation_card.dart         # Care log entry card
        ├── loading_indicator.dart        # Themed loading animation
        └── omnicare_button.dart          # Reusable themed button
```

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `http` | ^1.4.0 | HTTP client for backend communication |
| `google_fonts` | ^6.2.1 | Source Serif 4 + DM Sans typography |
| `record` | ^6.2.1 | Audio recording for voice notes |
| `path_provider` | ^2.1.5 | Local file paths for temporary audio files |
| `permission_handler` | ^11.4.0 | Microphone permission requests |
| `flutter_launcher_icons` | ^0.14.4 | Custom app icon generation (dev dependency) |
