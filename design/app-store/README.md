# App Store screenshot kit

The five active source screenshots in `source/` (`today.jpg`, `guidance.jpg`,
`progress.jpg`, `settings.jpg`, and `pro.jpg`) were captured from the current
Chinese app UI in light mode.
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
