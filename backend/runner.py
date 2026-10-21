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
    replan_agent,
    deterministic_categorize_places,
    build_daily_schedules_programmatic,
    suggest_replan_candidates,
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
    seen_names = set()
    for idx, pid in enumerate(selected_ids):
        name = selected_names[idx] if (selected_names and idx < len(selected_names)) else None
        place_obj = None
        if pid in places_lookup:
            place_obj = dict(places_lookup[pid])
        elif name and name in places_lookup:
            place_obj = dict(places_lookup[name])

        if not place_obj:
            p_name = name or pid.replace("local_", "").replace("city_", "").replace("_", " ").title()
            if "stop" in p_name.lower() or not p_name.strip():
                p_name = "City Landmark"
            place_obj = {
                "place_id": pid,
                "name": p_name,
                "types": ["tourist_attraction"],
                "rating": 4.5,
            }

        clean_name = place_obj.get("name", "").strip().lower()
        if clean_name and clean_name not in seen_names:
            if any(w in clean_name for w in ["taralabalu", "layout rd", "location (", "starting point", "start:"]):
                continue
            seen_names.add(clean_name)
            selected_places.append(place_obj)

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


async def run_replan_suggest_async(
    user_id: str,
    trip_id: str,
    current_place: str,
    current_lat: float,
    current_lng: float,
    next_place: Optional[str] = None,
    next_lat: Optional[float] = None,
    next_lng: Optional[float] = None,
    current_time_str: str = "11:00 AM",
    next_time_str: str = "02:00 PM",
    available_minutes: int = 120,
    city_or_region: str = "Karnataka",
    existing_places: Optional[List[str]] = None,
    max_radius_km: float = 15.0,
    pool_places: Optional[List[Dict[str, Any]]] = None,
) -> Dict[str, Any]:
    """ADK runner function: finds candidate places near `current_place` within `max_radius_km`,
    checks travel time & duration, and evaluates potential time clashes with `next_place`.
    """
    existing = list(existing_places or [])
    candidates_pool: List[Dict[str, Any]] = []

    # 1. Include already known places from the trip pool
    if pool_places:
        candidates_pool.extend(pool_places)

    # 2. Search places nearby current location within radius_km
    loop = asyncio.get_event_loop()
    try:
        nearby_fetched = await loop.run_in_executor(
            None,
            find_places,
            city_or_region or current_place,
            current_lat,
            current_lng,
            max_radius_km,
        )
        if nearby_fetched:
            candidates_pool.extend(nearby_fetched)
    except Exception as e:
        logger.warning(f"Error fetching nearby places for replan: {e}")

    # Deduplicate candidate places by name/place_id
    deduped: Dict[str, Dict[str, Any]] = {}
    for p in candidates_pool:
        key = p.get("place_id") or p.get("name")
        if key and key not in deduped:
            deduped[key] = p
    candidate_list = list(deduped.values())

    # 3. Analyze time management and clashes
    suggestions = await loop.run_in_executor(
        None,
        lambda: suggest_replan_candidates(
            current_place=current_place,
            current_lat=current_lat,
            current_lng=current_lng,
            next_place=next_place,
            next_lat=next_lat,
            next_lng=next_lng,
            current_time_str=current_time_str,
            next_time_str=next_time_str,
            available_minutes=available_minutes,
            candidate_places=candidate_list,
            existing_places=existing,
            max_radius_km=max_radius_km,
        ),
    )

    return {
        "trip_id": trip_id,
        "current_place": current_place,
        "next_place": next_place or "Next Scheduled Stop",
        "available_minutes": available_minutes,
        "total_suggestions": len(suggestions),
        "suggestions": suggestions,
    }

