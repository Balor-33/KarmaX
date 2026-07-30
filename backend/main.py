"""
KarmaX FastAPI Backend
======================

Architecture:
  Flutter  →  POST /analyze-problem  →  [this backend]  →  Gemini API
  Flutter  →  POST /generate-quiz    →  [this backend]  →  Gemini API
  Flutter  →  POST /analyze          →  [this backend]  →  Gemini API

Security model:
  • GEMINI_API_KEY  – set as a Render environment variable. NEVER in Flutter.
  • SUPABASE_SERVICE_ROLE_KEY (if used) – Render env var only. NEVER in Flutter.
  • SUPABASE_ANON_KEY – may be in Flutter (it's a public key by design).

Local development:
  Create backend/.env (gitignored) with:
    GEMINI_API_KEY=your_key_here
    SUPABASE_URL=https://xxxx.supabase.co
    SUPABASE_ANON_KEY=eyJ...
  Then run: uvicorn main:app --reload

Render deployment:
  Set GEMINI_API_KEY (and optionally SUPABASE_* vars) in the Render dashboard
  under Environment → Environment Variables. The dotenv load below is a
  no-op on Render (no .env file present), so the os.environ values win.
"""

import sys
import os

# Ensure backend directory is in Python module search path.
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# ── Environment variable loading ──────────────────────────────────────────────
# Load from a local backend/.env for development convenience.
# On Render (production) this file won't exist, so the call is a no-op and
# the real env vars set in the Render dashboard are used automatically.
from dotenv import load_dotenv

_backend_dir = os.path.dirname(os.path.abspath(__file__))
_local_env = os.path.join(_backend_dir, ".env")
if os.path.isfile(_local_env):
    load_dotenv(dotenv_path=_local_env, override=False)
    print(f"[main] Loaded local env from {_local_env}")
else:
    print("[main] No local .env found – using process environment (Render / CI).")

# Validate that the Gemini key is present before starting up.
_gemini_key = os.environ.get("GEMINI_API_KEY", "")
if not _gemini_key:
    print(
        "[main] WARNING: GEMINI_API_KEY is not set. "
        "Set it as a Render environment variable or add it to backend/.env for local dev."
    )
else:
    # Only print key presence, never the key itself.
    print(f"[main] GEMINI_API_KEY loaded ✓ (length: {len(_gemini_key)} chars)")

# ── FastAPI app ───────────────────────────────────────────────────────────────
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import List
from karmax_model import KarmaxModel

app = FastAPI(
    title="Karmax Behavior & Quest Engine API",
    description=(
        "Backend API powering behavioral analysis and gamified quest generation for KarmaX. "
        "All Gemini API calls are made here — the Flutter client never contacts Gemini directly."
    ),
    version="1.0.0",
)

# ── CORS ──────────────────────────────────────────────────────────────────────
# Allows Flutter (mobile/web) to call this backend.
# For production you can tighten allow_origins to your specific domain(s).
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # tighten to e.g. ["https://your-flutter-web.app"] in production
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
)

# ── Global AI model instance ──────────────────────────────────────────────────
karmax_ai = KarmaxModel()

# ── Request/Response schemas ──────────────────────────────────────────────────
class ProblemRequest(BaseModel):
    problem: str = Field(description="Free-text description of the student's problem")

class QuizRequest(BaseModel):
    problem_title: str = Field(description="Title of the diagnosed problem")
    causes: List[str] = Field(default=[], description="Selected root causes")

class AnalyzeRequest(BaseModel):
    player_name: str = Field(default="Student", description="Name of the player/student")
    schedule: str = Field(default="Standard", description="Student schedule preference")
    problem_title: str = Field(default="General Focus", description="Main stated problem")
    problem_subtitle: str = Field(default="", description="Subtitle or detail of the problem")
    selected_causes: List[str] = Field(default=[], description="User-selected root causes")
    quiz_answers: List[str] = Field(default=[], description="Answers to diagnostic quiz")
    sleep_hours: float = Field(default=7.0, description="Sleep hours per night")
    study_hours: float = Field(default=4.0, description="Study/focus hours per day")
    screen_time_hours: float = Field(default=5.0, description="Screen time hours per day")
    stress_level: int = Field(default=3, description="Self-reported stress level (1–5)")
    physical_activity_hours: float = Field(default=1.0, description="Physical activity hours per day")
    social_hours: float = Field(default=2.0, description="Social hours per day")
    gpa: float = Field(default=3.0, description="Current GPA")
    emotion: str = Field(default="Neutral", description="Current emotional state")

class GenerateRequest(BaseModel):
    """Generic prompt endpoint – kept simple for future extensibility."""
    prompt: str = Field(description="Raw prompt text to send to Gemini via the backend")

# ── Routes ────────────────────────────────────────────────────────────────────
@app.get("/")
def read_root():
    return {
        "system": "KarmaX AI Backend API",
        "status": "online",
        "model": KarmaxModel.MODEL_NAME,
        "note": "Gemini API key is held server-side only.",
    }

@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "api_key_configured": bool(karmax_ai.api_key),
        "model": KarmaxModel.MODEL_NAME,
    }

@app.post("/generate")
def generate_endpoint(payload: GenerateRequest):
    """
    Generic prompt → Gemini response endpoint.
    Flutter POSTs { "prompt": "..." } and receives the AI response.
    The Gemini API key never leaves this server.
    """
    try:
        result = karmax_ai._generate_with_retry(payload.prompt)
        if result is None:
            raise HTTPException(status_code=503, detail="AI backend unavailable – all models exhausted or cooling down.")
        return {"response": result}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Generation failed: {str(e)}")

@app.post("/analyze-problem")
def analyze_problem_endpoint(payload: ProblemRequest):
    try:
        return karmax_ai.analyze_problem(payload.problem)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Problem analysis failed: {str(e)}")

@app.post("/generate-quiz")
def generate_quiz_endpoint(payload: QuizRequest):
    try:
        return karmax_ai.generate_quiz(payload.problem_title, payload.causes)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Quiz generation failed: {str(e)}")

@app.post("/analyze")
def analyze_behavior(payload: AnalyzeRequest):
    try:
        result = karmax_ai.analyze_and_generate_quests(
            player_name=payload.player_name,
            schedule=payload.schedule,
            problem_title=payload.problem_title,
            problem_subtitle=payload.problem_subtitle,
            selected_causes=payload.selected_causes,
            quiz_answers=payload.quiz_answers,
            sleep_hours=payload.sleep_hours,
            study_hours=payload.study_hours,
            screen_time_hours=payload.screen_time_hours,
            stress_level=payload.stress_level,
            physical_activity_hours=payload.physical_activity_hours,
            social_hours=payload.social_hours,
            gpa=payload.gpa,
            emotion=payload.emotion,
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")

# ── Entry point ───────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)