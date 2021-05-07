local string = string
local table = table
local math = math
local net = net

file.CreateDir("p2m")


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
			upstreams[crc] = prop2mesh.WriteStream(filecache_keys[crc].data)
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

local function exportOBJ(meshparts)
	if not meshparts then
		return
	end

	local concat  = table.concat
	local format  = string.format

	local p_verts = "v %f %f %f\n"
	local p_norms = "vn %f %f %f\n"
	local p_uvws  = "vt %f %f\n"
	local p_faces = "f %d/%d/%d %d/%d/%d %d/%d/%d\n"
	local p_parts = "#PART NUMBER %d\n"

	local function push(tbl, pattern, ...)
		tbl[#tbl + 1] = format(pattern, ...)
	end

	local t_output = {}
	local vnum = 1

	for i = 2, #meshparts do
		local part = meshparts[i]

		local s_verts = {}
		local s_norms = {}
		local s_uvws  = {}
		local s_faces = {}

		for j = 1, #part, 3 do
			local v1 = part[j + 0]
			local v2 = part[j + 1]
			local v3 = part[j + 2]

			push(s_verts, p_verts, v1.pos.x, v1.pos.y, v1.pos.z)
			push(s_verts, p_verts, v2.pos.x, v2.pos.y, v2.pos.z)
			push(s_verts, p_verts, v3.pos.x, v3.pos.y, v3.pos.z)

			push(s_norms, p_norms, v1.normal.x, v1.normal.y, v1.normal.z)
			push(s_norms, p_norms, v2.normal.x, v2.normal.y, v2.normal.z)
			push(s_norms, p_norms, v3.normal.x, v3.normal.y, v3.normal.z)

			push(s_uvws, p_uvws, v1.u, v1.v)
			push(s_uvws, p_uvws, v2.u, v2.v)
			push(s_uvws, p_uvws, v3.u, v3.v)

			push(s_faces, p_faces, vnum, vnum, vnum, vnum + 2, vnum + 2, vnum + 2, vnum + 1, vnum + 1, vnum + 1)
			vnum = vnum + 3
		end

		t_output[#t_output + 1] = concat({
			format("\no model %d\n", i - 1),
			concat(s_verts),
			concat(s_norms),
			concat(s_uvws),
			concat(s_faces)
		})
	end

	return concat(t_output)
end

local function formatE2(conroot)
	local format = string.format
	local concat = table.concat

	local header = {}
	header[#header + 1] = "#---- UNCOMMENT IF NECESSARY\n#---- ONLY NEEDED ONCE PER ENTITY\n"
	header[#header + 1] = "#[\nBase = entity()\nP2M = p2mCreate( put count here, Base:pos(), Base:angles())\nP2M:p2mSetParent(Base)\n]#\n\n"
	header[#header + 1] = "#---- UNCOMMENT AND PUT AT END OF CODE\n#P2M:p2mBuild()\n\n"

	header[#header + 1] = format("#---- CONTROLLER %d\nlocal Index = %d\n", conroot.num, conroot.num)
	header[#header + 1] = format("P2M:p2mSetUV(Index, %d)", conroot.info.uvs)
	header[#header + 1] = format("P2M:p2mSetScale(Index, vec(%g, %g, %g))", conroot.info.scale.x, conroot.info.scale.y, conroot.info.scale.z)
	header[#header + 1] = format("P2M:p2mSetColor(Index, vec4(%d, %d, %d, %d))", conroot.info.col.r, conroot.info.col.g, conroot.info.col.b, conroot.info.col.a)
	header[#header + 1] = format("P2M:p2mSetMaterial(Index, \"%s\")\n\n", conroot.info.mat)

	local specialk = {
		clips = true, vsmooth = true, vinside = true, bodygroup = true, submodels = true
	}

	local body = {}
	for k, v in ipairs(prop2mesh.getMeshData(conroot.info.crc, true)) do
		if not v.prop and not v.holo then
			goto CONTINUE
		end

		local special
		for i, j in pairs(v) do
			if specialk[i] then
				special = true
				break
			end
		end

		if special then
			local push = {}

			push[#push + 1] = format("    \"model\" = \"%s\"", v.prop or v.holo)
			push[#push + 1] = format("    \"pos\" = vec(%g, %g, %g)", v.pos.x, v.pos.y, v.pos.z)
			push[#push + 1] = format("    \"ang\" = ang(%g, %g, %g)", v.ang.p, v.ang.y, v.ang.r)

			if v.scale then
				push[#push + 1] = format("    \"scale\" = vec(%g, %g, %g)", v.scale.x, v.scale.y, v.scale.z)
			end
			if v.vsmooth then
				push[#push + 1] = "    \"flat\" = 1"
			end
			if v.vinside then
				push[#push + 1] = "    \"inside\" = 1"
			end
			if v.bodygroup then
				push[#push + 1] = format("    \"bodygroup\" = %d", v.bodygroup)
			end
			if v.submodels then
				push[#push + 1] = format("    \"submodels\" = array(%s)", concat(table.GetKeys(v.submodels), ","))
			end
			if v.clips then
				local clips = {}
				for i, clip in ipairs(v.clips) do
					local pos = clip.n * clip.d
					clips[#clips + 1] = format("vec(%g, %g, %g), vec(%g, %g, %g)", pos.x, pos.y, pos.z, clip.n.x, clip.n.y, clip.n.z)
				end
				push[#push + 1] = format("    \"clips\" = array(\n        %s\n    )", concat(clips, ",\n        "))
			end

			body[#body + 1] = format("P2M:p2mPushModel(Index, table(\n%s\n))", concat(push, ",\n"))
		else
			if v.scale then
				body[#body + 1] = format("P2M:p2mPushModel(Index, \"%s\", vec(%g, %g, %g), ang(%g, %g, %g), vec(%g, %g, %g))",
					v.prop or v.holo, v.pos.x, v.pos.y, v.pos.z, v.ang.p, v.ang.y, v.ang.r, v.scale.x, v.scale.y, v.scale.z)
			else
				body[#body + 1] = format("P2M:p2mPushModel(Index, \"%s\", vec(%g, %g, %g), ang(%g, %g, %g))",
					v.prop or v.holo, v.pos.x, v.pos.y, v.pos.z, v.ang.p, v.ang.y, v.ang.r)
			end
		end

		::CONTINUE::
	end

	return concat({ concat(header, "\n"), concat(body, "\n") })
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
theme.colorText_default = Color(75, 75, 75)
theme.colorMain = Color(75, 75, 75)
theme.colorTree = Color(245, 245, 245)

local wireframe = Material("models/wireframe")

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

local function HideIcons() return false end


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
	if not tonumber(val) or partnode.new[key][i] == val then
		return
	end

	partnode.new[key][i] = tonumber(val)

	if partnode.new[key][i] ~= partnode.old[key][i] then
		name.Label:SetTextColor((partnode.mod or partnode.set) and theme.colorText_edit or theme.colorText_add)
		text:SetTextColor((partnode.mod or partnode.set) and theme.colorText_edit or theme.colorText_add)

		changetable(partnode, key, true)
	else
		name.Label:SetTextColor(theme.colorText_default)
		text:SetTextColor(theme.colorText_default)

		local diff = false
		for j = 1, 3 do
			if partnode.new[key][j] ~= partnode.old[key][j] then
				diff = true
				break
			end
		end

		changetable(partnode, key, diff)
	end
end

local function registerVector(partnode, name, key)
	local node = partnode:AddNode(name, "icon16/bullet_black.png"):AddNode("")
	node.ShowIcons = HideIcons
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
	node.ShowIcons = HideIcons

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
	node.ShowIcons = HideIcons

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

local function registerSubmodels(partnode)
	if partnode.new.objd or (not partnode.new.prop and not partnode.new.holo) then
		return
	end

	local submeshes = util.GetModelMeshes(partnode.new.prop or partnode.new.holo, 0, partnode.new.bodygroup or 0)
	if not submeshes then
		return
	end

	local new = partnode.new.submodels
	local old = partnode.old.submodels

	local node = partnode:AddNode("sub-models", "icon16/bullet_black.png")

	for i = 1, #submeshes do
		local subnode = node:AddNode("")
		subnode.ShowIcons = HideIcons
		subnode:SetDrawLines(false)

		local x = vgui.Create("DCheckBoxLabel", subnode)
		x:Dock(LEFT)
		x:DockMargin(24, 0, 4, 0)
		x.Label:SetDisabled(true)

		if new[i] == nil then new[i] = 0 end
		if old[i] == nil then old[i] = 0 end

		x.OnChange = function(self, val)
			if new[i] == val then
				return
			end

			new[i] = val and 1 or 0

			if new[i] ~= old[i] then
				x:SetTextColor((partnode.mod or partnode.set) and theme.colorText_edit or theme.colorText_add)
				changetable(partnode, "submodels", true)
			else
				x:SetTextColor(theme.colorText_default)

				local diff = false
				for k, v in pairs(new) do
					if old[k] ~= v then
						diff = true
						break
					end
				end
				changetable(partnode, "submodels", diff)
			end
			x:SetText(string.format("part %d will be %s", i, val and "ignored" or "generated"))
		end

		x:SetValue(new[i] == 1)
		x:SetToolTip(string.format("tris: %d\nmat: %s", #submeshes[i].triangles, submeshes[i].material))
		x:SetTextColor(theme.colorText_default)
		x:SetFont(theme.font)
	end
end


--[[

	menus

]]
local function installEditors(partnode)
	registerSubmodels(partnode)
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

local function copyclips(clips)
	local ret = {}
	for k, clip in ipairs(clips) do
		ret[k] = {d = clip.d, n = {clip.n.x, clip.n.y, clip.n.z}}
	end
	return ret
end

local function partcopy(from)
	local a = { pos = {0, 0, 0}, ang = {0, 0, 0}, scale = {1, 1, 1}, vinvert = 0, vinside = 0, vsmooth = 0, submodels = {}, clips = {} }
	local b = { pos = {0, 0, 0}, ang = {0, 0, 0}, scale = {1, 1, 1}, vinvert = 0, vinside = 0, vsmooth = 0, submodels = {}, clips = {} }
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
		else
			if k == "submodels" then
				a[k] = table.Copy(v)
				b[k] = table.Copy(v)
			elseif k == "clips" then
				a[k] = copyclips(v)
				b[k] = copyclips(v)
			end
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
	local menu = DermaMenu()

	menu:AddOption("export as .obj", function()
		local pnl = Derma_StringRequest("", string.format("Exporting and saving controller %d as:", conroot.num), "default.txt", function(text)
			local filedata = exportOBJ(prop2mesh.getMeshDirect(conroot.info.crc, conroot.info.uvs))
			if filedata then
				local filename = string.lower(string.StripExtension(string.GetFileFromFilename(text)))
				file.Write(string.format("p2m/%s.txt", filename), filedata)
			end
		end)

		pnl.Paint = function(_, w, h)
			surface.SetDrawColor(theme.colorMain)
			surface.DrawRect(0, 24, w, h - 24)
			surface.SetDrawColor(0, 0, 0)
			surface.DrawOutlinedRect(0, 24, w, h - 24)
		end
	end):SetIcon("icon16/car.png")

	if E2Lib and openE2Editor then
		local opt = menu:AddOption("export to expression2", function()
			openE2Editor()
			if wire_expression2_editor then
				local e2code = formatE2(conroot)

				wire_expression2_editor:NewTab()
				wire_expression2_editor:SetCode(e2code)
				spawnmenu.ActivateTool("wire_expression2")
			end
		end)
		opt:SetIcon("icon16/cog.png")
		opt.m_Image:SetImageColor(Color(255, 125, 125))
	end

	menu:AddOption("cancel"):SetIcon("icon16/cancel.png")
	menu:Open()
end


--[[

	derma

]]
local PANEL = {}

local function setEntityActual(self, ent)
	self.Entity = ent
	self.Entity:CallOnRemove("prop2mesh_editor_close", function()
		self:Remove()
	end)
	self:SetTitle(tostring(self.Entity))
	self:RemakeTree()
end

function PANEL:RequestSetEntity(ent)
	if IsValid(self.Entity) then
		local edited
		for index, updates in pairs(self.updates) do
			for k, v in pairs(updates) do
				if next(v) then
					edited = true
					break
				end
			end
		end
		if edited then
			local pnl = Derma_Query("Unconfirmed changes, are you sure?", "", "Yes", function()
				self.Entity:RemoveCallOnRemove("prop2mesh_editor_close")
				setEntityActual(self, ent)
			end, "No")
			pnl.Paint = function(_, w, h)
				surface.SetDrawColor(theme.colorMain)
				surface.DrawRect(0, 24, w, h - 24)
				surface.SetDrawColor(0, 0, 0)
				surface.DrawOutlinedRect(0, 24, w, h - 24)
			end
			return
		else
			self.Entity:RemoveCallOnRemove("prop2mesh_editor_close")
		end
	end
	setEntityActual(self, ent)
end

function PANEL:CreateGhost()
	self.Ghost = ents.CreateClientside("base_anim")
	self.Ghost:SetNoDraw(true)
	self.Ghost.Draw = function(ent)
		local clips, prev = ent.clips, nil
		if clips then
			prev = render.EnableClipping(true)

			local pos = ent:GetPos()
			local ang = ent:GetAngles()

			for i = 1, #clips do
				local clip = clips[i]
				local norm = Vector(unpack(clip.n))
				norm:Rotate(ang)

				render.PushCustomClipPlane(norm, norm:Dot(pos + norm * clip.d))
			end
		end

		render.ModelMaterialOverride(wireframe)
		cam.IgnoreZ(true)
		ent:DrawModel()
		cam.IgnoreZ(false)
		render.ModelMaterialOverride(nil)

		if clips then
			for _ = 1, #clips do
				render.PopCustomClipPlane()
			end
			render.EnableClipping(prev)
		end
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

	if self.Entity:GetNetworkedBool("uploading", false) then
		if not self.disable or not self.contree:GetDisabled() then
			self.disable = true
			self.contree:SetDisabled(true)
			self.confirm:SetDisabled(true)
		end
		self.progress.frac = upstreamProgress()
		self.progress.text = "uploading data..."
	else
		if self.disable or self.contree:GetDisabled() then
			local ready, status = self.Entity:GetAllDataReady()
			if ready then
				self.progress.frac = nil
				self.disable = nil
				self.contree:SetDisabled(false)
				self.confirm:SetDisabled(false)
				self:RemakeTree()
			elseif status == 1 then -- no data
				self.progress.frac = 1
				self.progress.text = "downloading data..."
			elseif status == 2 then -- data but no meshes
				self.progress.frac = 1
				self.progress.text = "generating mesh..."
			end
		elseif self.Entity.prop2mesh_triggereditor then
			self.Entity.prop2mesh_triggereditor = nil
			self:RemakeTree()
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
			if self.Ghost.lastSubmodels then
				for k in pairs(self.Ghost.lastSubmodels) do
					self.Ghost:SetSubMaterial(k - 1, nil)
				end
				self.Ghost.lastSubmodels = nil
			end

			self.Ghost:SetNoDraw(false)
			self.Ghost:SetModel(partnode.new.holo or partnode.new.prop)

			local scale = partnode:GetParentNode().conscale or Vector(1,1,1)

			local pos, ang = LocalToWorld(Vector(unpack(partnode.new.pos))*scale, Angle(unpack(partnode.new.ang)), self.Entity:GetPos(), self.Entity:GetAngles())

			self.Ghost:SetParent(self.Entity)
			self.Ghost:SetPos(pos)
			self.Ghost:SetAngles(ang)

			if partnode.new.submodels then
				self.Ghost.lastSubmodels = {}
				for k, v in pairs(partnode.new.submodels) do
					if v == 1 then
						self.Ghost.lastSubmodels[k] = true
						self.Ghost:SetSubMaterial(k - 1, "Models/effects/vol_light001")
					end
				end
			end

			if partnode.new.clips and #partnode.new.clips > 0 then
				self.Ghost.clips = partnode.new.clips
			else
				self.Ghost.clips = nil
			end

			if partnode.new.scale then
				matrix:SetScale(Vector(unpack(partnode.new.scale))*scale)
				self.Ghost:EnableMatrix("RenderMultiply", matrix)
			else
				self.Ghost:DisableMatrix("RenderMultiply")
			end
		else
			self.Ghost:SetNoDraw(true)
		end

		label:InvalidateLayout(true)
	end
end

function PANEL:RemakeTree()
	if IsValid(self.Ghost) then
		self.Ghost:SetNoDraw(true)
	end

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
		conroot.info = self.Entity.prop2mesh_controllers[i]
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

