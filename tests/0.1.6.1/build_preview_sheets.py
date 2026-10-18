"""Assemble technical previews from the recorded release Canvas replays."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

test = Path(__file__).resolve().parent
captures = test / 'captures'
previews = test / 'previews'
previews.mkdir(exist_ok=True)
font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 19)
small = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 14)
sheet = Image.new('RGB', (1100, 1190), '#e7ddbd')
draw = ImageDraw.Draw(sheet)
scenes = [('dawn', 'DAWN'), ('noon', 'MIDDAY'), ('evening', 'EVENING'),
          ('dusk', 'DUSK'), ('midnight-unlit', 'MIDNIGHT - UNLIT'),
          ('midnight-torch', 'MIDNIGHT - TORCH (5 m)')]
for index, (name, title) in enumerate(scenes):
    x, y = index % 2 * 550, index // 2 * 390
    draw.text((x + 12, y + 5), title, font=font, fill='#35483d')
    image = Image.open(captures / (name + '.png')).convert('RGB')
    image = image.resize((550, 360), Image.Resampling.LANCZOS)
    sheet.paste(image, (x, y + 30))
draw.text((12, 1173), 'Staged scenes; actual release Canvas commands, software replay. Native source art is unchanged.', font=small, fill='#35483d')
sheet.save(previews / 'daylight-and-torch.jpg', quality=94)

frames = [Image.open(captures / ('gait-%02d.png' % frame)).convert('RGB') for frame in range(32)]
frames[0].save(previews / 'five-animal-cycle.gif', save_all=True,
               append_images=frames[1:], duration=45, loop=0, optimize=True)
print('FINAL_PREVIEWS_READY', previews)
