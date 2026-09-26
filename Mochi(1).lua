--!nonstrict
--[[
	Mochi UI  —  UI-библиотека для Roblox Studio
	Кладёшь как ModuleScript (например ReplicatedStorage.Mochi), подключаешь из LocalScript.

	Что внутри:
	  • окно: раскрывающаяся левая панель (стрелочка), логотип растёт под панель, секции сверху справа
	  • на телефоне панель по умолчанию свёрнута в иконки, по стрелке выезжает поверх контента
	  • маскот над логотипом (картинка / кадры / спрайтшит вместо гифки)
	  • логотип и иконки на SVG (мини-растеризатор SVG -> EditableImage), логотип можно заменить
	  • темы: Mochi.ThemeNames (один цвет и два цвета, тёмные и светлая), Window:SetTheme("Ocean")
	  • ВЛАСТЬ НАД ВИДОМ: Window:SetStyle({...}) на лету — скругление всего (Round), скругление каждой
	    детали отдельно (Radius = { thumb = 0, toggle = 0, card = 4 ... }), размеры логотипа/панели,
	    название, рамка, квадратное окно, масштаб (Window:SetScale)
	  • конфиги: сохранить / загрузить / удалить / автозагрузка / экспорт-импорт текстом
	    (файлы, если в среде есть writefile/readfile; иначе на сессию + экспорт/импорт; можно свой backend)
	  • бинды: Keybind = Enum.KeyCode.X у Toggle и Button, отдельный элемент Keybind
	  • Window:AddSettingsTab() — готовая вкладка настроек (тема, вид, масштаб, клавиша меню, конфиги)
	  • элементы: Toggle, Slider, Dropdown (Multi), Button, Keybind, Input, Label

	Важно про SVG:
	  Roblox не умеет SVG нативно, поэтому SVG растеризуется в EditableImage.
	  В Studio работает сразу. В опубликованной игре EditableImage нужно включить:
	  Game Settings > Security > "Allow Mesh & Image APIs" (нужна верификация аккаунта).
	  Если EditableImage недоступен — библиотека не падает, логотип заменяется буквой.
	  Поддерживается: path (M L H V C S Q T A Z), circle, ellipse, rect, polygon,
	  fill / fill-opacity / opacity / fill-rule. Обводки (stroke) и градиенты не поддерживаются —
	  рисуй всё заливкой. fill="accent" и fill="accent2" = цвета акцента окна.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local AssetService = game:GetService("AssetService")
local ContentProvider = game:GetService("ContentProvider")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Mochi = {}

local FONT = Enum.Font.Gotham
local FONT_B = Enum.Font.GothamBold
local TOUCH = UserInputService.TouchEnabled
local ELEM_H = TOUCH and 38 or 34
local SS = 4 -- субсэмплов на пиксель по вертикали (сглаживание SVG)

local function C(r, g, b) return Color3.fromRGB(r, g, b) end

-- базовые палитры (цвета интерфейса), акценты добавляются поверх
local Bases = {
	Ink = { -- чёрный с фиолетовым оттенком
		Bg = C(17, 17, 23), Side = C(22, 22, 30), Elem = C(30, 30, 41), ElemHover = C(37, 37, 51),
		Track = C(46, 46, 62), Stroke = C(58, 58, 78), Text = C(236, 236, 246), SubText = C(148, 148, 172),
	},
	Pitch = { -- почти чистый чёрный
		Bg = C(10, 10, 12), Side = C(15, 15, 18), Elem = C(22, 22, 26), ElemHover = C(29, 29, 34),
		Track = C(38, 38, 44), Stroke = C(50, 50, 58), Text = C(240, 240, 242), SubText = C(150, 150, 158),
	},
	Navy = { -- тёмно-синий
		Bg = C(12, 15, 26), Side = C(16, 20, 34), Elem = C(23, 28, 46), ElemHover = C(30, 36, 58),
		Track = C(38, 46, 72), Stroke = C(52, 62, 96), Text = C(232, 238, 250), SubText = C(140, 152, 185),
	},
	Snow = { -- светлая
		Bg = C(243, 243, 249), Side = C(233, 233, 242), Elem = C(252, 252, 255), ElemHover = C(244, 244, 252),
		Track = C(214, 214, 228), Stroke = C(200, 200, 218), Text = C(28, 28, 40), SubText = C(105, 105, 130),
	},
}

local function mk(base, a1, a2)
	local t = table.clone(Bases[base])
	t.Accent = a1
	t.Accent2 = a2 or a1
	return t
end

-- порядок = порядок в списке Mochi.ThemeNames
local themeList = {
	-- один цвет
	{ "Pink", mk("Ink", C(255, 122, 189)) },
	{ "Violet", mk("Ink", C(150, 100, 255)) },
	{ "Blue", mk("Navy", C(95, 145, 255)) },
	{ "Mono", mk("Pitch", C(236, 236, 242)) },
	{ "Snow", mk("Snow", C(130, 90, 240)) },
	{ "Crimson", mk("Pitch", C(255, 72, 92)) },
	{ "Mint", mk("Pitch", C(70, 225, 170)) },
	{ "Amber", mk("Pitch", C(255, 170, 60)) },
	-- два цвета
	{ "Violet+Blue", mk("Ink", C(150, 100, 255), C(80, 150, 255)) },
	{ "Violet+White", mk("Pitch", C(150, 100, 255), C(240, 240, 250)) },
	{ "White+Violet", mk("Pitch", C(240, 240, 250), C(150, 100, 255)) },
	{ "Ultraviolet", mk("Ink", C(150, 90, 255), C(255, 100, 200)) },
	{ "Ocean", mk("Navy", C(70, 140, 255), C(70, 230, 200)) },
	{ "Neon", mk("Pitch", C(60, 230, 255), C(170, 90, 255)) },
	{ "Sunset", mk("Ink", C(255, 150, 70), C(255, 80, 150)) },
	{ "Bloodmoon", mk("Pitch", C(255, 60, 80), C(150, 60, 255)) },
	{ "Snow+Blue", mk("Snow", C(130, 90, 240), C(80, 150, 255)) },
}
Mochi.Themes = {}
Mochi.ThemeNames = {}
for _, t in ipairs(themeList) do
	Mochi.Themes[t[1]] = t[2]
	table.insert(Mochi.ThemeNames, t[1])
end

-- виды меню (готовые наборы; любой параметр потом можно менять через Window:SetStyle)
--   Round          множитель скругления всего (0 = всё квадратное, 1 = как задумано)
--   Radius         точечные переопределения в пикселях по имени детали, false = сбросить
--                  имена: window card button option input chip avatar toggle knob track thumb fab strip key underline arrow close
--   Title          показывать название под логотипом, когда панель раскрыта
--   LogoSize       размер логотипа в свёрнутой панели (в раскрытой логотип сам растёт под панель)
--   CollapsedWidth / ExpandedWidth   ширина свёрнутой и раскрытой панели
--   Strip / StripH ширина цветной полоски на кнопках и её высота (наведение, актив, нажатие)
--   CardStroke     прозрачность рамки у карточек (0 = чёткая, 1 = нет)
--   OutlineAccent  цветная рамка вокруг окна
--   SidebarMode    как раскрывается левая панель: "Auto" | "Overlay" (поверх) | "Slide" (сдвигает контент, не сжимая) | "Push" (сжимает контент)
--                  Auto: на телефоне Slide, на ПК Push
--   SliderStyle    "Knob" (дорожка с кружком) | "Bar" (прямоугольная полоса без кружка, как на скетче)
--   ToggleStyle    "Switch" (переключатель) | "Checkbox" (квадратная галочка)
Mochi.Styles = {
	-- мягкое, скруглённое
	Soft = {
		Round = 1, Radius = {}, Title = true, LogoSize = 34, CollapsedWidth = 64, ExpandedWidth = 176,
		Strip = 3, StripH = { 0.62, 0.4, 0.7 }, CardStroke = 0.55, OutlineAccent = false,
		SidebarMode = "Auto", SliderStyle = "Knob", ToggleStyle = "Switch",
	},
	-- острое, квадратное, без названия, логотип крупный
	Sharp = {
		Round = 0, Radius = {}, Title = false, LogoSize = 54, CollapsedWidth = 64, ExpandedWidth = 176,
		Strip = 4, StripH = { 1, 0.55, 1 }, CardStroke = 0.15, OutlineAccent = true,
		SidebarMode = "Auto", SliderStyle = "Bar", ToggleStyle = "Checkbox",
	},
}

----------------------------------------------------------------------
-- SVG -> EditableImage
----------------------------------------------------------------------
local Svg = {}
local svgCache = {}
local svgKeep = {}

local NAMED = { white = Color3.new(1, 1, 1), black = Color3.new(0, 0, 0) }

local function num(v, d)
	if v == nil then return d end
	return tonumber(tostring(v):match("^%s*([-+]?%d*%.?%d+)")) or d
end

local function parseColor(s, accent, accent2)
	if not s or s == "none" then return nil end
	if s == "accent2" then return accent2 end
	if s == "accent" or s == "currentColor" or s:find("^url") then return accent end
	local hex = s:match("^#(%x+)$")
	if hex then
		if #hex == 3 then hex = (hex:gsub(".", "%0%0")) end
		if #hex >= 6 then
			return Color3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
		end
	end
	local r, g, b = s:match("^rgb%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*%)")
	if r then return Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b)) end
	return NAMED[s:lower()] or accent
end

local function parseAttrs(str)
	local at = {}
	for k, v in str:gmatch('([%w%-:]+)%s*=%s*"([^"]*)"') do at[k] = v end
	for k, v in str:gmatch("([%w%-:]+)%s*=%s*'([^']*)'") do at[k] = v end
	return at
end

local function tokenize(d)
	local t, pos = {}, 1
	while pos <= #d do
		local c = d:sub(pos, pos)
		if c:match("[MmLlHhVvCcSsQqTtAaZz]") then
			t[#t + 1] = c
			pos += 1
		else
			local s, e = d:find("^[-+]?%d*%.?%d+[eE][-+]?%d+", pos)
			if not s then s, e = d:find("^[-+]?%d*%.?%d+", pos) end
			if s then
				t[#t + 1] = tonumber(d:sub(s, e))
				pos = e + 1
			else
				pos += 1
			end
		end
	end
	return t
end

local function arcPoints(x1, y1, rx, ry, phiDeg, fa, fs, x2, y2, push)
	if rx == 0 or ry == 0 or (x1 == x2 and y1 == y2) then
		push(x2, y2)
		return
	end
	rx, ry = math.abs(rx), math.abs(ry)
	local phi = math.rad(phiDeg)
	local cp, sp = math.cos(phi), math.sin(phi)
	local dx, dy = (x1 - x2) / 2, (y1 - y2) / 2
	local x1p = cp * dx + sp * dy
	local y1p = -sp * dx + cp * dy
	local lam = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
	if lam > 1 then
		local s = math.sqrt(lam)
		rx *= s
		ry *= s
	end
	local nu = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
	local de = rx * rx * y1p * y1p + ry * ry * x1p * x1p
	local co = math.sqrt(math.max(0, nu / de))
	if fa == fs then co = -co end
	local cxp = co * rx * y1p / ry
	local cyp = -co * ry * x1p / rx
	local cx = cp * cxp - sp * cyp + (x1 + x2) / 2
	local cy = sp * cxp + cp * cyp + (y1 + y2) / 2
	local function ang(ux, uy, vx, vy)
		return math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)
	end
	local th1 = ang(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
	local dth = ang((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
	if fs == 0 and dth > 0 then
		dth -= 2 * math.pi
	elseif fs == 1 and dth < 0 then
		dth += 2 * math.pi
	end
	local segs = math.max(4, math.ceil(math.abs(dth) / (math.pi / 24)))
	for k = 1, segs do
		local t = th1 + dth * k / segs
		local ct, st = math.cos(t), math.sin(t)
		push(cp * rx * ct - sp * ry * st + cx, sp * rx * ct + cp * ry * st + cy)
	end
end

local ARITY = { M = 2, L = 2, H = 1, V = 1, C = 6, S = 4, Q = 4, T = 2, A = 7 }

-- path "d" -> список замкнутых полигонов { {x,y}, ... }
local function flatten(d)
	local tk = tokenize(d)
	local polys, cur = {}, nil
	local x, y, sx, sy = 0, 0, 0, 0
	local lcx, lcy, lqx, lqy = 0, 0, 0, 0
	local prev, cmd, i = "", nil, 1

	local function push(px, py)
		cur[#cur + 1] = { px, py }
		x, y = px, py
	end
	local function ensure()
		if not cur then cur = { { x, y } } end
	end
	local function finish()
		if cur and #cur > 1 then polys[#polys + 1] = cur end
		cur = nil
	end
	local function cubic(x0, y0, x1, y1, x2, y2, x3, y3)
		for k = 1, 20 do
			local t = k / 20
			local u = 1 - t
			push(
				u * u * u * x0 + 3 * u * u * t * x1 + 3 * u * t * t * x2 + t * t * t * x3,
				u * u * u * y0 + 3 * u * u * t * y1 + 3 * u * t * t * y2 + t * t * t * y3
			)
		end
	end
	local function quad(x0, y0, x1, y1, x2, y2)
		for k = 1, 16 do
			local t = k / 16
			local u = 1 - t
			push(u * u * x0 + 2 * u * t * x1 + t * t * x2, u * u * y0 + 2 * u * t * y1 + t * t * y2)
		end
	end

	while i <= #tk do
		local t = tk[i]
		if type(t) == "string" then
			cmd = t
			i += 1
			if cmd == "Z" or cmd == "z" then
				finish()
				x, y = sx, sy
				prev = "Z"
				cmd = nil
			end
		elseif not cmd then
			i += 1
		else
			local C = cmd:upper()
			local rel = cmd ~= C
			if i + ARITY[C] - 1 > #tk then break end
			local ox, oy = 0, 0
			if rel then ox, oy = x, y end

			if C == "M" then
				finish()
				local px, py = tk[i] + ox, tk[i + 1] + oy
				i += 2
				cur = {}
				push(px, py)
				sx, sy = px, py
				cmd = rel and "l" or "L"
				prev = "M"
			elseif C == "L" then
				local px, py = tk[i] + ox, tk[i + 1] + oy
				i += 2
				ensure()
				push(px, py)
				prev = "L"
			elseif C == "H" then
				local px = tk[i] + (rel and x or 0)
				i += 1
				ensure()
				push(px, y)
				prev = "H"
			elseif C == "V" then
				local py = tk[i] + (rel and y or 0)
				i += 1
				ensure()
				push(x, py)
				prev = "V"
			elseif C == "C" then
				local x1, y1, x2, y2, px, py = tk[i] + ox, tk[i + 1] + oy, tk[i + 2] + ox, tk[i + 3] + oy, tk[i + 4] + ox, tk[i + 5] + oy
				i += 6
				ensure()
				cubic(x, y, x1, y1, x2, y2, px, py)
				lcx, lcy = x2, y2
				prev = "C"
			elseif C == "S" then
				local x2, y2, px, py = tk[i] + ox, tk[i + 1] + oy, tk[i + 2] + ox, tk[i + 3] + oy
				i += 4
				local x1, y1 = x, y
				if prev == "C" or prev == "S" then x1, y1 = 2 * x - lcx, 2 * y - lcy end
				ensure()
				cubic(x, y, x1, y1, x2, y2, px, py)
				lcx, lcy = x2, y2
				prev = "S"
			elseif C == "Q" then
				local x1, y1, px, py = tk[i] + ox, tk[i + 1] + oy, tk[i + 2] + ox, tk[i + 3] + oy
				i += 4
				ensure()
				quad(x, y, x1, y1, px, py)
				lqx, lqy = x1, y1
				prev = "Q"
			elseif C == "T" then
				local px, py = tk[i] + ox, tk[i + 1] + oy
				i += 2
				local x1, y1 = x, y
				if prev == "Q" or prev == "T" then x1, y1 = 2 * x - lqx, 2 * y - lqy end
				ensure()
				quad(x, y, x1, y1, px, py)
				lqx, lqy = x1, y1
				prev = "T"
			elseif C == "A" then
				local rx, ry, rot, fa, fs = tk[i], tk[i + 1], tk[i + 2], tk[i + 3], tk[i + 4]
				local px, py = tk[i + 5] + ox, tk[i + 6] + oy
				i += 7
				ensure()
				arcPoints(x, y, rx, ry, rot, fa, fs, px, py, push)
				prev = "A"
			else
				i += 1
			end
		end
	end
	finish()
	return polys
end

local function shapePath(tag, at)
	local f = string.format
	if tag == "path" then
		return at.d
	elseif tag == "circle" then
		local cx, cy, r = num(at.cx, 0), num(at.cy, 0), num(at.r, 0)
		return f("M%f %f A%f %f 0 0 1 %f %f A%f %f 0 0 1 %f %f Z", cx - r, cy, r, r, cx + r, cy, r, r, cx - r, cy)
	elseif tag == "ellipse" then
		local cx, cy, rx, ry = num(at.cx, 0), num(at.cy, 0), num(at.rx, 0), num(at.ry, 0)
		return f("M%f %f A%f %f 0 0 1 %f %f A%f %f 0 0 1 %f %f Z", cx - rx, cy, rx, ry, cx + rx, cy, rx, ry, cx - rx, cy)
	elseif tag == "rect" then
		local x, y, w, h = num(at.x, 0), num(at.y, 0), num(at.width, 0), num(at.height, 0)
		local rx = math.min(num(at.rx, num(at.ry, 0)), w / 2)
		local ry = math.min(num(at.ry, rx), h / 2)
		if rx <= 0 or ry <= 0 then
			return f("M%f %f H%f V%f H%f Z", x, y, x + w, y + h, x)
		end
		return f(
			"M%f %f H%f A%f %f 0 0 1 %f %f V%f A%f %f 0 0 1 %f %f H%f A%f %f 0 0 1 %f %f V%f A%f %f 0 0 1 %f %f Z",
			x + rx, y, x + w - rx,
			rx, ry, x + w, y + ry, y + h - ry,
			rx, ry, x + w - rx, y + h, x + rx,
			rx, ry, x, y + h - ry, y + ry,
			rx, ry, x + rx, y
		)
	elseif tag == "polygon" then
		local pts = {}
		for v in (at.points or ""):gmatch("[-+]?%d*%.?%d+") do pts[#pts + 1] = v end
		local out = {}
		for k = 1, #pts - 1, 2 do
			out[#out + 1] = (k == 1 and "M" or "L") .. pts[k] .. " " .. pts[k + 1]
		end
		return table.concat(out, " ") .. " Z"
	end
	return nil
end

local function crossCompare(a, b) return a[1] < b[1] end

-- svg-строка -> EditableImage (px x px) либо nil
function Svg.render(svg, px, accent, accent2)
	accent2 = accent2 or accent
	local vbx, vby, vbw, vbh = 0, 0, 100, 100
	local vb = svg:match('viewBox%s*=%s*"([^"]+)"')
	if vb then
		local a = {}
		for v in vb:gmatch("[-+]?%d*%.?%d+") do a[#a + 1] = tonumber(v) end
		if #a >= 4 then vbx, vby, vbw, vbh = a[1], a[2], a[3], a[4] end
	else
		local at = parseAttrs(svg:match("<svg([^>]*)>") or "")
		vbw, vbh = num(at.width, 100), num(at.height, 100)
	end
	local scale = math.min(px / vbw, px / vbh)
	local offx = (px - vbw * scale) / 2 - vbx * scale
	local offy = (px - vbh * scale) / 2 - vby * scale

	local N = px * px
	local R, G, B, A = table.create(N, 0), table.create(N, 0), table.create(N, 0), table.create(N, 0)
	local cov = table.create(px + 2, 0)
	local firstColor = nil

	local function rasterize(polys, color, opacity, evenodd)
		local edges = {}
		local ymin, ymax = math.huge, -math.huge
		for _, poly in ipairs(polys) do
			local m = #poly
			for j = 1, m do
				local p, q = poly[j], poly[j % m + 1]
				local x0, y0 = p[1] * scale + offx, p[2] * scale + offy
				local x1, y1 = q[1] * scale + offx, q[2] * scale + offy
				if y0 ~= y1 then
					local dir = 1
					if y0 > y1 then
						x0, y0, x1, y1 = x1, y1, x0, y0
						dir = -1
					end
					edges[#edges + 1] = { x0, y0, (x1 - x0) / (y1 - y0), y1, dir }
					if y0 < ymin then ymin = y0 end
					if y1 > ymax then ymax = y1 end
				end
			end
		end
		if #edges == 0 then return end

		local r, g, b = color.R, color.G, color.B
		local lo, hi = px, -1
		local w = 1 / SS

		local function addSpan(x0, x1)
			if x0 < 0 then x0 = 0 end
			if x1 > px then x1 = px end
			if x1 <= x0 then return end
			local i0, i1 = math.floor(x0), math.floor(x1)
			if i0 < lo then lo = i0 end
			if i0 == i1 then
				cov[i0 + 1] += (x1 - x0) * w
				if i0 > hi then hi = i0 end
			else
				cov[i0 + 1] += (i0 + 1 - x0) * w
				for i = i0 + 1, i1 - 1 do cov[i + 1] += w end
				if i1 < px then cov[i1 + 1] += (x1 - i1) * w end
				local top = (i1 < px) and i1 or (px - 1)
				if top > hi then hi = top end
			end
		end

		local rowStart = math.max(0, math.floor(ymin))
		local rowEnd = math.min(px - 1, math.ceil(ymax))
		for py = rowStart, rowEnd do
			lo, hi = px, -1
			for s = 0, SS - 1 do
				local yy = py + (s + 0.5) / SS
				local xs = {}
				for _, e in ipairs(edges) do
					if yy >= e[2] and yy < e[4] then
						xs[#xs + 1] = { e[1] + (yy - e[2]) * e[3], e[5] }
					end
				end
				if #xs > 1 then
					table.sort(xs, crossCompare)
					local wind, cnt, inside, startX = 0, 0, false, 0
					for _, c in ipairs(xs) do
						wind += c[2]
						cnt += 1
						local now
						if evenodd then now = (cnt % 2 == 1) else now = (wind ~= 0) end
						if now and not inside then
							startX = c[1]
						elseif inside and not now then
							addSpan(startX, c[1])
						end
						inside = now
					end
				end
			end
			if hi >= lo then
				for i = lo, hi do
					local c = cov[i + 1]
					if c > 0 then
						cov[i + 1] = 0
						local sa = math.min(c, 1) * opacity
						local idx = py * px + i + 1
						local da = A[idx]
						local oa = sa + da * (1 - sa)
						if oa > 0 then
							R[idx] = (r * sa + R[idx] * da * (1 - sa)) / oa
							G[idx] = (g * sa + G[idx] * da * (1 - sa)) / oa
							B[idx] = (b * sa + B[idx] * da * (1 - sa)) / oa
							A[idx] = oa
						end
					end
				end
			end
		end
	end

	for tag, attrStr in svg:gmatch("<(%a+)([^>]*)>") do
		if tag == "path" or tag == "circle" or tag == "ellipse" or tag == "rect" or tag == "polygon" then
			local at = parseAttrs(attrStr)
			local color = parseColor(at.fill or "accent", accent, accent2)
			local d = shapePath(tag, at)
			if color and d then
				local ok, polys = pcall(flatten, d)
				if ok then
					firstColor = firstColor or color
					local opacity = num(at["fill-opacity"], 1) * num(at.opacity, 1)
					rasterize(polys, color, opacity, at["fill-rule"] == "evenodd")
				end
			end
		end
	end

	local okI, img = pcall(function()
		return AssetService:CreateEditableImage({ Size = Vector2.new(px, px) })
	end)
	if not okI or not img then return nil end

	local fc = firstColor or Color3.new(1, 1, 1)
	local size = Vector2.new(px, px)
	local okB = pcall(function()
		local buf = buffer.create(N * 4)
		for i = 1, N do
			local o = (i - 1) * 4
			local empty = A[i] <= 0
			buffer.writeu8(buf, o, math.floor((empty and fc.R or R[i]) * 255 + 0.5))
			buffer.writeu8(buf, o + 1, math.floor((empty and fc.G or G[i]) * 255 + 0.5))
			buffer.writeu8(buf, o + 2, math.floor((empty and fc.B or B[i]) * 255 + 0.5))
			buffer.writeu8(buf, o + 3, math.floor(A[i] * 255 + 0.5))
		end
		img:WritePixelsBuffer(Vector2.zero, size, buf)
	end)
	if not okB then
		local okA = pcall(function()
			local arr = table.create(N * 4, 0)
			for i = 1, N do
				local o = (i - 1) * 4
				local empty = A[i] <= 0
				arr[o + 1] = empty and fc.R or R[i]
				arr[o + 2] = empty and fc.G or G[i]
				arr[o + 3] = empty and fc.B or B[i]
				arr[o + 4] = A[i]
			end
			img:WritePixels(Vector2.zero, size, arr)
		end)
		if not okA then
			pcall(function() img:Destroy() end)
			return nil
		end
	end
	return img
end

-- svg -> Content (с кэшем)
function Svg.content(spec, px, accent, accent2)
	accent2 = accent2 or accent
	local key = px .. ":" .. accent:ToHex() .. ":" .. accent2:ToHex() .. ":" .. spec
	local hit = svgCache[key]
	if hit ~= nil then return hit or nil end
	local ok, res = pcall(function()
		local img = Svg.render(spec, px, accent, accent2)
		if not img then return nil end
		svgKeep[#svgKeep + 1] = img
		return Content.fromObject(img)
	end)
	local content = (ok and res) or false
	svgCache[key] = content
	return content or nil
end

-- заливает ImageLabel: svg-разметка, "rbxassetid://..." или число
local function applyImage(label, spec, px, accent, accent2)
	pcall(function() label.Image = "" end)
	if type(spec) == "number" then spec = "rbxassetid://" .. spec end
	if type(spec) ~= "string" or spec == "" then return false end
	if spec:find("<svg", 1, true) then
		local content = Svg.content(spec, px, accent, accent2)
		if not content then return false end
		return (pcall(function() label.ImageContent = content end))
	end
	label.Image = spec
	return true
end

----------------------------------------------------------------------
-- встроенные SVG
----------------------------------------------------------------------
Mochi.DefaultLogo = [[<svg viewBox="0 0 100 100">
<path d="M6 50 A44 44 0 0 1 94 50 A44 44 0 0 1 6 50 Z M20 50 A30 30 0 0 0 80 50 A30 30 0 0 0 20 50 Z" fill="accent" fill-opacity="0.55"/>
<path d="M50 24 C52.5 41 59 47.5 76 50 C59 52.5 52.5 59 50 76 C47.5 59 41 52.5 24 50 C41 47.5 47.5 41 50 24 Z" fill="accent2"/>
</svg>]]

-- иконки белые, окрашиваются через ImageColor3
Mochi.Icons = {
	Home = [[<svg viewBox="0 0 24 24"><path d="M12 3 L2 12 H5 V21 H10 V15 H14 V21 H19 V12 H22 Z" fill="#fff"/></svg>]],
	Star = [[<svg viewBox="0 0 24 24"><path d="M12 2 L14.9 8.6 L22 9.3 L16.6 14 L18.2 21 L12 17.3 L5.8 21 L7.4 14 L2 9.3 L9.1 8.6 Z" fill="#fff"/></svg>]],
	Bolt = [[<svg viewBox="0 0 24 24"><path d="M13 2 L4 14 H11 L10 22 L20 9 H13 Z" fill="#fff"/></svg>]],
	Heart = [[<svg viewBox="0 0 24 24"><path d="M12 21 C12 21 3 14.5 3 8.5 C3 5.5 5.3 3.5 7.8 3.5 C9.6 3.5 11.2 4.5 12 6 C12.8 4.5 14.4 3.5 16.2 3.5 C18.7 3.5 21 5.5 21 8.5 C21 14.5 12 21 12 21 Z" fill="#fff"/></svg>]],
	User = [[<svg viewBox="0 0 24 24"><path d="M8 8 A4 4 0 0 1 16 8 A4 4 0 0 1 8 8 Z" fill="#fff"/><path d="M4 21 C4 16 8 14 12 14 C16 14 20 16 20 21 Z" fill="#fff"/></svg>]],
	Chevron = [[<svg viewBox="0 0 24 24"><path d="M6 9 L12 15 L18 9 L16.6 7.6 L12 12.2 L7.4 7.6 Z" fill="#fff"/></svg>]],
}

Mochi.Icons.Check = [[<svg viewBox="0 0 24 24"><path d="M4.5 12.6 L6.3 10.8 L10 14.5 L17.7 6.8 L19.5 8.6 L10 18 Z" fill="#fff"/></svg>]]

Mochi.Icons.Close = [[<svg viewBox="0 0 24 24"><path d="M5.6 4.2 L12 10.6 L18.4 4.2 L19.8 5.6 L13.4 12 L19.8 18.4 L18.4 19.8 L12 13.4 L5.6 19.8 L4.2 18.4 L10.6 12 L4.2 5.6 Z" fill="#fff"/></svg>]]

do -- шестерёнка строится математикой
	local pts, n = {}, 8
	local step = 2 * math.pi / n
	local function P(r, a) return string.format("%f %f", 12 + r * math.cos(a), 12 + r * math.sin(a)) end
	for i = 0, n - 1 do
		local c = i * step
		pts[#pts + 1] = (#pts == 0 and "M" or "L") .. P(7.6, c - 0.36 * step)
		pts[#pts + 1] = "L" .. P(10.6, c - 0.2 * step)
		pts[#pts + 1] = "L" .. P(10.6, c + 0.2 * step)
		pts[#pts + 1] = "L" .. P(7.6, c + 0.36 * step)
	end
	local hole = "M8.6 12 A3.4 3.4 0 0 0 15.4 12 A3.4 3.4 0 0 0 8.6 12 Z"
	Mochi.Icons.Gear = '<svg viewBox="0 0 24 24"><path d="' .. table.concat(pts, " ") .. " Z " .. hole .. '" fill="#fff"/></svg>'
end

----------------------------------------------------------------------
-- утилиты UI
----------------------------------------------------------------------
local KEYBOARD = UserInputService.KeyboardEnabled

local function make(class, props, kids)
	local o = Instance.new(class)
	if o:IsA("GuiObject") then
		o.BorderSizePixel = 0
		if o:IsA("GuiButton") then o.AutoButtonColor = false end
		if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
			o.BackgroundTransparency = 1
			o.Font = FONT
			o.TextSize = 13
		elseif o:IsA("ImageLabel") or o:IsA("ImageButton") or o:IsA("ScrollingFrame") or o:IsA("CanvasGroup") then
			o.BackgroundTransparency = 1
		end
	end
	local parent
	for k, v in pairs(props) do
		if k == "Parent" then parent = v else o[k] = v end
	end
	if kids then
		for _, k in ipairs(kids) do k.Parent = o end
	end
	o.Parent = parent
	return o
end

local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local CTX = nil -- окно, в котором сейчас строится интерфейс

-- базовые радиусы деталей (умножаются на Style.Round, переопределяются через Style.Radius)
local BASE_RADIUS = {
	window = 12, card = 8, button = 8, option = 6, input = 6, chip = 10, avatar = 15,
	toggle = 10, knob = 7, track = 3, thumb = 6, fab = 23, strip = 2, key = 6, underline = 1,
	arrow = 12, close = 8, check = 4,
}
Mochi.RadiusKinds = BASE_RADIUS

local function corner(o, kind)
	local win = CTX
	local r = win and win:_radius(kind) or BASE_RADIUS[kind] or 8
	local ui = make("UICorner", { CornerRadius = UDim.new(0, r), Parent = o })
	if win then table.insert(win._corners, { ui, kind }) end
	return ui
end

local function stroke(o, color, thick, trans)
	return make("UIStroke", {
		Color = color, Thickness = thick or 1, Transparency = trans or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = o,
	})
end

local function pad(o, l, t, r, b)
	return make("UIPadding", {
		PaddingLeft = UDim.new(0, l or 0), PaddingTop = UDim.new(0, t or 0),
		PaddingRight = UDim.new(0, r or 0), PaddingBottom = UDim.new(0, b or 0), Parent = o,
	})
end

local function vlist(o, gap)
	return make("UIListLayout", { Padding = UDim.new(0, gap or 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = o })
end

local ICON_WHITE = Color3.new(1, 1, 1)
local function icon(parent, svg, size)
	local img = make("ImageLabel", { Size = UDim2.fromOffset(size, size), Parent = parent })
	applyImage(img, svg, 64, ICON_WHITE)
	return img
end

local function cleanName(n)
	n = tostring(n or "")
	n = n:gsub('[/\\:%*%?"<>|%c]', "")
	n = n:gsub("^%s+", "")
	n = n:gsub("%s+$", "")
	return n
end

----------------------------------------------------------------------
-- Картинки из кода: base64 (PNG / GIF), SVG, rbxassetid — для логотипа, маскота и панелей
----------------------------------------------------------------------
local function genv(name)
	local ok, v = pcall(function() return getfenv()[name] end)
	if ok then return v end
	return nil
end

local ImageDecode = {}

-- отдаём кадр движку, чтобы большие картинки не вешали игру
local lastYield = os.clock()
local function pace()
	if os.clock() - lastYield > 0.012 then
		task.wait()
		lastYield = os.clock()
	end
end

local B64 = {}
do
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for i = 1, 64 do B64[string.byte(chars, i)] = i - 1 end
	B64[45] = 62 -- '-'
	B64[95] = 63 -- '_'
end

-- base64 (можно с префиксом data:image/...;base64, с переносами строк, url-safe) -> buffer, длина
function ImageDecode.fromBase64(str)
	str = (str:gsub("^%s*data:[^,]*,", ""))
	local n = #str
	local out = buffer.create(math.floor(n * 3 / 4) + 3)
	local o, acc, nb = 0, 0, 0
	for i = 1, n do
		local v = B64[string.byte(str, i)]
		if v then
			acc = bit32.bor(bit32.lshift(acc, 6), v)
			nb += 6
			if nb >= 8 then
				nb -= 8
				buffer.writeu8(out, o, bit32.band(bit32.rshift(acc, nb), 255))
				o += 1
				acc = bit32.band(acc, bit32.lshift(1, nb) - 1)
			end
		end
		if i % 200000 == 0 then pace() end
	end
	return out, o
end

----------------------------------------------------------------------
-- inflate (порт puff.c)
----------------------------------------------------------------------
local LENS = { 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258 }
local LEXT = { 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0 }
local DISTS = { 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577 }
local DEXT = { 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13 }
local ORDER = { 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 }

local function inflate(src, srcPos, srcLen, dst, dstLen)
	local rb, wb = buffer.readu8, buffer.writeu8
	local band, bor, lshift, rshift = bit32.band, bit32.bor, bit32.lshift, bit32.rshift
	local pos = srcPos
	local bitbuf, bitcnt, outPos, steps = 0, 0, 0, 0

	local function bits(need)
		local val = bitbuf
		while bitcnt < need do
			if pos >= srcLen then error("inflate: конец данных") end
			val = bor(val, lshift(rb(src, pos), bitcnt))
			pos += 1
			bitcnt += 8
		end
		bitbuf = rshift(val, need)
		bitcnt -= need
		return band(val, lshift(1, need) - 1)
	end

	-- lengths: 1-based, символ i -> lengths[start + i + 1]
	local function construct(lengths, start, n)
		local count = table.create(16, 0) -- count[len + 1]
		for s = 1, n do
			local l = lengths[start + s]
			count[l + 1] += 1
		end
		if count[1] == n then return { count = count, symbol = {} }, 0 end
		local left = 1
		for ln = 1, 15 do
			left = left * 2 - count[ln + 1]
			if left < 0 then return nil, left end
		end
		local offs = table.create(16, 0) -- offs[len + 1]
		offs[2] = 0
		for ln = 1, 14 do
			offs[ln + 2] = offs[ln + 1] + count[ln + 1]
		end
		local symbol = {}
		for s = 1, n do
			local l = lengths[start + s]
			if l ~= 0 then
				symbol[offs[l + 1] + 1] = s - 1
				offs[l + 1] += 1
			end
		end
		return { count = count, symbol = symbol }, left
	end

	local function decode(h)
		local code, first, index = 0, 0, 0
		local count, symbol = h.count, h.symbol
		local bb, bc = bitbuf, bitcnt
		for ln = 1, 15 do
			if bc == 0 then
				if pos >= srcLen then error("inflate: конец данных") end
				bb = rb(src, pos)
				pos += 1
				bc = 8
			end
			code = bor(code, band(bb, 1))
			bb = rshift(bb, 1)
			bc -= 1
			local c = count[ln + 1]
			if code - c < first then
				bitbuf, bitcnt = bb, bc
				return symbol[index + (code - first) + 1]
			end
			index += c
			first += c
			first = first * 2
			code = code * 2
		end
		error("inflate: неверный код")
	end

	local function codes(lencode, distcode)
		while true do
			local sym = decode(lencode)
			if sym < 256 then
				wb(dst, outPos, sym)
				outPos += 1
			elseif sym == 256 then
				return
			else
				sym -= 257
				if sym >= 29 then error("inflate: плохой символ длины") end
				local len = LENS[sym + 1] + bits(LEXT[sym + 1])
				local ds = decode(distcode)
				if ds >= 30 then error("inflate: плохой символ дистанции") end
				local dist = DISTS[ds + 1] + bits(DEXT[ds + 1])
				if dist > outPos then error("inflate: дистанция слишком большая") end
				for _ = 1, len do
					wb(dst, outPos, rb(dst, outPos - dist))
					outPos += 1
				end
			end
			steps += 1
			if steps >= 30000 then
				steps = 0
				pace()
			end
		end
	end

	local fl = table.create(320, 0)
	for i = 1, 144 do fl[i] = 8 end
	for i = 145, 256 do fl[i] = 9 end
	for i = 257, 280 do fl[i] = 7 end
	for i = 281, 288 do fl[i] = 8 end
	local fixedLen = construct(fl, 0, 288)
	local fd = table.create(40, 0)
	for i = 1, 30 do fd[i] = 5 end
	local fixedDist = construct(fd, 0, 30)

	local function dynamic()
		local nlen = bits(5) + 257
		local ndist = bits(5) + 1
		local ncode = bits(4) + 4
		if nlen > 286 or ndist > 30 then error("inflate: плохие счётчики") end
		local lengths = table.create(330, 0)
		for i = 1, ncode do
			lengths[ORDER[i] + 1] = bits(3)
		end
		local lencode, err = construct(lengths, 0, 19)
		if err ~= 0 then error("inflate: плохие длины кодов") end
		local idx = 0
		while idx < nlen + ndist do
			local sym = decode(lencode)
			if sym < 16 then
				lengths[idx + 1] = sym
				idx += 1
			else
				local ln, rep = 0, 0
				if sym == 16 then
					if idx == 0 then error("inflate: нет предыдущей длины") end
					ln = lengths[idx]
					rep = 3 + bits(2)
				elseif sym == 17 then
					rep = 3 + bits(3)
				else
					rep = 11 + bits(7)
				end
				if idx + rep > nlen + ndist then error("inflate: слишком много длин") end
				for _ = 1, rep do
					lengths[idx + 1] = ln
					idx += 1
				end
			end
		end
		if lengths[257] == 0 then error("inflate: нет кода конца блока") end
		local lc, err1 = construct(lengths, 0, nlen)
		if err1 ~= 0 and (err1 < 0 or nlen ~= lc.count[1] + lc.count[2]) then error("inflate: плохие длины литералов") end
		local dc, err2 = construct(lengths, nlen, ndist)
		if err2 ~= 0 and (err2 < 0 or ndist ~= dc.count[1] + dc.count[2]) then error("inflate: плохие длины дистанций") end
		codes(lc, dc)
	end

	while true do
		local last = bits(1)
		local t = bits(2)
		if t == 0 then
			bitbuf, bitcnt = 0, 0
			if pos + 4 > srcLen then error("inflate: обрыв") end
			local ln = rb(src, pos) + rb(src, pos + 1) * 256
			local nl = rb(src, pos + 2) + rb(src, pos + 3) * 256
			if ln ~= band(bit32.bnot(nl), 0xFFFF) then error("inflate: плохая длина блока") end
			pos += 4
			if pos + ln > srcLen then error("inflate: обрыв") end
			buffer.copy(dst, outPos, src, pos, ln)
			pos += ln
			outPos += ln
		elseif t == 1 then
			codes(fixedLen, fixedDist)
		elseif t == 2 then
			dynamic()
		else
			error("inflate: плохой тип блока")
		end
		if last == 1 then break end
	end
	return outPos
end

----------------------------------------------------------------------
-- уменьшение картинки (усреднение по блокам, с учётом прозрачности)
----------------------------------------------------------------------
local function resizeRGBA(src, w, h, nw, nh)
	local rb, wb = buffer.readu8, buffer.writeu8
	local floor = math.floor
	local dst = buffer.create(nw * nh * 4)
	local sx, sy = w / nw, h / nh
	for y = 0, nh - 1 do
		local y0 = floor(y * sy)
		local y1 = math.max(y0 + 1, floor((y + 1) * sy))
		for x = 0, nw - 1 do
			local x0 = floor(x * sx)
			local x1 = math.max(x0 + 1, floor((x + 1) * sx))
			local r, g, b, a, rs, gs, bs, n = 0, 0, 0, 0, 0, 0, 0, 0
			for yy = y0, y1 - 1 do
				local row = yy * w
				for xx = x0, x1 - 1 do
					local o = (row + xx) * 4
					local pa = rb(src, o + 3)
					local pr, pg, pb = rb(src, o), rb(src, o + 1), rb(src, o + 2)
					r += pr * pa
					g += pg * pa
					b += pb * pa
					a += pa
					rs += pr
					gs += pg
					bs += pb
					n += 1
				end
			end
			local o = (y * nw + x) * 4
			if a > 0 then
				wb(dst, o, floor(r / a + 0.5))
				wb(dst, o + 1, floor(g / a + 0.5))
				wb(dst, o + 2, floor(b / a + 0.5))
				wb(dst, o + 3, floor(a / n + 0.5))
			else
				wb(dst, o, floor(rs / n + 0.5))
				wb(dst, o + 1, floor(gs / n + 0.5))
				wb(dst, o + 2, floor(bs / n + 0.5))
				wb(dst, o + 3, 0)
			end
		end
		if y % 16 == 0 then pace() end
	end
	return dst
end

local function fitSize(w, h, maxDim)
	local m = math.max(w, h)
	if m <= maxDim then return w, h end
	local k = maxDim / m
	return math.max(1, math.floor(w * k + 0.5)), math.max(1, math.floor(h * k + 0.5))
end

----------------------------------------------------------------------
-- PNG (без чересстрочной развёртки)
----------------------------------------------------------------------
local function u32be(b, p)
	local rb = buffer.readu8
	return bit32.bor(bit32.lshift(rb(b, p), 24), bit32.lshift(rb(b, p + 1), 16), bit32.lshift(rb(b, p + 2), 8), rb(b, p + 3))
end

local function decodePNG(buf, len)
	local rb, wb = buffer.readu8, buffer.writeu8
	local band, rshift = bit32.band, bit32.rshift
	local sig = { 137, 80, 78, 71, 13, 10, 26, 10 }
	for i = 1, 8 do
		if rb(buf, i - 1) ~= sig[i] then error("это не PNG") end
	end
	local pos = 8
	local width, height, depth, ctype, interlace
	local plteP, plteL, trnsP, trnsL
	local parts, total = {}, 0
	while pos + 8 <= len do
		local clen = u32be(buf, pos)
		local name = buffer.readstring(buf, pos + 4, 4)
		local dpos = pos + 8
		if name == "IHDR" then
			width, height = u32be(buf, dpos), u32be(buf, dpos + 4)
			depth, ctype, interlace = rb(buf, dpos + 8), rb(buf, dpos + 9), rb(buf, dpos + 12)
		elseif name == "PLTE" then
			plteP, plteL = dpos, clen
		elseif name == "tRNS" then
			trnsP, trnsL = dpos, clen
		elseif name == "IDAT" then
			table.insert(parts, { dpos, clen })
			total += clen
		elseif name == "IEND" then
			break
		end
		pos = dpos + clen + 4
	end
	if not width then error("PNG: нет заголовка") end
	if interlace ~= 0 then error("PNG с чересстрочной развёрткой не поддерживается: пересохрани без interlace") end
	local channels = ({ [0] = 1, [2] = 3, [3] = 1, [4] = 2, [6] = 4 })[ctype]
	if not channels then error("PNG: неизвестный тип цвета") end
	local bitsPP = channels * depth
	local bpp = math.max(1, bitsPP // 8)
	local stride = (width * bitsPP + 7) // 8
	local rawLen = height * (stride + 1)

	local z = buffer.create(total)
	local o = 0
	for _, p in ipairs(parts) do
		buffer.copy(z, o, buf, p[1], p[2])
		o += p[2]
	end
	local raw = buffer.create(rawLen)
	inflate(z, 2, total, raw, rawLen)

	-- убираем PNG-фильтры
	for y = 0, height - 1 do
		local rs = y * (stride + 1)
		local ft = rb(raw, rs)
		local cur = rs + 1
		local prev = (y > 0) and (cur - (stride + 1)) or nil
		if ft == 1 then
			for i = bpp, stride - 1 do
				wb(raw, cur + i, band(rb(raw, cur + i) + rb(raw, cur + i - bpp), 255))
			end
		elseif ft == 2 then
			if prev then
				for i = 0, stride - 1 do
					wb(raw, cur + i, band(rb(raw, cur + i) + rb(raw, prev + i), 255))
				end
			end
		elseif ft == 3 then
			for i = 0, stride - 1 do
				local a = (i >= bpp) and rb(raw, cur + i - bpp) or 0
				local b = prev and rb(raw, prev + i) or 0
				wb(raw, cur + i, band(rb(raw, cur + i) + (a + b) // 2, 255))
			end
		elseif ft == 4 then
			for i = 0, stride - 1 do
				local a = (i >= bpp) and rb(raw, cur + i - bpp) or 0
				local b = prev and rb(raw, prev + i) or 0
				local c = (prev and i >= bpp) and rb(raw, prev + i - bpp) or 0
				local p = a + b - c
				local pa, pb, pc = math.abs(p - a), math.abs(p - b), math.abs(p - c)
				local pr
				if pa <= pb and pa <= pc then
					pr = a
				elseif pb <= pc then
					pr = b
				else
					pr = c
				end
				wb(raw, cur + i, band(rb(raw, cur + i) + pr, 255))
			end
		elseif ft ~= 0 then
			error("PNG: неизвестный фильтр")
		end
		if y % 64 == 0 then pace() end
	end

	-- в RGBA
	local out = buffer.create(width * height * 4)
	local palR, palG, palB, palA
	if ctype == 3 then
		if not plteP then error("PNG: нет палитры") end
		palR, palG, palB, palA = table.create(256, 0), table.create(256, 0), table.create(256, 0), table.create(256, 255)
		for i = 0, plteL // 3 - 1 do
			palR[i + 1] = rb(buf, plteP + i * 3)
			palG[i + 1] = rb(buf, plteP + i * 3 + 1)
			palB[i + 1] = rb(buf, plteP + i * 3 + 2)
		end
		if trnsP then
			for i = 0, math.min(trnsL, 256) - 1 do
				palA[i + 1] = rb(buf, trnsP + i)
			end
		end
	end
	local mask = bit32.lshift(1, depth) - 1
	local step16 = depth == 16
	for y = 0, height - 1 do
		local cur = y * (stride + 1) + 1
		for x = 0, width - 1 do
			local q = (y * width + x) * 4
			if ctype == 6 then
				if not step16 then
					local p = cur + x * 4
					wb(out, q, rb(raw, p)); wb(out, q + 1, rb(raw, p + 1)); wb(out, q + 2, rb(raw, p + 2)); wb(out, q + 3, rb(raw, p + 3))
				else
					local p = cur + x * 8
					wb(out, q, rb(raw, p)); wb(out, q + 1, rb(raw, p + 2)); wb(out, q + 2, rb(raw, p + 4)); wb(out, q + 3, rb(raw, p + 6))
				end
			elseif ctype == 2 then
				if not step16 then
					local p = cur + x * 3
					wb(out, q, rb(raw, p)); wb(out, q + 1, rb(raw, p + 1)); wb(out, q + 2, rb(raw, p + 2))
				else
					local p = cur + x * 6
					wb(out, q, rb(raw, p)); wb(out, q + 1, rb(raw, p + 2)); wb(out, q + 2, rb(raw, p + 4))
				end
				wb(out, q + 3, 255)
			elseif ctype == 4 then
				local g, a
				if not step16 then
					local p = cur + x * 2
					g, a = rb(raw, p), rb(raw, p + 1)
				else
					local p = cur + x * 4
					g, a = rb(raw, p), rb(raw, p + 2)
				end
				wb(out, q, g); wb(out, q + 1, g); wb(out, q + 2, g); wb(out, q + 3, a)
			elseif ctype == 0 and depth >= 8 then
				local g = rb(raw, cur + x * (depth // 8))
				wb(out, q, g); wb(out, q + 1, g); wb(out, q + 2, g); wb(out, q + 3, 255)
			else
				-- палитра любой глубины, либо серый 1/2/4 бита
				local bitpos = x * depth
				local byte = rb(raw, cur + rshift(bitpos, 3))
				local shift = 8 - depth - band(bitpos, 7)
				local idx = band(rshift(byte, shift), mask)
				if ctype == 3 then
					wb(out, q, palR[idx + 1]); wb(out, q + 1, palG[idx + 1]); wb(out, q + 2, palB[idx + 1]); wb(out, q + 3, palA[idx + 1])
				else
					local g = idx * 255 // mask
					wb(out, q, g); wb(out, q + 1, g); wb(out, q + 2, g); wb(out, q + 3, 255)
				end
			end
		end
		if y % 32 == 0 then pace() end
	end
	return width, height, out
end

----------------------------------------------------------------------
-- GIF (кадры, прозрачность, disposal, чересстрочность)
----------------------------------------------------------------------
local function u16le(b, p)
	return buffer.readu8(b, p) + buffer.readu8(b, p + 1) * 256
end

-- возвращает W, H, { { Data = buffer RGBA (W*H*4), Delay = секунды }, ... }
local function decodeGIF(buf, len, maxFrames, maxDim)
	local rb, wb = buffer.readu8, buffer.writeu8
	if buffer.readstring(buf, 0, 3) ~= "GIF" then error("это не GIF") end
	local W, H = u16le(buf, 6), u16le(buf, 8)
	local flags = rb(buf, 10)
	local pos = 13
	local gct, gctN = nil, 0
	if bit32.band(flags, 0x80) ~= 0 then
		gctN = bit32.lshift(1, bit32.band(flags, 7) + 1)
		gct = pos
		pos += gctN * 3
	end
	local nw, nh = fitSize(W, H, maxDim)
	local canvas = buffer.create(W * H * 4)
	local frames = {}
	local gce = { disposal = 0, transparent = nil, delay = 10 }
	local prevDisposal, prevRect, prevSnap = 0, nil, nil

	local function skipSub(p)
		while true do
			local sz = rb(buf, p)
			p += 1 + sz
			if sz == 0 then return p end
		end
	end

	while pos < len do
		local b = rb(buf, pos)
		pos += 1
		if b == 0x21 then
			local label = rb(buf, pos)
			pos += 1
			if label == 0xF9 then
				local bs = rb(buf, pos)
				if bs >= 4 then
					local pf = rb(buf, pos + 1)
					gce = {
						disposal = bit32.band(bit32.rshift(pf, 2), 7),
						transparent = (bit32.band(pf, 1) == 1) and rb(buf, pos + 4) or nil,
						delay = u16le(buf, pos + 2),
					}
				end
			end
			pos = skipSub(pos)
		elseif b == 0x2C then
			local left, top = u16le(buf, pos), u16le(buf, pos + 2)
			local fw, fh = u16le(buf, pos + 4), u16le(buf, pos + 6)
			local pf = rb(buf, pos + 8)
			pos += 9
			local ct, ctN = gct, gctN
			if bit32.band(pf, 0x80) ~= 0 then
				ctN = bit32.lshift(1, bit32.band(pf, 7) + 1)
				ct = pos
				pos += ctN * 3
			end
			if not ct then error("GIF: нет палитры") end
			local interlaced = bit32.band(pf, 0x40) ~= 0
			local minCode = rb(buf, pos)
			pos += 1

			-- собрать данные LZW из под-блоков
			local dl, scan = 0, pos
			while true do
				local sz = rb(buf, scan)
				scan += 1
				if sz == 0 then break end
				dl += sz
				scan += sz
			end
			local data = buffer.create(math.max(dl, 1))
			local dp0 = 0
			while true do
				local sz = rb(buf, pos)
				pos += 1
				if sz == 0 then break end
				buffer.copy(data, dp0, buf, pos, sz)
				dp0 += sz
				pos += sz
			end

			-- LZW
			local total = fw * fh
			local idx = buffer.create(math.max(total, 1))
			local clear = bit32.lshift(1, minCode)
			local eoi = clear + 1
			local codeSize = minCode + 1
			local nxt = eoi + 1
			local prefix, suffix = table.create(4096, 0), table.create(4096, 0)
			local stack = table.create(4100, 0)
			local prev = -1
			local outp = 0
			local bitbuf, bitcnt, dp = 0, 0, 0
			local done = false
			while not done do
				while bitcnt < codeSize do
					if dp >= dl then
						done = true
						break
					end
					bitbuf = bit32.bor(bitbuf, bit32.lshift(rb(data, dp), bitcnt))
					dp += 1
					bitcnt += 8
				end
				if done then break end
				local code = bit32.band(bitbuf, bit32.lshift(1, codeSize) - 1)
				bitbuf = bit32.rshift(bitbuf, codeSize)
				bitcnt -= codeSize
				if code == clear then
					codeSize = minCode + 1
					nxt = eoi + 1
					prev = -1
				elseif code == eoi then
					break
				elseif prev == -1 then
					if outp < total then
						wb(idx, outp, code)
						outp += 1
					end
					prev = code
				else
					if code >= nxt then
						if code > nxt then error("GIF: битый LZW код") end
						local c = prev
						while c >= clear do c = prefix[c + 1] end
						local f = c
						if nxt < 4096 then
							prefix[nxt + 1] = prev
							suffix[nxt + 1] = f
							nxt += 1
							if nxt == bit32.lshift(1, codeSize) and codeSize < 12 then codeSize += 1 end
						end
						local sp = 0
						c = code
						while c >= clear do
							sp += 1
							stack[sp] = suffix[c + 1]
							c = prefix[c + 1]
						end
						sp += 1
						stack[sp] = c
						for i = sp, 1, -1 do
							if outp < total then
								wb(idx, outp, stack[i])
								outp += 1
							end
						end
					else
						local sp = 0
						local c = code
						while c >= clear do
							sp += 1
							stack[sp] = suffix[c + 1]
							c = prefix[c + 1]
						end
						sp += 1
						stack[sp] = c
						local f = c
						for i = sp, 1, -1 do
							if outp < total then
								wb(idx, outp, stack[i])
								outp += 1
							end
						end
						if nxt < 4096 then
							prefix[nxt + 1] = prev
							suffix[nxt + 1] = f
							nxt += 1
							if nxt == bit32.lshift(1, codeSize) and codeSize < 12 then codeSize += 1 end
						end
					end
					prev = code
				end
				if outp % 4096 == 0 then pace() end
			end

			-- disposal предыдущего кадра
			if prevDisposal == 2 and prevRect then
				local pl, pt, pw, ph = prevRect[1], prevRect[2], prevRect[3], prevRect[4]
				for yy = pt, math.min(pt + ph, H) - 1 do
					local xe = math.min(pl + pw, W)
					if xe > pl then buffer.fill(canvas, (yy * W + pl) * 4, 0, (xe - pl) * 4) end
				end
			elseif prevDisposal == 3 and prevSnap then
				buffer.copy(canvas, 0, prevSnap, 0, W * H * 4)
			end
			local snap = nil
			if gce.disposal == 3 then
				snap = buffer.create(W * H * 4)
				buffer.copy(snap, 0, canvas, 0, W * H * 4)
			end

			-- порядок строк
			local rowmap = nil
			if interlaced then
				rowmap = {}
				local passes = { { 0, 8 }, { 4, 8 }, { 2, 4 }, { 1, 2 } }
				for _, ps in ipairs(passes) do
					local r = ps[1]
					while r < fh do
						rowmap[#rowmap + 1] = r
						r += ps[2]
					end
				end
			end
			local tr = gce.transparent
			for sy = 0, fh - 1 do
				local dy = top + (rowmap and rowmap[sy + 1] or sy)
				if dy < H then
					for sx = 0, fw - 1 do
						local dx = left + sx
						if dx < W then
							local ci = rb(idx, sy * fw + sx)
							if not (tr and ci == tr) then
								local o = (dy * W + dx) * 4
								local p = ct + ci * 3
								wb(canvas, o, rb(buf, p)); wb(canvas, o + 1, rb(buf, p + 1)); wb(canvas, o + 2, rb(buf, p + 2)); wb(canvas, o + 3, 255)
							end
						end
					end
				end
			end
			local delay = gce.delay
			if delay < 2 then delay = 10 end
			local frameData
			if nw ~= W or nh ~= H then
				frameData = resizeRGBA(canvas, W, H, nw, nh)
			else
				frameData = buffer.create(W * H * 4)
				buffer.copy(frameData, 0, canvas, 0, W * H * 4)
			end
			frames[#frames + 1] = { Data = frameData, Delay = delay / 100 }
			prevDisposal, prevRect, prevSnap = gce.disposal, { left, top, fw, fh }, snap
			gce = { disposal = 0, transparent = nil, delay = 10 }
			pace()
			if #frames >= maxFrames then break end
		elseif b == 0x3B then
			break
		else
			break
		end
	end
	if #frames == 0 then error("GIF: нет кадров") end
	return nw, nh, frames
end

-- base64-строка -> { Width, Height, Frames = { { Data = buffer RGBA, Delay = сек } } }
local function decodeImage(b64, maxDim)
	local buf, len = ImageDecode.fromBase64(b64)
	if len < 8 then error("пустая картинка") end
	local b0, b1, b2 = buffer.readu8(buf, 0), buffer.readu8(buf, 1), buffer.readu8(buf, 2)
	if b0 == 137 and b1 == 80 then
		local w, h, rgba = decodePNG(buf, len)
		local nw, nh = fitSize(w, h, maxDim)
		if nw ~= w or nh ~= h then rgba = resizeRGBA(rgba, w, h, nw, nh) end
		return { Width = nw, Height = nh, Frames = { { Data = rgba, Delay = 1 } } }
	elseif b0 == 71 and b1 == 73 and b2 == 70 then
		local nw, nh, frames = decodeGIF(buf, len, 200, maxDim)
		return { Width = nw, Height = nh, Frames = frames }
	elseif b0 == 0xFF and b1 == 0xD8 then
		error("JPEG в чистом Luau не разбирается: используй PNG или GIF (или SVG / rbxassetid)")
	end
	error("неизвестный формат картинки (нужен PNG или GIF в base64)")
end
ImageDecode.decode = decodeImage

local decodeCache = {}
local function decodeShared(val, maxDim)
	local key = string.format("%d:%d:%s:%s", maxDim, #val, val:sub(1, 48), val:sub(-48))
	local ent = decodeCache[key]
	if ent then
		while not ent.result and not ent.err do task.wait() end
		if ent.err then error(ent.err) end
		return ent.result
	end
	ent = {}
	decodeCache[key] = ent
	local ok, res = pcall(decodeImage, val, maxDim)
	if ok then
		ent.result = res
		return res
	end
	ent.err = tostring(res)
	error(ent.err)
end

-- запись пикселей в EditableImage (новый API с buffer, иначе старый с массивом)
local function writeFrame(img, w, h, data)
	local size = Vector2.new(w, h)
	local ok = pcall(function() img:WritePixelsBuffer(Vector2.zero, size, data) end)
	if not ok then
		local n = w * h * 4
		local arr = table.create(n, 0)
		for i = 0, n - 1 do arr[i + 1] = buffer.readu8(data, i) / 255 end
		img:WritePixels(Vector2.zero, size, arr)
	end
end

-- запасной путь для JPEG и прочего: если в среде есть writefile + getcustomasset
local function tryFileAsset(label, b64)
	local wf, gca = genv("writefile"), genv("getcustomasset")
	if type(wf) ~= "function" or type(gca) ~= "function" then return false end
	local ok = pcall(function()
		local buf, n = ImageDecode.fromBase64(b64)
		local str = buffer.readstring(buf, 0, n)
		local ext = (buffer.readu8(buf, 0) == 0xFF) and "jpg" or "png"
		local sum = 0
		for i = 0, math.min(n, 256) - 1 do sum = (sum * 31 + buffer.readu8(buf, i)) % 1000003 end
		local path = string.format("mochi_%d_%d.%s", n, sum, ext)
		wf(path, str)
		label.Image = gca(path)
	end)
	return ok
end

local function classifyImage(spec)
	if type(spec) == "number" then return "asset", "rbxassetid://" .. spec end
	if type(spec) == "table" then
		if spec.Base64 then
			local b = spec.Base64
			if type(b) == "table" then b = table.concat(b) end
			return "b64", b
		end
		if spec.Svg then return "svg", spec.Svg end
		if spec.Image ~= nil then return classifyImage(spec.Image) end
		return nil
	end
	if type(spec) == "string" then
		local t = spec:match("^%s*(.-)%s*$")
		if t == "" then return nil end
		if t:find("<svg", 1, true) then return "svg", t end
		if t:find("^data:image") then return "b64", t end
		if t:find("^rbxassetid://") or t:find("^rbxasset://") or t:find("^rbxthumb://") or t:find("^https?://") then
			return "asset", t
		end
		if t:find("^%d+$") then return "asset", "rbxassetid://" .. t end -- голое число из TextBox и т.п.
		if #t > 64 and t:find("^[%w%+/=_%-%s]+$") then return "b64", t end
		return "asset", t
	end
	return nil
end

-- Универсальная загрузка картинки в ImageLabel:
--   "<svg ...>" | "rbxassetid://123" | 123 | "data:image/png;base64,..." | "iVBORw0..." (PNG / GIF в base64)
--   { Base64 = "..." } | { Base64 = { "часть1", "часть2" } } | { Svg = "..." }
-- opts: maxDim (по умолчанию 384), px (разрешение SVG), accent, accent2, onReady(), onFail(текст)
function Mochi.LoadImage(label, spec, opts)
	opts = opts or {}
	local handle = { Cancelled = false }
	function handle.Cancel() handle.Cancelled = true end
	local function finish(ok, why)
		if handle.Cancelled then return end
		if ok then
			if opts.onReady then opts.onReady() end
		elseif opts.onFail then
			opts.onFail(why)
		end
	end
	local kind, val = classifyImage(spec)
	if kind == "svg" then
		finish(applyImage(label, val, opts.px or 256, opts.accent or ICON_WHITE, opts.accent2 or opts.accent))
	elseif kind == "asset" then
		pcall(function() label.Image = val end)
		finish(true)
	elseif kind == "b64" then
		task.spawn(function()
			local ok, res = pcall(decodeShared, val, opts.maxDim or 384)
			if handle.Cancelled or not label.Parent then return end
			if not ok then
				if tryFileAsset(label, val) then
					finish(true)
				else
					warn("[Mochi] картинка не загружена: " .. tostring(res))
					finish(false, res)
				end
				return
			end
			local okShow, err = pcall(function()
				local img = AssetService:CreateEditableImage({ Size = Vector2.new(res.Width, res.Height) })
				writeFrame(img, res.Width, res.Height, res.Frames[1].Data)
				local shown = pcall(function() label.ImageContent = Content.fromObject(img) end)
				if not shown then img.Parent = label end
				if #res.Frames > 1 then
					task.spawn(function()
						local i = 1
						while not handle.Cancelled and label.Parent do
							local f = res.Frames[i]
							writeFrame(img, res.Width, res.Height, f.Data)
							task.wait(f.Delay)
							i = i % #res.Frames + 1
						end
					end)
				end
			end)
			if not okShow then warn("[Mochi] не удалось показать картинку: " .. tostring(err)) end
			finish(okShow, err)
		end)
	else
		finish(false, "неизвестный формат картинки")
	end
	return handle
end
Mochi.ImageDecode = ImageDecode

local Window, Tab, Section = {}, {}, {}
Window.__index, Tab.__index, Section.__index = Window, Tab, Section

function Window:_radius(kind)
	local ov = self.Style.Radius and self.Style.Radius[kind]
	if ov ~= nil and ov ~= false then return ov end
	return math.floor((BASE_RADIUS[kind] or 8) * self.Style.Round + 0.5)
end

function Window:_applyCorners()
	for i = #self._corners, 1, -1 do
		local e = self._corners[i]
		if not e[1]:IsDescendantOf(self.Gui) then
			table.remove(self._corners, i)
		else
			e[1].CornerRadius = UDim.new(0, self:_radius(e[2]))
		end
	end
end

function Window:_bind(fn)
	table.insert(self._accentFns, fn)
	fn(self.Accent, self.Accent2)
end

function Window:_connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(self._conns, c)
	return c
end

-- плавно или мгновенно меняет свойства
local function setProps(o, props, animate, t)
	if animate then
		tween(o, t or 0.34, props, Enum.EasingStyle.Quint)
	else
		for k, v in pairs(props) do o[k] = v end
	end
end

-- показать/спрятать подпись с плавным исчезновением
local function fadeVisible(label, show, animate)
	label:SetAttribute("want", show)
	if show then
		label.Visible = true
		if animate then
			label.TextTransparency = 1
			task.delay(0.14, function()
				if label.Parent and label:GetAttribute("want") == true then tween(label, 0.2, { TextTransparency = 0 }) end
			end)
		else
			label.TextTransparency = 0
		end
	else
		if animate and label.Visible then
			tween(label, 0.12, { TextTransparency = 1 })
			task.delay(0.13, function()
				if label.Parent and label:GetAttribute("want") == false then label.Visible = false end
			end)
		else
			label.Visible = false
		end
	end
end

----------------------------------------------------------------------
-- клавиша-чип (используется в Keybind и у Toggle/Button)
----------------------------------------------------------------------
local function keyChip(win, parent, default, onChanged, onPress)
	local T = win.Theme
	local box = make("TextButton", {
		Text = "", TextColor3 = T.Text, TextSize = 11, BackgroundTransparency = 0, BackgroundColor3 = T.Track,
		Size = UDim2.fromOffset(52, 22), ZIndex = 6, TextTruncate = Enum.TextTruncate.AtEnd, Parent = parent,
	})
	corner(box, "key")
	local api = { Key = default, Box = box, Kind = "key" }
	local listening = false
	local function refresh()
		box.Text = listening and "..." or (api.Key and api.Key.Name or "None")
		tween(box, 0.15, { BackgroundColor3 = listening and win.Accent or T.Track })
	end
	function api:Set(key, silent)
		self.Key = key
		listening = false
		refresh()
		if onChanged and not silent then task.spawn(onChanged, key) end
	end
	function api:Get() return self.Key end
	box.Activated:Connect(function()
		listening = true
		refresh()
	end)
	win:_connect(UserInputService.InputBegan, function(input, gp)
		if listening then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				api:Set(input.KeyCode ~= Enum.KeyCode.Escape and input.KeyCode or nil)
			end
			return
		end
		if not gp and api.Key and input.KeyCode == api.Key and onPress then
			task.spawn(onPress)
		end
	end)
	refresh()
	return api
end

----------------------------------------------------------------------
-- кнопка с цветной полосой, от которой цвет плавно растекается по кнопке
----------------------------------------------------------------------
local function glowButton(win, parent, o)
	local T = win.Theme
	local kind = o.Kind or "button"
	local root = make("Frame", {
		Size = o.Size or UDim2.new(1, 0, 0, o.Height or ELEM_H),
		BackgroundColor3 = T.Elem, Parent = parent,
	})
	corner(root, kind)

	local glow = make("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Parent = root,
	})
	corner(glow, kind)
	local glowGrad = make("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
		Parent = glow,
	})

	local strip = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(0, win.Style.Strip, 0, 0), BackgroundColor3 = Color3.new(1, 1, 1), Parent = root,
	})
	corner(strip, "strip")
	local stripGrad = make("UIGradient", { Rotation = 90, Parent = strip })

	local iconImg
	local textX = 14
	if o.Icon then
		iconImg = icon(root, o.Icon, 18)
		iconImg.AnchorPoint = Vector2.new(0, 0.5)
		iconImg.Position = UDim2.new(0, 14, 0.5, 0)
		iconImg.ImageColor3 = T.SubText
		textX = 40
	end

	local label = make("TextLabel", {
		Text = o.Text or "", TextColor3 = o.Dim and T.SubText or T.Text,
		Size = UDim2.new(1, -textX - 8, 1, 0), Position = UDim2.new(0, textX, 0, 0),
		TextXAlignment = o.Center and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = root,
	})
	local hit = make("TextButton", { Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 5, Parent = root })

	local st = { hover = false, active = false, press = false, compact = false }
	local function update()
		local S = win.Style
		local gt, sh = 1, 0
		if st.press then
			gt, sh = 0.35, S.StripH[3]
		elseif st.active then
			gt, sh = 0.55, S.StripH[1]
		elseif st.hover then
			gt, sh = 0.8, S.StripH[2]
		end
		tween(glow, 0.22, { BackgroundTransparency = gt })
		tween(strip, 0.22, { Size = UDim2.new(0, S.Strip, sh, 0) })
		local bright = st.active or st.hover or st.press or not o.Dim
		tween(label, 0.2, { TextColor3 = bright and T.Text or T.SubText })
		if iconImg then
			tween(iconImg, 0.2, { ImageColor3 = st.active and win.Accent or T.SubText })
		end
	end
	table.insert(win._refreshers, update)

	win:_bind(function(c, c2)
		glowGrad.Color = ColorSequence.new(c, c2)
		stripGrad.Color = ColorSequence.new(c, c2)
		if iconImg and st.active then iconImg.ImageColor3 = c end
	end)

	local function isPress(i)
		return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
	end
	hit.MouseEnter:Connect(function() st.hover = true; update() end)
	hit.MouseLeave:Connect(function() st.hover = false; st.press = false; update() end)
	hit.InputBegan:Connect(function(i)
		if isPress(i) then st.press = true; update() end
	end)
	hit.InputEnded:Connect(function(i)
		if isPress(i) then
			st.press = false
			if i.UserInputType == Enum.UserInputType.Touch then st.hover = false end
			update()
		end
	end)

	update()

	local api = { Root = root, Label = label, Hit = hit, Icon = iconImg }
	function api.SetActive(b) st.active = b; update() end
	function api.SetText(t) label.Text = t end
	function api.SetCompact(b, animate)
		st.compact = b
		if iconImg then
			setProps(iconImg, {
				AnchorPoint = b and Vector2.new(0.5, 0.5) or Vector2.new(0, 0.5),
				Position = b and UDim2.new(0.5, 0, 0.5, 0) or UDim2.new(0, 14, 0.5, 0),
			}, animate)
			if b then
				if animate then
					tween(label, 0.12, { TextTransparency = 1 })
					task.delay(0.13, function()
						if label.Parent and st.compact then label.Visible = false end
					end)
				else
					label.Visible = false
				end
			else
				label.Visible = true
				if animate then
					label.TextTransparency = 1
					task.delay(0.14, function()
						if label.Parent and not st.compact then tween(label, 0.2, { TextTransparency = 0 }) end
					end)
				else
					label.TextTransparency = 0
				end
			end
		else
			label.TextSize = b and 11 or 13
			label.TextXAlignment = b and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
			label.Position = b and UDim2.new(0, 4, 0, 0) or UDim2.new(0, textX, 0, 0)
			label.Size = b and UDim2.new(1, -8, 1, 0) or UDim2.new(1, -textX - 8, 1, 0)
		end
	end
	return api
end

----------------------------------------------------------------------
-- карточки элементов
----------------------------------------------------------------------
local function baseCard(section, h)
	local win = section.Window
	local card = make("Frame", { Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = win.Theme.Elem })
	corner(card, "card")
	table.insert(win._cardStrokes, stroke(card, win.Theme.Stroke, 1, win.Style.CardStroke))
	return card
end

local function cardLabel(card, T, text, reserve)
	return make("TextLabel", {
		Text = text, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -(24 + (reserve or 0)), 0, ELEM_H), Position = UDim2.new(0, 12, 0, 0),
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = card,
	})
end

local function cardHit(card)
	return make("TextButton", { Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 5, Parent = card })
end

local function hoverCard(win, card, src)
	local T = win.Theme
	src = src or card
	src.MouseEnter:Connect(function() tween(card, 0.15, { BackgroundColor3 = T.ElemHover }) end)
	src.MouseLeave:Connect(function() tween(card, 0.2, { BackgroundColor3 = T.Elem }) end)
end

local function sideIndex(s)
	if s == 1 or s == "Left" or s == "left" then return 1 end
	if s == 2 or s == "Right" or s == "right" then return 2 end
	return nil
end

----------------------------------------------------------------------
-- Section
----------------------------------------------------------------------
function Section:_place(item)
	local col
	if self.Window._oneCol then
		col = 1
	else
		col = item.Side or ((self._h[1] <= self._h[2]) and 1 or 2)
	end
	self._h[col] += item.H + 8
	item.Frame.Parent = (col == 1) and self._colL or self._colR
end

function Section:_arrange()
	self._h = { 0, 0 }
	for _, it in ipairs(self._items) do self:_place(it) end
	local one = self.Window._oneCol
	self._colR.Visible = not one
	self._colL.Size = one and UDim2.new(1, 0, 0, 0) or UDim2.new(0.5, -6, 0, 0)
end

function Section:_addItem(frame, h, side)
	self._n += 1
	frame.LayoutOrder = self._n
	local item = { Frame = frame, H = h, Side = sideIndex(side) }
	table.insert(self._items, item)
	self:_place(item)
	return item
end

-- уникальный ключ элемента для конфигов (по умолчанию Вкладка/Секция/Название)
function Section:_flag(o, kind)
	local win = self.Window
	local base = o.Flag or (self.Tab.Name .. "/" .. self.Name .. "/" .. (o.Name or kind))
	local flag, n = base, 1
	while win._flagNames[flag] do
		n += 1
		flag = base .. "#" .. n
	end
	win._flagNames[flag] = true
	return flag
end

function Section:_reg(flag, obj, kind, o)
	obj.Kind = kind
	obj.Flag = flag
	if o.Config ~= false then self.Window._flagObjs[flag] = obj end
end

function Section:AddLabel(text)
	CTX = self.Window
	local T = self.Window.Theme
	local l = make("TextLabel", {
		Text = text or "", TextColor3 = T.SubText, TextSize = 12, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	pad(l, 4, 2, 4, 2)
	self:_addItem(l, 22)
	local obj = { Root = l, Label = l }
	function obj:Set(t) l.Text = t end
	return obj
end

-- Keybind = Enum.KeyCode.X (или Bindable = true) добавляет чип с клавишей справа
function Section:AddButton(o)
	CTX = self.Window
	local win = self.Window
	local bindable = o.Keybind ~= nil or o.Bindable
	local flag = bindable and self:_flag(o, "button") or nil
	local b = glowButton(win, nil, { Text = o.Name or "Button", Height = ELEM_H })
	local function fire()
		if o.Callback then task.spawn(o.Callback) end
	end
	b.Hit.Activated:Connect(fire)
	local obj = { Root = b.Root, Label = b.Label, Hit = b.Hit, Icon = b.Icon }
	function obj:SetText(t) b.SetText(t) end
	if bindable then
		local chip = keyChip(win, b.Root, o.Keybind, o.BindChanged, fire)
		chip.Box.AnchorPoint = Vector2.new(1, 0.5)
		chip.Box.Position = UDim2.new(1, -8, 0.5, 0)
		chip.Box.Visible = KEYBOARD
		b.Label.Size = UDim2.new(1, -86, 1, 0)
		if o.Config ~= false then win._flagObjs[flag .. "@bind"] = chip end
		obj.Bind = chip
	end
	self:_addItem(b.Root, ELEM_H, o.Side)
	return obj
end

function Section:AddToggle(o)
	CTX = self.Window
	local win, T = self.Window, self.Window.Theme
	local flag = self:_flag(o, "toggle")
	local bindable = o.Keybind ~= nil or o.Bindable
	local card = baseCard(self, ELEM_H)
	local nameLbl = cardLabel(card, T, o.Name or "Toggle", 50 + (bindable and 62 or 0))

	local startOn = o.Default == true
	local white = Color3.new(1, 1, 1)

	-- вид «переключатель»
	local track = make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(38, 20), BackgroundColor3 = T.Track, Parent = card,
	})
	corner(track, "toggle")
	local onFill = make("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = white,
		BackgroundTransparency = startOn and 0 or 1, Parent = track,
	})
	corner(onFill, "toggle")
	local onGrad = make("UIGradient", { Parent = onFill })
	local knob = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(14, 14), BackgroundColor3 = white, ZIndex = 2, Parent = track,
	})
	corner(knob, "knob")

	-- вид «галочка»
	local box = make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(22, 22), BackgroundColor3 = T.Track, Visible = false, Parent = card,
	})
	corner(box, "check")
	stroke(box, T.Stroke, 1, 0.2)
	local boxFill = make("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = white,
		BackgroundTransparency = startOn and 0 or 1, Parent = box,
	})
	corner(boxFill, "check")
	local boxGrad = make("UIGradient", { Parent = boxFill })
	local tick = icon(box, Mochi.Icons.Check, 16)
	tick.AnchorPoint = Vector2.new(0.5, 0.5)
	tick.Position = UDim2.fromScale(0.5, 0.5)
	tick.ZIndex = 2
	tick.ImageTransparency = startOn and 0 or 1

	local hit = cardHit(card)
	hoverCard(win, card, hit)

	local obj = { Value = startOn, Root = card, NameLabel = nameLbl, Track = track, Knob = knob, Box = box, Tick = tick }
	if startOn then knob.Position = UDim2.new(1, -17, 0.5, 0) end
	win.Flags[flag] = obj.Value

	local chip
	local function applyStyle()
		local cb = win.Style.ToggleStyle == "Checkbox"
		track.Visible = not cb
		box.Visible = cb
		if chip then chip.Box.Position = UDim2.new(1, cb and -42 or -58, 0.5, 0) end
	end
	table.insert(win._refreshers, applyStyle)

	function obj:Set(v, silent)
		self.Value = v and true or false
		local on = self.Value
		tween(onFill, 0.2, { BackgroundTransparency = on and 0 or 1 })
		tween(boxFill, 0.2, { BackgroundTransparency = on and 0 or 1 })
		tween(tick, 0.2, { ImageTransparency = on and 0 or 1 })
		tween(knob, 0.22, { Position = on and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }, Enum.EasingStyle.Back)
		win.Flags[flag] = on
		if not silent and o.Callback then task.spawn(o.Callback, on) end
	end
	function obj:Get() return self.Value end

	hit.Activated:Connect(function() obj:Set(not obj.Value) end)
	win:_bind(function(c, c2)
		onGrad.Color = ColorSequence.new(c, c2)
		boxGrad.Color = ColorSequence.new(c, c2)
	end)

	if bindable then
		chip = keyChip(win, card, o.Keybind, o.BindChanged, function() obj:Set(not obj.Value) end)
		chip.Box.AnchorPoint = Vector2.new(1, 0.5)
		chip.Box.Visible = KEYBOARD
		if o.Config ~= false then win._flagObjs[flag .. "@bind"] = chip end
		obj.Bind = chip
	end
	applyStyle()

	self:_reg(flag, obj, "toggle", o)
	self:_addItem(card, ELEM_H, o.Side)
	return obj
end

function Section:AddSlider(o)
	CTX = self.Window
	local win, T = self.Window, self.Window.Theme
	local flag = self:_flag(o, "slider")
	local min, max, step = o.Min or 0, o.Max or 100, o.Step or 1
	local card = baseCard(self, 52)
	local nameLbl = make("TextLabel", {
		Text = o.Name or "Slider", TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -100, 0, 28), Position = UDim2.new(0, 12, 0, 4),
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = card,
	})
	local valLbl = make("TextLabel", {
		TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 84, 0, 28), Position = UDim2.new(1, -96, 0, 4), Parent = card,
	})
	local track = make("Frame", {
		Position = UDim2.new(0, 12, 0, 36), Size = UDim2.new(1, -24, 0, 6), BackgroundColor3 = T.Track, Parent = card,
	})
	corner(track, "track")
	local fill = make("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), Parent = track })
	corner(fill, "track")
	local grad = make("UIGradient", { Parent = fill })
	local knob = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Color3.new(1, 1, 1), Parent = fill,
	})
	corner(knob, "thumb")
	win:_bind(function(c, c2)
		local e = (c2 == c) and c:Lerp(Color3.new(1, 1, 1), 0.3) or c2
		grad.Color = ColorSequence.new(c, e)
	end)
	local hit = cardHit(card)
	hoverCard(win, card, hit)

	-- "Knob": дорожка с кружком, "Bar": прямоугольная полоса без кружка
	local function applySliderStyle()
		local bar = win.Style.SliderStyle == "Bar"
		track.Position = bar and UDim2.new(0, 12, 0, 32) or UDim2.new(0, 12, 0, 36)
		track.Size = bar and UDim2.new(1, -24, 0, 14) or UDim2.new(1, -24, 0, 6)
		knob.Visible = not bar
	end
	table.insert(win._refreshers, applySliderStyle)
	applySliderStyle()

	local function fmt(v)
		return tostring(tonumber(string.format("%.2f", v)))
	end
	local obj = {
		Value = math.clamp(o.Default or min, min, max),
		Root = card, NameLabel = nameLbl, ValueLabel = valLbl, Track = track, Fill = fill, Knob = knob,
	}

	local function render(instant)
		local rel = (obj.Value - min) / math.max(max - min, 1e-9)
		valLbl.Text = fmt(obj.Value) .. (o.Suffix or "")
		local goal = UDim2.new(rel, 0, 1, 0)
		if instant then
			fill.Size = goal
		else
			tween(fill, 0.08, { Size = goal }, Enum.EasingStyle.Linear)
		end
	end

	function obj:Set(v, silent)
		v = math.clamp(tonumber(v) or min, min, max)
		v = min + math.floor((v - min) / step + 0.5) * step
		v = math.clamp(math.floor(v * 1e6 + 0.5) / 1e6, min, max)
		local changed = v ~= self.Value
		self.Value = v
		render()
		win.Flags[flag] = v
		if changed and not silent and o.Callback then task.spawn(o.Callback, v) end
	end
	function obj:Get() return self.Value end

	render(true)
	win.Flags[flag] = obj.Value

	local dragging = false
	local function fromX(x)
		local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		obj:Set(min + rel * (max - min))
	end
	hit.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			if self.Scroll then self.Scroll.ScrollingEnabled = false end
			fromX(i.Position.X)
		end
	end)
	win:_connect(UserInputService.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			fromX(i.Position.X)
		end
	end)
	win:_connect(UserInputService.InputEnded, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			if self.Scroll then self.Scroll.ScrollingEnabled = true end
		end
	end)

	self:_reg(flag, obj, "slider", o)
	self:_addItem(card, 52, o.Side)
	return obj
end

function Section:AddDropdown(o)
	CTX = self.Window
	local win, T = self.Window, self.Window.Theme
	local flag = self:_flag(o, "dropdown")
	local multi = o.Multi == true
	local options = o.Options or {}
	local sel = {}
	if o.Default ~= nil then
		if type(o.Default) == "table" then
			for _, v in ipairs(o.Default) do sel[v] = true end
		else
			sel[o.Default] = true
		end
	end

	local card = baseCard(self, ELEM_H)
	card.ClipsDescendants = true
	local nameLbl = make("TextLabel", {
		Text = o.Name or "Dropdown", TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(0.5, -12, 0, ELEM_H), Position = UDim2.new(0, 12, 0, 0),
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = card,
	})
	local valueLbl = make("TextLabel", {
		Text = "—", TextColor3 = T.SubText, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(0.5, -38, 0, ELEM_H), Position = UDim2.new(0.5, 0, 0, 0),
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = card,
	})
	local chev = icon(card, Mochi.Icons.Chevron, 14)
	chev.AnchorPoint = Vector2.new(1, 0)
	chev.Position = UDim2.new(1, -12, 0, (ELEM_H - 14) / 2)
	chev.ImageColor3 = T.SubText
	local head = make("TextButton", { Text = "", Size = UDim2.new(1, 0, 0, ELEM_H), ZIndex = 5, Parent = card })
	hoverCard(win, card, head)

	local listFrame = make("ScrollingFrame", {
		Position = UDim2.new(0, 6, 0, ELEM_H + 2), Size = UDim2.new(1, -12, 0, 0),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 2, ScrollBarImageColor3 = T.Stroke, Parent = card,
	})
	vlist(listFrame, 3)

	local buttons = {}
	local obj = { Root = card, NameLabel = nameLbl, ValueLabel = valueLbl, Chevron = chev, List = listFrame, Options = buttons }
	local open = false
	local openH = ELEM_H

	local function getValue()
		if multi then
			local out = {}
			for _, name in ipairs(options) do
				if sel[name] then table.insert(out, name) end
			end
			return out
		end
		for _, name in ipairs(options) do
			if sel[name] then return name end
		end
		return nil
	end
	local function summary()
		local v = getValue()
		if multi then
			valueLbl.Text = (#v > 0) and table.concat(v, ", ") or "—"
		else
			valueLbl.Text = v and tostring(v) or "—"
		end
	end
	local function commit(silent)
		summary()
		for name, b in pairs(buttons) do b.SetActive(sel[name] == true) end
		win.Flags[flag] = getValue()
		if not silent and o.Callback then task.spawn(o.Callback, getValue()) end
	end
	local function setOpen(v)
		open = v
		tween(card, 0.25, { Size = UDim2.new(1, 0, 0, open and openH or ELEM_H) })
		tween(chev, 0.25, { Rotation = open and 180 or 0 })
	end

	local function rebuild()
		CTX = win
		for _, b in pairs(buttons) do b.Root:Destroy() end
		table.clear(buttons)
		for idx, name in ipairs(options) do
			local b = glowButton(win, listFrame, { Text = tostring(name), Height = 28, Kind = "option", Dim = true })
			b.Root.LayoutOrder = idx
			b.SetActive(sel[name] == true)
			b.Hit.Activated:Connect(function()
				if multi then
					sel[name] = (not sel[name]) or nil
				else
					sel = { [name] = true }
					setOpen(false)
				end
				commit()
			end)
			buttons[name] = b
		end
		local n = math.max(1, math.min(#options, 5))
		local listPx = n * 31 - 3
		listFrame.Size = UDim2.new(1, -12, 0, listPx)
		openH = ELEM_H + listPx + 10
		if open then setOpen(true) end
		summary()
	end

	function obj:Get() return getValue() end
	function obj:Set(v, silent)
		sel = {}
		if type(v) == "table" then
			for _, x in ipairs(v) do sel[x] = true end
		elseif v ~= nil then
			sel[v] = true
		end
		commit(silent)
	end
	function obj:Refresh(newOptions)
		options = newOptions or {}
		for name in pairs(sel) do
			if not table.find(options, name) then sel[name] = nil end
		end
		rebuild()
		commit(true)
	end

	head.Activated:Connect(function() setOpen(not open) end)
	rebuild()
	win.Flags[flag] = getValue()

	self:_reg(flag, obj, "dropdown", o)
	self:_addItem(card, ELEM_H, o.Side)
	return obj
end

-- Квадратный цветовой пикер (SV-квадрат + полоса оттенка), тач/мышь. Default = Color3.
function Section:AddColorPicker(o)
	CTX = self.Window
	local win, T = self.Window, self.Window.Theme
	local flag = self:_flag(o, "color")
	local card = baseCard(self, ELEM_H)
	card.ClipsDescendants = true
	local nameLbl = make("TextLabel", {
		Text = o.Name or "Цвет", TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -56, 0, ELEM_H), Position = UDim2.new(0, 12, 0, 0), Parent = card,
	})
	local swatch = make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(30, 20), Parent = card,
	})
	corner(swatch, "input")
	stroke(swatch, T.Stroke, 1, 0.2)
	local head = make("TextButton", { Text = "", Size = UDim2.new(1, 0, 0, ELEM_H), ZIndex = 5, Parent = card })
	hoverCard(win, card, head)

	local sq = 150
	local hueW = 18
	local area = make("Frame", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, ELEM_H + 6),
		Size = UDim2.new(1, -24, 0, sq), Parent = card,
	})

	local svFrame = make("Frame", {
		Size = UDim2.new(1, -(hueW + 10), 0, sq), BackgroundColor3 = Color3.fromHSV(0, 1, 1), Parent = area,
	})
	corner(svFrame, "card")
	svFrame.ClipsDescendants = true
	local satOverlay = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = svFrame })
	make("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }), Parent = satOverlay,
	})
	local valOverlay = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), Parent = svFrame })
	make("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }),
		Parent = valOverlay,
	})
	local cursor = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12),
		BackgroundTransparency = 1, ZIndex = 3, Parent = svFrame,
	})
	corner(cursor, "knob")
	stroke(cursor, Color3.new(1, 1, 1), 2, 0)
	local svHit = make("TextButton", { Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = svFrame })

	local hueFrame = make("Frame", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(hueW, sq), Parent = area,
	})
	corner(hueFrame, "card")
	hueFrame.ClipsDescendants = true
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
			ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
			ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)),
			ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
			ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)),
			ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
		}),
		Parent = hueFrame,
	})
	local hueCursor = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.new(1, 4, 0, 4), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = hueFrame,
	})
	stroke(hueCursor, Color3.new(0, 0, 0), 1, 0.4)
	local hueHit = make("TextButton", { Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = hueFrame })

	local pickerH = ELEM_H + 6 + sq + 8
	local open = false
	local function setOpen(v)
		open = v
		tween(card, 0.25, { Size = UDim2.new(1, 0, 0, open and pickerH or ELEM_H) })
	end
	head.Activated:Connect(function() setOpen(not open) end)

	local h, s, v = 0, 0, 1
	if o.Default then h, s, v = o.Default:ToHSV() end
	local function currentColor() return Color3.fromHSV(h, s, v) end
	local function updateVisuals()
		svFrame.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		cursor.Position = UDim2.new(s, 0, 1 - v, 0)
		hueCursor.Position = UDim2.new(0.5, 0, h, 0)
		swatch.BackgroundColor3 = currentColor()
	end
	updateVisuals()

	local obj = { Root = card, NameLabel = nameLbl, Swatch = swatch, SVFrame = svFrame, HueFrame = hueFrame }
	function obj:Get() return currentColor() end
	function obj:Set(color, silent)
		h, s, v = color:ToHSV()
		updateVisuals()
		win.Flags[flag] = color
		if not silent and o.Callback then task.spawn(o.Callback, color) end
	end

	local function fromSV(px, py)
		local pos, size = svFrame.AbsolutePosition, svFrame.AbsoluteSize
		s = math.clamp((px - pos.X) / math.max(size.X, 1), 0, 1)
		v = 1 - math.clamp((py - pos.Y) / math.max(size.Y, 1), 0, 1)
		updateVisuals()
		win.Flags[flag] = currentColor()
		if o.Callback then task.spawn(o.Callback, currentColor()) end
	end
	local function fromHue(py)
		local pos, size = hueFrame.AbsolutePosition, hueFrame.AbsoluteSize
		h = math.clamp((py - pos.Y) / math.max(size.Y, 1), 0, 1)
		updateVisuals()
		win.Flags[flag] = currentColor()
		if o.Callback then task.spawn(o.Callback, currentColor()) end
	end

	local draggingSV, draggingHue = false, false
	local function isPress(i)
		return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
	end
	svHit.InputBegan:Connect(function(i)
		if isPress(i) then
			draggingSV = true
			if self.Scroll then self.Scroll.ScrollingEnabled = false end
			fromSV(i.Position.X, i.Position.Y)
		end
	end)
	hueHit.InputBegan:Connect(function(i)
		if isPress(i) then
			draggingHue = true
			if self.Scroll then self.Scroll.ScrollingEnabled = false end
			fromHue(i.Position.Y)
		end
	end)
	win:_connect(UserInputService.InputChanged, function(i)
		if (draggingSV or draggingHue) and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			if draggingSV then fromSV(i.Position.X, i.Position.Y) else fromHue(i.Position.Y) end
		end
	end)
	win:_connect(UserInputService.InputEnded, function(i)
		if isPress(i) and (draggingSV or draggingHue) then
			draggingSV, draggingHue = false, false
			if self.Scroll then self.Scroll.ScrollingEnabled = true end
		end
	end)

	win.Flags[flag] = currentColor()
	self:_reg(flag, obj, "color", o)
	self:_addItem(card, ELEM_H, o.Side)
	return obj
end

function Section:AddKeybind(o)
	CTX = self.Window
	local win, T = self.Window, self.Window.Theme
	local flag = self:_flag(o, "key")
	local card = baseCard(self, ELEM_H)
	local nameLbl = cardLabel(card, T, o.Name or "Keybind", 84)
	hoverCard(win, card)

	local chip = keyChip(win, card, o.Default, function(key)
		win.Flags[flag] = key
		if o.ChangedCallback then o.ChangedCallback(key) end
	end, o.Callback)
	chip.Root, chip.NameLabel = card, nameLbl
	chip.Box.Size = UDim2.fromOffset(72, 24)
	chip.Box.AnchorPoint = Vector2.new(1, 0.5)
	chip.Box.Position = UDim2.new(1, -8, 0.5, 0)
	win.Flags[flag] = chip.Key

	self:_reg(flag, chip, "key", o)
	self:_addItem(card, ELEM_H, o.Side)
	return chip
end

function Section:AddInput(o)
	CTX = self.Window
	local win, T = self.Window, self.Window.Theme
	local flag = self:_flag(o, "input")
	local card = baseCard(self, 62)
	local nameLbl = make("TextLabel", {
		Text = o.Name or "Input", TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -24, 0, 22), Position = UDim2.new(0, 12, 0, 5),
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = card,
	})
	local box = make("TextBox", {
		Text = o.Default or "", PlaceholderText = o.Placeholder or "text...",
		PlaceholderColor3 = T.SubText, TextColor3 = T.Text, ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 0, BackgroundColor3 = T.Track,
		Position = UDim2.new(0, 10, 0, 29), Size = UDim2.new(1, -20, 0, 26), ClipsDescendants = true, Parent = card,
	})
	corner(box, "input")
	pad(box, 8, 0, 8, 0)
	local bs = stroke(box, T.Stroke, 1, 0.3)
	hoverCard(win, card)

	local obj = { Root = card, NameLabel = nameLbl, Box = box, Stroke = bs }
	function obj:Get() return box.Text end
	function obj:Set(t, silent)
		box.Text = tostring(t or "")
		win.Flags[flag] = box.Text
		if not silent and o.Callback then task.spawn(o.Callback, box.Text, false) end
	end
	box.Focused:Connect(function() tween(bs, 0.18, { Color = win.Accent, Transparency = 0 }) end)
	box.FocusLost:Connect(function(enter)
		tween(bs, 0.2, { Color = T.Stroke, Transparency = 0.3 })
		win.Flags[flag] = box.Text
		if o.Callback then task.spawn(o.Callback, box.Text, enter) end
	end)
	win.Flags[flag] = box.Text

	self:_reg(flag, obj, "input", o)
	self:_addItem(card, 62, o.Side)
	return obj
end

----------------------------------------------------------------------
-- Tab
----------------------------------------------------------------------
function Tab:SelectSection(sec)
	self._active = sec
	for _, s in ipairs(self.Sections) do
		local on = s == sec
		s._setBtnActive(on)
		if on then
			if not s.Page.Visible then
				s.Page.Visible = true
				s.Page.GroupTransparency = 1
				s.Page.Position = UDim2.new(0, 0, 0, 10)
				tween(s.Page, 0.3, { GroupTransparency = 0, Position = UDim2.new() })
			end
		else
			s.Page.Visible = false
		end
	end
end

function Tab:AddSection(name)
	CTX = self.Window
	local win = self.Window
	local T = win.Theme
	local sec = setmetatable({ Window = win, Tab = self, Name = name, _items = {}, _h = { 0, 0 }, _n = 0 }, Section)

	-- кнопка секции сверху
	local btn = make("TextButton", {
		Text = name, TextColor3 = T.SubText, Font = FONT_B, TextSize = 13,
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 30),
		LayoutOrder = #self.Sections + 1, Parent = self.Bar,
	})
	pad(btn, 12, 0, 12, 0)
	local ul = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(0, 0, 0, 2), BackgroundColor3 = Color3.new(1, 1, 1), Parent = btn,
	})
	corner(ul, "underline")
	local ulGrad = make("UIGradient", { Parent = ul })
	win:_bind(function(c, c2) ulGrad.Color = ColorSequence.new(c, c2) end)

	local active, hover = false, false
	local function paint()
		if active then
			tween(ul, 0.25, { Size = UDim2.new(0.8, 0, 0, 2), BackgroundTransparency = 0 })
		elseif hover then
			tween(ul, 0.2, { Size = UDim2.new(0.3, 0, 0, 2), BackgroundTransparency = 0.5 })
		else
			tween(ul, 0.2, { Size = UDim2.new(0, 0, 0, 2), BackgroundTransparency = 0.5 })
		end
		tween(btn, 0.2, { TextColor3 = (active or hover) and T.Text or T.SubText })
	end
	btn.MouseEnter:Connect(function() hover = true; paint() end)
	btn.MouseLeave:Connect(function() hover = false; paint() end)
	sec._setBtnActive = function(on) active = on; paint() end
	btn.Activated:Connect(function() self:SelectSection(sec) end)
	sec.Button, sec.Underline = btn, ul

	-- страница
	local page = make("CanvasGroup", { Size = UDim2.fromScale(1, 1), Visible = false, Parent = win._pages })
	local scroll = make("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3, ScrollBarImageColor3 = T.Stroke, ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = page,
	})
	local wrap = make("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = scroll,
	})
	pad(wrap, 12, 12, 12, 12)
	local cols = make("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = wrap,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Top, Parent = cols,
	})
	local function column(order)
		local c = make("Frame", {
			BackgroundTransparency = 1, Size = UDim2.new(0.5, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order, Parent = cols,
		})
		vlist(c, 8)
		return c
	end
	sec.Page, sec.Scroll = page, scroll
	sec._colL, sec._colR = column(1), column(2)
	sec:_arrange()

	table.insert(self.Sections, sec)
	table.insert(win._sections, sec)
	if #self.Sections == 1 then
		self._active = sec
		if win._activeTab == self then self:SelectSection(sec) end
	end
	return sec
end

----------------------------------------------------------------------
-- Конфиги: хранилища
----------------------------------------------------------------------
local MemoryStore = {}

local function makeMemoryBackend(id)
	MemoryStore[id] = MemoryStore[id] or { configs = {}, auto = nil }
	local st = MemoryStore[id]
	return {
		Persistent = false,
		List = function()
			local t = {}
			for n in pairs(st.configs) do t[#t + 1] = n end
			table.sort(t)
			return t
		end,
		Read = function(n) return st.configs[n] end,
		Write = function(n, s) st.configs[n] = s end,
		Delete = function(n) st.configs[n] = nil end,
		GetAuto = function() return st.auto end,
		SetAuto = function(n) st.auto = n end,
	}
end

-- файловое хранилище: работает только если в среде есть writefile / readfile / isfile / listfiles
local function makeFileBackend(folder)
	local wf, rf, isf, lf = genv("writefile"), genv("readfile"), genv("isfile"), genv("listfiles")
	if not (type(wf) == "function" and type(rf) == "function" and type(isf) == "function" and type(lf) == "function") then
		return nil
	end
	local mf, isfold, df = genv("makefolder"), genv("isfolder"), genv("delfile")
	local function ensure(path)
		if type(isfold) == "function" and type(mf) == "function" then
			local ok, has = pcall(isfold, path)
			if ok and not has then pcall(mf, path) end
		end
	end
	local root = "Mochi"
	local dir = root .. "/" .. folder
	ensure(root)
	ensure(dir)
	local function path(n) return dir .. "/" .. n .. ".json" end
	local autoPath = dir .. "/_autoload.txt"
	local function readIf(p)
		local ok, s = pcall(function()
			if isf(p) then return rf(p) end
			return nil
		end)
		if ok then return s end
		return nil
	end
	return {
		Persistent = true,
		List = function()
			local out = {}
			local ok, files = pcall(lf, dir)
			if ok and type(files) == "table" then
				for _, f in ipairs(files) do
					local n = tostring(f):match("([^/\\]+)%.json$")
					if n then out[#out + 1] = n end
				end
			end
			table.sort(out)
			return out
		end,
		Read = function(n) return readIf(path(n)) end,
		Write = function(n, s) pcall(wf, path(n), s) end,
		Delete = function(n)
			if type(df) == "function" then pcall(df, path(n)) end
		end,
		GetAuto = function()
			local s = readIf(autoPath)
			if s and s ~= "" then return s end
			return nil
		end,
		SetAuto = function(n) pcall(wf, autoPath, n or "") end,
	}
end

----------------------------------------------------------------------
-- Window: конфиги
----------------------------------------------------------------------
function Window:_cfgChanged()
	for _, fn in ipairs(self._onConfigs) do task.spawn(fn) end
end

function Window:_collect()
	local data = {}
	for flag, obj in pairs(self._flagObjs) do
		local ok, v = pcall(function() return obj:Get() end)
		if ok then
			if obj.Kind == "key" then
				data[flag] = v and { __key = v.Name } or "__none"
			elseif obj.Kind == "color" then
				data[flag] = { __color = { v.R, v.G, v.B } }
			elseif v ~= nil then
				data[flag] = v
			end
		end
	end
	return data
end

-- текущие значения всех элементов одной строкой (JSON)
function Window:ExportConfig()
	local ok, str = pcall(function() return HttpService:JSONEncode(self:_collect()) end)
	if ok then return str end
	return nil
end

-- применить строку конфига; возвращает ok, сколько элементов применено
function Window:ImportConfig(str)
	local ok, data = pcall(function() return HttpService:JSONDecode(str) end)
	if not ok or type(data) ~= "table" then return false, "не похоже на конфиг" end
	local n = 0
	for flag, v in pairs(data) do
		local obj = self._flagObjs[flag]
		if obj then
			local ok2 = pcall(function()
				if obj.Kind == "key" then
					if type(v) == "table" and v.__key then v = Enum.KeyCode[v.__key] else v = nil end
				elseif obj.Kind == "color" then
					if type(v) == "table" and v.__color then v = Color3.new(v.__color[1], v.__color[2], v.__color[3]) end
				end
				obj:Set(v)
			end)
			if ok2 then n += 1 end
		end
	end
	return true, n
end

function Window:ListConfigs() return self.ConfigBackend.List() end

function Window:SaveConfig(name)
	name = cleanName(name)
	if name == "" then return false, "пустое название" end
	local str = self:ExportConfig()
	if not str then return false, "не удалось собрать конфиг" end
	self.ConfigBackend.Write(name, str)
	self:_cfgChanged()
	return true
end

function Window:LoadConfig(name)
	name = cleanName(name)
	if name == "" then return false, "пустое название" end
	local str = self.ConfigBackend.Read(name)
	if not str then return false, "конфиг не найден" end
	return self:ImportConfig(str)
end

function Window:DeleteConfig(name)
	name = cleanName(name)
	if name == "" then return false, "пустое название" end
	self.ConfigBackend.Delete(name)
	if self.ConfigBackend.GetAuto() == name then self.ConfigBackend.SetAuto(nil) end
	self:_cfgChanged()
	return true
end

function Window:SetAutoload(name)
	self.ConfigBackend.SetAuto(name and cleanName(name) or nil)
end

-- вызови в конце своего скрипта, когда все элементы уже созданы
function Window:LoadAutoConfig()
	local n = self.ConfigBackend.GetAuto()
	if n and n ~= "" then return self:LoadConfig(n) end
	return false, "автозагрузка не задана"
end

----------------------------------------------------------------------
-- Window: логотип, маскот, тема, стиль
----------------------------------------------------------------------
-- target по умолчанию основное окно; onMove вызывается при реальном перемещении, onEnd — когда отпустили
local function draggable(win, handle, target, onMove, onEnd)
	target = target or win.Holder
	local isHolder = target == win.Holder
	local dragging, startPos, startTarget = false, nil, nil
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			startPos = input.Position
			startTarget = target.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					if onEnd then onEnd() end
				end
			end)
		end
	end)
	win:_connect(UserInputService.InputChanged, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - startPos
			if not isHolder then d = d / win._scale.Scale end
			target.Position = UDim2.new(
				startTarget.X.Scale, startTarget.X.Offset + d.X,
				startTarget.Y.Scale, startTarget.Y.Offset + d.Y
			)
			if isHolder then
				win._dragged = true
			elseif onMove then
				onMove()
			end
		end
	end)
end

function Window:_newLogo(parent, size)
	local slot = {}
	slot.frame = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), Parent = parent })
	slot.img = make("ImageLabel", { Size = UDim2.fromScale(1, 1), Parent = slot.frame })
	slot.fallback = make("TextLabel", {
		Text = string.upper(string.sub(self.Title, 1, 1)), Font = FONT_B, TextSize = math.floor(size * 0.6),
		TextColor3 = self.Accent, TextScaled = true, Size = UDim2.fromScale(1, 1), Visible = false, Parent = slot.frame,
	})
	table.insert(self._logoSlots, slot)
	return slot
end

function Window:_applyLogo()
	local spec = self.LogoSpec
	local kind = classifyImage(spec)
	for _, slot in ipairs(self._logoSlots) do
		if kind ~= "svg" and slot.spec == spec and slot.handle then
			-- base64 / rbxassetid не перезагружаем при смене акцента
		else
			if slot.handle then slot.handle.Cancel() end
			slot.spec = spec
			slot.img.Visible = false
			slot.fallback.Visible = true
			slot.handle = Mochi.LoadImage(slot.img, spec, {
				px = 256, maxDim = 384, accent = self.Accent, accent2 = self.Accent2,
				onReady = function()
					slot.img.Visible = true
					slot.fallback.Visible = false
				end,
				onFail = function()
					slot.img.Visible = false
					slot.fallback.Visible = true
				end,
			})
		end
		slot.fallback.TextColor3 = self.Accent
	end
end

-- Window:SetLogo("<svg ...>") | "rbxassetid://123" | 123 | "iVBORw0..." (PNG/GIF base64) | { Base64 = "..." } | nil (встроенный)
function Window:SetLogo(spec)
	self.LogoSpec = spec or Mochi.DefaultLogo
	self:_applyLogo()
end

function Window:SetAccent(c, c2)
	self.Accent = c
	self.Accent2 = c2 or c
	for _, fn in ipairs(self._accentFns) do fn(self.Accent, self.Accent2) end
	self:_applyLogo()
end

local ROLES = { "Bg", "Side", "Elem", "ElemHover", "Track", "Stroke", "Text", "SubText" }

-- Window:SetTheme("Violet") | Window:SetTheme(Mochi.Themes.Ocean) | Window:SetTheme("Mono", accent, accent2)
function Window:SetTheme(spec, a1, a2)
	if type(spec) == "string" then
		self._themeName = spec
		spec = Mochi.Themes[spec]
	else
		self._themeName = nil
	end
	if type(spec) ~= "table" then return end
	local T = self.Theme
	local map = {}
	for _, r in ipairs(ROLES) do
		if T[r] and spec[r] then map[T[r]:ToHex()] = spec[r] end
	end
	for _, r in ipairs(ROLES) do
		if spec[r] then T[r] = spec[r] end
	end
	local function remap(inst, prop)
		local ok, c = pcall(function() return inst[prop] end)
		if ok and typeof(c) == "Color3" then
			local n = map[c:ToHex()]
			if n then inst[prop] = n end
		end
	end
	for _, d in ipairs(self.Gui:GetDescendants()) do
		if d:IsA("GuiObject") then remap(d, "BackgroundColor3") end
		if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then remap(d, "TextColor3") end
		if d:IsA("TextBox") then remap(d, "PlaceholderColor3") end
		if d:IsA("ImageLabel") then remap(d, "ImageColor3") end
		if d:IsA("ScrollingFrame") then remap(d, "ScrollBarImageColor3") end
		if d:IsA("UIStroke") then remap(d, "Color") end
	end
	local c1 = a1 or spec.Accent or self.Accent
	self:SetAccent(c1, a2 or a1 or spec.Accent2 or c1)
end

-- Window:SetStyle({ Round = 0, Radius = { thumb = 0 }, Title = true, LogoSize = 40, ... })  —  меняет вид на лету
function Window:SetStyle(tbl)
	local S = self.Style
	for k, v in pairs(tbl) do
		if k == "Radius" and type(v) == "table" then
			for kk, vv in pairs(v) do S.Radius[kk] = vv end
		elseif k == "Square" then
			self.Square = v
		else
			S[k] = v
		end
	end
	self:_applyCorners()
	for _, st in ipairs(self._cardStrokes) do
		if st.Parent then st.Transparency = S.CardStroke end
	end
	self._outline.Thickness = S.OutlineAccent and 1.5 or 1
	for _, fn in ipairs(self._refreshers) do fn() end
	self:_applyLayout()
	self:SetAccent(self.Accent, self.Accent2)
end

function Window:GetStyle() return self.Style end

function Window:SetScale(k)
	self._userScale = math.clamp(k, 0.5, 1.6)
	if self._open then tween(self._scale, 0.2, { Scale = self._userScale }) end
	self:_applyLayout()
end

-- Маскот над логотипом. spec:
--   "rbxassetid://..." | число | "<svg ...>" | "iVBORw0..." / "R0lGOD..." (PNG или GIF в base64, GIF анимируется)
--   { Base64 = "..." } | { Base64 = { "часть1", "часть2" } } | { Svg = "..." }
--   { Image = ..., Size = Vector2, Align = "Left"|"Center"|"Right", MaxDim = 512,
--     Frames = { "rbxassetid://1", ... }, FPS = 12,
--     Sheet = { Cols = 4, Rows = 4, Count = 16, FrameSize = Vector2.new(256, 256) } }
function Window:SetMascot(spec)
	self._mascotToken += 1
	local token = self._mascotToken
	local m = self.Mascot
	if self._mascotHandle then
		self._mascotHandle.Cancel()
		self._mascotHandle = nil
	end
	m.ImageRectOffset = Vector2.zero
	m.ImageRectSize = Vector2.zero
	pcall(function() m.Image = "" end)
	if not spec then
		m.Visible = false
		self:_applyLayout()
		return
	end
	if type(spec) ~= "table" then spec = { Image = spec } end
	local imageSpec = spec.Image
	if imageSpec == nil and spec.Base64 ~= nil then imageSpec = { Base64 = spec.Base64 } end
	if imageSpec == nil and spec.Svg ~= nil then imageSpec = { Svg = spec.Svg } end
	if spec.Size then self.MascotSize = spec.Size end
	if spec.Align then self.MascotAlign = spec.Align end
	m.Visible = true
	local opts = { maxDim = spec.MaxDim or 512, px = 512, accent = self.Accent, accent2 = self.Accent2 }
	if spec.Sheet then
		local sh = spec.Sheet
		local cols, rows = sh.Cols or 1, sh.Rows or 1
		local count = sh.Count or cols * rows
		local fw, fh = sh.FrameSize.X, sh.FrameSize.Y
		opts.maxDim = 1024
		self._mascotHandle = Mochi.LoadImage(m, imageSpec, opts)
		m.ImageRectSize = Vector2.new(fw, fh)
		task.spawn(function()
			local i = 0
			while self._mascotToken == token and m.Parent do
				local f = i % count
				m.ImageRectOffset = Vector2.new((f % cols) * fw, math.floor(f / cols) * fh)
				i += 1
				task.wait(1 / (spec.FPS or 12))
			end
		end)
	elseif spec.Frames and #spec.Frames > 0 then
		local frames = {}
		for i, f in ipairs(spec.Frames) do
			frames[i] = (type(f) == "number") and ("rbxassetid://" .. f) or f
		end
		task.spawn(function() pcall(function() ContentProvider:PreloadAsync(frames) end) end)
		task.spawn(function()
			local i = 0
			while self._mascotToken == token and m.Parent do
				m.Image = frames[i % #frames + 1]
				i += 1
				task.wait(1 / (spec.FPS or 12))
			end
		end)
	else
		self._mascotHandle = Mochi.LoadImage(m, imageSpec, opts)
	end
	self:_applyLayout()
end

----------------------------------------------------------------------
-- Window: раскладка и левая панель
----------------------------------------------------------------------
function Window:_mascotX()
	local w, msz = self._w, self._msz
	if self.MascotAlign == "Center" then
		return w / 2
	elseif self.MascotAlign == "Right" then
		return w - msz.X / 2 - 24
	end
	return (self._sideW or 64) / 2
end

-- режим раскрытия панели: "Overlay" (поверх) | "Slide" (сдвигает контент) | "Push" (сжимает контент)
function Window:_effMode()
	local m = self.Style.SidebarMode or "Auto"
	if m == "Auto" then return self._compact and "Slide" or "Push" end
	return m
end

-- целевая геометрия панели для текущего состояния (свёрнута / раскрыта)
function Window:_geom()
	local S = self.Style
	local w, h = self._w, self._h
	local compact, open = self._compact, self._sideOpen
	local mode = self:_effMode()
	local cw = S.CollapsedWidth
	local ew = math.max(cw + 40, math.min(S.ExpandedWidth, w * (compact and 0.6 or 0.45)))
	local sideW = open and ew or cw
	local ls
	if open then
		ls = math.clamp(ew - 28, 40, math.max(40, h * 0.30)) -- логотип занимает всё новое место
	else
		ls = math.min(S.LogoSize, cw - 12)
	end
	local showTitle = (open and S.Title) and true or false
	local contentX, contentW
	if mode == "Push" then
		contentX, contentW = sideW, w - sideW -- контент сжимается
	elseif mode == "Slide" then
		contentX, contentW = sideW, w - cw -- контент уезжает вправо и не сжимается
	else
		contentX, contentW = cw, w - cw -- панель лежит поверх контента
	end
	return {
		sideW = sideW,
		contentX = contentX,
		contentW = contentW,
		ls = ls,
		showTitle = showTitle,
		headerH = ls + 26 + (showTitle and 22 or 0),
		scrim = open and mode ~= "Push",
	}
end

function Window:_applySide(animate)
	if not self._w then return end
	local g = self:_geom()
	local open = self._sideOpen
	self._sideW = g.sideW

	setProps(self._sidebar, { Size = UDim2.new(0, g.sideW, 1, 0) }, animate)
	setProps(self._content, {
		Position = UDim2.new(0, g.contentX, 0, 0), Size = UDim2.new(0, g.contentW, 1, 0),
	}, animate)
	setProps(self._arrow, { Position = UDim2.new(0, g.sideW, 0.5, 0) }, animate)
	setProps(self._arrowIcon, { Rotation = open and 90 or 270 }, animate)
	setProps(self._header, { Size = UDim2.new(1, 0, 0, g.headerH) }, animate)
	setProps(self._logo.frame, { Size = UDim2.fromOffset(g.ls, g.ls) }, animate)
	setProps(self._title, { Position = UDim2.new(0, 0, 0, 13 + g.ls + 4) }, animate)
	setProps(self._tabList, {
		Position = UDim2.new(0, 8, 0, g.headerH + 6),
		Size = UDim2.new(1, -16, 1, -(g.headerH + 6 + 58)),
	}, animate)
	setProps(self._avatar, {
		AnchorPoint = open and Vector2.new(0, 0.5) or Vector2.new(0.5, 0.5),
		Position = open and UDim2.new(0, 8, 0.5, 0) or UDim2.new(0.5, 0, 0.5, 0),
	}, animate)
	setProps(self.Mascot, { Position = UDim2.new(0, self:_mascotX(), 0, 16) }, animate)

	if self._sideShown ~= open or not animate then
		fadeVisible(self._title, g.showTitle, animate)
		fadeVisible(self._nameA, open, animate)
		fadeVisible(self._nameB, open, animate)
		for _, t in ipairs(self._tabs) do t.Button.SetCompact(not open, animate) end
		self._sideShown = open
	end

	-- затемнение контента, когда панель лежит поверх или сдвигает его
	if g.scrim then
		self._scrim.Visible = true
		tween(self._scrim, 0.3, { BackgroundTransparency = 0.45 })
	else
		tween(self._scrim, 0.25, { BackgroundTransparency = 1 })
		task.delay(0.26, function()
			if self._scrim.Parent and not self:_geom().scrim then self._scrim.Visible = false end
		end)
	end

	-- одна колонка, если контенту тесно
	local one = g.contentW < 400
	if one ~= self._oneCol then
		self._oneCol = one
		for _, sec in ipairs(self._sections) do sec:_arrange() end
	end
end

function Window:SetSidebar(open, animate)
	self._sideOpen = open and true or false
	self._sideManual = true
	self:_applySide(animate ~= false)
end

function Window:ToggleSidebar()
	self:SetSidebar(not self._sideOpen, true)
end

function Window:_applyLayout()
	local ui = self._userScale or 1
	local vp = self.Gui.AbsoluteSize / ui
	if vp.X < 10 or vp.Y < 10 then return end
	local hasMascot = self.Mascot.Visible

	local function fit(k)
		local msz = self.MascotSize * k
		local over = hasMascot and (msz.Y - 16) or 0
		local w = math.min(self.MaxSize.X, vp.X * 0.94)
		local h = math.max(200, math.min(self.MaxSize.Y, vp.Y * 0.94 - over))
		if self.Square then
			local side = math.min(w, h)
			w, h = side, side
		end
		return w, h, msz, over
	end
	local w, h, msz, over = fit(1)
	local compact = w < 560
	if compact then w, h, msz, over = fit(0.7) end
	self._w, self._h, self._msz = w, h, msz

	self.Holder.Size = UDim2.fromOffset(w, h)
	if not self._dragged then
		self.Holder.Position = UDim2.new(0.5, 0, 0.5, over / 2 * ui)
	end
	self.Mascot.Size = UDim2.fromOffset(msz.X, msz.Y)

	if compact ~= self._compact then
		self._compact = compact
		-- по умолчанию раскрыта только когда контент можно сжимать (режим Push на ПК)
		self._sideOpen = (not compact) and (self:_effMode() == "Push")
		self._sideManual = false
	end
	self:_applySide(false)
	for _, p in ipairs(self._panels) do self:_layoutPanel(p) end
end

function Window:Toggle(v)
	if v == nil then v = not self._open end
	self._open = v
	if v then
		self.Holder.Visible = true
		tween(self._scale, 0.32, { Scale = self._userScale }, Enum.EasingStyle.Back)
		tween(self.Body, 0.25, { GroupTransparency = 0 })
		tween(self.Mascot, 0.25, { ImageTransparency = 0 })
		tween(self._outline, 0.25, { Transparency = 0.35 })
		for _, p in ipairs(self._panels) do
			if p._open then
				tween(p.Canvas, 0.25, { GroupTransparency = 0 })
				tween(p.Stroke, 0.25, { Transparency = 0.35 })
			end
		end
	else
		tween(self._scale, 0.18, { Scale = self._userScale * 0.94 })
		tween(self.Body, 0.18, { GroupTransparency = 1 })
		tween(self.Mascot, 0.18, { ImageTransparency = 1 })
		tween(self._outline, 0.18, { Transparency = 1 })
		for _, p in ipairs(self._panels) do
			if p._open then
				tween(p.Canvas, 0.18, { GroupTransparency = 1 })
				tween(p.Stroke, 0.18, { Transparency = 1 })
			end
		end
		task.delay(0.2, function()
			if not self._open and self.Holder.Parent then self.Holder.Visible = false end
		end)
	end
	self._fab.Visible = self._fabEnabled and (TOUCH or not v)
end

function Window:SelectTab(tab)
	for _, t in ipairs(self._tabs) do
		local on = t == tab
		t.Button.SetActive(on)
		t.Bar.Visible = on
		if not on then
			for _, s in ipairs(t.Sections) do s.Page.Visible = false end
		end
	end
	self._activeTab = tab
	if tab._active then tab:SelectSection(tab._active) end
end

----------------------------------------------------------------------
-- Panel: отдельная панель слева или справа от меню (любого размера, с любым содержимым, двигается)
----------------------------------------------------------------------
local Panel = setmetatable({}, { __index = Section })
Panel.__index = Panel

function Panel:_place(item)
	self._h[1] += item.H + 8
	item.Frame.Parent = self._colL
end

function Panel:_arrange()
	self._h = { 0, 0 }
	for _, it in ipairs(self._items) do self:_place(it) end
end

-- не даём панели уехать за экран
function Window:_clampPanel(p)
	if not p.Root.Parent or not p.Root.Visible then return end
	local vp = self.Gui.AbsoluteSize
	local pos, size = p.Root.AbsolutePosition, p.Root.AbsoluteSize
	local dx, dy = 0, 0
	if size.X >= vp.X or pos.X < 0 then
		dx = -pos.X
	elseif pos.X + size.X > vp.X then
		dx = vp.X - (pos.X + size.X)
	end
	if size.Y >= vp.Y or pos.Y < 0 then
		dy = -pos.Y
	elseif pos.Y + size.Y > vp.Y then
		dy = vp.Y - (pos.Y + size.Y)
	end
	if dx ~= 0 or dy ~= 0 then
		local k = self._scale.Scale
		local cur = p.Root.Position
		p.Root.Position = UDim2.new(cur.X.Scale, cur.X.Offset + dx / k, cur.Y.Scale, cur.Y.Offset + dy / k)
	end
end

function Window:_layoutPanel(p)
	if not self._w then return end
	local w = math.max(140, p.Width)
	if self._compact then w = math.min(w, math.max(140, self._w * 0.85)) end
	local h = p.Height or self._h
	p.Root.Size = UDim2.fromOffset(w, h)
	if not p._moved then
		local gap = 10
		if p.Side == "Left" then
			p.Root.Position = UDim2.new(0, -(w + gap) + p.Offset.X, 0, p.Offset.Y)
		else
			p.Root.Position = UDim2.new(1, gap + p.Offset.X, 0, p.Offset.Y)
		end
	end
	task.delay(0.06, function() self:_clampPanel(p) end)
end

function Panel:Toggle(v)
	if v == nil then v = not self._open end
	self._open = v
	local win = self.Window
	if v then
		self.Root.Visible = true
		win:_layoutPanel(self)
		tween(self.Canvas, 0.25, { GroupTransparency = 0 })
		tween(self.Stroke, 0.25, { Transparency = 0.35 })
	else
		tween(self.Canvas, 0.18, { GroupTransparency = 1 })
		tween(self.Stroke, 0.18, { Transparency = 1 })
		task.delay(0.2, function()
			if not self._open and self.Root.Parent then self.Root.Visible = false end
		end)
	end
end
function Panel:Show() self:Toggle(true) end
function Panel:Hide() self:Toggle(false) end
function Panel:SetTitle(t)
	self.Name = t
	self.TitleLabel.Text = t
end

-- пустая область заданной высоты: кладёшь внутрь что угодно (ImageLabel, ViewportFrame, свои элементы)
function Panel:AddCustom(height)
	CTX = self.Window
	height = height or 120
	local f = make("Frame", { Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1 })
	self:_addItem(f, height)
	return f
end

-- картинка: { Image = <что угодно, как у логотипа>, Height = 160, Crop = false }
function Panel:AddImage(o)
	CTX = self.Window
	o = o or {}
	local win = self.Window
	local h = o.Height or 160
	local card = baseCard(self, h)
	local img = make("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		ScaleType = o.Crop and Enum.ScaleType.Crop or Enum.ScaleType.Fit, Parent = card,
	})
	corner(img, "card")
	local obj = { Label = img, Frame = card }
	local handle
	function obj:Set(spec)
		if handle then handle.Cancel() end
		handle = Mochi.LoadImage(img, spec, {
			px = 512, maxDim = o.MaxDim or 512, accent = win.Accent, accent2 = win.Accent2,
		})
	end
	obj:Set(o.Image)
	self:_addItem(card, h, o.Side)
	return obj
end

-- 3D-модель в панели: { Model = Instance, Avatar = true | UserId, Character = true, Height = 200, Spin = true, SpinSpeed = 1 }
function Panel:AddViewport(o)
	CTX = self.Window
	o = o or {}
	local win = self.Window
	local h = o.Height or 200
	local card = baseCard(self, h)
	card.ClipsDescendants = true
	local vf = make("ViewportFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(150, 150, 165), LightColor = Color3.new(1, 1, 1), Parent = card,
	})
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.Parent = vf
	vf.CurrentCamera = cam

	local obj = { Frame = card, Viewport = vf, Camera = cam, Spin = o.Spin ~= false }
	local model
	function obj:SetModel(inst)
		if model then model:Destroy() model = nil end
		if not inst then return end
		local clone = inst:Clone()
		if not clone then return end
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("LuaSourceContainer") then d:Destroy() end
			if d:IsA("Humanoid") then d.BreakJointsOnDeath = false end
			if d:IsA("BasePart") then d.Anchored = true end -- фикс: не даём частям разъехаться от физики/breakjoints
		end
		local root = Instance.new("Model")
		clone.Parent = root
		root.Parent = vf
		model = root
		local cf, size = root:GetBoundingBox()
		local radius = math.max(size.X, size.Y, size.Z)
		local dist = radius / (2 * math.tan(math.rad(cam.FieldOfView / 2))) + radius * 0.35
		cam.CFrame = CFrame.new(cf.Position + Vector3.new(0, size.Y * 0.05, dist), cf.Position)
	end

	win:_connect(RunService.RenderStepped, function(dt)
		if obj.Spin and model and model.Parent and self.Root.Visible and win._open then
			model:PivotTo(model:GetPivot() * CFrame.Angles(0, dt * (o.SpinSpeed or 1), 0))
		end
	end)

	if o.Model then
		obj:SetModel(o.Model)
	elseif o.Character then
		local char = Players.LocalPlayer.Character
		if char then
			local was = char.Archivable
			char.Archivable = true
			obj:SetModel(char)
			char.Archivable = was
		end
	elseif o.Avatar then
		task.spawn(function()
			local uid = (o.Avatar == true) and Players.LocalPlayer.UserId or o.Avatar
			local ok, m = pcall(function() return Players:CreateHumanoidModelFromUserId(uid) end)
			if ok and m then
				obj:SetModel(m)
				m:Destroy()
			end
		end)
	end

	self:_addItem(card, h, o.Side)
	return obj
end

function Panel:Destroy()
	local win = self.Window
	for i, p in ipairs(win._panels) do
		if p == self then table.remove(win._panels, i) break end
	end
	self.Root:Destroy()
end

-- Window:AddPanel({ Title = "Тест", Side = "Right" | "Left", Width = 240, Height = nil (по высоте окна),
--                   Offset = Vector2.new(0, 0), Open = true })
-- Внутри работают все элементы (AddToggle, AddSlider, AddButton ...), плюс AddCustom / AddImage / AddViewport.
function Window:AddPanel(o)
	CTX = self
	o = o or {}
	local T = self.Theme
	local panel = setmetatable({
		Window = self, Tab = { Name = "Panel" }, Name = o.Title or "Panel", Side = o.Side or "Right",
		Width = o.Width or 240, Height = o.Height, Offset = o.Offset or Vector2.zero,
		_items = {}, _h = { 0, 0 }, _n = 0, _open = false, _moved = false,
		Draggable = o.Draggable ~= false,
	}, Panel)

	local root = make("Frame", {
		Name = "Panel_" .. panel.Name, BackgroundTransparency = 1, Size = UDim2.fromOffset(panel.Width, 300),
		ZIndex = 4, Visible = false, Parent = self.Holder,
	})
	local canvas = make("CanvasGroup", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Bg, BackgroundTransparency = 0,
		GroupTransparency = 1, ZIndex = 1, Parent = root,
	})
	corner(canvas, "window")
	local outlineF = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, Parent = root })
	corner(outlineF, "window")
	local ostroke = stroke(outlineF, T.Stroke, 1, 1)

	local titleBar = make("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = T.Side, Parent = canvas })
	local titleLbl = make("TextLabel", {
		Text = panel.Name, Font = FONT_B, TextSize = 14, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, -56, 1, 0), Position = UDim2.new(0, 14, 0, 0),
		Parent = titleBar,
	})
	local closeB = make("TextButton", {
		Text = "", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 0, BackgroundColor3 = T.Elem, Parent = titleBar,
	})
	corner(closeB, "close")
	local cIcon = icon(closeB, Mochi.Icons.Close, 11)
	cIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	cIcon.Position = UDim2.fromScale(0.5, 0.5)
	cIcon.ImageColor3 = T.SubText
	closeB.MouseEnter:Connect(function()
		tween(closeB, 0.15, { BackgroundColor3 = self.Theme.ElemHover })
		tween(cIcon, 0.15, { ImageColor3 = self.Theme.Text })
	end)
	closeB.MouseLeave:Connect(function()
		tween(closeB, 0.2, { BackgroundColor3 = self.Theme.Elem })
		tween(cIcon, 0.2, { ImageColor3 = self.Theme.SubText })
	end)
	closeB.Activated:Connect(function() panel:Toggle(false) end)
	make("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 0, 40), BackgroundColor3 = T.Stroke, Parent = canvas })

	local scroll = make("ScrollingFrame", {
		Position = UDim2.new(0, 0, 0, 41), Size = UDim2.new(1, 0, 1, -41), CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = T.Stroke,
		ScrollingDirection = Enum.ScrollingDirection.Y, Parent = canvas,
	})
	local wrap = make("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = scroll,
	})
	pad(wrap, 12, 12, 12, 12)
	local col = make("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = wrap,
	})
	vlist(col, 8)

	panel.Root, panel.Canvas, panel.Stroke, panel.TitleLabel = root, canvas, ostroke, titleLbl
	panel.Scroll, panel._colL, panel.Content = scroll, col, col

	if panel.Draggable then
		draggable(self, titleBar, root, function() panel._moved = true end, function() self:_clampPanel(panel) end)
	end

	table.insert(self._panels, panel)
	self:_layoutPanel(panel)
	if o.Open ~= false then panel:Toggle(true) end
	return panel
end

function Window:AddTab(o)
	CTX = self
	if type(o) == "string" then o = { Name = o } end
	local tab = setmetatable({ Window = self, Name = o.Name, Sections = {} }, Tab)

	tab.Button = glowButton(self, self._tabList, {
		Text = o.Name, Icon = o.Icon, Height = ELEM_H + 2, Dim = true,
	})
	tab.Button.Root.LayoutOrder = #self._tabs + 1
	tab.Button.SetCompact(not self._sideOpen, false)
	tab.Button.Hit.Activated:Connect(function()
		self:SelectTab(tab)
		if self._compact and self._sideOpen then self:SetSidebar(false, true) end
	end)

	tab.Bar = make("ScrollingFrame", {
		Size = UDim2.new(1, -48, 0, 44), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 0, Visible = false, Parent = self._content,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = tab.Bar,
	})
	pad(tab.Bar, 8, 0, 8, 0)
	draggable(self, tab.Bar)

	table.insert(self._tabs, tab)
	if #self._tabs == 1 then self:SelectTab(tab) end
	return tab
end

-- Готовая вкладка настроек: тема, вид (скругления, слайдеры, панель, масштаб), картинки, клавиша меню, конфиги
function Window:AddSettingsTab(o)
	o = o or {}
	local win = self
	local tab = self:AddTab({ Name = o.Name or "Настройки", Icon = Mochi.Icons.Gear })
	local ui = tab:AddSection(o.UITitle or "Интерфейс")
	local pics = tab:AddSection(o.PicturesTitle or "Картинки")
	local cfg = tab:AddSection(o.ConfigTitle or "Конфиги")
	local S = self.Style

	local function labels(list)
		local out = {}
		for i, p in ipairs(list) do out[i] = p[1] end
		return out
	end
	local function labelOf(list, key)
		for _, p in ipairs(list) do
			if p[2] == key then return p[1] end
		end
		return list[1][1]
	end
	local function keyOf(list, label)
		for _, p in ipairs(list) do
			if p[1] == label then return p[2] end
		end
		return list[1][2]
	end
	local MODES = { { "Авто", "Auto" }, { "Поверх", "Overlay" }, { "Сдвиг", "Slide" }, { "Сжатие", "Push" } }
	local SLIDERS = { { "Ползунок", "Knob" }, { "Полоса", "Bar" } }
	local TOGGLES = { { "Переключатель", "Switch" }, { "Галочка", "Checkbox" } }

	ui:AddDropdown({
		Name = "Тема", Flag = "ui.theme", Options = Mochi.ThemeNames, Default = self._themeName,
		Callback = function(n) if n then win:SetTheme(n) end end,
	})
	ui:AddDropdown({
		Name = "Левая панель", Flag = "ui.sidebarmode", Options = labels(MODES), Default = labelOf(MODES, S.SidebarMode),
		Callback = function(l) if l then win:SetStyle({ SidebarMode = keyOf(MODES, l) }) end end,
	})
	ui:AddDropdown({
		Name = "Слайдер", Flag = "ui.sliderstyle", Options = labels(SLIDERS), Default = labelOf(SLIDERS, S.SliderStyle),
		Callback = function(l) if l then win:SetStyle({ SliderStyle = keyOf(SLIDERS, l) }) end end,
	})
	ui:AddDropdown({
		Name = "Тумблер", Flag = "ui.togglestyle", Options = labels(TOGGLES), Default = labelOf(TOGGLES, S.ToggleStyle),
		Callback = function(l) if l then win:SetStyle({ ToggleStyle = keyOf(TOGGLES, l) }) end end,
	})
	ui:AddSlider({
		Name = "Скругление", Flag = "ui.round", Min = 0, Max = 100, Default = math.floor(S.Round * 100 + 0.5), Suffix = "%",
		Callback = function(v) win:SetStyle({ Round = v / 100 }) end,
	})
	ui:AddToggle({
		Name = "Квадратные ручки", Flag = "ui.squarecontrols", Default = false,
		Callback = function(v)
			local r = v and 0 or false
			win:SetStyle({ Radius = { toggle = r, knob = r, track = r, thumb = r, check = r } })
		end,
	})
	ui:AddToggle({
		Name = "Квадратное окно", Flag = "ui.squarewindow", Default = self.Square,
		Callback = function(v) win:SetStyle({ Square = v }) end,
	})
	ui:AddToggle({
		Name = "Название под логотипом", Flag = "ui.title", Default = S.Title,
		Callback = function(v) win:SetStyle({ Title = v }) end,
	})
	ui:AddToggle({
		Name = "Цветная рамка", Flag = "ui.outline", Default = S.OutlineAccent,
		Callback = function(v) win:SetStyle({ OutlineAccent = v }) end,
	})
	ui:AddSlider({
		Name = "Логотип (свёрнутая панель)", Flag = "ui.logosize", Min = 24, Max = 56, Default = S.LogoSize,
		Callback = function(v) win:SetStyle({ LogoSize = v }) end,
	})
	ui:AddSlider({
		Name = "Ширина панели", Flag = "ui.sidewidth", Min = 140, Max = 260, Default = S.ExpandedWidth,
		Callback = function(v) win:SetStyle({ ExpandedWidth = v }) end,
	})
	ui:AddSlider({
		Name = "Масштаб", Flag = "ui.scale", Min = 60, Max = 140, Default = math.floor(self._userScale * 100 + 0.5), Suffix = "%",
		Callback = function(v) win:SetScale(v / 100) end,
	})
	ui:AddKeybind({
		Name = "Клавиша меню", Flag = "ui.togglekey", Default = self.ToggleKey,
		ChangedCallback = function(k) win.ToggleKey = k end,
	})

	-- свои картинки: логотип и маскот
	pics:AddLabel("Вставь SVG-код, base64 (PNG или GIF), rbxassetid://... или число. GIF анимируется.")
	local logoBox = pics:AddInput({ Name = "Логотип", Placeholder = "svg / base64 / rbxassetid", Config = false })
	pics:AddButton({ Name = "Применить логотип", Config = false, Callback = function()
		local t = logoBox:Get()
		if t ~= "" then win:SetLogo(t) end
	end })
	pics:AddButton({ Name = "Вернуть встроенный логотип", Config = false, Callback = function() win:SetLogo(nil) end })
	local mascotBox = pics:AddInput({ Name = "Картинка над логотипом", Placeholder = "base64 / rbxassetid", Config = false })
	pics:AddButton({ Name = "Применить картинку", Config = false, Callback = function()
		local t = mascotBox:Get()
		if t ~= "" then win:SetMascot(t) end
	end })
	pics:AddButton({ Name = "Убрать картинку", Config = false, Callback = function() win:SetMascot(nil) end })

	-- конфиги
	local status = cfg:AddLabel(
		self.ConfigBackend.Persistent and "Конфиги сохраняются в файлы."
			or "Файлового API нет: конфиги живут до выхода из игры. Для переноса используй экспорт и импорт."
	)
	local nameBox = cfg:AddInput({ Name = "Название конфига", Placeholder = "мой конфиг", Config = false })
	local list = cfg:AddDropdown({ Name = "Конфиг", Options = self:ListConfigs(), Config = false })
	local ioBox = cfg:AddInput({ Name = "Текст конфига (экспорт / импорт)", Placeholder = "{...}", Config = false })

	table.insert(self._onConfigs, function() list:Refresh(win:ListConfigs()) end)

	local function pick()
		local n = cleanName(nameBox:Get())
		if n == "" then n = list:Get() or "" end
		return n
	end
	local function say(ok, msg, okText)
		status:Set(ok and okText or ("Ошибка: " .. tostring(msg)))
	end

	cfg:AddButton({ Name = "Сохранить", Config = false, Callback = function()
		local n = pick()
		local ok, err = win:SaveConfig(n)
		say(ok, err, "Сохранено: " .. n)
		if ok then list:Set(n, true) end
	end })
	cfg:AddButton({ Name = "Загрузить", Config = false, Callback = function()
		local n = pick()
		local ok, res = win:LoadConfig(n)
		say(ok, res, "Загружено: " .. n .. " (" .. tostring(res) .. " знач.)")
	end })
	cfg:AddButton({ Name = "Удалить", Config = false, Callback = function()
		local n = pick()
		local ok, err = win:DeleteConfig(n)
		say(ok, err, "Удалено: " .. n)
	end })
	cfg:AddButton({ Name = "Автозагрузка: выбранный", Config = false, Callback = function()
		local n = pick()
		if n == "" then return say(false, "выбери конфиг") end
		win:SetAutoload(n)
		say(true, nil, "Автозагрузка: " .. n)
	end })
	cfg:AddButton({ Name = "Автозагрузка: выключить", Config = false, Callback = function()
		win:SetAutoload(nil)
		say(true, nil, "Автозагрузка выключена")
	end })
	cfg:AddButton({ Name = "Экспорт в поле", Config = false, Callback = function()
		local s = win:ExportConfig()
		if not s then return say(false, "не удалось") end
		ioBox:Set(s, true)
		local clip = genv("setclipboard")
		if type(clip) == "function" then pcall(clip, s) end
		say(true, nil, "Конфиг в поле ниже (скопируй его)")
	end })
	cfg:AddButton({ Name = "Импорт из поля", Config = false, Callback = function()
		local ok, res = win:ImportConfig(ioBox:Get())
		say(ok, res, "Импортировано: " .. tostring(res) .. " знач.")
	end })

	return tab
end

-- Вешает маленькую шестерёнку на любой элемент (host = obj.Root любого Add*) — открывает мини-окошко
-- с настройками, которое строится buildFn(section) один раз при первом открытии (там работают все
-- обычные AddToggle/AddSlider/AddColorPicker и т.д.). Window:AddGear(btn.Root, function(s) s:AddToggle({...}) end)
function Window:AddGear(host, buildFn, opts)
	opts = opts or {}
	local win = self
	local T = win.Theme
	local size = opts.Size or 20
	local gear = make("ImageButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = opts.Position or UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, ZIndex = 6, Parent = host,
	})
	local gi = icon(gear, Mochi.Icons.Gear, size - 5)
	gi.AnchorPoint = Vector2.new(0.5, 0.5)
	gi.Position = UDim2.fromScale(0.5, 0.5)
	gi.ImageColor3 = T.SubText
	gear.MouseEnter:Connect(function() tween(gi, 0.15, { ImageColor3 = win.Accent }) end)
	gear.MouseLeave:Connect(function() tween(gi, 0.2, { ImageColor3 = win.Theme.SubText }) end)

	if not win._gearCatcher then
		win._gearCatcher = make("TextButton", {
			Text = "", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 999, Parent = win.Gui,
		})
	end

	local popup, popSection, built
	local open = false
	local function close()
		if not popup or not open then return end
		open = false
		win._gearCatcher.Visible = false
		tween(popup, 0.15, { GroupTransparency = 1 })
		task.delay(0.16, function()
			if popup and not open then popup.Visible = false end
		end)
		if win._activeGearClose == close then win._activeGearClose = nil end
	end
	local function clampToScreen()
		local vp = win.Gui.AbsoluteSize
		local pos, sz = popup.AbsolutePosition, popup.AbsoluteSize
		local dx, dy = 0, 0
		if pos.X + sz.X > vp.X then dx = vp.X - (pos.X + sz.X) end
		if pos.X < 0 then dx = -pos.X end
		if pos.Y + sz.Y > vp.Y then dy = vp.Y - (pos.Y + sz.Y) end
		if pos.Y < 0 then dy = -pos.Y end
		if dx ~= 0 or dy ~= 0 then
			popup.Position = UDim2.new(0, popup.Position.X.Offset + dx, 0, popup.Position.Y.Offset + dy)
		end
	end
	local function show()
		if win._activeGearClose and win._activeGearClose ~= close then win._activeGearClose() end
		if not popup then
			local w = opts.Width or 220
			popup = make("CanvasGroup", {
				BackgroundColor3 = T.Bg, GroupTransparency = 1, Visible = false, ZIndex = 1000,
				Size = UDim2.fromOffset(w, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = win.Gui,
			})
			corner(popup, "card")
			stroke(popup, T.Stroke, 1, 0.3)
			local wrap = make("Frame", {
				BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = popup,
			})
			pad(wrap, 10, 10, 10, 10)
			local col = make("Frame", {
				BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = wrap,
			})
			vlist(col, 6)
			popSection = setmetatable(
				{ Window = win, Tab = { Name = "Gear" }, Name = opts.Name or "Gear", _items = {}, _h = { 0, 0 }, _n = 0, _colL = col, _colR = col, Scroll = nil },
				Section
			)
			function popSection:_place(item) item.Frame.Parent = self._colL end
			function popSection:_arrange() end
		end
		if not built then
			built = true
			CTX = win
			buildFn(popSection)
		end
		local pos, sz = gear.AbsolutePosition, gear.AbsoluteSize
		popup.Position = UDim2.fromOffset(pos.X + sz.X - (opts.Width or 220), pos.Y + sz.Y + 6)
		popup.Visible = true
		open = true
		win._activeGearClose = close
		win._gearCatcher.Visible = true
		tween(popup, 0.18, { GroupTransparency = 0 })
		task.delay(0.03, clampToScreen)
	end
	gear.Activated:Connect(function()
		if open then close() else show() end
	end)
	win._gearCatcher.Activated:Connect(function()
		if win._activeGearClose then win._activeGearClose() end
	end)

	return { Icon = gi, Button = gear, Close = close }
end

function Window:GetFlag(flag) return self.Flags[flag] end

function Window:Destroy()
	self._mascotToken += 1
	for _, c in ipairs(self._conns) do c:Disconnect() end
	self.Gui:Destroy()
end

--[[
	Mochi.CreateWindow({
		Title = "Mochi",
		Theme = "Pink",           -- любая из Mochi.ThemeNames
		Accent = nil, Accent2 = nil,  -- свои цвета поверх темы (Accent2 = второй цвет для двухцветных)
		Style = "Soft",           -- "Soft" | "Sharp" | { любой набор параметров, см. Mochi.Styles }
		SidebarOpen = nil,        -- nil = авто (телефон: свёрнута, ПК: раскрыта) | true | false
		-- в Style можно задать: SidebarMode = "Auto"|"Overlay"|"Slide"|"Push", SliderStyle = "Knob"|"Bar", ToggleStyle = "Switch"|"Checkbox"
		Logo = nil,               -- nil = встроенный SVG | "<svg ...>" | "rbxassetid://123" | 123 | "iVBORw0..." (PNG/GIF base64) | { Base64 = "..." }
		Mascot = "rbxassetid://123",  -- см. Window:SetMascot (asset, base64 PNG/GIF, кадры, спрайтшит)
		MascotSize = Vector2.new(110, 110),
		MascotAlign = "Left",     -- "Left" | "Center" | "Right"
		Size = Vector2.new(600, 600),   -- максимальный размер окна
		Square = true,            -- окно всегда квадратное (false = прямоугольное)
		Scale = 1,                -- масштаб всего интерфейса
		ToggleKey = Enum.KeyCode.RightShift,
		MobileButton = true,      -- плавающая кнопка открытия (на телефоне всегда; на ПК появляется, когда окно закрыто)
		ConfigBackend = nil,      -- свой backend конфигов: { List, Read, Write, Delete, GetAuto, SetAuto, Persistent }
		Open = true,
	})
]]
function Mochi.CreateWindow(a, b)
	local opts = (type(a) == "table" and a ~= Mochi) and a or b or {}
	local self = setmetatable({}, Window)
	CTX = self

	local themeSpec = opts.Theme
	if type(themeSpec) == "string" then
		self._themeName = themeSpec
		themeSpec = Mochi.Themes[themeSpec]
	end
	themeSpec = themeSpec or Mochi.Themes.Pink
	if not self._themeName and not opts.Theme then self._themeName = "Pink" end
	self.Theme = table.clone(themeSpec)

	local styleName = type(opts.Style) == "string" and opts.Style or "Soft"
	self.Style = table.clone(Mochi.Styles[styleName] or Mochi.Styles.Soft)
	self.Style.Radius = table.clone(self.Style.Radius or {})
	if type(opts.Style) == "table" then
		for k, v in pairs(opts.Style) do
			if k == "Radius" and type(v) == "table" then
				for kk, vv in pairs(v) do self.Style.Radius[kk] = vv end
			else
				self.Style[k] = v
			end
		end
	end

	self.Title = opts.Title or "Mochi"
	self.Accent = opts.Accent or themeSpec.Accent
	self.Accent2 = opts.Accent2 or opts.Accent or themeSpec.Accent2 or self.Accent
	self.Flags = {}
	self.MaxSize = opts.Size or Vector2.new(600, 600)
	self.Square = opts.Square ~= false
	self.MascotSize = opts.MascotSize or Vector2.new(110, 110)
	self.MascotAlign = opts.MascotAlign or "Left"
	self.LogoSpec = opts.Logo or Mochi.DefaultLogo
	self.ToggleKey = opts.ToggleKey or Enum.KeyCode.RightShift
	self._userScale = math.clamp(opts.Scale or 1, 0.5, 1.6)
	self._conns, self._accentFns, self._tabs, self._sections, self._logoSlots = {}, {}, {}, {}, {}
	self._corners, self._cardStrokes, self._refreshers, self._onConfigs = {}, {}, {}, {}
	self._panels = {}
	self._flagObjs, self._flagNames = {}, {}
	self._mascotToken = 0
	self._open = false
	self._oneCol = false
	self._fabEnabled = opts.MobileButton ~= false

	local folder = tostring(self.Title):gsub("[^%w_%-]", "_")
	self.ConfigBackend = opts.ConfigBackend or makeFileBackend(folder) or makeMemoryBackend(folder)

	local T = self.Theme
	local S = self.Style
	local player = Players.LocalPlayer

	self.Gui = make("ScreenGui", {
		Name = "Mochi_" .. self.Title, ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 100,
		Parent = player:WaitForChild("PlayerGui"),
	})

	self.Holder = make("Frame", {
		Name = "Holder", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(600, 600), BackgroundTransparency = 1, Visible = false, Parent = self.Gui,
	})
	self._scale = make("UIScale", { Scale = 0.92 * self._userScale, Parent = self.Holder })

	-- маскот: сидит ПОД окном (ZIndex 1) и выглядывает из-за верхнего края
	self.Mascot = make("ImageLabel", {
		Name = "Mascot", AnchorPoint = Vector2.new(0.5, 1), ZIndex = 1,
		ScaleType = Enum.ScaleType.Fit, Visible = false, Parent = self.Holder,
	})

	self.Body = make("CanvasGroup", {
		Name = "Body", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Bg, BackgroundTransparency = 0,
		GroupTransparency = 1, ZIndex = 2, Parent = self.Holder,
	})
	corner(self.Body, "window")
	local outlineFrame = make("Frame", {
		Name = "Outline", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Parent = self.Holder,
	})
	corner(outlineFrame, "window")
	self._outline = stroke(outlineFrame, T.Stroke, S.OutlineAccent and 1.5 or 1, 1)
	self:_bind(function(c)
		self._outline.Color = self.Style.OutlineAccent and c or self.Theme.Stroke
	end)

	-- контент (справа)
	self._content = make("Frame", {
		Name = "Content", Position = UDim2.new(0, 64, 0, 0), Size = UDim2.new(1, -64, 1, 0),
		BackgroundTransparency = 1, ZIndex = 1, Parent = self.Body,
	})
	make("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 0, 44), BackgroundColor3 = T.Stroke, Parent = self._content })
	self._pages = make("Frame", {
		Position = UDim2.new(0, 0, 0, 45), Size = UDim2.new(1, 0, 1, -45), BackgroundTransparency = 1, Parent = self._content,
	})

	-- кнопка закрытия окна
	local close = make("TextButton", {
		Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 0, BackgroundColor3 = T.Elem, ZIndex = 4, Parent = self._content,
	})
	corner(close, "close")
	local closeIcon = icon(close, Mochi.Icons.Close, 12)
	closeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	closeIcon.Position = UDim2.fromScale(0.5, 0.5)
	closeIcon.ImageColor3 = T.SubText
	close.MouseEnter:Connect(function()
		tween(close, 0.15, { BackgroundColor3 = self.Theme.ElemHover })
		tween(closeIcon, 0.15, { ImageColor3 = self.Theme.Text })
	end)
	close.MouseLeave:Connect(function()
		tween(close, 0.2, { BackgroundColor3 = self.Theme.Elem })
		tween(closeIcon, 0.2, { ImageColor3 = self.Theme.SubText })
	end)
	close.Activated:Connect(function() self:Toggle(false) end)

	-- затемнение под выехавшей панелью (телефон)
	self._scrim = make("Frame", {
		Name = "Scrim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1, Visible = false, ZIndex = 2, Parent = self.Body,
	})
	local scrimBtn = make("TextButton", { Text = "", Size = UDim2.fromScale(1, 1), Parent = self._scrim })
	scrimBtn.Activated:Connect(function() self:SetSidebar(false, true) end)

	-- левая панель
	self._sidebar = make("Frame", {
		Name = "Sidebar", Size = UDim2.new(0, 64, 1, 0), BackgroundColor3 = T.Side, ZIndex = 3, Parent = self.Body,
	})
	make("Frame", {
		Name = "Divider", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = T.Stroke, Parent = self._sidebar,
	})

	self._header = make("Frame", { Size = UDim2.new(1, 0, 0, 60), BackgroundTransparency = 1, Parent = self._sidebar })
	draggable(self, self._header)
	self._logo = self:_newLogo(self._header, S.LogoSize)
	self._logo.frame.AnchorPoint = Vector2.new(0.5, 0)
	self._logo.frame.Position = UDim2.new(0.5, 0, 0, 13)
	self._title = make("TextLabel", {
		Text = self.Title, Font = FONT_B, TextSize = 15, TextColor3 = T.Text,
		TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, -8, 0, 20),
		Position = UDim2.new(0, 4, 0, 13 + S.LogoSize + 4), Visible = false, Parent = self._sidebar,
	})
	self._title.Position = UDim2.new(0, 0, 0, 13 + S.LogoSize + 4)
	self._title.Size = UDim2.new(1, 0, 0, 20)

	self._tabList = make("ScrollingFrame", {
		Position = UDim2.new(0, 8, 0, 66), Size = UDim2.new(1, -16, 1, -124),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 0, Parent = self._sidebar,
	})
	vlist(self._tabList, 4)

	-- ник + аватар внизу слева
	local chip = make("Frame", {
		Position = UDim2.new(0, 8, 1, -52), Size = UDim2.new(1, -16, 0, 44), BackgroundColor3 = T.Elem, Parent = self._sidebar,
	})
	corner(chip, "chip")
	self._avatar = make("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.fromOffset(30, 30),
		BackgroundTransparency = 0, BackgroundColor3 = T.Track,
		Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150", Parent = chip,
	})
	corner(self._avatar, "avatar")
	self._nameA = make("TextLabel", {
		Text = player.DisplayName, Font = FONT_B, TextSize = 12, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, -52, 0, 16), Position = UDim2.new(0, 46, 0, 6),
		Visible = false, Parent = chip,
	})
	self._nameB = make("TextLabel", {
		Text = "@" .. player.Name, TextSize = 10, TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, -52, 0, 14), Position = UDim2.new(0, 46, 0, 22),
		Visible = false, Parent = chip,
	})

	-- стрелочка раскрытия панели
	self._arrow = make("TextButton", {
		Name = "SidebarArrow", Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 64, 0.5, 0),
		Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 0, BackgroundColor3 = T.Elem, ZIndex = 8, Parent = self.Body,
	})
	corner(self._arrow, "arrow")
	local arrowStroke = stroke(self._arrow, T.Stroke, 1, 0.2)
	self._arrowIcon = icon(self._arrow, Mochi.Icons.Chevron, 14)
	self._arrowIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	self._arrowIcon.Position = UDim2.fromScale(0.5, 0.5)
	self._arrowIcon.ImageColor3 = T.SubText
	self._arrowIcon.Rotation = 270
	self._arrow.MouseEnter:Connect(function()
		tween(self._arrow, 0.15, { BackgroundColor3 = self.Theme.ElemHover })
		tween(self._arrowIcon, 0.15, { ImageColor3 = self.Accent })
	end)
	self._arrow.MouseLeave:Connect(function()
		tween(self._arrow, 0.2, { BackgroundColor3 = self.Theme.Elem })
		tween(self._arrowIcon, 0.2, { ImageColor3 = self.Theme.SubText })
	end)
	self._arrow.Activated:Connect(function() self:ToggleSidebar() end)

	-- плавающая кнопка открытия (перетаскивается)
	local fab = make("TextButton", {
		Text = "", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(46, 46), BackgroundTransparency = 0, BackgroundColor3 = T.Bg,
		Visible = false, ZIndex = 10, Parent = self.Gui,
	})
	corner(fab, "fab")
	local fs = stroke(fab, self.Accent, 1.5)
	self:_bind(function(c) fs.Color = c end)
	local fl = self:_newLogo(fab, 28)
	fl.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	fl.frame.Position = UDim2.fromScale(0.5, 0.5)
	self._fab = fab
	local fdrag, fmoved, fstart, fpos = false, false, nil, nil
	fab.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			fdrag, fmoved, fstart, fpos = true, false, input.Position, fab.Position
		end
	end)
	self:_connect(UserInputService.InputChanged, function(input)
		if fdrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - fstart
			if d.Magnitude > 8 then fmoved = true end
			if fmoved then
				fab.Position = UDim2.new(fpos.X.Scale, fpos.X.Offset + d.X, fpos.Y.Scale, fpos.Y.Offset + d.Y)
			end
		end
	end)
	self:_connect(UserInputService.InputEnded, function(input)
		if fdrag and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			fdrag = false
		end
	end)
	fab.Activated:Connect(function()
		if not fmoved then self:Toggle() end
	end)

	self:_applyLogo()
	self:_applyLayout()
	if opts.SidebarOpen ~= nil then self:SetSidebar(opts.SidebarOpen, false) end
	self:SetMascot(opts.Mascot)

	self:_connect(self.Gui:GetPropertyChangedSignal("AbsoluteSize"), function() self:_applyLayout() end)
	self:_connect(UserInputService.InputBegan, function(input, gp)
		if not gp and self.ToggleKey and input.KeyCode == self.ToggleKey then self:Toggle() end
	end)

	if opts.Open ~= false then
		self:Toggle(true)
	else
		self._fab.Visible = self._fabEnabled
	end
	return self
end

return Mochi
