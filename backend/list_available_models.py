"""
Run this once (and any time you see a 404 'no longer available' error) to see
exactly which Gemini models YOUR key can call.

This reuses KarmaxModel's own .env resolution logic instead of re-guessing the
load order, so the key it tests is GUARANTEED to be the same one main.py
actually uses at runtime.

Usage:
    cd backend
    python list_available_models.py
"""
import requests
from karmax_model import KarmaxModel

km = KarmaxModel()
api_key = km.api_key

if not api_key:
    raise SystemExit("KarmaxModel resolved no GEMINI_API_KEY at all - check your .env files.")

masked = f"...{api_key[-6:]}" if len(api_key) > 6 else "(too short to mask)"
print(f"Testing the SAME key karmax_model.py resolves at runtime: {masked}\n")

url = "https://generativelanguage.googleapis.com/v1beta/models"
resp = requests.get(url, headers={"X-goog-api-key": api_key}, timeout=20)

if resp.status_code != 200:
    print(f"Header auth failed ({resp.status_code}): {resp.text}\n")
    print("Retrying with the key as a query param instead...\n")
    resp = requests.get(url, params={"key": api_key}, timeout=20)

if resp.status_code != 200:
    print(f"Query-param auth also failed ({resp.status_code}): {resp.text}")
    raise SystemExit(
        "\nBoth auth methods failed with the SAME key your app uses to "
        "successfully call generateContent. That's unusual - if generateContent "
        "works but ListModels doesn't for the identical key, check:\n"
        "  - whether the key has an 'API restrictions' setting in Google Cloud\n"
        "    Console that only allows specific methods, not the whole API\n"
        "  - whether you're on a free-tier/AI-Studio key that scopes ListModels\n"
        "    differently from generateContent\n"
        "Either way this isn't fatal - the FALLBACK_MODELS list in "
        "karmax_model.py will still work as long as generateContent itself "
        "succeeds for those model names."
    )

models = resp.json().get("models", [])
print(f"{len(models)} models visible to this key. "
      f"Ones that support generateContent (usable by KarmaxModel):\n")

usable = []
for m in models:
    name = m.get("name", "").removeprefix("models/")
    methods = m.get("supportedGenerationMethods", [])
    if "generateContent" in methods:
        usable.append(name)
        print(f"  - {name}")

if not usable:
    print("  (none found - see the raw response below)")
    print(resp.json())
else:
    print(f"\nSuggested FALLBACK_MODELS list (put your fastest/cheapest first):")
    print("FALLBACK_MODELS = [")
    for name in usable[:5]:
        print(f'    "{name}",')
    print("]")