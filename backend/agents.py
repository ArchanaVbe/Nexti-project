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
    """Builds a structured daily schedule strictly using the voted places,
    distributing them evenly across the trip days with seamless, zero-gap time management.
    """
    if not dates:
        dates = ["Day 1"]

    num_days = len(dates)
    days_data = []
    unfitted_stops = []
    warnings = []

    # 1. Clean and deduplicate selected places
    unique_places = []
    seen = set()
    for p in selected_places:
        name = p.get("name", "").strip()
        lower = name.lower()
        if not name or lower in seen:
            continue
        if (
            lower.startswith("day ")
            or lower.startswith("stop_")
            or lower.startswith("local_")
            or lower.startswith("start:")
            or lower == "starting point"
            or lower.startswith("location (")
            or lower.startswith("present location")
            or "taralabalu" in lower
            or "layout rd" in lower
            or lower.endswith(" hotel")
            or lower.endsWith(" resort") if hasattr(lower, "endsWith") else lower.endswith(" resort")
        ):
            continue
        seen.add(lower)
        unique_places.append(p)

    # 2. Distribute places evenly across days without repeating any attraction
    stops_per_day: List[List[Dict[str, Any]]] = [[] for _ in range(num_days)]
    total_places = len(unique_places)
    cursor = 0
    for d in range(num_days):
        remaining_places = total_places - cursor
        remaining_days = num_days - d
        if remaining_days <= 0 or remaining_places <= 0:
            break
        count_for_today = -(-remaining_places // remaining_days)
        for _ in range(count_for_today):
            if cursor < total_places:
                stops_per_day[d].append(unique_places[cursor])
                cursor += 1

    clean_hotel = hotel or "Hotel Stay"
    if any(w in clean_hotel.lower() for w in ["taralabalu", "layout rd", "location (", "starting point", "start:"]):
        clean_hotel = "Hotel Stay"

    for day_i, day_date in enumerate(dates):
        day_places = stops_per_day[day_i]
        k = len(day_places)

        scheduled_stops = []

        if k == 0:
            scheduled_stops.extend([
                {
                    "time": "10:00 AM",
                    "place_id": "leisure_explore",
                    "name": "Leisure & Local Exploration 🌿",
                    "activity_type": "leisure",
                    "duration_minutes": 180,
                    "travel_to_next_minutes": 15,
                    "opening_hours": ["09:00 AM – 06:00 PM"],
                    "notes": "Relaxed personal leisure and scenic exploration",
                },
                {
                    "time": "01:15 PM",
                    "place_id": "lunch_stop",
                    "name": "Authentic Regional Lunch Feast 🍛",
                    "activity_type": "meal",
                    "duration_minutes": 75,
                    "travel_to_next_minutes": 15,
                    "notes": "Traditional multi-course feast featuring local delicacies and refreshments",
                },
                {
                    "time": "05:30 PM",
                    "place_id": "tea_break",
                    "name": "Evening High Tea & Refreshments 🫖",
                    "activity_type": "break",
                    "duration_minutes": 45,
                    "travel_to_next_minutes": 15,
                    "notes": "Relax with fresh filter coffee/tea and regional savories",
                },
                {
                    "time": "08:00 PM",
                    "place_id": "dinner_stop",
                    "name": "Dinner & Group Downtime 🌙",
                    "activity_type": "meal",
                    "duration_minutes": 75,
                    "travel_to_next_minutes": 15,
                    "notes": "Relaxing dinner with friends recapping highlights and planning ahead",
                },
            ])

        elif k == 1:
            p1 = day_places[0]
            details = get_place_details(p1.get("place_id", ""))
            scheduled_stops.extend([
                {
                    "time": "09:30 AM",
                    "place_id": p1.get("place_id", "place_1"),
                    "name": p1.get("name", "Landmark"),
                    "activity_type": "visit",
                    "duration_minutes": 210,
                    "travel_to_next_minutes": 15,
                    "opening_hours": details.get("weekday_text", ["Open today: 09:00 AM – 06:00 PM"]),
                    "notes": f"In-depth exploration of {p1.get('name')}: grand architecture, galleries & photography • Rating {p1.get('rating', 4.5)} ★",
                },
                {
                    "time": "01:15 PM",
                    "place_id": "lunch_stop",
                    "name": "Authentic Regional Lunch Feast 🍛",
                    "activity_type": "meal",
                    "duration_minutes": 75,
                    "travel_to_next_minutes": 15,
                    "notes": f"Hearty multi-course regional thali served with ghee and local delicacies near {p1.get('name')}",
                },
                {
                    "time": "05:15 PM",
                    "place_id": "tea_break",
                    "name": "Evening High Tea & Snacks 🫖",
                    "activity_type": "break",
                    "duration_minutes": 45,
                    "travel_to_next_minutes": 15,
                    "notes": f"Unwind with regional sweets, warm savories, and fresh filter coffee near {p1.get('name')}",
                },
                {
                    "time": "07:45 PM",
                    "place_id": "dinner_stop",
                    "name": "Dinner & Group Celebration 🌙",
                    "activity_type": "meal",
                    "duration_minutes": 75,
                    "travel_to_next_minutes": 15,
                    "notes": f"Relaxing evening dinner with friends, recap highlights of visiting {p1.get('name')}",
                },
            ])

        elif k == 2:
            p1 = day_places[0]
            p2 = day_places[1]
            det1 = get_place_details(p1.get("place_id", ""))
            det2 = get_place_details(p2.get("place_id", ""))
            scheduled_stops.extend([
                {
                    "time": "09:30 AM",
                    "place_id": p1.get("place_id", "place_1"),
                    "name": p1.get("name", "Morning Landmark"),
                    "activity_type": "visit",
                    "duration_minutes": 195,
                    "travel_to_next_minutes": 15,
                    "opening_hours": det1.get("weekday_text", ["Open today: 09:00 AM – 06:00 PM"]),
                    "notes": f"Explore premier landmark {p1.get('name')}: grand architecture, galleries & photography • Rating {p1.get('rating', 4.5)} ★",
                },
                {
                    "time": "01:00 PM",
                    "place_id": "lunch_stop",
                    "name": "Authentic Regional Lunch Feast 🍛",
                    "activity_type": "meal",
                    "duration_minutes": 75,
                    "travel_to_next_minutes": 15,
                    "notes": f"Delicious regional multi-course meal and authentic cuisine near {p1.get('name')}",
                },
                {
                    "time": "02:30 PM",
                    "place_id": p2.get("place_id", "place_2"),
                    "name": p2.get("name", "Afternoon Attraction"),
                    "activity_type": "visit",
                    "duration_minutes": 180,
                    "travel_to_next_minutes": 15,
                    "opening_hours": det2.get("weekday_text", ["Open today: 09:00 AM – 06:00 PM"]),
                    "notes": f"Immersive afternoon visit to {p2.get('name')}: cultural heritage & scenic panoramas • Rating {p2.get('rating', 4.5)} ★",
                },
                {
                    "time": "05:45 PM",
                    "place_id": "tea_break",
                    "name": "Evening High Tea & Treats 🫖",
                    "activity_type": "break",
                    "duration_minutes": 45,
                    "travel_to_next_minutes": 15,
                    "notes": f"Relax with hot filter coffee/tea, freshly made warm savories and sweets near {p2.get('name')}",
                },
                {
                    "time": "07:45 PM",
                    "place_id": "dinner_stop",
                    "name": "Dinner & Group Downtime 🌙",
                    "activity_type": "meal",
                    "duration_minutes": 75,
                    "travel_to_next_minutes": 15,
                    "notes": f"Relaxing dinner with friends recapping {p1.get('name')} and {p2.get('name')}",
                },
            ])

        elif k == 3:
            p1 = day_places[0]
            p2 = day_places[1]
            p3 = day_places[2]
            det1 = get_place_details(p1.get("place_id", ""))
            det2 = get_place_details(p2.get("place_id", ""))
            det3 = get_place_details(p3.get("place_id", ""))
            scheduled_stops.extend([
                {
                    "time": "09:30 AM",
                    "place_id": p1.get("place_id", "place_1"),
                    "name": p1.get("name", "Landmark 1"),
                    "activity_type": "visit",
                    "duration_minutes": 120,
                    "travel_to_next_minutes": 15,
                    "opening_hours": det1.get("weekday_text", ["Open today"]),
                    "notes": f"Explore iconic landmark {p1.get('name')} • Rating {p1.get('rating', 4.5)} ★",
                },
                {
                    "time": "11:45 AM",
                    "place_id": p2.get("place_id", "place_2"),
                    "name": p2.get("name", "Landmark 2"),
                    "activity_type": "visit",
                    "duration_minutes": 75,
                    "travel_to_next_minutes": 15,
                    "opening_hours": det2.get("weekday_text", ["Open today"]),
                    "notes": f"Midday visit to {p2.get('name')}: scenic walks & cultural exhibits • Rating {p2.get('rating', 4.5)} ★",
                },
                {
                    "time": "01:15 PM",
                    "place_id": "lunch_stop",
                    "name": "Authentic Regional Lunch Feast 🍛",
                    "activity_type": "meal",
                    "duration_minutes": 60,
                    "travel_to_next_minutes": 15,
                    "notes": "Hearty traditional lunch thali with regional specialties",
                },
                {
                    "time": "02:30 PM",
                    "place_id": p3.get("place_id", "place_3"),
                    "name": p3.get("name", "Landmark 3"),
                    "activity_type": "visit",
                    "duration_minutes": 165,
                    "travel_to_next_minutes": 15,
                    "opening_hours": det3.get("weekday_text", ["Open today"]),
                    "notes": f"Deep dive into {p3.get('name')}: scenic nature & viewpoints • Rating {p3.get('rating', 4.5)} ★",
                },
                {
                    "time": "05:30 PM",
                    "place_id": "tea_break",
                    "name": "Evening High Tea & Snacks 🫖",
                    "activity_type": "break",
                    "duration_minutes": 45,
                    "travel_to_next_minutes": 15,
                    "notes": f"Unwind with regional warm snacks and fresh filter coffee near {p3.get('name')}",
                },
                {
                    "time": "07:45 PM",
                    "place_id": "dinner_stop",
                    "name": "Dinner & Group Downtime 🌙",
                    "activity_type": "meal",
                    "duration_minutes": 75,
                    "travel_to_next_minutes": 15,
                    "notes": f"Traditional dinner with the group, recap of {p1.get('name')}, {p2.get('name')}, and {p3.get('name')}",
                },
            ])

        else:
            # k >= 4
            p1, p2, p3, p4 = day_places[0], day_places[1], day_places[2], day_places[3]
            scheduled_stops.extend([
                {
                    "time": "09:30 AM",
                    "place_id": p1.get("place_id", "place_1"),
                    "name": p1.get("name"),
                    "activity_type": "visit",
                    "duration_minutes": 105,
                    "travel_to_next_minutes": 15,
                    "opening_hours": ["09:00 AM – 06:00 PM"],
                    "notes": f"Morning visit to {p1.get('name')}",
                },
                {
                    "time": "11:30 AM",
                    "place_id": p2.get("place_id", "place_2"),
                    "name": p2.get("name"),
                    "activity_type": "visit",
                    "duration_minutes": 90,
                    "travel_to_next_minutes": 15,
                    "opening_hours": ["09:00 AM – 06:00 PM"],
                    "notes": f"Midday exploration of {p2.get('name')}",
                },
                {
                    "time": "01:15 PM",
                    "place_id": "lunch_stop",
                    "name": "Authentic Regional Lunch Feast 🍛",
                    "activity_type": "meal",
                    "duration_minutes": 60,
                    "travel_to_next_minutes": 15,
                    "notes": "Traditional multi-course feast featuring local delicacies",
                },
                {
                    "time": "02:30 PM",
                    "place_id": p3.get("place_id", "place_3"),
                    "name": p3.get("name"),
                    "activity_type": "visit",
                    "duration_minutes": 120,
                    "travel_to_next_minutes": 15,
                    "opening_hours": ["09:00 AM – 06:00 PM"],
                    "notes": f"Afternoon attraction visit to {p3.get('name')}",
                },
                {
                    "time": "04:45 PM",
                    "place_id": "tea_break",
                    "name": "Evening High Tea & Snacks 🫖",
                    "activity_type": "break",
                    "duration_minutes": 30,
                    "travel_to_next_minutes": 15,
                    "notes": "Hot tea/coffee break with warm local savories",
                },
                {
                    "time": "05:30 PM",
                    "place_id": p4.get("place_id", "place_4"),
                    "name": p4.get("name"),
                    "activity_type": "visit",
                    "duration_minutes": 105,
                    "travel_to_next_minutes": 15,
                    "opening_hours": ["09:00 AM – 06:00 PM"],
                    "notes": f"Sunset attraction visit to {p4.get('name')}",
                },
            ])
            for extra_i in range(4, len(day_places)):
                ep = day_places[extra_i]
                scheduled_stops.append({
                    "time": "07:20 PM",
                    "place_id": ep.get("place_id", f"place_{extra_i+1}"),
                    "name": ep.get("name"),
                    "activity_type": "visit",
                    "duration_minutes": 40,
                    "travel_to_next_minutes": 15,
                    "notes": f"Evening exploration of {ep.get('name')}",
                })
            scheduled_stops.append({
                "time": "08:15 PM",
                "place_id": "dinner_stop",
                "name": "Dinner & Group Wind Down 🌙",
                "activity_type": "meal",
                "duration_minutes": 60,
                "travel_to_next_minutes": 15,
                "notes": "Relaxing dinner with friends",
            })

        # End of day: Hotel arrival & rest
        scheduled_stops.append(
            {
                "time": "09:30 PM",
                "place_id": "final_stop",
                "name": f"End: {clean_hotel}",
                "activity_type": "end",
                "duration_minutes": 0,
                "travel_to_next_minutes": 0,
                "notes": "Hotel check-in & rest (sleep schedule: 10:00 PM – 07:30 AM • 9 hrs rest)",
            }
        )

        day_summary = (
            f"Day {day_i + 1}: " + " & ".join([p["name"] for p in day_places])
            if day_places
            else f"Day {day_i + 1}: Cultural Leisure & City Exploration"
        )

        days_data.append(
            {
                "day_number": day_i + 1,
                "date": day_date,
                "summary": day_summary,
                "stops": scheduled_stops,
                "daily_total_travel_minutes": 60,
                "daily_total_distance_km": 25.0,
            }
        )

    return {
        "days": days_data,
        "unfitted_stops": unfitted_stops,
        "warnings": list(set(warnings)),
    }


# ----------------------------------------------------------------------
# 4. ADK Replanning Agent & Smart Detour Helper
# ----------------------------------------------------------------------

REPLAN_INSTRUCTION = """
You are an expert real-time travel replanning agent.
The user is currently visiting or has reached a specific destination spot during their trip.
They want to visit another nearby attraction ONLY near their current location without disturbing the next scheduled place in their itinerary.
Your job is to analyze candidate nearby attractions, calculate travel time to the candidate, recommended visit duration, and travel time from candidate to the next planned stop.
Verify that the detour fits comfortably within the time window before the next scheduled stop, and flag any time clashes.
"""

replan_agent = Agent(
    name="replan_agent",
    model=GEMINI_MODEL,
    instruction=REPLAN_INSTRUCTION,
    tools=[get_place_details, compute_route],
)


def _parse_departure_time_to_minutes(time_str: str) -> Optional[int]:
    try:
        clean = time_str.strip().upper()
        if "-" in clean or "–" in clean:
            parts = re.split(r"[-–]", clean)
            if len(parts) >= 2:
                v = _parse_single_time_to_minutes(parts[1].strip())
                if v is not None:
                    return v
        return _parse_single_time_to_minutes(clean)
    except Exception:
        return None


def _parse_arrival_time_to_minutes(time_str: str) -> Optional[int]:
    try:
        clean = time_str.strip().upper()
        if "-" in clean or "–" in clean:
            parts = re.split(r"[-–]", clean)
            if len(parts) >= 1:
                v = _parse_single_time_to_minutes(parts[0].strip())
                if v is not None:
                    return v
        return _parse_single_time_to_minutes(clean)
    except Exception:
        return None


def _parse_single_time_to_minutes(time_str: str) -> Optional[int]:
    try:
        clean = time_str.strip().upper()
        m = re.search(r"(\d{1,2}):(\d{2})\s*(AM|PM)?", clean)
        if not m:
            return None
        h = int(m.group(1))
        mins = int(m.group(2))
        ampm = m.group(3)
        if ampm == "PM" and h < 12:
            h += 12
        elif ampm == "AM" and h == 12:
            h = 0
        return h * 60 + mins
    except Exception:
        return None


def _parse_time_to_minutes(time_str: str) -> Optional[int]:
    return _parse_departure_time_to_minutes(time_str)


def _format_minutes_to_time(minutes_from_midnight: int) -> str:
    """Formats minutes from midnight to 'HH:MM AM/PM'."""
    m_wrap = minutes_from_midnight % (24 * 60)
    h = m_wrap // 60
    mins = m_wrap % 60
    ampm = "AM" if h < 12 else "PM"
    dh = h if 1 <= h <= 12 else (h - 12 if h > 12 else 12)
    return f"{dh:02d}:{mins:02d} {ampm}"


def suggest_replan_candidates(
    current_place: str,
    current_lat: float,
    current_lng: float,
    next_place: Optional[str],
    next_lat: Optional[float],
    next_lng: Optional[float],
    current_time_str: str,
    next_time_str: str,
    available_minutes: int,
    candidate_places: List[Dict[str, Any]],
    existing_places: List[str],
    max_radius_km: float = 15.0,
) -> List[Dict[str, Any]]:
    """Analyzes and scores nearby detour places near `current_place`.
    Strictly considers time management and potential clashes with `next_place`.
    """
    from tools import haversine_distance_km

    # Normalize existing places
    norm_existing = {p.strip().lower() for p in existing_places if p}
    norm_existing.add(current_place.strip().lower())
    if next_place:
        norm_existing.add(next_place.strip().lower())

    # Calculate available window from time strings if valid
    curr_mins = _parse_departure_time_to_minutes(current_time_str)
    next_mins = _parse_arrival_time_to_minutes(next_time_str)
    effective_window = available_minutes
    if curr_mins is not None and next_mins is not None and next_mins > curr_mins:
        effective_window = next_mins - curr_mins
    elif curr_mins is not None and next_mins is not None and next_mins <= curr_mins:
        effective_window = 35
    if effective_window <= 0:
        effective_window = 90

    base_time_mins = curr_mins if curr_mins is not None else 660  # default 11:00 AM

    scored_candidates = []

    for cand in candidate_places:
        c_name = cand.get("name", "Nearby Place")
        c_name_norm = c_name.strip().lower()
        clean_c = "".join(ch for ch in c_name_norm if ch.isalnum())
        is_dup = False
        for ex in norm_existing:
            clean_ex = "".join(ch for ch in ex if ch.isalnum())
            if not clean_c or not clean_ex:
                continue
            if clean_c == clean_ex:
                is_dup = True
                break
            if len(clean_c) >= 8 and len(clean_ex) >= 8 and (clean_c.startswith(clean_ex) or clean_ex.startswith(clean_c)):
                is_dup = True
                break
        if is_dup:
            continue

        c_lat = cand.get("lat")
        c_lng = cand.get("lng")
        if c_lat is None or c_lng is None:
            continue

        # Proximity filter: MUST be near current place (within max_radius_km)
        dist_from_curr = haversine_distance_km(current_lat, current_lng, c_lat, c_lng)
        if dist_from_curr > max_radius_km:
            continue

        # Travel time from current place to candidate (estimated ~2.2 min/km + 4 min base)
        travel_from_curr = max(5, int(dist_from_curr * 2.2 + 4))

        # Recommended visit duration based on place type / name
        types = [t.lower() for t in cand.get("types", [])]
        name_l = c_name.lower()
        if any(w in name_l for w in ["view", "lookout", "point", "sunset", "statue"]):
            visit_dur = 35
            cat = "Sightseeing"
        elif any(w in name_l for w in ["temple", "church", "fort", "palace", "museum"]):
            visit_dur = 45
            cat = "Culture"
        elif any(w in name_l for w in ["falls", "lake", "park", "garden", "sanctuary"]):
            visit_dur = 50
            cat = "Nature"
        elif any(w in name_l for w in ["cafe", "restaurant", "thali", "dosa", "food", "taste"]):
            visit_dur = 40
            cat = "Food"
        elif any(w in name_l for w in ["trek", "rafting", "safari", "climb", "adventure"]):
            visit_dur = 60
            cat = "Adventure"
        else:
            visit_dur = 40
            cat = "Sightseeing"

        # Travel time from candidate to next planned place
        if next_lat is not None and next_lng is not None and (next_lat != 0.0 or next_lng != 0.0):
            dist_to_next = haversine_distance_km(c_lat, c_lng, next_lat, next_lng)
            travel_to_next = max(5, int(dist_to_next * 2.2 + 4))
        else:
            travel_to_next = 15

        # Suggested time slot
        slot_start_mins = base_time_mins + travel_from_curr
        slot_end_mins = slot_start_mins + visit_dur
        suggested_slot = f"{_format_minutes_to_time(slot_start_mins)} – {_format_minutes_to_time(slot_end_mins)}"
        next_arrival_mins = slot_end_mins + travel_to_next
        next_arrival_str = _format_minutes_to_time(next_arrival_mins)

        next_label = next_place if next_place else "Next Scheduled Stop"

        if next_mins is not None:
            buffer_min = next_mins - next_arrival_mins
            if buffer_min >= 5:
                time_status = "fits"
                time_status_badge = f"No Clash ({buffer_min}m buffer)"
                summary = f"Reach {next_label} by {next_arrival_str} ({buffer_min}m buffer before schedule)."
            elif buffer_min >= -20:
                time_status = "tight"
                time_status_badge = f"Minor Shift ({abs(buffer_min)}m)"
                summary = f"Reach {next_label} by {next_arrival_str} ({abs(buffer_min)}m schedule adjustment)."
            else:
                time_status = "clash"
                time_status_badge = f"Shifts Stop (+{abs(buffer_min)}m)"
                summary = f"Caution: reach {next_label} by {next_arrival_str} (+{abs(buffer_min)}m adjustment)."
        else:
            time_status = "fits"
            time_status_badge = "No Clash"
            summary = f"Reach {next_label} by {next_arrival_str} on schedule."

        scored_candidates.append(
            {
                "name": c_name,
                "place_id": cand.get("place_id", f"replan_{len(scored_candidates)}"),
                "lat": c_lat,
                "lng": c_lng,
                "distance_km": round(dist_from_curr, 1),
                "travel_from_current_min": travel_from_curr,
                "visit_duration_min": visit_dur,
                "travel_to_next_min": travel_to_next,
                "total_time_min": total_time_needed,
                "time_status": time_status,
                "time_status_badge": time_status_badge,
                "suggested_slot": suggested_slot,
                "category": cat,
                "rating": cand.get("rating", 4.5),
                "summary": summary,
                "address": cand.get("address", f"Near {current_place}"),
                "_buffer_min": buffer_min,
            }
        )

    # Sort: "fits" first, then "tight", then "clash"
    # Within each group, closest distance first, then higher rating
    status_priority = {"fits": 0, "tight": 1, "clash": 2}
    scored_candidates.sort(
        key=lambda item: (
            status_priority.get(item["time_status"], 9),
            item["distance_km"],
            -item["rating"],
        )
    )

    return scored_candidates

