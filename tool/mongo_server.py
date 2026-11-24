"""ShareKit API. Reads MongoDB credentials from atlas-credentials.env."""

import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from bson import ObjectId
from bson.errors import InvalidId
from pymongo import MongoClient

ROOT = Path(__file__).resolve().parent.parent
ENV_PATH = ROOT / "atlas-credentials.env"


def load_env(path):
    values = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        text = line.strip()
        if not text or text.startswith("#") or "=" not in text:
            continue
        key, value = text.split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def mongodb_uri():
    uri = os.environ.get("MONGODB_URI", "").strip()
    if uri:
        return uri
    if ENV_PATH.is_file():
        return load_env(ENV_PATH).get("MONGODB_URI", "")
    return ""


def connect():
    uri = mongodb_uri()
    if not uri:
        raise SystemExit("MONGODB_URI is missing")
    client = MongoClient(uri, serverSelectionTimeoutMS=8000)
    client.admin.command("ping")
    return client["sharekit"]


DB = connect()


def public_id(value):
    if isinstance(value, ObjectId):
        return str(value)
    return value


def clean(document):
    if document is None:
        return None
    row = dict(document)
    if "_id" in row:
        row["_id"] = public_id(row["_id"])
    return row


def object_id(value):
    try:
        return ObjectId(value)
    except (InvalidId, TypeError):
        return value


class Handler(BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        self._send(204, b"")

    def do_GET(self):
        if self.path == "/api/health":
            self._send(200, b'{"ok":true}')
            return
        if self.path == "/api/catalog":
            document = DB.catalog.find_one({"_id": "main"}) or {
                "sequence": 240,
                "items": [],
                "bookings": [],
            }
            document.pop("_id", None)
            self._send(200, json.dumps(document).encode("utf-8"))
            return
        if self.path in ("/api/users", "/api/messages"):
            name = self.path.rsplit("/", 1)[-1]
            rows = [clean(row) for row in DB[name].find()]
            self._send(200, json.dumps(rows).encode("utf-8"))
            return
        self._send(404, b'{"error":"not found"}')

    def do_POST(self):
        if self.path not in ("/api/users", "/api/messages"):
            self._send(404, b'{"error":"not found"}')
            return
        name = self.path.rsplit("/", 1)[-1]
        payload = self._body()
        payload.pop("_id", None)
        inserted = DB[name].insert_one(payload)
        saved = DB[name].find_one({"_id": inserted.inserted_id})
        self._send(201, json.dumps(clean(saved)).encode("utf-8"))

    def do_PUT(self):
        if self.path == "/api/catalog":
            payload = self._body()
            payload.pop("_id", None)
            DB.catalog.replace_one({"_id": "main"}, payload, upsert=True)
            self._send(200, b'{"ok":true}')
            return
        parts = self.path.strip("/").split("/")
        if len(parts) == 3 and parts[0] == "api" and parts[1] in ("users", "messages"):
            payload = self._body()
            payload.pop("_id", None)
            DB[parts[1]].replace_one({"_id": object_id(parts[2])}, payload)
            self._send(200, b'{"ok":true}')
            return
        self._send(404, b'{"error":"not found"}')

    def _body(self):
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length).decode("utf-8")
        data = json.loads(raw or "{}")
        if not isinstance(data, dict):
            raise ValueError("expected an object")
        return data

    def _send(self, status, body):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        if body:
            self.wfile.write(body)

    def log_message(self, fmt, *args):
        print("[mongo] " + (fmt % args))


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8780"))
    print(f"ShareKit MongoDB API listening on port {port}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
