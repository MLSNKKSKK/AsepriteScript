-- 登録しておいたキャンバスサイズを選んで新規スプライトを作る
-- ・プリセットはダイアログの「追加...」「削除」で管理できる
-- ・プリセットは Aseprite の設定フォルダの canvas_presets.txt に保存される
--   (1行に「名前,幅,高さ」。テキストエディタで直接書き換えてもよい)

local PRESET_FILE = app.fs.joinPath(app.fs.userConfigPath, "canvas_presets.txt")

-- ファイルがまだないときに登録しておくプリセット
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
    app.alert("プリセットを保存できませんでした:\n" .. PRESET_FILE)
    return
  end
  f:write("# 名前,幅,高さ (1行に1つ)\n")
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
      -- Aseprite で作れないサイズ(手で書き換えたときの打ち間違いなど)は読み飛ばす
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
  ["グレースケール"] = ColorMode.GRAYSCALE,
  ["インデックス"] = ColorMode.INDEXED,
}

-- インデックス画像はパレット番号で色を持つので、いちばん近い色の番号を探す
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
  -- スクリプトで作ったスプライトはパレットが全部黒なので、ファイル > 新規作成 と同じく
  -- デフォルトパレットを使う(グレースケールは最初から灰色の階調になっている)
  if mode ~= ColorMode.GRAYSCALE and app.defaultPalette then
    sprite:setPalette(app.defaultPalette)
  end
  if bgName ~= "透明" then
    local color = (bgName == "白") and Color{ r = 255, g = 255, b = 255 } or app.bgColor
    -- 先に背景レイヤーにしてから塗ると、選んだ色がそのまま使われる
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

-- UI なし(コマンドライン実行)のときは最初のプリセットで作る
if not app.isUIAvailable then
  if #presets > 0 then
    createSprite(presets[1], "RGB", "透明")
    print(("%s で作成しました。"):format(labelOf(presets[1])))
  end
  return
end

local dlg

local function refreshList(selectLabel)
  dlg:modify{ id = "preset", options = labels(), option = selectLabel }
end

local function addPreset()
  local current = select(2, findByLabel(dlg.data.preset))
  local add = Dialog("プリセットを追加")
  add:entry{ id = "name", label = "名前", text = "" }
     :number{ id = "w", label = "幅", decimals = 0, text = tostring(current and current.w or 32) }
     :number{ id = "h", label = "高さ", decimals = 0, text = tostring(current and current.h or 32) }
     :label{ text = "同じ名前があれば上書きします" }
     :button{ id = "ok", text = "追加", focus = true }
     :button{ id = "cancel", text = "キャンセル" }
     :show()

  local d = add.data
  if not d.ok then return end

  local name = d.name:gsub(",", "、"):match("^%s*(.-)%s*$")
  local w, h = math.floor(d.w), math.floor(d.h)
  if name == "" then
    app.alert("名前を入れてください。")
    return
  end
  -- プリセットファイルでは # で始まる行はコメントになる
  if name:find("^#") then
    app.alert("名前の先頭に # は使えません。")
    return
  end
  if not validSize(w, h) then
    app.alert("幅と高さは 1〜65535 にしてください。")
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
    title = "プリセットを削除",
    text = ("「%s」を削除しますか?"):format(labelOf(p)),
    buttons = { "削除", "キャンセル" },
  }
  if answer ~= 1 then return end
  table.remove(presets, i)
  savePresets()
  local next = presets[math.min(i, #presets)]
  refreshList(next and labelOf(next) or "")
end

dlg = Dialog("プリセットから新規作成")
dlg:combobox{ id = "preset", label = "サイズ", options = labels() }
   :button{ text = "追加...", onclick = addPreset }
   :button{ text = "削除", onclick = removePreset }
   :separator()
   :combobox{ id = "mode", label = "カラーモード", option = "RGB", options = { "RGB", "グレースケール", "インデックス" } }
   :combobox{ id = "bg", label = "背景", option = "透明", options = { "透明", "白", "背景色" } }
   :separator()
   :button{ id = "ok", text = "作成", focus = true }
   :button{ id = "cancel", text = "キャンセル" }
   :show()

local data = dlg.data
if not data.ok then return end

local _, preset = findByLabel(data.preset)
if not preset then
  app.alert("プリセットを選んでください。")
  return
end

createSprite(preset, data.mode, data.bg)
