"""runner.py: ADK Runner and Session Management for Trip AI

Creates:
1. InMemorySessionService: In-memory session tracking per user and trip.
2. Runner: ADK Runner for orchestrating agents and tools.
3. run_discover_async: Discovers places within 70 km and classifies them into 5 categories.
4. run_plan_async: Coordinates daily itinerary generation, routing, opening hours, and meals.
"""

import asyncio
import json
import logging
import os
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple
from dotenv import load_dotenv

env_path = Path(__file__).resolve().parent / ".env"
load_dotenv(dotenv_path=env_path)

from google.adk.runners import Runner
from google.adk.sessions import InMemorySessionService
from google.genai import types

from agents import (
    planner_agent,
    deterministic_categorize_places,
    build_daily_schedules_programmatic,
)
from tools import find_places, get_place_details, compute_route

logger = logging.getLogger("trip_ai.runner")

# ---------------------------------------------------------------------------
# Server-side discover cache: avoids re-hitting Google Places + Gemini for the
# same city within a 30-minute window.  Key = (city_lower, lat_1dp, lng_1dp).
# ---------------------------------------------------------------------------
_DISCOVER_CACHE: Dict[Tuple, Dict[str, Any]] = {}
_CACHE_TTL_SEC = 1800  # 30 minutes


# In-memory session service storing conversational state for active trips
session_service = InMemorySessionService()

# Central ADK Runner wrapping the planner agent
planner_runner = Runner(
    app_name="trip_ai_planner",
    agent=planner_agent,
    session_service=session_service,
)


async def run_discover_async(
    user_id: str,
    trip_id: str,
    city: str,
    lat: float,
    lng: float,
    radius_km: float = 70.0,
) -> Dict[str, Any]:
    """Runs discovery within 70 km radius and groups candidate places into 5 categories:
    Adventure, Food, Nature, Culture, Sightseeing.
    """
    # -----------------------------------------------------------------------
    # 1. Cache check — return immediately if we already processed this city
    # -----------------------------------------------------------------------
    cache_key = (city.lower().strip(), round(lat, 1), round(lng, 1))
    cached = _DISCOVER_CACHE.get(cache_key)
    if cached and (time.time() - cached["_ts"]) < _CACHE_TTL_SEC:
        # Return a fresh copy with the requested trip_id
        result = dict(cached)
        result["trip_id"] = trip_id
        result.pop("_ts", None)
        logger.info(f"Discover cache HIT for {city!r} — returning instantly")
        return result

    # -----------------------------------------------------------------------
    # 2. Discover candidate places (parallel HTTP — fast)
    # -----------------------------------------------------------------------
    # find_places now uses ThreadPoolExecutor internally, so wrap in executor
    # to avoid blocking the async event loop.
    loop = asyncio.get_event_loop()
    candidates = await loop.run_in_executor(
        None, find_places, city, lat, lng, radius_km
    )

    # -----------------------------------------------------------------------
    # 3. Categorise using fast deterministic classifier (no Gemini round-trip)
    # -----------------------------------------------------------------------
    categories = deterministic_categorize_places(candidates)

    result = {
        "trip_id": trip_id,
        "city": city,
        "center": {"lat": lat, "lng": lng},
        "radius_km": radius_km,
        "total_places": len(candidates),
        "categories": categories,
        "places": candidates,
    }

    # Store in cache
    _DISCOVER_CACHE[cache_key] = {**result, "_ts": time.time()}

    return result


async def run_plan_async(
    user_id: str,
    trip_id: str,
    dates: List[str],
    selected_ids: List[str],
    all_places_pool: List[Dict[str, Any]],
    start_point: str,
    end_point: str,
    hotel: Optional[str] = None,
    travel_mode: str = "DRIVE",
    selected_names: Optional[List[str]] = None,
) -> Dict[str, Any]:
    """Runs ADK planner agent with get_place_details and compute_route tools
    to generate an optimized, scheduled daily itinerary.
    """
    # Filter selected place objects (by place_id and by name)
    places_lookup = {p["place_id"]: p for p in all_places_pool}
    for p in all_places_pool:
        if "name" in p:
            places_lookup[p["name"]] = p

    selected_places = []
    for idx, pid in enumerate(selected_ids):
        if pid in places_lookup:
            selected_places.append(places_lookup[pid])
        elif selected_names and idx < len(selected_names) and selected_names[idx]:
            selected_places.append(
                {
                    "place_id": pid,
                    "name": selected_names[idx],
                    "types": ["tourist_attraction"],
                    "rating": 4.6,
                }
            )
        else:
            # Fallback for unknown id
            name = pid.replace("local_", "").replace("city_", "").replace("_", " ").title()
            if "stop" in name.lower() or not name.strip():
                name = "City Attraction Landmark"
            selected_places.append(
                {
                    "place_id": pid,
                    "name": name,
                    "types": ["tourist_attraction"],
                    "rating": 4.5,
                }
            )

    itinerary_result: Optional[Dict[str, Any]] = None

    try:
        session = await session_service.create_session(
            app_name="trip_ai_planner",
            user_id=user_id or "anonymous_traveler",
        )
    except Exception as e:
        logger.warning(f"Failed to create session: {e}")

    # Fast robust programmatic schedule builder
    if not itinerary_result or "days" not in itinerary_result:
        loop = asyncio.get_event_loop()
        itinerary_result = await loop.run_in_executor(
            None,
            lambda: build_daily_schedules_programmatic(
                dates=dates,
                selected_places=selected_places,
                start_point=start_point,
                end_point=end_point,
                hotel=hotel,
                travel_mode=travel_mode,
            ),
        )

    itinerary_result["trip_id"] = trip_id
    itinerary_result["travel_mode"] = travel_mode
    itinerary_result["start_point"] = start_point
    itinerary_result["end_point"] = end_point

    return itinerary_result
