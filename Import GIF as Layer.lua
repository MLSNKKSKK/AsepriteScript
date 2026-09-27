-- Import GIF as Layer
-- Imports a GIF animation into the open sprite.
-- * A new layer is created right above the active layer (named after the GIF file).
-- * When importing into the active layer, the GIF is drawn on top of the existing art.
-- * The GIF's first frame goes on the current frame (or frame 1), and the rest follow.
-- * Missing frames are added at the end, using the GIF's frame durations.
-- * Besides actual size, the GIF can be resized to the canvas
--   (Fit = may leave empty space / Fill = no empty space, but may extend past the canvas).
-- * A single Ctrl+Z undoes the whole import.

local target = app.sprite
if not target then
  app.alert("No sprite is open.")
  return
end

if target.colorMode ~= ColorMode.RGB then
  app.alert("This script only works with RGB sprites.")
  return
end

local SIZE_ACTUAL = "Actual Size"
local SIZE_FIT = "Fit to Canvas (keep aspect ratio)"
local SIZE_COVER = "Fill Canvas (keep aspect ratio, no empty space)"
local SIZE_STRETCH = "Stretch to Canvas"

local METHODS = {
  ["Nearest Neighbor (for pixel art)"] = "nearest",
  ["Bilinear (smooth)"] = "bilinear",
}

local DEST_NEW = "New Layer"
local DEST_CURRENT = "Active Layer (draw on top)"

local opts = {
  file = "",
  dest = DEST_NEW,
  start = "Current Frame",
  size = SIZE_ACTUAL,
  method = "Nearest Neighbor (for pixel art)",
  place = "Center",
  addFrames = true,
  matchDurations = false,
}

-- Without a UI (command-line run), pass the GIF with --script-param file=...
-- (dest=current, size=fit / size=cover / size=stretch and method=bilinear are also accepted)
if app.isUIAvailable then
  local dlg = Dialog("Import GIF as Layer")
  dlg:file{ id = "file", label = "GIF File", open = true, filetypes = { "gif" } }
     :combobox{ id = "dest", label = "Import Into", option = opts.dest, options = { DEST_NEW, DEST_CURRENT } }
     :combobox{ id = "start", label = "Start At", option = opts.start, options = { "Current Frame", "Frame 1" } }
     :combobox{
       id = "size", label = "Size", option = opts.size,
       options = { SIZE_ACTUAL, SIZE_FIT, SIZE_COVER, SIZE_STRETCH },
       onchange = function()
         local scaled = dlg.data.size ~= SIZE_ACTUAL
         dlg:modify{ id = "method", enabled = scaled }
         dlg:modify{ id = "place", enabled = dlg.data.size ~= SIZE_STRETCH }
       end,
     }
     :combobox{
       id = "method", label = "Resize Method", option = opts.method,
       options = { "Nearest Neighbor (for pixel art)", "Bilinear (smooth)" },
       enabled = false,
     }
     :combobox{ id = "place", label = "Position", option = opts.place, options = { "Center", "Top Left" } }
     :check{ id = "addFrames", text = "Add frames if the sprite runs out", selected = opts.addFrames }
     :check{ id = "matchDurations", text = "Also match existing frame durations to the GIF", selected = opts.matchDurations }
     :button{ id = "ok", text = "Import", focus = true }
     :button{ id = "cancel", text = "Cancel" }
     :show()
  if not dlg.data.ok then return end
  opts = dlg.data
else
  opts.file = app.params.file or ""
  if app.params.dest == "current" then opts.dest = DEST_CURRENT end
  if app.params.size == "fit" then opts.size = SIZE_FIT end
  if app.params.size == "cover" then opts.size = SIZE_COVER end
  if app.params.size == "stretch" then opts.size = SIZE_STRETCH end
  if app.params.method == "bilinear" then opts.method = "Bilinear (smooth)" end
end

if opts.file == "" or not app.fs.isFile(opts.file) then
  app.alert("Please choose a GIF file.")
  return
end

local src = app.layer
if opts.dest == DEST_CURRENT
  and (not src or src.isGroup or src.isTilemap or src.isReference or not src.isEditable) then
  app.alert("To import into the active layer, select a regular layer that isn't locked.")
  return
end

local startFrame = 1
if opts.start == "Current Frame" and app.frame then
  startFrame = app.frame.frameNumber
end

-- Open the GIF as a separate sprite, turn each frame into an RGB image, then close it
local gif = Sprite{ fromFile = opts.file }
if not gif then
  app.alert("Could not load the GIF:\n" .. opts.file)
  return
end

-- Work out the size after import
local w, h = gif.width, gif.height
if opts.size == SIZE_FIT then
  local scale = math.min(target.width / w, target.height / h)
  w = math.max(1, math.floor(w * scale + 0.5))
  h = math.max(1, math.floor(h * scale + 0.5))
elseif opts.size == SIZE_COVER then
  -- Scale until the shorter side matches the canvas. The overflow stays outside the canvas
  local scale = math.max(target.width / w, target.height / h)
  w = math.max(target.width, math.floor(w * scale + 0.5))
  h = math.max(target.height, math.floor(h * scale + 0.5))
elseif opts.size == SIZE_STRETCH then
  w, h = target.width, target.height
end
local resize = (w ~= gif.width or h ~= gif.height)

local frames = {}
for i, fr in ipairs(gif.frames) do
  local img = Image(gif.width, gif.height, ColorMode.RGB)
  img:drawSprite(gif, i, Point(0, 0))
  if resize then
    img:resize{ width = w, height = h, method = METHODS[opts.method] }
  end
  table.insert(frames, { image = img, duration = fr.duration })
end
gif:close()
app.sprite = target

local pos = Point(0, 0)
if opts.place == "Center" then
  pos = Point((target.width - w) // 2, (target.height - h) // 2)
end

local skippedFrames = 0

-- If a cel already exists, draw the GIF frame on top of its art
local function drawOnto(layer, n, img, linkedIds)
  local cel = layer:cel(n)
  if not cel and not layer.isBackground then
    target:newCel(layer, n, img, pos)
    return
  end

  local bounds
  if layer.isBackground then
    bounds = Rectangle(0, 0, target.width, target.height)
  else
    bounds = cel.bounds:union(Rectangle(pos.x, pos.y, img.width, img.height))
  end
  local merged = Image(bounds.width, bounds.height, ColorMode.RGB)
  if cel then
    merged:drawImage(cel.image, Point(cel.position.x - bounds.x, cel.position.y - bounds.y))
  end
  merged:drawImage(img, Point(pos.x - bounds.x, pos.y - bounds.y))
  local origin = Point(bounds.x, bounds.y)

  if cel and not linkedIds[cel.image.id] then
    cel.image = merged
    cel.position = origin
  else
    -- Linked cels share one image, so editing it in place would change other frames too.
    -- Recreate just this frame's cel instead
    local opacity = cel and cel.opacity or 255
    if cel then target:deleteCel(cel) end
    target:newCel(layer, n, merged, origin).opacity = opacity
  end
end

app.transaction("Import GIF as Layer", function()
  local layer
  local linkedIds = {}
  if opts.dest == DEST_CURRENT then
    layer = src
    local seen = {}
    for _, cel in ipairs(layer.cels) do
      local id = cel.image.id
      if seen[id] then linkedIds[id] = true end
      seen[id] = true
    end
  else
    layer = target:newLayer()
    layer.name = app.fs.fileTitle(opts.file)
    if src then
      layer.parent = src.parent
      layer.stackIndex = src.stackIndex + 1
    end
  end

  for i, f in ipairs(frames) do
    local n = startFrame + i - 1
    if n > #target.frames then
      if not opts.addFrames then
        skippedFrames = #frames - i + 1
        break
      end
      target:newEmptyFrame(n).duration = f.duration
    elseif opts.matchDurations then
      target.frames[n].duration = f.duration
    end
    if not f.image:isEmpty() then
      if opts.dest == DEST_CURRENT then
        drawOnto(layer, n, f.image, linkedIds)
      else
        target:newCel(layer, n, f.image, pos)
      end
    end
  end

  app.layer = layer
  app.frame = target.frames[startFrame]
end)

app.refresh()

if skippedFrames > 0 then
  app.alert(("The sprite ran out of frames, so the last %d frame(s) of the GIF were not imported."):format(skippedFrames))
end
