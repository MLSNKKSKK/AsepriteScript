-- New Sprite from Preset
-- Creates a new sprite from a list of saved canvas sizes.
-- * Manage presets with the "Add..." and "Remove" buttons in the dialog.
-- * Presets are stored in canvas_presets.txt in Aseprite's user config folder
--   (one "name,width,height" per line; you can also edit it in a text editor).

local PRESET_FILE = app.fs.joinPath(app.fs.userConfigPath, "canvas_presets.txt")

-- Presets written to the file when it doesn't exist yet
local DEFAULT_PRESETS = {
  { name = "16px", w = 16, h = 16 },
  { name = "32px", w = 32, h = 32 },
  { name = "64px", w = 64, h = 64 },
}

local MAX_SIZE = 65535

local presets = {}

local function validSize(w, h)
  return w >= 1 and h >= 1 and w <= MAX_SIZE and h <= MAX_SIZE
end

local function savePresets()
  local f = io.open(PRESET_FILE, "w")
  if not f then
    app.alert("Could not save presets to:\n" .. PRESET_FILE)
    return
  end
  f:write("# name,width,height (one per line)\n")
  for _, p in ipairs(presets) do
    f:write(("%s,%d,%d\n"):format(p.name, p.w, p.h))
  end
  f:close()
end

local function loadPresets()
  presets = {}
  local f = io.open(PRESET_FILE, "r")
  if not f then
    for _, p in ipairs(DEFAULT_PRESETS) do
      table.insert(presets, { name = p.name, w = p.w, h = p.h })
    end
    savePresets()
    return
  end
  for line in f:lines() do
    local name, w, h = line:match("^%s*(.-)%s*,%s*(%d+)%s*,%s*(%d+)%s*$")
    if name and name ~= "" and not name:find("^#") then
      w, h = tonumber(w), tonumber(h)
      -- Skip sizes Aseprite can't create (e.g. typos made while editing the file)
      if validSize(w, h) then
        table.insert(presets, { name = name, w = w, h = h })
      end
    end
  end
  f:close()
end

local function labelOf(p)
  return ("%s (%dx%d)"):format(p.name, p.w, p.h)
end

local function labels()
  local t = {}
  for _, p in ipairs(presets) do
    table.insert(t, labelOf(p))
  end
  return t
end

local function findByLabel(label)
  for i, p in ipairs(presets) do
    if labelOf(p) == label then return i, p end
  end
end

local MODES = {
  ["RGB"] = ColorMode.RGB,
  ["Grayscale"] = ColorMode.GRAYSCALE,
  ["Indexed"] = ColorMode.INDEXED,
}

-- Indexed images store palette indexes, so find the entry closest to the color
local function nearestIndex(palette, color)
  local best, bestDist = 0, math.huge
  for i = 0, #palette - 1 do
    local c = palette:getColor(i)
    local d = (c.red - color.red) ^ 2 + (c.green - color.green) ^ 2 + (c.blue - color.blue) ^ 2
    if d < bestDist then
      best, bestDist = i, d
    end
  end
  return best
end

local function createSprite(p, modeName, bgName)
  local mode = MODES[modeName]
  local sprite = Sprite(p.w, p.h, mode)
  app.sprite = sprite
  -- Sprites made by scripts start with an all-black palette, so use the default
  -- palette like File > New does (Grayscale sprites already get a gray ramp)
  if mode ~= ColorMode.GRAYSCALE and app.defaultPalette then
    sprite:setPalette(app.defaultPalette)
  end
  if bgName ~= "Transparent" then
    local color = (bgName == "White") and Color{ r = 255, g = 255, b = 255 } or app.bgColor
    -- Make the background first, then fill it, so the color is used as is
    app.command.BackgroundFromLayer()
    local img = Image(sprite.spec)
    if mode == ColorMode.INDEXED then
      img:clear(nearestIndex(sprite.palettes[1], color))
    else
      img:clear(Color{ r = color.red, g = color.green, b = color.blue })
    end
    sprite.cels[1].image = img
  end
  app.refresh()
end

loadPresets()

-- Without a UI (command-line run), create a sprite from the first preset
if not app.isUIAvailable then
  if #presets > 0 then
    createSprite(presets[1], "RGB", "Transparent")
    print(("Created a sprite from %s."):format(labelOf(presets[1])))
  end
  return
end

local dlg

local function refreshList(selectLabel)
  dlg:modify{ id = "preset", options = labels(), option = selectLabel }
end

local function addPreset()
  local current = select(2, findByLabel(dlg.data.preset))
  local add = Dialog("Add Preset")
  add:entry{ id = "name", label = "Name", text = "" }
     :number{ id = "w", label = "Width", decimals = 0, text = tostring(current and current.w or 32) }
     :number{ id = "h", label = "Height", decimals = 0, text = tostring(current and current.h or 32) }
     :label{ text = "A preset with the same name will be replaced." }
     :button{ id = "ok", text = "Add", focus = true }
     :button{ id = "cancel", text = "Cancel" }
     :show()

  local d = add.data
  if not d.ok then return end

  -- Commas separate the fields in the preset file, so keep them out of names
  local name = d.name:gsub("%s*,%s*", " "):match("^%s*(.-)%s*$")
  local w, h = math.floor(d.w), math.floor(d.h)
  if name == "" then
    app.alert("Please enter a name.")
    return
  end
  -- Lines starting with # are comments in the preset file
  if name:find("^#") then
    app.alert("Names can't start with #.")
    return
  end
  if not validSize(w, h) then
    app.alert("Width and height must be between 1 and 65535.")
    return
  end

  local p = { name = name, w = w, h = h }
  local replaced = false
  for i, old in ipairs(presets) do
    if old.name == name then
      presets[i] = p
      replaced = true
      break
    end
  end
  if not replaced then
    table.insert(presets, p)
  end
  savePresets()
  refreshList(labelOf(p))
end

local function removePreset()
  local i, p = findByLabel(dlg.data.preset)
  if not i then return end
  local answer = app.alert{
    title = "Remove Preset",
    text = ("Remove \"%s\"?"):format(labelOf(p)),
    buttons = { "Remove", "Cancel" },
  }
  if answer ~= 1 then return end
  table.remove(presets, i)
  savePresets()
  local next = presets[math.min(i, #presets)]
  refreshList(next and labelOf(next) or "")
end

dlg = Dialog("New Sprite from Preset")
dlg:combobox{ id = "preset", label = "Size", options = labels() }
   :button{ text = "Add...", onclick = addPreset }
   :button{ text = "Remove", onclick = removePreset }
   :separator()
   :combobox{ id = "mode", label = "Color Mode", option = "RGB", options = { "RGB", "Grayscale", "Indexed" } }
   :combobox{ id = "bg", label = "Background", option = "Transparent", options = { "Transparent", "White", "Background Color" } }
   :separator()
   :button{ id = "ok", text = "Create", focus = true }
   :button{ id = "cancel", text = "Cancel" }
   :show()

local data = dlg.data
if not data.ok then return end

local _, preset = findByLabel(data.preset)
if not preset then
  app.alert("Please select a preset.")
  return
end

createSprite(preset, data.mode, data.bg)
