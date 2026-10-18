"""Record and render final release art, binding the previews to source hashes."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

test = Path(__file__).resolve().parent
project = test.parents[1] / 'output/adventure game 0.1.6.2'
engine = '/Applications/Godot.app/Contents/MacOS/Godot'
node = '/Users/jasonsmacair/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node'
inputs = ['main.gd', 'animal_gait.gd', 'assets/animal_atlas.json', 'assets/animal-skin-topology.bin', 'world_lighting.gd']
def hashes():
    return {name: hashlib.sha256((project / name).read_bytes()).hexdigest() for name in inputs}
before = hashes()
subprocess.run([sys.executable, str(test / 'make_capture_script.py')], check=True)
for script, log in [('capture_release.gd', 'capture.log'), ('capture_art_review.gd', 'capture-art-review.log')]:
    with (test / log).open('w') as out:
        subprocess.run([engine, '--headless', '--path', str(project), '--script', str(test / script)], stdout=out, stderr=out, check=True, timeout=120)
    text = (test / log).read_text()
    assert not any(word in text for word in ['SCRIPT ERROR', 'Parse Error', 'Invalid polygon', 'triangulation failed']), text
names = ['dawn', 'noon', 'evening', 'dusk', 'midnight-unlit', 'midnight-torch', 'before-dawn', 'camp-night']
names += ['gait-%02d' % frame for frame in range(32)]
names += ['art-review-%02d' % frame for frame in range(24)]
names += ['all-painted-headings']
with (test / 'render-final.log').open('w') as out:
    subprocess.run([node, str(test / 'render_captures.cjs'), *names], stdout=out, stderr=out, check=True, timeout=180)
for script in ['build_preview_sheets.py', 'build_art_demo.py']:
    subprocess.run([sys.executable, str(test / script)], check=True)
assert hashes() == before, 'Release changed during visual capture'
(test / 'preview-source-hashes.json').write_text(json.dumps(before, indent=2))
print('FINAL_SOURCE_BOUND_PREVIEWS_READY', len(names))
