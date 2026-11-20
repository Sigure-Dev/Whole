# アプリ代替アイコン & プレビュー画像ジェネレータ
# 使い方: python Tools/gen_app_icons.py
# Resources/icon.png (白線+黒背景) をもとに、色違いのアイコンを生成して
# Resources/Assets.xcassets に配置する。
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "Resources", "icon.png")
ASSETS = os.path.join(ROOT, "Resources", "Assets.xcassets")

# (名前, 背景色RGB, 線色RGB)
VARIANTS = [
    ("Ocean", (10, 30, 52), (95, 205, 235)),
    ("Sakura", (252, 247, 249), (232, 72, 141)),
    ("Sunset", (46, 16, 40), (255, 150, 90)),
    ("Forest", (8, 40, 28), (110, 232, 175)),
]

APPICONSET_JSON = {
    "images": [
        {"filename": "", "idiom": "universal", "platform": "ios", "size": "1024x1024"}
    ],
    "info": {"author": "xcode", "version": 1},
}

IMAGESET_JSON = {
    "images": [{"filename": "preview.png", "idiom": "universal"}],
    "info": {"author": "xcode", "version": 1},
}


def write_json(path: str, data: dict) -> None:
    with open(path, "w", encoding="utf-8") as fp:
        json.dump(data, fp, indent=2, ensure_ascii=False)


def main() -> None:
    # プライマリアイコン(1024)を appiconset へ配置
    primary_dir = os.path.join(ASSETS, "AppIcon.appiconset")
    os.makedirs(primary_dir, exist_ok=True)
    Image.open(SRC).convert("RGBA").resize((1024, 1024), Image.LANCZOS).save(
        os.path.join(primary_dir, "AppIcon1024.png"), "PNG"
    )
    print("ok: AppIcon (primary 1024)")

    # 白線(明部)をマスクとして使う
    lum = np.asarray(Image.open(SRC).convert("L")).astype(np.float32) / 255.0
    mask = lum[..., None]  # H x W x 1

    for name, bg, fg in VARIANTS:
        b = np.array(bg, dtype=np.float32)[None, None, :]
        f = np.array(fg, dtype=np.float32)[None, None, :]
        blended = b * (1 - mask) + f * mask
        img = Image.fromarray(np.clip(blended, 0, 255).astype(np.uint8), "RGB")

        set_dir = os.path.join(ASSETS, f"AppIcon-{name}.appiconset")
        os.makedirs(set_dir, exist_ok=True)
        png = os.path.join(set_dir, f"AppIcon-{name}.png")
        img.save(png, "PNG")

        meta = json.loads(json.dumps(APPICONSET_JSON))
        meta["images"][0]["filename"] = f"AppIcon-{name}.png"
        write_json(os.path.join(set_dir, "Contents.json"), meta)

        prev_dir = os.path.join(ASSETS, f"IconPreview-{name}.imageset")
        os.makedirs(prev_dir, exist_ok=True)
        img.resize((180, 180), Image.LANCZOS).save(
            os.path.join(prev_dir, "preview.png"), "PNG"
        )
        write_json(os.path.join(prev_dir, "Contents.json"), IMAGESET_JSON)
        print(f"ok: AppIcon-{name} ({os.path.getsize(png)} bytes)")

    # デフォルトアイコンのプレビュー
    orig = Image.open(SRC).convert("RGB").resize((180, 180), Image.LANCZOS)
    ddir = os.path.join(ASSETS, "IconPreview-Default.imageset")
    os.makedirs(ddir, exist_ok=True)
    orig.save(os.path.join(ddir, "preview.png"), "PNG")
    write_json(os.path.join(ddir, "Contents.json"), IMAGESET_JSON)
    print("ok: IconPreview-Default")


if __name__ == "__main__":
    main()
