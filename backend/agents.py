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

        # Dynamic, human-friendly departure based on transit time to first spot
        transit_to_first = legs[0]["duration_minutes"] if legs else 25
        first_leg_km = legs[0]["distance_km"] if legs else 12.0

        if day_i == 0:
            if transit_to_first >= 180:
                current_hour = 6
                current_minute = 0
            elif transit_to_first >= 90:
                current_hour = 7
                current_minute = 0
            elif transit_to_first >= 45:
                current_hour = 8
                current_minute = 0
            else:
                current_hour = 8
                current_minute = 30
        else:
            current_hour = 8
            current_minute = 30

        scheduled_stops = []

        # 1. Start point
        ampm = "AM" if current_hour < 12 else "PM"
        display_h = current_hour if 1 <= current_hour <= 12 else (current_hour - 12 if current_hour > 12 else 12)
        h_dur = transit_to_first // 60
        m_dur = transit_to_first % 60
        dur_label = f"{h_dur}h {m_dur}m" if h_dur > 0 else f"{m_dur}m"

        start_notes = (
            f"Depart by {travel_mode} • {dur_label} travel ({first_leg_km} km)"
            if day_i == 0
            else "Depart from hotel after breakfast"
        )

        scheduled_stops.append(
            {
                "time": f"{display_h:02d}:{current_minute:02d} {ampm}",
                "place_id": "start_point",
                "name": f"Start: {current_start_point or 'Starting Point'}",
                "activity_type": "start",
                "duration_minutes": 15,
                "travel_to_next_minutes": transit_to_first,
                "notes": start_notes,
            }
        )

        # 2. Highway break if long travel (> 2.5 hours)
        has_highway_break = False
        if day_i == 0 and transit_to_first >= 150:
            has_highway_break = True
            half_transit = transit_to_first // 2
            tot_bk = current_minute + 15 + half_transit
            bk_h = current_hour + tot_bk // 60
            bk_m = tot_bk % 60
            bk_ampm = "AM" if bk_h < 12 else "PM"
            bk_dh = bk_h if 1 <= bk_h <= 12 else (bk_h - 12 if bk_h > 12 else 12)
            scheduled_stops.append(
                {
                    "time": f"{bk_dh:02d}:{bk_m:02d} {bk_ampm}",
                    "place_id": "highway_break",
                    "name": "Highway Refreshment & Tea Break",
                    "activity_type": "break",
                    "duration_minutes": 25,
                    "travel_to_next_minutes": transit_to_first - half_transit,
                    "notes": "Restroom, tea/coffee & light breakfast on highway route",
                }
            )

        # Advance time to arrival at first destination
        tot_initial = current_minute + 15 + transit_to_first + (25 if has_highway_break else 0)
        current_hour += tot_initial // 60
        current_minute = tot_initial % 60

        lunch_inserted = False

        for p_idx, p in enumerate(day_places):
            details = get_place_details(p["place_id"])
            if not details.get("has_opening_hours"):
                warnings.append(f"Opening hours for '{p['name']}' are unverified.")

            # Check for lunch between 12:45 PM and 2:00 PM
            time_in_mins = current_hour * 60 + current_minute
            if not lunch_inserted and 765 <= time_in_mins <= 870:
                l_ampm = "AM" if current_hour < 12 else "PM"
                l_dh = current_hour if 1 <= current_hour <= 12 else (current_hour - 12 if current_hour > 12 else 12)
                scheduled_stops.append(
                    {
                        "time": f"{l_dh:02d}:{current_minute:02d} {l_ampm}",
                        "place_id": "lunch_stop",
                        "name": "Lunch & Regional Cuisine Refreshment",
                        "activity_type": "meal",
                        "duration_minutes": 60,
                        "travel_to_next_minutes": 10,
                        "notes": "Enjoy regional authentic dining and rest",
                    }
                )
                tot_lunch = current_minute + 60 + 10
                current_hour += tot_lunch // 60
                current_minute = tot_lunch % 60
                lunch_inserted = True

            visit_duration = 90
            p_name_lower = p["name"].lower()
            if any(k in p_name_lower for k in ("sunset", "viewpoint", "lookout")):
                visit_duration = 60
            elif any(k in p_name_lower for k in ("temple", "gopura", "tower")):
                visit_duration = 75

            ampm = "AM" if current_hour < 12 else "PM"
            display_h = current_hour if 1 <= current_hour <= 12 else (current_hour - 12 if current_hour > 12 else 12)

            leg_duration = (
                legs[p_idx + 1]["duration_minutes"] if (p_idx + 1) < len(legs) else 15
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

            if not lunch_inserted and current_hour >= 14:
                l_ampm = "PM"
                l_dh = current_hour - 12 if current_hour > 12 else 12
                scheduled_stops.append(
                    {
                        "time": f"{l_dh:02d}:{current_minute:02d} {l_ampm}",
                        "place_id": "lunch_stop",
                        "name": "Late Lunch & Refreshment Break",
                        "activity_type": "meal",
                        "duration_minutes": 45,
                        "travel_to_next_minutes": 10,
                        "notes": "Regional dining and afternoon rest",
                    }
                )
                tot_lunch = current_minute + 45 + 10
                current_hour += tot_lunch // 60
                current_minute = tot_lunch % 60
                lunch_inserted = True

        # Dinner Break (19:30 - 20:30)
        if 19 <= current_hour < 21:
            d_ampm = "PM"
            d_dh = current_hour - 12 if current_hour > 12 else 12
            scheduled_stops.append(
                {
                    "time": f"{d_dh:02d}:{current_minute:02d} {d_ampm}",
                    "place_id": "dinner_stop",
                    "name": "Dinner & Evening Relaxation",
                    "activity_type": "meal",
                    "duration_minutes": 50,
                    "travel_to_next_minutes": 15,
                    "notes": "Traditional dinner & relaxing evening downtime",
                }
            )
            tot_dinner = current_minute + 50 + 15
            current_hour += tot_dinner // 60
            current_minute = tot_dinner % 60

        # Human-friendly night hotel arrival (09:15 PM - 09:30 PM)
        if current_hour < 21 or (current_hour == 21 and current_minute < 15):
            final_time_str = "09:15 PM"
        else:
            final_h = min(22, current_hour)
            final_dh = final_h - 12 if final_h > 12 else final_h
            final_time_str = f"{final_dh:02d}:{current_minute:02d} PM"

        scheduled_stops.append(
            {
                "time": final_time_str,
                "place_id": "final_stop",
                "name": f"End: {hotel_name}",
                "activity_type": "end",
                "duration_minutes": 0,
                "travel_to_next_minutes": 0,
                "notes": (
                    "Hotel check-in & rest (sleep schedule: 10:00 PM – 07:30 AM • 9 hrs rest)"
                    if num_days > 1
                    else "Arrival at resting location"
                ),
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

