-- 全レイヤー・全フレームの指定した色を別の色に置き換える
-- ・グループの中や非表示のレイヤーも対象
-- ・ロック中・タイルマップ・参照レイヤーは対象外
-- ・元のピクセルの透明度は残す(置き換え後の色が半透明なら、その分だけ薄くなる)
-- ・1回の Ctrl+Z で元に戻せる

local sprite = app.sprite
if not sprite then
  app.alert("スプライトが開かれていません。")
  return
end

if sprite.colorMode ~= ColorMode.RGB then
  app.alert("RGB モードのスプライトにだけ使えます。")
  return
end

local opts = {
  from = app.fgColor,
  to = app.bgColor,
  tolerance = 0,
}

-- UI なし(コマンドライン実行)のときは既定値のまま実行する
if app.isUIAvailable then
  local dlg = Dialog("全レイヤーの色を置き換え")
  dlg:color{ id = "from", label = "置き換える色", color = opts.from }
     :color{ id = "to", label = "新しい色", color = opts.to }
     :slider{ id = "tolerance", label = "許容範囲", min = 0, max = 255, value = opts.tolerance }
     :label{ text = "0 だと完全に同じ色だけを置き換えます" }
     :button{ id = "ok", text = "置き換え", focus = true }
     :button{ id = "cancel", text = "キャンセル" }
     :show()
  if not dlg.data.ok then return end
  opts = dlg.data
end

-- 対象レイヤーを集める(グループは中身を展開)
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

-- 置き換えたピクセル数を返す
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

app.transaction("全レイヤーの色を置き換え", function()
  local done = {} -- リンクセルは同じ画像を共有しているので1回だけ処理する
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

local msg = ("%d ピクセルを置き換えました。"):format(total)
if skipped > 0 then
  msg = msg .. ("(%d レイヤーはロック中・タイルマップ・参照レイヤーのため飛ばしました)"):format(skipped)
end
if app.isUIAvailable then
  app.alert(msg)
else
  print(msg)
end
