-- 指定した GIF アニメーションを、開いているスプライトに読み込む
-- ・新規レイヤーはアクティブなレイヤーのすぐ上に作る(名前は GIF のファイル名)
-- ・選択中のレイヤーに読み込むときは、今ある絵の上に重ねる
-- ・GIF の1フレーム目を、今いるフレーム(または1フレーム目)から並べる
-- ・フレームが足りなければ後ろに追加し、長さは GIF のフレームに合わせる
-- ・ピクセル等倍のほか、キャンバスサイズに合わせて拡大縮小もできる
--   (収める=余白が出ることがある / 埋める=余白は出ないがはみ出す)
-- ・1回の Ctrl+Z で元に戻せる

local target = app.sprite
if not target then
  app.alert("スプライトが開かれていません。")
  return
end

if target.colorMode ~= ColorMode.RGB then
  app.alert("RGB モードのスプライトにだけ使えます。")
  return
end

local SIZE_ACTUAL = "ピクセル等倍"
local SIZE_FIT = "キャンバスに収める(縦横比を保つ)"
local SIZE_COVER = "キャンバスを埋める(縦横比を保つ・余白なし)"
local SIZE_STRETCH = "キャンバスに引き伸ばす"

local METHODS = {
  ["ニアレストネイバー(ドット絵向け)"] = "nearest",
  ["バイリニア(なめらか)"] = "bilinear",
}

local DEST_NEW = "新規レイヤー"
local DEST_CURRENT = "選択中のレイヤー(上に重ねる)"

local opts = {
  file = "",
  dest = DEST_NEW,
  start = "今のフレームから",
  size = SIZE_ACTUAL,
  method = "ニアレストネイバー(ドット絵向け)",
  place = "中央",
  addFrames = true,
  matchDurations = false,
}

-- UI なし(コマンドライン実行)のときは --script-param file=... で GIF を指定する
-- (dest=current、size=fit / size=cover / size=stretch、method=bilinear も指定できる)
if app.isUIAvailable then
  local dlg = Dialog("GIF をレイヤーとして読み込み")
  dlg:file{ id = "file", label = "GIF ファイル", open = true, filetypes = { "gif" } }
     :combobox{ id = "dest", label = "読み込み先", option = opts.dest, options = { DEST_NEW, DEST_CURRENT } }
     :combobox{ id = "start", label = "開始位置", option = opts.start, options = { "今のフレームから", "1フレーム目から" } }
     :combobox{
       id = "size", label = "サイズ", option = opts.size,
       options = { SIZE_ACTUAL, SIZE_FIT, SIZE_COVER, SIZE_STRETCH },
       onchange = function()
         local scaled = dlg.data.size ~= SIZE_ACTUAL
         dlg:modify{ id = "method", enabled = scaled }
         dlg:modify{ id = "place", enabled = dlg.data.size ~= SIZE_STRETCH }
       end,
     }
     :combobox{
       id = "method", label = "拡大縮小の方法", option = opts.method,
       options = { "ニアレストネイバー(ドット絵向け)", "バイリニア(なめらか)" },
       enabled = false,
     }
     :combobox{ id = "place", label = "配置", option = opts.place, options = { "中央", "左上" } }
     :check{ id = "addFrames", text = "フレームが足りなければ追加する", selected = opts.addFrames }
     :check{ id = "matchDurations", text = "既存フレームの長さも GIF に合わせる", selected = opts.matchDurations }
     :button{ id = "ok", text = "読み込み", focus = true }
     :button{ id = "cancel", text = "キャンセル" }
     :show()
  if not dlg.data.ok then return end
  opts = dlg.data
else
  opts.file = app.params.file or ""
  if app.params.dest == "current" then opts.dest = DEST_CURRENT end
  if app.params.size == "fit" then opts.size = SIZE_FIT end
  if app.params.size == "cover" then opts.size = SIZE_COVER end
  if app.params.size == "stretch" then opts.size = SIZE_STRETCH end
  if app.params.method == "bilinear" then opts.method = "バイリニア(なめらか)" end
end

if opts.file == "" or not app.fs.isFile(opts.file) then
  app.alert("GIF ファイルを選んでください。")
  return
end

local src = app.layer
if opts.dest == DEST_CURRENT
  and (not src or src.isGroup or src.isTilemap or src.isReference or not src.isEditable) then
  app.alert("読み込み先には、ロックされていない普通のレイヤーを選んでください。")
  return
end

local startFrame = 1
if opts.start == "今のフレームから" and app.frame then
  startFrame = app.frame.frameNumber
end

-- GIF を別スプライトとして開き、各フレームを RGB 画像にしてから閉じる
local gif = Sprite{ fromFile = opts.file }
if not gif then
  app.alert("GIF を読み込めませんでした:\n" .. opts.file)
  return
end

-- 読み込み後のサイズを決める
local w, h = gif.width, gif.height
if opts.size == SIZE_FIT then
  local scale = math.min(target.width / w, target.height / h)
  w = math.max(1, math.floor(w * scale + 0.5))
  h = math.max(1, math.floor(h * scale + 0.5))
elseif opts.size == SIZE_COVER then
  -- 足りない方の辺をキャンバスに合わせる。はみ出した分はキャンバスの外に残る
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
if opts.place == "中央" then
  pos = Point((target.width - w) // 2, (target.height - h) // 2)
end

local skippedFrames = 0

-- 既存のセルがあれば、その絵の上に GIF のフレームを重ねる
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
    -- リンクセルは画像を共有しているので、そのまま書き換えると他のフレームまで変わる。
    -- このフレームのセルだけを作り直す
    local opacity = cel and cel.opacity or 255
    if cel then target:deleteCel(cel) end
    target:newCel(layer, n, merged, origin).opacity = opacity
  end
end

app.transaction("GIF をレイヤーとして読み込み", function()
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
  app.alert(("フレームが足りないため、GIF の最後の %d フレームは読み込みませんでした。"):format(skippedFrames))
end
