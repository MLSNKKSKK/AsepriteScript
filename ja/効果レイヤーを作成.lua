-- 選択中のレイヤーの上に「効果レイヤー」を作る
-- ・選択中のレイヤーの不透明ピクセルと同じ範囲を、選んだ色で塗りつぶす
-- ・乗算などのレイヤーモードで、下のレイヤーに効果をかける
-- ・全フレーム分を作る。1回の Ctrl+Z で元に戻せる

local sprite = app.sprite
if not sprite then
  app.alert("スプライトが開かれていません。")
  return
end

if sprite.colorMode ~= ColorMode.RGB then
  app.alert("RGB モードのスプライトにだけ使えます。")
  return
end

local src = app.layer
if not src or src.isGroup or src.isTilemap then
  app.alert("普通のレイヤーを1つ選んでください(グループとタイルマップには使えません)。")
  return
end

local MODES = {
  { "乗算", BlendMode.MULTIPLY },
  { "スクリーン", BlendMode.SCREEN },
  { "オーバーレイ", BlendMode.OVERLAY },
  { "ソフトライト", BlendMode.SOFT_LIGHT },
  { "ハードライト", BlendMode.HARD_LIGHT },
  { "覆い焼き", BlendMode.COLOR_DODGE },
  { "焼き込み", BlendMode.COLOR_BURN },
  { "加算", BlendMode.ADDITION },
  { "減算", BlendMode.SUBTRACT },
  { "比較(暗)", BlendMode.DARKEN },
  { "比較(明)", BlendMode.LIGHTEN },
  { "差の絶対値", BlendMode.DIFFERENCE },
  { "除外", BlendMode.EXCLUSION },
  { "除算", BlendMode.DIVIDE },
  { "色相", BlendMode.HUE },
  { "彩度", BlendMode.SATURATION },
  { "カラー", BlendMode.COLOR },
  { "輝度", BlendMode.LUMINOSITY },
  { "通常", BlendMode.NORMAL },
}

local modeNames, modeByName = {}, {}
for _, m in ipairs(MODES) do
  table.insert(modeNames, m[1])
  modeByName[m[1]] = m[2]
end

local opts = {
  color = app.fgColor,
  mode = "乗算",
  opacity = 255,
  keepAlpha = true,
}

-- UI なし(コマンドライン実行)のときは既定値のまま作る
if app.isUIAvailable then
  local dlg = Dialog("効果レイヤーを作成")
  dlg:color{ id = "color", label = "色", color = opts.color }
     :combobox{ id = "mode", label = "レイヤーモード", option = opts.mode, options = modeNames }
     :slider{ id = "opacity", label = "不透明度", min = 0, max = 255, value = opts.opacity }
     :check{ id = "keepAlpha", text = "元レイヤーの半透明を反映する", selected = opts.keepAlpha }
     :button{ id = "ok", text = "作成", focus = true }
     :button{ id = "cancel", text = "キャンセル" }
     :show()
  if not dlg.data.ok then return end
  opts = dlg.data
end

local pc = app.pixelColor
local rgba, aOf = pc.rgba, pc.rgbaA
local c = opts.color
local cr, cg, cb, ca = c.red, c.green, c.blue, c.alpha

-- 元のセル画像の不透明ピクセルだけを色で塗った画像を作る
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

app.transaction("効果レイヤーを作成", function()
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
