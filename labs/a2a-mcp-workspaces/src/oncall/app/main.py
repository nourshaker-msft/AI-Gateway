from datetime import datetime, timezone

from fastapi import FastAPI

app = FastAPI(title="OnCall API", version="1.0")

ROTATIONS = {
    "platform": {
        "engineer": "Robin Diaz",
        "phone": "+1-555-0142",
        "severity_level": "P1",
        "escalation_policy": "Escalate to team lead after 15 minutes",
    },
    "payments": {
        "engineer": "Sam Okafor",
        "phone": "+1-555-0177",
        "severity_level": "P2",
        "escalation_policy": "Escalate to finance duty manager after 30 minutes",
    },
    "network": {
        "engineer": "Lena Petrova",
        "phone": "+1-555-0199",
        "severity_level": "P1",
        "escalation_policy": "Page the NOC bridge immediately",
    },
}


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/status")
def oncall_status(team: str = "platform"):
    """Return the current (synthetic) on-call engineer for a team."""
    entry = ROTATIONS.get(team.lower(), ROTATIONS["platform"])
    on_call_since = datetime.now(timezone.utc).replace(
        hour=8, minute=0, second=0, microsecond=0
    )

    return {
        "team": team,
        "engineer": entry["engineer"],
        "phone": entry["phone"],
        "severity_level": entry["severity_level"],
        "escalation_policy": entry["escalation_policy"],
        "on_call_since": on_call_since.strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
