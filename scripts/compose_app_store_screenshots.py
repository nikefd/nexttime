#!/usr/bin/env python3

from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps


CANVAS = (1290, 2796)
ROOT = Path(__file__).resolve().parents[1]
BACKGROUND = ROOT / "design/app-store/marketing-background.png"
SOURCE_DIR = ROOT / "design/app-store/source"
OUTPUT_DIR = ROOT / "fastlane/screenshots/zh-Hans"
FONT = "/System/Library/Fonts/Hiragino Sans GB.ttc"

SHOTS = [
    (
        "01-today-practice.png",
        SOURCE_DIR / "today.jpg",
        "打开就知道，今天练什么",
        "一键开始 · 每天只做当前这一项",
    ),
    (
        "02-natural-guidance.png",
        SOURCE_DIR / "guidance.jpg",
        "像正常说话一样自然引导",
        "呼吸、放松与动作节奏更清楚",
    ),
    (
        "03-personal-progress.png",
        SOURCE_DIR / "progress.jpg",
        "18 节个人训练，循序渐进",
        "3 条个人路线 · 6 周计划 · 避开近期重复",
    ),
    (
        "04-local-privacy.png",
        SOURCE_DIR / "settings.jpg",
        "隐私与安全，由你掌控",
        "Face ID · 隐藏通知 · 数据保存在本机",
    ),
    (
        "05-one-time-pro.png",
        SOURCE_DIR / "pro.jpg",
        "一次买断，终身解锁",
        "完整个性化计划 · 自定义训练 · 详细统计",
    ),
]


def font(size: int, index: int = 0) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT, size=size, index=index)


def rounded_image(image: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *image.size), radius=radius, fill=255)
    result = image.convert("RGBA")
    result.putalpha(mask)
    return result


def compose(index: int, output_name: str, source: Path, title: str, subtitle: str) -> None:
    base = Image.open(BACKGROUND).convert("RGB")
    base = ImageOps.fit(base, CANVAS, method=Image.Resampling.LANCZOS)
    base = Image.blend(base, Image.new("RGB", CANVAS, "white"), 0.12).convert("RGBA")

    draw = ImageDraw.Draw(base)
    pill = (120, 72, 350, 132)
    draw.rounded_rectangle(pill, radius=30, fill=(19, 143, 255, 235))
    draw.text((150, 84), "NEXTTIME", font=font(27), fill="white")
    draw.text((1150, 85), f"{index:02d}", font=font(27), fill=(54, 84, 122, 180), anchor="ra")
    draw.text((120, 164), title, font=font(61), fill=(16, 26, 44, 255))
    draw.text((122, 260), subtitle, font=font(32), fill=(73, 92, 119, 235))

    screenshot = Image.open(source).convert("RGB")
    target_width = 970
    target_height = round(screenshot.height * target_width / screenshot.width)
    screenshot = screenshot.resize((target_width, target_height), Image.Resampling.LANCZOS)
    screenshot = rounded_image(screenshot, 58)

    x = (CANVAS[0] - target_width) // 2
    y = 430
    shadow = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        (x - 12, y + 18, x + target_width + 12, y + target_height + 42),
        radius=70,
        fill=(42, 79, 128, 75),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(30))
    base.alpha_composite(shadow)

    border = Image.new("RGBA", (target_width + 16, target_height + 16), (255, 255, 255, 255))
    border = rounded_image(border, 64)
    base.alpha_composite(border, (x - 8, y - 8))
    base.alpha_composite(screenshot, (x, y))

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    output = OUTPUT_DIR / output_name
    base.convert("RGB").save(output, "PNG", optimize=True)
    print(output)


if __name__ == "__main__":
    for position, shot in enumerate(SHOTS, start=1):
        compose(position, *shot)
