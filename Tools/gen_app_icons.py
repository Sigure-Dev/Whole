# アプリアイコン & プレビュー画像ジェネレータ
# 使い方: python Tools/gen_app_icons.py
# Resources 内のソース画像から Assets.xcassets のアイコン一式を生成する。
#
# 構成:
#   icon.png           (正方形)   -> AppIcon (プライマリ)
#   icon-yoko.png      (横長)     -> AppIcon-Yoko     (黒背景にパディングして正方形化)
#   icon-yoko-yoko.png (超横長)   -> AppIcon-YokoYoko (同上)
import json
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "Resources")
ASSETS = os.path.join(RES, "Assets.xcassets")

# (アセット名, プレビュー名, ソースパス)
VARIANTS = [
    ("AppIcon", "Default", os.path.join(RES, "icon.png")),
    ("AppIcon-Yoko", "Yoko", os.path.join(RES, "icon-yoko.png")),
    ("AppIcon-YokoYoko", "YokoYoko", os.path.join(RES, "icon-yoko-yoko.png")),
]

ICON_SIZE = 1024
PREVIEW_SIZE = 180

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


def fit_square(img: Image.Image, size: int) -> Image.Image:
    """アスペクト比を保ったまま黒背景の正方形に収める(アートは黒背景なのでシームレス)"""
    img = img.convert("RGB")
    img.thumbnail((size, size), Image.LANCZOS)
    canvas = Image.new("RGB", (size, size), (0, 0, 0))
    canvas.paste(img, ((size - img.width) // 2, (size - img.height) // 2))
    return canvas


def main() -> None:
    for asset_name, preview_name, src in VARIANTS:
        if asset_name == "AppIcon":
            set_dir = os.path.join(ASSETS, "AppIcon.appiconset")
            png_name = "AppIcon1024.png"
        else:
            set_dir = os.path.join(ASSETS, f"{asset_name}.appiconset")
            png_name = f"{asset_name}.png"
        os.makedirs(set_dir, exist_ok=True)

        icon = fit_square(Image.open(src), ICON_SIZE)
        png = os.path.join(set_dir, png_name)
        icon.save(png, "PNG", optimize=True)

        meta = json.loads(json.dumps(APPICONSET_JSON))
        meta["images"][0]["filename"] = png_name
        write_json(os.path.join(set_dir, "Contents.json"), meta)

        prev_dir = os.path.join(ASSETS, f"IconPreview-{preview_name}.imageset")
        os.makedirs(prev_dir, exist_ok=True)
        icon.resize((PREVIEW_SIZE, PREVIEW_SIZE), Image.LANCZOS).save(
            os.path.join(prev_dir, "preview.png"), "PNG", optimize=True
        )
        write_json(os.path.join(prev_dir, "Contents.json"), IMAGESET_JSON)
        print(f"ok: {asset_name} ({os.path.getsize(png)} bytes)")


if __name__ == "__main__":
    main()
