from PIL import Image, ImageDraw
from pathlib import Path
import json

root = Path(__file__).resolve().parents[2]
document = json.loads((root / 'tests/0.1.5.8/independent-solid-samples.json').read_text())
keys = list(dict.fromkeys(sample['profile'] for sample in document['samples']))
cellw, cellh = 500, 590
sheet = Image.new('RGB', (3 * cellw, ((len(keys) + 2) // 3) * cellh), '#edf0e1')
draw = ImageDraw.Draw(sheet)
for index, key in enumerate(keys):
    x, y = (index % 3) * cellw, (index // 3) * cellh
    source = Image.open(root / 'tests/0.1.5.7/profile-sprites' / f'{key}.png').convert('RGBA')
    scale = min(440 / source.width, 360 / source.height)
    width, height = round(source.width * scale), round(source.height * scale)
    source = source.resize((width, height), Image.Resampling.LANCZOS)
    sheet.paste(source, (x + 20, y + 30), source)
    draw.text((x + 20, y + 10), key, fill='#28322b')
    points = [sample for sample in document['samples'] if sample['profile'] == key]
    for number, sample in enumerate(points):
        px = x + 20 + sample['uv'][0] * width
        py = y + 30 + sample['uv'][1] * height
        free = sample.get('expect') == 'free'
        draw.ellipse((px - 4, py - 4, px + 4, py + 4), fill='#37ff86' if free else '#e6f734', outline='#092ac7', width=2)
        draw.text((px + 5, py - 3), str(number + 1), fill='#092ac7', stroke_fill='white', stroke_width=1)
        note = ' [FREE center only]' if free and not sample.get('actor_footprint_clear', True) else (' [FREE]' if free else '')
        draw.text((x + 20, y + 400 + number * 13), f'{number + 1}. ' + sample['part'] + note, fill='#28322b')
output = root / 'tests/0.1.5.8/independent-solid-landmarks.png'
sheet.save(output)
print(output)
