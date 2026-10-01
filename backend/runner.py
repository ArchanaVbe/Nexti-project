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
from pathlib import Path
from typing import Any, Dict, List, Optional
from dotenv import load_dotenv

env_path = Path(__file__).resolve().parent / ".env"
load_dotenv(dotenv_path=env_path)

from google.adk.runners import Runner
from google.adk.sessions import InMemorySessionService
from google.genai import types

from agents import (
    categorizer_agent,
    planner_agent,
    deterministic_categorize_places,
    build_daily_schedules_programmatic,
)
from tools import find_places, get_place_details, compute_route

logger = logging.getLogger("trip_ai.runner")

# In-memory session service storing conversational state for active trips
session_service = InMemorySessionService()

# Central ADK Runner wrapping the planner agent
planner_runner = Runner(
    app_name="trip_ai_planner",
    agent=planner_agent,
    session_service=session_service,
)

categorizer_runner = Runner(
    app_name="trip_ai_categorizer",
    agent=categorizer_agent,
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
    # 1. Discover candidate places around center within 70 km radius
    candidates = find_places(city, lat, lng, radius_km)

    # 2. Categorize places using Gemini categorizer agent via ADK
    categories: Dict[str, List[str]] = {
        "Adventure": [],
        "Food": [],
        "Nature": [],
        "Culture": [],
        "Sightseeing": [],
    }

    categorized = False

    try:
        # Create session for this user and trip
        session = await session_service.create_session(
            app_name="trip_ai_categorizer",
            user_id=user_id or "anonymous_traveler",
        )

        places_payload = [
            {"id": p["place_id"], "name": p["name"], "types": p.get("types", [])}
            for p in candidates
        ]

        prompt_text = (
            f"Categorize the following places in and around {city} into Adventure, Food, Nature, Culture, and Sightseeing:\n"
            f"{json.dumps(places_payload, indent=2)}"
        )

        message = types.Content(
            role="user",
            parts=[types.Part.from_text(text=prompt_text)],
        )

        final_response_text = ""
        # Run ADK categorizer runner asynchronously
        async for event in categorizer_runner.run_async(
            session_id=session.id,
            user_id=user_id or "anonymous_traveler",
            new_message=message,
        ):
            if event.content and event.content.parts:
                for part in event.content.parts:
                    if part.text:
                        final_response_text += part.text

        # Extract JSON from model output
        cleaned = final_response_text.strip()
        if "```json" in cleaned:
            cleaned = cleaned.split("```json")[1].split("```")[0].strip()
        elif "```" in cleaned:
            cleaned = cleaned.split("```")[1].split("```")[0].strip()

        parsed = json.loads(cleaned)
        for cat in ["Adventure", "Food", "Nature", "Culture", "Sightseeing"]:
            if cat in parsed and isinstance(parsed[cat], list):
                categories[cat] = [str(x) for x in parsed[cat]]
        categorized = True
    except Exception as e:
        logger.warning(f"ADK categorizer fallback triggered: {e}")

    # Fallback to deterministic classifier if LLM output was malformed or unavailable
    if not categorized or not any(categories.values()):
        categories = deterministic_categorize_places(candidates)

    return {
        "trip_id": trip_id,
        "city": city,
        "center": {"lat": lat, "lng": lng},
        "radius_km": radius_km,
        "total_places": len(candidates),
        "categories": categories,
        "places": candidates,
    }


async def run_plan_async(
    user_id: str,
    trip_id: str,
    dates: List[str],
    selected_ids: List[str],
    all_places_pool: List[Dict[str, Any]],
    start_point: str,
    end_point: str,
    travel_mode: str = "DRIVE",
) -> Dict[str, Any]:
    """Runs ADK planner agent with get_place_details and compute_route tools
    to generate an optimized, scheduled daily itinerary.
    """
    # Filter selected place objects
    places_lookup = {p["place_id"]: p for p in all_places_pool}
    selected_places = []
    for pid in selected_ids:
        if pid in places_lookup:
            selected_places.append(places_lookup[pid])
        else:
            # Fallback for unknown id
            selected_places.append(
                {
                    "place_id": pid,
                    "name": pid.replace("local_", "").replace("_", " ").title(),
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

        plan_request = {
            "trip_id": trip_id,
            "dates": dates,
            "start_point": start_point or "Hotel",
            "end_point": end_point or start_point or "Hotel",
            "travel_mode": travel_mode,
            "selected_places": [
                {"id": p["place_id"], "name": p["name"]}
                for p in selected_places
            ],
        }

        prompt_text = (
            "Create a daily travel itinerary for this trip request. "
            "Use the tools get_place_details and compute_route to optimize travel times and respect opening hours.\n"
            f"{json.dumps(plan_request, indent=2)}"
        )

        message = types.Content(
            role="user",
            parts=[types.Part.from_text(text=prompt_text)],
        )

        final_response_text = ""
        async for event in planner_runner.run_async(
            session_id=session.id,
            user_id=user_id or "anonymous_traveler",
            new_message=message,
        ):
            if event.content and event.content.parts:
                for part in event.content.parts:
                    if part.text:
                        final_response_text += part.text

        cleaned = final_response_text.strip()
        if "```json" in cleaned:
            cleaned = cleaned.split("```json")[1].split("```")[0].strip()
        elif "```" in cleaned:
            cleaned = cleaned.split("```")[1].split("```")[0].strip()

        parsed = json.loads(cleaned)
        if "days" in parsed and isinstance(parsed["days"], list):
            itinerary_result = parsed
    except Exception as e:
        logger.warning(f"ADK planner fallback triggered: {e}")

    # Fallback to robust programmatic schedule builder
    if not itinerary_result or "days" not in itinerary_result:
        itinerary_result = build_daily_schedules_programmatic(
            dates=dates,
            selected_places=selected_places,
            start_point=start_point,
            end_point=end_point,
            travel_mode=travel_mode,
        )

    itinerary_result["trip_id"] = trip_id
    itinerary_result["travel_mode"] = travel_mode
    itinerary_result["start_point"] = start_point
    itinerary_result["end_point"] = end_point

    return itinerary_result
