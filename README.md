# New Sprite from Preset

An [Aseprite](https://www.aseprite.org/) script that creates a new sprite from a list of canvas sizes you've saved, so you don't have to type the width and height every time.

## Features

- Pick a saved canvas size and create a new sprite in one step
- Add, overwrite and remove presets right from the dialog
- Choose the color mode (RGB / Grayscale / Indexed)
- Choose the background (Transparent / White / the current Background Color)
- Presets are kept in a plain text file that you can also edit by hand

## Installation

1. Download [`New Sprite from Preset.lua`](New%20Sprite%20from%20Preset.lua).
2. In Aseprite, choose **File > Scripts > Open Scripts Folder**.
3. Copy the `.lua` file into that folder.
4. Choose **File > Scripts > Rescan Scripts Folder** (or restart Aseprite).

The script now appears under **File > Scripts**. You can also give it a keyboard shortcut in **Edit > Keyboard Shortcuts**.

## Usage

Run **File > Scripts > New Sprite from Preset**.

| Field | Description |
| --- | --- |
| **Size** | The preset to use. |
| **Add...** | Adds a new preset. The width and height start from the selected preset. A preset with the same name is replaced. |
| **Remove** | Removes the selected preset (asks first). |
| **Color Mode** | RGB, Grayscale or Indexed. |
| **Background** | Transparent, White, or Background Color (the background color currently set in Aseprite's color bar). |

Click **Create** to make the new sprite.

## Presets file

Presets are saved to `canvas_presets.txt` in Aseprite's user config folder, which is the parent of the scripts folder:

| OS | Location |
| --- | --- |
| Windows | `%APPDATA%\Aseprite\canvas_presets.txt` |
| macOS | `~/Library/Application Support/Aseprite/canvas_presets.txt` |
| Linux | `~/.config/aseprite/canvas_presets.txt` |

The file is created with these default presets the first time the script runs:

```
# name,width,height (one per line)
Character,220,360
16px,16,16
32px,32,32
64px,64,64
```

Each line is `name,width,height`. Lines starting with `#` are ignored. You can edit this file in any text editor; the changes show up the next time you run the script.

## Requirements

Aseprite with Lua scripting support (v1.3 or later recommended).

## License

[MIT](LICENSE)
