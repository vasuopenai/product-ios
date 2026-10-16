# App icon

`render.swift` draws the Food Genie icon with Core Graphics: four green tiles (leaf, flexed arm,
carrot, checkmark) under a magnifying lens, plus the earlier candidates and a size sheet.

```
cd Tools/AppIcon
swiftc -module-cache-path /tmp/swiftmc render.swift -o /tmp/render && /tmp/render /tmp/icons
cp /tmp/icons/H-quadrants-lens.png ../../FoodGenie/Assets.xcassets/AppIcon.appiconset/icon.png
```

`sheet.png` in the output shows each candidate at 180, 120 and 60 pixels on light and dark.
