-- Replace Color in All Layers
-- Replaces one color with another in every layer and every frame.
-- * Layers inside groups and hidden layers are included.
-- * Locked, tilemap and reference layers are skipped.
-- * Each pixel keeps its original alpha (if the new color is semi-transparent,
--   the pixel gets that much more transparent).
-- * A single Ctrl+Z undoes the whole replacement.

local sprite = app.sprite
if not sprite then
  app.alert("No sprite is open.")
  return
end

if sprite.colorMode ~= ColorMode.RGB then
  app.alert("This script only works with RGB sprites.")
  return
end

local opts = {
  from = app.fgColor,
  to = app.bgColor,
  tolerance = 0,
}

-- Without a UI (command-line run), use the defaults as they are
if app.isUIAvailable then
  local dlg = Dialog("Replace Color in All Layers")
  dlg:color{ id = "from", label = "From", color = opts.from }
     :color{ id = "to", label = "To", color = opts.to }
     :slider{ id = "tolerance", label = "Tolerance", min = 0, max = 255, value = opts.tolerance }
     :label{ text = "At 0, only the exact color is replaced." }
     :button{ id = "ok", text = "Replace", focus = true }
     :button{ id = "cancel", text = "Cancel" }
     :show()
  if not dlg.data.ok then return end
  opts = dlg.data
end

-- Collect the target layers (looking inside groups)
local targets = {}
local skipped = 0

local function collect(layers)
  for _, layer in ipairs(layers) do
    if layer.isGroup then
      collect(layer.layers)
    elseif layer.isTilemap or layer.isReference or not layer.isEditable then
      skipped = skipped + 1
    else
      table.insert(targets, layer)
    end
  end
end
collect(sprite.layers)

local pc = app.pixelColor
local rgba, rOf, gOf, bOf, aOf = pc.rgba, pc.rgbaR, pc.rgbaG, pc.rgbaB, pc.rgbaA
local fr, fg, fb = opts.from.red, opts.from.green, opts.from.blue
local tr, tg, tb, ta = opts.to.red, opts.to.green, opts.to.blue, opts.to.alpha
local tol = opts.tolerance

-- Returns the number of pixels replaced
local function replace(img)
  local count = 0
  for it in img:pixels() do
    local px = it()
    local a = aOf(px)
    if a > 0
      and math.abs(rOf(px) - fr) <= tol
      and math.abs(gOf(px) - fg) <= tol
      and math.abs(bOf(px) - fb) <= tol then
      it(rgba(tr, tg, tb, a * ta // 255))
      count = count + 1
    end
  end
  return count
end

local total = 0

app.transaction("Replace Color in All Layers", function()
  local done = {} -- Linked cels share one image, so process each image only once
  for _, layer in ipairs(targets) do
    for _, cel in ipairs(layer.cels) do
      local id = cel.image.id
      if not done[id] then
        done[id] = true
        local img = cel.image:clone()
        local n = replace(img)
        if n > 0 then
          cel.image = img
          total = total + n
        end
      end
    end
  end
end)

app.refresh()

local msg = ("Replaced %d pixel(s)."):format(total)
if skipped > 0 then
  msg = msg .. (" (Skipped %d locked, tilemap or reference layer(s).)"):format(skipped)
end
if app.isUIAvailable then
  app.alert(msg)
else
  print(msg)
end
