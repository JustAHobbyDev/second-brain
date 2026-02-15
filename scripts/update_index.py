import os
import json
from datetime import datetime, timezone

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SESSIONS_DIR = os.path.join(BASE_DIR, "sessions")

def load_json(path, default):
    if not os.path.exists(path):
        return default
    with open(path, "r") as f:
        return json.load(f)

def save_json(path, data):
    with open(path, "w") as f:
        json.dump(data, f, indent=2)


def summary_snippet(data):
    summary = data.get("summary")
    out = ""
    if isinstance(summary, str):
        out = summary.strip()
    elif isinstance(summary, dict):
        high = summary.get("high_level")
        if isinstance(high, str):
            out = high.strip()
    return (out[:157] + "...") if len(out) > 160 else out


def session_date_from_artifact_id(artifact_id):
    if not isinstance(artifact_id, str):
        return ""
    tail = artifact_id.split("/", 1)[-1]
    parts = tail.split("_")
    for i in range(len(parts) - 2):
        a, b, c = parts[i], parts[i + 1], parts[i + 2]
        if len(a) == 4 and len(b) == 2 and len(c) == 2 and a.isdigit() and b.isdigit() and c.isdigit():
            return f"{a}-{b}-{c}"
    return ""


def update_index_for_directory(directory):
    index_path = os.path.join(directory, "index.json")
    tool = os.path.basename(directory)
    records_by_id = {}

    for filename in os.listdir(directory):
        if not filename.endswith(".json"):
            continue
        if filename == "index.json":
            continue

        file_path = os.path.join(directory, filename)

        try:
            with open(file_path, "r") as f:
                data = json.load(f)
                if not isinstance(data, dict):
                    continue
                artifact_id = data.get("artifact_id") or data.get("id")
                if not isinstance(artifact_id, str):
                    continue
                session_date = data.get("session_date")
                if not isinstance(session_date, str):
                    session_date = session_date_from_artifact_id(artifact_id)
                resumption_score = data.get("resumption_score")
                if not isinstance(resumption_score, int):
                    resumption_score = None
                records_by_id[artifact_id] = {
                    "id": artifact_id,
                    "date": session_date,
                    "resumption_score": resumption_score,
                    "summary_snippet": summary_snippet(data),
                }
        except Exception:
            print(f"Skipping invalid JSON: {file_path}")

    artifacts = sorted(records_by_id.values(), key=lambda r: ((r.get("date") or ""), r["id"]))
    save_json(
        index_path,
        {
            "tool": tool,
            "artifacts": artifacts,
            "last_updated": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        },
    )

def main():
    for root, dirs, files in os.walk(SESSIONS_DIR):
        if root == SESSIONS_DIR:
            continue  # skip top-level sessions/
        update_index_for_directory(root)

if __name__ == "__main__":
    main()
