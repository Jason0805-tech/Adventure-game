"""Make the review animation from final actual Canvas replay frames."""
from pathlib import Path
from PIL import Image
base=Path(__file__).resolve().parent
out=base/'previews'
out.mkdir(exist_ok=True)
frames=[Image.open(base/'captures'/('art-review-%02d.png'%frame)).convert('RGB') for frame in range(24)]
frames[0].save(out/'original-paint-and-walk.gif',save_all=True,append_images=frames[1:],duration=50,loop=0,optimize=True)
frames[4].save(out/'original-paint-and-walk.png')
print('ORIGINAL_PAINT_DEMO_READY',out/'original-paint-and-walk.gif')
