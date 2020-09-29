-- -----------------------------------------------------------------------------
local string = string
local render = render

local string_explode = string.Explode
local string_format = string.format
local string_gsub = string.gsub
local string_trim = string.Trim
local table_remove = table.remove
local math_abs = math.abs
local tonumber = tonumber
local next = next


-- -----------------------------------------------------------------------------
local color_deleted = Color(200, 85, 85)
local color_changed = Color(85, 200, 85)

local icon_file = "icon16/page_white_text.png"
local icon_cancel = "icon16/cancel.png"
local icon_part_default = "icon16/brick.png"
local icon_part_changed = "icon16/brick_add.png"
local icon_part_deleted = "icon16/brick_delete.png"


-- -----------------------------------------------------------------------------
local csent

local editors   = {}
local mcol_hov  = { r = 200/255, g = 200/255, b = 200/255 }
local mcol_del  = { r = color_deleted.r/255, g = color_deleted.g/255, b = color_deleted.b/255 }
local mcol_chn  = { r = color_changed.r/255, g = color_changed.g/255, b = color_changed.b/255 }
local wireframe = Material("models/wireframe")

local scalem = Matrix()
local scalev = Vector(1, 1, 1)

local enable_clipping = CreateClientConVar("prop2mesh_editor_enableclipping", "1", true, false)

hook.Add("PostDrawOpaqueRenderables", "P2MDrawEditorGhosts", function()
	if next(editors) == nil then
		return
	end
	if not IsValid(csent) then
		csent = ClientsideModel("models/error.mdl")
		csent:SetNoDraw(true)
	end

	cam.IgnoreZ(true)
	render.ModelMaterialOverride(wireframe)
	render.SetColorModulation(1, 1, 1)

	local doClipping = enable_clipping:GetBool()

	for editor, partDataHover in pairs(editors) do
		for partID, partData in ipairs(editor.Data) do
			if next(editor.changes[partID]) == nil or not partData.mdl then
				continue
			end

			scalem:SetScale(partData.scale or scalev)

			csent:SetModel(partData.mdl)
			csent:SetPos(editor.Entity:LocalToWorld(partData.pos))
			csent:SetAngles(editor.Entity:LocalToWorldAngles(partData.ang))
			csent:EnableMatrix("RenderMultiply", scalem)
			csent:SetupBones()

			if editor.changes[partID].delete then
				render.SetColorModulation(mcol_del.r, mcol_del.g, mcol_del.b)
			else
				render.SetColorModulation(mcol_chn.r, mcol_chn.g, mcol_chn.b)
			end

			if doClipping and partData.clips then
				render.EnableClipping(true)
				for clipID, clipData in ipairs(partData.clips) do
					local normal = csent:LocalToWorld(clipData.n) - csent:GetPos()
					render.PushCustomClipPlane(normal, normal:Dot(csent:LocalToWorld(clipData.n * clipData.d)))
				end
			end

			csent:DrawModel()

			if doClipping and partData.clips then
				for clipID, clipData in ipairs(partData.clips) do
					render.PopCustomClipPlane()
				end
				render.EnableClipping(false)
			end
		end

		if partDataHover.mdl then
			scalem:SetScale(partDataHover.scale or scalev)

			csent:SetModel(partDataHover.mdl)
			csent:SetPos(editor.Entity:LocalToWorld(partDataHover.pos))
			csent:SetAngles(editor.Entity:LocalToWorldAngles(partDataHover.ang))
			csent:EnableMatrix("RenderMultiply", scalem)
			csent:SetupBones()

			render.SetColorModulation(mcol_hov.r, mcol_hov.g, mcol_hov.b)

			if doClipping and partDataHover.clips then
				render.EnableClipping(true)
				for clipID, clipData in ipairs(partDataHover.clips) do
					local normal = csent:LocalToWorld(clipData.n) - csent:GetPos()
					render.PushCustomClipPlane(normal, normal:Dot(csent:LocalToWorld(clipData.n * clipData.d)))
				end
			end

			csent:DrawModel()

			if doClipping and partDataHover.clips then
				for clipID, clipData in ipairs(partDataHover.clips) do
					render.PopCustomClipPlane()
				end
				render.EnableClipping(false)
			end
		end
	end

	cam.IgnoreZ(false)
	render.ModelMaterialOverride(nil)
	render.SetColorModulation(1, 1, 1)
end)


-- -----------------------------------------------------------------------------
local PANEL = {}


-- -----------------------------------------------------------------------------
function PANEL:Init()
	self.editor = vgui.Create("DTree", self)
	self.editor:Dock(FILL)
	self.editor.OnNodeSelected = function() self.editor:SetSelectedItem() end

	self.confirm = vgui.Create("DButton", self)
	self.confirm:Dock(BOTTOM)
	self.confirm:DockMargin(0, 2, 0, 0)
	self.confirm:SetText("Confirm changes")

	self.confirm.DoClick = function()
		if not IsValid(self.Entity) then
			return
		end

		local changes = { edits = {} }

		for k, v in pairs(self.changes) do
			if next(v) ~= nil then
				changes.edits[k] = v
			end
		end
		if next(changes.edits) == nil then
			changes.edits = nil
		end
		if next(self.additions) ~= nil then
			changes.additions = self.additions
		end
		if next(self.settings) ~= nil then
			changes.settings = self.settings
		end
		if next(changes) == nil then
			return
		end

		local data = util.Compress(util.TableToJSON(changes))
		local size = string.len(data)

		if size > 63000 then
			self:SetEntity(self.Entity)
			return
		end

		net.Start("NetP2M.MakeChanges")
		net.WriteEntity(self.Entity)
		net.WriteUInt(size, 32)
		net.WriteData(data, size)
		net.SendToServer()

		self:Close()
	end

	self.editor.Paint = function(pnl, w, h)
		surface.SetDrawColor(245, 245, 245)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(0, 0, 0)
		surface.DrawOutlinedRect(0, 0, w, h)
	end

	self.Paint = function(pnl, w, h)
		surface.SetDrawColor(55, 55, 60)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(85, 85, 90)
		surface.DrawRect(0, 0, w, 24)
		surface.SetDrawColor(0, 0, 0)
		surface.DrawOutlinedRect(0, 0, w, h)
	end
end

-- -----------------------------------------------------------------------------
function PANEL:OnClose()
	editors[self] = nil
	if IsValid(self.Entity) then
		self.Entity:RemoveCallOnRemove("RemoveP2MEditor")
		if self.ResetEntityColor then
			self.Entity:SetColor(self.ResetEntityColor)
			self.Entity:SetRenderMode(self.ResetEntityColor.a == 255 and RENDERMODE_NORMAL or RENDERMODE_TRANSALPHA)
		end
		self.Entity.MaterialName = nil
	end
end


-- -----------------------------------------------------------------------------
function PANEL:SetEntity(ent)
	if not IsValid(ent) or ent:GetClass() ~= "gmod_ent_p2m" then
		return
	end

	self.Entity = ent
	self:SetTitle(tostring(self.Entity))

	self.Entity:CallOnRemove("RemoveP2MEditor", function()
		self:Close()
	end)

	self.changes = {}
	self.additions = {}
	self.settings = {}

	local crc = self.Entity:GetCRC()
	local tbl = p2mlib.models[crc]

	if tbl then
		self.Data = util.JSONToTable(util.Decompress(tbl.data))
	else
		self.Data = {}
	end

	self:RebuildTree()
end


-- -----------------------------------------------------------------------------
local menuFunctions = {}

function PANEL:RebuildTree()
	self.editor:Clear()

	local settings = self.editor:AddNode("settings", "icon16/cog.png")
	self:PopulateSettings(settings)
	settings:SetExpanded(true)

	local parts = self.editor:AddNode("parts", "icon16/world.png")

	self.obj_root = parts:AddNode(".obj", "icon16/car.png")

	self.obj_file = self.obj_root:AddNode("data/p2m/*.txt", "icon16/bullet_disk.png")
	self:PopulateFiles()

	self.obj_data = self.obj_root:AddNode("attachments", "icon16/bullet_picture.png")
	self.mdl_data = parts:AddNode(".mdl", "icon16/bricks.png")
	if self.Data then
		self:PopulateData()
	end

	self.editor.DoRightClick = function(_, node)
		if menuFunctions[node.menu_type] then
			menuFunctions[node.menu_type](self, node)
		end
	end

	parts:SetExpanded(true)
end


-- -----------------------------------------------------------------------------
function PANEL:MakeColorPanel(rootnode)
	self.ResetEntityColor = self.Entity:GetColor()
	local node_color = rootnode:AddNode(string.format("color [%d, %d, %d, %d]", self.ResetEntityColor.r, self.ResetEntityColor.g, self.ResetEntityColor.b, self.ResetEntityColor.a), "icon16/color_wheel.png")

	node_color.DoRightClick = function()
		local dmenu = DermaMenu()
		dmenu:AddSpacer()
		dmenu:AddOption("Reset", function()
			node_color:SetText(string.format("color [%d, %d, %d, %d]", self.ResetEntityColor.r, self.ResetEntityColor.g, self.ResetEntityColor.b, self.ResetEntityColor.a))
			node_color.Label:SetTextColor(nil)
			self.Entity:SetColor(self.ResetEntityColor)
			self.Entity:SetRenderMode(self.ResetEntityColor.a == 255 and RENDERMODE_NORMAL or RENDERMODE_TRANSALPHA)
			self.settings.color = nil
		end):SetIcon(icon_part_deleted)
		dmenu:AddSpacer()
		dmenu:AddOption("Cancel"):SetIcon(icon_cancel)
		dmenu:Open()
	end

	node_color.DoClick = function()
		local panel_color = vgui.Create("DColorMixer", self)
		panel_color:SetSize(256, 256)
		panel_color.ValueChanged = function(_, value)
			node_color:SetText(string.format("color [%d, %d, %d, %d]", value.r, value.g, value.b, value.a))
			self.Entity:SetColor(value)
			self.Entity:SetRenderMode(value.a == 255 and RENDERMODE_NORMAL or RENDERMODE_TRANSALPHA)
			if value.r == self.ResetEntityColor.r and value.g == self.ResetEntityColor.g and value.b == self.ResetEntityColor.b and value.a == self.ResetEntityColor.a then
				self.settings.color = nil
				node_color.Label:SetTextColor(nil)
			else
				self.settings.color = value
				node_color.Label:SetTextColor(color_changed)
			end
		end
		panel_color:SetColor(self.Entity:GetColor())
		panel_color.Paint = function(_, w, h)
			surface.SetDrawColor(85, 85, 90)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(0, 0, 0)
			surface.DrawOutlinedRect(0, 0, w, h)
		end
		panel_color.OnClose = function()
			self.Entity:SetColor(panel_color:GetColor())
			self.Entity:SetRenderMode(panel_color:GetColor().a == 255 and RENDERMODE_NORMAL or RENDERMODE_TRANSALPHA)
		end

		local dmenu = DermaMenu()
		dmenu:AddPanel(panel_color)
		dmenu:SetPaintBackground(false)

		local px, py = self:GetPos()
		dmenu:Open(px - 256, py)
	end
end


-- -----------------------------------------------------------------------------
function PANEL:MakeMaterialPanel(rootnode)
	self.ResetEntityMaterial = self.Entity:GetMaterial()
	local node_matrl = rootnode:AddNode(string.format("material [%s]", self.ResetEntityMaterial), self.ResetEntityMaterial)

	node_matrl.DoRightClick = function()
		local dmenu = DermaMenu()
		dmenu:AddSpacer()
		dmenu:AddOption("Reset", function()
			node_matrl:SetIcon(self.ResetEntityMaterial)
			node_matrl:SetText(string.format("material [%s]", self.ResetEntityMaterial))
			node_matrl.Label:SetTextColor(nil)
			self.Entity.MaterialName = nil
			self.settings.material = nil
		end):SetIcon(icon_part_deleted)
		dmenu:AddSpacer()
		dmenu:AddOption("Cancel"):SetIcon(icon_cancel)
		dmenu:Open()
	end

	node_matrl.DoClick = function()
		local panel_matrl = vgui.Create("DPanel", self)
		panel_matrl:SetSize(256, self:GetTall())
		panel_matrl.Paint = function(_, w, h)
			surface.SetDrawColor(85, 85, 90)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(0, 0, 0)
			surface.DrawOutlinedRect(0, 0, w, h)
		end

		local dmenu = DermaMenu()
		dmenu:AddPanel(panel_matrl)
		dmenu:SetPaintBackground(false)

		local px, py = self:GetPos()
		dmenu:Open(px - 256, py)

		local scroll = vgui.Create("DScrollPanel", panel_matrl)
		scroll:Dock(FILL)

		local MatSelect = vgui.Create("MatSelect", scroll)
		MatSelect:Dock(FILL)
		MatSelect.Paint = function() end

		MatSelect:SetConVar("material_override")
		MatSelect:SetAutoHeight(true)
		MatSelect:SetItemWidth(0.25)
		MatSelect:SetItemHeight(0.25)

		for id, str in pairs(list.Get("OverrideMaterials")) do
			local label = id
			if isnumber(label) then label = str end
			MatSelect:AddMaterial(label, str)
		end
		scroll:AddItem(MatSelect)

		for _, mat in ipairs(MatSelect.Controls) do
			mat.DoClick = function(button)
				node_matrl:SetIcon(mat.Value)
				node_matrl:SetText(string.format("material [%s]", mat.Value))
				self.Entity.MaterialMeshes = Material(mat.Value)
				RunConsoleCommand(MatSelect:ConVar(), mat.Value)
				if mat.Value ~= self.ResetEntityMaterial then
					node_matrl.Label:SetTextColor(color_changed)
					self.settings.material = mat.Value
				else
					node_matrl.Label:SetTextColor(nil)
					self.settings.material = nil
				end
			end
			mat.DoRightClick = function() end
		end
	end
end


-- -----------------------------------------------------------------------------
function PANEL:PopulateSettings(rootnode)
	local tscale = rootnode:AddNode("texture scale", "icon16/bullet_wrench.png")
	local temp = tscale:AddNode("")
	temp.ShowIcons = function() return false end

	local component = vgui.Create("DNumSlider", temp)
	component.Scratch:SetVisible(false)
	component.Label:SetVisible(false)
	component:SetWide(256)
	component:DockMargin(24, 1, 4, 0)
	component:Dock(LEFT)
	component:SetMin(0)
	component:SetMax(512)
	component:SetDecimals(0)
	component:SetValue(self.Entity:GetNWInt("P2M_TSCALE"))

	component.OnValueChanged = function(_, value)
		if self.Entity:GetNWInt("P2M_TSCALE") == value then
			tscale.Label:SetTextColor()
			self.settings.P2M_TSCALE = nil
			return
		end
		tscale.Label:SetTextColor(color_changed)
		self.settings.P2M_TSCALE = value
	end

	tscale.DoRightClick = function()
		local dmenu = DermaMenu()
		dmenu:AddSpacer()
		dmenu:AddOption("Reset", function()
			component:SetValue(self.Entity:GetNWInt("P2M_TSCALE"))
		end):SetIcon(icon_part_deleted)
		dmenu:AddSpacer()
		dmenu:AddOption("Cancel"):SetIcon(icon_cancel)
		dmenu:Open()
	end

	local mscale = rootnode:AddNode("mesh scale", "icon16/bullet_wrench.png")
	local temp = mscale:AddNode("")
	temp.ShowIcons = function() return false end

	local component = vgui.Create("DNumSlider", temp)
	component.Scratch:SetVisible(false)
	component.Label:SetVisible(false)
	component:SetWide(256)
	component:DockMargin(24, 1, 4, 0)
	component:Dock(LEFT)
	component:SetMin(0.1)
	component:SetMax(1)
	component:SetValue(self.Entity:GetNWInt("P2M_MSCALE"))

	component.OnValueChanged = function(_, value)
		if self.Entity:GetNWInt("P2M_MSCALE") == value then
			mscale.Label:SetTextColor()
			self.settings.P2M_MSCALE = nil
			return
		end
		mscale.Label:SetTextColor(color_changed)
		self.settings.P2M_MSCALE = value
	end

	mscale.DoRightClick = function()
		local dmenu = DermaMenu()
		dmenu:AddSpacer()
		dmenu:AddOption("Reset", function()
			component:SetValue(self.Entity:GetNWInt("P2M_MSCALE"))
		end):SetIcon(icon_part_deleted)
		dmenu:AddSpacer()
		dmenu:AddOption("Cancel"):SetIcon(icon_cancel)
		dmenu:Open()
	end

	self:MakeColorPanel(rootnode)
	self:MakeMaterialPanel(rootnode)
end


-- -----------------------------------------------------------------------------
function PANEL:PopulateData()
	self.obj_data.subnodes = {}
	self.mdl_data.subnodes = {}

	for partID, partData in ipairs(self.Data) do
		if partData.obj then
			self:PopulateOBJ(partID, partData)
		elseif partData.mdl then
			self:PopulateMDL(partID, partData)
		end
	end

	self.obj_data:SetText(string_format(".obj [%d]", table.Count(self.obj_data.subnodes)))
	self.mdl_data:SetText(string_format(".mdl [%d]", table.Count(self.mdl_data.subnodes)))
end


-- -----------------------------------------------------------------------------
function PANEL:PopulateFiles()
	local files, folders = file.Find("p2m/*.txt", "DATA")
	for i = 1, #files do
		local node = self.obj_file:AddNode(string_format("p2m/%s", files[i]), icon_file)
		node.menu_type = "file"
	end
	local files, folders = file.Find("p2m/*.obj", "DATA")
	for i = 1, #files do
		local node = self.obj_file:AddNode(string_format("p2m/%s", files[i]), icon_file)
		node.menu_type = "file"
	end
end


-- -----------------------------------------------------------------------------
local flags = {
	{
		text  = "Render inside",
		data  = "inv",
		icons = { "icon16/camera.png", "icon16/camera_add.png", "icon16/camera_delete.png" },
		toggle = function(node, dValue, cValue)
			if cValue ~= nil then
				node.Label:SetTextColor(color_changed)
				node:SetIcon("icon16/bullet_green.png")
				node:SetText(string_format("render_inside = %s", cValue and "true" or "false"))
			else
				node.Label:SetTextColor()
				node:SetIcon("icon16/bullet_black.png")
				node:SetText(string_format("render_inside = %s", dValue and "true" or "false"))
			end
		end
	},
	{
		text  = "Flat shading",
		data  = "flat",
		icons = { "icon16/contrast.png", "icon16/contrast_high.png", "icon16/contrast_low.png" },
		toggle = function(node, dValue, cValue)
			if cValue ~= nil then
				node.Label:SetTextColor(color_changed)
				node:SetIcon("icon16/bullet_green.png")
				node:SetText(string_format("flat_shading = %s", cValue and "true" or "false"))
			else
				node.Label:SetTextColor()
				node:SetIcon("icon16/bullet_black.png")
				node:SetText(string_format("flat_shading = %s", dValue and "true" or "false"))
			end

		end
	}
}


-- -----------------------------------------------------------------------------
local function ToggleNodeColors(self, rootnode)
	if not rootnode.partID then
		return
	end
	if next(self.changes[rootnode.partID]) == nil then
		rootnode.Label:SetTextColor()
		rootnode:SetIcon(icon_part_default)
	else
		rootnode.Label:SetTextColor(color_changed)
		rootnode:SetIcon(icon_part_changed)
	end
end

local function BuildOBJNode(self, rootnode, partData)
	--
	local pos = rootnode:AddNode("local origin offset", "icon16/bullet_black.png")
	local temp = pos:AddNode("")
	temp.ShowIcons = function() return false end

	for i = 1, 3 do
		local component = vgui.Create("DTextEntry", temp)
		component:Dock(LEFT)
		component:DockMargin(i == 1 and 24 or 1, 1, 4, 0)
		component:SetWide(58)
		component:SetNumeric(true)
		component.OnValueChange = function(_, value)
			if partData.pos[i] == value then
				return
			end
			if rootnode.partID and self.changes[rootnode.partID] then
				if not self.changes[rootnode.partID].pos then
					self.changes[rootnode.partID].pos = Vector(partData.pos)
				end
				self.changes[rootnode.partID].pos[i] = value

				if partData.pos[1] == self.changes[rootnode.partID].pos[1] and
				   partData.pos[2] == self.changes[rootnode.partID].pos[2] and
				   partData.pos[3] == self.changes[rootnode.partID].pos[3] then
					pos.Label:SetTextColor(nil)
					self.changes[rootnode.partID].pos = nil
				else
					pos.Label:SetTextColor(color_changed)
				end
			else
				partData.pos[i] = value
			end
			ToggleNodeColors(self, rootnode)
		end
		component:SetValue(partData.pos[i])
	end

	--
	local ang = rootnode:AddNode("local angle offset", "icon16/bullet_black.png")
	local temp = ang:AddNode("")
	temp.ShowIcons = function() return false end

	for i = 1, 3 do
		local component = vgui.Create("DTextEntry", temp)
		component:Dock(LEFT)
		component:DockMargin(i == 1 and 24 or 1, 1, 4, 0)
		component:SetWide(58)
		component:SetNumeric(true)
		component.OnValueChange = function(_, value)
			if partData.ang[i] == value then
				return
			end
			if rootnode.partID and self.changes[rootnode.partID] then
				if not self.changes[rootnode.partID].ang then
					self.changes[rootnode.partID].ang = Angle(partData.ang)
				end
				self.changes[rootnode.partID].ang[i] = value

				if partData.ang[1] == self.changes[rootnode.partID].ang[1] and
				   partData.ang[2] == self.changes[rootnode.partID].ang[2] and
				   partData.ang[3] == self.changes[rootnode.partID].ang[3] then
					ang.Label:SetTextColor(nil)
					self.changes[rootnode.partID].ang = nil
				else
					ang.Label:SetTextColor(color_changed)
				end
			else
				partData.ang[i] = value
			end
			ToggleNodeColors(self, rootnode)
		end
		component:SetValue(partData.ang[i])
	end

	--
	local scale = rootnode:AddNode("scale", "icon16/bullet_black.png")
	local temp = scale:AddNode("")
	temp.ShowIcons = function() return false end

	for i = 1, 3 do
		local component = vgui.Create("DTextEntry", temp)
		component:Dock(LEFT)
		component:DockMargin(i == 1 and 24 or 1, 1, 4, 0)
		component:SetWide(58)
		component:SetNumeric(true)
		component.OnValueChange = function(_, value)
			if partData.scale[i] == value then
				return
			end
			if rootnode.partID and self.changes[rootnode.partID] then
				if not self.changes[rootnode.partID].scale then
					self.changes[rootnode.partID].scale = Vector(partData.scale)
				end
				self.changes[rootnode.partID].scale[i] = value

				if partData.scale[1] == self.changes[rootnode.partID].scale[1] and
				   partData.scale[2] == self.changes[rootnode.partID].scale[2] and
				   partData.scale[3] == self.changes[rootnode.partID].scale[3] then
					scale.Label:SetTextColor(nil)
					self.changes[rootnode.partID].scale = nil
				else
					scale.Label:SetTextColor(color_changed)
				end
			else
				partData.scale[i] = value
			end
			ToggleNodeColors(self, rootnode)
		end
		component:SetValue(partData.scale[i])
	end

	--
	local temp = rootnode:AddNode("")
	temp.ShowIcons = function() return false end

	local inside_xbox = vgui.Create("DCheckBoxLabel", temp)
	inside_xbox:SetText("render_inside")
	inside_xbox:Dock(LEFT)
	inside_xbox:DockMargin(22, 2, 0, 0)
	inside_xbox.Label:SetTextColor(Color(100, 100, 100))

	inside_xbox.OnChange = function(_, value)
		if rootnode.partID and self.changes[rootnode.partID] then
			if value == true then
				if partData.inv == true then
					inside_xbox.Label:SetTextColor(Color(100, 100, 100))
					self.changes[rootnode.partID].inv = nil
				else
					inside_xbox.Label:SetTextColor(color_changed)
					self.changes[rootnode.partID].inv = true
				end
			elseif value == false then
				if partData.inv == nil then
					inside_xbox.Label:SetTextColor(Color(100, 100, 100))
					self.changes[rootnode.partID].inv = nil
				else
					inside_xbox.Label:SetTextColor(color_changed)
					self.changes[rootnode.partID].inv = false
				end
			end
			ToggleNodeColors(self, rootnode)
		else
			partData.inv = value
		end
	end
	inside_xbox:SetValue(partData.inv)

	--
	local temp = rootnode:AddNode("")
	temp.ShowIcons = function() return false end

	local invert_xbox = vgui.Create("DCheckBoxLabel", temp)
	invert_xbox:SetText("invert_normals")
	invert_xbox:Dock(LEFT)
	invert_xbox:DockMargin(22, 2, 0, 0)
	invert_xbox.Label:SetTextColor(Color(100, 100, 100))

	invert_xbox.OnChange = function(_, value)
		if rootnode.partID and self.changes[rootnode.partID] then
			if value == true then
				if partData.flip == true then
					invert_xbox.Label:SetTextColor(Color(100, 100, 100))
					self.changes[rootnode.partID].flip = nil
				else
					invert_xbox.Label:SetTextColor(color_changed)
					self.changes[rootnode.partID].flip = true
				end
			elseif value == false then
				if partData.flip == nil then
					invert_xbox.Label:SetTextColor(Color(100, 100, 100))
					self.changes[rootnode.partID].flip = nil
				else
					invert_xbox.Label:SetTextColor(color_changed)
					self.changes[rootnode.partID].flip = false
				end
			end
			ToggleNodeColors(self, rootnode)
		else
			partData.flip = value
		end
	end
	invert_xbox:SetValue(partData.flip)

	--
	local temp = rootnode:AddNode("")
	temp.ShowIcons = function() return false end

	local smooth_xbox = vgui.Create("DCheckBoxLabel", temp)
	smooth_xbox:SetText("smooth_normals")
	smooth_xbox:Dock(LEFT)
	smooth_xbox:DockMargin(22, 2, 0, 0)
	smooth_xbox.Label:SetTextColor(Color(100, 100, 100))

	local smooth_slider = vgui.Create("DNumSlider", temp)
	smooth_slider.Scratch:SetVisible(false)
	smooth_slider.Label:SetVisible(false)
	smooth_slider:SetWide(128)
	smooth_slider:DockMargin(24, 0, 0, 0)
	smooth_slider:Dock(LEFT)
	smooth_slider:SetMin(0)
	smooth_slider:SetMax(180)
	smooth_slider:SetDecimals(0)

	smooth_xbox.OnChange = function(_, value)
		if not value and smooth_slider:GetValue() ~= 0 then
			smooth_slider:SetValue(0)
		end
	end

	partData.smooth = partData.smooth or 0

	smooth_slider.OnValueChanged = function(_, value)
		smooth_xbox:SetValue(value > 0)
		if rootnode.partID and self.changes[rootnode.partID] then
			if partData.smooth ~= value then
				smooth_xbox.Label:SetTextColor(color_changed)
				self.changes[rootnode.partID].smooth = value
			else
				smooth_xbox.Label:SetTextColor(Color(100, 100, 100))
				self.changes[rootnode.partID].smooth = nil
			end
			ToggleNodeColors(self, rootnode)
		else
			partData.smooth = value
		end
	end

	smooth_slider:SetValue(partData.smooth)
end


function PANEL:AddOBJ(partData)
	self.additions[#self.additions + 1] = partData

	local node = self.obj_data:AddNode(string_format("[new] %s", partData.name), icon_part_changed)
	node.menu_type = "obj_new"

	node.Label:SetTextColor(color_changed)

	BuildOBJNode(self, node, partData)
end


-- -----------------------------------------------------------------------------
function PANEL:PopulateOBJ(partID, partData, add)
	local node = self.obj_data:AddNode(string_format("[%d] %s", partID, partData.name), icon_part_default)
	node.menu_type = "obj"
	node.partID = partID

	self.obj_data.subnodes[partID] = node
	self.changes[partID] = {}

	BuildOBJNode(self, node, partData)
end


-- -----------------------------------------------------------------------------
function PANEL:PopulateMDL(partID, partData)
	local node = self.mdl_data:AddNode(string_format("[%d] %s", partID, string.GetFileFromFilename(partData.mdl)), icon_part_default)
	node.menu_type = "mdl"
	node.partID = partID

	node.flags = {
		node:AddNode(string_format("render_inside = %s", partData.inv and "true" or "false"), "icon16/bullet_black.png"),
		node:AddNode(string_format("flat_shading = %s", partData.flat and "true" or "false"), "icon16/bullet_black.png"),
	}

	self.mdl_data.subnodes[partID] = node
	self.changes[partID] = {}

	node.Label.OnCursorEntered = function()
		editors[self] = partData
		node.Label:InvalidateLayout(true)
	end
end


-- -----------------------------------------------------------------------------
menuFunctions.file = function(self, node)
	local dmenu = DermaMenu()

	dmenu:AddOption("Add .obj", function()
		local name = node:GetText()
		local data = file.Read(name, "DATA")

		if not data then
			return
		end

		local valid, obj = pcall(function()
			local condensed = {}

			for line in string.gmatch(data, "(.-)\n") do
				local temp = string_explode(" ", string_gsub(string_trim(line), "%s+", " "))
				local head = table_remove(temp, 1)

				if head == "f" then
					local v1 = string_explode("/", temp[1])
					local v2 = string_explode("/", temp[2])
					for i  = 3, #temp do
						local v3 = string_explode("/", temp[i])
						condensed[#condensed + 1] = string_format("f %d %d %d\n", v1[1], v2[1], v3[1])
						v2 = v3
					end
				else
					if head == "v" then
						local x = tonumber(temp[1])
						local y = tonumber(temp[2])
						local z = tonumber(temp[3])

						x = math_abs(x) < 1e-4 and 0 or x
						y = math_abs(y) < 1e-4 and 0 or y
						z = math_abs(z) < 1e-4 and 0 or z

						condensed[#condensed + 1] = string_format("v %s %s %s\n", x, y, z)
					end
				end
			end

			return table.concat(condensed)
		end)

		if valid and obj then
			local size = string.len(util.Compress(obj))
			if size > 63000 then
				node:SetText(string_format("[%s] [%dkb file size too large]", node:GetText(), size*0.001))
				node:SetEnabled(false)
				node.Label:SetTextColor(color_deleted)
				return
			end

			self:AddOBJ({
				obj   = obj,
				name  = name,
				pos   = Vector(),
				ang   = Angle(),
				scale = Vector(1,1,1),
			})
		end
	end):SetIcon(icon_part_changed)

	dmenu:AddSpacer()
	dmenu:AddOption("Cancel"):SetIcon(icon_cancel)

	dmenu:Open()
end


-- -----------------------------------------------------------------------------
menuFunctions.obj_new = function(self, node)
	local dmenu = DermaMenu()

	dmenu:AddOption("Remove .obj", function()
		table_remove(self.additions, node.partID)
		node:Remove()
	end):SetIcon(icon_part_deleted)

	dmenu:AddSpacer()
	dmenu:AddOption("Cancel"):SetIcon(icon_cancel)

	dmenu:Open()
end


-- -----------------------------------------------------------------------------
menuFunctions.obj = function(self, node)
	local dmenu = DermaMenu()

	if self.changes[node.partID].delete then
		dmenu:AddSpacer()
		dmenu:AddOption("Undo remove .obj", function()
			node:SetIcon(icon_part_default)
			node.Label:SetTextColor()
			self.changes[node.partID] = {}
		end):SetIcon(icon_part_changed)
	else
		dmenu:AddSpacer()
		dmenu:AddOption("Remove .obj", function()
			node:SetIcon(icon_part_deleted)
			node.Label:SetTextColor(color_deleted)
			self.changes[node.partID] = { delete = true }
		end):SetIcon(icon_part_deleted)
	end

	dmenu:AddSpacer()
	dmenu:AddOption("Cancel"):SetIcon(icon_cancel)

	dmenu:Open()
end


-- -----------------------------------------------------------------------------
menuFunctions.mdl = function(self, node)
	local dmenu = DermaMenu()

	if self.changes[node.partID].delete then
		dmenu:AddSpacer()
		dmenu:AddOption("Undo remove .mdl", function()
			node:SetIcon(icon_part_default)
			node.Label:SetTextColor()
			self.changes[node.partID] = {}
		end):SetIcon(icon_part_changed)
	else
		for i, flag in ipairs(flags) do
			local sub, opt = dmenu:AddSubMenu(flag.text)
			opt:SetIcon(flag.icons[1])

			if self.changes[node.partID][flag.data] ~= nil then
				sub:AddOption(self.changes[node.partID][flag.data] and "Undo (Set false)" or "Undo (Set true)", function()
					self.changes[node.partID][flag.data] = nil
					flag.toggle(node.flags[i], self.Data[node.partID][flag.data], nil)
					if next(self.changes[node.partID]) == nil then
						node:SetIcon(icon_part_default)
						node.Label:SetTextColor()
					end
				end):SetIcon(flag.icons[3])
			else
				if self.Data[node.partID][flag.data] then
					sub:AddOption("Set false", function()
						if next(self.changes[node.partID]) == nil then
							node:SetIcon(icon_part_changed)
							node.Label:SetTextColor(color_changed)
						end
						self.changes[node.partID][flag.data] = false
						flag.toggle(node.flags[i], nil, false)
					end):SetIcon(flag.icons[3])
				else
					sub:AddOption("Set true", function()
						if next(self.changes[node.partID]) == nil then
							node:SetIcon(icon_part_changed)
							node.Label:SetTextColor(color_changed)
						end
						self.changes[node.partID][flag.data] = true
						flag.toggle(node.flags[i], nil, true)
					end):SetIcon(flag.icons[2])
				end
			end

			sub:AddSpacer()
			sub:AddOption("Set true all", function()
				for partID, partData in pairs(self.Data) do
					if not partData.mdl or self.changes[partID].delete or self.changes[partID][flag.data] == true then
						continue
					end
					if partData[flag.data] then
						self.changes[partID][flag.data] = nil
					else
						self.changes[partID][flag.data] = true
					end
					if next(self.changes[partID]) == nil then
						self.mdl_data.subnodes[partID]:SetIcon(icon_part_default)
						self.mdl_data.subnodes[partID].Label:SetTextColor()
					else
						self.mdl_data.subnodes[partID]:SetIcon(icon_part_changed)
						self.mdl_data.subnodes[partID].Label:SetTextColor(color_changed)
					end
					flag.toggle(self.mdl_data.subnodes[partID].flags[i], partData[flag.data], self.changes[partID][flag.data])
				end
			end):SetIcon(flag.icons[2])

			sub:AddOption("Set false all", function()
				for partID, partData in pairs(self.Data) do
					if not partData.mdl or self.changes[partID].delete or self.changes[partID][flag.data] == false then
						continue
					end
					if partData[flag.data] then
						self.changes[partID][flag.data] = false
					else
						self.changes[partID][flag.data] = nil
					end
					if next(self.changes[partID]) == nil then
						self.mdl_data.subnodes[partID]:SetIcon(icon_part_default)
						self.mdl_data.subnodes[partID].Label:SetTextColor()
					else
						self.mdl_data.subnodes[partID]:SetIcon(icon_part_changed)
						self.mdl_data.subnodes[partID].Label:SetTextColor(color_changed)
					end
					flag.toggle(self.mdl_data.subnodes[partID].flags[i], partData[flag.data], self.changes[partID][flag.data])
				end
			end):SetIcon(flag.icons[3])

			sub:AddSpacer()
			sub:AddOption("Cancel"):SetIcon(icon_cancel)
		end

		dmenu:AddSpacer()
		dmenu:AddOption("Remove .mdl", function()
			node:SetIcon(icon_part_deleted)
			node.Label:SetTextColor(color_deleted)
			self.changes[node.partID] = { delete = true }
			for i, flag in ipairs(flags) do
				flag.toggle(node.flags[i], self.Data[node.partID][flag.data], nil)
			end
		end):SetIcon(icon_part_deleted)
	end

	dmenu:AddSpacer()
	dmenu:AddOption("Cancel"):SetIcon(icon_cancel)

	dmenu:Open()
end


-- -----------------------------------------------------------------------------
vgui.Register("p2m_editor", PANEL, "DFrame")
