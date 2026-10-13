"""Copy reviewed local source changes only. Does not publish or read .env secrets."""
from pathlib import Path
import hashlib
import json
import shutil

base = Path(__file__).resolve().parent
source = (base / "render-release").resolve()
target = Path(r"D:\work\Study-birds").resolve()
entries = json.loads((base / "website-sync-manifest.json").read_text(encoding="utf-8"))
pending = []
for entry in entries:
    src = (source / entry["path"]).resolve()
    dst = (target / entry["path"]).resolve()
    if not src.is_relative_to(source) or not dst.is_relative_to(target):
        raise RuntimeError("Path outside reviewed source/target")
    if hashlib.sha256(src.read_bytes()).hexdigest() != entry["after"]:
        raise RuntimeError("Source changed since review: " + entry["path"])
    current = hashlib.sha256(dst.read_bytes()).hexdigest() if dst.exists() else None
    if current == entry["after"]:
        continue
    if current != entry["before"]:
        raise RuntimeError("Target has newer edits; refusing overwrite: " + entry["path"])
    pending.append((src, dst))
for src, dst in pending:
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dst)
print(f"Synced {len(pending)} reviewed source files. No deployment performed.")
