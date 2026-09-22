import random

from fastapi import FastAPI

app = FastAPI(title="Weather API", version="1.0")

DESCRIPTIONS = ["Clear skies", "Partly cloudy", "Overcast", "Light rain", "Sunny"]
FAHRENHEIT_CITIES = {"seattle", "new york city", "los angeles"}


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/current")
def current_weather(city: str = "Lisbon"):
    """Return the current (synthetic) weather for a city."""
    if city.lower() in FAHRENHEIT_CITIES:
        temperature_format = "Fahrenheit"
        temperature = round(random.uniform(45, 95), 1)
    else:
        temperature_format = "Celsius"
        temperature = round(random.uniform(-5, 35), 1)

    return {
        "city": city,
        "temperature": temperature,
        "temperature_format": temperature_format,
        "description": random.choice(DESCRIPTIONS),
        "humidity": random.randint(20, 100),
        "wind_speed": round(random.uniform(0, 10), 1),
    }
