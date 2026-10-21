from pathlib import Path
import hashlib
import json
import subprocess
import sys
import time
import zipfile

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "output/adventure game 0.1.6"
TEST = ROOT / "tests/0.1.6"
APP = PROJECT / "Forest Wanderer.app"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


if digest(PROJECT / "main.gd") != digest(APP / "Contents/Resources/main.gd"):
    with (TEST / "packaging.log").open("w") as log:
        subprocess.run([sys.executable, str(TEST / "package016.py")], stdout=log, stderr=log, check=True)

resources = APP / "Contents/Resources"
records = []
for path in sorted(resources.rglob("*")):
    if path.is_file():
        source = PROJECT / path.relative_to(resources)
        records.append({"path": str(path.relative_to(resources)), "matches_source": source.is_file() and digest(path) == digest(source)})
assert all(row["matches_source"] for row in records)
subprocess.run(["codesign", "--verify", "--deep", str(APP)], check=True)
start = time.perf_counter()
run = subprocess.run([str(APP / "Contents/MacOS/ForestWanderer016"), "--headless", "--quit-after", "3"], cwd="/private/tmp", capture_output=True, text=True, timeout=90)
log = run.stdout + run.stderr
(TEST / "bundled-launch.log").write_text(log)
ok = run.returncode == 0 and "GAME_READY 0.1.6" in log and "SCRIPT ERROR" not in log and "Parse Error" not in log
report = {"resource_checks": len(records), "resource_failures": sum(not row["matches_source"] for row in records), "game_ready": ok, "bundled_exit_code": run.returncode, "working_directory": "/private/tmp", "launch_wall_seconds": time.perf_counter() - start, "resources": records}
(TEST / "package-validation.json").write_text(json.dumps(report, indent=2))
assert ok
with zipfile.ZipFile(TEST / "release-source.zip", "w", zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(PROJECT.iterdir()):
        if path.is_file() and path.suffix in [".gd", ".godot", ".tscn", ".json", ".txt"]:
            archive.write(path, path.name)
manifest = {path.name: digest(path) for path in sorted(PROJECT.iterdir()) if path.is_file() and path.suffix in [".gd", ".godot", ".tscn", ".json"]}
(TEST / "validated-runtime-hashes.json").write_text(json.dumps(manifest, indent=2))
print("FINAL_PACKAGE_VALIDATED", {key: value for key, value in report.items() if key != "resources"})
