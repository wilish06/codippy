"""Compone las capturas de marketing de Codippy: fondo lavanda, titular y dispositivo enmarcado.
Uso: python3 compose_shots.py <raw_dir> <out_root>
Lee raw/iphone-*.png (1320x2868) y raw/ipad-*.png (2064x2752)."""
import sys, os, glob
from PIL import Image, ImageDraw, ImageFont, ImageFilter

RAW, OUT = sys.argv[1], sys.argv[2]

HEADLINES = {
    '1-portada':    'Encuentra cualquier\ncódigo postal',
    '2-resultados': 'Toda la ciudad,\nbarrio por barrio',
    '3-detalle':    'Provincia, mapa\ny códigos vecinos',
    '4-ia':         'Pega un texto y la IA\nencuentra la dirección',
    '5-offline':    'Descarga países y\nbusca sin conexión',
}

def font(size):
    try:
        f = ImageFont.truetype('/System/Library/Fonts/SFNS.ttf', size)
        try: f.set_variation_by_name('Bold')
        except Exception:
            try: f.set_variation_by_name(b'Bold')
            except Exception: pass
        return f
    except Exception:
        return ImageFont.truetype('/System/Library/Fonts/HelveticaNeue.ttc', size, index=1)

def gradient(w, h, top=(240, 238, 251), bottom=(221, 217, 245)):
    base = Image.new('RGB', (1, h))
    for y in range(h):
        t = y / (h - 1)
        base.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return base.resize((w, h))

def compose(raw_path, headline, spec):
    W, H = spec['canvas']
    shot = Image.open(raw_path).convert('RGB')
    canvas = gradient(W, H).convert('RGBA')
    draw = ImageDraw.Draw(canvas)

    # Titular
    f = font(spec['font'])
    lines = headline.split('\n')
    y = spec['title_y']
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=f)
        tw = bbox[2] - bbox[0]
        draw.text(((W - tw) / 2 - bbox[0], y), line, font=f, fill=(28, 26, 48))
        y += int(spec['font'] * 1.12)

    # Dispositivo
    margin, top = spec['margin'], spec['frame_top']
    bezel, radius = spec['bezel'], spec['radius']
    screen_w = W - 2 * (margin + bezel)
    scale = screen_w / shot.width
    screen_h = int(shot.height * scale)
    shot = shot.resize((screen_w, screen_h), Image.LANCZOS)

    frame_w, frame_h = screen_w + 2 * bezel, screen_h + 2 * bezel
    # Sombra
    shadow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [margin, top + 30, margin + frame_w, top + frame_h], radius=radius, fill=(40, 30, 90, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(50))
    canvas.alpha_composite(shadow)
    # Marco
    frame = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle(
        [margin, top, margin + frame_w, top + frame_h], radius=radius, fill=(24, 24, 28, 255))
    canvas.alpha_composite(frame)
    # Pantalla con esquinas redondeadas
    mask = Image.new('L', (screen_w * 2, screen_h * 2), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, screen_w * 2 - 1, screen_h * 2 - 1], radius=(radius - bezel) * 2, fill=255)
    mask = mask.resize((screen_w, screen_h), Image.LANCZOS)
    canvas.paste(shot, (margin + bezel, top + bezel), mask)
    return canvas.convert('RGB')

SPECS = {
    'iphone': dict(canvas=(1320, 2868), font=118, title_y=150, margin=88, frame_top=540, bezel=22, radius=150,
                   variants={'iphone-6.9': (1320, 2868), 'iphone-6.5': (1284, 2778)}),
    'ipad':   dict(canvas=(2064, 2752), font=126, title_y=140, margin=150, frame_top=525, bezel=26, radius=80,
                   variants={'ipad-13': (2064, 2752), 'ipad-12.9': (2048, 2732)}),
}

for device, spec in SPECS.items():
    for raw in sorted(glob.glob(f'{RAW}/{device}-*.png')):
        key = os.path.basename(raw)[len(device) + 1:-4]
        img = compose(raw, HEADLINES[key], spec)
        for variant, size in spec['variants'].items():
            d = f'{OUT}/marketing/{variant}'; os.makedirs(d, exist_ok=True)
            out = img if size == img.size else img.resize(size, Image.LANCZOS)
            out.save(f'{d}/{key}.png', optimize=True)
        # Captura limpia (sin marco) para el tamaño principal
        plain_dir = f"{OUT}/{'iphone-6.9' if device == 'iphone' else 'ipad-13'}"
        os.makedirs(plain_dir, exist_ok=True)
        Image.open(raw).convert('RGB').save(f'{plain_dir}/{key}.png', optimize=True)
        print('ok', device, key)

# Cómo regenerar las capturas (ver README):
#   1. Arranca un iPhone 17 Pro Max y un iPad Pro 13" (iOS 26.5) y fija la barra de estado:
#        xcrun simctl status_bar <UDID> override --time 09:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
#   2. Lanza la app con los argumentos de demo y captura con `xcrun simctl io <UDID> screenshot raw/<iphone|ipad>-<escena>.png`:
#        1-portada:    -demoNoSplash YES
#        2-resultados: -demoNoSplash YES -demoQuery Sevilla
#        3-detalle:    -demoNoSplash YES -demoQuery 28001 -demoOpenFirst YES
#        4-ia:         -demoNoSplash YES -demoSmartText "Hola! Te lo mando a Calle Serrano 21, 3ºB, Madrid. Mi tel es 600 123 456. Gracias!"
#        5-offline:    -demoNoSplash YES -demoOfflineSheet YES
#   3. python3 Tools/compose_shots.py raw AppStoreAssets
