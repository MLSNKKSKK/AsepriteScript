# Aseprite Scripts

English | [日本語](README.ja.md)

A small collection of [Aseprite](https://www.aseprite.org/) scripts, plus one extension.

| Script | What it does |
| --- | --- |
| [New Sprite from Preset](#new-sprite-from-preset) | Creates a new sprite from a list of canvas sizes you've saved. |
| [Import GIF as Layer](#import-gif-as-layer) | Imports a GIF animation into the open sprite as a layer. |
| [Replace Color in All Layers](#replace-color-in-all-layers) | Replaces one color with another in every layer and frame at once. |
| [Create Effect Layer](#create-effect-layer) | Adds a color layer shaped like the active layer, with a blend mode such as Multiply. |
| [Bezier Curve](#bezier-curve) (extension) | Adds curve layers: lines drawn with Bezier curves that you can edit on the canvas at any time. |

## Installation

1. Download the `.lua` files you want:
   - [`New Sprite from Preset.lua`](New%20Sprite%20from%20Preset.lua)
   - [`Import GIF as Layer.lua`](Import%20GIF%20as%20Layer.lua)
   - [`Replace Color in All Layers.lua`](Replace%20Color%20in%20All%20Layers.lua)
   - [`Create Effect Layer.lua`](Create%20Effect%20Layer.lua)

   To get them all at once, use **Code > Download ZIP** on this page.
2. In Aseprite, choose **File > Scripts > Open Scripts Folder**.
3. Copy the `.lua` files into that folder.
4. Choose **File > Scripts > Rescan Scripts Folder** (or restart Aseprite).

The scripts now appear under **File > Scripts**. You can also give them keyboard shortcuts in **Edit > Keyboard Shortcuts**.

The [`ja`](ja) folder has Japanese versions of the same scripts. You only need one language version of each.

Bezier Curve is an extension, and is installed differently:

1. Download [`bezier-curve.aseprite-extension`](extensions/bezier-curve.aseprite-extension).
2. Double-click it (Windows, macOS), or in Aseprite choose **Edit > Preferences > Extensions > Add Extension** and pick the file.

It stays installed and is ready every time Aseprite starts. Its menus and messages are in English or Japanese, following Aseprite's language setting. To remove it, use **Uninstall** in the same Extensions page.

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

An extension that adds **curve layers**. Lines on a curve layer are drawn with Bezier curves and stay editable: select the layer and you can move the points, change how the lines bend, or change their color and width right on the canvas, at any time.

- Click and drag on the canvas, like the Pen tool in drawing apps. A small panel holds the settings
- Several lines per layer, each with its own color and width (1–32 px, round brush)
- Pixel-perfect option for clean 1px lines, or antialiasing for smooth edges (RGB and Grayscale)
- Closed shapes (connect the last point to the first), and filling the inside with a color, with or without the line
- Transform lines: scale, rotate, shear, flip and move them with a box on the canvas, or type exact values
- Each frame has its own lines
- Works with RGB, Grayscale and Indexed sprites

### Usage

Choose **Layer > New > New Curve Layer** (also in the right-click menu of the layers in the timeline). A layer named `Curve 1` is added right above the active layer. Curve layers are shown in green in the timeline, so they're easy to tell apart (curve layers made with an earlier version get the color with their next edit; a layer color you picked yourself is kept).

While a curve layer is selected, you edit its lines directly on the canvas, and a small panel opens at the right edge of the window. Zooming with the mouse wheel and scrolling with Space+drag work as usual.

| On the canvas | What it does |
| --- | --- |
| Click an empty spot | Starts a new shape, or adds a point to the end of the shape you're drawing (or the selected shape). |
| Press on an empty spot and drag | Adds a point and pulls out its handles, bending the line. |
| Click the last point of the shape you're drawing, or press **Enter** | Finishes the shape. The next click on an empty spot starts a new one. |
| Click the first point of the shape you're drawing | Closes the shape (joins its last point to the first) and finishes it. It stays selected. |
| Drag a point | Moves the point. |
| Drag a handle | Changes how the line bends. The handle on the other side turns with it, unless **Move one handle only** is checked. |
| Click a line | Selects its shape. Clicking a line of the selected shape adds a point there without changing its form. |
| Click inside a filled shape | Selects the shape (the one on top where fills overlap). To start a new shape on top of a fill, press **New Shape** first. |
| Drag a line, or inside a fill | Moves the whole shape. |
| Click a point | Selects it (it gets a white outline). |
| **Delete** / **Backspace** | Deletes the selected point, and selects the one before it (so pressing it again goes on with the points). When a shape is selected without a point (for example after clicking its line or fill, or closing it), deletes the whole shape. |
| **Ctrl+Z** / **Ctrl+Y** | Undo / redo. Your recent changes to the lines are undone first, then Aseprite's own history. |
| **Esc** | Cancels the drag in progress, or finishes / deselects the shape. |

While you're drawing a shape, clicks only add to that shape: other shapes can't be grabbed, so you can start on another shape's point or cross over its line. Inside fills, clicks and drags add points too (a drag pulls out a curved point). After you finish the shape, clicking another shape's line selects it for editing.

There is no "apply" step. When you select another layer or frame, or use another command (such as saving or a filter), the changes are put in Aseprite's undo history as a single step (**Edit > Undo** / Ctrl+Z). Selecting the curve layer again lets you keep editing, and so does coming back after saving and reopening the file.

While you edit, the points and handles are shown on the curve layer in bright green: each point is a hollow 3×3 pixel square with the line showing in its middle (pale green for the selected point, darker green for the points of other shapes), and each handle is a dotted line ending in a filled 3×3 square. Clicking anywhere on the square of a point or a handle end grabs it.

Grayscale sprites can't show green, and neither can Indexed sprites whose palette has no green, so there the guides are black and white instead: points are hollow squares with black corners and white sides (the selected point the other way around), handles are dotted in black and white, and each handle end is a filled square with a black outline and a white center. Adding a bright green to an Indexed palette makes the guides green. They disappear when you leave the layer. Zoom in to work comfortably.

At the top of the panel, below a short help text, are the buttons for new shapes, deleting, copying and pasting. Below them, the **Selected Shape** section holds the settings of the selected shape. It has two groups: **Line** for the line around the shape, and **Fill** for its inside.

| Panel | Description |
| --- | --- |
| **New Shape** | Finishes the current shape, so the next click starts a new one. |
| **Delete Shape** | Deletes the selected shape. |
| **Copy** / **Paste** | **Copy** copies the selected shape, or all the shapes of the frame when none is selected. **Paste** adds them at the same place to the frame you're editing, which can be another frame, layer or sprite (handy for animation). When they would land exactly on the same shapes (for example when you paste in the frame you copied from), they go 4 pixels away, towards the inside of the canvas, so Copy and Paste also duplicate shapes. A single pasted shape gets selected. To copy a whole frame, you can also copy its cel in the timeline (for example by dragging it with Ctrl held down): the curves go along and stay editable. |
| **Antialias (smooth edges)** | Smooths the edges of the line and the fill with partly transparent pixels. Where shapes overlap, they blend with each other. RGB and Grayscale only: Indexed sprites can't have partly transparent pixels, so there it's turned off. |
| **Line**: **Draw the line** | Turn it off to draw only the fill, without a line around it. |
| **Line**: **Color** | The line color. Starts as the current foreground color. |
| **Line**: **Width** | The line width in pixels (1–32). |
| **Line**: **Pixel-perfect (width 1)** | Removes the doubled pixels at the corners of 1px lines (the shape's own points are always kept, so the corners of a square stay sharp). Not used with antialiasing. |
| **Fill**: **Fill the inside** | Fills the inside of the shape. A shape whose ends aren't connected is filled as if they were joined by a straight line. The line is drawn on top of the fill. |
| **Fill**: **Color** | The fill color. |
| **Move one handle only** | Dragging a handle doesn't turn the one on the other side, so you can make sharp corners. |
| **Show guides** | Shows or hides the points and handles, to check how the shapes really look. |
| **Connect the ends** | Joins the last point of the selected shape back to the first. Connecting the ends of the shape you're drawing also finishes it (it stays selected). |
| **Delete Point** | Deletes the selected point. |
| **Round/Sharp** | Switches the selected point between round (with handles) and sharp. |
| **Transform Box**, **Numeric...**, **Flip**, **Rotate**, **Keep proportions** | Transform the shapes (see below). |
| **Undo** / **Redo** | Undo / redo your changes to the shapes. |
| **Close** | Closes the panel and stops editing the layer, so you can use Aseprite's tools on it (for example the Move tool). Closing the panel with its × button does the same. Selecting the layer again, or **Layer > Edit Curves**, starts editing again. |
| **Rasterize** | Turns the curve layer into a normal layer (see below). |

When a shape is selected, the fields show its settings and changing them changes that shape. When no shape is selected, the section is called **Next Shape** and holds the settings for the next new shape (while you draw one, it says **Drawing a Shape**).

Editing also pauses while the animation plays, and starts again when you stop it with Enter.

### Transforming lines

Transforms work on the selected shape, or on all the shapes of the frame when no shape is selected (the panel says which). Each one is a single undo step. Points stay on whole pixels, and the handles turn and stretch with the line.

- **Transform Box** (or **Edit > Transform**, Ctrl+T) puts a box around the lines. It has two modes; click inside the box to switch between them:

  | Mode | Handles | Drag them to |
  | --- | --- | --- |
  | Scale | Squares at the corners and sides | Scale. The opposite side stays in place. Dragging past it flips the lines. With **Keep proportions** checked, the corners keep the width and height in proportion. |
  | Rotate/shear | Circles at the corners | Rotate around the center (the small cross). The angle snaps to multiples of 15° when it's close. |
  | | Diamonds on the sides | Shear: the side slides along, and the line through the center stays. To keep the opposite side in place, move the center onto it first. |
  | | The cross | Moves the center that rotating and shearing work around, for example onto a point to turn the shape around it. It snaps to the points of the shape, to the corners and the middles of the sides of its area, and back to the middle. Its place is remembered, also in the saved file: each shape keeps its own center, and each frame keeps one for transforming all its shapes at once. It moves along when the shape is moved or transformed. Dragging it back to the middle resets it. |

  Drag inside the box to move the lines. Enter, Esc, a click outside the box or **End Transform** finishes.
- **Numeric...** asks for the width and height (%), a rotation (degrees, clockwise) and a horizontal and vertical shear (degrees), and shows the result while you type. Everything happens around the middle of the shapes, or around the center of the transform box if you moved it.
- **Flip Horizontal** / **Flip Vertical** and **Rotate Left 90°** / **Rotate Right 90°** work right away. Aseprite's own **Edit > Flip Horizontal** / **Flip Vertical** (Shift+H / Shift+V) and **Edit > Rotate** do the same while a curve layer is being edited. (**Sprite > Rotate Canvas** and **Sprite > Flip Canvas Horizontal** / **Vertical** still work on the pixels of the whole sprite.)

### Rasterizing

**Layer > Rasterize Curve Layer** (also in the timeline's right-click menu and the panel's **Rasterize** button) turns the curve layer into a normal layer. The pixels stay as they are, but the lines can no longer be edited as curves, and you can paint on the layer with Aseprite's tools. The cels are trimmed to their pixels and the green layer color is removed. **Edit > Undo** (Ctrl+Z) brings the curve layer back.

### Notes

- The lines are saved in the cels, so they're kept in `.aseprite` files. Other formats such as PNG only keep the pixels.
- If you move a curve layer with the Move tool, the lines move with it.
- New frames and copied cels keep their lines, so you can copy a frame and adjust the lines for the next pose. Linked cels share the same lines.
- If a frame of a curve layer is changed some other way (painted over by hand, a filter, and so on), it isn't editable right away, so those changes aren't lost by accident. **Layer > Edit Curves** asks first, then redraws the frame from the lines.
- Curve layers made with the earlier script version of Bezier Curve work as they are. Remove the old `Bezier Curve.lua` from your scripts folder.
- The points and handles are drawn on the curve layer itself, so layers above it can hide them, and the layer's opacity and blend mode apply to them.

### Limitations

Aseprite scripts can't draw on top of the canvas or tell which mouse button or modifier keys were used on it. That's why the points and handles are shown as pixels, and why deleting points, making sharp corners and finishing a line use the panel, the Delete key, Enter or Esc instead of right-click and Alt. Handles snap to whole pixels.

A second click right after the first can be taken as a double-click and ignored, so leave a short pause between clicks when placing points close together. (While editing, the extension turns off **Select a grid tile with double-click** in the preferences, and turns it back on afterwards.)

To rebuild the extension file from the [`extensions/bezier-curve`](extensions/bezier-curve) folder, run `python3 extensions/build.py`.

## Requirements

Aseprite with Lua scripting support (v1.3 or later recommended). The Bezier Curve extension needs v1.3 or later.

## License

[MIT](LICENSE)
