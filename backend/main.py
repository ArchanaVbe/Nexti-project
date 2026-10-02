"""main.py: FastAPI Backend for Trip AI

Exposes HTTP endpoints specified in the Trip AI Development Plan:
1. POST /places/autocomplete - Calls autocomplete_city directly; returns city suggestions.
2. POST /places/resolve      - Calls resolve_city directly; returns name, ID, lat and lng.
3. POST /discover            - Runs ADK find_places and categorize_places; returns categories and place cards.
4. POST /plan                - Runs ADK details and route tools; validates the result and returns daily schedules.
"""

import os
import re
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
from firebase_service import sync_discover_places_to_firestore, sync_trip_plan_to_firestore

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
    types: Optional[str] = "cities"
    session_token: Optional[str] = None
    destination: Optional[str] = None

    @property
    def search_query(self) -> str:
        return self.query or self.input or ""


class ReverseGeocodeRequest(BaseModel):
    lat: float
    lng: float


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
    selected_names: Optional[List[str]] = None
    selected_places: Optional[List[Dict[str, Any]]] = None
    start: Optional[str] = "Starting Point"
    hotel: Optional[str] = None
    end: Optional[str] = None
    travel_mode: Optional[str] = "DRIVE"
    session_token: Optional[str] = None


# Cache of discovered places by trip_id so planner can reference rich place data
TRIP_PLACES_CACHE: Dict[str, List[Dict[str, Any]]] = {}

# Comprehensive registry of all Karnataka tourist hubs, districts, hill stations, and heritage centers
KARNATAKA_DESTINATIONS: List[Dict[str, Any]] = [
    # Malnad & Western Ghats Hubs
    {"name": "Shimoga (Shivamogga), Karnataka, India", "id": "city_shimoga", "lat": 13.9299, "lng": 75.5681, "keywords": ["shimoga", "shivamogga", "malnad"]},
    {"name": "Jog Falls, Shimoga, Karnataka, India", "id": "city_jog_falls", "lat": 14.2285, "lng": 74.8123, "keywords": ["jog falls", "falls", "sagar"]},
    {"name": "Agumbe, Shimoga, Karnataka, India", "id": "city_agumbe", "lat": 13.5025, "lng": 75.0935, "keywords": ["agumbe", "sunset", "rainforest"]},
    {"name": "Thirthahalli, Shimoga, Karnataka, India", "id": "city_thirthahalli", "lat": 13.6892, "lng": 75.2415, "keywords": ["thirthahalli", "tunga"]},
    {"name": "Sagar, Shimoga, Karnataka, India", "id": "city_sagar", "lat": 14.1670, "lng": 75.0298, "keywords": ["sagar", "ikkeri", "keladi"]},
    {"name": "Bhadravathi, Shimoga, Karnataka, India", "id": "city_bhadravathi", "lat": 13.8409, "lng": 75.7032, "keywords": ["bhadravathi"]},
    {"name": "Chikmagalur (Chikkamagaluru), Karnataka, India", "id": "city_chikmagalur", "lat": 13.3161, "lng": 75.7720, "keywords": ["chikmagalur", "chikkamagaluru", "coffee"]},
    {"name": "Mullayanagiri, Chikmagalur, Karnataka, India", "id": "city_mullayanagiri", "lat": 13.3917, "lng": 75.7214, "keywords": ["mullayanagiri", "highest peak"]},
    {"name": "Kudremukh, Chikmagalur, Karnataka, India", "id": "city_kudremukh", "lat": 13.2185, "lng": 75.2536, "keywords": ["kudremukh", "national park"]},
    {"name": "Kemmangundi, Chikmagalur, Karnataka, India", "id": "city_kemmangundi", "lat": 13.5484, "lng": 75.7570, "keywords": ["kemmangundi", "hill station"]},
    {"name": "Sringeri, Chikmagalur, Karnataka, India", "id": "city_sringeri", "lat": 13.4184, "lng": 75.2570, "keywords": ["sringeri", "sharada peetham"]},
    {"name": "Horanadu, Chikmagalur, Karnataka, India", "id": "city_horanadu", "lat": 13.2721, "lng": 75.3421, "keywords": ["horanadu", "annapoorneshwari"]},
    {"name": "Coorg (Madikeri), Karnataka, India", "id": "city_coorg", "lat": 12.4244, "lng": 75.7382, "keywords": ["coorg", "kodagu", "madikeri", "coffee"]},
    {"name": "Kushalnagar, Coorg, Karnataka, India", "id": "city_kushalnagar", "lat": 12.4578, "lng": 75.9602, "keywords": ["kushalnagar", "golden temple"]},
    {"name": "Virajpet, Coorg, Karnataka, India", "id": "city_virajpet", "lat": 12.1994, "lng": 75.8042, "keywords": ["virajpet"]},

    # Coastal Karnataka
    {"name": "Gokarna, Uttara Kannada, Karnataka, India", "id": "city_gokarna", "lat": 14.5479, "lng": 74.3188, "keywords": ["gokarna", "om beach", "beaches"]},
    {"name": "Murudeshwar, Uttara Kannada, Karnataka, India", "id": "city_murudeshwar", "lat": 14.0940, "lng": 74.4899, "keywords": ["murudeshwar", "shiva statue"]},
    {"name": "Dandeli, Uttara Kannada, Karnataka, India", "id": "city_dandeli", "lat": 15.2447, "lng": 74.6225, "keywords": ["dandeli", "river rafting", "safari"]},
    {"name": "Karwar, Uttara Kannada, Karnataka, India", "id": "city_karwar", "lat": 14.8136, "lng": 74.1298, "keywords": ["karwar", "sea beach"]},
    {"name": "Honnavar, Uttara Kannada, Karnataka, India", "id": "city_honnavar", "lat": 14.2798, "lng": 74.4439, "keywords": ["honnavar", "backwaters", "mangroves"]},
    {"name": "Sirsi, Uttara Kannada, Karnataka, India", "id": "city_sirsi", "lat": 14.6196, "lng": 74.8354, "keywords": ["sirsi", "marikamba"]},
    {"name": "Kumta, Uttara Kannada, Karnataka, India", "id": "city_kumta", "lat": 14.4253, "lng": 74.4093, "keywords": ["kumta"]},
    {"name": "Yellapur, Uttara Kannada, Karnataka, India", "id": "city_yellapur", "lat": 14.9644, "lng": 74.7121, "keywords": ["yellapur", "waterfalls"]},
    {"name": "Udupi, Karnataka, India", "id": "city_udupi", "lat": 13.3409, "lng": 74.7421, "keywords": ["udupi", "krishna mutt"]},
    {"name": "Malpe, Udupi, Karnataka, India", "id": "city_malpe", "lat": 13.3551, "lng": 74.7042, "keywords": ["malpe", "st marys island", "beach"]},
    {"name": "Manipal, Udupi, Karnataka, India", "id": "city_manipal", "lat": 13.3525, "lng": 74.7868, "keywords": ["manipal"]},
    {"name": "Karkala, Udupi, Karnataka, India", "id": "city_karkala", "lat": 13.2144, "lng": 74.9984, "keywords": ["karkala"]},
    {"name": "Kundapura, Udupi, Karnataka, India", "id": "city_kundapura", "lat": 13.6264, "lng": 74.6917, "keywords": ["kundapura"]},
    {"name": "Kollur, Udupi, Karnataka, India", "id": "city_kollur", "lat": 13.8656, "lng": 74.8139, "keywords": ["kollur", "mookambika"]},
    {"name": "Mangaluru (Mangalore), Karnataka, India", "id": "city_mangaluru", "lat": 12.9141, "lng": 74.8560, "keywords": ["mangaluru", "mangalore", "panambur"]},
    {"name": "Dharmasthala, Dakshina Kannada, Karnataka, India", "id": "city_dharmasthala", "lat": 12.9566, "lng": 75.3789, "keywords": ["dharmasthala"]},
    {"name": "Subramanya (Kukke), Dakshina Kannada, Karnataka, India", "id": "city_subramanya", "lat": 12.6631, "lng": 75.6155, "keywords": ["subramanya", "kukke"]},
    {"name": "Moodabidri, Dakshina Kannada, Karnataka, India", "id": "city_moodabidri", "lat": 13.0700, "lng": 74.9961, "keywords": ["moodabidri"]},
    {"name": "Puttur, Dakshina Kannada, Karnataka, India", "id": "city_puttur", "lat": 12.7667, "lng": 75.2000, "keywords": ["puttur"]},

    # Heritage, Central & South Karnataka
    {"name": "Hampi, Vijayanagara, Karnataka, India", "id": "city_hampi", "lat": 15.3350, "lng": 76.4600, "keywords": ["hampi", "unesco", "heritage"]},
    {"name": "Hosapete (Hospet), Vijayanagara, Karnataka, India", "id": "city_hospet", "lat": 15.2689, "lng": 76.3909, "keywords": ["hosapete", "hospet"]},
    {"name": "Mysuru (Mysore), Karnataka, India", "id": "city_mysuru", "lat": 12.2958, "lng": 76.6394, "keywords": ["mysuru", "mysore", "palace"]},
    {"name": "Srirangapatna, Mandya, Karnataka, India", "id": "city_srirangapatna", "lat": 12.4237, "lng": 76.6946, "keywords": ["srirangapatna"]},
    {"name": "Nanjangud, Mysuru, Karnataka, India", "id": "city_nanjangud", "lat": 12.1189, "lng": 76.6828, "keywords": ["nanjangud"]},
    {"name": "Bengaluru (Bangalore), Karnataka, India", "id": "city_bengaluru", "lat": 12.9716, "lng": 77.5946, "keywords": ["bengaluru", "bangalore"]},
    {"name": "Belur, Hassan, Karnataka, India", "id": "city_belur", "lat": 13.1623, "lng": 75.8625, "keywords": ["belur", "chennakeshava"]},
    {"name": "Halebidu, Hassan, Karnataka, India", "id": "city_halebidu", "lat": 13.2163, "lng": 75.9939, "keywords": ["halebidu", "halebeedu"]},
    {"name": "Shravanabelagola, Hassan, Karnataka, India", "id": "city_shravanabelagola", "lat": 12.8574, "lng": 76.4862, "keywords": ["shravanabelagola", "gommateshwara"]},
    {"name": "Sakleshpur, Hassan, Karnataka, India", "id": "city_sakleshpur", "lat": 12.9734, "lng": 75.7876, "keywords": ["sakleshpur"]},
    {"name": "Hassan, Karnataka, India", "id": "city_hassan", "lat": 13.0033, "lng": 76.1004, "keywords": ["hassan"]},
    {"name": "Bandipur National Park, Chamarajanagar, Karnataka, India", "id": "city_bandipur", "lat": 11.6664, "lng": 76.6291, "keywords": ["bandipur", "tiger reserve", "safari"]},
    {"name": "Nagarhole National Park (Kabini), Karnataka, India", "id": "city_nagarhole", "lat": 12.0314, "lng": 76.1207, "keywords": ["nagarhole", "kabini"]},
    {"name": "BR Hills (Biligiriranga Hills), Chamarajanagar, Karnataka, India", "id": "city_br_hills", "lat": 11.9939, "lng": 77.1394, "keywords": ["br hills", "biligiriranga"]},
    {"name": "MM Hills (Male Mahadeshwara), Chamarajanagar, Karnataka, India", "id": "city_mm_hills", "lat": 12.0125, "lng": 77.5684, "keywords": ["mm hills", "male mahadeshwara"]},
    {"name": "Chamarajanagar, Karnataka, India", "id": "city_chamarajanagar", "lat": 11.9261, "lng": 76.9437, "keywords": ["chamarajanagar"]},
    {"name": "Mandya, Karnataka, India", "id": "city_mandya", "lat": 12.5228, "lng": 76.8974, "keywords": ["mandya"]},
    {"name": "Shivanasamudra Falls, Mandya, Karnataka, India", "id": "city_shivanasamudra", "lat": 12.2963, "lng": 77.1691, "keywords": ["shivanasamudra", "gaganachukki"]},
    {"name": "Melukote, Mandya, Karnataka, India", "id": "city_melukote", "lat": 12.6631, "lng": 76.6508, "keywords": ["melukote"]},
    {"name": "Ramanagara, Karnataka, India", "id": "city_ramanagara", "lat": 12.7150, "lng": 77.2811, "keywords": ["ramanagara", "sholay hills"]},
    {"name": "Channapatna, Ramanagara, Karnataka, India", "id": "city_channapatna", "lat": 12.6518, "lng": 77.2089, "keywords": ["channapatna", "toys"]},
    {"name": "Kanakapura, Ramanagara, Karnataka, India", "id": "city_kanakapura", "lat": 12.5461, "lng": 77.4199, "keywords": ["kanakapura", "mekedatu"]},
    {"name": "Nandi Hills, Chikkaballapur, Karnataka, India", "id": "city_nandi_hills", "lat": 13.3702, "lng": 77.6835, "keywords": ["nandi hills"]},
    {"name": "Chikkaballapur, Karnataka, India", "id": "city_chikkaballapur", "lat": 13.4355, "lng": 77.7315, "keywords": ["chikkaballapur"]},
    {"name": "Kolar, Karnataka, India", "id": "city_kolar", "lat": 13.1367, "lng": 78.1291, "keywords": ["kolar"]},
    {"name": "KGF (Kolar Gold Fields), Kolar, Karnataka, India", "id": "city_kgf", "lat": 12.9589, "lng": 78.2710, "keywords": ["kgf", "kolar gold fields"]},
    {"name": "Tumakuru (Tumkur), Karnataka, India", "id": "city_tumakuru", "lat": 13.3379, "lng": 77.1173, "keywords": ["tumakuru", "tumkur"]},
    {"name": "Devarayanadurga, Tumakuru, Karnataka, India", "id": "city_devarayanadurga", "lat": 13.3721, "lng": 77.2091, "keywords": ["devarayanadurga"]},
    {"name": "Madhugiri, Tumakuru, Karnataka, India", "id": "city_madhugiri", "lat": 13.6631, "lng": 77.2089, "keywords": ["madhugiri"]},
    {"name": "Chitradurga, Karnataka, India", "id": "city_chitradurga", "lat": 14.2251, "lng": 76.3980, "keywords": ["chitradurga", "fort"]},
    {"name": "Davanagere, Karnataka, India", "id": "city_davanagere", "lat": 14.4644, "lng": 75.9218, "keywords": ["davanagere"]},
    {"name": "Ballari (Bellary), Karnataka, India", "id": "city_ballari", "lat": 15.1394, "lng": 76.9214, "keywords": ["ballari", "bellary"]},

    # North Karnataka Hubs
    {"name": "Badami, Bagalkot, Karnataka, India", "id": "city_badami", "lat": 15.9187, "lng": 75.6766, "keywords": ["badami", "caves"]},
    {"name": "Pattadakal, Bagalkot, Karnataka, India", "id": "city_pattadakal", "lat": 15.9486, "lng": 75.8160, "keywords": ["pattadakal", "unesco"]},
    {"name": "Aihole, Bagalkot, Karnataka, India", "id": "city_aihole", "lat": 16.0189, "lng": 75.8821, "keywords": ["aihole"]},
    {"name": "Bagalkot, Karnataka, India", "id": "city_bagalkot", "lat": 16.1691, "lng": 75.6615, "keywords": ["bagalkot"]},
    {"name": "Vijayapura (Bijapur), Karnataka, India", "id": "city_vijayapura", "lat": 16.8302, "lng": 75.7100, "keywords": ["vijayapura", "bijapur", "gol gumbaz"]},
    {"name": "Belagavi (Belgaum), Karnataka, India", "id": "city_belagavi", "lat": 15.8497, "lng": 74.4977, "keywords": ["belagavi", "belgaum"]},
    {"name": "Gokak Falls, Belagavi, Karnataka, India", "id": "city_gokak_falls", "lat": 16.1856, "lng": 74.8219, "keywords": ["gokak", "gokak falls"]},
    {"name": "Hubballi (Hubli), Dharwad, Karnataka, India", "id": "city_hubballi", "lat": 15.3647, "lng": 75.1240, "keywords": ["hubballi", "hubli"]},
    {"name": "Dharwad, Karnataka, India", "id": "city_dharwad", "lat": 15.4589, "lng": 75.0078, "keywords": ["dharwad"]},
    {"name": "Kalaburagi (Gulbarga), Karnataka, India", "id": "city_kalaburagi", "lat": 17.3297, "lng": 76.8343, "keywords": ["kalaburagi", "gulbarga"]},
    {"name": "Bidar, Karnataka, India", "id": "city_bidar", "lat": 17.9104, "lng": 77.5199, "keywords": ["bidar", "fort"]},
    {"name": "Basavakalyan, Bidar, Karnataka, India", "id": "city_basavakalyan", "lat": 17.8744, "lng": 76.9500, "keywords": ["basavakalyan"]},
    {"name": "Raichur, Karnataka, India", "id": "city_raichur", "lat": 16.2076, "lng": 77.3463, "keywords": ["raichur"]},
    {"name": "Koppal, Karnataka, India", "id": "city_koppal", "lat": 15.3456, "lng": 76.1550, "keywords": ["koppal"]},
    {"name": "Anegundi, Koppal, Karnataka, India", "id": "city_anegundi", "lat": 15.3524, "lng": 76.4957, "keywords": ["anegundi", "kishkindha"]},
    {"name": "Gadag, Karnataka, India", "id": "city_gadag", "lat": 15.4167, "lng": 75.6167, "keywords": ["gadag"]},
    {"name": "Lakkundi, Gadag, Karnataka, India", "id": "city_lakkundi", "lat": 15.3942, "lng": 75.7198, "keywords": ["lakkundi"]},
    {"name": "Haveri, Karnataka, India", "id": "city_haveri", "lat": 14.7963, "lng": 75.4013, "keywords": ["haveri"]},
    {"name": "Ranebennur, Haveri, Karnataka, India", "id": "city_ranebennur", "lat": 14.6231, "lng": 75.6214, "keywords": ["ranebennur"]},
    {"name": "Yadgir, Karnataka, India", "id": "city_yadgir", "lat": 16.7644, "lng": 77.1378, "keywords": ["yadgir"]},
]

# Quick lookup mapping by place_id or alias
KNOWN_CITIES = {d["id"]: {"name": d["name"], "place_id": d["id"], "lat": d["lat"], "lng": d["lng"]} for d in KARNATAKA_DESTINATIONS}


# ----------------------------------------------------------------------
# Backend Helpers
# ----------------------------------------------------------------------

# In-memory place resolution cache so any suggested hotel/place resolves instantly
PLACES_RESOLVE_CACHE: Dict[str, Dict[str, Any]] = {}

def autocomplete_city(
    query: str,
    types: Optional[str] = "cities",
    session_token: Optional[str] = None,
    destination: Optional[str] = None,
) -> List[Dict[str, str]]:
    """Calls Karnataka places registry, OpenStreetMap Nominatim, or Google Places as user types.
    For hotels ('lodging'), searches real hotels and resorts in the destination / Karnataka.
    For cities ('cities'), prioritizes places whose names start with user's typed letters.
    """
    clean_q = query.strip()
    if not clean_q:
        return []

    q_lower = clean_q.lower()
    seen_ids = set()
    suggestions: List[Dict[str, str]] = []

    # ------------------------------------------------------------------
    # CASE A: LODGING / HOTEL SEARCH
    # ------------------------------------------------------------------
    if types == "lodging":
        # 1. Search OpenStreetMap Nominatim for hotels, resorts, homestays, and stays
        search_queries = []
        if destination and destination.lower() not in q_lower:
            search_queries.append(f"{clean_q} {destination} Karnataka")
            search_queries.append(f"{clean_q} resort hotel {destination}")
        else:
            search_queries.append(f"{clean_q} hotel resort Karnataka")
            search_queries.append(f"{clean_q} Karnataka")

        osm_url = "https://nominatim.openstreetmap.org/search"
        headers = {"User-Agent": "NextiTravelCompanion/1.0 (hotel search)"}

        for sq in search_queries:
            if len(suggestions) >= 10:
                break
            try:
                resp = requests.get(
                    osm_url,
                    params={
                        "q": sq,
                        "format": "json",
                        "addressdetails": 1,
                        "limit": 8,
                        "countrycodes": "in",
                    },
                    headers=headers,
                    timeout=3.5,
                )
                if resp.status_code == 200:
                    for item in resp.json():
                        disp_name = item.get("display_name", "")
                        # Verify it's in Karnataka or matches destination
                        if "karnataka" not in disp_name.lower() and (not destination or destination.lower() not in disp_name.lower()):
                            continue
                        short_name = disp_name.split(",")[0].strip()
                        lat = float(item.get("lat", 0))
                        lng = float(item.get("lon", 0))
                        slug = re.sub(r'[^a-zA-Z0-9]', '_', short_name)[:25]
                        pid = f"osm_{lat:.5f}_{lng:.5f}_{slug}"
                        if pid not in seen_ids:
                            seen_ids.add(pid)
                            PLACES_RESOLVE_CACHE[pid] = {
                                "name": short_name,
                                "place_id": pid,
                                "lat": lat,
                                "lng": lng,
                                "formatted_address": disp_name,
                            }
                            suggestions.append({
                                "description": disp_name,
                                "place_id": pid,
                            })
            except Exception:
                pass

        # 2. Also try Google Places Autocomplete if configured
        key = os.getenv("GOOGLE_MAPS_API_KEY", GOOGLE_MAPS_API_KEY)
        if key and len(suggestions) < 5:
            try:
                g_url = (
                    "https://maps.googleapis.com/maps/api/place/autocomplete/json"
                    f"?input={requests.utils.quote(clean_q)}"
                    "&types=lodging"
                    "&components=country:in"
                    "&location=14.5000,75.8000&radius=450000"
                    f"&key={key}"
                )
                if session_token:
                    g_url += f"&sessiontoken={session_token}"
                g_resp = requests.get(g_url, timeout=3)
                g_data = g_resp.json()
                if g_data.get("status") == "OK":
                    for pred in g_data.get("predictions", []):
                        g_pid = pred.get("place_id", "")
                        desc = pred.get("description", "")
                        if g_pid not in seen_ids:
                            seen_ids.add(g_pid)
                            suggestions.append({"description": desc, "place_id": g_pid})
            except Exception:
                pass

        # 3. If user typed a specific name and nothing found, provide custom hotel entry
        if not suggestions:
            dest_label = f"{destination}, Karnataka, India" if destination else "Karnataka, India"
            pid = f"hotel_{clean_q.lower().replace(' ', '_')}"
            suggestions.append({
                "description": f"{clean_q.title()} Stay, {dest_label}",
                "place_id": pid,
            })

        return suggestions

    # ------------------------------------------------------------------
    # CASE B: CITIES / GEOCODE DESTINATIONS SEARCH
    # ------------------------------------------------------------------
    prefix_matches: List[Dict[str, str]] = []
    word_matches: List[Dict[str, str]] = []
    other_matches: List[Dict[str, str]] = []

    # 1. Match against comprehensive Karnataka registry (Prioritizing Starts-With)
    for dest in KARNATAKA_DESTINATIONS:
        dest_name = dest["name"]
        pid = dest["id"]
        primary_name = dest_name.split(",")[0].strip().lower()
        alias_keywords = [k.lower() for k in dest.get("keywords", [])]

        if primary_name.startswith(q_lower):
            if pid not in seen_ids:
                prefix_matches.append({"description": dest_name, "place_id": pid})
                seen_ids.add(pid)
        elif any(k.startswith(q_lower) for k in alias_keywords) or any(w.startswith(q_lower) for w in primary_name.replace("(", " ").replace(")", " ").split()):
            if pid not in seen_ids:
                word_matches.append({"description": dest_name, "place_id": pid})
                seen_ids.add(pid)
        elif q_lower in primary_name or any(q_lower in k for k in alias_keywords):
            if pid not in seen_ids:
                other_matches.append({"description": dest_name, "place_id": pid})
                seen_ids.add(pid)

    ordered_karnataka = prefix_matches + word_matches + other_matches

    # 2. If user searched for a town/place in Karnataka not in top 100 or query has >= 3 chars
    if len(ordered_karnataka) < 5 and len(clean_q) >= 3:
        try:
            osm_url = "https://nominatim.openstreetmap.org/search"
            headers = {"User-Agent": "NextiTravelCompanion/1.0 (city search)"}
            resp = requests.get(
                osm_url,
                params={
                    "q": f"{clean_q}, Karnataka, India",
                    "format": "json",
                    "addressdetails": 1,
                    "limit": 5,
                    "countrycodes": "in",
                },
                headers=headers,
                timeout=3,
            )
            if resp.status_code == 200:
                for item in resp.json():
                    disp_name = item.get("display_name", "")
                    if "karnataka" in disp_name.lower():
                        short_name = disp_name.split(",")[0].strip()
                        lat = float(item.get("lat", 0))
                        lng = float(item.get("lon", 0))
                        slug = re.sub(r'[^a-zA-Z0-9]', '_', short_name)[:25]
                        pid = f"osm_{lat:.5f}_{lng:.5f}_{slug}"
                        if pid not in seen_ids:
                            seen_ids.add(pid)
                            PLACES_RESOLVE_CACHE[pid] = {
                                "name": short_name,
                                "place_id": pid,
                                "lat": lat,
                                "lng": lng,
                                "formatted_address": disp_name,
                            }
                            ordered_karnataka.append({
                                "description": disp_name,
                                "place_id": pid,
                            })
        except Exception:
            pass

    # 3. Query Google Places if available
    key = os.getenv("GOOGLE_MAPS_API_KEY", GOOGLE_MAPS_API_KEY)
    google_suggestions: List[Dict[str, str]] = []
    if key:
        url = (
            "https://maps.googleapis.com/maps/api/place/autocomplete/json"
            f"?input={requests.utils.quote(clean_q)}"
            "&types=(cities)"
            "&components=country:in"
            "&location=14.5000,75.8000&radius=450000"
            f"&key={key}"
        )
        if session_token:
            url += f"&sessiontoken={session_token}"
        try:
            resp = requests.get(url, timeout=3)
            data = resp.json()
            if data.get("status") == "OK":
                for pred in data.get("predictions", []):
                    desc = pred.get("description", "")
                    g_pid = pred.get("place_id", "")
                    if "karnataka" in desc.lower():
                        if g_pid not in seen_ids:
                            google_suggestions.append({"description": desc, "place_id": g_pid})
                            seen_ids.add(g_pid)
        except Exception:
            pass

    final_suggestions = ordered_karnataka + google_suggestions
    if not final_suggestions:
        formatted = f"{clean_q.title()}, Karnataka, India"
        final_suggestions.append({
            "description": formatted,
            "place_id": f"city_{clean_q.lower().replace(' ', '_')}",
        })

    return final_suggestions


def resolve_city(place_id: str, session_token: Optional[str] = None) -> Dict[str, Any]:
    """Calls Place Details with the chosen place ID; resolves name, ID, lat and lng."""
    # 1. Check in-memory PLACES_RESOLVE_CACHE
    if place_id in PLACES_RESOLVE_CACHE:
        return PLACES_RESOLVE_CACHE[place_id]

    # 2. Check osm_{lat}_{lng}_{slug} format - directly decode coordinates!
    if place_id.startswith("osm_"):
        parts = place_id.split("_")
        if len(parts) >= 3:
            try:
                lat = float(parts[1])
                lng = float(parts[2])
                slug_name = " ".join(parts[3:]).title() if len(parts) > 3 else "Place"
                return {
                    "name": slug_name,
                    "place_id": place_id,
                    "lat": lat,
                    "lng": lng,
                    "formatted_address": f"{slug_name}, Karnataka, India",
                }
            except Exception:
                pass

    # 3. Check Google Places API if key available
    key = os.getenv("GOOGLE_MAPS_API_KEY", GOOGLE_MAPS_API_KEY)
    if key and (place_id.startswith("ChIJ") or len(place_id) > 25) and not place_id.startswith("city_"):
        url = (
            "https://maps.googleapis.com/maps/api/place/details/json"
            f"?place_id={place_id}"
            "&fields=name,geometry,formatted_address"
            f"&key={key}"
        )
        if session_token:
            url += f"&sessiontoken={session_token}"
        try:
            resp = requests.get(url, timeout=3)
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

    # 4. Match in comprehensive Karnataka registry
    clean_id = place_id.lower().replace("city_", "").replace("_", " ")
    for dest in KARNATAKA_DESTINATIONS:
        if dest["id"] == place_id or dest["id"] in place_id or clean_id in dest["name"].lower():
            return {
                "name": dest["name"].split(",")[0],
                "place_id": dest["id"],
                "lat": dest["lat"],
                "lng": dest["lng"],
                "formatted_address": dest["name"],
            }

    # 5. Geocode via Nominatim for any other city / hotel name
    try:
        clean_name = place_id.replace("city_", "").replace("hotel_", "").replace("_", " ")
        osm_url = "https://nominatim.openstreetmap.org/search"
        headers = {"User-Agent": "NextiTravelCompanion/1.0"}
        resp = requests.get(
            osm_url,
            params={
                "q": f"{clean_name}, Karnataka, India",
                "format": "json",
                "limit": 1,
            },
            headers=headers,
            timeout=3,
        )
        if resp.status_code == 200 and resp.json():
            item = resp.json()[0]
            lat = float(item.get("lat"))
            lng = float(item.get("lon"))
            disp_name = item.get("display_name", "")
            return {
                "name": clean_name.title(),
                "place_id": place_id,
                "lat": lat,
                "lng": lng,
                "formatted_address": disp_name,
            }
    except Exception:
        pass

    # Fallback to Coorg / Central Karnataka
    return {
        "name": place_id.replace("city_", "").replace("hotel_", "").replace("_", " ").title(),
        "place_id": place_id,
        "lat": 12.4244,
        "lng": 75.7382,
        "formatted_address": f"{place_id.replace('city_', '').replace('hotel_', '').title()}, Karnataka, India",
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
    search_q = req.search_query
    suggestions = autocomplete_city(
        search_q,
        types=req.types,
        session_token=req.session_token,
        destination=req.destination,
    )
    return {
        "query": search_q,
        "suggestions": suggestions,
    }


@app.post("/places/reverse-geocode")
def handle_reverse_geocode(req: ReverseGeocodeRequest):
    """Converts GPS coordinates into human-readable address/place name."""
    key = os.getenv("GOOGLE_MAPS_API_KEY", GOOGLE_MAPS_API_KEY)
    if key:
        url = f"https://maps.googleapis.com/maps/api/geocode/json?latlng={req.lat},{req.lng}&key={key}"
        try:
            resp = requests.get(url, timeout=5)
            data = resp.json()
            if data.get("status") == "OK" and data.get("results"):
                res = data["results"][0]
                formatted = res.get("formatted_address", "")
                locality = ""
                for comp in res.get("address_components", []):
                    types = comp.get("types", [])
                    if "locality" in types or "sublocality" in types:
                        locality = comp.get("long_name", "")
                        break
                return {
                    "address": formatted,
                    "locality": locality or formatted,
                    "place_id": res.get("place_id", ""),
                }
        except Exception:
            pass
    return {
        "address": f"Location ({req.lat:.4f}, {req.lng:.4f})",
        "locality": f"Coordinates ({req.lat:.3f}, {req.lng:.3f})",
        "place_id": "",
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

    # Synchronize discovered places to Firestore if Firebase Admin is configured
    sync_discover_places_to_firestore(req.trip_id, discover_result)

    return discover_result


@app.post("/plan")
async def handle_plan(req: PlanRequest):
    """Step 7 & 8: ADK planner builds daily schedule, opening hours, and routes.
    Backend validates itinerary and returns daily schedules with warnings.
    """
    user_id = req.session_token or "traveler"
    start_pt = req.start or "Starting Point"
    hotel_pt = req.hotel or "Hotel Stay"
    end_pt = req.end or req.hotel or start_pt

    pool = list(TRIP_PLACES_CACHE.get(req.trip_id, []))
    if req.selected_places:
        pool.extend(req.selected_places)

    plan_result = await run_plan_async(
        user_id=user_id,
        trip_id=req.trip_id,
        dates=req.dates,
        selected_ids=req.selected_ids,
        all_places_pool=pool,
        start_point=start_pt,
        end_point=end_pt,
        hotel=hotel_pt,
        travel_mode=req.travel_mode or "DRIVE",
        selected_names=req.selected_names,
    )

    # Validate itinerary
    validated_itinerary = validate_itinerary(
        itinerary=plan_result,
        trip_dates=req.dates,
        selected_stops=req.selected_ids,
    )

    # Synchronize generated itinerary to Firestore if Firebase Admin is configured
    sync_trip_plan_to_firestore(req.trip_id, validated_itinerary)

    return validated_itinerary


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    host = os.getenv("HOST", "0.0.0.0")
    uvicorn.run("main:app", host=host, port=port, reload=True)
