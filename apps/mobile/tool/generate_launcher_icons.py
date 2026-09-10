"""Regenerate Android launcher packaging from the unchanged complete logo.

Run from any directory with Python 3 and Pillow: python tool/generate_launcher_icons.py
Pillow is build tooling only, not a mobile runtime dependency.
"""

from pathlib import Path

from PIL import Image, ImageDraw

MOBILE = Path(__file__).resolve().parents[1]
RES = MOBILE / 'android/app/src/main/res'
SOURCE = MOBILE / 'assets/branding/weyonje-logo.png'


def artwork(size, width_fraction, background):
    source = Image.open(SOURCE).convert('RGBA')
    logo = source.crop(source.getchannel('A').getbbox())
    width = round(size * width_fraction)
    height = round(width * logo.height / logo.width)
    logo = logo.resize((width, height), Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', (size, size), background)
    canvas.alpha_composite(logo, ((size - width) // 2, (size - height) // 2))
    return canvas


def generate():
    for density, scale in [('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2),
                           ('xxhdpi', 3), ('xxxhdpi', 4)]:
        folder = RES / f'mipmap-{density}'
        folder.mkdir(parents=True, exist_ok=True)
        size = round(48 * scale)
        legacy = artwork(size, 0.80, 'white')
        legacy.save(folder / 'ic_launcher.png')
        mask = Image.new('L', (size, size))
        ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
        legacy.putalpha(mask)
        legacy.save(folder / 'ic_launcher_round.png')
        # The full rectangle fits inside the adaptive 66 dp safe circle:
        # sqrt(60^2 + (60*148/472)^2) < 66 on a 108 dp layer.
        artwork(round(108 * scale), 60 / 108, (0, 0, 0, 0)).save(
            folder / 'ic_launcher_foreground.png')
    folder = RES / 'mipmap-anydpi-v26'
    folder.mkdir(parents=True, exist_ok=True)
    xml = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@android:color/white" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
'''
    for name in ['ic_launcher', 'ic_launcher_round']:
        (folder / f'{name}.xml').write_text(xml, encoding='utf-8')


if __name__ == '__main__':
    generate()
