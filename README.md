# Aseprite Scripts

English | [日本語](README.ja.md)

A small collection of [Aseprite](https://www.aseprite.org/) scripts.

| Script | What it does |
| --- | --- |
| [New Sprite from Preset](#new-sprite-from-preset) | Creates a new sprite from a list of canvas sizes you've saved. |
| [Import GIF as Layer](#import-gif-as-layer) | Imports a GIF animation into the open sprite as a layer. |
| [Replace Color in All Layers](#replace-color-in-all-layers) | Replaces one color with another in every layer and frame at once. |
| [Create Effect Layer](#create-effect-layer) | Adds a color layer shaped like the active layer, with a blend mode such as Multiply. |
| [Bezier Curve](#bezier-curve) | Draws lines with Bezier curves right on the canvas, and lets you edit them again later. |

## Installation

1. Download the `.lua` files you want:
   - [`New Sprite from Preset.lua`](New%20Sprite%20from%20Preset.lua)
   - [`Import GIF as Layer.lua`](Import%20GIF%20as%20Layer.lua)
   - [`Replace Color in All Layers.lua`](Replace%20Color%20in%20All%20Layers.lua)
   - [`Create Effect Layer.lua`](Create%20Effect%20Layer.lua)
   - [`Bezier Curve.lua`](Bezier%20Curve.lua)

   To get them all at once, use **Code > Download ZIP** on this page.
2. In Aseprite, choose **File > Scripts > Open Scripts Folder**.
3. Copy the `.lua` files into that folder.
4. Choose **File > Scripts > Rescan Scripts Folder** (or restart Aseprite).

The scripts now appear under **File > Scripts**. You can also give them keyboard shortcuts in **Edit > Keyboard Shortcuts**.

The [`ja`](ja) folder has Japanese versions of the same scripts. You only need one language version of each.

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

## Create Effect Layer

Creates an "effect layer" right above the active layer: the same shape as the active layer's pixels, filled with one color and set to a blend mode such as Multiply. Handy for shading, tinting or lighting a character without painting on the original layer.

- Covers every frame the active layer has art on
- The new layer is named after the blend mode and the source layer, e.g. `Multiply (Layer 1)`
- The whole operation is a single undo step (**Edit > Undo** / Ctrl+Z)

### Usage

Open an RGB sprite (to convert one, use **Sprite > Color Mode > RGB Color**), select a regular layer (not a group or tilemap), then run **File > Scripts > Create Effect Layer**.

| Field | Description |
| --- | --- |
| **Color** | The fill color. Starts as the current foreground color. |
| **Blend Mode** | The new layer's blend mode (Multiply by default). Uses the same names as Aseprite's Layer Properties. |
| **Opacity** | The new layer's opacity (0–255). |
| **Match the source layer's transparency** | When checked, semi-transparent pixels on the source layer stay semi-transparent on the effect layer. When unchecked, every visible pixel gets the color as is, ignoring the source layer's transparency. |

Click **Create**.

The effect layer is a copy made at that moment: if you edit the original layer later, the effect layer doesn't follow. You can change its blend mode and opacity afterwards in **Layer > Properties**.

When run without the UI, the script uses the foreground color, Multiply and full opacity.

## Bezier Curve

Draws lines with Bezier curves right on the canvas, on a separate "curve layer". The lines stay editable: run the script again later to move the points, change how the lines bend, or change their color and width.

- Click and drag on the canvas, like the Pen tool in drawing apps. A small panel holds the settings
- Several lines per layer, each with its own color and width (1–32 px, round brush)
- Pixel-perfect option for clean 1px lines
- Closed shapes (connect the last point to the first)
- Each frame has its own lines
- Works with RGB, Grayscale and Indexed sprites
- Applying is a single undo step (**Edit > Undo** / Ctrl+Z)

### Usage

Select the layer you want the lines to go above, then run **File > Scripts > Bezier Curve**. A small panel opens at the right edge of the window and you can draw on the canvas right away. Zooming with the mouse wheel and scrolling with Space+drag work as usual.

| On the canvas | What it does |
| --- | --- |
| Click an empty spot | Adds a point to the end of the selected line, or starts a new line if none is selected. |
| Press on an empty spot and drag | Adds a point and pulls out its handles, bending the line. |
| Drag a point | Moves the point. |
| Drag a handle | Changes how the line bends. The handle on the other side turns with it, unless **Move one handle only** is checked. |
| Click a line | Adds a point there without changing the shape. |
| Drag a line | Moves the whole line. |
| Click a point | Selects it (it gets a white outline). |
| **Delete** / **Backspace** | Deletes the selected point. |
| **Ctrl+Z** / **Ctrl+Y** | Undo / redo your changes to the lines. |
| **Esc** | Cancels the drag in progress, or deselects the line. |

While you edit, the points and handles are shown as colored pixels on a temporary layer called `Bezier Curve guides (editing)`: magenta for the points of the selected line, yellow for the selected point, cyan for the handles, and purple for the points of the other lines. They are removed when you finish. Zoom in to work comfortably.

| Panel | Description |
| --- | --- |
| **Color** | The line color. Starts as the current foreground color. |
| **Width** | The line width in pixels (1–32). |
| **Pixel-perfect (width 1)** | Removes the doubled pixels at the corners of 1px lines. |
| **Connect the ends** | Joins the last point of the selected line back to the first. |
| **Move one handle only** | Dragging a handle doesn't turn the one on the other side, so you can make sharp corners. |
| **Show guides** | Shows or hides the points and handles, to check how the line really looks. |
| **New Line** | Deselects the line, so the next click starts a new one. |
| **Delete Line** / **Delete Point** | Deletes the selected line / point. |
| **Round/Sharp** | Switches the selected point between round (with handles) and sharp. |
| **Undo** / **Redo** | Undo / redo your changes to the lines. |
| **Apply** / **Cancel** | Finishes the edit. **Cancel** throws away the changes. |

When a line is selected, the fields show its settings and changing them changes that line. When no line is selected, they are the settings for the next new line.

Click **Apply** (or close the panel). The first time, a new layer named `Curve 1` is created right above the active layer.

The edit is also applied automatically when you go to another frame or sprite, or use any other command (such as saving), like Aseprite's Text tool does. View commands like zoom and grid don't end the edit.

### Editing the lines later

Select the curve layer, go to the frame you want to change and run **Bezier Curve** again. The lines of that frame become editable on the canvas.

- The lines are saved in the cel, so they're kept in `.aseprite` files. Other formats such as PNG only keep the pixels.
- If you move the curve layer with the Move tool, the lines move with it.
- New frames and copied cels keep their lines, so you can copy a frame and adjust the lines for the next pose. Linked cels share the same lines.
- Anything painted by hand on the curve layer is lost when you apply an edit, because the frame is redrawn from the lines (the script warns you first). Paint on other layers instead.
- The English and Japanese versions use the same data, so either one can edit lines made with the other.

### Limitations

Aseprite scripts can't draw on top of the canvas or tell which mouse button or modifier keys were used on it. That's why the points and handles are shown as pixels, and why deleting points and making sharp corners use the panel or the Delete key instead of right-click and Alt. Handles snap to whole pixels.

A second click right after the first can be taken as a double-click and ignored, so leave a short pause between clicks when placing points close together. (While editing, the script turns off **Select a grid tile with double-click** in the preferences, and turns it back on when you finish.)

## Requirements

Aseprite with Lua scripting support (v1.3 or later recommended). Bezier Curve needs v1.3 or later.

## License

[MIT](LICENSE)
