from __future__ import annotations


def icon_key_for_category(name: str | None) -> str:
    normalized = (name or "").strip().lower()
    icon_map = {
        "coffee": "coffee",
        "spices": "spices",
        "herbs & attar": "herbs_attar",
        "incense": "incense",
        "nuts": "nuts",
        "dates": "dates",
        "oils": "oils",
    }
    return icon_map.get(normalized, "collection")
