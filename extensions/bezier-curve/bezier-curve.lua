-- Bezier Curve (Aseprite extension)
--
-- Lines drawn with Bezier curves on "curve layers" that stay editable.
-- * Layer > New > New Curve Layer makes a curve layer. While a curve layer is
--   selected, its lines can be edited right on the canvas: click to add
--   points, drag points or handles to bend the lines.
-- * The lines are drawn as pixels, and the curve data is kept in the cel, so
--   they can be edited again at any time (and are saved in .aseprite files).
-- * Selecting another layer or frame, or using another command, puts the
--   edit in the undo history as a single step.

local KEY = "asepritescript/bezier-curve"
local HIT = 6   -- how close (in screen pixels) a click must be to grab something

local TEXT = {
  en = {
    title = "Bezier Curve",
    newLayerCmd = "New Curve Layer",
    editCmd = "Edit Curves",
    layerName = "Curve",
    hint = "Bezier Curve: click to add points, drag points or handles to edit them",
    hintNew = "Bezier Curve: drawing a new line (other lines can't be selected). Esc: done",
    help1 = "Click to add points, drag points or handles to bend.",
    help2 = "Click a line to add a point there. Del: delete the point.",
    nextLine = "Next Line",
    selectedLine = "Selected Line",
    drawingLine = "New Line (Esc: done)",
    color = "Color",
    width = "Width",
    pixelPerfect = "Pixel-perfect (width 1)",
    closed = "Connect the ends",
    oneSide = "Move one handle only",
    guides = "Show guides",
    newLine = "New Line",
    deleteLine = "Delete Line",
    deletePoint = "Delete Point",
    roundSharp = "Round/Sharp",
    undo = "Undo",
    redo = "Redo",
    stop = "Stop Editing",
    notCurveLayer = "The active layer isn't a curve layer. Make one with Layer > New > New Curve Layer.",
    locked = "The curve layer is locked or hidden.",
    handEdited = { "The pixels in this frame were changed after the lines were drawn",
                   "(for example, painted over or filtered).",
                   "Editing the lines redraws the frame, so those changes will be lost." },
    extraPixels = { "This frame of the curve layer has pixels that aren't part of a line.",
                    "Editing the lines will erase them." },
    continue = "Continue",
    cancel = "Cancel",
    skippedTip = "This frame of the curve layer was changed by hand. Use Layer > Edit Curves to edit its lines.",
    stoppedTip = "Curve editing stopped. Use Layer > Edit Curves to start again.",
    error = "Something went wrong while finishing the curve edit:",
  },
  ja = {
    title = "ベジェ曲線",
    newLayerCmd = "新しい曲線レイヤー",
    editCmd = "曲線を編集",
    layerName = "曲線",
    hint = "ベジェ曲線: クリックで点を追加、点やハンドルをドラッグで編集",
    hintNew = "ベジェ曲線: 新しい線を描いています(ほかの線は選べません)。Esc で終了",
    help1 = "クリックで点を追加、点やハンドルをドラッグで曲げる",
    help2 = "線をクリックでそこに点を追加 / Del: 点を削除",
    nextLine = "次に描く線",
    selectedLine = "選択中の線",
    drawingLine = "新しい線(Esc で終了)",
    color = "色",
    width = "太さ",
    pixelPerfect = "ピクセルパーフェクト(太さ1のとき)",
    closed = "始点と終点をつなぐ",
    oneSide = "ハンドルを片側だけ動かす",
    guides = "ガイドを表示",
    newLine = "新しい線",
    deleteLine = "線を削除",
    deletePoint = "点を削除",
    roundSharp = "丸/角",
    undo = "元に戻す",
    redo = "やり直す",
    stop = "編集をやめる",
    notCurveLayer = "選択中のレイヤーは曲線レイヤーではありません。レイヤー > 新規 > 新しい曲線レイヤー で作れます。",
    locked = "曲線レイヤーがロックされているか、非表示になっています。",
    handEdited = { "このフレームの絵は、線を引いたあとに変更されています",
                   "(手で描き足したり、フィルターをかけたりした場合など)。",
                   "線を編集するとフレームを描き直すため、その変更は消えます。" },
    extraPixels = { "曲線レイヤーのこのフレームに、線ではない絵があります。",
                    "線を編集すると消えます。" },
    continue = "続ける",
    cancel = "キャンセル",
    skippedTip = "曲線レイヤーのこのフレームは手で変更されています。線を編集するには レイヤー > 曲線を編集 を使ってください。",
    stoppedTip = "曲線の編集をやめました。レイヤー > 曲線を編集 でもう一度始められます。",
    error = "曲線の編集を終えるときにエラーが起きました:",
  },
}
local T = TEXT.en

-- Commands that only change the view. Any other command applies the edit first.
local VIEW_COMMANDS = {}
for _, name in ipairs{
  "About", "AdvancedMode", "ChangeBrush", "ChangeColor", "ContiguousFill", "Eyedropper",
  "FitScreen", "FullscreenMode", "FullscreenPreview", "KeyboardShortcuts", "Options",
  "PixelPerfectMode", "Refresh", "Screenshot", "Scroll", "ScrollCenter", "SetColorSelector",
  "SetInkType", "SetPaletteEntrySize", "SetSameInk", "ShowAutoGuides", "ShowBrushPreview",
  "ShowBrushPreviewInPreview", "ShowExtras", "ShowGrid", "ShowLayerEdges", "ShowMenu",
  "ShowOnionSkin", "ShowPixelGrid", "ShowSelectionEdges", "ShowSlices", "ShowTileNumbers",
  "SnapToGrid", "SwapCheckerboardColors", "SwitchColors", "SymmetryMode", "TiledMode",
  "Timeline", "ToggleOtherLayersOpacity", "TogglePreview", "ToggleTilesMode",
  "ToggleTimelineThumbnails", "ToggleWorkspaceLayout", "Zoom",
} do
  VIEW_COMMANDS[name] = true
end

local pc = app.pixelColor
local floor, sqrt, abs = math.floor, math.sqrt, math.abs

local function round(v) return floor(v + 0.5) end

local function dist(x0, y0, x1, y1)
  return sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
end

------------------------------------------------------------------------
-- Curve data
--
-- A line (path) is a list of points (nodes). Each node has a position on a
-- pixel (x, y) and two handles stored as offsets from that position:
-- the "in" handle (ix, iy) bends the curve coming into the point, and
-- the "out" handle (ox, oy) bends the curve leaving it.
-- A smooth node keeps both handles on a straight line.

local function colorToTable(c)
  return { r = c.red, g = c.green, b = c.blue, a = c.alpha, index = c.index }
end

local function tableToColor(sprite, t)
  if sprite.colorMode == ColorMode.INDEXED then return Color(t.index) end
  return Color{ r = t.r, g = t.g, b = t.b, a = t.a }
end

local function serialize(paths)
  -- Handles are saved with 2 decimals
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

-- Returns the segments of a path as { nodeA, nodeB, indexOfA }
local function segments(p)
  local list, nodes = {}, p.nodes
  for i = 1, #nodes - 1 do list[#list + 1] = { nodes[i], nodes[i + 1], i } end
  if p.closed and #nodes > 1 then list[#list + 1] = { nodes[#nodes], nodes[1], #nodes } end
  return list
end

-- Point at t (0..1) on the curve between nodes a and b
local function bezier(a, b, t)
  local u = 1 - t
  local k0, k1, k2, k3 = u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t
  return k0 * a.x + k1 * (a.x + a.ox) + k2 * (b.x + b.ix) + k3 * b.x,
         k0 * a.y + k1 * (a.y + a.oy) + k2 * (b.y + b.iy) + k3 * b.y
end

------------------------------------------------------------------------
-- Drawing the lines as pixels

-- Follows the path and returns the pixels it passes through, in order.
-- Each pixel touches the next one.
local function tracePath(p)
  local xs, ys = {}, {}
  local function add(x, y)
    local n = #xs
    if n > 0 then
      local lx, ly = xs[n], ys[n]
      if lx == x and ly == y then return end
      -- Fill any gap with a straight line
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

-- Removes the extra pixel from L-shaped corners so 1px lines look clean
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

-- Pixels covered by a round brush of the given width, relative to its center
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

-- Calls fn(x, y) once for every pixel of the line that's inside the canvas
local function plotPath(sprite, p, fn)
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

-- Pixel value to write in the sprite's color mode
local function outputPixel(sprite, p)
  local c = p.color
  if sprite.colorMode == ColorMode.INDEXED then
    return c.index
  elseif sprite.colorMode == ColorMode.GRAY then
    return pc.graya(grayOf(c), c.a)
  end
  return pc.rgba(c.r, c.g, c.b, c.a)
end

local function blankImage(sprite, w, h)
  local img = Image(ImageSpec{ width = w, height = h,
    colorMode = sprite.colorMode, transparentColor = sprite.transparentColor })
  img:clear()
  return img
end

-- Draws all the lines into a new canvas-sized image
local function renderPaths(sprite, paths)
  local img = blankImage(sprite, sprite.width, sprite.height)
  for _, p in ipairs(paths) do
    local v = outputPixel(sprite, p)
    plotPath(sprite, p, function(x, y) img:drawPixel(x, y, v) end)
  end
  return img
end

-- Pixel value of a guide color in the sprite's color mode
local function guidePixel(sprite, r, g, b)
  if sprite.colorMode == ColorMode.INDEXED then
    -- The closest palette entry
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

------------------------------------------------------------------------
-- Curve layers and cels

local function isCurveLayer(layer)
  return layer ~= nil and layer.isImage and not layer.isTilemap
         and layer.properties(KEY).curve == true
end

local function coversCanvas(sprite, cel)
  local b = cel.bounds
  return b.x <= 0 and b.y <= 0 and b.x + b.width >= sprite.width and b.y + b.height >= sprite.height
end

local function isEmptyRect(r) return r.width <= 0 or r.height <= 0 end

-- Checks that a cel shows exactly what its lines draw, wherever the cel was
-- moved. Returns whether it does, and how far the cel was moved.
local function compareWithLines(sprite, cel, paths)
  local drawn = renderPaths(sprite, paths)
  local db = drawn:shrinkBounds()
  local img = cel.image
  local cb = img:shrinkBounds()
  if isEmptyRect(db) or isEmptyRect(cb) then
    return isEmptyRect(db) and isEmptyRect(cb), 0, 0
  end
  if db.width ~= cb.width or db.height ~= cb.height then return false end
  if Image(drawn, db).bytes ~= Image(img, cb).bytes then return false end
  return true, cel.position.x + cb.x - db.x, cel.position.y + cb.y - db.y
end

local function newLayerName(sprite)
  local used = {}
  local function scan(layers)
    for _, l in ipairs(layers) do
      used[l.name] = true
      if l.isGroup then scan(l.layers) end
    end
  end
  scan(sprite.layers)
  local n = 1
  while used[T.layerName .. " " .. n] do n = n + 1 end
  return T.layerName .. " " .. n
end

------------------------------------------------------------------------
-- Overlay
--
-- Scripts can't draw on top of the canvas. So while editing, the lines and
-- the points and handles are drawn straight into the curve layer's cel.
-- These pixels are written without undo information, and are put back
-- exactly as they were before anything else can touch the sprite.

-- Pixels of an image that aren't transparent, as { [key] = pixel value }
local function visiblePixels(img)
  local list = {}
  local b = img:shrinkBounds()
  if not isEmptyRect(b) then
    local mask, w = img.spec.transparentColor, img.width
    for it in img:pixels(b) do
      local v = it()
      if v ~= mask then list[it.y * w + it.x] = v end
    end
  end
  return list
end

local function newOverlay(cel)
  local img = cel.image
  return { img = img, x = cel.position.x, y = cel.position.y, w = img.width, h = img.height,
           mask = img.spec.transparentColor, base = img:clone(),
           cur = visiblePixels(img), touched = {} }
end

-- Key of a canvas pixel in an overlay, or nil if it's outside
local function overlayKey(o, x, y)
  local ix, iy = x - o.x, y - o.y
  if ix < 0 or iy < 0 or ix >= o.w or iy >= o.h then return nil end
  return iy * o.w + ix
end

-- Makes the overlay show exactly the pixels in `want` ({ [key] = pixel value })
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
-- State

local S = nil          -- the editing session (while a curve layer is selected)
local panel = nil      -- the panel dialog, kept open between sessions
local paused = nil     -- { layer = layer }: don't edit this layer until it's selected again
local pending = nil    -- a command held back until the edit is applied
local rerunning = false -- true while running the held command
local removals = {}    -- event listeners to remove on the next tick
local listeners = {}   -- app event listeners of the extension
local lastSkip = nil   -- the last frame that couldn't be edited (to show the tip once)
local prefs = {}       -- plugin.preferences
local askTimer, tickTimer

local function scheduleTick()
  if tickTimer and not tickTimer.isRunning then tickTimer:start() end
end

local function tip(text)
  pcall(function() app.tip(text, 4) end)
end

------------------------------------------------------------------------
-- Editing operations

local function hasHandle(n, side)
  if side == "in" then return n.ix ~= 0 or n.iy ~= 0 end
  return n.ox ~= 0 or n.oy ~= 0
end

-- The "in" handle of the first point and the "out" handle of the last
-- point only matter when the line is closed
local function handleUsed(p, i, side)
  if p.closed then return true end
  if side == "in" then return i > 1 end
  return i < #p.nodes
end

local function handlePos(n, side)
  if side == "in" then return n.x + n.ix, n.y + n.iy end
  return n.x + n.ox, n.y + n.oy
end

-- Moves one handle to (hx, hy). A smooth point turns the other handle too,
-- unless oneSide is set.
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

-- Pulls out both handles from a point, pointing at (hx, hy)
local function pullHandles(n, hx, hy)
  local dx, dy = hx - n.x, hy - n.y
  n.ox, n.oy, n.ix, n.iy = dx, dy, -dx, -dy
  n.smooth = dx ~= 0 or dy ~= 0
end

-- Adds a point at t on a segment without changing the shape of the curve
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

-- A point with handles becomes sharp, a sharp one becomes round
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
-- Panel fields

local function syncFields()
  local s, dlg = S, panel
  if not s or not dlg then return end
  local p = s.paths[s.active]
  s.syncing = true
  if p then
    dlg:modify{ id = "color", color = tableToColor(s.sprite, p.color) }
    dlg:modify{ id = "width", value = p.width }
    dlg:modify{ id = "pixelPerfect", selected = p.pixelPerfect }
    dlg:modify{ id = "closed", selected = p.closed }
    dlg:modify{ id = "styleSep", text = s.newLine and T.drawingLine or T.selectedLine }
  else
    dlg:modify{ id = "closed", selected = false }
    dlg:modify{ id = "styleSep", text = s.newLine and T.drawingLine or T.nextLine }
  end
  s.syncing = false
end

local function updateButtons()
  local s, dlg = S, panel
  if not s or not dlg then return end
  local p = s.paths[s.active]
  local hasPoint = p ~= nil and s.selNode ~= nil
  dlg:modify{ id = "closed", enabled = p ~= nil }
  dlg:modify{ id = "deleteLine", enabled = p ~= nil }
  dlg:modify{ id = "deletePoint", enabled = hasPoint }
  dlg:modify{ id = "roundSharp", enabled = hasPoint }
  dlg:modify{ id = "undo", enabled = #s.undoStack > 0 }
  dlg:modify{ id = "redo", enabled = #s.redoStack > 0 }
end

local function select(pi, ni)
  local s = S
  local changed = pi ~= s.active
  s.active, s.selNode = pi, ni
  if changed then syncFields() end
end

local function deleteNode(pi, ni)
  local s = S
  local p = s.paths[pi]
  table.remove(p.nodes, ni)
  if #p.nodes == 0 then
    table.remove(s.paths, pi)
    if s.active == pi then
      select(nil, nil)
    elseif s.active and s.active > pi then
      s.active = s.active - 1
    end
  elseif s.active == pi and s.selNode then
    if s.selNode == ni then s.selNode = nil elseif s.selNode > ni then s.selNode = s.selNode - 1 end
  end
end

------------------------------------------------------------------------
-- Showing the lines on the canvas

-- Calls fn(x, y, i) for each pixel of a straight line, i counting from 0
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

-- Adds the points and handles to `want`, on top of the lines
local function addGuides(want)
  local s = S
  if panel and not panel.data.guides then return end
  local g = s.guide
  local function put(x, y, v)
    local k = overlayKey(s.ov, x, y)
    if k then want[k] = v end
  end
  for pi, p in ipairs(s.paths) do
    if pi ~= s.active then
      for _, n in ipairs(p.nodes) do put(n.x, n.y, g.other) end
    end
  end
  local p = s.paths[s.active]
  if p then
    for i, n in ipairs(p.nodes) do
      for _, side in ipairs({ "in", "out" }) do
        if hasHandle(n, side) and handleUsed(p, i, side) then
          local hx, hy = handlePos(n, side)
          hx, hy = round(hx), round(hy)
          -- Dotted line from the point to the end of the handle
          linePixels(n.x, n.y, hx, hy, function(x, y, j)
            if j % 2 == 0 then put(x, y, g.handle) end
          end)
          put(hx, hy, g.handle)
        end
      end
    end
    for i, n in ipairs(p.nodes) do
      put(n.x, n.y, i == s.selNode and g.selected or g.point)
    end
  end
end

-- Gives the frame a cel that covers the whole canvas, so the lines can be
-- shown anywhere. This is its own undo step, which is undone again when the
-- edit ends (if nothing else happened in between).
local function prepareCel()
  local s = S
  local sprite, layer, f = s.sprite, s.layer, s.frameNumber
  local cel = layer:cel(f)
  s.busy = true
  app.transaction(T.title, function()
    if cel then
      local b = cel.bounds
      local x0, y0 = math.min(0, b.x), math.min(0, b.y)
      local x1 = math.max(sprite.width, b.x + b.width)
      local y1 = math.max(sprite.height, b.y + b.height)
      local full = blankImage(sprite, x1 - x0, y1 - y0)
      full:drawImage(cel.image, Point(b.x - x0, b.y - y0))
      cel.image = full
      cel.position = Point(x0, y0)
    else
      sprite:newCel(layer, f, blankImage(sprite, sprite.width, sprite.height), Point(0, 0))
    end
  end)
  s.busy = false
  s.setup = true
  s.ov = newOverlay(layer:cel(f))
end

local function redraw()
  local s = S
  if not s.ov then
    if #s.paths == 0 then return end
    prepareCel()   -- the first point on a frame without a cel
  end
  local want = {}
  for _, p in ipairs(s.paths) do
    local v = outputPixel(s.sprite, p)
    plotPath(s.sprite, p, function(x, y)
      local k = overlayKey(s.ov, x, y)
      if k then want[k] = v end
    end)
  end
  addGuides(want)
  showOverlay(s.ov, want)
end

-- Shows the lines on the canvas and updates the panel
local function refresh()
  redraw()
  updateButtons()
  app.refresh()
end

local function snapshot()
  local s = S
  return { data = serialize(s.paths), active = s.active, sel = s.selNode }
end

-- Adds an undo step if the lines changed since `before`
local function pushUndo(before)
  local s = S
  if before.data == serialize(s.paths) then return false end
  s.undoStack[#s.undoStack + 1] = before
  s.redoStack = {}
  return true
end

-- Runs fn as one editing step. Consecutive steps with the same mergeKey
-- (e.g. dragging the width slider) become a single undo step.
local function edit(fn, mergeKey)
  local s = S
  local before = nil
  if not mergeKey or mergeKey ~= s.lastMerge then before = snapshot() end
  fn()
  if before then
    s.lastMerge = pushUndo(before) and mergeKey or nil
  end
  refresh()
end

local function restore(snap)
  local s = S
  s.paths = parse(snap.data)
  s.active, s.selNode = snap.active, snap.sel
  if not s.paths[s.active] then s.active, s.selNode = nil, nil end
  if s.active and s.selNode and not s.paths[s.active].nodes[s.selNode] then s.selNode = nil end
  s.lastMerge, s.press = nil, nil
  syncFields()
  refresh()
  askTimer:start()
end

local function undo()
  local s = S
  if #s.undoStack == 0 then return end
  s.redoStack[#s.redoStack + 1] = snapshot()
  restore(table.remove(s.undoStack))
end

local function redo()
  local s = S
  if #s.redoStack == 0 then return end
  s.undoStack[#s.undoStack + 1] = snapshot()
  restore(table.remove(s.redoStack))
end

local function deleteSelectedPoint()
  local s = S
  if s.paths[s.active] and s.selNode then
    edit(function() deleteNode(s.active, s.selNode) end)
    askTimer:start()
  end
end

------------------------------------------------------------------------
-- Clicks and drags on the canvas

-- How close (in sprite pixels) a click must be to grab something
local function tolerance()
  local ok, zoom = pcall(function() return S.editor.zoom end)
  if not ok or type(zoom) ~= "number" or zoom <= 0 then zoom = 8 end
  return math.max(0.5, HIT / zoom)
end

-- The point on a segment closest to (x, y): returns its t and the distance
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

-- Finds what's at the pixel (x, y): a handle, a point, or a line.
-- While a new line is being drawn, only that line can be grabbed.
local function hitTest(x, y)
  local s = S
  local tol = tolerance()
  local function grabbable(pi) return not s.newLine or pi == s.active end
  local best, bestD = nil, math.huge
  local function consider(d, hit)
    if d <= tol and d < bestD then best, bestD = hit, d end
  end

  -- Handles of the selected line (unless they're on their own point)
  local p = s.paths[s.active]
  if p then
    for i, n in ipairs(p.nodes) do
      for _, side in ipairs({ "out", "in" }) do
        if hasHandle(n, side) and handleUsed(p, i, side) then
          local hx, hy = handlePos(n, side)
          if round(hx) ~= n.x or round(hy) ~= n.y then
            consider(dist(x, y, hx, hy) + 0.01, { kind = "handle", path = s.active, node = i, side = side })
          end
        end
      end
    end
  end

  -- Points (the selected line wins a tie)
  for pi, q in ipairs(s.paths) do
    local bias = pi == s.active and 0 or 0.02
    if grabbable(pi) then
      for i, n in ipairs(q.nodes) do
        consider(dist(x, y, n.x, n.y) + bias, { kind = "anchor", path = pi, node = i })
      end
    end
  end
  if best then return best end

  -- Lines: a click on one of their pixels, or close to the curve
  for pi, q in ipairs(s.paths) do
    local onPixel = false
    if grabbable(pi) then
      plotPath(s.sprite, q, function(px, py)
        if px == x and py == y then onPixel = true end
      end)
    end
    for _, sg in ipairs(grabbable(pi) and segments(q) or {}) do
      local t, d = nearestOnSegment(sg[1], sg[2], x, y)
      if pi ~= s.active then d = d + 0.02 end
      if (onPixel or d <= tol) and d < bestD then
        best, bestD = { kind = "segment", path = pi, seg = sg[3], t = t }, d
      end
    end
  end
  return best
end

-- Adds a point to the end of the selected line, or starts a new line
local function addPoint(x, y)
  local s = S
  local p = s.paths[s.active]
  if not p or p.closed then
    local color, width, perfect = app.fgColor, 1, true
    if panel then
      local d = panel.data
      color, width, perfect = d.color, d.width, d.pixelPerfect
    end
    p = { color = colorToTable(color), width = width, pixelPerfect = perfect,
          closed = false, nodes = {} }
    s.paths[#s.paths + 1] = p
    select(#s.paths, nil)
  end
  p.nodes[#p.nodes + 1] = { x = x, y = y, ix = 0, iy = 0, ox = 0, oy = 0, smooth = false }
  s.selNode = #p.nodes
  return { kind = "anchor", path = s.active, node = s.selNode }
end

-- The mouse button went down at (x, y): decide what the drag will do
local function startGesture(x, y)
  local s = S
  s.lastMerge = nil
  local before = snapshot()
  local hit = hitTest(x, y)
  if hit and hit.kind == "handle" then
    select(hit.path, hit.node)
    local hx, hy = handlePos(s.paths[hit.path].nodes[hit.node], hit.side)
    s.press = { kind = "handle", hit = hit, before = before, sx = x, sy = y, hx = hx, hy = hy }
  elseif hit and hit.kind == "anchor" then
    select(hit.path, hit.node)
    local n = s.paths[hit.path].nodes[hit.node]
    s.press = { kind = "anchor", hit = hit, before = before, sx = x, sy = y, x = n.x, y = n.y }
  elseif hit then
    select(hit.path, nil)
    local orig = {}
    for i, n in ipairs(s.paths[hit.path].nodes) do orig[i] = { n.x, n.y } end
    s.press = { kind = "segment", hit = hit, before = before, sx = x, sy = y, orig = orig }
  else
    s.press = { kind = "pull", hit = addPoint(x, y), before = before }
  end
end

local function dragTo(x, y)
  local s = S
  local d = s.press
  local n = d.hit.node and s.paths[d.hit.path].nodes[d.hit.node]
  if d.kind == "anchor" then
    n.x, n.y = d.x + x - d.sx, d.y + y - d.sy
  elseif d.kind == "handle" then
    moveHandle(n, d.hit.side, d.hx + x - d.sx, d.hy + y - d.sy, panel and panel.data.oneSide)
  elseif d.kind == "pull" then
    if x == n.x and y == n.y then
      n.ix, n.iy, n.ox, n.oy, n.smooth = 0, 0, 0, 0, false
    else
      pullHandles(n, x, y)
    end
  elseif d.kind == "segment" then
    -- Clicking a line adds a point, dragging it moves the whole line
    if x ~= d.sx or y ~= d.sy then d.moved = true end
    if d.moved then
      for i, m in ipairs(s.paths[d.hit.path].nodes) do
        m.x, m.y = d.orig[i][1] + x - d.sx, d.orig[i][2] + y - d.sy
      end
    end
  end
end

local function endGesture(x, y, dragged)
  local s = S
  local d = s.press
  if dragged then dragTo(x, y) end
  s.press = nil
  if d.kind == "segment" and not d.moved then
    select(d.hit.path, insertNode(s.paths[d.hit.path], d.hit.seg, d.hit.t))
  end
  pushUndo(d.before)
  refresh()
end

-- While the button is held: called on every mouse move
local function onChange(ev)
  local s = S
  if not s or s.finished then return end
  local pt = ev.point
  if not s.press then startGesture(pt.x, pt.y) end
  dragTo(pt.x, pt.y)
  redraw()
end

-- The button was released
local function onClick(ev)
  local s = S
  if not s or s.finished then return end
  local pt = ev.point
  if s.press then
    endGesture(pt.x, pt.y, true)
  else
    startGesture(pt.x, pt.y)
    endGesture(pt.x, pt.y, false)
  end
  -- askPoint() ends after each click, so ask again (it can't be done from here)
  askTimer:start()
end

-- Esc cancels the drag, or deselects the line
local function onCancel()
  local s = S
  if not s or s.finished then return end
  if s.press then
    local before = s.press.before
    s.press = nil
    restore(before)
  elseif s.active or s.newLine then
    s.newLine = false
    select(nil, nil)
    syncFields()
    refresh()
  end
  askTimer:start()
end

local function ask()
  local s = S
  if not s or s.finished or app.editor ~= s.editor then return end
  local p = s.paths[s.active]
  local n = p and s.selNode and p.nodes[s.selNode]
  -- `point` outlines the selected point
  s.editor:askPoint{ title = s.newLine and T.hintNew or T.hint, point = n and Point(n.x, n.y) or nil,
                     onchange = onChange, onclick = onClick, oncancel = onCancel }
end

------------------------------------------------------------------------
-- Sessions

local openPanel, closePanel

-- Starts editing the active curve layer. Without `force`, frames that were
-- changed by hand are left alone. Returns "started", "edited" or nil.
local function startSession(force)
  local sprite, layer, frame, editor = app.sprite, app.layer, app.frame, app.editor
  if not (sprite and layer and frame and editor) then return end
  if not isCurveLayer(layer) then
    if force then app.alert{ title = T.title, text = T.notCurveLayer } end
    return
  end
  if not layer.isEditable or not layer.isVisible then
    if force then app.alert{ title = T.title, text = T.locked } end
    return
  end
  if editor.sprite ~= sprite then return end

  local f = frame.frameNumber
  local cel = layer:cel(f)
  local paths, original = {}, ""
  if cel then
    local data = cel.properties(KEY)
    if type(data.paths) == "string" then
      paths = parse(data.paths)
      local same, dx, dy = compareWithLines(sprite, cel, paths)
      if same then
        -- If the cel was moved (e.g. with the Move tool), move the lines with it
        for _, p in ipairs(paths) do
          for _, n in ipairs(p.nodes) do n.x, n.y = n.x + dx, n.y + dy end
        end
        original = serialize(paths)
      else
        if not force then return "edited" end
        local r = app.alert{ title = T.title, text = T.handEdited, buttons = { T.continue, T.cancel } }
        if r ~= 1 then return end
        original = nil   -- redraw the frame even without changes
      end
    elseif not cel.image:isEmpty() then
      if not force then return "edited" end
      local r = app.alert{ title = T.title, text = T.extraPixels, buttons = { T.continue, T.cancel } }
      if r ~= 1 then return end
    end
  end

  local s = {
    sprite = sprite, layer = layer, frameNumber = f, editor = editor,
    paths = paths, original = original,
    active = nil, selNode = nil, press = nil,
    undoStack = {}, redoStack = {}, lastMerge = nil,
    guide = {
      point = guidePixel(sprite, 0, 255, 0),        -- points of the selected line
      selected = guidePixel(sprite, 200, 255, 200), -- the selected point
      handle = guidePixel(sprite, 0, 255, 0),       -- handles
      other = guidePixel(sprite, 0, 170, 0),        -- points of the other lines
    },
  }
  S = s
  lastSkip = nil

  if cel then
    if coversCanvas(sprite, cel) then
      s.ov = newOverlay(cel)
    else
      prepareCel()
    end
  end

  s.changeId = sprite.events:on("change", function(ev)
    if s.finished or s.busy then return end
    -- Something else changed the sprite: apply the edit on the next tick
    s.externalChange = true
    if ev.fromUndo then s.historyMoved = true end
    scheduleTick()
  end)

  openPanel()
  syncFields()
  refresh()
  ask()
  return "started"
end

-- Ends the session and puts the edit in the undo history.
-- canUndo: the setup step may be undone with the Undo command.
local function finishSession(canUndo)
  local s = S
  if not s or s.finished then return end
  s.finished = true
  s.press = nil
  askTimer:stop()
  if s.changeId then
    -- Listeners can't be removed while an event is being sent
    removals[#removals + 1] = { s.sprite.events, s.changeId }
    scheduleTick()
  end

  local ok, err = pcall(function()
    if not pcall(function() return s.sprite.width end) then return end   -- the sprite was closed

    -- Work on the edited sprite even if the user moved somewhere else
    local keepSprite, keepLayer, keepFrame = app.sprite, app.layer, app.frame
    local switched = keepSprite ~= s.sprite
    if switched then app.sprite = s.sprite end
    if app.editor == s.editor then s.editor:cancel() end
    -- Record the edit on its own layer and frame, so undoing it goes back there
    pcall(function() app.layer = s.layer end)
    pcall(function() app.frame = s.frameNumber end)

    -- Put the pixels back as they were before the lines were shown
    if s.ov then pcall(restoreOverlay, s.ov) end

    -- If the undo history was moved (e.g. in the Undo History panel), leave it as it is
    if not s.historyMoved then
      local result = serialize(s.paths)
      if s.setup and canUndo and not s.externalChange then
        app.command.Undo()   -- the setup step is still the last one
      end
      if result ~= s.original then
        app.transaction(T.title, function()
          local c = s.layer:cel(s.frameNumber)
          if #s.paths == 0 then
            if c then s.sprite:deleteCel(c) end
          else
            local img = renderPaths(s.sprite, s.paths)
            if c then
              c.image = img
              c.position = Point(0, 0)
            else
              c = s.sprite:newCel(s.layer, s.frameNumber, img, Point(0, 0))
            end
            c.properties(KEY, { version = 2, paths = result })
          end
        end)
      end
    end

    -- Go back to where the user was (undoing may have moved the active layer or frame)
    if switched then
      app.sprite = keepSprite
    else
      if keepLayer and app.layer ~= keepLayer then pcall(function() app.layer = keepLayer end) end
      if keepFrame and app.frame and app.frame.frameNumber ~= keepFrame.frameNumber then
        pcall(function() app.frame = keepFrame end)
      end
    end
  end)

  S = nil
  app.refresh()
  if not ok then
    app.alert{ title = T.title, text = { T.error, tostring(err) } }
  end
end

-- "Stop Editing": apply, and leave the layer alone until it's selected again
local function stopEditing()
  local s = S
  if not s or s.finished then return end
  local layer = s.layer
  finishSession(true)
  paused = { layer = layer }
  closePanel()
  tip(T.stoppedTip)
end

------------------------------------------------------------------------
-- Panel

local function changeStyle(key, apply)
  local s = S
  if panel then
    -- Remember the width and pixel-perfect settings for next time
    prefs.width = panel.data.width
    prefs.pixelPerfect = panel.data.pixelPerfect
  end
  if not s or s.finished or s.syncing then return end
  local p = s.paths[s.active]
  if p then edit(function() apply(p) end, key .. s.active) end
end

local function whenEditing(fn)
  return function()
    local s = S
    if s and not s.finished then fn(s) end
  end
end

openPanel = function()
  if panel then return end
  local dlg
  dlg = Dialog{ title = T.title, onclose = function()
    if panel ~= dlg then return end   -- closed by closePanel()
    panel = nil
    stopEditing()
  end }
  dlg:label{ text = T.help1 }
     :newrow()
     :label{ text = T.help2 }
     :separator{ id = "styleSep", text = T.nextLine }
     :color{ id = "color", label = T.color, color = app.fgColor,
             onchange = function()
               changeStyle("color", function(p) p.color = colorToTable(dlg.data.color) end)
             end }
     :slider{ id = "width", label = T.width, min = 1, max = 32, value = prefs.width or 1,
              onchange = function()
                changeStyle("width", function(p) p.width = dlg.data.width end)
              end }
     :check{ id = "pixelPerfect", label = "", text = T.pixelPerfect, selected = prefs.pixelPerfect ~= false,
             onclick = function()
               changeStyle("pixelPerfect", function(p) p.pixelPerfect = dlg.data.pixelPerfect end)
             end }
     :check{ id = "closed", text = T.closed, selected = false,
             onclick = function()
               changeStyle("closed", function(p) p.closed = dlg.data.closed end)
             end }
     :check{ id = "oneSide", label = "", text = T.oneSide, selected = false }
     :check{ id = "guides", text = T.guides, selected = true,
             onclick = whenEditing(function() refresh() end) }
     :separator{}
     :button{ id = "newLine", text = T.newLine,
              onclick = whenEditing(function(s)
                -- Until Esc, clicks only draw the new line (other lines can't be grabbed)
                s.newLine = true
                select(nil, nil)
                syncFields()
                refresh()
                askTimer:start()
              end) }
     :button{ id = "deleteLine", text = T.deleteLine,
              onclick = whenEditing(function(s)
                if not s.paths[s.active] then return end
                local pi = s.active
                edit(function()
                  table.remove(s.paths, pi)
                  s.newLine = false
                  select(nil, nil)
                end)
                syncFields()
                askTimer:start()
              end) }
     :newrow()
     :button{ id = "deletePoint", text = T.deletePoint, onclick = whenEditing(deleteSelectedPoint) }
     :button{ id = "roundSharp", text = T.roundSharp,
              onclick = whenEditing(function(s)
                if not (s.paths[s.active] and s.selNode) then return end
                local p, i = s.paths[s.active], s.selNode
                edit(function() toggleRound(p, i) end)
              end) }
     :newrow()
     :button{ id = "undo", text = T.undo, onclick = whenEditing(undo) }
     :button{ id = "redo", text = T.redo, onclick = whenEditing(redo) }
     :separator{}
     :button{ id = "stop", text = T.stop, onclick = stopEditing }
  panel = dlg
  dlg:show{ wait = false }

  -- Keep the panel out of the way: where it was last time, or at the right edge
  local b = dlg.bounds
  if prefs.panelX and prefs.panelY then
    dlg.bounds = Rectangle(prefs.panelX, prefs.panelY, b.width, b.height)
  elseif app.window then
    dlg.bounds = Rectangle(math.max(0, app.window.width - b.width - 24), 72, b.width, b.height)
  end
end

closePanel = function()
  local dlg = panel
  if not dlg then return end
  panel = nil
  pcall(function()
    local b = dlg.bounds
    prefs.panelX, prefs.panelY = b.x, b.y
  end)
  dlg:close()
end

------------------------------------------------------------------------
-- Watching the active layer

-- Runs a moment after something changed: ends the session when the user
-- moved away, runs a held command, and starts a session on a curve layer
local function tick()
  tickTimer:stop()

  local list = removals
  removals = {}
  for _, r in ipairs(list) do pcall(function() r[1]:off(r[2]) end) end

  local s = S
  if s and not s.finished then
    local moved = app.sprite ~= s.sprite or app.layer ~= s.layer or app.editor ~= s.editor
                  or not app.frame or app.frame.frameNumber ~= s.frameNumber
    if moved or s.externalChange or pending then finishSession(true) end
  end

  if pending then
    local cmd = pending
    pending = nil
    -- Don't edit while the animation plays (it would stop the playback)
    if cmd.name == "PlayAnimation" and app.layer then paused = { layer = app.layer, play = true } end
    local run = app.command[cmd.name]
    if run then
      rerunning = true
      pcall(run, cmd.params)
      rerunning = false
    end
  end

  if paused and app.layer ~= paused.layer then paused = nil end
  if not S and not paused then
    local r = startSession(false)
    if r == "edited" then
      local layer, frame = app.layer, app.frame
      if not (lastSkip and lastSkip.layer == layer and lastSkip.frame == frame.frameNumber) then
        lastSkip = { layer = layer, frame = frame.frameNumber }
        tip(T.skippedTip)
      end
    end
  end
  if not S then closePanel() end
end

local function onBeforeCommand(ev)
  local s = S
  local name = ev.name
  if not s or s.finished then
    -- Playing again stops the playback: editing can start again
    if paused and paused.play and name == "PlayAnimation" and not rerunning then paused = nil end
    return
  end
  local here = app.sprite == s.sprite
  if here and name == "Undo" and #s.undoStack > 0 then
    undo()
    ev.stopPropagation()
  elseif here and name == "Redo" and #s.redoStack > 0 then
    redo()
    ev.stopPropagation()
  elseif here and name == "Clear" then
    -- Delete/Backspace deletes the selected point instead of clearing pixels
    deleteSelectedPoint()
    ev.stopPropagation()
  elseif not VIEW_COMMANDS[name] then
    -- Hold the command back, apply the edit, then run the command again.
    -- (Applying right here would leave the setup step in the undo history.)
    if not pending then pending = { name = name, params = ev.params } end
    ev.stopPropagation()
    scheduleTick()
  end
end

------------------------------------------------------------------------
-- Menu commands

local function newCurveLayer()
  local sprite = app.sprite
  if not sprite then return end
  local src = app.layer
  app.transaction(T.newLayerCmd, function()
    local layer = sprite:newLayer()
    layer.name = newLayerName(sprite)
    if src then
      layer.parent = src.parent
      layer.stackIndex = src.stackIndex + 1
    end
    layer.properties(KEY).curve = true
    app.layer = layer
  end)
  paused = nil
  scheduleTick()
end

local function editCurves()
  paused = nil
  lastSkip = nil
  if S then return end
  startSession(true)
end

function init(plugin)
  if not app.isUIAvailable then return end
  prefs = plugin.preferences

  local ok, lang = pcall(function() return app.preferences.general.language end)
  if ok and type(lang) == "string" and lang:sub(1, 2) == "ja" then T = TEXT.ja end

  askTimer = Timer{ interval = 0.01, ontick = function()
    askTimer:stop()
    ask()
  end }
  tickTimer = Timer{ interval = 0.01, ontick = tick }

  local function hasSprite() return app.sprite ~= nil end
  local function onCurveLayer() return isCurveLayer(app.layer) end
  plugin:newCommand{ id = "BezierCurveNewLayer", title = T.newLayerCmd, group = "layer_new",
                     onenabled = hasSprite, onclick = newCurveLayer }
  plugin:newCommand{ id = "BezierCurveNewLayerPopup", title = T.newLayerCmd, group = "layer_popup_new",
                     onenabled = hasSprite, onclick = newCurveLayer }
  plugin:newCommand{ id = "BezierCurveEdit", title = T.editCmd, group = "layer_properties",
                     onenabled = onCurveLayer, onclick = editCurves }
  plugin:newCommand{ id = "BezierCurveEditPopup", title = T.editCmd, group = "layer_popup_properties",
                     onenabled = onCurveLayer, onclick = editCurves }

  listeners = {
    app.events:on("beforecommand", onBeforeCommand),
    app.events:on("aftercommand", scheduleTick),
    app.events:on("sitechange", scheduleTick),
  }
  scheduleTick()
end

function exit(plugin)
  if S then pcall(finishSession, false) end
  S = nil
  closePanel()
  for _, id in ipairs(listeners) do pcall(function() app.events:off(id) end) end
  listeners = {}
  if askTimer then askTimer:stop() end
  if tickTimer then tickTimer:stop() end
end
