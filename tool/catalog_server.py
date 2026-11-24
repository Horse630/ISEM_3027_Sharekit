"""Shared item catalog for Firefox, Edge, and any other browser on this computer."""

import base64
import json
import os
import sqlite3
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DB_PATH = Path(os.environ.get("SHAREKIT_CATALOG_DB", str(ROOT / "sharekit_catalog.db")))


def connect():
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(DB_PATH)
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA journal_mode=WAL")
    db.executescript(
        """
        CREATE TABLE IF NOT EXISTS items (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          owner TEXT NOT NULL,
          category TEXT NOT NULL,
          condition TEXT NOT NULL,
          distance_meters INTEGER NOT NULL,
          summary TEXT NOT NULL,
          rating REAL NOT NULL,
          review_count INTEGER NOT NULL,
          handovers INTEGER NOT NULL,
          daily_price REAL,
          photo BLOB,
          address TEXT NOT NULL,
          handover TEXT NOT NULL,
          district TEXT NOT NULL DEFAULT 'kowloonCity'
        );
        CREATE TABLE IF NOT EXISTS bookings (
          id TEXT PRIMARY KEY,
          item_id TEXT NOT NULL,
          start_date TEXT NOT NULL,
          end_date TEXT NOT NULL,
          stage TEXT NOT NULL,
          pickup_code TEXT NOT NULL,
          note TEXT NOT NULL,
          deposit TEXT NOT NULL,
          return_condition TEXT,
          stars INTEGER,
          comment TEXT,
          issue TEXT
        );
        CREATE TABLE IF NOT EXISTS catalog_meta (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          sequence INTEGER NOT NULL
        );
        """
    )
    columns = {row[1] for row in db.execute("PRAGMA table_info(items)")}
    if "district" not in columns:
        db.execute(
            "ALTER TABLE items ADD COLUMN district TEXT NOT NULL DEFAULT 'kowloonCity'"
        )
    return db


def snapshot(db):
    meta = db.execute("SELECT sequence FROM catalog_meta WHERE id = 1").fetchone()
    items = []
    for row in db.execute("SELECT * FROM items ORDER BY rowid ASC"):
        item = dict(row)
        photo = item["photo"]
        item["photo"] = base64.b64encode(photo).decode("ascii") if photo else None
        items.append(item)
    bookings = [dict(row) for row in db.execute("SELECT * FROM bookings ORDER BY rowid ASC")]
    return {
        "sequence": meta["sequence"] if meta else 240,
        "items": items,
        "bookings": bookings,
    }


def replace(db, payload):
    db.execute("DELETE FROM items")
    db.execute("DELETE FROM bookings")
    for item in payload.get("items", []):
        photo = item.get("photo")
        db.execute(
            """
            INSERT INTO items (
              id, name, owner, category, condition, distance_meters, summary,
              rating, review_count, handovers, daily_price, photo, address, handover, district
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                item["id"],
                item["name"],
                item["owner"],
                item["category"],
                item["condition"],
                item["distance_meters"],
                item["summary"],
                item["rating"],
                item["review_count"],
                item["handovers"],
                item.get("daily_price"),
                base64.b64decode(photo) if photo else None,
                item["address"],
                item["handover"],
                item.get("district") or "kowloonCity",
            ),
        )
    for booking in payload.get("bookings", []):
        db.execute(
            """
            INSERT INTO bookings (
              id, item_id, start_date, end_date, stage, pickup_code, note,
              deposit, return_condition, stars, comment, issue
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                booking["id"],
                booking["item_id"],
                booking["start_date"],
                booking["end_date"],
                booking["stage"],
                booking["pickup_code"],
                booking["note"],
                booking["deposit"],
                booking.get("return_condition"),
                booking.get("stars"),
                booking.get("comment"),
                booking.get("issue"),
            ),
        )
    db.execute(
        "INSERT OR REPLACE INTO catalog_meta (id, sequence) VALUES (1, ?)",
        (payload.get("sequence", 240),),
    )
    db.commit()


class Handler(BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        self._send(204, b"")

    def do_GET(self):
        if self.path == "/api/health":
            self._send(200, b'{"ok":true}')
            return
        if self.path == "/api/catalog":
            with connect() as db:
                body = json.dumps(snapshot(db)).encode("utf-8")
            self._send(200, body)
            return
        self._send(404, b'{"error":"not found"}')

    def do_PUT(self):
        if self.path != "/api/catalog":
            self._send(404, b'{"error":"not found"}')
            return
        length = int(self.headers.get("Content-Length", "0"))
        payload = json.loads(self.rfile.read(length).decode("utf-8"))
        with connect() as db:
            replace(db, payload)
            body = json.dumps(snapshot(db)).encode("utf-8")
        self._send(200, body)

    def _send(self, status, body):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, PUT, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        if body:
            self.wfile.write(body)

    def log_message(self, fmt, *args):
        print(f"[catalog] {self.address_string()} {fmt % args}")


if __name__ == "__main__":
    port = int(os.environ.get("SHAREKIT_CATALOG_PORT", "8780"))
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    print(f"ShareKit catalog database: {DB_PATH}")
    print(f"Listening on http://127.0.0.1:{port}")
    server.serve_forever()
