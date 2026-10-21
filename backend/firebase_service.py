"""firebase_service.py: Firebase Admin Firestore Integration for Trip AI Backend.

Connects the FastAPI backend to Cloud Firestore (Project: nextripia-3e2bc).
Automatically persists generated itineraries and discovered places so that both
the Flutter client and backend stay perfectly in sync.
"""

import logging
import os
from pathlib import Path
from typing import Any, Dict, Optional

logger = logging.getLogger("trip_ai.firebase")

_firebase_initialized = False
_db = None

PROJECT_ID = "nextripia-3e2bc"


def get_firestore_client():
    """Initializes and returns the Firestore client if credentials are present."""
    global _firebase_initialized, _db
    if _db is not None:
        return _db

    if _firebase_initialized and _db is None:
        return None

    try:
        import firebase_admin
        from firebase_admin import credentials, firestore

        # Check for service account JSON key in backend folder or environment
        key_path = os.getenv("FIREBASE_SERVICE_ACCOUNT_KEY")
        if not key_path:
            candidate = Path(__file__).resolve().parent / "serviceAccountKey.json"
            if candidate.exists():
                key_path = str(candidate)

        if key_path and os.path.exists(key_path):
            cred = credentials.Certificate(key_path)
            firebase_admin.initialize_app(cred, {"projectId": PROJECT_ID})
            _db = firestore.client()
            _firebase_initialized = True
            logger.info("Firebase Admin successfully initialized with Service Account Key.")
            return _db
        else:
            # Attempt default application credentials
            try:
                firebase_admin.initialize_app(options={"projectId": PROJECT_ID})
                _db = firestore.client()
                _firebase_initialized = True
                logger.info("Firebase Admin initialized with default project credentials.")
                return _db
            except Exception:
                logger.info(
                    "Firebase Admin running in optional mode. Place 'serviceAccountKey.json' "
                    "in backend/ to enable direct server-to-Firestore synchronization."
                )
                _firebase_initialized = True
                return None
    except Exception as e:
        logger.warning(f"Could not initialize Firebase Admin: {e}")
        _firebase_initialized = True
        return None


def sync_trip_plan_to_firestore(trip_id: str, plan_data: Dict[str, Any]) -> bool:
    """Saves or updates generated itinerary in Firestore collection 'trips/{trip_id}'."""
    if not trip_id or trip_id.startswith("test_"):
        return False

    db = get_firestore_client()
    if db is None:
        return False

    try:
        from firebase_admin import firestore
        doc_ref = db.collection("trips").document(trip_id)
        doc_ref.set(
            {
                "tripCode": trip_id,
                "itineraryPlan": plan_data,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            },
            merge=True,
        )
        logger.info(f"Successfully synced itinerary for trip '{trip_id}' to Firestore.")
        return True
    except Exception as e:
        logger.warning(f"Failed to sync trip plan to Firestore: {e}")
        return False


def sync_discover_places_to_firestore(trip_id: str, discover_data: Dict[str, Any]) -> bool:
    """Saves discovered places in Firestore collection 'trips/{trip_id}'."""
    if not trip_id or trip_id.startswith("test_"):
        return False

    db = get_firestore_client()
    if db is None:
        return False

    try:
        from firebase_admin import firestore
        doc_ref = db.collection("trips").document(trip_id)
        doc_ref.set(
            {
                "tripCode": trip_id,
                "destination": discover_data.get("city"),
                "discoveredPlaces": discover_data.get("places", []),
                "categories": discover_data.get("categories", {}),
                "updatedAt": firestore.SERVER_TIMESTAMP,
            },
            merge=True,
        )
        logger.info(f"Successfully synced discovered places for trip '{trip_id}' to Firestore.")
        return True
    except Exception as e:
        logger.warning(f"Failed to sync discover places to Firestore: {e}")
        return False
