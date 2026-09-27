-- Create Effect Layer
-- Creates an "effect layer" right above the active layer.
-- * Fills the same area as the active layer's opaque pixels with the chosen color.
-- * Uses a blend mode such as Multiply to apply the effect to the layer below.
-- * Covers every frame. A single Ctrl+Z undoes it.

local sprite = app.sprite
if not sprite then
  app.alert("No sprite is open.")
  return
end

if sprite.colorMode ~= ColorMode.RGB then
  app.alert("This script only works with RGB sprites.")
  return
end

local src = app.layer
if not src or src.isGroup or src.isTilemap then
  app.alert("Please select a single regular layer (groups and tilemaps aren't supported).")
  return
end

local MODES = {
  { "Multiply", BlendMode.MULTIPLY },
  { "Screen", BlendMode.SCREEN },
  { "Overlay", BlendMode.OVERLAY },
  { "Soft Light", BlendMode.SOFT_LIGHT },
  { "Hard Light", BlendMode.HARD_LIGHT },
  { "Color Dodge", BlendMode.COLOR_DODGE },
  { "Color Burn", BlendMode.COLOR_BURN },
  { "Addition", BlendMode.ADDITION },
  { "Subtract", BlendMode.SUBTRACT },
  { "Darken", BlendMode.DARKEN },
  { "Lighten", BlendMode.LIGHTEN },
  { "Difference", BlendMode.DIFFERENCE },
  { "Exclusion", BlendMode.EXCLUSION },
  { "Divide", BlendMode.DIVIDE },
  { "Hue", BlendMode.HUE },
  { "Saturation", BlendMode.SATURATION },
  { "Color", BlendMode.COLOR },
  { "Luminosity", BlendMode.LUMINOSITY },
  { "Normal", BlendMode.NORMAL },
}

local modeNames, modeByName = {}, {}
for _, m in ipairs(MODES) do
  table.insert(modeNames, m[1])
  modeByName[m[1]] = m[2]
end

local opts = {
  color = app.fgColor,
  mode = "Multiply",
  opacity = 255,
  keepAlpha = true,
}

-- Without a UI (command-line run), create it with the defaults
if app.isUIAvailable then
  local dlg = Dialog("Create Effect Layer")
  dlg:color{ id = "color", label = "Color", color = opts.color }
     :combobox{ id = "mode", label = "Blend Mode", option = opts.mode, options = modeNames }
     :slider{ id = "opacity", label = "Opacity", min = 0, max = 255, value = opts.opacity }
     :check{ id = "keepAlpha", text = "Match the source layer's transparency", selected = opts.keepAlpha }
     :button{ id = "ok", text = "Create", focus = true }
     :button{ id = "cancel", text = "Cancel" }
     :show()
  if not dlg.data.ok then return end
  opts = dlg.data
end

local pc = app.pixelColor
local rgba, aOf = pc.rgba, pc.rgbaA
local c = opts.color
local cr, cg, cb, ca = c.red, c.green, c.blue, c.alpha

-- Build an image with only the source cel's opaque pixels filled with the color
local function makeMask(srcImg)
  local img = Image(srcImg.width, srcImg.height, ColorMode.RGB)
  for it in srcImg:pixels() do
    local a = aOf(it())
    if a > 0 then
      if opts.keepAlpha then
        a = a * ca // 255
      else
        a = ca
      end
      img:drawPixel(it.x, it.y, rgba(cr, cg, cb, a))
    end
  end
  return img
end

app.transaction("Create Effect Layer", function()
  local layer = sprite:newLayer()
  layer.name = opts.mode .. " (" .. src.name .. ")"
  layer.parent = src.parent
  layer.stackIndex = src.stackIndex + 1
  layer.blendMode = modeByName[opts.mode]
  layer.opacity = opts.opacity

  for _, cel in ipairs(src.cels) do
    sprite:newCel(layer, cel.frameNumber, makeMask(cel.image), cel.position)
  end

  app.layer = layer
end)

app.refresh()
