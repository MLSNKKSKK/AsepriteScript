-- ベジェ曲線で、キャンバス上で直接、あとから編集できる線を引く
-- ・キャンバスをクリックして点を追加し、点やハンドルをドラッグして曲げる。
--   色・太さ・確定/キャンセルのボタンは小さなパネルにある
-- ・線は選択中のレイヤーのすぐ上の「曲線レイヤー」に描かれる。
--   曲線レイヤーを選んでもう一度実行すると、線を編集できる
-- ・曲線のデータはセルに保存されるので、.aseprite ファイルに残る。
--   フレームごとに別の線を持てる。確定は1回の Ctrl+Z で元に戻せる

local KEY = "asepritescript/bezier-curve"
local TITLE = "ベジェ曲線"
local SESSION = KEY .. "/session"   -- 編集中だけ設定するグローバル
local PANEL_BOUNDS = KEY .. "/panel"  -- 前回のパネルの位置

if not app.apiVersion or app.apiVersion < 24 then
  app.alert("このスクリプトには Aseprite v1.3 以降が必要です。")
  return
end

-- 編集には画面が必要なので、UI なしのときは何もしない
if not app.isUIAvailable then return end

-- 同時に編集できるのは1つだけ
local running = rawget(_G, SESSION)
if running then
  local r = app.alert{ title = TITLE,
    text = "すでにベジェ曲線を編集中です。先にパネルで確定かキャンセルをしてください。",
    buttons = { "OK", "今すぐ確定する" } }
  if r == 2 then
    pcall(running.finish, true, false)
    rawset(_G, SESSION, nil)
  end
  return
end

local sprite = app.sprite
if not sprite then
  app.alert("スプライトが開かれていません。")
  return
end

local editor = app.editor
if not editor or editor.sprite ~= sprite then
  app.alert("スプライトを編集画面に表示してから、もう一度実行してください。")
  return
end

local frameNumber = app.frame and app.frame.frameNumber or 1
local src = app.layer

-- (強制終了などで)残った一時的なガイドレイヤーには描かない
if src and src.properties(KEY).guide == true then src = nil end

local curveLayer = nil
if src and src.isImage and not src.isTilemap and src.properties(KEY).curve == true then
  curveLayer = src
end
if curveLayer and not curveLayer.isEditable then
  app.alert("曲線レイヤーがロックされています。ロックを外してから、もう一度実行してください。")
  return
end

local pc = app.pixelColor
local floor, sqrt, abs = math.floor, math.sqrt, math.abs

local function round(v) return floor(v + 0.5) end

------------------------------------------------------------------------
-- 曲線のデータ
--
-- 線(path)は点(node)の並び。点はピクセルの位置 (x, y) と、そこからの差で表した
-- 2本のハンドルを持つ。「in」ハンドル (ix, iy) は点に入ってくる側の曲がり、
-- 「out」ハンドル (ox, oy) は点から出ていく側の曲がりを決める。
-- なめらかな点(smooth)は、2本のハンドルを一直線に保つ。

local function colorToTable(c)
  return { r = c.red, g = c.green, b = c.blue, a = c.alpha, index = c.index }
end

local function tableToColor(t)
  if sprite.colorMode == ColorMode.INDEXED then return Color(t.index) end
  return Color{ r = t.r, g = t.g, b = t.b, a = t.a }
end

local function serialize(paths)
  -- ハンドルは小数第2位まで保存する
  local function h(v) return round(v * 100) / 100 end
  local lines = {}
  for _, p in ipairs(paths) do
    local c = p.color
    lines[#lines + 1] = string.format("path %d %d %d %d %d %d %d %d",
      c.r, c.g, c.b, c.a, c.index, p.width, p.closed and 1 or 0, p.pixelPerfect and 1 or 0)
    for _, n in ipairs(p.nodes) do
      lines[#lines + 1] = string.format("node %d %d %.2f %.2f %.2f %.2f %d",
        n.x, n.y, h(n.ix), h(n.iy), h(n.ox), h(n.oy), n.smooth and 1 or 0)
    end
  end
  return table.concat(lines, "\n")
end

local function parse(text)
  local paths, cur = {}, nil
  for line in text:gmatch("[^\n]+") do
    local v = {}
    for w in line:gmatch("%S+") do v[#v + 1] = w end
    local function num(i) return tonumber(v[i]) or 0 end
    if v[1] == "path" then
      cur = {
        color = { r = floor(num(2)), g = floor(num(3)), b = floor(num(4)), a = floor(num(5)), index = floor(num(6)) },
        width = math.max(1, floor(num(7))),
        closed = num(8) == 1,
        pixelPerfect = num(9) == 1,
        nodes = {},
      }
      paths[#paths + 1] = cur
    elseif v[1] == "node" and cur then
      cur.nodes[#cur.nodes + 1] = {
        x = floor(num(2)), y = floor(num(3)),
        ix = num(4), iy = num(5), ox = num(6), oy = num(7),
        smooth = num(8) == 1,
      }
    end
  end
  for i = #paths, 1, -1 do
    if #paths[i].nodes == 0 then table.remove(paths, i) end
  end
  return paths
end

-- 線の区間を { 点A, 点B, Aの番号 } の並びで返す
local function segments(p)
  local list, nodes = {}, p.nodes
  for i = 1, #nodes - 1 do list[#list + 1] = { nodes[i], nodes[i + 1], i } end
  if p.closed and #nodes > 1 then list[#list + 1] = { nodes[#nodes], nodes[1], #nodes } end
  return list
end

-- 点 a と b の間の曲線上で、t (0〜1) の位置
local function bezier(a, b, t)
  local u = 1 - t
  local k0, k1, k2, k3 = u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t
  return k0 * a.x + k1 * (a.x + a.ox) + k2 * (b.x + b.ix) + k3 * b.x,
         k0 * a.y + k1 * (a.y + a.oy) + k2 * (b.y + b.iy) + k3 * b.y
end

local function dist(x0, y0, x1, y1)
  return sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
end

------------------------------------------------------------------------
-- 線をピクセルとして描く

-- 線をたどり、通るピクセルを順に返す。
-- 隣り合うピクセルは必ず接している。
local function tracePath(p)
  local xs, ys = {}, {}
  local function add(x, y)
    local n = #xs
    if n > 0 then
      local lx, ly = xs[n], ys[n]
      if lx == x and ly == y then return end
      -- すき間は直線で埋める
      local dx, dy = abs(x - lx), abs(y - ly)
      if dx > 1 or dy > 1 then
        local sx, sy = x > lx and 1 or -1, y > ly and 1 or -1
        local err, cx, cy = dx - dy, lx, ly
        while true do
          local e2 = 2 * err
          if e2 > -dy then err = err - dy; cx = cx + sx end
          if e2 < dx then err = err + dx; cy = cy + sy end
          if cx == x and cy == y then break end
          xs[#xs + 1], ys[#ys + 1] = cx, cy
        end
      end
    end
    xs[#xs + 1], ys[#ys + 1] = x, y
  end

  add(p.nodes[1].x, p.nodes[1].y)
  for _, s in ipairs(segments(p)) do
    local a, b = s[1], s[2]
    local len = dist(a.x, a.y, a.x + a.ox, a.y + a.oy)
              + dist(a.x + a.ox, a.y + a.oy, b.x + b.ix, b.y + b.iy)
              + dist(b.x + b.ix, b.y + b.iy, b.x, b.y)
    local steps = math.max(1, math.ceil(len * 2))
    for i = 1, steps do
      local x, y = bezier(a, b, i / steps)
      add(round(x), round(y))
    end
  end
  return xs, ys
end

-- L字の角の余分なピクセルを取り除き、1px の線をきれいにする
local function pixelPerfect(xs, ys)
  local n = #xs
  if n < 3 then return xs, ys end
  local rx, ry = { xs[1] }, { ys[1] }
  for i = 2, n - 1 do
    local ax, ay = rx[#rx], ry[#ry]
    local bx, by, cx, cy = xs[i], ys[i], xs[i + 1], ys[i + 1]
    local corner = (ax == bx or ay == by) and (cx == bx or cy == by)
                   and ax ~= cx and ay ~= cy
    if not corner then rx[#rx + 1], ry[#ry + 1] = bx, by end
  end
  rx[#rx + 1], ry[#ry + 1] = xs[n], ys[n]
  return rx, ry
end

-- 指定した太さの丸いブラシが塗るピクセル(中心からの位置)
local brushCache = {}
local function brushOffsets(w)
  if brushCache[w] then return brushCache[w] end
  local offs = {}
  if w <= 1 then
    offs[1] = { 0, 0 }
  else
    local c, r2, o = (w - 1) / 2, (w / 2) ^ 2 - 0.5, w // 2
    for dy = 0, w - 1 do
      for dx = 0, w - 1 do
        if (dx - c) ^ 2 + (dy - c) ^ 2 <= r2 then offs[#offs + 1] = { dx - o, dy - o } end
      end
    end
  end
  brushCache[w] = offs
  return offs
end

-- 線のうちキャンバス内のピクセルごとに、fn(x, y) を1回ずつ呼ぶ
local function plotPath(p, fn)
  local xs, ys = tracePath(p)
  if p.width == 1 and p.pixelPerfect then xs, ys = pixelPerfect(xs, ys) end
  local offs = brushOffsets(p.width)
  local W, H = sprite.width, sprite.height
  local seen = {}
  for i = 1, #xs do
    for _, o in ipairs(offs) do
      local x, y = xs[i] + o[1], ys[i] + o[2]
      if x >= 0 and y >= 0 and x < W and y < H then
        local k = y * W + x
        if not seen[k] then
          seen[k] = true
          fn(x, y)
        end
      end
    end
  end
end

local function grayOf(c)
  return (c.r * 2126 + c.g * 7152 + c.b * 722) // 10000
end

-- スプライトのカラーモードで書き込むピクセル値
local function outputPixel(p)
  local c = p.color
  if sprite.colorMode == ColorMode.INDEXED then
    return c.index
  elseif sprite.colorMode == ColorMode.GRAY then
    return pc.graya(grayOf(c), c.a)
  end
  return pc.rgba(c.r, c.g, c.b, c.a)
end

-- すべての線を、線の範囲ぴったりの新しい画像に描く。
-- 画像と、そのキャンバス上の位置を返す。
local function renderPaths(paths)
  local px, py, pv = {}, {}, {}
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, p in ipairs(paths) do
    local v = outputPixel(p)
    plotPath(p, function(x, y)
      local n = #px + 1
      px[n], py[n], pv[n] = x, y, v
      if x < x0 then x0 = x end
      if y < y0 then y0 = y end
      if x > x1 then x1 = x end
      if y > y1 then y1 = y end
    end)
  end
  -- キャンバス内に何も見えないときは、1x1 の透明な画像にして
  -- セル(と中の曲線データ)が消えないようにする
  if #px == 0 then x0, y0, x1, y1 = 0, 0, 0, 0 end
  local img = Image(ImageSpec{
    width = x1 - x0 + 1, height = y1 - y0 + 1,
    colorMode = sprite.colorMode, transparentColor = sprite.transparentColor })
  img:clear()
  for i = 1, #px do img:drawPixel(px[i] - x0, py[i] - y0, pv[i]) end
  return img, Point(x0, y0)
end

------------------------------------------------------------------------
-- このフレームの線を読み込む

local paths = {}
local oldCel = curveLayer and curveLayer:cel(frameNumber)
-- 読み込んだときの線。何も変えていなければ確定しても何もしない。
-- nil のときは、変更がなくても描き直す。
local original = ""

if oldCel then
  local data = oldCel.properties(KEY)
  if type(data.paths) == "string" then
    paths = parse(data.paths)
    local img, pos = renderPaths(paths)
    local old = oldCel.image
    local same = img.width == old.width and img.height == old.height and img.bytes == old.bytes
    if not same then
      local r = app.alert{ title = TITLE,
        text = { "このフレームの絵は、線を引いたあとに変更されています",
                 "(手で描き足した場合など)。",
                 "確定すると線のデータから描き直すため、その変更は消えます。" },
        buttons = { "続ける", "キャンセル" } }
      if r ~= 1 then return end
    end
    -- セルが動かされていたら(移動ツールなど)、線も一緒に動かす
    local dx = oldCel.position.x - (data.x or pos.x)
    local dy = oldCel.position.y - (data.y or pos.y)
    if dx ~= 0 or dy ~= 0 then
      for _, p in ipairs(paths) do
        for _, n in ipairs(p.nodes) do n.x, n.y = n.x + dx, n.y + dy end
      end
    end
    original = same and serialize(paths) or nil
  elseif not oldCel.image:isEmpty() then
    local r = app.alert{ title = TITLE,
      text = { "曲線レイヤーのこのフレームに、線ではない絵があります。",
               "確定すると消えます。" },
      buttons = { "続ける", "キャンセル" } }
    if r ~= 1 then return end
  end
end

------------------------------------------------------------------------
-- 編集セッション
--
-- スクリプトはキャンバスの上に補助線を描けない。そのため編集中は、線を曲線
-- レイヤーに、点とハンドルを一番上の一時的なガイドレイヤーに直接描く。これらの
-- ピクセルは元に戻す情報を作らずに書き込み、ほかの操作がスプライトに触れる前に
-- 元どおりに戻す。レイヤーの準備は1回分の履歴になるが、終わるときにそれを
-- 元に戻すので、履歴には最終的な結果だけが残る。

local GUIDE_NAME = "ベジェ曲線のガイド(編集中)"
local HINT = "ベジェ曲線: クリックで点を追加、点やハンドルをドラッグで編集"
local HIT = 6   -- どこまで近ければつかめるか(画面のピクセル数)

-- 表示だけを変えるコマンド。それ以外のコマンドは、先に編集を確定してから実行する
local VIEW_COMMANDS = {}
for _, name in ipairs{
  "About", "AdvancedMode", "ChangeBrush", "ChangeColor", "ContiguousFill", "Eyedropper",
  "FitScreen", "FullscreenMode", "FullscreenPreview", "GotoNextLayer", "GotoPreviousLayer",
  "KeyboardShortcuts", "Options", "PixelPerfectMode", "Refresh", "Screenshot", "Scroll",
  "ScrollCenter", "SetColorSelector", "SetInkType", "SetPaletteEntrySize", "SetSameInk",
  "ShowAutoGuides", "ShowBrushPreview", "ShowBrushPreviewInPreview", "ShowExtras", "ShowGrid",
  "ShowLayerEdges", "ShowMenu", "ShowOnionSkin", "ShowPixelGrid", "ShowSelectionEdges",
  "ShowSlices", "ShowTileNumbers", "SnapToGrid", "SwapCheckerboardColors", "SwitchColors",
  "SymmetryMode", "TiledMode", "Timeline", "ToggleOtherLayersOpacity", "TogglePreview",
  "ToggleTilesMode", "ToggleTimelineThumbnails", "ToggleWorkspaceLayout", "Zoom",
} do
  VIEW_COMMANDS[name] = true
end

local function newLayerName()
  local used = {}
  local function scan(layers)
    for _, l in ipairs(layers) do
      used[l.name] = true
      if l.isGroup then scan(l.layers) end
    end
  end
  scan(sprite.layers)
  local n = 1
  while used["曲線 " .. n] do n = n + 1 end
  return "曲線 " .. n
end

local function blankImage(w, h)
  local img = Image(ImageSpec{ width = w, height = h,
    colorMode = sprite.colorMode, transparentColor = sprite.transparentColor })
  img:clear()
  return img
end

-- ガイドの色の、スプライトのカラーモードでのピクセル値
local function guidePixel(r, g, b)
  if sprite.colorMode == ColorMode.INDEXED then
    -- パレットのいちばん近い色
    local pal = sprite.palettes[1]
    local best, bestD = 0, math.huge
    for i = 0, #pal - 1 do
      if i ~= sprite.transparentColor then
        local c = pal:getColor(i)
        local d = (c.red - r) ^ 2 + (c.green - g) ^ 2 + (c.blue - b) ^ 2
        if d < bestD then best, bestD = i, d end
      end
    end
    return best
  elseif sprite.colorMode == ColorMode.GRAY then
    return pc.graya(grayOf{ r = r, g = g, b = b }, 255)
  end
  return pc.rgba(r, g, b, 255)
end

local GUIDE_POINT = guidePixel(255, 0, 200)      -- 選択中の線の点
local GUIDE_SELECTED = guidePixel(255, 230, 0)   -- 選択中の点
local GUIDE_HANDLE = guidePixel(0, 200, 255)     -- ハンドル
local GUIDE_OTHER = guidePixel(150, 70, 220)     -- ほかの線の点

-- 準備: キャンバス全体をおおうセル(絵は今までと同じ)を持つ曲線レイヤーと、
-- 一番上のガイドレイヤーを用意する

local createdLayer = not curveLayer
local layer = curveLayer
local cel, guideLayer
local oldImage = oldCel and oldCel.image:clone()
local oldPos = oldCel and oldCel.position

-- 新しいセルは、キャンバスと元のセルの両方をおおう
local bx, by, bw, bh = 0, 0, sprite.width, sprite.height
if oldCel then
  local b = oldCel.bounds
  local x2 = math.max(sprite.width, b.x + b.width)
  local y2 = math.max(sprite.height, b.y + b.height)
  bx, by = math.min(0, b.x), math.min(0, b.y)
  bw, bh = x2 - bx, y2 - by
end
local shown = {}   -- そのセルの透明でないピクセル

app.transaction(TITLE, function()
  local stale = {}
  for _, l in ipairs(sprite.layers) do
    if l.properties(KEY).guide == true then stale[#stale + 1] = l end
  end
  for _, l in ipairs(stale) do sprite:deleteLayer(l) end

  if not layer then
    layer = sprite:newLayer()
    layer.name = newLayerName()
    if src then
      layer.parent = src.parent
      layer.stackIndex = src.stackIndex + 1
    end
    layer.properties(KEY).curve = true
  end

  local full = blankImage(bw, bh)
  if oldCel then
    local mask = full.spec.transparentColor
    for it in oldImage:pixels() do
      local v = it()
      local ix, iy = it.x + oldPos.x - bx, it.y + oldPos.y - by
      full:drawPixel(ix, iy, v)
      if v ~= mask then shown[iy * bw + ix] = v end
    end
    oldCel.image = full
    oldCel.position = Point(bx, by)
    cel = oldCel
  else
    cel = sprite:newCel(layer, frameNumber, full, Point(bx, by))
  end

  guideLayer = sprite:newLayer()
  guideLayer.name = GUIDE_NAME
  guideLayer.properties(KEY).guide = true
  sprite:newCel(guideLayer, frameNumber, blankImage(sprite.width, sprite.height), Point(0, 0))

  app.layer = layer
end)

-- overlay は、元に戻す情報を作らずにセルの画像へピクセルを書き込む。
-- 画像のコピーを持っていて、restoreOverlay() ですべてのピクセルを元に戻せる。
local function newOverlay(c, current)
  local img = c.image
  return { img = img, x = c.position.x, y = c.position.y, w = img.width, h = img.height,
           mask = img.spec.transparentColor, base = img:clone(),
           cur = current or {}, touched = {} }
end

local curveOv = newOverlay(cel, shown)
local guideOv = newOverlay(guideLayer:cel(frameNumber))

-- キャンバスのピクセルの overlay でのキー。範囲外なら nil
local function overlayKey(o, x, y)
  local ix, iy = x - o.x, y - o.y
  if ix < 0 or iy < 0 or ix >= o.w or iy >= o.h then return nil end
  return iy * o.w + ix
end

-- overlay に `want` ({ [キー] = ピクセル値 }) のピクセルだけを表示させる
local function showOverlay(o, want)
  local img, w = o.img, o.w
  for k in pairs(o.cur) do
    if want[k] == nil then
      img:drawPixel(k % w, k // w, o.mask)
      o.touched[k] = true
    end
  end
  for k, v in pairs(want) do
    if o.cur[k] ~= v then
      img:drawPixel(k % w, k // w, v)
      o.touched[k] = true
    end
  end
  o.cur = want
end

local function restoreOverlay(o)
  local img, base, w = o.img, o.base, o.w
  for k in pairs(o.touched) do
    local x, y = k % w, k // w
    img:drawPixel(x, y, base:getPixel(x, y))
  end
  o.touched, o.cur = {}, {}
end

------------------------------------------------------------------------
-- 編集の状態

local dlg
local active, selNode = nil, nil   -- 選択中の線と点
local press = nil                  -- ドラッグ中の操作
local syncing = false              -- 入力欄をコードから更新している間は true
local undoStack, redoStack = {}, {}
local lastMerge = nil
local finished = false
local externalChange = false       -- ほかの操作がスプライトを変えた
local historyMoved = false         -- ほかの操作で元に戻す履歴が動いた
local askTimer, autoTimer, cleanupTimer
local pendingCommand = nil         -- 編集を確定するまで待たせているコマンド
local listeners = {}
local oldDoubleClick = nil

local function snapshot()
  return { data = serialize(paths), active = active, sel = selNode }
end

-- `before` から線が変わっていれば、元に戻す履歴に追加する
local function pushUndo(before)
  if before.data == serialize(paths) then return false end
  undoStack[#undoStack + 1] = before
  redoStack = {}
  return true
end

local function syncFields()
  local p = paths[active]
  syncing = true
  if p then
    dlg:modify{ id = "color", color = tableToColor(p.color) }
    dlg:modify{ id = "width", value = p.width }
    dlg:modify{ id = "pixelPerfect", selected = p.pixelPerfect }
    dlg:modify{ id = "closed", selected = p.closed }
    dlg:modify{ id = "styleSep", text = "選択中の線" }
  else
    dlg:modify{ id = "closed", selected = false }
    dlg:modify{ id = "styleSep", text = "次に描く線" }
  end
  syncing = false
end

local function updateButtons()
  local p = paths[active]
  local hasPoint = p ~= nil and selNode ~= nil
  dlg:modify{ id = "closed", enabled = p ~= nil }
  dlg:modify{ id = "deleteLine", enabled = p ~= nil }
  dlg:modify{ id = "deletePoint", enabled = hasPoint }
  dlg:modify{ id = "roundSharp", enabled = hasPoint }
  dlg:modify{ id = "undo", enabled = #undoStack > 0 }
  dlg:modify{ id = "redo", enabled = #redoStack > 0 }
end

local function select(pi, ni)
  local changed = pi ~= active
  active, selNode = pi, ni
  if changed then syncFields() end
end

------------------------------------------------------------------------
-- 編集操作

local function hasHandle(n, side)
  if side == "in" then return n.ix ~= 0 or n.iy ~= 0 end
  return n.ox ~= 0 or n.oy ~= 0
end

-- 最初の点の「in」ハンドルと最後の点の「out」ハンドルは、
-- 始点と終点をつないだときだけ使う
local function handleUsed(p, i, side)
  if p.closed then return true end
  if side == "in" then return i > 1 end
  return i < #p.nodes
end

local function handlePos(n, side)
  if side == "in" then return n.x + n.ix, n.y + n.iy end
  return n.x + n.ox, n.y + n.oy
end

-- ハンドルを (hx, hy) に動かす。なめらかな点では、oneSide でなければ
-- 反対側のハンドルも回す。
local function moveHandle(n, side, hx, hy, oneSide)
  local dx, dy = hx - n.x, hy - n.y
  local ox, oy
  if side == "out" then
    n.ox, n.oy = dx, dy
    ox, oy = n.ix, n.iy
  else
    n.ix, n.iy = dx, dy
    ox, oy = n.ox, n.oy
  end
  if oneSide then
    n.smooth = false
    return
  end
  if n.smooth then
    local len, olen = sqrt(dx * dx + dy * dy), sqrt(ox * ox + oy * oy)
    if len > 0 and olen > 0 then
      local k = -olen / len
      if side == "out" then n.ix, n.iy = dx * k, dy * k else n.ox, n.oy = dx * k, dy * k end
    end
  end
end

-- 点から (hx, hy) の向きに、両側のハンドルを引き出す
local function pullHandles(n, hx, hy)
  local dx, dy = hx - n.x, hy - n.y
  n.ox, n.oy, n.ix, n.iy = dx, dy, -dx, -dy
  n.smooth = dx ~= 0 or dy ~= 0
end

-- 区間の t の位置に、曲線の形を変えずに点を追加する
local function insertNode(p, seg, t)
  local nodes = p.nodes
  local a = nodes[seg]
  local b = nodes[seg % #nodes + 1]
  local function lerp(u, v) return u + (v - u) * t end
  local p1x, p1y = a.x + a.ox, a.y + a.oy
  local p2x, p2y = b.x + b.ix, b.y + b.iy
  local q0x, q0y = lerp(a.x, p1x), lerp(a.y, p1y)
  local q1x, q1y = lerp(p1x, p2x), lerp(p1y, p2y)
  local q2x, q2y = lerp(p2x, b.x), lerp(p2y, b.y)
  local r0x, r0y = lerp(q0x, q1x), lerp(q0y, q1y)
  local r1x, r1y = lerp(q1x, q2x), lerp(q1y, q2y)
  local x, y = round(lerp(r0x, r1x)), round(lerp(r0y, r1y))
  a.ox, a.oy = q0x - a.x, q0y - a.y
  b.ix, b.iy = q2x - b.x, q2y - b.y
  table.insert(nodes, seg + 1, {
    x = x, y = y, ix = r0x - x, iy = r0y - y, ox = r1x - x, oy = r1y - y, smooth = true })
  return seg + 1
end

local function deleteNode(pi, ni)
  local p = paths[pi]
  table.remove(p.nodes, ni)
  if #p.nodes == 0 then
    table.remove(paths, pi)
    if active == pi then
      select(nil, nil)
    elseif active and active > pi then
      active = active - 1
    end
  elseif active == pi and selNode then
    if selNode == ni then selNode = nil elseif selNode > ni then selNode = selNode - 1 end
  end
end

-- ハンドルのある点は角に、角の点は丸くする
local function toggleRound(p, i)
  local n = p.nodes[i]
  if hasHandle(n, "in") or hasHandle(n, "out") then
    n.ix, n.iy, n.ox, n.oy, n.smooth = 0, 0, 0, 0, false
    return
  end
  local count = #p.nodes
  local prev = p.nodes[i - 1] or (p.closed and p.nodes[count]) or nil
  local nxt = p.nodes[i + 1] or (p.closed and p.nodes[1]) or nil
  if prev == n then prev = nil end
  if nxt == n then nxt = nil end
  local dx, dy
  if prev and nxt then
    dx, dy = (nxt.x - prev.x) / 6, (nxt.y - prev.y) / 6
  elseif nxt then
    dx, dy = (nxt.x - n.x) / 3, (nxt.y - n.y) / 3
  elseif prev then
    dx, dy = (n.x - prev.x) / 3, (n.y - prev.y) / 3
  else
    return
  end
  n.ox, n.oy, n.ix, n.iy = dx, dy, -dx, -dy
  n.smooth = dx ~= 0 or dy ~= 0
end

------------------------------------------------------------------------
-- 線をキャンバスに表示する

-- 直線のピクセルごとに fn(x, y, i) を呼ぶ(i は 0 から数える)
local function linePixels(x0, y0, x1, y1, fn)
  local dx, dy = abs(x1 - x0), abs(y1 - y0)
  local sx, sy = x1 > x0 and 1 or -1, y1 > y0 and 1 or -1
  local err, x, y, i = dx - dy, x0, y0, 0
  while true do
    fn(x, y, i)
    if x == x1 and y == y1 then break end
    local e2 = 2 * err
    if e2 > -dy then err = err - dy; x = x + sx end
    if e2 < dx then err = err + dx; y = y + sy end
    i = i + 1
  end
end

local function guidePixels()
  local want = {}
  if not dlg.data.guides then return want end
  local function put(x, y, v)
    local k = overlayKey(guideOv, x, y)
    if k then want[k] = v end
  end
  for pi, p in ipairs(paths) do
    if pi ~= active then
      for _, n in ipairs(p.nodes) do put(n.x, n.y, GUIDE_OTHER) end
    end
  end
  local p = paths[active]
  if p then
    for i, n in ipairs(p.nodes) do
      for _, side in ipairs({ "in", "out" }) do
        if hasHandle(n, side) and handleUsed(p, i, side) then
          local hx, hy = handlePos(n, side)
          hx, hy = round(hx), round(hy)
          -- 点からハンドルの先までの点線
          linePixels(n.x, n.y, hx, hy, function(x, y, j)
            if j % 2 == 0 then put(x, y, GUIDE_HANDLE) end
          end)
          put(hx, hy, GUIDE_HANDLE)
        end
      end
    end
    for i, n in ipairs(p.nodes) do
      put(n.x, n.y, i == selNode and GUIDE_SELECTED or GUIDE_POINT)
    end
  end
  return want
end

local function redraw()
  local want = {}
  for _, p in ipairs(paths) do
    local v = outputPixel(p)
    plotPath(p, function(x, y)
      local k = overlayKey(curveOv, x, y)
      if k then want[k] = v end
    end)
  end
  showOverlay(curveOv, want)
  showOverlay(guideOv, guidePixels())
end

-- 線をキャンバスに表示し、パネルを更新する
local function refresh()
  redraw()
  updateButtons()
  app.refresh()
end

-- fn を1回の編集として実行する。同じ mergeKey の編集が続いたとき
-- (太さのスライダーを動かしている間など)は、まとめて1回で元に戻す。
local function edit(fn, mergeKey)
  local before = nil
  if not mergeKey or mergeKey ~= lastMerge then before = snapshot() end
  fn()
  if before then
    lastMerge = pushUndo(before) and mergeKey or nil
  end
  refresh()
end

local function restore(s)
  paths = parse(s.data)
  active, selNode = s.active, s.sel
  if not paths[active] then active, selNode = nil, nil end
  if active and selNode and not paths[active].nodes[selNode] then selNode = nil end
  lastMerge, press = nil, nil
  syncFields()
  refresh()
  askTimer:start()
end

local function undo()
  if #undoStack == 0 then return end
  redoStack[#redoStack + 1] = snapshot()
  restore(table.remove(undoStack))
end

local function redo()
  if #redoStack == 0 then return end
  undoStack[#undoStack + 1] = snapshot()
  restore(table.remove(redoStack))
end

local function deleteSelectedPoint()
  if paths[active] and selNode then
    edit(function() deleteNode(active, selNode) end)
    askTimer:start()
  end
end

------------------------------------------------------------------------
-- キャンバスでのクリックとドラッグ

-- どこまで近ければつかめるか(スプライトのピクセル数)
local function tolerance()
  local ok, zoom = pcall(function() return editor.zoom end)
  if not ok or type(zoom) ~= "number" or zoom <= 0 then zoom = 8 end
  return math.max(0.5, HIT / zoom)
end

-- 区間上で (x, y) にいちばん近い位置の t と、その距離を返す
local function nearestOnSegment(a, b, x, y)
  local len = dist(a.x, a.y, a.x + a.ox, a.y + a.oy)
            + dist(a.x + a.ox, a.y + a.oy, b.x + b.ix, b.y + b.iy)
            + dist(b.x + b.ix, b.y + b.iy, b.x, b.y)
  local steps = math.max(8, math.min(2000, math.ceil(len * 2)))
  local bestD, bestT = math.huge, 0
  local px, py = a.x, a.y
  for i = 1, steps do
    local qx, qy = bezier(a, b, i / steps)
    local dx, dy = qx - px, qy - py
    local l2 = dx * dx + dy * dy
    local u = 0
    if l2 > 0 then u = math.max(0, math.min(1, ((x - px) * dx + (y - py) * dy) / l2)) end
    local d = dist(x, y, px + u * dx, py + u * dy)
    if d < bestD then bestD, bestT = d, (i - 1 + u) / steps end
    px, py = qx, qy
  end
  return bestT, bestD
end

-- ピクセル (x, y) にあるもの(ハンドル・点・線)を探す
local function hitTest(x, y)
  local tol = tolerance()
  local best, bestD = nil, math.huge
  local function consider(d, hit)
    if d <= tol and d < bestD then best, bestD = hit, d end
  end

  -- 選択中の線のハンドル(自分の点と重なっているものは除く)
  local p = paths[active]
  if p then
    for i, n in ipairs(p.nodes) do
      for _, side in ipairs({ "out", "in" }) do
        if hasHandle(n, side) and handleUsed(p, i, side) then
          local hx, hy = handlePos(n, side)
          if round(hx) ~= n.x or round(hy) ~= n.y then
            consider(dist(x, y, hx, hy) + 0.01, { kind = "handle", path = active, node = i, side = side })
          end
        end
      end
    end
  end

  -- 点(同じ距離なら選択中の線を優先)
  for pi, q in ipairs(paths) do
    local bias = pi == active and 0 or 0.02
    for i, n in ipairs(q.nodes) do
      consider(dist(x, y, n.x, n.y) + bias, { kind = "anchor", path = pi, node = i })
    end
  end
  if best then return best end

  -- 線: 線のピクセルか、曲線の近くをクリックしたとき
  for pi, q in ipairs(paths) do
    local onPixel = false
    plotPath(q, function(px, py)
      if px == x and py == y then onPixel = true end
    end)
    for _, s in ipairs(segments(q)) do
      local t, d = nearestOnSegment(s[1], s[2], x, y)
      if pi ~= active then d = d + 0.02 end
      if (onPixel or d <= tol) and d < bestD then
        best, bestD = { kind = "segment", path = pi, seg = s[3], t = t }, d
      end
    end
  end
  return best
end

-- 選択中の線の最後に点を追加する。選択中の線がなければ新しい線を始める
local function addPoint(x, y)
  local p = paths[active]
  if not p or p.closed then
    local d = dlg.data
    p = { color = colorToTable(d.color), width = d.width, pixelPerfect = d.pixelPerfect,
          closed = false, nodes = {} }
    paths[#paths + 1] = p
    select(#paths, nil)
  end
  p.nodes[#p.nodes + 1] = { x = x, y = y, ix = 0, iy = 0, ox = 0, oy = 0, smooth = false }
  selNode = #p.nodes
  return { kind = "anchor", path = active, node = selNode }
end

-- (x, y) でボタンが押された: ドラッグで何をするかを決める
local function startGesture(x, y)
  lastMerge = nil
  local before = snapshot()
  local hit = hitTest(x, y)
  if hit and hit.kind == "handle" then
    select(hit.path, hit.node)
    local hx, hy = handlePos(paths[hit.path].nodes[hit.node], hit.side)
    press = { kind = "handle", hit = hit, before = before, sx = x, sy = y, hx = hx, hy = hy }
  elseif hit and hit.kind == "anchor" then
    select(hit.path, hit.node)
    local n = paths[hit.path].nodes[hit.node]
    press = { kind = "anchor", hit = hit, before = before, sx = x, sy = y, x = n.x, y = n.y }
  elseif hit then
    select(hit.path, nil)
    local orig = {}
    for i, n in ipairs(paths[hit.path].nodes) do orig[i] = { n.x, n.y } end
    press = { kind = "segment", hit = hit, before = before, sx = x, sy = y, orig = orig }
  else
    press = { kind = "pull", hit = addPoint(x, y), before = before }
  end
end

local function dragTo(x, y)
  local d = press
  local n = d.hit.node and paths[d.hit.path].nodes[d.hit.node]
  if d.kind == "anchor" then
    n.x, n.y = d.x + x - d.sx, d.y + y - d.sy
  elseif d.kind == "handle" then
    moveHandle(n, d.hit.side, d.hx + x - d.sx, d.hy + y - d.sy, dlg.data.oneSide)
  elseif d.kind == "pull" then
    if x == n.x and y == n.y then
      n.ix, n.iy, n.ox, n.oy, n.smooth = 0, 0, 0, 0, false
    else
      pullHandles(n, x, y)
    end
  elseif d.kind == "segment" then
    -- 線をクリックすると点を追加、ドラッグすると線ごと移動
    if x ~= d.sx or y ~= d.sy then d.moved = true end
    if d.moved then
      for i, m in ipairs(paths[d.hit.path].nodes) do
        m.x, m.y = d.orig[i][1] + x - d.sx, d.orig[i][2] + y - d.sy
      end
    end
  end
end

local function endGesture(x, y, dragged)
  local d = press
  if dragged then dragTo(x, y) end
  press = nil
  if d.kind == "segment" and not d.moved then
    select(d.hit.path, insertNode(paths[d.hit.path], d.hit.seg, d.hit.t))
  end
  pushUndo(d.before)
  refresh()
end

local ask

-- ボタンを押している間、マウスが動くたびに呼ばれる
local function onChange(ev)
  if finished then return end
  local pt = ev.point
  if not press then startGesture(pt.x, pt.y) end
  dragTo(pt.x, pt.y)
  redraw()
end

-- ボタンが離された
local function onClick(ev)
  if finished then return end
  local pt = ev.point
  if press then
    endGesture(pt.x, pt.y, true)
  else
    startGesture(pt.x, pt.y)
    endGesture(pt.x, pt.y, false)
  end
  -- askPoint() はクリックのたびに終わるので、もう一度呼ぶ(ここからは呼べない)
  askTimer:start()
end

-- Esc はドラッグを取り消すか、線の選択を解除する
local function onCancel()
  if finished then return end
  if press then
    local before = press.before
    press = nil
    restore(before)
  elseif active then
    select(nil, nil)
    refresh()
  end
  askTimer:start()
end

ask = function()
  if finished or app.editor ~= editor then return end
  local p = paths[active]
  local n = p and selNode and p.nodes[selNode]
  -- `point` で選択中の点を枠で囲む
  editor:askPoint{ title = HINT, point = n and Point(n.x, n.y) or nil,
                   onchange = onChange, onclick = onClick, oncancel = onCancel }
end

------------------------------------------------------------------------
-- 編集の終了

local function finish(apply, canUndo, fromPanelClose)
  if finished then return end
  finished = true
  press = nil
  rawset(_G, SESSION, nil)
  askTimer:stop()
  autoTimer:stop()
  -- イベントを送っている最中にはリスナーを外せない
  cleanupTimer:start()
  if oldDoubleClick ~= nil then
    pcall(function() app.preferences.selection.doubleclick_select_tile = oldDoubleClick end)
  end
  pcall(function() rawset(_G, PANEL_BOUNDS, dlg.bounds) end)

  local ok, err = pcall(function()
    if not pcall(function() return sprite.width end) then return end   -- スプライトが閉じられた

    -- ほかのスプライトを表示中でも、編集していたスプライトで作業する
    local keepSprite, keepFrame = app.sprite, app.frame
    local switched = keepSprite ~= sprite
    if switched then app.sprite = sprite end
    if app.editor == editor then editor:cancel() end

    -- ピクセルを準備した直後の状態に戻す
    pcall(restoreOverlay, curveOv)
    pcall(restoreOverlay, guideOv)

    if historyMoved then
      -- (元に戻す履歴パネルなどで)履歴が動かされたので、そのままにする
      app.alert{ title = TITLE, text = "元に戻す履歴が変更されたため、ベジェ曲線の編集を終了しました。" }
    else
      local result = serialize(paths)
      local changed = apply and result ~= original

      -- 準備が履歴の最後のままなら、それを元に戻す
      local undone = false
      if canUndo and not externalChange then
        app.command.Undo()
        -- うまくいったか確かめる: ガイドレイヤーがなくなっていればよい
        undone = true
        for _, l in ipairs(sprite.layers) do
          if l == guideLayer then undone = false end
        end
      end

      if not undone or changed then
        app.transaction(TITLE, function()
          -- 準備を元に戻すと、そのとき作ったレイヤーはなくなる
          local target = layer
          if undone then target = curveLayer end
          if not undone then
            sprite:deleteLayer(guideLayer)
            if not changed then
              -- キャンセル: 準備でしたことを元に戻す
              if createdLayer then
                sprite:deleteLayer(layer)
              elseif oldCel then
                cel.image = oldImage
                cel.position = oldPos
              else
                sprite:deleteCel(cel)
              end
              return
            end
            if createdLayer and #paths == 0 then
              sprite:deleteLayer(layer)
              return
            end
          end

          if not target then
            target = sprite:newLayer()
            target.name = newLayerName()
            if src then
              target.parent = src.parent
              target.stackIndex = src.stackIndex + 1
            end
            target.properties(KEY).curve = true
          end
          local c = target:cel(frameNumber)
          if #paths == 0 then
            if c then sprite:deleteCel(c) end
          else
            local img, pos = renderPaths(paths)
            if c then
              c.image = img
              c.position = pos
            else
              c = sprite:newCel(target, frameNumber, img, pos)
            end
            c.properties(KEY, { version = 1, x = pos.x, y = pos.y, paths = result })
          end
          app.layer = target
        end)
      end
    end

    -- ユーザーがいた場所に戻る
    if switched then
      app.sprite = keepSprite
    elseif keepFrame and keepFrame.frameNumber ~= frameNumber then
      app.frame = keepFrame
    end
  end)

  if not fromPanelClose then dlg:close() end
  app.refresh()
  if not ok then
    app.alert{ title = TITLE, text = { "ベジェ曲線の編集を終えるときにエラーが起きました:", tostring(err) } }
  end
end

------------------------------------------------------------------------
-- パネル

local function changeStyle(key, apply)
  if syncing or finished then return end
  local p = paths[active]
  if p then edit(function() apply(p) end, key .. active) end
end

dlg = Dialog{ title = TITLE, onclose = function() finish(true, true, true) end }
dlg:label{ text = "キャンバスをクリックで点を追加、点やハンドルをドラッグで曲げる" }
   :newrow()
   :label{ text = "線をクリックでそこに点を追加 / Del: 点を削除" }
   :separator{ id = "styleSep", text = "次に描く線" }
   :color{ id = "color", label = "色", color = app.fgColor,
           onchange = function()
             changeStyle("color", function(p) p.color = colorToTable(dlg.data.color) end)
           end }
   :slider{ id = "width", label = "太さ", min = 1, max = 32, value = 1,
            onchange = function()
              changeStyle("width", function(p) p.width = dlg.data.width end)
            end }
   :check{ id = "pixelPerfect", label = "", text = "ピクセルパーフェクト(太さ1のとき)", selected = true,
           onclick = function()
             changeStyle("pixelPerfect", function(p) p.pixelPerfect = dlg.data.pixelPerfect end)
           end }
   :check{ id = "closed", text = "始点と終点をつなぐ", selected = false,
           onclick = function()
             changeStyle("closed", function(p) p.closed = dlg.data.closed end)
           end }
   :check{ id = "oneSide", label = "", text = "ハンドルを片側だけ動かす", selected = false }
   :check{ id = "guides", text = "ガイドを表示", selected = true,
           onclick = function() if not finished then refresh() end end }
   :separator{}
   :button{ id = "newLine", text = "新しい線",
            onclick = function()
              if finished then return end
              select(nil, nil)
              refresh()
              askTimer:start()
            end }
   :button{ id = "deleteLine", text = "線を削除",
            onclick = function()
              if finished or not paths[active] then return end
              local pi = active
              edit(function()
                table.remove(paths, pi)
                select(nil, nil)
              end)
              askTimer:start()
            end }
   :newrow()
   :button{ id = "deletePoint", text = "点を削除",
            onclick = function() if not finished then deleteSelectedPoint() end end }
   :button{ id = "roundSharp", text = "丸/角",
            onclick = function()
              if finished or not (paths[active] and selNode) then return end
              local p, i = paths[active], selNode
              edit(function() toggleRound(p, i) end)
            end }
   :newrow()
   :button{ id = "undo", text = "元に戻す", onclick = function() if not finished then undo() end end }
   :button{ id = "redo", text = "やり直す", onclick = function() if not finished then redo() end end }
   :separator{}
   :button{ id = "ok", text = "確定", focus = true, onclick = function() finish(true, true) end }
   :button{ id = "cancel", text = "キャンセル", onclick = function() finish(false, true) end }

------------------------------------------------------------------------
-- 開始

askTimer = Timer{ interval = 0.01, ontick = function()
  askTimer:stop()
  ask()
end }

-- ほかのフレームやスプライトに移ったとき、またはほかの操作がスプライトを
-- 変えたときに、編集を確定する
autoTimer = Timer{ interval = 0.01, ontick = function()
  autoTimer:stop()
  finish(true, true)
  local cmd = pendingCommand
  pendingCommand = nil
  if cmd and app.command[cmd.name] then app.command[cmd.name](cmd.params) end
end }

cleanupTimer = Timer{ interval = 0.01, ontick = function()
  cleanupTimer:stop()
  for _, l in ipairs(listeners) do pcall(function() l[1]:off(l[2]) end) end
  listeners = {}
end }

local function listen(events, name, fn)
  listeners[#listeners + 1] = { events, events:on(name, fn) }
end

listen(app.events, "beforecommand", function(ev)
  if finished then return end
  local here = app.sprite == sprite
  if here and ev.name == "Undo" then
    undo()
    ev.stopPropagation()
  elseif here and ev.name == "Redo" then
    redo()
    ev.stopPropagation()
  elseif here and ev.name == "Clear" then
    -- Delete/Backspace はピクセルを消す代わりに、選択中の点を削除する
    deleteSelectedPoint()
    ev.stopPropagation()
  elseif not VIEW_COMMANDS[ev.name] then
    -- コマンドをいったん止め、編集を確定してから、もう一度実行する
    -- (ここで確定すると、準備の分が元に戻す履歴に残ってしまう)
    if not pendingCommand then pendingCommand = { name = ev.name, params = ev.params } end
    ev.stopPropagation()
    autoTimer:start()
  end
end)

listen(app.events, "sitechange", function()
  if finished then return end
  if app.sprite ~= sprite or not app.frame or app.frame.frameNumber ~= frameNumber then
    autoTimer:start()
  end
end)

listen(sprite.events, "change", function(ev)
  if finished then return end
  externalChange = true
  if ev.fromUndo then historyMoved = true end
  autoTimer:start()
end)

-- 素早く2回クリックするとグリッドのタイルが選択されてしまう(スクリプトにも届かない)
pcall(function()
  oldDoubleClick = app.preferences.selection.doubleclick_select_tile
  app.preferences.selection.doubleclick_select_tile = false
end)

rawset(_G, SESSION, { finish = finish })

syncFields()
dlg:show{ wait = false }

-- パネルはじゃまにならない位置に置く: 前回の位置か、右端
local b = dlg.bounds
local saved = rawget(_G, PANEL_BOUNDS)
if saved then
  dlg.bounds = Rectangle(saved.x, saved.y, b.width, b.height)
elseif app.window then
  dlg.bounds = Rectangle(math.max(0, app.window.width - b.width - 24), 72, b.width, b.height)
end

refresh()
ask()
