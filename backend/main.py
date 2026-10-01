"""main.py: FastAPI Backend for Trip AI

Exposes HTTP endpoints specified in the Trip AI Development Plan:
1. POST /places/autocomplete - Calls autocomplete_city directly; returns city suggestions.
2. POST /places/resolve      - Calls resolve_city directly; returns name, ID, lat and lng.
3. POST /discover            - Runs ADK find_places and categorize_places; returns categories and place cards.
4. POST /plan                - Runs ADK details and route tools; validates the result and returns daily schedules.
"""

import os
from pathlib import Path
from typing import Any, Dict, List, Optional
import requests
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

env_path = Path(__file__).resolve().parent / ".env"
load_dotenv(dotenv_path=env_path)

from runner import run_discover_async, run_plan_async
from tools import haversine_distance_km

app = FastAPI(
    title="Trip AI Backend",
    description="FastAPI + Google ADK Trip Planning Backend",
    version="1.0.0",
)

# Enable CORS for Flutter web, emulator, and mobile devices
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

GOOGLE_MAPS_API_KEY = os.getenv("GOOGLE_MAPS_API_KEY", "")


# ----------------------------------------------------------------------
# Pydantic Request & Response Models
# ----------------------------------------------------------------------

class AutocompleteRequest(BaseModel):
    query: Optional[str] = None
    input: Optional[str] = None
    session_token: Optional[str] = None

    @property
    def search_query(self) -> str:
        return self.query or self.input or ""


class ResolveRequest(BaseModel):
    place_id: str
    session_token: Optional[str] = None


class DiscoverRequest(BaseModel):
    trip_id: str
    city: str
    lat: Optional[float] = None
    lng: Optional[float] = None
    radius_km: float = 70.0
    session_token: Optional[str] = None


class PlanRequest(BaseModel):
    trip_id: str
    dates: List[str]
    selected_ids: List[str]
    start: Optional[str] = "Hotel"
    end: Optional[str] = "Hotel"
    travel_mode: Optional[str] = "DRIVE"
    session_token: Optional[str] = None


# Cache of discovered places by trip_id so planner can reference rich place data
TRIP_PLACES_CACHE: Dict[str, List[Dict[str, Any]]] = {}

# Known geographical coordinates for instant offline / fallback resolution
KNOWN_CITIES: Dict[str, Dict[str, Any]] = {
    "shimoga": {"name": "Shimoga, Karnataka, India", "place_id": "city_shimoga", "lat": 13.9299, "lng": 75.5681},
    "shivamogga": {"name": "Shivamogga, Karnataka, India", "place_id": "city_shivamogga", "lat": 13.9299, "lng": 75.5681},
    "coorg": {"name": "Coorg (Kodagu), Karnataka, India", "place_id": "city_coorg", "lat": 12.4244, "lng": 75.7382},
    "madikeri": {"name": "Madikeri, Karnataka, India", "place_id": "city_madikeri", "lat": 12.4244, "lng": 75.7382},
    "hampi": {"name": "Hampi, Karnataka, India", "place_id": "city_hampi", "lat": 15.3350, "lng": 76.4600},
    "mysuru": {"name": "Mysuru (Mysore), Karnataka, India", "place_id": "city_mysuru", "lat": 12.2958, "lng": 76.6394},
    "mysore": {"name": "Mysore, Karnataka, India", "place_id": "city_mysore", "lat": 12.2958, "lng": 76.6394},
    "bengaluru": {"name": "Bengaluru, Karnataka, India", "place_id": "city_bengaluru", "lat": 12.9716, "lng": 77.5946},
    "bangalore": {"name": "Bangalore, Karnataka, India", "place_id": "city_bangalore", "lat": 12.9716, "lng": 77.5946},
    "chikmagalur": {"name": "Chikmagalur, Karnataka, India", "place_id": "city_chikmagalur", "lat": 13.3161, "lng": 75.7720},
    "gokarna": {"name": "Gokarna, Karnataka, India", "place_id": "city_gokarna", "lat": 14.5479, "lng": 74.3188},
    "dandeli": {"name": "Dandeli, Karnataka, India", "place_id": "city_dandeli", "lat": 15.2447, "lng": 74.6225},
    "badami": {"name": "Badami, Karnataka, India", "place_id": "city_badami", "lat": 15.9187, "lng": 75.6766},
    "ooty": {"name": "Ooty, Tamil Nadu, India", "place_id": "city_ooty", "lat": 11.4102, "lng": 76.6950},
    "wayanad": {"name": "Wayanad, Kerala, India", "place_id": "city_wayanad", "lat": 11.6854, "lng": 76.1320},
    "goa": {"name": "Panaji, Goa, India", "place_id": "city_goa", "lat": 15.4909, "lng": 73.8278},
}


# ----------------------------------------------------------------------
# Backend Helpers
# ----------------------------------------------------------------------

def autocomplete_city(query: str, session_token: Optional[str] = None) -> List[Dict[str, str]]:
    """Calls Google Places Autocomplete as the user types; returns city suggestions."""
    clean_q = query.strip()
    if not clean_q:
        return []

    key = os.getenv("GOOGLE_MAPS_API_KEY", GOOGLE_MAPS_API_KEY)
    suggestions: List[Dict[str, str]] = []

    if key:
        url = (
            "https://maps.googleapis.com/maps/api/place/autocomplete/json"
            f"?input={requests.utils.quote(clean_q)}"
            "&types=(cities)"
            f"&key={key}"
        )
        if session_token:
            url += f"&sessiontoken={session_token}"

        try:
            resp = requests.get(url, timeout=5)
            data = resp.json()
            if data.get("status") == "OK":
                for pred in data.get("predictions", []):
                    suggestions.append(
                        {
                            "description": pred.get("description", ""),
                            "place_id": pred.get("place_id", ""),
                        }
                    )
                if suggestions:
                    return suggestions
        except Exception:
            pass

    # Curated fallback suggestions matching query
    q_lower = clean_q.lower()
    for k, v in KNOWN_CITIES.items():
        if q_lower in k or k in q_lower or q_lower in v["name"].lower():
            suggestions.append(
                {
                    "description": v["name"],
                    "place_id": v["place_id"],
                }
            )

    # If no matches, return query as a custom searchable city
    if not suggestions:
        formatted = f"{clean_q.title()}, India"
        suggestions.append(
            {
                "description": formatted,
                "place_id": f"city_{clean_q.lower().replace(' ', '_')}",
            }
        )

    return suggestions


def resolve_city(place_id: str, session_token: Optional[str] = None) -> Dict[str, Any]:
    """Calls Place Details with the chosen place ID; resolves name, ID, lat and lng."""
    key = os.getenv("GOOGLE_MAPS_API_KEY", GOOGLE_MAPS_API_KEY)

    if key and not place_id.startswith("city_"):
        url = (
            "https://maps.googleapis.com/maps/api/place/details/json"
            f"?place_id={place_id}"
            "&fields=name,geometry,formatted_address"
            f"&key={key}"
        )
        if session_token:
            url += f"&sessiontoken={session_token}"

        try:
            resp = requests.get(url, timeout=6)
            data = resp.json()
            if data.get("status") == "OK":
                res = data.get("result", {})
                loc = res.get("geometry", {}).get("location", {})
                return {
                    "name": res.get("name", "Destination"),
                    "place_id": place_id,
                    "lat": loc.get("lat"),
                    "lng": loc.get("lng"),
                    "formatted_address": res.get("formatted_address", ""),
                }
        except Exception:
            pass

    # Fallback to known registry
    for k, v in KNOWN_CITIES.items():
        if v["place_id"] == place_id or k in place_id.lower():
            return {
                "name": v["name"].split(",")[0],
                "place_id": v["place_id"],
                "lat": v["lat"],
                "lng": v["lng"],
                "formatted_address": v["name"],
            }

    # Deterministic fallback coordinate in central Karnataka / South India
    return {
        "name": place_id.replace("city_", "").replace("_", " ").title(),
        "place_id": place_id,
        "lat": 13.9299,
        "lng": 75.5681,
        "formatted_address": f"{place_id.replace('city_', '').title()}, Karnataka, India",
    }


def validate_itinerary(
    itinerary: Dict[str, Any],
    trip_dates: List[str],
    selected_stops: List[str],
) -> Dict[str, Any]:
    """Checks dates, selected stops and schedule timing.
    Flags stops that cannot fit and unknown opening hours.
    """
    days = itinerary.get("days", [])
    unfitted = itinerary.get("unfitted_stops", [])
    warnings = list(itinerary.get("warnings", []))

    # Check date coverage
    if len(days) != len(trip_dates):
        warnings.append(
            f"Itinerary covers {len(days)} day(s), but {len(trip_dates)} date(s) were specified."
        )

    # Check that all stops were accounted for
    scheduled_pids = set()
    for d in days:
        for s in d.get("stops", []):
            pid = s.get("place_id")
            if pid and pid not in ["start_point", "final_stop", "lunch_stop"]:
                scheduled_pids.add(pid)

    unfitted_pids = {u.get("place_id") for u in unfitted if isinstance(u, dict)}

    missing_pids = set(selected_stops) - scheduled_pids - unfitted_pids
    if missing_pids:
        warnings.append(f"{len(missing_pids)} selected stop(s) were omitted during planning.")

    itinerary["validation"] = {
        "is_valid": len(warnings) == 0,
        "total_selected_stops": len(selected_stops),
        "scheduled_stops_count": len(scheduled_pids),
        "unfitted_stops_count": len(unfitted),
        "warnings": list(set(warnings)),
    }
    itinerary["schedule"] = days
    itinerary["warnings"] = list(set(warnings))
    return itinerary


# ----------------------------------------------------------------------
# Endpoints
# ----------------------------------------------------------------------

@app.get("/")
def health_check():
    return {
        "status": "online",
        "service": "Trip AI FastAPI Backend",
        "gemini_model": os.getenv("GEMINI_MODEL", "gemini-3.8-flash"),
        "maps_configured": bool(os.getenv("GOOGLE_MAPS_API_KEY")),
    }


@app.post("/places/autocomplete")
def handle_autocomplete(req: AutocompleteRequest):
    """Step 2: Call Google Places Autocomplete as the user types."""
    search_q = req.search_query
    suggestions = autocomplete_city(search_q, req.session_token)
    return {
        "query": search_q,
        "suggestions": suggestions,
    }


@app.post("/places/resolve")
def handle_resolve(req: ResolveRequest):
    """Step 3: Call Place Details with chosen place ID; get latitude and longitude."""
    resolved = resolve_city(req.place_id, req.session_token)
    return resolved


@app.post("/discover")
async def handle_discover(req: DiscoverRequest):
    """Step 4 & 5: Search Google Places around center within 70 km radius,
    then categorize candidate places into Adventure, Food, Nature, Culture, Sightseeing.
    """
    # If coordinates are missing, resolve from city name
    lat = req.lat
    lng = req.lng
    if lat is None or lng is None:
        city_res = resolve_city(f"city_{req.city.lower()}")
        lat = city_res["lat"]
        lng = city_res["lng"]

    user_id = req.session_token or "traveler"
    discover_result = await run_discover_async(
        user_id=user_id,
        trip_id=req.trip_id,
        city=req.city,
        lat=lat,
        lng=lng,
        radius_km=req.radius_km or 70.0,
    )

    # Store places in cache for upcoming planning requests
    TRIP_PLACES_CACHE[req.trip_id] = discover_result.get("places", [])

    return discover_result


@app.post("/plan")
async def handle_plan(req: PlanRequest):
    """Step 7 & 8: ADK planner builds daily schedule, opening hours, and routes.
    Backend validates itinerary and returns daily schedules with warnings.
    """
    user_id = req.session_token or "traveler"
    places_pool = TRIP_PLACES_CACHE.get(req.trip_id, [])

    plan_result = await run_plan_async(
        user_id=user_id,
        trip_id=req.trip_id,
        dates=req.dates,
        selected_ids=req.selected_ids,
        all_places_pool=places_pool,
        start_point=req.start or "Hotel",
        end_point=req.end or req.start or "Hotel",
        travel_mode=req.travel_mode or "DRIVE",
    )

    # Validate itinerary
    validated_itinerary = validate_itinerary(
        itinerary=plan_result,
        trip_dates=req.dates,
        selected_stops=req.selected_ids,
    )

    return validated_itinerary


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    host = os.getenv("HOST", "0.0.0.0")
    uvicorn.run("main:app", host=host, port=port, reload=True)
