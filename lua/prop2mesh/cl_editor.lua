local string = string
local table = table
local math = math
local net = net


--[[

	uploader

]]
local filecache_data = {}
local filecache_keys = {}

local upstreams = {}

net.Receive("prop2mesh_upload_start", function(len)
	local eid = net.ReadUInt(16)
	for i = 1, net.ReadUInt(8) do
		local crc = net.ReadString()
		if filecache_keys[crc] and filecache_keys[crc].data then
			net.Start("prop2mesh_upload")
			net.WriteUInt(eid, 16)
			net.WriteString(crc)
			upstreams[crc] = net.WriteStream(filecache_keys[crc].data)
			net.SendToServer()
		end
	end
end)

local function upstreamProgress()
	local max = 0
	for crc, stream in pairs(upstreams) do
		local client = next(stream.clients)
		if client and stream.clients[client] then
			client = stream.clients[client]
			if client.finished then
				upstreams[crc] = nil
			else
				local progress = client.progress / stream.numchunks
				if max < progress then
					max = progress
				end
			end
		end
	end
	return max
end

local function formatOBJ(filestr)
	local vcount = 0
	local condensed = {}

	for line in string.gmatch(filestr, "(.-)\n") do
		local temp = string.Explode(" ", string.gsub(string.Trim(line), "%s+", " "))
		local head = table.remove(temp, 1)

		if head == "f" then
			local v1 = string.Explode("/", temp[1])
			local v2 = string.Explode("/", temp[2])
			for i  = 3, #temp do
				local v3 = string.Explode("/", temp[i])
				condensed[#condensed + 1] = string.format("f %d %d %d\n", v1[1], v2[1], v3[1])
				v2 = v3
			end
		else
			if head == "v" then
				local x = tonumber(temp[1])
				local y = tonumber(temp[2])
				local z = tonumber(temp[3])

				x = math.abs(x) < 1e-4 and 0 or x
				y = math.abs(y) < 1e-4 and 0 or y
				z = math.abs(z) < 1e-4 and 0 or z

				condensed[#condensed + 1] = string.format("v %s %s %s\n", x, y, z)
				vcount = vcount + 1
			end
		end

		if vcount > 63999 then return end
	end

	return table.concat(condensed)
end


--[[

	skin and panel overrides

]]
local theme = {}
theme.font = "prop2mesheditor"
surface.CreateFont(theme.font, { size = 15, weight = 400, font = "Roboto Mono" })

theme.colorText_add = Color(100, 200, 100)
theme.colorText_edit = Color(100, 100, 255)
theme.colorText_kill = Color(255, 100, 100)
theme.colorText_default = Color(100, 100, 100)
theme.colorMain = Color(75, 75, 75)
theme.colorTree = Color(245, 245, 245)

local TreeAddNode, NodeAddNode
function TreeAddNode(self, text, icon, font)
	local node = DTree.AddNode(self, string.lower(text), icon)
	node.Label:SetFont(font or theme.font)
	node.Label:SetTextColor(theme.colorText_default)
	node.AddNode = NodeAddNode
	return node
end
function NodeAddNode(self, text, icon, font)
	local node = DTree_Node.AddNode(self, string.lower(text), icon)
	node.Label:SetFont(font or theme.font)
	node.Label:SetTextColor(theme.colorText_default)
	node.AddNode = NodeAddNode
	return node
end


--[[

	editor components

]]
local function changetable(partnode, key, diff)
	if not partnode.mod then
		if partnode.set then
			partnode.set[key] = diff and partnode.new[key] or nil

			local color = next(partnode.set) and theme.colorText_edit
			partnode.Label:SetTextColor(color or theme.colorText_default)
			partnode.Icon:SetImageColor(color or color_white)
		end
		return
	end
	if diff then
		if not partnode.mod[partnode.num] then
			partnode.mod[partnode.num] = {}
		end
		partnode.mod[partnode.num][key] = partnode.new[key]
		local color = partnode.mod[partnode.num].kill and theme.colorText_kill or theme.colorText_edit
		partnode.Label:SetTextColor(color)
		partnode.Icon:SetImageColor(color)
	elseif partnode.mod[partnode.num] then
		partnode.mod[partnode.num][key] = nil
		if not next(partnode.mod[partnode.num]) then
			partnode.mod[partnode.num] = nil
			partnode.Label:SetTextColor(theme.colorText_default)
			partnode.Icon:SetImageColor(color_white)
		end
	end
end

local function callbackVector(partnode, name, text, key, i, val)
	if partnode.new[key][i] == val then
		return
	end

	partnode.new[key][i] = val

	if partnode.new[key][i] ~= partnode.old[key][i] then
		name.Label:SetTextColor((partnode.mod or partnode.set) and theme.colorText_edit or theme.colorText_add)
		text:SetTextColor((partnode.mod or partnode.set) and theme.colorText_edit or theme.colorText_add)

		changetable(partnode, key, true)
	else
		name.Label:SetTextColor(theme.colorText_default)
		text:SetTextColor(theme.colorText_default)

		changetable(partnode, key, partnode.new[key] ~= partnode.old[key])
	end
end

local function registerVector(partnode, name, key)
	local node = partnode:AddNode(name, "icon16/bullet_black.png"):AddNode("")
	node.ShowIcons = function() return false end
	node:SetDrawLines(false)

	local x = vgui.Create("DTextEntry", node)
	local y = vgui.Create("DTextEntry", node)
	local z = vgui.Create("DTextEntry", node)

	node.PerformLayout = function(self, w, h)
		DTree_Node.PerformLayout(self, w, h)

    	local spacing = 4
    	local cellWidth = math.ceil((w - 48) / 3) - spacing

	    x:SetPos(24, 0)
		x:SetSize(cellWidth, h)

	    y:SetPos(24 + cellWidth + spacing, 0)
	    y:SetSize(cellWidth, h)

	    z:SetPos(24 + (cellWidth + spacing) * 2, 0)
	    z:SetSize(cellWidth, h)
	end

	for i, v in ipairs({x, y, z}) do
		v:SetFont(theme.font)
		v:SetNumeric(true)
		v.OnValueChange = function(self, val)
			if not tonumber(val) then
				self:SetText(string.format("%.4f", partnode.new[key][i]))
				return
			end
			self:SetText(string.format("%.4f", val))
			callbackVector(partnode, node:GetParentNode(), self, key, i, val)
		end
		v:SetValue(partnode.new[key][i])
	end
end

local function callbackBoolean(partnode, name, key, val)
	if partnode.new[key] == val then
		return
	end

	partnode.new[key] = val

	if partnode.new[key] ~= partnode.old[key] then
		name:SetTextColor((partnode.mod or partnode.set) and theme.colorText_edit or theme.colorText_add)

		changetable(partnode, key, true)
	else
		name:SetTextColor(theme.colorText_default)

		changetable(partnode, key, false)
	end
end

local function registerBoolean(partnode, name, key)
	local node = partnode:AddNode("")
	node.ShowIcons = function() return false end

	local x = vgui.Create("DCheckBoxLabel", node)
	x:SetText(name)
	x:Dock(LEFT)
	x:DockMargin(24, 0, 4, 0)
	x.Label:SetDisabled(true)

	x.OnChange = function(self, val)
		callbackBoolean(partnode, self, key, val and 1 or 0)
	end

	x:SetValue(partnode.new[key] == 1)
	x:SetTextColor(theme.colorText_default)
	x:SetFont(theme.font)
end

local function registerFloat(partnode, name, key, min, max)
	local node = partnode:AddNode("")
	node.ShowIcons = function() return false end

	local x = vgui.Create("DCheckBoxLabel", node)
	x:Dock(LEFT)
	x:DockMargin(24, 0, 4, 0)
	x:SetText(name)
	x:SetFont(theme.font)
	x:SetTextColor(theme.colorText_default)

	local s = vgui.Create("DNumSlider", node)
	s.Scratch:SetVisible(false)
	s.Label:SetVisible(false)
	s:SetWide(128)
	s:DockMargin(24, 0, 4, 0)
	s:Dock(LEFT)
	s:SetMin(min)
	s:SetMax(max)
	s:SetDecimals(0)

	s.OnValueChanged = function(self, val)
		x:SetChecked(val > 0)
		callbackBoolean(partnode, x, key, math.Round(val))
	end

	x.OnChange = function(self, value)
		self:SetChecked(s:GetValue() > 0)
	end

	s:SetValue(partnode.new[key])
end


--[[

	menus

]]
local function installEditors(partnode)
	registerVector(partnode, "pos", "pos")
	registerVector(partnode, "ang", "ang")
	registerVector(partnode, "scale", "scale")
	registerBoolean(partnode, "render_inside", "vinside")

	if partnode.new.objd then
		registerBoolean(partnode, "render_invert", "vinvert")
		registerFloat(partnode, "render_smooth", "vsmooth", 0, 180)
	else
		registerBoolean(partnode, "render_flat", "vsmooth")
	end

	partnode:ExpandRecurse(true)
	partnode.edited = true
end

--[[
local function partcopy(from)
	local a = { pos = Vector(), ang = Angle(), scale = Vector(1,1,1), vinvert = 0, vinside = 0, vsmooth = 0 }
	local b = { pos = Vector(), ang = Angle(), scale = Vector(1,1,1), vinvert = 0, vinside = 0, vsmooth = 0 }
	for k, v in pairs(from) do
		if isnumber(v) or isstring(v) then
			a[k] = v
			b[k] = v
		elseif isvector(v) then
			a[k] = Vector(v)
			b[k] = Vector(v)
		elseif isangle(v) then
			a[k] = Angle(v)
			b[k] = Angle(v)
		end
	end
	return a, b
end
]]

local function partcopy(from)
	local a = { pos = {0, 0, 0}, ang = {0, 0, 0}, scale = {1, 1, 1}, vinvert = 0, vinside = 0, vsmooth = 0 }
	local b = { pos = {0, 0, 0}, ang = {0, 0, 0}, scale = {1, 1, 1}, vinvert = 0, vinside = 0, vsmooth = 0 }
	for k, v in pairs(from) do
		if isnumber(v) or isstring(v) then
			a[k] = v
			b[k] = v
		elseif isvector(v) then
			a[k] = {v.x, v.y, v.z}
			b[k] = {v.x, v.y, v.z}
		elseif isangle(v) then
			a[k] = {v.p, v.y, v.r}
			b[k] = {v.p, v.y, v.r}
		end
	end
	return a, b
end

local function partmenu(frame, partnode)
	local menu = DermaMenu()

	if not partnode.edited then
		menu:AddOption("edit part", function()
			installEditors(partnode)
		end):SetIcon("icon16/brick_edit.png")
	end

	menu:AddOption(partnode.new.kill and "undo remove part" or "remove part", function()
		partnode.new.kill = not partnode.new.kill
		changetable(partnode, "kill", partnode.new.kill)
		partnode:SetExpanded(false, true)
	end):SetIcon("icon16/brick_delete.png")

	menu:AddOption("cancel"):SetIcon("icon16/cancel.png")
	menu:Open()
end

local function objmenu(frame, objnode)
	local menu = DermaMenu()

	menu:AddOption("remove model", function()
		objnode:Remove()
		objnode = nil
	end):SetIcon("icon16/brick_delete.png")

	menu:AddOption("cancel"):SetIcon("icon16/cancel.png")
	menu:Open()
end

local function attach(pathnode)
	local filepath = pathnode.path
	local filestr = file.Read(pathnode.path)
	local filecrc = tostring(util.CRC(filestr))

	if not filecache_data[filecrc] then
		local valid, contents = pcall(formatOBJ, filestr)
		if not valid then
			chat.AddText(Color(255, 125, 125), "unexpected error!")
			return
		end
		if not contents then
			chat.AddText(Color(255, 125, 125), ".obj must have fewer than 64000 vertices!")
			return
		end
		local crc = tostring(util.CRC(contents))
		filecache_data[filecrc] = { crc = crc, data = util.Compress(contents) }
		filecache_keys[crc] = filecache_data[filecrc]
	end
	if not filecache_data[filecrc] then
		chat.AddText(Color(255, 125, 125), "unexpected error!")
		return
	end

	local filename = string.GetFileFromFilename(pathnode.path)
	local rootnode = pathnode:GetParentNode()
	local partnode = rootnode.list:AddNode(string.format("[new!] %s", filename), "icon16/brick.png")
	partnode.Label:SetTextColor(theme.colorText_add)
	partnode.Icon:SetImageColor(theme.colorText_add)

	partnode.menu = objmenu
	partnode.new, partnode.old = partcopy({ objn = filename, objd = filecache_data[filecrc].crc })
	rootnode.add[partnode] = true

	installEditors(partnode)

	partnode:ExpandTo(true)
end

local function filemenu(frame, pathnode)
	local menu = DermaMenu()

	menu:AddOption("attach model", function()
		attach(pathnode)
	end):SetIcon("icon16/brick_add.png")

	menu:AddOption("cancel"):SetIcon("icon16/cancel.png")
	menu:Open()
end

local function conmenu(frame, conroot)
end



--[[

	derma

]]
local PANEL = {}

function PANEL:CreateGhost()
	self.Ghost = ents.CreateClientside("base_anim")
	self.Ghost:SetMaterial("models/wireframe")
	self.Ghost:SetNoDraw(true)

	self.Ghost.Draw = function(ent)
		cam.IgnoreZ(true)
		ent:DrawModel()
		cam.IgnoreZ(false)
	end

	self.Ghost:Spawn()
end

function PANEL:Init()
	self:CreateGhost()

	self.updates = {}

	self.contree = vgui.Create("DTree", self)
	self.contree:Dock(FILL)
	self.contree.AddNode = TreeAddNode
	self.contree:SetClickOnDragHover(true)
	self.contree.DoRightClick = function(pnl, node)
		if node.menu then node.menu(self, node) end
	end
	self.contree.Paint = function(pnl, w, h)
		surface.SetDrawColor(theme.colorTree)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(0, 0, 0)
		surface.DrawOutlinedRect(0, 0, w, h)
	end
	self.contree:DockMargin(1, 1, 1, 1)

	self.confirm = vgui.Create("DButton", self)
	self.confirm:Dock(BOTTOM)
	self.confirm:DockMargin(0, 2, 0, 0)
	self.confirm:SetText("Confirm changes")
	self.confirm.DoClick = function()
		if not IsValid(self.Entity) then
			return false
		end

		local set = {}
		local add = {}
		local mod = {}

		for k, v in pairs(self.updates) do
			if next(v.set) then
				if not set[k] then
					set[k] = {}
				end
				for i, j in pairs(v.set) do
					set[k][i] = j
				end
				if not next(set[k]) then
					set[k] = nil
				end
			end
			if next(v.add) then
				if not add[k] then
					add[k] = {}
				end
				for i in pairs(v.add) do
					if IsValid(i) then
						add[k][#add[k] + 1] = i.new
					end
				end
				if not next(add[k]) then
					add[k] = nil
				end
			end
			if next(v.mod) then
				if not mod[k] then
					mod[k] = {}
				end
				for i, j in pairs(v.mod) do
					mod[k][i] = j.kill and { kill = true } or j
				end
			end
		end

		if next(set) or next(add) or next(mod) then
			net.Start("prop2mesh_upload_start")
			net.WriteUInt(self.Entity:EntIndex(), 16)
			for k, v in ipairs({set, add, mod}) do
				if next(v) then
					net.WriteBool(true)
					net.WriteTable(v)
				else
					net.WriteBool(false)
				end
			end
			net.SendToServer()
		end
	end
	self.confirm:DockMargin(1, 1, 1, 1)

	self.progress = vgui.Create("DPanel", self)
	self.progress:Dock(BOTTOM)
	self.progress:DockMargin(1, 1, 1, 1)
	self.progress:SetTall(16)
	self.progress.Paint = function(pnl, w, h)
		surface.SetDrawColor(theme.colorTree)
		surface.DrawRect(0, 0, w, h)

		if pnl.frac then
			surface.SetDrawColor(0, 255, 0)
			surface.DrawRect(0, 0, pnl.frac*w, h)

			if pnl.text then
				draw.SimpleText(pnl.text, theme.font, w*0.5, h*0.5, theme.colorText_default, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end

		surface.SetDrawColor(0, 0, 0)
		surface.DrawOutlinedRect(0, 0, w, h)
	end
end

function PANEL:Paint(w, h)
	surface.SetDrawColor(theme.colorMain)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(0, 0, 0)
	surface.DrawOutlinedRect(0, 0, w, h)
end

function PANEL:OnRemove()
	if IsValid(self.Entity) then
		self.Entity:RemoveCallOnRemove("prop2mesh_editor_close")
		self.Entity.prop2mesh_triggereditor = nil
	end
	if IsValid(self.Ghost) then
		self.Ghost:Remove()
	end
end

function PANEL:Think()
	if not IsValid(self.Entity) then
		return
	end

	if self.Entity.prop2mesh_triggereditor then
		self.Entity.prop2mesh_triggereditor = nil
		self:RemakeTree()
		return
	end

	if self.Entity:GetNetworkedBool("uploading", false) then
		if not self.contree:GetDisabled() or not self.disable then
			self.contree:SetDisabled(true)
			self.confirm:SetDisabled(true)
			self.disable = true
		end
		self.progress.frac = upstreamProgress()
		self.progress.text = "uploading..."
	else
		if self.contree:GetDisabled() or self.disable then
			if self.Entity:GetAllDataReady() then
				self.contree:SetDisabled(false)
				self.confirm:SetDisabled(false)
				self.disable = nil
				self:RemakeTree()
				self.progress.frac = nil
			else
				local frac = self.Entity:GetDownloadProgress()

				self.progress.frac = frac or 1
				self.progress.text = frac and "downloading..." or "building mesh..."
			end
		end
	end

end

local matrix = Matrix()
local function onPartHover(label)
	local self = prop2mesh.editor
	if not self then
		return
	end

	local partnode = label:GetParent()
	if self.contree:GetSelectedItem() ~= partnode then
		self.contree:SetSelectedItem(partnode)

		if partnode.new and (partnode.new.holo or partnode.new.prop) then
			self.Ghost:SetNoDraw(false)
			self.Ghost:SetModel(partnode.new.holo or partnode.new.prop)

			local scale = partnode:GetParentNode().conscale or Vector(1,1,1)

			local pos, ang = LocalToWorld(Vector(unpack(partnode.new.pos))*scale, Angle(unpack(partnode.new.ang)), self.Entity:GetPos(), self.Entity:GetAngles())

			self.Ghost:SetParent(self.Entity)
			self.Ghost:SetPos(pos)
			self.Ghost:SetAngles(ang)

			if partnode.new.scale then
				matrix:SetScale(Vector(unpack(partnode.new.scale))*scale)
				self.Ghost:EnableMatrix("RenderMultiply", matrix)
			else
				self.GHost:DisableMatrix("RenderMultiply")
			end
		else
			self.Ghost:SetNoDraw(true)
		end

		label:InvalidateLayout(true)
	end
end

function PANEL:RemakeTree()
	self.contree:Clear()
	self.updates = {}

	local files, filenodes = {}, {}
	for k, v in ipairs(file.Find("p2m/*.txt", "DATA")) do table.insert(files, v) end
	for k, v in ipairs(file.Find("p2m/*.obj", "DATA")) do table.insert(files, v) end

	for i = 1, #self.Entity.prop2mesh_controllers do
		self.updates[i] = { mod = {}, add = {}, set = {} }

		local condata = prop2mesh.getMeshData(self.Entity.prop2mesh_controllers[i].crc, true) or {}
		local conroot = self.contree:AddNode(string.format("controller %d [%d]", i, #condata), "icon16/image.png")

		conroot.num = i
		conroot.menu = conmenu

		local setroot = conroot:AddNode("settings", "icon16/cog.png")

		setroot.set = self.updates[i].set

		local setscale = self.Entity.prop2mesh_controllers[i].scale
		setroot.old = { uvs = self.Entity.prop2mesh_controllers[i].uvs, scale = {setscale.x,setscale.y,setscale.z} }
		setroot.new = { uvs = self.Entity.prop2mesh_controllers[i].uvs, scale = {setscale.x,setscale.y,setscale.z} }

		registerVector(setroot, "mesh scale", "scale")
		registerFloat(setroot, "texture size", "uvs", 0, 512)

		setroot:ExpandRecurse(true)

		local objroot = conroot:AddNode(".obj", "icon16/pictures.png")
		local objfile = objroot:AddNode("files", "icon16/bullet_disk.png")
		local objlist = objroot:AddNode("attachments", "icon16/bullet_picture.png")
		local mdllist = conroot:AddNode(".mdl", "icon16/images.png")

		filenodes[#filenodes + 1] = objfile
		objfile.list = objlist
		objfile.add = self.updates[i].add

		objlist.conscale = setscale
		mdllist.conscale = setscale

		for k, v in ipairs(condata) do
			local root = v.objd and objlist or mdllist
			local part = root:AddNode(string.format("[%d] %s", k, string.GetFileFromFilename(v.objn or v.objd or v.prop or v.holo)))
			part:SetIcon("icon16/brick.png")

			part.Label.OnCursorEntered = onPartHover
			part.menu = partmenu
			part.new, part.old = partcopy(v)
			part.mod = self.updates[i].mod
			part.num = k
		end
	end

	for k, v in SortedPairs(files) do
		local path = string.format("p2m/%s", v)
		for _, filenode in pairs(filenodes) do
			local pathnode = filenode:AddNode(path, "icon16/page_white_text.png")
			pathnode.menu = filemenu
			pathnode.path = path
		end
	end
end

vgui.Register("prop2mesh_editor", PANEL, "DFrame")

