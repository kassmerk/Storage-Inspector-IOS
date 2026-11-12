# AppIcons — hand-cut icons

Icons in this folder are copied into the app bundle as-is and win over every other source:
they are used before the icon of the installed app and before the App Store artwork, so they
also work offline and on iOS versions where the private APIs are gone.

## Naming

| File name | Shown on |
| --- | --- |
| `icon-<bundle-id>.png` | the installed app with that bundle id (installed-apps mode) |
| `icon-<item id>.png` | the demo row with that id (`youtube`, `telegram`, `spotify`, …) |

`AppIconLoader` tries `icon-<bundle-id>.png` first and falls back to `icon-<item id>.png`, so a
single file can serve both modes: `icon-com.google.ios.youtube.png` matches the real YouTube
app, `icon-youtube.png` matches the demo row.

## Requirements

* PNG, square, 180×180 px or larger (the tile is 62 pt, so 180 px is 3×).
* No transparency needed — the tile clips the corners itself.
* Keep the file name lowercase with dots/dashes only (they end up in a file path).

## Adding one

`tools/make-app-icon.ps1` does the cutting and resizing on Windows:

```powershell
# center crop of a square-ish screenshot, resized to 180x180
./tools/make-app-icon.ps1 -Source C:\icons\youtube-photo.png -Name icon-youtube

# take the 512 px icon out of a full home-screen screenshot at (40, 300)
./tools/make-app-icon.ps1 -Source C:\icons\home.png -Name icon-com.google.ios.youtube `
    -CropX 40 -CropY 300 -CropSize 512
```

The script writes `StorageInspector/Resources/AppIcons/<name>.png`. The folder is registered in
the Xcode project as a *folder reference*, so a new PNG needs no project change: rebuild and it
is inside the bundle.
