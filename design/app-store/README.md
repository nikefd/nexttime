# App Store screenshot kit

The five source screenshots in `source/` were captured from the current Chinese app UI.
`marketing-background.png` was generated as a text-free brand background. The final,
App Store-ready PNG files live in `fastlane/screenshots/zh-Hans/`.

To regenerate the 1290 × 2796 assets:

```bash
python3 -m venv /tmp/nexttime-screenshot-venv
/tmp/nexttime-screenshot-venv/bin/pip install pillow
/tmp/nexttime-screenshot-venv/bin/python scripts/compose_app_store_screenshots.py
```

The composition script preserves the source UI pixels and adds only the background,
headline, subtitle, border, and shadow.
