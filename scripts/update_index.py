import os
import json

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

def update_index_for_directory(directory):
    index_path = os.path.join(directory, "index.json")
    existing_ids = set(load_json(index_path, []))

    for filename in os.listdir(directory):
        if not filename.endswith(".json"):
            continue
        if filename == "index.json":
            continue

        file_path = os.path.join(directory, filename)

        try:
            with open(file_path, "r") as f:
                data = json.load(f)
                artifact_id = data.get("id")
                if artifact_id:
                    existing_ids.add(artifact_id)
        except Exception:
            print(f"Skipping invalid JSON: {file_path}")

    save_json(index_path, sorted(existing_ids))

def main():
    for root, dirs, files in os.walk(SESSIONS_DIR):
        if root == SESSIONS_DIR:
            continue  # skip top-level sessions/
        update_index_for_directory(root)

if __name__ == "__main__":
    main()

