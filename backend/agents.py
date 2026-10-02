"""agents.py: ADK Agents for Trip AI

Defines:
1. categorizer_agent: Gemini agent that classifies place IDs into Adventure, Food, Nature, Culture, Sightseeing.
2. categorize_places: AgentTool wrapping categorizer_agent.
3. planner_agent: Multi-tool Gemini agent that plans daily itineraries, sequences stops,
   incorporates opening hours and routing, and adds meals/breaks.
"""

import json
import os
from pathlib import Path
from typing import Any, Dict, List, Optional
from dotenv import load_dotenv

env_path = Path(__file__).resolve().parent / ".env"
load_dotenv(dotenv_path=env_path)

from google.adk.agents import Agent
from google.adk.tools import AgentTool
from tools import compute_route, get_place_details

GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-3.8-flash")

CATEGORIZER_INSTRUCTION = """
You are a travel categorization specialist.
Given a list of place objects with id, name, and types, classify each place into EXACTLY ONE of these 5 categories:
1. Adventure: (e.g., trekking, hiking, river rafting, climbing, safari, water sports, outdoor thrills)
2. Food: (e.g., restaurants, traditional eateries, cafes, markets, street food, dining, culinary)
3. Nature: (e.g., waterfalls, lakes, wildlife sanctuaries, national parks, botanical gardens, rivers, hills)
4. Culture: (e.g., temples, historic forts, monuments, palaces, churches, heritage villages, museums)
5. Sightseeing: (e.g., viewpoints, city squares, dams, scenic lookouts, landmarks, clock towers)

Always return a JSON object with this exact structure:
{
  "Adventure": ["place_id_1", ...],
  "Food": ["place_id_2", ...],
  "Nature": ["place_id_3", ...],
  "Culture": ["place_id_4", ...],
  "Sightseeing": ["place_id_5", ...]
}
Include every input place ID exactly once. Do not add explanations outside the JSON.
"""

# 1. Specialized Categorization Agent
categorizer_agent = Agent(
    name="categorizer_agent",
    model=GEMINI_MODEL,
    instruction=CATEGORIZER_INSTRUCTION,
)

# 2. Wrapped as an AgentTool
categorize_places = AgentTool(agent=categorizer_agent)

PLANNER_INSTRUCTION = """
You are an expert itinerary planning agent.
Your task is to build a realistic, balanced, and optimized daily trip itinerary for a user.

You have access to tools:
- get_place_details(place_id): retrieves opening hours and metadata.
- compute_route(origin, destination, waypoints, travel_mode): calculates travel time and optimal order.

Planning Rules:
1. Spread the user's selected stops evenly across the given trip dates.
2. Group nearby places together to minimize back-and-forth travel.
3. Check opening hours for each stop. If closed or hours unknown, add an appropriate note or warning.
4. Each day should start at the specified starting point (e.g. hotel) around 09:00 AM.
5. Allocate realistic visit durations (e.g., 60-120 minutes per tourist attraction).
6. Always schedule a lunch break (e.g. 1:00 PM – 2:00 PM) and appropriate travel intervals.
7. End each day at the designated final stop (or hotel) by 07:00 PM - 08:30 PM.
8. If a selected stop cannot fit into the available days, list it in unfitted_stops.

Return your final output in valid JSON format:
{
  "days": [
    {
      "day_number": 1,
      "date": "YYYY-MM-DD",
      "summary": "Theme of the day",
      "stops": [
        {
          "time": "09:00 AM - 09:30 AM",
          "place_id": "hotel_or_start",
          "name": "Start: Hotel",
          "activity_type": "start",
          "duration_minutes": 30,
          "travel_to_next_minutes": 20,
          "notes": "Departure"
        },
        {
          "time": "09:50 AM - 11:30 AM",
          "place_id": "place_id",
          "name": "Attraction Name",
          "activity_type": "visit",
          "duration_minutes": 100,
          "travel_to_next_minutes": 15,
          "notes": "Enjoy scenic views"
        },
        {
          "time": "01:00 PM - 02:00 PM",
          "place_id": "lunch",
          "name": "Lunch Break",
          "activity_type": "meal",
          "duration_minutes": 60,
          "travel_to_next_minutes": 15,
          "notes": "Local cuisine"
        }
      ],
      "daily_total_travel_minutes": 45,
      "daily_total_distance_km": 18.5
    }
  ],
  "unfitted_stops": [],
  "warnings": []
}
"""

# 3. Multi-tool Planner Agent
planner_agent = Agent(
    name="planner_agent",
    model=GEMINI_MODEL,
    instruction=PLANNER_INSTRUCTION,
    tools=[get_place_details, compute_route],
)


# ----------------------------------------------------------------------
# Robust Helpers for Categorization & Planning (Used by Runner / Service)
# ----------------------------------------------------------------------

def deterministic_categorize_places(places: List[Dict[str, Any]]) -> Dict[str, List[str]]:
    """Fast deterministic categorizer ensuring valid 5-category grouping
    even during Gemini API network outages or rate limits.
    """
    categories: Dict[str, List[str]] = {
        "Adventure": [],
        "Food": [],
        "Nature": [],
        "Culture": [],
        "Sightseeing": [],
    }

    for p in places:
        pid = p["place_id"]
        name_lower = p["name"].lower()
        types = [t.lower() for t in p.get("types", [])]

        if any(w in name_lower for w in ["rafting", "trek", "climb", "safari", "sports", "adventure", "camp", "peak", "jumping"]):
            categories["Adventure"].append(pid)
        elif any(w in name_lower for w in ["restaurant", "thali", "dosa", "sweets", "bakery", "food", "cafe", "bazaar", "taste", "eatery"]) or any(t in types for t in ["restaurant", "food", "bakery", "cafe", "meal_takeaway"]):
            categories["Food"].append(pid)
        elif any(w in name_lower for w in ["falls", "lake", "sanctuary", "garden", "forest", "wildlife", "river", "reserve", "nature", "valley", "tree"]) or any(t in types for t in ["park", "natural_feature", "zoo"]):
            categories["Nature"].append(pid)
        elif any(w in name_lower for w in ["temple", "fort", "palace", "museum", "monument", "heritage", "church", "cathedral", "bath", "mahal"]) or any(t in types for t in ["hindu_temple", "museum", "place_of_worship", "church"]):
            categories["Culture"].append(pid)
        else:
            categories["Sightseeing"].append(pid)

    return categories


def build_daily_schedules_programmatic(
    dates: List[str],
    selected_places: List[Dict[str, Any]],
    start_point: str,
    end_point: str,
    travel_mode: str,
    hotel: Optional[str] = None,
) -> Dict[str, Any]:
    """Builds a structured daily schedule allocating stops, opening hours,
    meals, and routing travel times.
    """
    if not dates:
        dates = ["Day 1"]

    num_days = len(dates)
    days_data = []
    unfitted_stops = []
    warnings = []

    # Allocate max 3-4 stops per day for a realistic trip
    max_stops_per_day = 4
    total_capacity = num_days * max_stops_per_day

    fitting_places = selected_places[:total_capacity]
    if len(selected_places) > total_capacity:
        for extra in selected_places[total_capacity:]:
            unfitted_stops.append(
                {
                    "place_id": extra["place_id"],
                    "name": extra["name"],
                    "reason": "Exceeds daily schedule capacity for selected trip duration",
                }
            )
            warnings.append(f"Stop '{extra['name']}' could not fit within {num_days} day(s).")

    # Distribute fitting stops across days
    stops_per_day: List[List[Dict[str, Any]]] = [[] for _ in range(num_days)]
    for idx, place in enumerate(fitting_places):
        day_idx = idx % num_days
        stops_per_day[day_idx].append(place)

    hotel_name = hotel or start_point or "Hotel"

    for day_i, day_date in enumerate(dates):
        day_places = stops_per_day[day_i]
        place_names = [p["name"] for p in day_places]

        # Day starts at start_point for Day 1, hotel for Day 2+
        current_start_point = start_point if day_i == 0 else hotel_name

        # Compute route travel times using compute_route tool
        route_info = compute_route(
            origin=current_start_point or "Starting Point",
            destination=hotel_name,
            waypoints=place_names,
            travel_mode=travel_mode,
        )
        legs = route_info.get("legs", [])

        # Build chronologically sequenced timeline
        current_hour = 6 # Start at 6 AM
        current_minute = 0
        scheduled_stops = []

        # 1. Start point
        scheduled_stops.append(
            {
                "time": f"{current_hour:02d}:{current_minute:02d} AM",
                "place_id": "start_point",
                "name": f"Start: {current_start_point or 'Starting Point'}",
                "activity_type": "start",
                "duration_minutes": 15,
                "travel_to_next_minutes": legs[0]["duration_minutes"] if legs else 15,
                "notes": f"Depart from starting location ({travel_mode})",
            }
        )
        # Advance time by transit
        transit_to_first = legs[0]["duration_minutes"] if legs else 15
        total_min = current_minute + 15 + transit_to_first
        current_hour += total_min // 60
        current_minute = total_min % 60

        lunch_inserted = False

        for p_idx, p in enumerate(day_places):
            details = get_place_details(p["place_id"])
            if not details.get("has_opening_hours"):
                warnings.append(f"Opening hours for '{p['name']}' are unverified.")

            # Check for lunch around 13:00 (1 PM)
            if current_hour >= 13 and not lunch_inserted:
                lunch_time_str = f"01:{current_minute:02d} PM"
                scheduled_stops.append(
                    {
                        "time": lunch_time_str,
                        "place_id": "lunch_stop",
                        "name": "Lunch & Refreshment Break",
                        "activity_type": "meal",
                        "duration_minutes": 60,
                        "travel_to_next_minutes": 10,
                        "notes": "Enjoy regional authentic food and rest",
                    }
                )
                current_hour += 1
                current_minute = (current_minute + 10) % 60
                lunch_inserted = True

            visit_duration = 90
            ampm = "AM" if current_hour < 12 else "PM"
            display_h = current_hour if current_hour <= 12 else current_hour - 12
            if display_h == 0:
                display_h = 12

            leg_duration = (
                legs[p_idx + 1]["duration_minutes"] if (p_idx + 1) < len(legs) else 20
            )

            scheduled_stops.append(
                {
                    "time": f"{display_h:02d}:{current_minute:02d} {ampm}",
                    "place_id": p["place_id"],
                    "name": p["name"],
                    "activity_type": "visit",
                    "duration_minutes": visit_duration,
                    "travel_to_next_minutes": leg_duration,
                    "opening_hours": details.get("weekday_text", ["Open today"]),
                    "notes": f"Rating {p.get('rating', 4.5)} ★ - {p.get('address', '')}",
                }
            )

            tot_min = current_minute + visit_duration + leg_duration
            current_hour += tot_min // 60
            current_minute = tot_min % 60

        # Final return
        # Adjust so that the day ends at exactly 12:00 AM (next day) for 6 hrs sleep
        if num_days > 1:
            final_time_str = "12:00 AM" # Midnight
        else:
            final_ampm = "AM" if current_hour < 12 else "PM"
            final_display_h = current_hour if current_hour <= 12 else current_hour - 12
            if final_display_h == 0:
                final_display_h = 12
            final_time_str = f"{final_display_h:02d}:{current_minute:02d} {final_ampm}"

        scheduled_stops.append(
            {
                "time": final_time_str,
                "place_id": "final_stop",
                "name": f"End: {hotel_name}",
                "activity_type": "end",
                "duration_minutes": 0,
                "travel_to_next_minutes": 0,
                "notes": "Arrival at hotel (6 hrs sleep schedule applied)" if num_days > 1 else "Arrival at resting location",
            }
        )

        days_data.append(
            {
                "day_number": day_i + 1,
                "date": day_date,
                "summary": f"Day {day_i + 1}: Exploring {len(day_places)} attractions",
                "stops": scheduled_stops,
                "daily_total_travel_minutes": route_info.get("total_duration_minutes", 60),
                "daily_total_distance_km": route_info.get("total_distance_km", 25.0),
            }
        )

    return {
        "days": days_data,
        "unfitted_stops": unfitted_stops,
        "warnings": list(set(warnings)),
    }
