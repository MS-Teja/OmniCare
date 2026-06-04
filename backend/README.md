# OmniCare Backend

The context engine powering OmniCare — a FastAPI server that orchestrates Google Gemini AI agents, MongoDB Atlas, and the Model Context Protocol (MCP) to process caregiver observations and generate personalized, history-aware interventions.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [How It Works](#how-it-works)
  - [Ingestion Pipeline](#1-ingestion-pipeline-post-ingest)
  - [Intervention Pipeline](#2-intervention-pipeline-post-query)
  - [History & Patients](#3-history--patients)
- [Pre-warmed MCP Session](#pre-warmed-mcp-session)
- [Agent Personas](#agent-personas)
- [Data Model](#data-model)
- [Prerequisites](#prerequisites)
- [Setup](#setup)
- [Running Locally](#running-locally)
- [Deployment (Google Cloud Run)](#deployment-google-cloud-run)
- [API Reference](#api-reference)
- [File Structure](#file-structure)
- [Environment Variables](#environment-variables)

---

## Architecture Overview

```
                    ┌───────────────────────────────────────────────┐
   HTTP Request     │               FastAPI (main.py)               │
──────────────────▶ │                                               │
                    │  ┌─────────────────┐  ┌────────────────────┐ │
                    │  │  POST /ingest    │  │   POST /query      │ │
                    │  │                 │  │                    │ │
                    │  │  1. Transcribe  │  │  1. Vector Search  │ │
                    │  │     (Gemini)    │  │     (MCP → Atlas)  │ │
                    │  │  2. Structure   │  │  2. Reasoning      │ │
                    │  │     (Pydantic)  │  │     (Gemini Agent)  │ │
                    │  │  3. Insert      │  │  3. Respond        │ │
                    │  │     (PyMongo)   │  │     (ACTION+CONTEXT)│ │
                    │  └────────┬────────┘  └────────┬───────────┘ │
                    │           │                     │             │
                    │           ▼                     ▼             │
                    │  ┌─────────────┐      ┌──────────────────┐  │
                    │  │  PyMongo    │      │  MCP STDIO       │  │
                    │  │  (Direct    │      │  Session          │  │
                    │  │   Insert)   │      │  (Pre-warmed)     │  │
                    │  └──────┬──────┘      └────────┬─────────┘  │
                    └─────────┼──────────────────────┼─────────────┘
                              │                      │
                              ▼                      ▼
                    ┌───────────────────────────────────────────────┐
                    │           MongoDB Atlas (Cloud)               │
                    │                                               │
                    │  Database: omnicare_db                        │
                    │  Collection: omnicare_collection              │
                    │  • Auto-Embeddings on "content" field         │
                    │  • Vector Search Index: "vector_index"        │
                    │  • Filter field: "patient_id"                 │
                    └───────────────────────────────────────────────┘
```

---

## How It Works

### 1. Ingestion Pipeline (`POST /ingest`)

When a caregiver logs an observation (text, audio, or both):

| Step | What Happens | Tool Used |
|------|-------------|-----------|
| **A. Transcription** | If audio is provided (base64 or URL), Gemini transcribes it to text | `google-genai` (Gemini 3.5 Flash) |
| **B. Structuring** | The raw text is sent to Gemini with a Pydantic `response_schema`. Gemini returns a guaranteed JSON shape with type classification, triggers, interventions, and sentiment | `google-genai` + `ExtractedObservation` schema |
| **C. Metadata** | `patient_id` and `timestamp` are injected deterministically by Python (never by the LLM) | Backend logic |
| **D. Storage** | The structured document is inserted via PyMongo. Atlas Auto-Embeddings vectorize the `content` field in the background | `pymongo` → Atlas |

**Why PyMongo instead of MCP for inserts?** Inserts are deterministic — there's no need for an AI agent to mediate. Using PyMongo directly is faster and more reliable.

### 2. Intervention Pipeline (`POST /query`)

When a caregiver asks for help:

| Step | What Happens | Tool Used |
|------|-------------|-----------|
| **A. Vector Search** | The caregiver's question is used in a `$vectorSearch` aggregation pipeline via the pre-warmed MCP session. Atlas auto-embeds the query text server-side (no manual embedding needed). Results are filtered by `patient_id` | MCP STDIO → `mongodb-mcp-server` |
| **B. RAG Prompt** | The retrieved past logs are injected into the prompt alongside the caregiver's current message | String formatting |
| **C. Reasoning** | A tool-less Gemini agent (no MCP tools, no DB access) synthesizes an `ACTION` + `CONTEXT` response based purely on the injected RAG context | `google-adk` Agent + Runner |

**Why a tool-less reasoning agent?** Giving the intervention agent database tools would add latency and risk unintended DB mutations. By injecting RAG context into the prompt, we get faster, safer responses.

### 3. History & Patients

- **`GET /history`** — Fetches recent observations for a patient via PyMongo, sorted by timestamp descending. Excludes the `embedding` field to keep payloads light.
- **`GET /patients`** — Returns distinct `patient_id` values from the collection.

---

## Pre-warmed MCP Session

The MongoDB MCP Server runs as an STDIO subprocess. Instead of spawning a new Node.js process on every `/query` request (which adds 2–4 seconds of cold-start latency), we pre-warm a single persistent session at startup using FastAPI's `lifespan`:

```python
@asynccontextmanager
async def lifespan(app: FastAPI):
    global _mcp_toolset, _mcp_session
    # Spawn the MCP server process once
    _mcp_toolset = McpToolset(connection_params=StdioConnectionParams(server_params=...))
    _mcp_session = await _mcp_toolset._mcp_session_manager.create_session()
    yield
    await _mcp_toolset.close()
```

An `asyncio.Lock` ensures concurrent `/query` requests safely share the session:

```python
async with _mcp_lock:
    search_results = await _mcp_session.call_tool("aggregate", arguments={...})
```

**Result:** Zero cold-start latency per query. One Node.js process for the lifetime of the server.

---

## Agent Personas

The backend uses two distinct AI personas, each tuned for its specific task:

### Ingestion Agent (Structured Extraction)
- **Model:** Gemini 3.5 Flash (via `google-genai` direct API)
- **Purpose:** Extract structured data from raw caregiver text
- **Output:** Guaranteed JSON via Pydantic `response_schema`
- **Type Classification:** One of exactly five values: `behavioral_observation`, `medication_log`, `dietary_note`, `environmental_note`, `other`
- **Fields Extracted:** type, content, triggers, successful_interventions, failed_interventions, sentiment, logged_by

### Intervention Agent (Empathetic Reasoning)
- **Model:** Gemini 3.5 Flash (via `google-adk` Agent/Runner)
- **Purpose:** Generate actionable, empathetic advice for stressed caregivers
- **Tools:** None (reasoning only — RAG context injected in-prompt)
- **Output Format:** `ACTION:` (what to do right now) + `CONTEXT:` (why, what past logs show)
- **Emergency Rule:** If the message suggests a medical emergency, responds with "call 911/112" immediately
- **No-History Rule:** If no past logs exist for the patient, the agent explicitly flags that the advice is general (not personalized)

---

## Data Model

Each observation stored in MongoDB follows this schema:

```json
{
  "_id": "ObjectId(...)",
  "type": "behavioral_observation",
  "content": "Dad got very agitated when I asked him to shower, but calmed down when I played jazz music",
  "triggers": ["shower", "hygiene routine"],
  "successful_interventions": ["playing jazz music"],
  "failed_interventions": [],
  "sentiment": "distressing",
  "logged_by": "family",
  "patient_id": "mr_roy",
  "timestamp": "2026-06-04T06:30:00+00:00"
}
```

| Field | Type | Source |
|-------|------|--------|
| `type` | string (enum) | Gemini extraction |
| `content` | string | Original caregiver text |
| `triggers` | string[] | Gemini extraction |
| `successful_interventions` | string[] | Gemini extraction |
| `failed_interventions` | string[] | Gemini extraction |
| `sentiment` | string (enum) | Gemini extraction |
| `logged_by` | string | Gemini extraction |
| `patient_id` | string | Injected by backend |
| `timestamp` | ISO 8601 string | Injected by backend |

---

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Python | 3.11+ | Backend runtime |
| Node.js | 20+ | Required for `npx mongodb-mcp-server` |
| MongoDB Atlas | Free tier works | Database with Auto-Embeddings + Vector Search |
| Google API Key | — | Gemini access via [AI Studio](https://aistudio.google.com/apikey) |

---

## Setup

```bash
# 1. Create and activate virtual environment
python -m venv .venv
source .venv/bin/activate   # macOS/Linux
# .venv\Scripts\activate    # Windows

# 2. Install dependencies
pip install -r requirements.txt

# 3. Configure environment
cp .env.example .env
# Edit .env:
#   GOOGLE_API_KEY=your_gemini_api_key
#   MDB_MCP_CONNECTION_STRING=your_atlas_connection_string
```

---

## Running Locally

```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

On successful startup you should see:
```
✅ MCP session pre-warmed.
INFO:     Uvicorn running on http://0.0.0.0:8000
```

> **Binding to `0.0.0.0`** is required so Flutter running on a physical device (same WiFi network) can reach the backend.

---

## Deployment (Google Cloud Run)

The included `Dockerfile` builds a container with both Python 3.11 and Node.js 20 (required for the MCP server):

```bash
gcloud run deploy omnicare-backend \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars "GOOGLE_API_KEY=your_key,MDB_MCP_CONNECTION_STRING=your_connection_string" \
  --min-instances 1
```

> **`--min-instances 1`** is critical. It ensures the MCP session pre-warms before the first request, eliminating cold-start latency.

### What the Dockerfile does:

| Layer | Purpose |
|-------|---------|
| `python:3.11-slim` | Base image |
| Node.js 20 install | Required for `npx mongodb-mcp-server` |
| `pip install -r requirements.txt` | Python dependencies |
| `npm install -g mongodb-mcp-server@latest` | Pre-installs MCP server globally (no npm resolution delay at runtime) |
| `exec uvicorn ...` | Runs with `exec` so Cloud Run's termination signals reach uvicorn directly for graceful shutdown |

---

## API Reference

### `GET /`
Health check endpoint.

```json
// Response
{ "status": "online", "message": "OmniCare Backend is running!" }
```

---

### `POST /ingest`
Log a caregiver observation. Supports text, audio (base64 or URL), or both.

**Request:**
```json
{
  "text": "Dad got agitated during shower time but calmed down with jazz music",
  "audio_data": null,
  "patient_id": "mr_roy"
}
```

**Response:**
```json
{
  "status": "success",
  "message": "Observation structured and saved via PyMongo. Atlas will auto-embed it!",
  "extracted_text": "Dad got agitated during shower time but calmed down with jazz music",
  "structured_data": {
    "type": "behavioral_observation",
    "content": "Dad got agitated during shower time...",
    "triggers": ["shower", "hygiene routine"],
    "successful_interventions": ["playing jazz music"],
    "failed_interventions": [],
    "sentiment": "distressing",
    "logged_by": "family",
    "patient_id": "mr_roy",
    "timestamp": "2026-06-04T06:30:00+00:00"
  }
}
```

---

### `POST /query`
Ask for context-aware intervention advice based on the patient's care history.

**Request:**
```json
{
  "question": "He is refusing to eat lunch and pushing the plate away",
  "patient_id": "mr_roy"
}
```

**Response:**
```json
{
  "status": "success",
  "question": "He is refusing to eat lunch and pushing the plate away",
  "intervention": "ACTION: Try offering a smaller portion of a comfort food he enjoys, like kheer, and sit with him calmly while eating together.\n\nCONTEXT: I see in the logs that large portions have been overwhelming for him recently. Last Tuesday, sitting with him and sharing a meal helped him eat more comfortably. Avoid insisting he finish his plate — that caused more resistance last time."
}
```

---

### `GET /history`
Retrieve past observations for a patient.

**Query Parameters:**
| Param | Default | Description |
|-------|---------|-------------|
| `patient_id` | `"unknown"` | Patient identifier |
| `limit` | `50` | Max number of observations |

**Response:**
```json
{
  "status": "success",
  "observations": [ { "type": "...", "content": "...", ... } ]
}
```

---

### `GET /patients`
List all distinct patient IDs in the database.

**Response:**
```json
{
  "status": "success",
  "patients": ["mr_roy", "mrs_chen"]
}
```

---

## File Structure

```
backend/
├── main.py               # Single-file FastAPI app with all endpoints and agent logic
├── requirements.txt       # Pinned Python dependencies
├── Dockerfile             # Production container (Python 3.11 + Node.js 20)
├── .env.example           # Environment variable template
├── .env                   # Local secrets (gitignored)
└── adk_debug.log          # ADK debug output (gitignored, auto-generated)
```

---

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `GOOGLE_API_KEY` | ✅ | Google Gemini API key from [AI Studio](https://aistudio.google.com/apikey) |
| `MDB_MCP_CONNECTION_STRING` | ✅ | MongoDB Atlas connection string (SRV format) |
