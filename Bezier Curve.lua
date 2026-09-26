-- Bezier Curve
-- Draws lines with Bezier curves that you can edit again later.
-- * Place points and drag their handles in the editor window. The lines are
--   drawn on a "curve layer" right above the active layer.
-- * Run the script again with the curve layer selected to edit the lines:
--   move points, bend them, change the color or width, add or delete lines.
-- * The curve data is saved in the cel, so it's kept in the .aseprite file.
--   Each frame has its own lines. Applying an edit is a single Ctrl+Z.

local KEY = "asepritescript/bezier-curve"
local TITLE = "Bezier Curve"

if not app.apiVersion or app.apiVersion < 21 then
  app.alert("This script needs Aseprite v1.3 or later.")
  return
end

-- Editing needs the canvas, so there's nothing to do without a UI
if not app.isUIAvailable then return end

local sprite = app.sprite
if not sprite then
  app.alert("No sprite is open.")
  return
end

local frameNumber = app.frame and app.frame.frameNumber or 1
local src = app.layer

local curveLayer = nil
if src and src.isImage and not src.isTilemap and src.properties(KEY).curve == true then
  curveLayer = src
end
if curveLayer and not curveLayer.isEditable then
  app.alert("The curve layer is locked. Unlock it and try again.")
  return
end

local pc = app.pixelColor
local floor, sqrt, abs = math.floor, math.sqrt, math.abs

local function round(v) return floor(v + 0.5) end

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

local function tableToColor(t)
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

local function dist(x0, y0, x1, y1)
  return sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
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

-- Pixel value to write in the sprite's color mode
local function outputPixel(p)
  local c = p.color
  if sprite.colorMode == ColorMode.INDEXED then
    return c.index
  elseif sprite.colorMode == ColorMode.GRAY then
    return pc.graya(grayOf(c), c.a)
  end
  return pc.rgba(c.r, c.g, c.b, c.a)
end

-- RGB pixel value used in the editor preview
local function previewPixel(p)
  local c = p.color
  if sprite.colorMode == ColorMode.INDEXED then
    local pal = sprite.palettes[1]
    if c.index == sprite.transparentColor or c.index < 0 or c.index >= #pal then return 0 end
    local pcol = pal:getColor(c.index)
    return pc.rgba(pcol.red, pcol.green, pcol.blue, pcol.alpha)
  elseif sprite.colorMode == ColorMode.GRAY then
    local g = grayOf(c)
    return pc.rgba(g, g, g, c.a)
  end
  return pc.rgba(c.r, c.g, c.b, c.a)
end

-- Draws all the lines into a new image trimmed to their bounds.
-- Returns the image and its position on the canvas.
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
  -- Nothing visible on the canvas: keep a 1x1 transparent image so the
  -- cel (and the curve data in it) isn't lost
  if #px == 0 then x0, y0, x1, y1 = 0, 0, 0, 0 end
  local img = Image(ImageSpec{
    width = x1 - x0 + 1, height = y1 - y0 + 1,
    colorMode = sprite.colorMode, transparentColor = sprite.transparentColor })
  img:clear()
  for i = 1, #px do img:drawPixel(px[i] - x0, py[i] - y0, pv[i]) end
  return img, Point(x0, y0)
end

------------------------------------------------------------------------
-- Load the lines of this frame

local paths = {}
local oldCel = curveLayer and curveLayer:cel(frameNumber)
-- The lines as they were loaded, to skip applying when nothing changed.
-- nil means the frame has to be redrawn anyway.
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
        text = { "The pixels in this frame were changed after the lines were drawn",
                 "(for example, painted over by hand).",
                 "Applying an edit redraws the frame from the lines, so those changes will be lost." },
        buttons = { "Continue", "Cancel" } }
      if r ~= 1 then return end
    end
    -- If the cel was moved (e.g. with the Move tool), move the lines with it
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
      text = { "This frame of the curve layer has pixels that aren't part of a line.",
               "They will be erased when you apply." },
      buttons = { "Continue", "Cancel" } }
    if r ~= 1 then return end
  end
end

-- The sprite as it looks now, without the curve layer
local bgImage = Image(sprite.width, sprite.height, ColorMode.RGB)
do
  local wasVisible = curveLayer and curveLayer.isVisible
  if curveLayer then curveLayer.isVisible = false end
  bgImage:drawSprite(sprite, frameNumber, Point(0, 0))
  if curveLayer then curveLayer.isVisible = wasVisible end
end
local previewImage = Image(sprite.width, sprite.height, ColorMode.RGB)

------------------------------------------------------------------------
-- Editor state

local dlg
local active, selNode = nil, nil   -- selected line and point
local hover = nil                  -- what's under the mouse
local drag = nil                   -- what's being dragged
local mouse = { x = 0, y = 0 }
local syncing = false              -- true while updating the fields from code
local undoStack, redoStack = {}, {}
local lastMerge = nil
local cursor = nil

local view = { zoom = 1, x = 0, y = 0, w = 480, h = 360, fitted = false }
local ZOOMS = { 1/16, 1/8, 1/4, 1/3, 1/2, 1, 2, 3, 4, 5, 6, 8, 10, 12, 16, 20, 24, 32, 48, 64 }
local HIT = 6   -- how close (in screen pixels) the mouse must be to grab something

local GUIDE = Color{ r = 0, g = 150, b = 255 }
local GUIDE_LINE = Color{ r = 0, g = 150, b = 255, a = 150 }
local WHITE = Color{ r = 255, g = 255, b = 255 }
local DARK = Color{ r = 40, g = 40, b = 40 }
local OUTSIDE = Color{ r = 96, g = 96, b = 96 }
local CHECK_A = Color{ r = 204, g = 204, b = 204 }
local CHECK_B = Color{ r = 153, g = 153, b = 153 }
local STATUS_BG = Color{ r = 0, g = 0, b = 0, a = 170 }

local HINT_NEW = "Click: start a new line"
local HINT_ADD = "Click: add a point to the line (drag to bend)"
local HINT_ANCHOR = "Drag: move   Right-click: delete   Double-click: round/sharp"
local HINT_HANDLE = "Drag: bend (Alt: one side only)   Right-click: remove"
local HINT_SEGMENT = "Click: add a point here   Drag: move the line"

local function updatePreview()
  previewImage:clear()
  for _, p in ipairs(paths) do
    local v = previewPixel(p)
    plotPath(p, function(x, y) previewImage:drawPixel(x, y, v) end)
  end
end

local function snapshot()
  return { data = serialize(paths), active = active, sel = selNode }
end

-- Adds an undo step if the lines changed since `before`
local function pushUndo(before)
  if before.data == serialize(paths) then return false end
  undoStack[#undoStack + 1] = before
  redoStack = {}
  return true
end

-- Runs fn as one editing step. Consecutive steps with the same mergeKey
-- (e.g. dragging the width slider) become a single undo step.
local function edit(fn, mergeKey)
  local before = nil
  if not mergeKey or mergeKey ~= lastMerge then before = snapshot() end
  fn()
  if before then
    lastMerge = pushUndo(before) and mergeKey or nil
  end
  updatePreview()
  dlg:repaint()
end

local function syncFields()
  local p = paths[active]
  syncing = true
  if p then
    dlg:modify{ id = "color", color = tableToColor(p.color) }
    dlg:modify{ id = "width", value = p.width }
    dlg:modify{ id = "pixelPerfect", selected = p.pixelPerfect }
    dlg:modify{ id = "closed", selected = p.closed, enabled = true }
    dlg:modify{ id = "styleSep", text = "Selected Line" }
  else
    dlg:modify{ id = "closed", selected = false, enabled = false }
    dlg:modify{ id = "styleSep", text = "Next Line" }
  end
  dlg:modify{ id = "deleteLine", enabled = p ~= nil }
  syncing = false
end

local function select(pi, ni)
  local changed = pi ~= active
  active, selNode = pi, ni
  if changed then syncFields() end
end

local function restore(s)
  paths = parse(s.data)
  active, selNode = s.active, s.sel
  if not paths[active] then active, selNode = nil, nil end
  if active and selNode and not paths[active].nodes[selNode] then selNode = nil end
  lastMerge = nil
  hover = nil
  drag = nil
  syncFields()
  updatePreview()
  dlg:repaint()
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

------------------------------------------------------------------------
-- View (zoom and scroll)

local function toScreen(x, y)
  return view.x + (x + 0.5) * view.zoom, view.y + (y + 0.5) * view.zoom
end

local function toSprite(sx, sy)
  return (sx - view.x) / view.zoom - 0.5, (sy - view.y) / view.zoom - 0.5
end

local function fitView()
  local margin = 24
  local fit = math.min((view.w - margin * 2) / sprite.width, (view.h - margin * 2) / sprite.height)
  local z = ZOOMS[1]
  for _, v in ipairs(ZOOMS) do
    if v <= fit then z = v end
  end
  view.zoom = z
  view.x = round((view.w - sprite.width * z) / 2)
  view.y = round((view.h - sprite.height * z) / 2)
end

local function zoomAt(sx, sy, dir)
  local i = 1
  for k, v in ipairs(ZOOMS) do
    if v <= view.zoom then i = k end
  end
  local ni = math.max(1, math.min(#ZOOMS, i + dir))
  if ni == i then return end
  local fx, fy = (sx - view.x) / view.zoom, (sy - view.y) / view.zoom
  view.zoom = ZOOMS[ni]
  view.x = round(sx - fx * view.zoom)
  view.y = round(sy - fy * view.zoom)
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

local function snap45(dx, dy)
  local len = sqrt(dx * dx + dy * dy)
  if len == 0 then return 0, 0 end
  local step = math.pi / 4
  local a = round(math.atan(dy, dx) / step) * step
  return len * math.cos(a), len * math.sin(a)
end

-- Moves one handle to (hx, hy). A smooth point turns the other handle too.
local function moveHandle(n, side, hx, hy, alt, shift)
  local dx, dy = hx - n.x, hy - n.y
  if shift then dx, dy = snap45(dx, dy) end
  local ox, oy
  if side == "out" then
    n.ox, n.oy = dx, dy
    ox, oy = n.ix, n.iy
  else
    n.ix, n.iy = dx, dy
    ox, oy = n.ox, n.oy
  end
  if alt then
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
local function pullHandles(n, hx, hy, shift)
  local dx, dy = hx - n.x, hy - n.y
  if shift then dx, dy = snap45(dx, dy) end
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

-- Double-click: a point with handles becomes sharp, a sharp one becomes round
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

-- Distance check between the mouse and a segment drawn on screen.
-- Returns the t of the closest point, or nil if it's too far.
local function hitSegment(a, b, mx, my, tolerance)
  local c1x, c1y = toScreen(a.x + a.ox, a.y + a.oy)
  local c2x, c2y = toScreen(b.x + b.ix, b.y + b.iy)
  local ax, ay = toScreen(a.x, a.y)
  local bx, by = toScreen(b.x, b.y)
  local len = dist(ax, ay, c1x, c1y) + dist(c1x, c1y, c2x, c2y) + dist(c2x, c2y, bx, by)
  local steps = math.max(8, math.min(400, math.ceil(len / 6)))
  local best, bestT = tolerance * tolerance, nil
  local px, py = ax, ay
  for i = 1, steps do
    local qx, qy = toScreen(bezier(a, b, i / steps))
    local dx, dy = qx - px, qy - py
    local l2 = dx * dx + dy * dy
    local u = 0
    if l2 > 0 then u = math.max(0, math.min(1, ((mx - px) * dx + (my - py) * dy) / l2)) end
    local d2 = (mx - px - u * dx) ^ 2 + (my - py - u * dy) ^ 2
    if d2 <= best then best, bestT = d2, (i - 1 + u) / steps end
    px, py = qx, qy
  end
  return bestT
end

-- Finds what's under the mouse: a handle, a point, or a line
local function hitTest(mx, my)
  local function near(x, y)
    local sx, sy = toScreen(x, y)
    return (sx - mx) ^ 2 + (sy - my) ^ 2 <= HIT * HIT
  end

  -- Handles of the selected line (unless they overlap their point)
  local p = paths[active]
  if p then
    for i, n in ipairs(p.nodes) do
      local ax, ay = toScreen(n.x, n.y)
      for _, side in ipairs({ "out", "in" }) do
        if hasHandle(n, side) and handleUsed(p, i, side) then
          local hx, hy = handlePos(n, side)
          local sx, sy = toScreen(hx, hy)
          if (sx - ax) ^ 2 + (sy - ay) ^ 2 > HIT * HIT and near(hx, hy) then
            return { kind = "handle", path = active, node = i, side = side }
          end
        end
      end
    end
  end

  -- Selected line first, then the others from top to bottom
  local order = {}
  if p then order[1] = active end
  for i = #paths, 1, -1 do
    if i ~= active then order[#order + 1] = i end
  end

  for _, pi in ipairs(order) do
    for i, n in ipairs(paths[pi].nodes) do
      if near(n.x, n.y) then return { kind = "anchor", path = pi, node = i } end
    end
  end

  for _, pi in ipairs(order) do
    local q = paths[pi]
    local tolerance = math.max(5, q.width * view.zoom / 2 + 2)
    for _, s in ipairs(segments(q)) do
      local t = hitSegment(s[1], s[2], mx, my, tolerance)
      if t then return { kind = "segment", path = pi, seg = s[3], t = t } end
    end
  end
  return nil
end

local function setCursor(kind)
  if not MouseCursor then return end
  local c = MouseCursor.CROSSHAIR
  if kind == "anchor" or kind == "handle" then
    c = MouseCursor.MOVE
  elseif kind == "segment" then
    c = MouseCursor.POINTER
  elseif kind == "pan" then
    c = MouseCursor.GRABBING or MouseCursor.MOVE
  end
  if c ~= cursor then
    cursor = c
    dlg:modify{ id = "canvas", mousecursor = c }
  end
end

------------------------------------------------------------------------
-- Painting the canvas

local function box(gc, x, y, r, fill, stroke)
  local rc = Rectangle(round(x) - r, round(y) - r, 2 * r + 1, 2 * r + 1)
  gc.color = fill
  gc:fillRect(rc)
  gc.color = stroke
  gc:strokeRect(rc)
end

local function diamond(gc, x, y, r, fill, stroke)
  x, y = round(x) + 0.5, round(y) + 0.5
  gc:beginPath()
  gc:moveTo(x, y - r)
  gc:lineTo(x + r, y)
  gc:lineTo(x, y + r)
  gc:lineTo(x - r, y)
  gc:closePath()
  gc.color = fill
  gc:fill()
  gc.color = stroke
  gc:stroke()
end

local function strokePath(gc, p)
  if #p.nodes < 2 then return end
  gc:beginPath()
  gc:moveTo(toScreen(p.nodes[1].x, p.nodes[1].y))
  for _, s in ipairs(segments(p)) do
    local a, b = s[1], s[2]
    local c1x, c1y = toScreen(a.x + a.ox, a.y + a.oy)
    local c2x, c2y = toScreen(b.x + b.ix, b.y + b.iy)
    local ex, ey = toScreen(b.x, b.y)
    gc:cubicTo(c1x, c1y, c2x, c2y, ex, ey)
  end
  gc:stroke()
end

local function drawCheckerboard(gc, x0, y0, x1, y1)
  gc.color = CHECK_A
  gc:fillRect(Rectangle(x0, y0, x1 - x0, y1 - y0))
  gc.color = CHECK_B
  local C = 8
  for j = (y0 - view.y) // C, (y1 - 1 - view.y) // C do
    local ry0 = math.max(y0, view.y + j * C)
    local ry1 = math.min(y1, view.y + (j + 1) * C)
    for i = (x0 - view.x) // C, (x1 - 1 - view.x) // C do
      if (i + j) % 2 == 1 then
        local rx0 = math.max(x0, view.x + i * C)
        local rx1 = math.min(x1, view.x + (i + 1) * C)
        gc:fillRect(Rectangle(rx0, ry0, rx1 - rx0, ry1 - ry0))
      end
    end
  end
end

local function statusText()
  local h = hover
  if not h then
    local p = paths[active]
    if p and not p.closed then return HINT_ADD end
    return HINT_NEW
  elseif h.kind == "anchor" then
    return HINT_ANCHOR
  elseif h.kind == "handle" then
    return HINT_HANDLE
  end
  return HINT_SEGMENT
end

local function paint(ev)
  local gc = ev.context
  view.w, view.h = gc.width, gc.height
  if not view.fitted then
    fitView()
    view.fitted = true
  end
  local z = view.zoom

  gc.color = OUTSIDE
  gc:fillRect(Rectangle(0, 0, view.w, view.h))

  -- Visible part of the sprite
  local x0 = math.max(0, floor(-view.x / z))
  local y0 = math.max(0, floor(-view.y / z))
  local x1 = math.min(sprite.width, math.ceil((view.w - view.x) / z))
  local y1 = math.min(sprite.height, math.ceil((view.h - view.y) / z))
  if x1 > x0 and y1 > y0 then
    local sx0, sy0 = round(view.x + x0 * z), round(view.y + y0 * z)
    local sx1, sy1 = round(view.x + x1 * z), round(view.y + y1 * z)
    drawCheckerboard(gc, math.max(sx0, 0), math.max(sy0, 0),
                     math.min(sx1, view.w), math.min(sy1, view.h))
    gc:drawImage(bgImage, x0, y0, x1 - x0, y1 - y0, sx0, sy0, sx1 - sx0, sy1 - sy0)
    gc:drawImage(previewImage, x0, y0, x1 - x0, y1 - y0, sx0, sy0, sx1 - sx0, sy1 - sy0)
  end

  -- Outline of the selected line and the one under the mouse
  gc.strokeWidth = 1
  gc.antialias = true
  gc.color = GUIDE_LINE
  for pi, p in ipairs(paths) do
    if pi == active or (hover and hover.path == pi) then strokePath(gc, p) end
  end
  gc.antialias = false

  -- Points of the other lines
  for pi, p in ipairs(paths) do
    if pi ~= active then
      for _, n in ipairs(p.nodes) do
        local x, y = toScreen(n.x, n.y)
        box(gc, x, y, 2, WHITE, DARK)
      end
    end
  end

  -- Points and handles of the selected line
  local p = paths[active]
  if p then
    for i, n in ipairs(p.nodes) do
      local ax, ay = toScreen(n.x, n.y)
      for _, side in ipairs({ "in", "out" }) do
        if hasHandle(n, side) and handleUsed(p, i, side) then
          local hx, hy = toScreen(handlePos(n, side))
          gc.color = GUIDE
          gc:beginPath()
          gc:moveTo(ax, ay)
          gc:lineTo(hx, hy)
          gc:stroke()
          diamond(gc, hx, hy, 4, GUIDE, WHITE)
        end
      end
    end
    for i, n in ipairs(p.nodes) do
      local x, y = toScreen(n.x, n.y)
      if i == selNode then box(gc, x, y, 3, GUIDE, WHITE) else box(gc, x, y, 3, WHITE, GUIDE) end
    end
  end

  -- Status bar: hint, pixel under the mouse and zoom
  local text = statusText()
  local mx, my = toSprite(mouse.x, mouse.y)
  local info = string.format("%d, %d   %d%%", round(mx), round(my), round(z * 100))
  local th = gc:measureText("Ag").height
  local bh = th + 6
  gc.color = STATUS_BG
  gc:fillRect(Rectangle(0, view.h - bh, view.w, bh))
  gc.color = WHITE
  gc:fillText(text, 5, view.h - bh + 3)
  local iw = gc:measureText(info).width
  if gc:measureText(text).width + iw + 20 < view.w then
    gc:fillText(info, view.w - iw - 5, view.h - bh + 3)
  end
end

------------------------------------------------------------------------
-- Mouse and keyboard

local function onMouseDown(ev)
  mouse.x, mouse.y = ev.x, ev.y
  if ev.button == MouseButton.MIDDLE or (ev.button == MouseButton.LEFT and ev.spaceKey) then
    drag = { kind = "pan", mx = ev.x, my = ev.y, vx = view.x, vy = view.y }
    setCursor("pan")
    return
  end

  local hit = hitTest(ev.x, ev.y)

  if ev.button == MouseButton.RIGHT then
    if hit and hit.kind == "anchor" then
      edit(function() deleteNode(hit.path, hit.node) end)
    elseif hit and hit.kind == "handle" then
      edit(function()
        local n = paths[hit.path].nodes[hit.node]
        if hit.side == "in" then n.ix, n.iy = 0, 0 else n.ox, n.oy = 0, 0 end
      end)
    end
    hover = hitTest(ev.x, ev.y)
    dlg:repaint()
    return
  end
  if ev.button ~= MouseButton.LEFT then return end

  lastMerge = nil
  local before = snapshot()
  if hit and hit.kind == "handle" then
    select(hit.path, hit.node)
    drag = { kind = "handle", hit = hit, before = before }
  elseif hit and hit.kind == "anchor" then
    select(hit.path, hit.node)
    local n = paths[hit.path].nodes[hit.node]
    drag = { kind = ev.altKey and "pull" or "anchor", hit = hit, before = before,
             mx = ev.x, my = ev.y, x = n.x, y = n.y }
  elseif hit and hit.kind == "segment" then
    select(hit.path, nil)
    local orig = {}
    for i, n in ipairs(paths[hit.path].nodes) do orig[i] = { n.x, n.y } end
    drag = { kind = "segment", hit = hit, before = before, mx = ev.x, my = ev.y, orig = orig }
  else
    -- Add a point to the end of the selected line, or start a new line
    local p = paths[active]
    if not p or p.closed then
      local d = dlg.data
      p = { color = colorToTable(d.color), width = d.width, pixelPerfect = d.pixelPerfect,
            closed = false, nodes = {} }
      paths[#paths + 1] = p
      select(#paths, nil)
    end
    local x, y = toSprite(ev.x, ev.y)
    p.nodes[#p.nodes + 1] = { x = round(x), y = round(y), ix = 0, iy = 0, ox = 0, oy = 0, smooth = false }
    selNode = #p.nodes
    hit = { kind = "anchor", path = active, node = selNode }
    drag = { kind = "pull", hit = hit, before = before }
    updatePreview()
  end
  hover = hit
  dlg:repaint()
end

local function onMouseMove(ev)
  mouse.x, mouse.y = ev.x, ev.y
  local d = drag
  if not d then
    hover = hitTest(ev.x, ev.y)
    setCursor(hover and hover.kind)
    dlg:repaint()
    return
  end

  if d.kind == "pan" then
    view.x, view.y = round(d.vx + ev.x - d.mx), round(d.vy + ev.y - d.my)
  elseif d.kind == "anchor" or d.kind == "segment" then
    local dx = round((ev.x - d.mx) / view.zoom)
    local dy = round((ev.y - d.my) / view.zoom)
    if ev.shiftKey then
      if abs(dx) >= abs(dy) then dy = 0 else dx = 0 end
    end
    if d.kind == "anchor" then
      local n = paths[d.hit.path].nodes[d.hit.node]
      n.x, n.y = d.x + dx, d.y + dy
    else
      -- Clicking a line adds a point; dragging it moves the whole line
      if not d.moved and (ev.x - d.mx) ^ 2 + (ev.y - d.my) ^ 2 > 9 then d.moved = true end
      if d.moved then
        for i, n in ipairs(paths[d.hit.path].nodes) do
          n.x, n.y = d.orig[i][1] + dx, d.orig[i][2] + dy
        end
      end
    end
    updatePreview()
  elseif d.kind == "handle" then
    local hx, hy = toSprite(ev.x, ev.y)
    moveHandle(paths[d.hit.path].nodes[d.hit.node], d.hit.side, hx, hy, ev.altKey, ev.shiftKey)
    updatePreview()
  elseif d.kind == "pull" then
    local n = paths[d.hit.path].nodes[d.hit.node]
    local ax, ay = toScreen(n.x, n.y)
    if (ev.x - ax) ^ 2 + (ev.y - ay) ^ 2 < 9 then
      n.ix, n.iy, n.ox, n.oy, n.smooth = 0, 0, 0, 0, false
    else
      local hx, hy = toSprite(ev.x, ev.y)
      pullHandles(n, hx, hy, ev.shiftKey)
    end
    updatePreview()
  end
  dlg:repaint()
end

local function onMouseUp(ev)
  local d = drag
  if not d then return end
  drag = nil
  if d.kind == "segment" and not d.moved then
    local ni = insertNode(paths[d.hit.path], d.hit.seg, d.hit.t)
    select(d.hit.path, ni)
    updatePreview()
  end
  if d.before then pushUndo(d.before) end
  hover = hitTest(ev.x, ev.y)
  setCursor(hover and hover.kind)
  dlg:repaint()
end

local function onDoubleClick(ev)
  if ev.button ~= MouseButton.LEFT then return end
  if drag and drag.kind ~= "pan" then drag = nil end
  local hit = hitTest(ev.x, ev.y)
  if hit and hit.kind == "anchor" then
    select(hit.path, hit.node)
    edit(function() toggleRound(paths[hit.path], hit.node) end)
  end
end

local function onWheel(ev)
  local dir = 0
  if ev.deltaY < 0 then dir = 1 elseif ev.deltaY > 0 then dir = -1 end
  if dir ~= 0 then
    zoomAt(ev.x, ev.y, dir)
    hover = hitTest(ev.x, ev.y)
    dlg:repaint()
  end
end

local ARROWS = { ArrowLeft = { -1, 0 }, ArrowRight = { 1, 0 }, ArrowUp = { 0, -1 }, ArrowDown = { 0, 1 } }

local function onKeyDown(ev)
  local code = ev.code
  local ctrl = ev.ctrlKey or ev.metaKey
  if ctrl and code == "KeyZ" then
    if ev.shiftKey then redo() else undo() end
    ev:stopPropagation()
  elseif ctrl and code == "KeyY" then
    redo()
    ev:stopPropagation()
  elseif code == "Escape" and (drag or paths[active]) then
    -- Esc cancels the drag or deselects the line before it closes the window
    local d = drag
    drag = nil
    if d and d.before then
      restore(d.before)
    else
      select(nil, nil)
      hover = nil
      dlg:repaint()
    end
    ev:stopPropagation()
  elseif (code == "Delete" or code == "Backspace") and paths[active] and selNode then
    edit(function() deleteNode(active, selNode) end)
    ev:stopPropagation()
  elseif ARROWS[code] and paths[active] and selNode then
    -- Arrow keys nudge the selected point by 1 pixel
    local n = paths[active].nodes[selNode]
    edit(function()
      n.x, n.y = n.x + ARROWS[code][1], n.y + ARROWS[code][2]
    end, "nudge" .. active .. ":" .. selNode)
    ev:stopPropagation()
  end
end

------------------------------------------------------------------------
-- Dialog

local function changeStyle(key, apply)
  if syncing then return end
  local p = paths[active]
  if p then edit(function() apply(p) end, key .. active) end
end

dlg = Dialog{ title = TITLE }
dlg:canvas{ id = "canvas", width = 480, height = 360,
            onpaint = paint,
            onmousedown = onMouseDown,
            onmousemove = onMouseMove,
            onmouseup = onMouseUp,
            ondblclick = onDoubleClick,
            onwheel = onWheel,
            onkeydown = onKeyDown }
   :label{ text = "Wheel: zoom   Middle-drag / Space+drag: scroll   Shift: straight   Ctrl+Z: undo" }
   :separator{ id = "styleSep", text = "Next Line" }
   :color{ id = "color", label = "Color", color = app.fgColor,
           onchange = function()
             changeStyle("color", function(p) p.color = colorToTable(dlg.data.color) end)
           end }
   :slider{ id = "width", label = "Width", min = 1, max = 32, value = 1,
            onchange = function()
              changeStyle("width", function(p) p.width = dlg.data.width end)
            end }
   :check{ id = "pixelPerfect", label = "", text = "Pixel-perfect (width 1)", selected = true,
           onclick = function()
             changeStyle("pixelPerfect", function(p) p.pixelPerfect = dlg.data.pixelPerfect end)
           end }
   :check{ id = "closed", text = "Connect the ends", selected = false,
           onclick = function()
             changeStyle("closed", function(p) p.closed = dlg.data.closed end)
           end }
   :button{ id = "newLine", text = "New Line",
            onclick = function()
              select(nil, nil)
              hover = nil
              dlg:repaint()
            end }
   :button{ id = "deleteLine", text = "Delete Line",
            onclick = function()
              if not paths[active] then return end
              local pi = active
              edit(function()
                table.remove(paths, pi)
                select(nil, nil)
              end)
            end }
   :button{ id = "undo", text = "Undo", onclick = undo }
   :button{ id = "fit", text = "Fit",
            onclick = function()
              fitView()
              dlg:repaint()
            end }
   :separator{}
   :button{ id = "ok", text = "Apply", focus = true }
   :button{ id = "cancel", text = "Cancel" }

syncFields()
updatePreview()
dlg:show()

if not dlg.data.ok then return end

------------------------------------------------------------------------
-- Apply

local result = serialize(paths)
if result == original then return end

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
  while used["Curve " .. n] do n = n + 1 end
  return "Curve " .. n
end

app.transaction(TITLE, function()
  local layer = curveLayer
  if not layer then
    layer = sprite:newLayer()
    layer.name = newLayerName()
    if src then
      layer.parent = src.parent
      layer.stackIndex = src.stackIndex + 1
    end
    layer.properties(KEY).curve = true
  end

  local cel = layer:cel(frameNumber)
  if #paths == 0 then
    if cel then sprite:deleteCel(cel) end
  else
    local img, pos = renderPaths(paths)
    if cel then
      cel.image = img
      cel.position = pos
    else
      cel = sprite:newCel(layer, frameNumber, img, pos)
    end
    cel.properties(KEY, { version = 1, x = pos.x, y = pos.y, paths = result })
  end

  app.layer = layer
end)

app.refresh()
