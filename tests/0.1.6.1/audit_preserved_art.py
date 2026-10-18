"""Check that lighting and locomotion do not lower native asset resolution."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[2]
old = root / 'output/adventure game 0.1.6'
new = root / 'output/adventure game 0.1.6.1'
digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
checks = []
for path in sorted((old / 'assets').rglob('*')):
    if not path.is_file() or path.suffix not in ['.png', '.jpg', '.jpeg']:
        continue
    target = new / path.relative_to(old)
    checks.append({'path': str(path.relative_to(old)), 'byte_identical': target.is_file() and digest(path) == digest(target)})
for name in ['collision_profiles.json', 'world_geometry.gd', 'depth_layers.gd', 'paint_density.gd', 'ground_painter.gd']:
    checks.append({'path': name, 'byte_identical': digest(old / name) == digest(new / name)})
report = {'checks': len(checks), 'failures': sum(not row['byte_identical'] for row in checks), 'details': checks}
Path(__file__).with_name('preserved-art-and-collisions.json').write_text(json.dumps(report, indent=2))
assert report['failures'] == 0, report
print('NATIVE_ART_AND_GROUND_PRESERVED', report['checks'], 'checks, 0 failures')
