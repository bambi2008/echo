# Echo — App Asset Colors

Create these Color Sets in `Assets.xcassets`:

| Name | Hex | Usage |
|------|-----|-------|
| `background` | #090A0E | Main background |
| `surface` | #1A1B1F | Card background |
| `accent` | #3B82F6 | Buttons, highlights |
| `textPrimary` | #FFFFFF | Headlines |
| `textSecondary` | #8E8E93 | Subtitles |
| `textMuted` | #636366 | Timestamps |

## How to create

1. Open `Assets.xcassets` in Xcode
2. Right-click → New Color Set
3. Set the name (e.g. `accent`)
4. Set "Any Appearance" and "Dark" to the same hex value (dark-only app)

The code uses `Color("accent", bundle: .main)` which expects these to exist.
If you haven't created them yet, SwiftUI will fall back to `.accentColor` (system blue).
