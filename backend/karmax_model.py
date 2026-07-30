import os
import re
import json
import time
import datetime
import hashlib
import requests
from typing import Dict, Any, List, Optional, Tuple

from dotenv import dotenv_values

# Candidate .env locations, checked in this order (relative to this file's
# directory, i.e. backend/). The FIRST one that contains a real-looking
# GEMINI_API_KEY wins - unlike load_dotenv()'s silent "first file loaded
# wins even if it's an empty placeholder" behavior, this explicitly SKIPS
# placeholder/empty values and prints which file it actually used, so a
# stray unfilled .env can never silently shadow the real key again.
_ENV_DIR = os.path.dirname(os.path.abspath(__file__))
_CANDIDATE_ENV_FILES = [
    os.path.join(_ENV_DIR, ".env.local"),
    os.path.join(_ENV_DIR, ".env"),
    os.path.join(_ENV_DIR, "..", "assets", ".env.local"),
    os.path.join(_ENV_DIR, "..", "assets", ".env"),
    os.path.join(_ENV_DIR, "..", ".env.local"),
    os.path.join(_ENV_DIR, "..", ".env"),
]
_PLACEHOLDER_MARKERS = ("your_", "here", "xxxx", "changeme", "replace", "<", "example")


def _looks_like_placeholder(value: str) -> bool:
    lowered = value.strip().lower()
    return any(marker in lowered for marker in _PLACEHOLDER_MARKERS)


def _resolve_gemini_api_key() -> str:
    """Checks each candidate .env file in order and returns the first
    non-empty, non-placeholder-looking GEMINI_API_KEY it finds. Prints
    exactly which file it used (or skipped and why) so this is never a
    silent guessing game again."""
    # A real env var set outside any .env file (e.g. exported in the shell,
    # or set in a deployment platform) still takes priority, same as before.
    env_var = os.environ.get("GEMINI_API_KEY", "").strip('"\' ')
    if env_var and not _looks_like_placeholder(env_var):
        print("[KarmaxModel] Using GEMINI_API_KEY from the process environment (not a .env file).")
        return env_var

    for path in _CANDIDATE_ENV_FILES:
        if not os.path.isfile(path):
            continue
        values = dotenv_values(path)
        candidate = (values.get("GEMINI_API_KEY") or "").strip('"\' ')
        if not candidate:
            continue
        if _looks_like_placeholder(candidate):
            print(f"[KarmaxModel] Skipping GEMINI_API_KEY in {path} - looks like an unfilled placeholder.")
            continue
        print(f"[KarmaxModel] Using GEMINI_API_KEY from {path}")
        return candidate

    return ""


class KarmaxModel:
    """
    Karmax Behavior Analysis & Gamified RPG Adventure Quest Engine using Gemini API.

    API-usage safeguards built in:
      - A process-wide response cache (shared across EVERY user hitting this
        backend, not per-device) with per-endpoint TTLs, so identical or
        near-identical requests never re-hit Gemini.
      - Continuous-input bucketing for the quest endpoint, so users with
        *similar* (not necessarily identical) lifestyle stats land on the
        same cache entry instead of each triggering a fresh generation.
      - player_name is intentionally kept OUT of the prompt and cache key —
        it's flavor text, not part of the output schema, and including it
        would make every single request unique and un-cacheable.
      - A per-model cooldown: once a model returns 429, every request (from
        every user, not just the one that got rate-limited) skips it until
        the cooldown expires, instead of independently rediscovering the
        same rate limit over and over.
      - Retry logic that fails fast to the next model on a 429 instead of
        hammering the same exhausted model 2-3 more times.
    """

    MODEL_NAME = "gemini-3.1-flash-lite"
    # NOTE: Gemini model availability changes fast and varies PER API KEY, and
    # ListModels() and generateContent() don't always agree (gemini-2.5-flash-lite
    # showed up in this key's ListModels output but 404'd on an actual
    # generateContent call - "no longer available to new users"). Trust a live
    # generateContent success/failure over the model list. Run
    # list_available_models.py periodically, but verify anything new by
    # actually watching the server logs for a real "Success on model 'X'"
    # line before trusting it long-term.
    #
    # This list mixes model families on purpose (3.6 / 3.1 / 2.0) so an
    # outage or quota exhaustion on one generation doesn't take out every
    # fallback at once.
    FALLBACK_MODELS = [
        "gemini-3.1-flash-lite",
        "gemini-3.6-flash",       # confirmed working - newest, best quality
        "gemini-flash-latest",    # confirmed working - auto-updated alias  # confirmed working - cheap & fast
        "gemini-2.0-flash",       # different generation entirely, confirmed
                                   # present for this key - last-resort diversity
    ]
    BASE_URL_TEMPLATE = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"

    # ── Cache TTLs (seconds) ────────────────────────────────────────────
    PROBLEM_CACHE_TTL = 7 * 24 * 3600   # problem diagnoses are generic -> cache a week
    QUIZ_CACHE_TTL = 7 * 24 * 3600      # quiz questions are generic -> cache a week
    QUEST_CACHE_TTL = 24 * 3600         # quests are meant to refresh daily
    FALLBACK_CACHE_TTL = 60             # briefly cache fallback data too, so a Gemini
                                         # outage doesn't cause every request in the next
                                         # minute to re-attempt the full model sweep

    # ── Retry tuning ─────────────────────────────────────────────────────
    MAX_ATTEMPTS_PER_MODEL = 2          # only for transient/network errors, NOT 429
    BASE_BACKOFF_SECONDS = 1
    MODEL_COOLDOWN_SECONDS = 60         # skip a rate-limited (429) model for this long
    OVERLOAD_COOLDOWN_SECONDS = 20      # skip a temporarily-overloaded (503) model for this long

    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or _resolve_gemini_api_key()
        if not self.api_key:
            print("[KarmaxModel] Warning: no valid GEMINI_API_KEY found in any .env file "
                  "(or only placeholder values were found).")

        # In-memory cache shared across every request this process serves.
        # Structure: {cache_key: (payload, expires_at_epoch_seconds)}
        self._cache: Dict[str, Tuple[Dict[str, Any], float]] = {}

        # Per-model rate-limit cooldowns. Structure: {model_name: cooldown_until_epoch}
        self._model_cooldowns: Dict[str, float] = {}

    # ── Cache helpers ────────────────────────────────────────────────────
    @staticmethod
    def _normalize(text: str) -> str:
        """Lower-cases, strips punctuation and collapses whitespace so
        near-identical free text collapses to the same cache key."""
        text = (text or "").lower()
        text = re.sub(r"[^\w\s]", "", text)
        text = re.sub(r"\s+", " ", text)
        return text.strip()

    @staticmethod
    def _bucket(value: float, step: float) -> float:
        """Rounds a continuous value to the nearest `step` so users with
        similar (not identical) stats share a cache entry."""
        return round(value / step) * step

    def _make_cache_key(self, prefix: str, params: Dict[str, Any]) -> str:
        encoded = json.dumps(params, sort_keys=True)
        digest = hashlib.sha256(encoded.encode("utf-8")).hexdigest()
        return f"{prefix}:{digest}"

    def _resolve_supabase_creds(self) -> Tuple[str, str]:
        """Resolves SUPABASE_URL and SUPABASE_ANON_KEY from process environment or candidate .env files."""
        if hasattr(self, "_supabase_url") and hasattr(self, "_supabase_key"):
            return self._supabase_url, self._supabase_key

        url = os.environ.get("SUPABASE_URL", "")
        key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "") or os.environ.get("SUPABASE_ANON_KEY", "")
        if not (url and key):
            for path in _CANDIDATE_ENV_FILES:
                if os.path.isfile(path):
                    vals = dotenv_values(path)
                    url = url or vals.get("SUPABASE_URL", "")
                    key = key or vals.get("SUPABASE_SERVICE_ROLE_KEY", "") or vals.get("SUPABASE_ANON_KEY", "")
                    if url and key:
                        break

        self._supabase_url = url.strip('"\' ')
        self._supabase_key = key.strip('"\' ')
        return self._supabase_url, self._supabase_key

    def _cache_get(self, key: str) -> Optional[Dict[str, Any]]:
        # 1. Check RAM cache first (0ms ultra-fast)
        entry = self._cache.get(key)
        if entry is not None:
            payload, expires_at = entry
            if time.time() < expires_at:
                return payload
            del self._cache[key]  # Stale entry — drop it

        # 2. Check Supabase persistent DB cache fallback (~50ms, survives server restarts)
        url, anon_key = self._resolve_supabase_creds()
        if url and anon_key:
            try:
                headers = {"apikey": anon_key, "Authorization": f"Bearer {anon_key}"}
                resp = requests.get(
                    f"{url}/rest/v1/ai_cache?key=eq.{key}&select=payload,expires_at",
                    headers=headers,
                    timeout=2.0
                )
                if resp.status_code == 200:
                    data = resp.json()
                    if data and isinstance(data, list) and len(data) > 0:
                        row = data[0]
                        payload = row.get("payload")
                        expires_at_str = row.get("expires_at")
                        if payload and expires_at_str:
                            # Parse ISO timestamp
                            dt = datetime.datetime.fromisoformat(expires_at_str.replace("Z", "+00:00"))
                            rem_ttl = dt.timestamp() - time.time()
                            if rem_ttl > 0:
                                print(f"[KarmaxModel] Supabase DB Cache HIT for '{key}' - populating RAM cache.")
                                self._cache[key] = (payload, time.time() + rem_ttl)
                                return payload
                else:
                    # Non-2xx (e.g. 401/403 from an RLS policy blocking the anon
                    # key) was previously swallowed silently, making the DB
                    # cache look "empty" with no clue why. Surface it instead.
                    print(f"[KarmaxModel] Supabase DB Cache GET failed for '{key}': "
                          f"HTTP {resp.status_code} - {resp.text[:300]}")
            except Exception as exc:
                print(f"[KarmaxModel] Supabase DB Cache GET error for '{key}': {exc}")
                # Gracefully fall back to generator on any DB connection error

        return None

    def _cache_set(self, key: str, payload: Dict[str, Any], ttl_seconds: float) -> None:
        expires_at = time.time() + ttl_seconds
        # 1. Save to RAM cache
        self._cache[key] = (payload, expires_at)

        # 2. Save to Supabase persistent DB cache
        url, anon_key = self._resolve_supabase_creds()
        if url and anon_key:
            try:
                expires_dt = datetime.datetime.fromtimestamp(expires_at, tz=datetime.timezone.utc).isoformat()
                headers = {
                    "apikey": anon_key,
                    "Authorization": f"Bearer {anon_key}",
                    "Content-Type": "application/json",
                    "Prefer": "resolution=merge-duplicates"
                }
                body = {
                    "key": key,
                    "payload": payload,
                    "expires_at": expires_dt
                }
                resp = requests.post(
                    f"{url}/rest/v1/ai_cache",
                    headers=headers,
                    json=body,
                    timeout=2.0
                )
                if resp.status_code >= 400:
                    # Previously ignored entirely - a blocked write (e.g. RLS
                    # enabled with no policy on ai_cache) failed 100% of the
                    # time with zero indication in the logs. Surface it.
                    print(f"[KarmaxModel] Supabase DB Cache SET failed for '{key}': "
                          f"HTTP {resp.status_code} - {resp.text[:300]}")
            except Exception as exc:
                print(f"[KarmaxModel] Supabase DB Cache SET error for '{key}': {exc}")

    @staticmethod
    def _classify_problem_intent(text: str) -> str:
        """Categorizes raw student problem text into semantic intent clusters
        so equivalent phrasings (e.g. 'I cannot focus' vs 'I have problem focusing')
        share a cache entry."""
        lowered = (text or "").lower()

        has_focus = any(w in lowered for w in ["focus", "concentrat", "distract", "attention", "wander", "mind"])
        has_screen = any(w in lowered for w in ["screen", "phone", "scroll", "social media", "tiktok", "instagram", "youtube", "reels", "doomscroll"])
        has_sleep = any(w in lowered for w in ["sleep", "tired", "exhaust", "wake", "insomnia", "fatigue", "nap", "drowsy", "yawn"])
        has_procrastination = any(w in lowered for w in ["procrastinat", "delay", "put off", "initiat", "motivation", "avoid"])
        has_stress = any(w in lowered for w in ["stress", "overwhelm", "burnout", "burn out"])
        has_study = any(w in lowered for w in ["study", "exam", "homework", "assignment", "grade", "gpa", "subject", "lecture", "textbook"])
        # ── More specific intents checked BEFORE generic ones ────────────
        has_social_anxiety = any(w in lowered for w in ["stage fright", "presentation", "public speak", "oral", "speech", "perform", "audience", "nervou", "anxi", "shy", "embarrass", "fear speak"])
        has_time_mgmt = any(w in lowered for w in ["time manag", "schedule", "deadline", "priorit", "plan", "organiz", "routine", "structure"])
        has_eating = any(w in lowered for w in ["eat", "meal", "diet", "food", "skip meal", "skip breakfast", "snack", "nutrition", "hungry", "binge"])
        has_social_relations = any(w in lowered for w in ["friend", "relation", "loneli", "isolat", "social", "people", "communic", "interact"])
        has_memory = any(w in lowered for w in ["memor", "forget", "recall", "retain", "remember", "revision"])

        # Specific high-priority rules first (prevent generic rules swallowing them)
        if has_social_anxiety:
            return "intent:social_anxiety_performance"
        if has_memory:
            return "intent:memory_retention"
        if has_eating:
            return "intent:eating_habits"
        if has_time_mgmt:
            return "intent:time_management"
        if has_social_relations and not has_focus:
            return "intent:social_isolation"
        # Generic rules
        if has_focus and has_screen:
            return "intent:focus_digital"
        if has_focus and has_sleep:
            return "intent:focus_burnout"
        if has_focus or (has_study and not (has_sleep or has_stress or has_procrastination)):
            return "intent:focus_study"
        if has_sleep:
            return "intent:sleep_fatigue"
        if has_procrastination:
            return "intent:procrastination"
        if has_stress:
            return "intent:stress_anxiety"
        if has_screen:
            return "intent:digital_drain"

        # ── Dynamic Intent: extract meaningful keywords from unmapped text ──
        return KarmaxModel._dynamic_intent(text)

    # Common English stopwords and filler words that carry no meaning for bucketing
    _STOPWORDS = frozenset({
        "a", "an", "the", "and", "or", "but", "in", "on", "at", "to",
        "for", "of", "with", "by", "from", "is", "am", "are", "was",
        "were", "be", "been", "being", "have", "has", "had", "do", "does",
        "did", "will", "would", "could", "should", "may", "might", "shall",
        "can", "i", "my", "me", "we", "us", "our", "you", "your", "it",
        "its", "he", "she", "they", "them", "their", "this", "that",
        "these", "those", "what", "when", "where", "how", "who", "which",
        "very", "really", "just", "so", "too", "also", "always", "never",
        "get", "got", "feel", "feels", "feeling", "felt", "make", "makes",
        "made", "keep", "keeps", "kept", "seem", "seems", "like", "want",
        "not", "no", "any", "all", "some", "if", "than", "then", "up",
        "down", "out", "about", "into", "over", "after", "before", "more",
        "much", "many", "every", "bit", "lot", "time", "thing", "things",
        "way", "days", "day", "life", "now", "even", "still", "try", "help",
        "cannot", "cant", "dont", "wont", "couldnt", "shouldnt", "wouldnt",
        "its", "ive", "im", "theyre", "theres", "its", "whats",
    })

    # Simple suffix-stripping rules applied in order (longest suffix first)
    _STEM_RULES = [
        # Longest suffixes first to prevent premature truncation
        ("inging", "ing"), ("ations", "ate"), ("nesses", ""), ("ments", ""),
        ("pping", "p"), ("tting", "t"), ("nning", "n"),  # double-consonant+ing: skipping->skip
        ("ation", "ate"), ("tions", "tion"), ("ities", "ity"), ("iness", "y"),
        ("ness", ""), ("ment", ""), ("tion", ""), ("ings", ""), ("ing", ""),
        ("ity", ""), ("ies", "y"), ("ped", "p"), ("ted", "t"), ("ned", "n"),
        ("ern", ""), ("tern", ""),
        ("ed", ""), ("er", ""), ("ly", ""),
        ("al", ""), ("ic", ""), ("es", "e"), ("s", ""),
    ]

    @staticmethod
    def _stem(word: str) -> str:
        """Applies simple suffix-stripping to reduce related forms to a common root."""
        if len(word) < 5:
            return word
        for suffix, replacement in KarmaxModel._STEM_RULES:
            if word.endswith(suffix) and len(word) - len(suffix) >= 3:
                return word[: len(word) - len(suffix)] + replacement
        return word

    @staticmethod
    def _dynamic_intent(text: str) -> str:
        """Generates a stable, reusable intent key from the meaningful keywords
        in a novel/unmapped problem description. Different phrasings of the same
        topic collapse to an identical key because keywords are stemmed and sorted."""
        import re
        words = re.findall(r"[a-z]+", (text or "").lower())
        # Keep words that are at least 4 chars and not stopwords
        meaningful = [
            w for w in words
            if len(w) >= 4 and w not in KarmaxModel._STOPWORDS
        ]
        # Stem each word and deduplicate while preserving sort order
        stems = sorted(set(KarmaxModel._stem(w) for w in meaningful))
        # Take up to 5 most alphabetically-stable stems for the key
        key_parts = [s for s in stems if len(s) >= 3][:5]
        if not key_parts:
            return f"problem:{KarmaxModel._normalize(text)}"
        return "intent:dyn_" + "_".join(key_parts)

    # ── 1. Analyze free-text problem ──────────────────────────────────────
    def analyze_problem(self, raw_problem: str) -> Dict[str, Any]:
        intent_key = self._classify_problem_intent(raw_problem)
        cache_key = self._make_cache_key("problem", {"intent": intent_key})
        cached = self._cache_get(cache_key)
        if cached is not None:
            print(f"[KarmaxModel] Cache hit for analyze_problem (intent '{intent_key}') - no API call made.")
            return cached

        prompt = (
            f'Analyze this student problem: "{raw_problem}"\n\n'
            'Reply with ONLY a valid raw JSON object. No markdown, no code fences.\n'
            'Required JSON shape:\n'
            '{\n'
            '  "id": "snake_case_id",\n'
            '  "title": "Short Punchy Title",\n'
            '  "subtitle": "One line summary",\n'
            '  "icon": "emoji",\n'
            '  "causes": ["cause 1", "cause 2", "cause 3", "cause 4", "cause 5"],\n'
            '  "summary": "Two empathetic sentences about their situation."\n'
            '}'
        )
        result = self._generate_with_retry(prompt, required_keys=["id", "title", "causes", "summary"])
        if result:
            self._cache_set(cache_key, result, self.PROBLEM_CACHE_TTL)
            return result

        fallback = {
            "id": "focus_and_momentum",
            "title": "Focus & Energy Reclaim",
            "subtitle": "Overcoming distraction and rebuilding study momentum",
            "icon": "⚡",
            "causes": [
                "High evening screen time exposure",
                "Irregular sleep and recharge cycles",
                "Decision fatigue when starting tasks",
                "Dopamine burnout from social feeds",
                "Unstructured study environments"
            ],
            "summary": "You are experiencing classic focus fragmentation caused by digital fatigue. By restructuring your evening shutdown and study sprints, you can reclaim your mental momentum."
        }
        self._cache_set(cache_key, fallback, self.FALLBACK_CACHE_TTL)
        return fallback

    # ── 2. Generate quiz questions ────────────────────────────────────────
    def generate_quiz(self, problem_title: str, causes: List[str]) -> Dict[str, Any]:
        causes = causes or []
        cache_key = self._make_cache_key("quiz", {
            "problem_title": self._normalize(problem_title),
            "causes": sorted(self._normalize(c) for c in causes),
        })
        cached = self._cache_get(cache_key)
        if cached is not None:
            print("[KarmaxModel] Cache hit for generate_quiz - no API call made.")
            return cached

        cause_list = ", ".join(causes[:3]) if causes else "General focus drain"
        prompt = (
            f'Student problem: {problem_title}. Root causes: {cause_list}\n\n'
            'Generate exactly 5 diagnostic quiz questions for this student.\n'
            'Reply with ONLY a valid raw JSON object. No markdown.\n'
            'Required shape:\n'
            '{"questions":[{"question":"question text","options":["opt1","opt2","opt3","opt4"]}]}'
        )
        result = self._generate_with_retry(prompt, required_keys=["questions"])
        if result and isinstance(result.get("questions"), list) and len(result["questions"]) > 0:
            self._cache_set(cache_key, result, self.QUIZ_CACHE_TTL)
            return result

        fallback = {
            "questions": [
                {
                    "question": "When do you feel most distracted during the day?",
                    "options": ["Late night before bed", "Right after waking up", "During study sessions", "In the late afternoon"]
                },
                {
                    "question": "How often do you check your phone while studying?",
                    "options": ["Every 5-10 minutes", "Every 30 minutes", "Once an hour", "Only when taking a break"]
                },
                {
                    "question": "What is your main barrier to starting a task?",
                    "options": ["Feeling overwhelmed by size", "Lack of energy/sleepiness", "Digital notifications", "Unclear priorities"]
                },
                {
                    "question": "How many hours of sleep do you average per night?",
                    "options": ["Less than 5 hours", "5 to 6 hours", "6 to 7 hours", "8+ hours"]
                },
                {
                    "question": "How do you feel after a long screen-time session?",
                    "options": ["Brain fog & exhausted", "Anxious or restless", "Neutral", "Motivated"]
                }
            ]
        }
        self._cache_set(cache_key, fallback, self.FALLBACK_CACHE_TTL)
        return fallback

    # ── 3. Analyze behavior & generate RPG quests ──────────────────────────
    def analyze_and_generate_quests(
        self,
        player_name: str,
        schedule: str,
        problem_title: str,
        problem_subtitle: str = "",
        selected_causes: List[str] = None,
        quiz_answers: List[str] = None,
        sleep_hours: float = 7.0,
        study_hours: float = 4.0,
        screen_time_hours: float = 5.0,
        stress_level: int = 3,
        physical_activity_hours: float = 1.0,
        social_hours: float = 2.0,
        gpa: float = 3.0,
        emotion: str = "Neutral"
    ) -> Dict[str, Any]:
        selected_causes = selected_causes or []
        quiz_answers = quiz_answers or []

        # Bucket continuous inputs so users with SIMILAR (not identical)
        # lifestyle stats share a cache entry. player_name is deliberately
        # excluded - see class docstring.
        bucketed = {
            "schedule": self._normalize(schedule),
            "problem_title": self._normalize(problem_title),
            "problem_subtitle": self._normalize(problem_subtitle),
            "selected_causes": sorted(self._normalize(c) for c in selected_causes),
            "quiz_answers": [self._normalize(a) for a in quiz_answers],
            "sleep_hours": self._bucket(sleep_hours, 1.0),
            "study_hours": self._bucket(study_hours, 1.0),
            "screen_time_hours": self._bucket(screen_time_hours, 1.0),
            "stress_level": stress_level,
            "physical_activity_hours": self._bucket(physical_activity_hours, 1.0),
            "social_hours": self._bucket(social_hours, 1.0),
            "gpa": self._bucket(gpa, 0.5),
            "emotion": self._normalize(emotion),
        }
        cache_key = self._make_cache_key("quests", bucketed)
        cached = self._cache_get(cache_key)
        if cached is not None:
            print("[KarmaxModel] Cache hit for analyze_and_generate_quests - no API call made.")
            return cached

        prompt = self._build_prompt(
            schedule=schedule,
            problem_title=problem_title,
            problem_subtitle=problem_subtitle,
            selected_causes=selected_causes,
            quiz_answers=quiz_answers,
            sleep_hours=sleep_hours,
            study_hours=study_hours,
            screen_time_hours=screen_time_hours,
            stress_level=stress_level,
            physical_activity_hours=physical_activity_hours,
            social_hours=social_hours,
            gpa=gpa,
            emotion=emotion
        )

        res = self._generate_with_retry(prompt, required_keys=["primary_problem", "root_cause", "reasoning", "daily", "weekly"])
        if res:
            self._cache_set(cache_key, res, self.QUEST_CACHE_TTL)
            return res

        fallback = self._get_fallback_response()
        self._cache_set(cache_key, fallback, self.FALLBACK_CACHE_TTL)
        return fallback

    def _build_prompt(
        self,
        schedule: str,
        problem_title: str,
        problem_subtitle: str,
        selected_causes: List[str],
        quiz_answers: List[str],
        sleep_hours: float,
        study_hours: float,
        screen_time_hours: float,
        stress_level: int,
        physical_activity_hours: float,
        social_hours: float,
        gpa: float,
        emotion: str
    ) -> str:
        causes_str = ", ".join(selected_causes[:3]) if selected_causes else "None specified"
        quiz_str = "; ".join(quiz_answers[:3]) if quiz_answers else "None specified"

        system_instruction = (
            "You are Karmax, an AI Gamemaster and Behavioral System Coach.\n"
            "Treat the student as an RPG hero struggling against real-life debuffs (sleep debt, digital fatigue, focus drain).\n"
            "Analyze their lifestyle parameters, root causes, and diagnostic quiz answers.\n"
            "Generate an immersive, story-driven, adventure-flavored diagnosis and epic RPG quests to level up their life stats.\n\n"
            "TONE & STYLE GUIDELINES:\n"
            "- Make quest titles sound like epic RPG quests or cyberpunk ops (use emojis, action titles, e.g. '⚡ Operation Midnight Blackout', '⚔️ The 25-Min Deep Work Raid').\n"
            "- Explain why/benefit using RPG lore style (e.g., 'Purges digital poison to restore +20 HP & max mana for morning focus raids').\n"
            "- Make reasoning empathetic yet heroic, framing interventions as unlocking stat boosts.\n"
            "- Address the player generically as 'Hero' or 'Adventurer' - do not invent or assume a name.\n\n"
            "STRICT OUTPUT REQUIREMENTS:\n"
            "Return ONLY a single valid raw JSON object. Do not include markdown block formatting (no ```json).\n"
            "The JSON structure MUST follow this exact schema:\n"
            "{\n"
            '  "primary_problem": "Punchy RPG Debuff Name (3-5 words, e.g. Chrono-Fatigue & Screen Drain)",\n'
            '  "root_cause": "Key RPG Root Cause Factor",\n'
            '  "reasoning": "2-3 immersive, heroic sentences explaining the debuff loop and how these quests break it.",\n'
            '  "daily": [\n'
            '    {\n'
            '      "title": "Epic Daily Quest Title with Emoji",\n'
            '      "xp": 25,\n'
            '      "category": "discipline | health | focus | social",\n'
            '      "why": "Story-flavored RPG benefit explaining stat boost"\n'
            "    }\n"
            "  ],\n"
            '  "weekly": [\n'
            '    {\n'
            '      "title": "Epic Weekly Milestone Quest Title with Emoji",\n'
            '      "xp": 75,\n'
            '      "category": "discipline | health | focus | social",\n'
            '      "why": "Lore-based strategic achievement benefit"\n'
            "    }\n"
            "  ]\n"
            "}\n\n"
            "Generate EXACTLY 5 daily quests and EXACTLY 3 weekly quests."
        )

        user_input_summary = (
            f"HERO PROFILE:\n"
            f"- Operating Schedule: {schedule}\n"
            f"- Main Debuff/Problem: {problem_title} ({problem_subtitle})\n"
            f"- Identified Root Causes: {causes_str}\n"
            f"- Diagnostic Quiz Input: {quiz_str}\n\n"
            f"LIFESTYLE STATS:\n"
            f"- Sleep Recharge: {sleep_hours:.1f} hours/night\n"
            f"- Focus/Study Energy: {study_hours:.1f} hours/day\n"
            f"- Screen Time Exposure: {screen_time_hours:.1f} hours/day\n"
            f"- Stress Level: {stress_level}/5\n"
            f"- Physical Stamina Activity: {physical_activity_hours:.1f} hours/day\n"
            f"- Social Connection: {social_hours:.1f} hours/day\n"
            f"- Academic Rank (GPA): {gpa:.1f}/4.0\n"
            f"- Current Mind State: {emotion}\n"
        )

        return f"{system_instruction}\n\n{user_input_summary}"

    def _generate_with_retry(self, prompt: str, required_keys: List[str] = None) -> Optional[Dict[str, Any]]:
        """
        Send *prompt* to Gemini, rotating through FALLBACK_MODELS.

        - Skips any model currently in cooldown (set after a 429 from that
          model), so a rate-limited model doesn't get hit again by THIS or
          any OTHER request until the cooldown expires.
        - On 429: sets a cooldown for that model and moves to the next model
          immediately - no same-model retry, since retrying an exhausted
          quota just guarantees more 429s.
        - On transient errors (network/timeout): retries the SAME model up
          to MAX_ATTEMPTS_PER_MODEL times with exponential backoff.
        - On 200 with malformed/missing-key content: treated as a model
          failure, fails fast to the next model (no point retrying the same
          prompt against the same model expecting a different shape).
        """
        if not self.api_key:
            return None

        headers = {
            "Content-Type": "application/json",
            "X-goog-api-key": self.api_key,
        }

        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {
                "temperature": 0.3,
                "maxOutputTokens": 2048,
                "responseMimeType": "application/json",
            },
        }

        for model_name in self.FALLBACK_MODELS:
            now = time.time()
            cooldown_until = self._model_cooldowns.get(model_name, 0)
            if now < cooldown_until:
                print(f"[KarmaxModel] Skipping '{model_name}' - in cooldown for {int(cooldown_until - now)}s more.")
                continue

            url = f"{self.BASE_URL_TEMPLATE.format(model=model_name)}?key={self.api_key}"
            attempt = 0
            backoff = self.BASE_BACKOFF_SECONDS

            while attempt < self.MAX_ATTEMPTS_PER_MODEL:
                attempt += 1
                try:
                    response = requests.post(url, headers=headers, json=payload, timeout=20)

                    if response.status_code == 200:
                        res_json = response.json()
                        candidates = res_json.get("candidates", [])
                        if candidates:
                            parts = candidates[0].get("content", {}).get("parts", [])
                            raw_text = "".join(p.get("text", "") for p in parts).strip()
                            cleaned = self._clean_json_string(raw_text)
                            parsed = self._parse_first_json_object(cleaned)
                            if parsed is not None and (required_keys is None or all(k in parsed for k in required_keys)):
                                print(f"[KarmaxModel] Success on model '{model_name}' (attempt {attempt}).")
                                parsed["model_version"] = model_name
                                return parsed
                        print(f"[KarmaxModel] Model '{model_name}' returned 200 but malformed/incomplete content.")
                        break  # don't retry same model for a malformed response

                    if response.status_code == 429:
                        print(f"[KarmaxModel] 429 rate limit on '{model_name}'. "
                              f"Cooling it down for {self.MODEL_COOLDOWN_SECONDS}s, moving to next model.")
                        self._model_cooldowns[model_name] = time.time() + self.MODEL_COOLDOWN_SECONDS
                        break  # do NOT retry the same model

                    if response.status_code == 503:
                        print(f"[KarmaxModel] 503 (model overloaded) on '{model_name}'. "
                              f"Cooling it down for {self.OVERLOAD_COOLDOWN_SECONDS}s, moving to next model.")
                        self._model_cooldowns[model_name] = time.time() + self.OVERLOAD_COOLDOWN_SECONDS
                        break  # instant retry on an overloaded model rarely helps - move on

                    print(f"[KarmaxModel] Model '{model_name}' returned HTTP {response.status_code}: {response.text}")
                    break

                except Exception as exc:
                    print(f"[KarmaxModel] Exception on model '{model_name}' (attempt {attempt}): {exc}")
                    if attempt < self.MAX_ATTEMPTS_PER_MODEL:
                        time.sleep(backoff)
                        backoff *= 2
                    continue

            print(f"[KarmaxModel] Moving to next fallback model after '{model_name}'.")

        print("[KarmaxModel] All fallback models exhausted or cooling down - returning None.")
        return None

    def _parse_first_json_object(self, text: str) -> Optional[Dict[str, Any]]:
        """Parses only the FIRST valid JSON object in `text` and ignores any
        trailing content after it. Gemini occasionally appends extra text
        after a complete, valid JSON object despite responseMimeType=json -
        plain json.loads() throws on that ("Extra data: line N column N"),
        which wastes a whole attempt on output that was actually usable."""
        try:
            obj, _end_index = json.JSONDecoder().raw_decode(text)
            return obj if isinstance(obj, dict) else None
        except json.JSONDecodeError:
            return None

    def _clean_json_string(self, text: str) -> str:
        cleaned = text.strip()
        if cleaned.startswith("```json"):
            cleaned = cleaned[7:]
        elif cleaned.startswith("```"):
            cleaned = cleaned[3:]
        if cleaned.endswith("```"):
            cleaned = cleaned[:-3]
        return cleaned.strip()

    def _get_fallback_response(self) -> Dict[str, Any]:
        return {
            "model_version": "fallback-static",
            "primary_problem": "⚔️ Chrono-Drain & Screen-Curse Debuff",
            "root_cause": "Nocturnal Screen Exposure & Low Sleep Mana",
            "reasoning": "Your energy core is experiencing high screen-radiation drain before sleep, lowering your focus aura during daylight raids. Executing these tactical quests will cleanse digital toxins and boost your daily XP multiplier.",
            "daily": [
                {
                    "title": "⚡ Operation Midnight Blackout: Sever Screen Signal",
                    "xp": 25,
                    "category": "health",
                    "why": "Cleanses blue-light poison 1hr before sleep to fully recharge Mana and HP."
                },
                {
                    "title": "⚔️ Deep Work Crusade: 25-Min Focus Sprint",
                    "xp": 30,
                    "category": "focus",
                    "why": "Engages tactical focus mode to slay the Procrastination Specter without distraction."
                },
                {
                    "title": "🧪 Elixir of Vitality: Hydrate & 10-Min Outdoor Patrol",
                    "xp": 20,
                    "category": "health",
                    "why": "Restores baseline stamina and clears midday mental fog."
                },
                {
                    "title": "📜 Master Strategy: Map Tomorrow's 3 Boss Objectives",
                    "xp": 20,
                    "category": "discipline",
                    "why": "Eliminates morning decision fatigue for an instant activation energy bonus."
                },
                {
                    "title": "🛡️ Guild Connection: Phone-Free Social Raid",
                    "xp": 25,
                    "category": "social",
                    "why": "Replaces synthetic digital dopamine with real guildmate camaraderie."
                }
            ],
            "weekly": [
                {
                    "title": "👑 Fortress of Sleep: 7+ Hours Sleep for 4 Nights",
                    "xp": 80,
                    "category": "health",
                    "why": "Fortifies baseline focus aura and permanently boosts daily energy caps."
                },
                {
                    "title": "🏆 Deep Work Paragon: Complete 5 Tactical Focus Raids",
                    "xp": 100,
                    "category": "focus",
                    "why": "Conquers major academic dungeons and secures massive XP rewards."
                },
                {
                    "title": "🔍 Time-Crystal Audit: Review Screen-Time Drain",
                    "xp": 60,
                    "category": "discipline",
                    "why": "Grants high-level meta-awareness to seal time sinks."
                }
            ]
        }