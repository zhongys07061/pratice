# -*- coding: utf-8 -*-
"""把 362a 图标缩放到各 mipmap 尺寸，替换 Android 应用图标"""
from PIL import Image
import os

SRC = r'C:\Users\18249\Desktop\362af907edd247da953c0e0d69b09f2e.jpeg~tplv-a9rns2rl98-downsize_watermark_1_5_b.png'
BASE = r'C:\Users\18249\Desktop\quiz_app\android\app\src\main\res'

sizes = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
}

im = Image.open(SRC).convert('RGBA')

for density, size in sizes.items():
    out_dir = os.path.join(BASE, f'mipmap-{density}')
    out_path = os.path.join(out_dir, 'ic_launcher.png')
    # 高质量缩放
    resized = im.resize((size, size), Image.LANCZOS)
    resized.save(out_path, 'PNG')
    print(f'{density}: {size}x{size} -> {out_path}')

print('done')
