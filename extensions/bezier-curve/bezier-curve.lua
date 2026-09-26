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
    rasterizeCmd = "Rasterize Curve Layer",
    rasterize = "Rasterize",
    rasterizedTip = "The curve layer is now a normal layer. Edit > Undo brings the lines back.",
    layerName = "Curve",
    hint = "Bezier Curve: click to add points, drag points or handles to edit them",
    hintDrawing = "Bezier Curve: drawing a shape (other shapes can't be grabbed). Click its first point to close it; Esc, Enter or click its last point: done",
    help1 = "Click to add points, drag points or handles to bend.",
    help2 = "Click a line to select it, again to add a point. Del: delete the selected point or shape.",
    nextShape = "Next Shape",
    selectedShape = "Selected Shape",
    drawingShape = "Drawing a Shape (Esc/Enter: done)",
    -- The line and fill settings are grouped under their own headings, so
    -- their labels are indented
    lineGroup = "Line",
    fillGroup = "Fill",
    color = "   Color",
    width = "   Width",
    pixelPerfect = "Pixel-perfect (width 1)",
    antialias = "Antialias (smooth edges)",
    antialiasIndexed = "Antialias (RGB and Grayscale only)",
    closed = "Connect the ends",
    stroke = "Draw the line",
    fill = "Fill the inside",
    fillColor = "   Color",
    oneSide = "Move one handle only",
    guides = "Show guides",
    newShape = "Draw New",
    place = "Place Shape...",
    placeTitle = "Place Shape",
    shapeKind = "Shape",
    shapes = { ellipse = "Circle", rect = "Rectangle", roundRect = "Rounded Rectangle",
               triangle = "Triangle", polygon = "Polygon", star = "Star" },
    sides = "Corners",
    rounding = "Rounding (%)",
    sameSize = "Same width and height (circle, square...)",
    placingShape = "Placing a Shape (drag; Esc: cancel)",
    hintPlace = "Bezier Curve: drag to place the shape (a click places it at a default size). Esc: cancel",
    deleteShape = "Delete Shape",
    copy = "Copy",
    paste = "Paste",
    copiedOne = "Copied 1 shape. Paste it in any frame, layer or sprite.",
    copiedMany = "Copied %d shapes. Paste them in any frame, layer or sprite.",
    deletePoint = "Delete Point",
    roundSharp = "Round/Sharp",
    undo = "Undo",
    redo = "Redo",
    stop = "Close",
    transformAll = "Transform (all shapes)",
    transformSelected = "Transform (selected shape)",
    transformBox = "Transform Box",
    endTransform = "End Transform",
    numeric = "Numeric...",
    flipH = "Flip Horizontal",
    flipV = "Flip Vertical",
    rotateLeft = "Rotate Left 90°",
    rotateRight = "Rotate Right 90°",
    keepRatio = "Keep proportions (corner handles)",
    hintScale = "Transform: drag the squares to scale, inside to move. Click inside: rotate/shear. Enter, Esc or click outside: done",
    hintRotate = "Transform: drag the circles to rotate, the diamonds to shear, the cross to move the center. Click inside: scale. Enter, Esc or click outside: done",
    numericTitle = "Transform",
    scaleX = "Width (%)",
    scaleY = "Height (%)",
    rotate = "Rotate (°, clockwise)",
    shearX = "Shear horizontally (°)",
    shearY = "Shear vertically (°)",
    ok = "OK",
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
    rasterizeCmd = "曲線レイヤーをラスタライズ",
    rasterize = "ラスタライズ",
    rasterizedTip = "曲線レイヤーを普通のレイヤーにしました。編集 > 元に戻す で線のデータも戻せます。",
    layerName = "曲線",
    hint = "ベジェ曲線: クリックで点を追加、点やハンドルをドラッグで編集",
    hintDrawing = "ベジェ曲線: 図形を描いています(ほかの図形はつかめません)。始点をクリックで閉じる、Esc・Enter・最後の点をクリックで終了",
    help1 = "クリックで点を追加、点やハンドルをドラッグで曲げる",
    help2 = "線をクリックで選択(選択中なら点を追加) / Del: 選択中の点か図形を削除",
    nextShape = "次に描く図形",
    selectedShape = "選択中の図形",
    drawingShape = "図形を描画中(Esc / Enter で終了)",
    lineGroup = "線",
    fillGroup = "塗り",
    color = "　色",
    width = "　太さ",
    pixelPerfect = "ピクセルパーフェクト(太さ1のとき)",
    antialias = "アンチエイリアス(縁をなめらかに)",
    antialiasIndexed = "アンチエイリアス(RGB・グレースケールのみ)",
    closed = "始点と終点をつなぐ",
    stroke = "線を描く",
    fill = "内側を塗りつぶす",
    fillColor = "　色",
    oneSide = "ハンドルを片側だけ動かす",
    guides = "ガイドを表示",
    newShape = "新しく作図",
    place = "図形を配置…",
    placeTitle = "図形を配置",
    shapeKind = "形",
    shapes = { ellipse = "円", rect = "四角", roundRect = "角丸四角",
               triangle = "三角", polygon = "多角形", star = "星" },
    sides = "角の数",
    rounding = "角の丸み(%)",
    sameSize = "縦横を同じにする(正円・正方形など)",
    placingShape = "図形を配置中(ドラッグで配置、Esc でやめる)",
    hintPlace = "ベジェ曲線: ドラッグで図形を配置(クリックで標準の大きさ)。Esc でやめる",
    deleteShape = "図形を削除",
    copy = "コピー",
    paste = "貼り付け",
    copiedOne = "図形を1個コピーしました。ほかのフレーム・レイヤー・スプライトにも貼り付けられます。",
    copiedMany = "図形を%d個コピーしました。ほかのフレーム・レイヤー・スプライトにも貼り付けられます。",
    deletePoint = "点を削除",
    roundSharp = "丸/角",
    undo = "元に戻す",
    redo = "やり直す",
    stop = "閉じる",
    transformAll = "変形(すべての図形)",
    transformSelected = "変形(選択中の図形)",
    transformBox = "変形ボックス",
    endTransform = "変形を終える",
    numeric = "数値で変形...",
    flipH = "左右反転",
    flipV = "上下反転",
    rotateLeft = "左に90°回転",
    rotateRight = "右に90°回転",
    keepRatio = "縦横比を保つ(角のハンドル)",
    hintScale = "変形: 四角をドラッグで拡大縮小、内側をドラッグで移動。内側をクリックで回転・シアーに切り替え。Enter・Esc・外側をクリックで終了",
    hintRotate = "変形: 丸をドラッグで回転、ひし形でシアー、十字で中心を移動。内側をクリックで拡大縮小に切り替え。Enter・Esc・外側をクリックで終了",
    numericTitle = "数値で変形",
    scaleX = "横幅(%)",
    scaleY = "高さ(%)",
    rotate = "回転(°、時計回り)",
    shearX = "横に傾ける(°)",
    shearY = "縦に傾ける(°)",
    ok = "OK",
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
-- A line can also fill its inside (fill, fillColor). An open line is filled
-- as if its ends were joined by a straight line. With stroke off, only the
-- fill is drawn. With antialias on, the edges of the line and the fill are
-- smoothed with partly transparent pixels.
-- A line can also keep a center (pivot) for rotating and shearing it, and
-- the list of lines can keep one for transforming all of them together.

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
  local function pivot(pv)
    if pv then lines[#lines + 1] = string.format("pivot %d %d", pv.x, pv.y) end
  end
  pivot(paths.pivot)
  for _, p in ipairs(paths) do
    local c, f = p.color, p.fillColor or p.color
    lines[#lines + 1] = string.format("path %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d",
      c.r, c.g, c.b, c.a, c.index, p.width, p.closed and 1 or 0, p.pixelPerfect and 1 or 0,
      p.fill and 1 or 0, f.r, f.g, f.b, f.a, f.index, p.stroke == false and 0 or 1,
      p.antialias and 1 or 0)
    pivot(p.pivot)
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
      local color = { r = floor(num(2)), g = floor(num(3)), b = floor(num(4)), a = floor(num(5)), index = floor(num(6)) }
      cur = {
        color = color,
        width = math.max(1, floor(num(7))),
        closed = num(8) == 1,
        pixelPerfect = num(9) == 1,
        -- Older data has no fill fields (no fill, line drawn)
        fill = num(10) == 1,
        stroke = v[16] == nil or num(16) == 1,
        antialias = num(17) == 1,
        fillColor = v[15] and { r = floor(num(11)), g = floor(num(12)), b = floor(num(13)),
                                a = floor(num(14)), index = floor(num(15)) }
                    or { r = color.r, g = color.g, b = color.b, a = color.a, index = color.index },
        nodes = {},
      }
      paths[#paths + 1] = cur
    elseif v[1] == "pivot" then
      -- After a path line: that line's center; before any: the one for all lines
      local pv = { x = floor(num(2)), y = floor(num(3)) }
      if cur then cur.pivot = pv else paths.pivot = pv end
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

-- Removes the extra pixel from L-shaped corners so 1px lines look clean.
-- Pixels in `keep` (the line's own points, e.g. the corners of a square)
-- are never removed.
local function pixelPerfect(xs, ys, keep)
  local n = #xs
  if n < 3 then return xs, ys end
  local rx, ry = { xs[1] }, { ys[1] }
  for i = 2, n - 1 do
    local ax, ay = rx[#rx], ry[#ry]
    local bx, by, cx, cy = xs[i], ys[i], xs[i + 1], ys[i + 1]
    local corner = (ax == bx or ay == by) and (cx == bx or cy == by)
                   and ax ~= cx and ay ~= cy
    if not corner or keep[bx .. "," .. by] then rx[#rx + 1], ry[#ry + 1] = bx, by end
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
  if p.width == 1 and p.pixelPerfect then
    local keep = {}
    for _, n in ipairs(p.nodes) do keep[n.x .. "," .. n.y] = true end
    xs, ys = pixelPerfect(xs, ys, keep)
  end
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

-- Calls fn(x, y) for every pixel of the canvas whose center is inside the
-- line (nonzero winding rule). An open line is closed with a straight line.
local function fillPath(sprite, p, fn)
  if #p.nodes < 2 then return end
  -- The outline as a polygon
  local pts = { { p.nodes[1].x, p.nodes[1].y } }
  for _, sg in ipairs(segments(p)) do
    local a, b = sg[1], sg[2]
    local len = dist(a.x, a.y, a.x + a.ox, a.y + a.oy)
              + dist(a.x + a.ox, a.y + a.oy, b.x + b.ix, b.y + b.iy)
              + dist(b.x + b.ix, b.y + b.iy, b.x, b.y)
    local steps = math.max(1, math.ceil(len * 2))
    for i = 1, steps do
      local x, y = bezier(a, b, i / steps)
      pts[#pts + 1] = { x, y }
    end
  end
  local n = #pts
  local top, bottom = math.huge, -math.huge
  for _, q in ipairs(pts) do
    if q[2] < top then top = q[2] end
    if q[2] > bottom then bottom = q[2] end
  end
  local W = sprite.width
  for y = math.max(0, math.ceil(top)), math.min(sprite.height - 1, floor(bottom)) do
    -- Look just above and just below the row's center, so pixels on the
    -- top and bottom edges of the shape are filled too
    local done = {}
    for _, yy in ipairs({ y - 0.001, y + 0.001 }) do
      -- Where the edges cross, and in which direction
      local xs = {}
      for i = 1, n do
        local a, b = pts[i], pts[i % n + 1]
        if (a[2] <= yy and b[2] > yy) or (b[2] <= yy and a[2] > yy) then
          local t = (yy - a[2]) / (b[2] - a[2])
          xs[#xs + 1] = { a[1] + t * (b[1] - a[1]), b[2] > a[2] and 1 or -1 }
        end
      end
      table.sort(xs, function(u, v) return u[1] < v[1] end)
      local winding = 0
      for i = 1, #xs - 1 do
        winding = winding + xs[i][2]
        if winding ~= 0 then
          for x = math.max(0, math.ceil(xs[i][1] - 0.001)), math.min(W - 1, floor(xs[i + 1][1] + 0.001)) do
            if not done[x] then
              done[x] = true
              fn(x, y)
            end
          end
        end
      end
    end
  end
end

-- Pixel value of a color in the sprite's color mode
local function colorPixel(sprite, c)
  if sprite.colorMode == ColorMode.INDEXED then
    return c.index
  elseif sprite.colorMode == ColorMode.GRAY then
    return pc.graya(grayOf(c), c.a)
  end
  return pc.rgba(c.r, c.g, c.b, c.a)
end

------------------------------------------------------------------------
-- Antialiasing
--
-- An antialiased line gives each pixel an alpha by how much of the pixel
-- the line (or fill) covers, and blends it over what's already drawn.
-- Indexed images can't have partly transparent pixels, so there the line
-- is drawn without antialiasing.

local function antialiased(sprite, p)
  return p.antialias and sprite.colorMode ~= ColorMode.INDEXED
end

-- The path as a list of points joined by straight lines, which stay within
-- 0.02 pixels of the curve
local function flatten(p)
  local pts = { { p.nodes[1].x, p.nodes[1].y } }
  for _, sg in ipairs(segments(p)) do
    local a, b = sg[1], sg[2]
    -- How sharply the curve can bend, which sets how many pieces it needs
    local p1x, p1y, p2x, p2y = a.x + a.ox, a.y + a.oy, b.x + b.ix, b.y + b.iy
    local bend = math.max(dist(0, 0, a.x - 2 * p1x + p2x, a.y - 2 * p1y + p2y),
                          dist(0, 0, p1x - 2 * p2x + b.x, p1y - 2 * p2y + b.y))
    local steps = math.max(1, math.min(1000, math.ceil(sqrt(37.5 * bend))))
    for i = 1, steps do
      local x, y = bezier(a, b, i / steps)
      pts[#pts + 1] = { x, y }
    end
  end
  return pts
end

-- Calls fn(x, y, coverage) for every pixel of the canvas the line touches,
-- with how much of the pixel it covers (0..1)
local function coverPath(sprite, p, fn)
  local pts = flatten(p)
  local reach = p.width / 2 + 0.5   -- pixels whose center is closer than this are touched
  local W, H = sprite.width, sprite.height
  local near = {}                   -- squared distance from each pixel to the line
  local function visit(ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local l2 = dx * dx + dy * dy
    for y = math.max(0, math.ceil(math.min(ay, by) - reach)), math.min(H - 1, floor(math.max(ay, by) + reach)) do
      for x = math.max(0, math.ceil(math.min(ax, bx) - reach)), math.min(W - 1, floor(math.max(ax, bx) + reach)) do
        local u = 0
        if l2 > 0 then u = math.max(0, math.min(1, ((x - ax) * dx + (y - ay) * dy) / l2)) end
        local ex, ey = x - ax - u * dx, y - ay - u * dy
        local d2, k = ex * ex + ey * ey, y * W + x
        if not near[k] or d2 < near[k] then near[k] = d2 end
      end
    end
  end
  if #pts == 1 then visit(pts[1][1], pts[1][2], pts[1][1], pts[1][2]) end
  for i = 1, #pts - 1 do visit(pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2]) end
  for k, d2 in pairs(near) do
    local c = reach - sqrt(d2)
    if c > 0 then fn(k % W, k // W, math.min(1, c)) end
  end
end

-- Calls fn(x, y, coverage) for every pixel of the canvas the inside of the
-- line touches (nonzero winding rule), with how much of the pixel is inside
local FILL_SAMPLES = 8   -- rows looked at in each pixel row
local function coverFill(sprite, p, fn)
  if #p.nodes < 2 then return end
  local pts = flatten(p)
  local n, W, H = #pts, sprite.width, sprite.height
  -- The edges, listed under each pixel row they reach
  local rows = {}
  for i = 1, n do
    local a, b = pts[i], pts[i % n + 1]
    if a[2] ~= b[2] then
      local e = { a[1], a[2], b[1], b[2], b[2] > a[2] and 1 or -1 }
      for y = math.max(0, floor(math.min(a[2], b[2]))), math.min(H - 1, math.ceil(math.max(a[2], b[2]))) do
        local list = rows[y]
        if not list then list = {}; rows[y] = list end
        list[#list + 1] = e
      end
    end
  end
  for y, edges in pairs(rows) do
    local part, full = {}, {}   -- coverage of pixels partly covered, and runs of full ones
    local lo, hi = math.huge, -math.huge
    local w = 1 / FILL_SAMPLES
    local function span(xa, xb)
      xa, xb = math.max(xa, -0.5), math.min(xb, W - 0.5)
      if xb <= xa then return end
      local i0, i1 = floor(xa + 0.5), floor(xb + 0.5)   -- pixel x covers x-0.5 .. x+0.5
      if i0 == i1 then
        part[i0] = (part[i0] or 0) + (xb - xa) * w
      else
        part[i0] = (part[i0] or 0) + (i0 + 0.5 - xa) * w
        part[i1] = (part[i1] or 0) + (xb - i1 + 0.5) * w
        full[i0 + 1] = (full[i0 + 1] or 0) + w
        full[i1] = (full[i1] or 0) - w
      end
      if i0 < lo then lo = i0 end
      if i1 > hi then hi = i1 end
    end
    for s = 0, FILL_SAMPLES - 1 do
      local yy = y - 0.5 + (s + 0.5) * w
      local xs = {}
      for _, e in ipairs(edges) do
        if (e[2] <= yy and e[4] > yy) or (e[4] <= yy and e[2] > yy) then
          xs[#xs + 1] = { e[1] + (yy - e[2]) / (e[4] - e[2]) * (e[3] - e[1]), e[5] }
        end
      end
      table.sort(xs, function(u, v) return u[1] < v[1] end)
      local winding = 0
      for i = 1, #xs - 1 do
        winding = winding + xs[i][2]
        if winding ~= 0 then span(xs[i][1], xs[i + 1][1]) end
      end
    end
    local run = 0
    for x = lo, math.min(hi, W - 1) do
      run = run + (full[x] or 0)
      local c = run + (part[x] or 0)
      if c > 0.0001 then fn(x, y, math.min(1, c)) end
    end
  end
end

-- Pixel value of color c covering part of a pixel (0..1) over the pixel
-- value `under`, or nil if nothing would show
local function blendPixel(sprite, c, cover, under)
  local a = round(c.a * cover)
  if a <= 0 then return nil end
  local sa, gray = a / 255, sprite.colorMode == ColorMode.GRAY
  local ua = 0
  if under then ua = (gray and pc.grayaA(under) or pc.rgbaA(under)) / 255 end
  if ua == 0 then
    if gray then return pc.graya(grayOf(c), a) end
    return pc.rgba(c.r, c.g, c.b, a)
  end
  local oa = sa + ua * (1 - sa)
  local function mix(v, uv) return round((v * sa + uv * ua * (1 - sa)) / oa) end
  if gray then return pc.graya(mix(grayOf(c), pc.grayaV(under)), round(oa * 255)) end
  return pc.rgba(mix(c.r, pc.rgbaR(under)), mix(c.g, pc.rgbaG(under)), mix(c.b, pc.rgbaB(under)),
                 round(oa * 255))
end

-- Draws a line (its fill first, then the line itself) by calling
-- put(x, y, pixel value) for each pixel. An antialiased line is blended
-- over what get(x, y) returns (nil for nothing).
local function drawPath(sprite, p, put, get)
  local aa = antialiased(sprite, p)
  local function blend(c)
    return function(x, y, cover)
      local v = blendPixel(sprite, c, cover, get(x, y))
      if v then put(x, y, v) end
    end
  end
  if p.fill then
    if aa then
      coverFill(sprite, p, blend(p.fillColor))
    else
      local fv = colorPixel(sprite, p.fillColor)
      fillPath(sprite, p, function(x, y) put(x, y, fv) end)
    end
  end
  if p.stroke ~= false then
    if aa then
      coverPath(sprite, p, blend(p.color))
    else
      local v = colorPixel(sprite, p.color)
      plotPath(sprite, p, function(x, y) put(x, y, v) end)
    end
  end
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
    drawPath(sprite, p, function(x, y, v) img:drawPixel(x, y, v) end,
             function(x, y) return img:getPixel(x, y) end)
  end
  return img
end

-- The palette entry closest to a color (never the transparent one)
local function nearestIndex(sprite, r, g, b)
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
end

-- Pixel value of a guide color in the sprite's color mode
local function guidePixel(sprite, r, g, b)
  if sprite.colorMode == ColorMode.INDEXED then
    return nearestIndex(sprite, r, g, b)
  elseif sprite.colorMode == ColorMode.GRAY then
    return pc.graya(grayOf{ r = r, g = g, b = b }, 255)
  end
  return pc.rgba(r, g, b, 255)
end

-- Colors of the guides. In RGB (or Indexed with a green in the palette) they
-- are bright green. Grayscale and other palettes can't show green, so the
-- guides are black and white there, mixed so they stand out on any picture.
local function guideStyle(sprite, layer, frameNumber)
  local mode = sprite.colorMode
  local green = mode == ColorMode.RGB
  if mode == ColorMode.INDEXED then
    local c = sprite.palettes[1]:getColor(nearestIndex(sprite, 0, 255, 0))
    green = c.green >= 128 and c.green - math.max(c.red, c.blue) >= 64
  end
  if green then
    return {
      point = guidePixel(sprite, 0, 255, 0),        -- points of the selected line
      selected = guidePixel(sprite, 200, 255, 200), -- the selected point
      handle = guidePixel(sprite, 0, 255, 0),       -- handles
      other = guidePixel(sprite, 0, 170, 0),        -- points of the other lines
    }
  end

  local style = { twoTone = true }
  if mode == ColorMode.GRAY then
    style.dark, style.light = pc.graya(0, 255), pc.graya(255, 255)
    style.otherRing, style.otherCenter = pc.graya(64, 255), pc.graya(200, 255)
  else
    -- The darkest and lightest palette entries, and two in between
    local pal = sprite.palettes[1]
    local dark, light, darkL, lightL = 0, 0, math.huge, -1
    for i = 0, #pal - 1 do
      if i ~= sprite.transparentColor then
        local c = pal:getColor(i)
        local l = grayOf{ r = c.red, g = c.green, b = c.blue }
        if l < darkL then dark, darkL = i, l end
        if l > lightL then light, lightL = i, l end
      end
    end
    style.dark, style.light = dark, light
    style.otherRing = nearestIndex(sprite, 64, 64, 64)
    style.otherCenter = nearestIndex(sprite, 200, 200, 200)
  end
  return style
end

------------------------------------------------------------------------
-- Curve layers and cels

local function isCurveLayer(layer)
  return layer ~= nil and layer.isImage and not layer.isTilemap
         and layer.properties(KEY).curve == true
end

-- Curve layers get this color in the timeline, so they're easy to tell apart
local CURVE_COLOR = { r = 80, g = 200, b = 110 }

local function isCurveColor(c)
  return c ~= nil and c.alpha > 0
         and c.red == CURVE_COLOR.r and c.green == CURVE_COLOR.g and c.blue == CURVE_COLOR.b
end

-- Gives a curve layer its color, unless the user already picked one
local function colorCurveLayer(layer)
  if layer.color.alpha == 0 then
    layer.color = Color{ r = CURVE_COLOR.r, g = CURVE_COLOR.g, b = CURVE_COLOR.b }
  end
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
local clipboard = nil  -- shapes copied with the Copy button (serialized)
local prefs = {}       -- plugin.preferences
local askTimer, tickTimer

local function scheduleTick()
  if tickTimer and not tickTimer.isRunning then tickTimer:start() end
end

local function tip(text)
  pcall(function() app.tip(text, 4) end)
end

-- A quick second click on the canvas is a double-click, which Aseprite uses
-- to select a grid tile (and which never reaches the script). The
-- "Select a grid tile with double-click" preference is turned off while
-- editing, and turned back on afterwards. The original value is also kept
-- in the plugin preferences, in case Aseprite closes before it's restored.
local function disableTileDoubleClick()
  if prefs.savedDoubleClick ~= nil then return end
  pcall(function()
    local v = app.preferences.selection.doubleclick_select_tile
    if type(v) ~= "boolean" then return end
    prefs.savedDoubleClick = v
    app.preferences.selection.doubleclick_select_tile = false
  end)
end

local function restoreTileDoubleClick()
  local v = prefs.savedDoubleClick
  if v == nil then return end
  prefs.savedDoubleClick = nil
  pcall(function() app.preferences.selection.doubleclick_select_tile = v end)
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
-- Transforming lines (scale, rotate, shear, flip)
--
-- A transform moves every point and handle end of the lines with a
-- function fn(x, y) -> x, y. Points land on whole pixels, handle ends keep
-- their exact positions. Dragging always transforms the lines as they were
-- when the drag started, so rounding doesn't add up.

-- Copies of the points of the lines in `list` (indexes into `paths`)
local function copyNodes(paths, list)
  local orig = {}
  for _, pi in ipairs(list) do
    local c = {}
    for i, n in ipairs(paths[pi].nodes) do
      c[i] = { x = n.x, y = n.y, ix = n.ix, iy = n.iy, ox = n.ox, oy = n.oy }
    end
    c.pivot = paths[pi].pivot
    orig[pi] = c
  end
  return orig
end

-- Moves a center with fn (it stays on a whole pixel)
local function mapPivot(pv, fn)
  if not pv then return nil end
  local x, y = fn(pv.x, pv.y)
  return { x = round(x), y = round(y) }
end

-- Sets the points of the lines to their copies moved by fn. The lines'
-- centers go along.
local function mapNodes(paths, orig, fn)
  for pi, c in pairs(orig) do
    paths[pi].pivot = mapPivot(c.pivot, fn)
    local nodes = paths[pi].nodes
    for i, o in ipairs(c) do
      local n = nodes[i]
      local x, y = fn(o.x, o.y)
      n.x, n.y = round(x), round(y)
      -- A point without a handle stays without it
      if o.ix ~= 0 or o.iy ~= 0 then
        local hx, hy = fn(o.x + o.ix, o.y + o.iy)
        n.ix, n.iy = hx - n.x, hy - n.y
      end
      if o.ox ~= 0 or o.oy ~= 0 then
        local hx, hy = fn(o.x + o.ox, o.y + o.oy)
        n.ox, n.oy = hx - n.x, hy - n.y
      end
    end
  end
end

-- The area the lines in `list` pass through (not counting their width)
local function pathBounds(paths, list)
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, pi in ipairs(list) do
    for _, q in ipairs(flatten(paths[pi])) do
      x0, x1 = math.min(x0, q[1]), math.max(x1, q[1])
      y0, y1 = math.min(y0, q[2]), math.max(y1, q[2])
    end
  end
  if x0 > x1 then return nil end
  -- Points on the curve can be off by a hair (19.9999999 instead of 20)
  local function snap(v)
    local r = round(v)
    return abs(v - r) < 1e-6 and r or v
  end
  return snap(x0), snap(y0), snap(x1), snap(y1)
end

-- The point the lines turn around: the middle of their area. It's moved
-- by half a pixel if needed, so that turning by 90 degrees keeps the
-- points on whole pixels.
local function turnCenter(x0, y0, x1, y1)
  local sx, sy = round(x0) + round(x1), round(y0) + round(y1)
  if (sx + sy) % 2 == 0 then return sx / 2, sy / 2 end
  return round(sx / 2), round(sy / 2)
end

-- Transforms that the panel buttons and the Edit menu use
local function flipFn(vertical)
  return function(x0, y0, x1, y1)
    local cx, cy = round(x0) + round(x1), round(y0) + round(y1)
    if vertical then return function(x, y) return x, cy - y end end
    return function(x, y) return cx - x, y end
  end
end

-- Turns by a multiple of 90 degrees (clockwise on the screen)
local function rotateFn(quarters)
  quarters = quarters % 4
  return function(x0, y0, x1, y1)
    local cx, cy = turnCenter(x0, y0, x1, y1)
    if quarters == 2 then
      -- Half a turn keeps the points on whole pixels around the exact middle
      cx, cy = (round(x0) + round(x1)) / 2, (round(y0) + round(y1)) / 2
    end
    return function(x, y)
      local ux, uy = x - cx, y - cy
      if quarters == 1 then ux, uy = -uy, ux
      elseif quarters == 2 then ux, uy = -ux, -uy
      elseif quarters == 3 then ux, uy = uy, -ux end
      return cx + ux, cy + uy
    end
  end
end

------------------------------------------------------------------------
-- Basic shapes (Place Shape)

local SHAPE_KINDS = { "ellipse", "rect", "roundRect", "triangle", "polygon", "star" }
local KAPPA = 0.5523   -- handle length for a quarter circle, as a part of the radius

-- A point at (x, y) with handles (offsets). It lands on a whole pixel, and
-- its handles keep pointing at the same places.
local function shapeNode(x, y, ix, iy, ox, oy)
  local n = { x = round(x), y = round(y), ix = 0, iy = 0, ox = 0, oy = 0 }
  if ix ~= 0 or iy ~= 0 then n.ix, n.iy = x + ix - n.x, y + iy - n.y end
  if ox ~= 0 or oy ~= 0 then n.ox, n.oy = x + ox - n.x, y + oy - n.y end
  n.smooth = (ix ~= 0 or iy ~= 0) and (ox ~= 0 or oy ~= 0)
  return n
end

-- Joins points of a closed shape that landed on the same pixel
local function mergeSame(nodes)
  local out = {}
  for _, n in ipairs(nodes) do
    local last = out[#out]
    if last and last.x == n.x and last.y == n.y then
      last.ox, last.oy, last.smooth = n.ox, n.oy, false
    else
      out[#out + 1] = n
    end
  end
  while #out > 1 and out[1].x == out[#out].x and out[1].y == out[#out].y do
    local last = table.remove(out)
    out[1].ix, out[1].iy, out[1].smooth = last.ix, last.iy, false
  end
  return out
end

-- The points of a basic shape that fills the box (x0, y0) - (x1, y1)
local function shapeNodes(kind, opt, x0, y0, x1, y1)
  local cx, cy, rx, ry = (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2, (y1 - y0) / 2
  local N = shapeNode
  if kind == "rect" then
    return mergeSame{ N(x0, y0, 0, 0, 0, 0), N(x1, y0, 0, 0, 0, 0), N(x1, y1, 0, 0, 0, 0), N(x0, y1, 0, 0, 0, 0) }
  elseif kind == "ellipse" then
    local kx, ky = KAPPA * rx, KAPPA * ry
    return mergeSame{ N(cx, y0, -kx, 0, kx, 0), N(x1, cy, 0, -ky, 0, ky),
                      N(cx, y1, kx, 0, -kx, 0), N(x0, cy, 0, ky, 0, -ky) }
  elseif kind == "roundRect" then
    local r = math.min(rx, ry) * (opt.rounding or 30) / 100
    local k = KAPPA * r
    return mergeSame{ N(x0 + r, y0, -k, 0, 0, 0), N(x1 - r, y0, 0, 0, k, 0),
                      N(x1, y0 + r, 0, -k, 0, 0), N(x1, y1 - r, 0, 0, 0, k),
                      N(x1 - r, y1, k, 0, 0, 0), N(x0 + r, y1, 0, 0, -k, 0),
                      N(x0, y1 - r, 0, k, 0, 0), N(x0, y0 + r, 0, 0, 0, -k) }
  elseif kind == "triangle" then
    return mergeSame{ N(cx, y0, 0, 0, 0, 0), N(x1, y1, 0, 0, 0, 0), N(x0, y1, 0, 0, 0, 0) }
  end
  -- A polygon or a star, starting at the top
  local count = kind == "star" and opt.sides * 2 or opt.sides
  local list = {}
  for i = 0, count - 1 do
    local a = -math.pi / 2 + 2 * math.pi * i / count
    local q = (kind == "star" and i % 2 == 1) and 0.4 or 1
    list[#list + 1] = N(cx + rx * q * math.cos(a), cy + ry * q * math.sin(a), 0, 0, 0, 0)
  end
  return mergeSame(list)
end

------------------------------------------------------------------------
-- Panel fields

local function syncFields()
  local s, dlg = S, panel
  if not s or not dlg then return end
  local p = s.paths[s.active]
  local indexed = s.sprite.colorMode == ColorMode.INDEXED
  s.syncing = true
  dlg:modify{ id = "antialias", text = indexed and T.antialiasIndexed or T.antialias }
  if p then
    dlg:modify{ id = "color", color = tableToColor(s.sprite, p.color) }
    dlg:modify{ id = "width", value = p.width }
    dlg:modify{ id = "pixelPerfect", selected = p.pixelPerfect }
    dlg:modify{ id = "antialias", selected = p.antialias }
    dlg:modify{ id = "closed", selected = p.closed }
    dlg:modify{ id = "stroke", selected = p.stroke ~= false }
    dlg:modify{ id = "fill", selected = p.fill }
    dlg:modify{ id = "fillColor", color = tableToColor(s.sprite, p.fillColor) }
    dlg:modify{ id = "styleSep", text = s.drawing and T.drawingShape or T.selectedShape }
  else
    dlg:modify{ id = "closed", selected = false }
    dlg:modify{ id = "styleSep", text = s.drawing and T.drawingShape or T.nextShape }
  end
  if s.placing then dlg:modify{ id = "styleSep", text = T.placingShape } end
  -- Transforms work on the selected line, or on all lines when none is selected
  dlg:modify{ id = "xfSep", text = p and T.transformSelected or T.transformAll }
  dlg:modify{ id = "transform", text = s.xf and T.endTransform or T.transformBox }
  s.syncing = false
end

local function updateButtons()
  local s, dlg = S, panel
  if not s or not dlg then return end
  local p = s.paths[s.active]
  local hasPoint = p ~= nil and s.selNode ~= nil
  -- Antialiasing needs RGB or Grayscale, and replaces pixel-perfect
  local indexed = s.sprite.colorMode == ColorMode.INDEXED
  dlg:modify{ id = "antialias", enabled = not indexed }
  dlg:modify{ id = "pixelPerfect", enabled = indexed or not dlg.data.antialias }
  dlg:modify{ id = "closed", enabled = p ~= nil }
  dlg:modify{ id = "copy", enabled = #s.paths > 0 }
  dlg:modify{ id = "paste", enabled = clipboard ~= nil }
  dlg:modify{ id = "deleteLine", enabled = p ~= nil }
  dlg:modify{ id = "deletePoint", enabled = hasPoint }
  dlg:modify{ id = "roundSharp", enabled = hasPoint }
  dlg:modify{ id = "undo", enabled = #s.undoStack > 0 }
  dlg:modify{ id = "redo", enabled = #s.redoStack > 0 }
  for _, id in ipairs({ "transform", "numeric", "flipH", "flipV", "rotateLeft", "rotateRight" }) do
    dlg:modify{ id = id, enabled = #s.paths > 0 or (id == "transform" and s.xf ~= nil) }
  end
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
    -- The point before a deleted selected point gets selected, so deleting
    -- again goes on with the points (not the whole shape)
    if s.selNode == ni then s.selNode = math.max(1, ni - 1)
    elseif s.selNode > ni then s.selNode = s.selNode - 1 end
  end
end

------------------------------------------------------------------------
-- The transform box

-- The lines a transform works on: the selected line, or all lines
local function xfTargets()
  local s = S
  if s.paths[s.active] then return { s.active } end
  local list = {}
  for i = 1, #s.paths do list[i] = i end
  return list
end

-- The box around the lines being transformed, with its handles. The box is
-- drawn a little outside the lines (and inside the canvas).
local function xfBox()
  local s = S
  local list = xfTargets()
  local x0, y0, x1, y1 = pathBounds(s.paths, list)
  if not x0 then return nil end
  local pad = 2
  for _, pi in ipairs(list) do
    local p = s.paths[pi]
    if p.stroke ~= false then pad = math.max(pad, p.width // 2 + 2) end
  end
  local W, H = s.sprite.width, s.sprite.height
  -- At least 8 pixels each way, so a flat shape (like a straight line)
  -- still has room inside the box between its handles
  local function side(a0, a1, hi)
    a0, a1 = floor(a0) - pad, math.ceil(a1) + pad
    local short = 8 - (a1 - a0)
    if short > 0 then a0, a1 = a0 - short // 2, a1 + short - short // 2 end
    return math.max(0, math.min(hi, a0)), math.max(0, math.min(hi, a1))
  end
  local ex0, ex1 = side(x0, x1, W - 1)
  local ey0, ey1 = side(y0, y1, H - 1)
  local mx, my = (ex0 + ex1) // 2, (ey0 + ey1) // 2
  return {
    x0 = x0, y0 = y0, x1 = x1, y1 = y1, ex0 = ex0, ey0 = ey0, ex1 = ex1, ey1 = ey1,
    -- Corners first: they win when handles overlap
    handles = { { "nw", ex0, ey0 }, { "ne", ex1, ey0 }, { "sw", ex0, ey1 }, { "se", ex1, ey1 },
                { "n", mx, ey0 }, { "s", mx, ey1 }, { "w", ex0, my }, { "e", ex1, my } },
  }
end

-- What keeps the center for the lines being transformed: the selected
-- line, or the list of lines (for all of them)
local function pivotOwner()
  local s = S
  return s.paths[s.active] or s.paths
end

-- The center that rotating and shearing work around: where the user put it,
-- or the middle of the lines
local function xfPivot(b)
  local pv = pivotOwner().pivot
  if pv then return pv.x, pv.y end
  return turnCenter(b.x0, b.y0, b.x1, b.y1)
end

-- Pixels of the handle shapes, around their center
local CIRCLE, DIAMOND, RING, PLUS = {}, {}, {}, {}
for dy = -2, 2 do
  for dx = -2, 2 do
    local m, c = abs(dx) + abs(dy), math.max(abs(dx), abs(dy))
    if c == 2 and m < 4 then CIRCLE[#CIRCLE + 1] = { dx, dy } end
    if m == 2 then DIAMOND[#DIAMOND + 1] = { dx, dy } end
    if c == 1 then RING[#RING + 1] = { dx, dy } end
    if m == 1 then PLUS[#PLUS + 1] = { dx, dy } end
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

-- Adds the points and handles to `want`, on top of the lines.
-- Points are 3x3 squares, handle ends single pixels.
local function addGuides(want)
  local s = S
  if panel and not panel.data.guides then return end
  local g = s.guide
  local function put(x, y, v)
    local k = overlayKey(s.ov, x, y)
    if k then want[k] = v end
  end
  -- A 3x3 square: `ring` around, `center` in the middle
  local function square(x, y, ring, center)
    for dy = -1, 1 do
      for dx = -1, 1 do put(x + dx, y + dy, (dx == 0 and dy == 0) and (center or ring) or ring) end
    end
  end
  -- A hollow 3x3 square (a point): `corner` at the corners, `side` between
  -- them; the middle shows the line under it
  local function hollow(x, y, corner, side)
    for dy = -1, 1 do
      for dx = -1, 1 do
        if dx ~= 0 and dy ~= 0 then put(x + dx, y + dy, corner)
        elseif dx ~= 0 or dy ~= 0 then put(x + dx, y + dy, side or corner) end
      end
    end
  end
  -- Transforming: only the box and its handles
  if s.xf then
    local b = xfBox()
    if not b then return end
    local function dot(x, y, j)
      if j % 2 == 0 then
        if g.twoTone then put(x, y, j % 4 == 0 and g.dark or g.light) else put(x, y, g.handle) end
      end
    end
    for x = b.ex0, b.ex1 do dot(x, b.ey0, x - b.ex0); dot(x, b.ey1, x - b.ex0) end
    for y = b.ey0, b.ey1 do dot(b.ex0, y, y - b.ey0); dot(b.ex1, y, y - b.ey0) end
    local outer, inner = g.point, nil
    if g.twoTone then outer, inner = g.dark, g.light end
    local function shape(x, y, pixels, fill)
      for _, o in ipairs(pixels) do put(x + o[1], y + o[2], outer) end
      if inner then for _, o in ipairs(fill) do put(x + o[1], y + o[2], inner) end end
    end
    local rotating = s.xf.mode == "rotate"
    for _, h in ipairs(b.handles) do
      local x, y = h[2], h[3]
      if not rotating then
        square(x, y, outer, inner)            -- squares: scale
      elseif #h[1] == 2 then
        shape(x, y, CIRCLE, RING)             -- circles at the corners: rotate
      else
        shape(x, y, DIAMOND, PLUS)            -- diamonds on the sides: shear
      end
    end
    if rotating then
      -- The center (a cross that can be dragged)
      local cx, cy = xfPivot(b)
      cx, cy = floor(cx), floor(cy)
      for _, o in ipairs(PLUS) do put(cx + o[1], cy + o[2], outer) end
      put(cx, cy, inner or outer)
    end
    return
  end

  for pi, p in ipairs(s.paths) do
    if pi ~= s.active then
      for _, n in ipairs(p.nodes) do
        if g.twoTone then hollow(n.x, n.y, g.otherRing, g.otherCenter) else hollow(n.x, n.y, g.other) end
      end
    end
  end
  local p = s.paths[s.active]
  if p then
    local ends = {}
    for i, n in ipairs(p.nodes) do
      for _, side in ipairs({ "in", "out" }) do
        if hasHandle(n, side) and handleUsed(p, i, side) then
          local hx, hy = handlePos(n, side)
          hx, hy = round(hx), round(hy)
          -- Dotted line from the point to the end of the handle
          -- (black and white dots when green isn't available)
          linePixels(n.x, n.y, hx, hy, function(x, y, j)
            -- (not inside the point's hollow square)
            if j % 2 == 0 and (abs(x - n.x) > 1 or abs(y - n.y) > 1) then
              if g.twoTone then put(x, y, j % 4 == 0 and g.dark or g.light) else put(x, y, g.handle) end
            end
          end)
          ends[#ends + 1] = { hx, hy }
        end
      end
    end
    -- Points: hollow squares
    for i, n in ipairs(p.nodes) do
      if not g.twoTone then
        hollow(n.x, n.y, i == s.selNode and g.selected or g.point)
      elseif i == s.selNode then
        hollow(n.x, n.y, g.light, g.dark)   -- white corners, black sides
      else
        hollow(n.x, n.y, g.dark, g.light)   -- black corners, white sides
      end
    end
    -- Handle ends: filled squares, on top so short handles stay visible
    for _, e in ipairs(ends) do
      if g.twoTone then square(e[1], e[2], g.dark, g.light) else square(e[1], e[2], g.handle) end
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
  local function put(x, y, v)
    local k = overlayKey(s.ov, x, y)
    if k then want[k] = v end
  end
  local function get(x, y)
    local k = overlayKey(s.ov, x, y)
    return k and want[k]
  end
  for _, p in ipairs(s.paths) do drawPath(s.sprite, p, put, get) end
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

local function deleteSelectedShape()
  local s = S
  if not s.paths[s.active] then return end
  local pi = s.active
  edit(function()
    table.remove(s.paths, pi)
    s.drawing = false
    s.xf = nil
    select(nil, nil)
  end)
  syncFields()
  askTimer:start()
end

-- Stops drawing the line: the next click on an empty spot starts a new line
local function endDrawing()
  local s = S
  s.drawing = false
  select(nil, nil)
  syncFields()
  refresh()
  askTimer:start()
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

-- Whether the pixel (x, y) is inside the fill of a line (nonzero winding
-- rule; an open line is closed with a straight line, as when filling)
local function insideFill(p, x, y)
  if not p.fill or #p.nodes < 2 then return false end
  local pts = flatten(p)
  local n, winding = #pts, 0
  for i = 1, n do
    local a, b = pts[i], pts[i % n + 1]
    local side = (b[1] - a[1]) * (y - a[2]) - (x - a[1]) * (b[2] - a[2])
    if a[2] <= y then
      if b[2] > y and side > 0 then winding = winding + 1 end
    elseif b[2] <= y and side < 0 then
      winding = winding - 1
    end
  end
  return winding ~= 0
end

-- Finds what's at the pixel (x, y): a handle, a point, a line, or the fill
-- of a shape. While a line is being drawn, only that line can be grabbed.
local function hitTest(x, y)
  local s = S
  local tol = tolerance()
  local function grabbable(pi) return not s.drawing or pi == s.active end
  local best, bestD = nil, math.huge
  local function consider(d, hit, limit)
    if d <= (limit or tol) and d < bestD then best, bestD = hit, d end
  end

  -- Handles of the selected line (unless they're on their own point)
  local p = s.paths[s.active]
  if p then
    for i, n in ipairs(p.nodes) do
      for _, side in ipairs({ "out", "in" }) do
        if hasHandle(n, side) and handleUsed(p, i, side) then
          local hx, hy = handlePos(n, side)
          if round(hx) ~= n.x or round(hy) ~= n.y then
            -- The whole 3x3 square of a handle end can be clicked
            consider(dist(x, y, hx, hy) + 0.01, { kind = "handle", path = s.active, node = i, side = side },
                     math.max(tol, 1.5))
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
        -- The whole 3x3 square of a point can be clicked
        consider(dist(x, y, n.x, n.y) + bias, { kind = "anchor", path = pi, node = i },
                 math.max(tol, 1.5 + bias))
      end
    end
  end
  if best then return best end

  -- Lines: a click on one of their pixels, or close to the curve
  for pi, q in ipairs(s.paths) do
    local onPixel = false
    if grabbable(pi) and q.stroke ~= false then
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
  if best or s.drawing then return best end

  -- Inside a fill: the shape on top
  for pi = #s.paths, 1, -1 do
    if insideFill(s.paths[pi], x, y) then return { kind = "fill", path = pi } end
  end
  return nil
end

-- Adds a point to the end of the selected line, or starts a new line
-- A new line (without points) with the settings in the panel
local function newStyledPath()
  local s = S
  local color, width, perfect, fill, fillColor, stroke = app.fgColor, 1, true, false, app.fgColor, true
  local aa = false
  if panel then
    local d = panel.data
    color, width, perfect, fill, fillColor, stroke =
      d.color, d.width, d.pixelPerfect, d.fill, d.fillColor, d.stroke
    aa = d.antialias and s.sprite.colorMode ~= ColorMode.INDEXED
  end
  return { color = colorToTable(color), width = width, pixelPerfect = perfect, stroke = stroke,
           antialias = aa, fill = fill, fillColor = colorToTable(fillColor), closed = false, nodes = {} }
end

local function addPoint(x, y)
  local s = S
  local wasDrawing = s.drawing
  s.drawing = true
  local p = s.paths[s.active]
  if not p or p.closed then
    p = newStyledPath()
    s.paths[#s.paths + 1] = p
    select(#s.paths, nil)
  end
  p.nodes[#p.nodes + 1] = { x = x, y = y, ix = 0, iy = 0, ox = 0, oy = 0, smooth = false }
  s.selNode = #p.nodes
  if not wasDrawing then syncFields() end
  return { kind = "anchor", path = s.active, node = s.selNode }
end

-- Where the center goes when dragged to (x, y): it snaps to the points of
-- the lines, to the corners and the middles of the sides of their area, and
-- back to the middle (nil)
local function snapPivot(b, x, y)
  local s = S
  local best, bestD = nil, math.max(tolerance(), 1.5) + 0.001
  local function try(px, py, middle)
    local d = dist(x, y, px, py)
    if d < bestD then best, bestD = { x = px, y = py, middle = middle }, d end
  end
  local cx, cy = turnCenter(b.x0, b.y0, b.x1, b.y1)
  try(cx, cy, true)
  for _, rx in ipairs({ b.x0, (b.x0 + b.x1) / 2, b.x1 }) do
    for _, ry in ipairs({ b.y0, (b.y0 + b.y1) / 2, b.y1 }) do try(round(rx), round(ry)) end
  end
  for _, pi in ipairs(xfTargets()) do
    for _, n in ipairs(s.paths[pi].nodes) do try(n.x, n.y) end
  end
  if not best then return { x = x, y = y } end
  if best.middle then return nil end
  return { x = best.x, y = best.y }
end

-- The mouse button went down at (x, y): decide what the drag will do
-- The box a shape is placed in, dragged from (d.sx, d.sy) to (x, y)
local function placeBox(d, x, y)
  local sx, sy = d.sx, d.sy
  if d.placing.square then
    local m = math.max(abs(x - sx), abs(y - sy))
    x, y = sx + (x >= sx and m or -m), sy + (y >= sy and m or -m)
  end
  return math.min(sx, x), math.min(sy, y), math.max(sx, x), math.max(sy, y)
end

local function startGesture(x, y)
  local s = S
  s.lastMerge = nil
  local before = snapshot()
  if s.placing then
    -- Place Shape: the drag sets the box of the new shape
    local p = newStyledPath()
    p.closed = true
    s.paths[#s.paths + 1] = p
    select(#s.paths, nil)
    s.press = { kind = "place", before = before, sx = x, sy = y, path = #s.paths, placing = s.placing }
    p.nodes = shapeNodes(s.placing.kind, s.placing, x, y, x, y)
    return
  end
  if s.xf then
    -- A handle of the box, the center (while rotating), inside the box
    -- (move), or outside (done). The nearest handle or center wins.
    local b = xfBox()
    local press = { kind = "xfOut", before = before, sx = x, sy = y, box = b, mode = s.xf.mode,
                    orig = copyNodes(s.paths, xfTargets()),
                    allPivot = not s.paths[s.active] and s.paths.pivot or nil }
    if b then
      press.px, press.py = xfPivot(b)
      local bestD = math.max(tolerance(), 2.5) + 0.001
      for _, h in ipairs(b.handles) do
        local d = dist(x, y, h[2], h[3])
        if d < bestD then press.kind, press.handle, bestD = "xfHandle", h[1], d end
      end
      local d = dist(x, y, press.px, press.py)
      if s.xf.mode == "rotate" and d <= math.max(tolerance(), 1.5) and d <= bestD then
        press.kind, press.handle = "xfPivot", nil
      end
      if press.kind == "xfOut" and x >= b.ex0 and x <= b.ex1 and y >= b.ey0 and y <= b.ey1 then
        press.kind = "xfMove"
      end
    end
    s.press = press
    return
  end
  local hit = hitTest(x, y)
  if hit and hit.kind == "handle" then
    select(hit.path, hit.node)
    local hx, hy = handlePos(s.paths[hit.path].nodes[hit.node], hit.side)
    s.press = { kind = "handle", hit = hit, before = before, sx = x, sy = y, hx = hx, hy = hy }
  elseif hit and hit.kind == "anchor" then
    -- A click (not a drag) on the last point of the line being drawn ends
    -- drawing; on its first point, it closes the line
    local q = s.paths[hit.path]
    local drawn = s.drawing and hit.path == s.active
    local finishes = drawn and hit.node == #q.nodes
    local closes = drawn and hit.node == 1 and #q.nodes >= 2 and not q.closed
    select(hit.path, hit.node)
    local n = q.nodes[hit.node]
    s.press = { kind = "anchor", hit = hit, before = before, sx = x, sy = y, x = n.x, y = n.y,
                finishes = finishes, closes = closes }
  elseif hit then
    -- Clicking the line of the selected shape adds a point; clicking another
    -- shape's line, or inside a fill, only selects the shape. Dragging moves it.
    local addsPoint = hit.kind == "segment" and hit.path == s.active
    select(hit.path, nil)
    local orig = {}
    for i, n in ipairs(s.paths[hit.path].nodes) do orig[i] = { n.x, n.y } end
    s.press = { kind = "segment", hit = hit, before = before, sx = x, sy = y, orig = orig,
                pivot = s.paths[hit.path].pivot, addsPoint = addsPoint }
  else
    s.press = { kind = "pull", hit = addPoint(x, y), before = before }
  end
end

-- The transform for dragging a handle of the box from where the drag
-- started to (x, y), or nil to leave the lines alone
local function handleTransform(d, x, y)
  local b, h = d.box, d.handle
  local dx, dy = x - d.sx, y - d.sy
  if d.mode == "rotate" and #h == 2 then
    -- Rotate around the center, snapping to multiples of 15 degrees
    local cx, cy = d.px, d.py
    local a = math.atan(y - cy, x - cx) - math.atan(d.sy - cy, d.sx - cx)
    local deg = math.deg(a)
    local snap = round(deg / 15) * 15
    if abs(deg - snap) < 2 then a = math.rad(snap) end
    local c, sn = math.cos(a), math.sin(a)
    return function(px, py)
      local ux, uy = px - cx, py - cy
      return cx + ux * c - uy * sn, cy + ux * sn + uy * c
    end
  elseif d.mode == "rotate" then
    -- Shear: the dragged side slides along (following the pointer), and
    -- the line through the center stays
    if h == "n" or h == "s" then
      local span = d.sy - d.py
      if abs(span) < 0.5 then return nil end
      local k, ay = dx / span, d.py
      return function(px, py) return px + k * (py - ay), py end
    end
    local span = d.sx - d.px
    if abs(span) < 0.5 then return nil end
    local k, ax = dy / span, d.px
    return function(px, py) return px, py + k * (px - ax) end
  end
  -- Scale: the dragged side (or corner) moves, the opposite one stays
  local w, ht = b.x1 - b.x0, b.y1 - b.y0
  local sx, sy, ax, ay = 1, 1, b.x0, b.y0
  if h:find("e") then ax = b.x0; if w > 0 then sx = (w + dx) / w end
  elseif h:find("w") then ax = b.x1; if w > 0 then sx = (w - dx) / w end end
  if h:find("s") then ay = b.y0; if ht > 0 then sy = (ht + dy) / ht end
  elseif h:find("n") then ay = b.y1; if ht > 0 then sy = (ht - dy) / ht end end
  if #h == 2 and panel and panel.data.keepRatio then
    local k = abs(sx - 1) >= abs(sy - 1) and sx or sy
    sx, sy = k, k
  end
  return function(px, py) return ax + (px - ax) * sx, ay + (py - ay) * sy end
end

local function dragTo(x, y)
  local s = S
  local d = s.press
  if d.kind == "place" then
    local x0, y0, x1, y1 = placeBox(d, x, y)
    s.paths[d.path].nodes = shapeNodes(d.placing.kind, d.placing, x0, y0, x1, y1)
    return
  elseif d.kind == "xfHandle" or d.kind == "xfMove" then
    local fn
    if d.kind == "xfMove" then
      local dx, dy = x - d.sx, y - d.sy
      if dx ~= 0 or dy ~= 0 then d.moved = true end
      fn = function(px, py) return px + dx, py + dy end
    else
      fn = handleTransform(d, x, y) or function(px, py) return px, py end
    end
    mapNodes(s.paths, d.orig, fn)
    -- Centers the user put somewhere move with the lines
    if d.allPivot then s.paths.pivot = mapPivot(d.allPivot, fn) end
    return
  elseif d.kind == "xfPivot" then
    pivotOwner().pivot = snapPivot(d.box, x, y)
    return
  elseif d.kind == "xfOut" then
    return
  end
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
      s.paths[d.hit.path].pivot = mapPivot(d.pivot, function(px, py) return px + x - d.sx, py + y - d.sy end)
    end
  end
end

local function endGesture(x, y, dragged)
  local s = S
  local d = s.press
  if dragged then dragTo(x, y) end
  s.press = nil
  if d.kind == "segment" and not d.moved and d.addsPoint then
    select(d.hit.path, insertNode(s.paths[d.hit.path], d.hit.seg, d.hit.t))
  end
  local clicked = x == d.sx and y == d.sy
  if d.kind == "place" then
    if clicked then
      -- A click places the shape at a default size, centered on it
      local h = math.max(2, math.min(16, math.min(s.sprite.width, s.sprite.height) // 4))
      s.paths[d.path].nodes = shapeNodes(d.placing.kind, d.placing, x - h, y - h, x + h, y + h)
    end
    s.placing = nil
    select(d.path, nil)
    syncFields()
  elseif d.kind == "xfMove" and not d.moved and s.xf then
    -- A click inside the box switches between scaling and rotating/shearing
    s.xf.mode = s.xf.mode == "rotate" and "scale" or "rotate"
  elseif d.kind == "xfOut" and clicked then
    -- A click outside the box ends transforming
    s.xf = nil
    syncFields()
  elseif d.closes and clicked then
    -- Closed: the shape is finished (and stays selected, as a whole)
    s.paths[d.hit.path].closed = true
    s.drawing = false
    s.selNode = nil
    syncFields()
  end
  pushUndo(d.before)
  if d.finishes and x == d.sx and y == d.sy then
    endDrawing()
  else
    refresh()
  end
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
  elseif s.placing then
    s.placing = nil
    syncFields()
    refresh()
  elseif s.xf then
    s.xf = nil
    syncFields()
    refresh()
  elseif s.active or s.drawing then
    endDrawing()
  end
  askTimer:start()
end

local function ask()
  local s = S
  if not s or s.finished or app.editor ~= s.editor then return end
  local p = s.paths[s.active]
  local n = p and s.selNode and p.nodes[s.selNode]
  -- `point` outlines the selected point
  local title = s.drawing and T.hintDrawing or T.hint
  if s.xf then
    title = s.xf.mode == "rotate" and T.hintRotate or T.hintScale
    n = nil
  elseif s.placing then
    title, n = T.hintPlace, nil
  end
  s.editor:askPoint{ title = title, point = n and Point(n.x, n.y) or nil,
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
        local function shift(pv) return pv and { x = pv.x + dx, y = pv.y + dy } end
        paths.pivot = shift(paths.pivot)
        for _, p in ipairs(paths) do
          for _, n in ipairs(p.nodes) do n.x, n.y = n.x + dx, n.y + dy end
          p.pivot = shift(p.pivot)
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
    guide = guideStyle(sprite, layer, f),
  }
  S = s
  lastSkip = nil
  disableTileDoubleClick()

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
          pcall(colorCurveLayer, s.layer)   -- curve layers made before layers had a color
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

-- "Close" (or closing the panel): apply, and leave the layer alone until
-- it's selected again
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
-- Transform actions

-- Turns the transform box on or off
local function toggleTransform(s)
  s.placing = nil
  if s.xf then
    s.xf = nil
  elseif #s.paths > 0 then
    s.drawing = false
    s.selNode = nil
    s.xf = { mode = "scale" }
  end
  syncFields()
  refresh()
  askTimer:start()
end

-- Transforms the lines (see xfTargets) as one step. makeFn(x0, y0, x1, y1)
-- gets the area of the lines and returns the transform.
local function transformLines(s, makeFn)
  local list = xfTargets()
  local x0, y0, x1, y1 = pathBounds(s.paths, list)
  if not x0 then return end
  local orig = copyNodes(s.paths, list)
  local fn = makeFn(x0, y0, x1, y1)
  edit(function()
    mapNodes(s.paths, orig, fn)
    if not s.paths[s.active] then s.paths.pivot = mapPivot(s.paths.pivot, fn) end
  end)
  askTimer:start()
end

-- Copies the selected line, or all lines when none is selected
local function copyShapes(s)
  local list = {}
  for _, pi in ipairs(xfTargets()) do list[#list + 1] = s.paths[pi] end
  if #list == 0 then return end
  clipboard = serialize(list)
  tip(#list == 1 and T.copiedOne or string.format(T.copiedMany, #list))
  updateButtons()
end

-- The shape of a line (its points and handles), to find copies of it
local function shapeKey(p)
  local t = { p.closed and "closed" or "open" }
  for _, n in ipairs(p.nodes) do
    t[#t + 1] = string.format("%d %d %.2f %.2f %.2f %.2f", n.x, n.y, n.ix, n.iy, n.ox, n.oy)
  end
  return table.concat(t, ";")
end

-- Adds the copied lines where they were, on top of the others. Pasted onto
-- the same lines (e.g. in the frame they were copied from), they go a few
-- pixels away (towards the inside of the canvas) so they can be seen.
-- A single pasted line gets selected.
local function pasteShapes(s)
  local list = clipboard and parse(clipboard) or {}
  if #list == 0 then return end
  local taken = {}
  for _, p in ipairs(s.paths) do taken[shapeKey(p)] = true end
  local function onTop()
    for _, p in ipairs(list) do
      if taken[shapeKey(p)] then return true end
    end
    return false
  end
  if onTop() then
    local all = {}
    for i = 1, #list do all[i] = i end
    local x0, y0, x1, y1 = pathBounds(list, all)
    local dx = (x1 + 4 <= s.sprite.width - 1 or x0 - 4 < 0) and 4 or -4
    local dy = (y1 + 4 <= s.sprite.height - 1 or y0 - 4 < 0) and 4 or -4
    local orig = copyNodes(list, all)
    for k = 1, 64 do
      mapNodes(list, orig, function(x, y) return x + k * dx, y + k * dy end)
      if not onTop() then break end
    end
  end
  edit(function()
    for _, p in ipairs(list) do s.paths[#s.paths + 1] = p end
    s.drawing = false
    if #list == 1 then select(#s.paths, nil) else select(nil, nil) end
  end)
  syncFields()
  askTimer:start()
end

-- Place Shape: asks for the kind of shape; then the next drag on the canvas
-- places it
local function placeShapeDialog(s)
  local names, kinds = {}, {}
  for i, k in ipairs(SHAPE_KINDS) do names[i], kinds[T.shapes[k]] = T.shapes[k], k end
  local dlg = Dialog{ title = T.placeTitle }
  local function update()
    local k = kinds[dlg.data.kind]
    dlg:modify{ id = "sides", enabled = k == "polygon" or k == "star" }
    dlg:modify{ id = "rounding", enabled = k == "roundRect" }
  end
  dlg:combobox{ id = "kind", label = T.shapeKind, option = T.shapes[prefs.placeKind or "ellipse"] or names[1],
                options = names, onchange = update }
     :number{ id = "sides", label = T.sides, text = tostring(prefs.placeSides or 5), decimals = 0 }
     :slider{ id = "rounding", label = T.rounding, min = 0, max = 100, value = prefs.placeRounding or 30 }
     :check{ id = "square", label = "", text = T.sameSize, selected = prefs.placeSquare == true }
     :button{ id = "ok", text = T.ok, focus = true }
     :button{ id = "cancel", text = T.cancel }
  update()
  dlg:show()
  if S ~= s or s.finished or not dlg.data.ok then return end
  local d = dlg.data
  local placing = { kind = kinds[d.kind] or "ellipse", rounding = d.rounding, square = d.square,
                    sides = math.max(3, math.min(64, floor(tonumber(d.sides) or 5))) }
  prefs.placeKind, prefs.placeSides = placing.kind, placing.sides
  prefs.placeRounding, prefs.placeSquare = placing.rounding, placing.square
  s.placing = placing
  s.drawing, s.xf = false, nil
  select(nil, nil)
  syncFields()
  refresh()
  askTimer:start()
end

-- Asks for exact values, showing the result while they're typed
local function numericTransform(s)
  local list = xfTargets()
  local x0, y0, x1, y1 = pathBounds(s.paths, list)
  if not x0 then return end
  -- Around the center of the transform box if it was moved, else the middle
  local cx, cy = turnCenter(x0, y0, x1, y1)
  local pv = pivotOwner().pivot
  if pv then cx, cy = pv.x, pv.y end
  local before = snapshot()
  local orig = copyNodes(s.paths, list)
  local dlg
  local function apply()
    if S ~= s or s.finished then return end
    local d = dlg.data
    local function angle(v) return math.rad(math.max(-89, math.min(89, v or 0))) end
    local sx, sy = (d.scaleX or 100) / 100, (d.scaleY or 100) / 100
    local tx, ty = math.tan(angle(d.shearX)), math.tan(angle(d.shearY))
    local a = math.rad(d.rotate or 0)
    local c, sn = math.cos(a), math.sin(a)
    -- Scale, then shear (positive: above the center moves right, right of
    -- it moves down), then rotate, all around the center
    mapNodes(s.paths, orig, function(px, py)
      local ux, uy = (px - cx) * sx, (py - cy) * sy
      ux = ux - tx * uy
      uy = uy + ty * ux
      return cx + ux * c - uy * sn, cy + ux * sn + uy * c
    end)
    redraw()
    app.refresh()
  end
  dlg = Dialog{ title = T.numericTitle }
  dlg:number{ id = "scaleX", label = T.scaleX, text = "100", decimals = 1, onchange = apply }
     :number{ id = "scaleY", label = T.scaleY, text = "100", decimals = 1, onchange = apply }
     :number{ id = "rotate", label = T.rotate, text = "0", decimals = 1, onchange = apply }
     :number{ id = "shearX", label = T.shearX, text = "0", decimals = 1, onchange = apply }
     :number{ id = "shearY", label = T.shearY, text = "0", decimals = 1, onchange = apply }
     :button{ id = "ok", text = T.ok, focus = true }
     :button{ id = "cancel", text = T.cancel }
  dlg:show()
  if S ~= s or s.finished then return end
  if dlg.data.ok then
    apply()
    s.lastMerge = nil
    pushUndo(before)
    refresh()
    askTimer:start()
  else
    restore(before)
  end
end

------------------------------------------------------------------------
-- Panel

local function changeStyle(key, apply)
  local s = S
  if panel then
    -- Remember the width, pixel-perfect and antialias settings for next time
    prefs.width = panel.data.width
    prefs.pixelPerfect = panel.data.pixelPerfect
    prefs.antialias = panel.data.antialias
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
  -- A color picker goes on the row of the checkbox before it, with a small
  -- label, where Aseprite can do that (Dialog:samerow); otherwise it gets a
  -- row of its own
  local sameRow = false
  pcall(function() sameRow = dlg.samerow ~= nil end)
  local function colorField(t, text)
    if sameRow then
      dlg:samerow():label{ text = text, hexpand = false }:samerow():color(t)
    else
      t.label = text
      dlg:color(t)
    end
    return dlg
  end
  dlg:label{ text = T.help1 }
     :newrow()
     :label{ text = T.help2 }
     -- Shapes: new, delete, copy and paste
     :button{ id = "newLine", text = T.newShape,
              onclick = whenEditing(function(s)
                -- Until drawing ends, clicks only draw the new line (other lines can't be grabbed)
                s.xf, s.placing = nil, nil
                s.drawing = true
                select(nil, nil)
                syncFields()
                refresh()
                askTimer:start()
              end) }
     :button{ id = "place", text = T.place, onclick = whenEditing(placeShapeDialog) }
     :button{ id = "deleteLine", text = T.deleteShape, onclick = whenEditing(deleteSelectedShape) }
     :newrow()
     :button{ id = "copy", text = T.copy, onclick = whenEditing(copyShapes) }
     :button{ id = "paste", text = T.paste, onclick = whenEditing(pasteShapes) }
     -- The shape: its antialiasing, then its line and its fill
     :separator{ id = "styleSep", text = T.nextShape }
     :check{ id = "antialias", label = "", text = T.antialias, selected = prefs.antialias == true,
             onclick = function()
               changeStyle("antialias", function(p) p.antialias = dlg.data.antialias end)
               updateButtons()
             end }
     :separator{ id = "lineSep", text = T.lineGroup }
     :check{ id = "stroke", label = "", text = T.stroke, selected = true,
             onclick = function()
               changeStyle("stroke", function(p) p.stroke = dlg.data.stroke end)
             end }
  colorField({ id = "color", color = app.fgColor,
               onchange = function()
                 changeStyle("color", function(p) p.color = colorToTable(dlg.data.color) end)
               end }, T.color)
     :slider{ id = "width", label = T.width, min = 1, max = 32, value = prefs.width or 1,
              onchange = function()
                changeStyle("width", function(p) p.width = dlg.data.width end)
              end }
     :check{ id = "pixelPerfect", label = "", text = T.pixelPerfect, selected = prefs.pixelPerfect ~= false,
             onclick = function()
               changeStyle("pixelPerfect", function(p) p.pixelPerfect = dlg.data.pixelPerfect end)
             end }
     :separator{ id = "fillSep", text = T.fillGroup }
     :check{ id = "fill", label = "", text = T.fill, selected = false,
             onclick = function()
               changeStyle("fill", function(p) p.fill = dlg.data.fill end)
             end }
  colorField({ id = "fillColor", color = app.fgColor,
               onchange = function()
                 changeStyle("fillColor", function(p) p.fillColor = colorToTable(dlg.data.fillColor) end)
               end }, T.fillColor)
     -- Editing options
     :separator{}
     :check{ id = "oneSide", label = "", text = T.oneSide, selected = false }
     :check{ id = "guides", text = T.guides, selected = true,
             onclick = whenEditing(function() refresh() end) }
     :separator{}
     :check{ id = "closed", label = "", text = T.closed, selected = false,
             onclick = function()
               changeStyle("closed", function(p) p.closed = dlg.data.closed end)
               -- Closing the shape being drawn finishes it (it stays selected)
               local s = S
               if s and not s.finished and s.drawing and dlg.data.closed and s.paths[s.active] then
                 s.drawing = false
                 s.selNode = nil
                 syncFields()
                 refresh()
                 askTimer:start()
               end
             end }
     :button{ id = "deletePoint", text = T.deletePoint, onclick = whenEditing(deleteSelectedPoint) }
     :button{ id = "roundSharp", text = T.roundSharp,
              onclick = whenEditing(function(s)
                if not (s.paths[s.active] and s.selNode) then return end
                local p, i = s.paths[s.active], s.selNode
                edit(function() toggleRound(p, i) end)
              end) }
     :separator{ id = "xfSep", text = T.transformAll }
     :button{ id = "transform", text = T.transformBox, onclick = whenEditing(toggleTransform) }
     :button{ id = "numeric", text = T.numeric, onclick = whenEditing(numericTransform) }
     :newrow()
     :button{ id = "flipH", text = T.flipH,
              onclick = whenEditing(function(s) transformLines(s, flipFn(false)) end) }
     :button{ id = "flipV", text = T.flipV,
              onclick = whenEditing(function(s) transformLines(s, flipFn(true)) end) }
     :newrow()
     :button{ id = "rotateLeft", text = T.rotateLeft,
              onclick = whenEditing(function(s) transformLines(s, rotateFn(-1)) end) }
     :button{ id = "rotateRight", text = T.rotateRight,
              onclick = whenEditing(function(s) transformLines(s, rotateFn(1)) end) }
     :newrow()
     :check{ id = "keepRatio", text = T.keepRatio, selected = prefs.keepRatio == true,
             onclick = function() prefs.keepRatio = dlg.data.keepRatio end }
     :separator{}
     :button{ id = "undo", text = T.undo, onclick = whenEditing(undo) }
     :button{ id = "redo", text = T.redo, onclick = whenEditing(redo) }
     :separator{}
     :button{ id = "stop", text = T.stop, onclick = stopEditing }
     :button{ id = "rasterize", text = T.rasterize,
              onclick = function() app.command.BezierCurveRasterize() end }
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

  local exiting = false
  if pending then
    local cmd = pending
    pending = nil
    -- Don't edit while the animation plays (it would stop the playback)
    if cmd.name == "PlayAnimation" and app.layer then paused = { layer = app.layer, play = true } end
    -- Aseprite is closing: put the preference back before it's saved
    if cmd.name == "Exit" then
      exiting = true
      restoreTileDoubleClick()
      closePanel()
    end
    local run = app.command[cmd.name]
    if run then
      rerunning = true
      pcall(run, cmd.params)
      rerunning = false
    end
  end

  if paused and app.layer ~= paused.layer then paused = nil end
  if not S and not paused and not exiting then
    local r = startSession(false)
    if r == "edited" then
      local layer, frame = app.layer, app.frame
      if not (lastSkip and lastSkip.layer == layer and lastSkip.frame == frame.frameNumber) then
        lastSkip = { layer = layer, frame = frame.frameNumber }
        tip(T.skippedTip)
      end
    end
  end
  if not S then
    closePanel()
    restoreTileDoubleClick()
  end
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
  elseif here and name == "PlayAnimation" and s.placing then
    -- Enter stops placing a shape (instead of playing the animation)
    s.placing = nil
    syncFields()
    refresh()
    askTimer:start()
    ev.stopPropagation()
  elseif here and name == "PlayAnimation" and s.xf then
    -- Enter ends transforming (instead of playing the animation)
    toggleTransform(s)
    ev.stopPropagation()
  elseif here and name == "PlayAnimation" and s.drawing then
    -- Enter ends drawing the line (instead of playing the animation)
    endDrawing()
    ev.stopPropagation()
  elseif here and name == "MaskContent" then
    -- Edit > Transform (Ctrl+T) shows the transform box
    if not s.xf then toggleTransform(s) end
    ev.stopPropagation()
  elseif here and (name == "Flip" or name == "Rotate") and ev.params and ev.params.target == "mask" then
    -- Edit > Flip (Shift+H, Shift+V) and Edit > Rotate turn the lines
    -- instead of the pixels
    if name == "Flip" then
      transformLines(s, flipFn(ev.params.orientation == "vertical"))
    else
      transformLines(s, rotateFn((tonumber(ev.params.angle) or 0) // 90))
    end
    ev.stopPropagation()
  elseif here and name == "Clear" then
    -- Delete/Backspace deletes the selected point, or the selected shape
    -- when no point is selected (never the pixels)
    if s.paths[s.active] and not s.selNode then
      deleteSelectedShape()
    else
      deleteSelectedPoint()
    end
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
    colorCurveLayer(layer)
    app.layer = layer
  end)
  paused = nil
  scheduleTick()
end

-- Turns the active curve layer into a normal layer: the pixels stay, the
-- curve data goes. Edit > Undo brings it back.
local function rasterizeLayer()
  local sprite, layer = app.sprite, app.layer
  if not sprite or not isCurveLayer(layer) then
    app.alert{ title = T.title, text = T.notCurveLayer }
    return
  end
  if not layer.isEditable then
    app.alert{ title = T.title, text = T.locked }
    return
  end
  app.transaction(T.rasterizeCmd, function()
    local cels = {}
    for _, c in ipairs(layer.cels) do cels[#cels + 1] = c end
    for _, c in ipairs(cels) do
      c.properties(KEY, {})
      -- Trim the canvas-sized cels to their pixels, like a normal layer
      local img = c.image
      local b = img:shrinkBounds()
      if b.width <= 0 or b.height <= 0 then
        sprite:deleteCel(c)
      elseif b.width < img.width or b.height < img.height then
        local pos = c.position
        c.image = Image(img, b)
        c.position = Point(pos.x + b.x, pos.y + b.y)
      end
    end
    layer.properties(KEY, {})
    if isCurveColor(layer.color) then layer.color = Color{ r = 0, g = 0, b = 0, a = 0 } end
  end)
  paused, lastSkip = nil, nil
  tip(T.rasterizedTip)
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
  restoreTileDoubleClick()

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
  plugin:newCommand{ id = "BezierCurveRasterize", title = T.rasterizeCmd, group = "layer_properties",
                     onenabled = onCurveLayer, onclick = rasterizeLayer }
  plugin:newCommand{ id = "BezierCurveRasterizePopup", title = T.rasterizeCmd, group = "layer_popup_properties",
                     onenabled = onCurveLayer, onclick = rasterizeLayer }

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
  -- Keep the note of the original value: if Aseprite saved its preferences
  -- before this, it's put back again at the next start
  local saved = prefs.savedDoubleClick
  restoreTileDoubleClick()
  prefs.savedDoubleClick = saved
  for _, id in ipairs(listeners) do pcall(function() app.events:off(id) end) end
  listeners = {}
  if askTimer then askTimer:stop() end
  if tickTimer then tickTimer:stop() end
end
