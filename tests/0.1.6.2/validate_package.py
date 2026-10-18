from pathlib import Path
import hashlib
import json
import subprocess
import sys
import time
import zipfile

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "output/adventure game 0.1.6.2"
TEST = ROOT / "tests/0.1.6.2"
APP = PROJECT / "Forest Wanderer.app"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


source_files = [PROJECT / name for name in [
    "project.godot", "main.gd", "main.tscn", "item_data.gd", "inventory.gd",
    "world_geometry.gd", "ground_painter.gd", "paint_density.gd", "depth_layers.gd",
    "collision_profiles.json", "wildlife.gd", "wildlife_data.gd", "animal_gait.gd",
    "world_lighting.gd", "npc_roaming.gd", "ENGINE_LICENSES.txt",
]] + [path for path in (PROJECT / "assets").rglob("*")
      if path.is_file() and path.suffix not in [".import", ".uid"] and path.name != ".DS_Store"]
if any(not (APP / "Contents/Resources" / path.relative_to(PROJECT)).is_file()
       or digest(path) != digest(APP / "Contents/Resources" / path.relative_to(PROJECT))
       for path in source_files):
    with (TEST / "packaging.log").open("w") as log:
        subprocess.run([sys.executable, str(TEST / "package016.py")], stdout=log, stderr=log, check=True)

resources = APP / "Contents/Resources"
records = []
for path in sorted(resources.rglob("*")):
    if path.is_file():
        source = PROJECT / path.relative_to(resources)
        records.append({"path": str(path.relative_to(resources)), "matches_source": source.is_file() and digest(path) == digest(source)})
assert all(row["matches_source"] for row in records)
assert len(records) == len(source_files), "A required release resource was omitted"
subprocess.run(["codesign", "--verify", "--deep", str(APP)], check=True)
start = time.perf_counter()
run = subprocess.run([str(APP / "Contents/MacOS/ForestWanderer0162"), "--headless", "--quit-after", "3"], cwd="/private/tmp", capture_output=True, text=True, timeout=90)
log = run.stdout + run.stderr
(TEST / "bundled-launch.log").write_text(log)
runtime_errors = [text for text in ["SCRIPT ERROR", "Parse Error", "Invalid polygon", "triangulation failed"] if text in log]
ok = run.returncode == 0 and "GAME_READY 0.1.6.2" in log and not runtime_errors
report = {"resource_checks": len(records), "resource_failures": sum(not row["matches_source"] for row in records), "game_ready": ok, "bundled_exit_code": run.returncode, "runtime_errors": runtime_errors, "working_directory": "/private/tmp", "launch_wall_seconds": time.perf_counter() - start, "resources": records}
(TEST / "package-validation.json").write_text(json.dumps(report, indent=2))
assert ok
with zipfile.ZipFile(TEST / "release-source.zip", "w", zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(PROJECT.iterdir()):
        if path.is_file() and path.suffix in [".gd", ".godot", ".tscn", ".json", ".txt"]:
            archive.write(path, path.name)
    for path in sorted((PROJECT / "assets").rglob("*")):
        if path.is_file() and path.suffix in [".json", ".bin"]:
            archive.write(path, str(path.relative_to(PROJECT)))
manifest = {str(path.relative_to(PROJECT)): digest(path) for path in source_files}
(TEST / "validated-runtime-hashes.json").write_text(json.dumps(manifest, indent=2))
print("FINAL_PACKAGE_VALIDATED", {key: value for key, value in report.items() if key != "resources"})
