# 🫶 OmniCare

**A context-aware, multimodal AI companion for dementia caregivers.**

OmniCare is a respectful, simple, and empathetic digital assistant designed specifically for dementia caregivers. Caregiving is a heavy, emotionally taxing responsibility. OmniCare acts as a trusted companion — allowing caregivers to easily log observations (via text or voice) and get immediate, context-aware advice drawn from the patient's actual care history.

> **Built with:** Flutter · FastAPI · Google Gemini (via ADK) · MongoDB Atlas · Model Context Protocol (MCP)

---

## Table of Contents

- [How It Works](#how-it-works)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
  - [1. MongoDB Atlas Setup](#1-mongodb-atlas-setup)
  - [2. Backend Setup](#2-backend-setup)
  - [3. Frontend Setup](#3-frontend-setup)
- [Deployment (Google Cloud Run)](#deployment-google-cloud-run)
- [API Reference](#api-reference)
- [Design Philosophy](#design-philosophy)
- [Environment Variables](#environment-variables)
- [Tech Stack](#tech-stack)

---

## How It Works

OmniCare is designed around two primary workflows that map directly to a caregiver's needs: **Logging** and **Asking for Help**.

### 1. 📝 Logging a Moment (Ingestion)

When a caregiver notices a behavioral change, an incident, or something that works well (e.g., *"Dad got very agitated when I asked him to shower, but calmed down when I played jazz music"*), they open the app and tap **"Log a moment"**.

- **Input:** Caregivers can type or use the built-in voice recorder. Audio is transcribed server-side by Gemini.
- **AI Structuring:** The raw input is sent to the backend where Google Gemini analyzes it with structured output enforcement (Pydantic schema). It classifies the event type (e.g., `behavioral_observation`, `medication_log`, `dietary_note`), extracts triggers, and identifies what interventions succeeded or failed.
- **Storage:** The structured document is saved to MongoDB Atlas via PyMongo. Atlas Auto-Embeddings vectorize the content in the background — no manual embedding pipeline required.

**Endpoint:** `POST /ingest`

### 2. 🆘 Asking for Help (Intervention)

When a caregiver is in a crisis or needs immediate advice (e.g., *"He is refusing to eat his lunch and getting agitated"*), they tap **"Ask for help"**.

- **Vector Search (via MCP):** The backend uses a pre-warmed MongoDB MCP Server (STDIO) session to execute a `$vectorSearch` aggregation pipeline against Atlas. This retrieves past logs that share similar semantic context for that specific patient.
- **AI Synthesis:** A reasoning-only Gemini agent reviews the caregiver's current situation alongside the patient's historical data — specifically what has *actually worked or failed* for this patient before.
- **Empathetic Delivery:** The response is structured as an **ACTION** (exactly what to do right now) followed by **CONTEXT** (why this should work, what past logs show). Emergency situations trigger immediate 911/112 guidance.

**Endpoint:** `POST /query`

---

## Architecture

```
┌─────────────────────┐         ┌──────────────────────────────────────┐
│                     │  HTTP   │          FastAPI Backend              │
│   Flutter Mobile    │────────▶│                                      │
│   App (Frontend)    │◀────────│  ┌──────────┐    ┌───────────────┐  │
│                     │         │  │ Ingestion │    │ Intervention  │  │
│  • Patient Select   │         │  │ (Gemini   │    │ (Gemini       │  │
│  • Log a Moment     │         │  │  + Pydantic│   │  Reasoning    │  │
│  • Ask for Help     │         │  │  Schema)  │    │  Agent)       │  │
│  • Care History     │         │  └─────┬─────┘    └───────┬───────┘  │
│  • Voice Recording  │         │        │                  │          │
└─────────────────────┘         │        ▼                  ▼          │
                                │  ┌───────────┐    ┌──────────────┐  │
                                │  │  PyMongo   │    │  MCP STDIO   │  │
                                │  │  (Insert)  │    │  Session     │  │
                                │  └─────┬──────┘   │  (Pre-warmed)│  │
                                │        │          └──────┬───────┘  │
                                └────────┼─────────────────┼──────────┘
                                         │                 │
                                         ▼                 ▼
                                ┌──────────────────────────────────────┐
                                │       MongoDB Atlas (Cloud)          │
                                │                                      │
                                │  • omnicare_db.omnicare_collection   │
                                │  • Atlas Auto-Embeddings             │
                                │  • Vector Search Index               │
                                └──────────────────────────────────────┘
```

**Key architectural decisions:**

| Decision | Rationale |
|---|---|
| **PyMongo for inserts, MCP for reads** | Inserts are deterministic — no LLM needed. MCP is used for vector search, which is the "meaningful integration" with MongoDB's agent capabilities. |
| **Pre-warmed MCP session** | The STDIO MCP server process is spawned once at startup via FastAPI's `lifespan`. An `asyncio.Lock` ensures safe concurrent access. This eliminates the 2–4 second cold-start that would otherwise occur on every `/query` request. |
| **Structured output via Pydantic schema** | Gemini's `response_schema` parameter guarantees the extracted observation matches the exact JSON shape we need. No regex parsing, no prompt-and-pray. |
| **Reasoning-only intervention agent** | The intervention agent receives RAG context in-prompt (no tools). This reduces latency and prevents rogue DB calls during response generation. |

---

## Project Structure

```
Omnicare/
├── README.md
├── .gitignore
│
├── backend/
│   ├── main.py               # FastAPI application (all endpoints + agent logic)
│   ├── requirements.txt       # Python dependencies
│   ├── Dockerfile             # Cloud Run deployment (Python + Node.js)
│   ├── .env.example           # Environment variable template
│   └── .env                   # Local secrets (gitignored)
│
└── frontend/
    ├── pubspec.yaml            # Flutter dependencies
    └── lib/
        ├── main.dart           # App entry point
        ├── config.dart         # API host/port configuration
        ├── models/
        │   ├── observation.dart    # Observation data model
        │   └── intervention.dart   # Intervention response model
        ├── screens/
        │   ├── patient_screen.dart  # Patient selection (landing page)
        │   ├── home_screen.dart     # Main dashboard
        │   ├── log_screen.dart      # Log a moment (text + voice)
        │   ├── ask_screen.dart      # Ask for help (intervention chat)
        │   └── history_screen.dart  # Past observations timeline
        ├── services/
        │   └── api_service.dart     # HTTP client with friendly error handling
        ├── theme/
        │   └── omnicare_theme.dart  # "Warm Sanctuary" design system
        └── widgets/
            ├── chat_bubble.dart       # ACTION/CONTEXT response display
            ├── loading_indicator.dart  # Animated loading states
            ├── observation_card.dart   # Care log card
            ├── omnicare_button.dart    # Themed action button
            └── voice_recorder.dart     # Audio recording widget
```

---

## Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| **Python** | 3.11+ | Backend runtime |
| **Node.js** | 20+ | Required for `npx mongodb-mcp-server` |
| **Flutter** | 3.10+ | Mobile frontend |
| **MongoDB Atlas** | Free tier works | Database with Auto-Embeddings enabled |
| **Google API Key** | — | Gemini model access via [Google AI Studio](https://aistudio.google.com/apikey) |

---

## Getting Started

### 1. MongoDB Atlas Setup

1. Create a free cluster at [MongoDB Atlas](https://cloud.mongodb.com/).
2. Create a database named `omnicare_db` with a collection named `omnicare_collection`.
3. **Enable Auto-Embeddings** on the `content` field of `omnicare_collection`.
4. Create a **Vector Search Index** named `vector_index` on the collection with the auto-embedded `content` field.
5. Add a filter field for `patient_id` in the vector index definition.
6. Copy your connection string (you'll need it for the `.env` file).

### 2. Backend Setup

```bash
# Clone the repo and navigate to the backend
cd backend

# Create and activate a virtual environment
python -m venv .venv
source .venv/bin/activate   # macOS/Linux
# .venv\Scripts\activate    # Windows

# Install dependencies
pip install -r requirements.txt

# Configure environment variables
cp .env.example .env
# Edit .env and fill in:
#   GOOGLE_API_KEY=your_gemini_api_key
#   MDB_MCP_CONNECTION_STRING=your_atlas_connection_string

# Start the server
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

On startup you should see:
```
✅ MCP session pre-warmed.
INFO:     Uvicorn running on http://0.0.0.0:8000
```

### 3. Frontend Setup

```bash
# Navigate to the frontend
cd frontend

# Install Flutter dependencies
flutter pub get

# Run on a connected device or emulator
# For physical device, specify your local backend URL:
flutter run --dart-define=BASE_URL=http://192.168.x.x:8000

# For emulator (uses Cloud Run URL by default):
flutter run
```

> **Note:** When using `--dart-define=BASE_URL`, it must point to your machine's local network IP (not `localhost`) when running on a physical device. Find it with `ifconfig | grep "inet "` on macOS.

---

## Deployment (Google Cloud Run)

The backend includes a production-ready Dockerfile that installs both Python and Node.js (required for the MCP server).

```bash
cd backend

# Build and deploy to Cloud Run
gcloud run deploy omnicare-backend \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --set-secrets="GOOGLE_API_KEY=GOOGLE_API_KEY:latest,MDB_MCP_CONNECTION_STRING=MDB_MCP_CONNECTION_STRING:latest" \
  --min-instances 0
```

> **Important:** Set `--min-instances 1` so the MCP session pre-warms before the first request hits the service. Without this, the first request after a cold start will take an extra 2-4 seconds while the Node.js MCP process spins up.

---

## API Reference

### `GET /`
Health check.

**Response:**
```json
{ "status": "online", "message": "OmniCare Backend is running!" }
```

### `POST /ingest`
Log a caregiver observation. Accepts text, audio, or both.

**Request Body:**
```json
{
  "text": "Dad got agitated during shower time but calmed down with jazz music",
  "audio_data": null,
  "patient_id": "mr_roy"
}
```

**Response:** Returns the AI-structured observation with extracted type, triggers, interventions, and sentiment.

### `POST /query`
Ask for context-aware intervention advice.

**Request Body:**
```json
{
  "question": "He is refusing to eat lunch and pushing the plate away",
  "patient_id": "mr_roy"
}
```

**Response:** Returns an `ACTION` + `CONTEXT` formatted intervention based on the patient's care history.

### `GET /history?patient_id=mr_roy&limit=50`
Retrieve past observations for a patient, sorted newest first.

### `GET /patients`
List all distinct patient IDs in the database.

---

## Design Philosophy

OmniCare is not a clinical tool, nor is it a generic AI chat wrapper. It is built around strict empathetic design principles:

| Principle | Implementation |
|---|---|
| **Stupidly Simple UX** | Zero complex navigation. Two primary actions from the home screen: Log and Ask. |
| **Accessible by Default** | 56dp minimum touch targets, high contrast ratios, readable typography via Google Fonts. |
| **Warm Sanctuary** | Soft earth tones (Cream, Sage, Terracotta). Avoids sterile medical aesthetics and aggressive tech themes. |
| **Action-Oriented Clarity** | Agent responses always lead with a direct **ACTION** ("Try this") before providing the **CONTEXT** ("Why"). |
| **Voice-First Accessible** | Built-in voice recording for caregivers who can't type while managing a situation. Audio is transcribed server-side by Gemini. |
| **Emergency-Aware** | If the agent detects a medical emergency, it immediately tells the caregiver to call 911/112 before anything else. |

---

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `GOOGLE_API_KEY` | ✅ | API key from [Google AI Studio](https://aistudio.google.com/apikey) for Gemini access |
| `MDB_MCP_CONNECTION_STRING` | ✅ | MongoDB Atlas connection string (SRV format) |

---

## Production Considerations & HIPAA

This repository and demo use fully synthetic patient data. 

**Is this HIPAA compliant?**
A production deployment of OmniCare would involve processing Protected Health Information (PHI). Google Cloud Platform (Agent Builder, Cloud Run) and MongoDB Atlas both support HIPAA-compliant configurations. To deploy this to production, you would need to:
1. Ensure your Google Cloud organization has a signed Business Associate Agreement (BAA) with Google.
2. Ensure your MongoDB Atlas account has a signed BAA with MongoDB and is configured according to their security whitepapers.
3. Add end-user authentication (e.g., Firebase Auth) and granular role-based access control (RBAC).

---

## Tech Stack

| Layer | Technology | Role |
|---|---|---|
| **Frontend** | Flutter (Dart) | Cross-platform mobile app |
| **Backend** | FastAPI (Python) | REST API, agent orchestration |
| **AI** | Google Gemini 3.5 Flash | Transcription, structured extraction, intervention reasoning |
| **Agent Framework** | Google ADK | Agent runner with MCP tool integration |
| **Database** | MongoDB Atlas | Document storage with auto-embeddings and vector search |
| **MCP Server** | `mongodb-mcp-server` (STDIO) | Executes `$vectorSearch` aggregation pipelines for RAG |
| **Deployment** | Google Cloud Run | Containerized backend with Python + Node.js |

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

*Built for the Google Cloud Rapid Agent Hackathon*

