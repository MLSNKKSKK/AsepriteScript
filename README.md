# Aseprite Scripts

A small collection of [Aseprite](https://www.aseprite.org/) scripts.

| Script | What it does |
| --- | --- |
| [New Sprite from Preset](#new-sprite-from-preset) | Creates a new sprite from a list of canvas sizes you've saved. |
| [Import GIF as Layer](#import-gif-as-layer) | Imports a GIF animation into the open sprite as a layer. |
| [Replace Color in All Layers](#replace-color-in-all-layers) | Replaces one color with another in every layer and frame at once. |

## Installation

1. Download the `.lua` files you want:
   - [`New Sprite from Preset.lua`](New%20Sprite%20from%20Preset.lua)
   - [`Import GIF as Layer.lua`](Import%20GIF%20as%20Layer.lua)
   - [`Replace Color in All Layers.lua`](Replace%20Color%20in%20All%20Layers.lua)

   To get them all at once, use **Code > Download ZIP** on this page.
2. In Aseprite, choose **File > Scripts > Open Scripts Folder**.
3. Copy the `.lua` files into that folder.
4. Choose **File > Scripts > Rescan Scripts Folder** (or restart Aseprite).

The scripts now appear under **File > Scripts**. You can also give them keyboard shortcuts in **Edit > Keyboard Shortcuts**.

## New Sprite from Preset

Creates a new sprite from a list of canvas sizes you've saved, so you don't have to type the width and height every time.

- Pick a saved canvas size and create a new sprite in one step
- Add, overwrite and remove presets right from the dialog
- Choose the color mode (RGB / Grayscale / Indexed)
- Choose the background (Transparent / White / the current Background Color)
- Presets are kept in a plain text file that you can also edit by hand

### Usage

Run **File > Scripts > New Sprite from Preset**.

| Field | Description |
| --- | --- |
| **Size** | The preset to use. |
| **Add...** | Adds a new preset. The width and height start from the selected preset. A preset with the same name is replaced. |
| **Remove** | Removes the selected preset (asks first). |
| **Color Mode** | RGB, Grayscale or Indexed. |
| **Background** | Transparent, White, or Background Color (the background color currently set in Aseprite's color bar). |

Click **Create** to make the new sprite.

### Presets file

Presets are saved to `canvas_presets.txt` in Aseprite's user config folder, which is the parent of the scripts folder:

| OS | Location |
| --- | --- |
| Windows | `%APPDATA%\Aseprite\canvas_presets.txt` |
| macOS | `~/Library/Application Support/Aseprite/canvas_presets.txt` |
| Linux | `~/.config/aseprite/canvas_presets.txt` |

The file is created with these default presets the first time the script runs:

```
# name,width,height (one per line)
16px,16,16
32px,32,32
64px,64,64
```

Each line is `name,width,height`. Lines starting with `#` are ignored. You can edit this file in any text editor; the changes show up the next time you run the script.

## Import GIF as Layer

Imports a GIF animation into the open sprite, one GIF frame per sprite frame.

- Import into a new layer (placed right above the active layer and named after the GIF file), or draw on top of the active layer
- Start from the current frame or from frame 1
- Keep the actual size, or resize the GIF to fit, fill or stretch to the canvas
- Adds frames when the sprite runs out, using the GIF's frame durations
- The whole import is a single undo step (**Edit > Undo** / Ctrl+Z)

### Usage

Open an RGB sprite (to convert one, use **Sprite > Color Mode > RGB Color**), then run **File > Scripts > Import GIF as Layer**.

| Field | Description |
| --- | --- |
| **GIF File** | The GIF to import. |
| **Import Into** | **New Layer**, or **Active Layer (draw on top)** to draw the GIF over the art already on the active layer. The active layer must be a regular layer that isn't locked (not a group, tilemap or reference layer). |
| **Start At** | Which sprite frame the GIF's first frame goes on: **Current Frame** or **Frame 1**. |
| **Size** | **Actual Size**: pixel for pixel.<br>**Fit to Canvas**: the whole GIF fits inside the canvas (may leave empty space).<br>**Fill Canvas**: the GIF covers the whole canvas (parts may extend past the edges).<br>**Stretch to Canvas**: matches the canvas size exactly, ignoring the aspect ratio. |
| **Resize Method** | **Nearest Neighbor** keeps pixels sharp (best for pixel art); **Bilinear** is smooth. Only used when the GIF is resized. |
| **Position** | **Center** or **Top Left**. Not used with Stretch to Canvas. |
| **Add frames if the sprite runs out** | When the GIF has more frames than the sprite has left, adds new frames at the end. If unchecked, the extra GIF frames are skipped. |
| **Also match existing frame durations to the GIF** | Changes the duration of existing sprite frames the GIF lands on to match the GIF. |

Click **Import**.

If the active layer has linked cels, only the cels the GIF is drawn on are unlinked, so the other frames don't change.

### Command line

When run without the UI, pass the options with `--script-param` (before `--script`):

| Parameter | Value |
| --- | --- |
| `file` | Path to the GIF (required). |
| `dest` | `current` to draw on the active layer. Default: new layer. |
| `size` | `fit`, `cover` (Fill Canvas) or `stretch`. Default: actual size. |
| `method` | `bilinear`. Default: nearest neighbor. |

## Replace Color in All Layers

Replaces one color with another in every layer and every frame of the sprite at once.

- Includes layers inside groups and hidden layers
- Skips locked, tilemap and reference layers
- Each pixel keeps its original alpha, so semi-transparent pixels stay semi-transparent
- The whole replacement is a single undo step (**Edit > Undo** / Ctrl+Z)

### Usage

Open an RGB sprite (to convert one, use **Sprite > Color Mode > RGB Color**), then run **File > Scripts > Replace Color in All Layers**.

| Field | Description |
| --- | --- |
| **From** | The color to replace. Starts as the current foreground color. |
| **To** | The new color. Starts as the current background color. If it's semi-transparent, replaced pixels get that much more transparent. |
| **Tolerance** | How close a color must be to **From** to be replaced (0–255, checked separately for red, green and blue). At 0, only the exact color is replaced. |

Click **Replace**. When it's done, a message shows how many pixels were replaced (and how many layers were skipped, if any).

When run without the UI, the script replaces the foreground color with the background color at tolerance 0.

## Requirements

Aseprite with Lua scripting support (v1.3 or later recommended).

## License

[MIT](LICENSE)
