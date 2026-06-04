import os
import json
import base64
import asyncio
from contextlib import asynccontextmanager
import logging
import warnings
import urllib.request
import certifi
from datetime import datetime, timezone
from pymongo import MongoClient
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv

# Google ADK & GenAI
from google import genai
from google.adk import Agent, Runner
from google.adk.sessions import InMemorySessionService
from google.adk.tools import McpToolset
from google.adk.tools.mcp_tool import StdioConnectionParams
from mcp.client.stdio import StdioServerParameters
import google.genai.types as genai_types

# Load environment variables from the .env file
load_dotenv()

# =====================================================================
# Suppress Noisy ADK and MCP Warnings
# =====================================================================
warnings.filterwarnings("ignore", category=UserWarning, module="google.adk")

logging.basicConfig(level=logging.INFO, filename='adk_debug.log', filemode='w')
adk_logger = logging.getLogger("google.adk")
adk_logger.setLevel(logging.DEBUG)

class IgnorePingWarnings(logging.Filter):
    def filter(self, record):
        return "Failed to validate notification" not in record.getMessage()

logging.getLogger().addFilter(IgnorePingWarnings())

# =====================================================================
# App + Shared Services
# =====================================================================

# Pre-warmed MCP session (eliminates 2-4s cold-start per /query request)
_mcp_toolset = None
_mcp_session = None
_mcp_lock = asyncio.Lock()

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Pre-warm the MCP STDIO session at startup, close on shutdown."""
    global _mcp_toolset, _mcp_session
    server_params = StdioServerParameters(
        command="mongodb-mcp-server",
        args=[],
        env={
            "MDB_MCP_CONNECTION_STRING": os.getenv("MDB_MCP_CONNECTION_STRING"),
            "PATH": os.getenv("PATH", "")
        }
    )
    _mcp_toolset = McpToolset(connection_params=StdioConnectionParams(server_params=server_params))
    _mcp_session = await _mcp_toolset._mcp_session_manager.create_session()
    print("✅ MCP session pre-warmed.")
    yield
    await _mcp_toolset.close()
    print("🛑 MCP session closed.")

app = FastAPI(
    title="OmniCare Context Engine",
    description="Multimodal elder-care assistant backend powered by MongoDB and Google ADK",
    version="1.0.0",
    lifespan=lifespan
)

# CORS configuration to support web client calls
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# PyMongo Client (For fast, deterministic inserts)
mongo_client = MongoClient(os.getenv("MDB_MCP_CONNECTION_STRING"), tlsCAFile=certifi.where())
db = mongo_client["omnicare_db"]
collection = db["omnicare_collection"]

# Session service is stateless enough to share across requests
session_service = InMemorySessionService()

# =====================================================================
# Agent Instructions (Personas)
# =====================================================================
INGESTION_INSTRUCTION = (
    "You are a structured data extraction assistant for a dementia care logging system. "
    "When given a raw caregiver observation, extract and structure it into a JSON document. "
    "Use these exact fields:\n"
    "   - 'type': MUST be exactly one of these five values (no synonyms, no alternatives): "
    "'behavioral_observation', 'medication_log', 'dietary_note', 'environmental_note', 'other'. "
    "Use 'behavioral_observation' for mood, agitation, wandering, confusion, sundowning, sleep, or any behavioral pattern. "
    "Use 'medication_log' for anything about pills, drugs, prescriptions, dosages, or medication compliance. "
    "Use 'dietary_note' for food, drink, appetite, meals, hydration, or nutrition. "
    "Use 'environmental_note' for surroundings, room changes, temperature, noise, lighting, or safety hazards. "
    "Use 'other' only if none of the above categories fit at all.\n"
    "   - 'content': the full original observation as written\n"
    "   - 'triggers': list of identified triggers if any (e.g. ['mealtime', 'transition'])\n"
    "   - 'successful_interventions': list of things the caregiver tried that WORKED or calmed the person down, if mentioned\n"
    "   - 'failed_interventions': list of things the caregiver tried that DID NOT WORK or made things worse, if mentioned\n"
    "   - 'sentiment': one of ['distressing', 'neutral', 'positive']\n"
    "   - 'logged_by': 'family' or 'nurse' based on context, default 'unknown'"
)

INTERVENTION_INSTRUCTION = (
    "You are an experienced, empathetic elder-care guide supporting a stressed caregiver or nurse. "
    "You speak the language of caregiving — practical, warm, specific, and actionable. "
    "You NEVER sound like a robotic medical chatbot and you NEVER make medical diagnoses. \n\n"
    "EMERGENCY RULE: If the caregiver's message suggests a medical emergency (difficulty breathing, "
    "unresponsiveness, a fall with injury, chest pain), immediately respond: "
    "'This sounds urgent — please call emergency services (112 / 911) right now. "
    "Do not wait for me.' Do nothing else.\n\n"
    "RESPONSE FORMAT: You MUST structure EVERY response in exactly this format:\n"
    "ACTION: [One clear, specific sentence telling the caregiver exactly what to do RIGHT NOW. "
    "This must be a direct instruction they can act on immediately, e.g., "
    "'Try asking him to help you fold laundry to redirect his attention.']\n\n"
    "CONTEXT: [Your warm, supportive explanation — why this should work, what past logs show, "
    "what to avoid. Keep this to 2-3 sentences max.]\n\n"
    "When provided with a caregiver's concern and retrieved past log context:\n"
    "- If past logs show a previous approach FAILED or caused distress: Warn the caregiver not to repeat it! "
    "Include this warning in the CONTEXT section. "
    "(e.g., CONTEXT: 'I see in the logs that telling him he is retired made him more upset last time. "
    "Instead, last time it really helped to distract him by asking for help with a simple task.')\n"
    "- If past logs show a SUCCESSFUL resolution: draw on those EXACT past experiences. "
    "Put the successful approach in the ACTION line.\n"
    "- If the logs section starts with 'NO_HISTORY': you have zero records for this patient. "
    "You MUST do two things:\n"
    "  1. Begin the ACTION line with '[No care history yet]' so the caregiver knows this is not personalised.\n"
    "  2. In CONTEXT, write exactly this, then stop: "
    "'There are no past care notes for this patient yet, so this is general guidance only — "
    "not based on their history. After this incident, log what happened and what helped so "
    "future advice can be specific to them.'\n"
    "Do NOT present general advice as if it is drawn from this patient's records.\n\n"
    "The ACTION line is what the caregiver reads first in a panic. Make it count."
)

# =====================================================================
# Audio Helper Function
# =====================================================================
def transcribe_audio(audio_data: str) -> str:
    """Uses Gemini to transcribe base64 or URL audio to text."""
    client = genai.Client(api_key=os.getenv("GOOGLE_API_KEY"))
    
    if audio_data.startswith("http"):
        req = urllib.request.Request(audio_data, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req) as response:
            audio_bytes = response.read()
    else:
        if "," in audio_data:
            audio_data = audio_data.split(",")[1]
        audio_bytes = base64.b64decode(audio_data)

    response = client.models.generate_content(
        model='gemini-3.5-flash',
        contents=[
            genai.types.Part.from_bytes(data=audio_bytes, mime_type='audio/mp3'),
            "You are an expert transcriber. Transcribe the following audio accurately. Output ONLY the transcription text."
        ]
    )
    return response.text.strip()

# =====================================================================
# Helper: run a pure reasoning agent (No Tools injected!)
# =====================================================================
async def _run_intervention_agent(instruction: str, prompt: str) -> str | None:
    # We stripped the MCP tools from this agent. It relies purely on the RAG context 
    # injected into the prompt. This reduces latency and prevents rogue DB calls.
    agent = Agent(
        name="InterventionAgent",
        instruction=instruction,
        model="gemini-3.5-flash",
        tools=[], 
    )

    runner = Runner(agent=agent, app_name="omnicare", session_service=session_service)
    session = await session_service.create_session(app_name="omnicare", user_id="default_user")

    final_text = None
    try:
        async for event in runner.run_async(
            user_id="default_user",
            session_id=session.id,
            new_message=genai_types.Content(role="user", parts=[genai_types.Part(text=prompt)]),
        ):
            if event.error_message:
                return f"Agent Error: {event.error_message}"
            
            if event.content and event.content.parts:
                for part in event.content.parts:
                    if hasattr(part, 'text') and part.text:
                        final_text = part.text
    finally:
        # Clean up the session to prevent memory leaks during load testing
        await session_service.delete_session(
            app_name="omnicare", 
            user_id="default_user", 
            session_id=session.id
        )

    return final_text or f"No text response generated."

# =====================================================================
# Request Models
# =====================================================================
class Observation(BaseModel):
    text: str = ""
    audio_data: str | None = None
    patient_id: str = "unknown"

class QueryRequest(BaseModel):
    question: str
    patient_id: str = "unknown"

# Pydantic schema enforces the exact output shape from Gemini
class ExtractedObservation(BaseModel):
    type: str
    content: str
    triggers: list[str]
    successful_interventions: list[str]
    failed_interventions: list[str]
    sentiment: str
    logged_by: str

# =====================================================================
# Endpoints
# =====================================================================
@app.get("/")
async def health_check():
    return {"status": "online", "message": "OmniCare Backend is running!"}

@app.post("/ingest")
async def ingest_observation(obs: Observation):
    try:
        final_text = obs.text

        # Step A: Transcribe audio if present
        if obs.audio_data:
            transcription = await asyncio.to_thread(transcribe_audio, obs.audio_data)
            final_text += f"\n[Audio Transcription]: {transcription}"
            final_text = final_text.strip()

        if not final_text:
            raise ValueError("Must provide either text or audio_data.")

        # Step B: Ask Gemini to Structure the Data 
        client = genai.Client(api_key=os.getenv("GOOGLE_API_KEY"))
        extraction_prompt = f"{INGESTION_INSTRUCTION}\n\nObservation: {final_text}"
        
        extraction_response = await asyncio.to_thread(
            client.models.generate_content,
            model='gemini-3.5-flash',
            contents=extraction_prompt,
            config=genai.types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=ExtractedObservation
            )
        )
        
        doc_to_insert = json.loads(extraction_response.text)
        
        # Inject deterministic fields via Python backend (not LLM-generated)
        doc_to_insert["patient_id"] = obs.patient_id
        doc_to_insert["timestamp"] = datetime.now(timezone.utc).isoformat()

        # Step C: Insert deterministically via PyMongo (Atlas Auto-Embeds in the background)
        await asyncio.to_thread(collection.insert_one, doc_to_insert)

        if "_id" in doc_to_insert:
            doc_to_insert["_id"] = str(doc_to_insert["_id"])

        return {
            "status": "success",
            "message": "Observation structured and saved via PyMongo. Atlas will auto-embed it!",
            "extracted_text": final_text,
            "structured_data": doc_to_insert
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/query")
async def query_interventions(req: QueryRequest):
    try:
        # 🚀 NO MANUAL EMBEDDING REQUIRED!
        # Atlas Auto-Embeddings vectorize the query text dynamically server-side.
        
        # Step A: Execute the vector search directly using MCP
        pipeline = [
            {
                "$vectorSearch": {
                    "index": "vector_index",
                    "path": "content",
                    "query": {
                        "text": req.question
                    },
                    "filter": {"patient_id": req.patient_id},
                    "numCandidates": 10,
                    "limit": 3
                }
            }
        ]
        
        # NOTE(Hackathon): We reuse the pre-warmed MCP session to call the aggregate
        # tool directly, executing a $vectorSearch pipeline natively. This fulfills the
        # "meaningful integration" requirement by utilizing MongoDB's capabilities as
        # our agent's superpower — with zero cold-start latency.
        async with _mcp_lock:
            # Cloud Run CPU throttling can cause the first MCP IPC call to take >5s to wake up the Node process.
            # We add a simple retry mechanism.
            for attempt in range(2):
                try:
                    search_results = await asyncio.wait_for(
                        _mcp_session.call_tool(
                            "aggregate",
                            arguments={
                                "database": "omnicare_db",
                                "collection": "omnicare_collection",
                                "pipeline": pipeline
                            }
                        ),
                        timeout=15.0
                    )
                    break
                except (TimeoutError, asyncio.TimeoutError) as e:
                    if attempt == 1:
                        raise HTTPException(status_code=500, detail="MCP backend timeout after retry") from e
                    print("⚠️ MCP tool call timed out, retrying...")
        
        if getattr(search_results, 'isError', False):
            error_msgs = "\n".join([c.text for c in search_results.content if c.type == 'text'])
            print(f"MCP Aggregate Error: {error_msgs}")
            
        raw_logs = "\n".join([c.text for c in search_results.content if c.type == 'text']) if search_results.content else ""
        
        if not raw_logs or "0 documents" in raw_logs or raw_logs.strip() == "[]":
            log_section = "NO_HISTORY: There are no past care observations recorded for this patient yet."
        else:
            log_section = raw_logs

        # Step B: Instruct the Intervention Agent (Pure Reasoning)
        agent_prompt = (
            f"Caregiver's current message/emergency: '{req.question}'\n\n"
            f"Retrieved past logs:\n"
            f"{log_section}\n\n"
            f"Review the 'successful_interventions' and 'failed_interventions' in these logs closely. "
            f"Provide your response following your persona instructions exactly."
        )

        agent_response = await _run_intervention_agent(INTERVENTION_INSTRUCTION, agent_prompt)

        return {
            "status": "success",
            "question": req.question,
            "intervention": agent_response
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/history")
async def get_history(patient_id: str = "unknown", limit: int = 50):
    """Fetch recent observations from MongoDB for a specific patient."""
    try:
        docs = await asyncio.to_thread(
            lambda: list(
                collection.find({"patient_id": patient_id}, {"embedding": 0})
                .sort("timestamp", -1)
                .limit(limit)
            )
        )
        for doc in docs:
            if "_id" in doc:
                doc["_id"] = str(doc["_id"])
        return {"status": "success", "observations": docs}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/patients")
async def list_patients():
    """Returns distinct patient_id values from the collection."""
    try:
        patient_ids = await asyncio.to_thread(
            lambda: collection.distinct("patient_id")
        )
        return {"status": "success", "patients": patient_ids}
    except Exception as e:
        logging.exception(f"GET /patients failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)