# App Icon

## Generation Prompt

```
Dibsly iOS app icon, a bold white hand silhouette claiming a small rounded price tag,
large dominant subject filling the entire square frame, edge-to-edge composition,
no padding, no margin, no empty space, no transparent edges,
solid vivid green background (#16C784), flat design, simple bold shapes,
professional, clean, no text, no words, no letters, square format, 1024x1024
```

## Generated Image

- Source: `icon_raw.png` (1024×1024, Agnes Image 2.1 Flash)
- Final asset: `Dibsly/Assets.xcassets/AppIcon.appiconset/icon_1024.png`
- Style: flat brand mark, white/cream hand claiming a tag on Dibs Green `#16C784`
- API: Agnes Image 2.1 Flash (primary), 1 attempt, no fallback needed
- Processing: alpha trimmed, subject scaled to 920px on an opaque green canvas, converted to RGB (no alpha)

## Asset Catalog

- AppIcon.appiconset configured: ✅ (single 1024×1024 universal icon, Xcode 27 asset format)
- All sizes generated: ✅ (Xcode derives all required sizes from the 1024 icon)
- AccentColor: defined as `#16C784` in `AccentColor.colorset`
- Alpha channel: ❌ none (`sips -g hasAlpha` → `no`)
