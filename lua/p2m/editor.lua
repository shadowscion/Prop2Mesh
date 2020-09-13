-- -----------------------------------------------------------------------------
local PANEL = {}

local wireframe = Material("models/wireframe")

local color_hover = Color(200, 200, 200)
local color_delete = Color(200, 85, 85)
local color_change = Color(85, 200, 85)

local editors = {}

hook.Add("PostDrawOpaqueRenderables", "P2MDrawEditorGhosts", function()
	for editor, _ in pairs(editors) do
		editor:DrawGhosts()
	end
end)


-- -----------------------------------------------------------------------------
function PANEL:Init()

	editors[self] = true

	self.csmodel = ClientsideModel("models/error.mdl")
	self.csmodel:SetNoDraw(true)

	self.ghosts = {}

	self.tree = vgui.Create("DTree", self)
	self.tree:Dock(FILL)
	self.tree.OnNodeSelected = function()
		self.tree:SetSelectedItem(nil)
	end

	local btn = vgui.Create("DButton", self)
	btn:SetText("Confirm changes")
	btn:Dock(BOTTOM)
	btn:DockMargin(0, 2, 0, 0)
	btn.DoClick = function()
		if IsValid(self.controller) then
			for k, v in pairs(self.changes) do
				if next(v) == nil then
					self.changes[k] = nil
				end
			end

			if next(self.changes) ~= nil then
				net.Start("NetP2M.MakeChanges")
				net.WriteEntity(self.controller)
				local data = util.Compress(util.TableToJSON(self.changes))
				local size = string.len(data)
				net.WriteUInt(size, 32)
				net.WriteData(data, size)
				net.SendToServer()
			end

			self:Close()
		end
	end

	self.tree.Paint = function(pnl, w, h)
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

	if IsValid(self.controller) then
		self.controller:RemoveCallOnRemove("p2m_editor_rmv")
	end

	self.csmodel:Remove()

end


-- -----------------------------------------------------------------------------
function PANEL:SetController(controller, models)

	if not models then
		return
	end

	self.controller = controller
	self.controller:CallOnRemove("p2m_editor_rmv", function()
		self:Close()
	end)
	self:SetTitle(tostring(controller))

	self.models  = models
	self:RebuildTree()

end


-- -----------------------------------------------------------------------------
local node_icon = "icon16/brick.png"
local node_icon_changed = "icon16/brick_add.png"
local node_icon_deleted = "icon16/brick_delete.png"

local function BooleanSubmenu(self, id, model, field, menu, title, opt_icon, opt_icon_set, opt_icon_unset, allowSetAll)
	local sub, opt = menu:AddSubMenu(title)
	opt:SetIcon(opt_icon)

	if self.changes[id][field] ~= nil then
		sub:AddOption(self.changes[id][field] and "Set false" or "Set true", function()
			self.changes[id][field] = nil
			if self.nodes[id].subnodes[field] then
				self.nodes[id].subnodes[field]:toggle(id, model)
			end
			if next(self.changes[id]) == nil then
				self.nodes[id]:SetIcon(node_icon)
				self.nodes[id].Label:SetTextColor(nil)
				self:CreateGhost(id)
			end
		end):SetIcon(opt_icon_unset)
	else
		if model[field] then
			sub:AddOption("Set false", function()
				if next(self.changes[id]) == nil then
					self.nodes[id]:SetIcon(node_icon_changed)
					self.nodes[id].Label:SetTextColor(color_change)
					self:CreateGhost(id, wireframe, color_change, model)
				end
				self.changes[id][field] = false
				if self.nodes[id].subnodes[field] then
					self.nodes[id].subnodes[field]:toggle(id, model)
				end
			end):SetIcon(opt_icon_unset)
		else
			sub:AddOption("Set true", function()
				if next(self.changes[id]) == nil then
					self.nodes[id]:SetIcon(node_icon_changed)
					self.nodes[id].Label:SetTextColor(color_change)
					self:CreateGhost(id, wireframe, color_change, model)
				end
				self.changes[id][field] = true
				if self.nodes[id].subnodes[field] then
					self.nodes[id].subnodes[field]:toggle(id, model)
				end
			end):SetIcon(opt_icon_set)
		end
	end

	sub:AddSpacer()
	if allowSetAll then
		sub:AddOption("Set true all", function()
			for k, v in ipairs(self.models) do
				self.changes[k][field] = nil
				if next(self.changes[k]) == nil then
					self.nodes[k]:SetIcon(node_icon)
					self.nodes[k].Label:SetTextColor(nil)
					self:CreateGhost(k)
				end

				if not v[field] then
					if next(self.changes[k]) == nil then
						self.nodes[k]:SetIcon(node_icon_changed)
						self.nodes[k].Label:SetTextColor(color_change)
						self:CreateGhost(k, wireframe, color_change, v)
					end
					self.changes[k][field] = true
				end

				if self.nodes[k].subnodes[field] then
					self.nodes[k].subnodes[field]:toggle(k, v)
				end
			end
		end):SetIcon(opt_icon_set)
	end

	sub:AddOption("Set false all", function()
		for k, v in ipairs(self.models) do
			self.changes[k][field] = nil
			if next(self.changes[k]) == nil then
				self.nodes[k]:SetIcon(node_icon)
				self.nodes[k].Label:SetTextColor(nil)
				self:CreateGhost(k)
			end

			if v[field] then
				if next(self.changes[k]) == nil then
					self.nodes[k]:SetIcon(node_icon_changed)
					self.nodes[k].Label:SetTextColor(color_change)
					self:CreateGhost(k, wireframe, color_change, v)
				end
				self.changes[k][field] = false
			end

			if self.nodes[k].subnodes[field] then
				self.nodes[k].subnodes[field]:toggle(k, v)
			end
		end
	end):SetIcon(opt_icon_unset)
end

function PANEL:OpenChangesMenu(id, model)

	local menu = DermaMenu()

	if self.changes[id].delete then
		menu:AddOption("Undo mark for deletion", function()
			self.nodes[id]:SetIcon(node_icon)
			self.nodes[id].Label:SetTextColor(nil)
			self:CreateGhost(id)
			self.changes[id] = {}
		end):SetIcon(node_icon_changed)
	else
		BooleanSubmenu(self, id, model, "inv", menu, "Render inside", "icon16/camera.png", "icon16/camera_add.png", "icon16/camera_delete.png")
		BooleanSubmenu(self, id, model, "flat", menu, "Flat shading", "icon16/contrast.png", "icon16/contrast_high.png", "icon16/contrast_low.png", true)

		menu:AddSpacer()
		menu:AddOption("Mark for deletion", function()
			self.nodes[id]:SetIcon(node_icon_deleted)
			self.nodes[id].Label:SetTextColor(color_delete)
			self:CreateGhost(id, wireframe, color_delete, model)
			self.changes[id] = { delete = true }
			for k, v in pairs(self.nodes[id].subnodes) do
				v:toggle(id, model)
			end
		end):SetIcon(node_icon_deleted)
	end

	menu:Open()

end


-- -----------------------------------------------------------------------------
function PANEL:CreateModelNode(id, model)

	self.nodes[id] = self.tree:AddNode(string.format("[%d] %s", id, string.GetFileFromFilename(model.mdl)), "icon16/brick.png")
	self.nodes[id].Label:SetTooltip(model.mdl)
	self.nodes[id].Label.OnCursorEntered = function()
		self:CreateGhost("hover", wireframe, color_hover, model)
	end

	self.changes[id] = {}

	self.nodes[id].DoRightClick = function()
		self:OpenChangesMenu(id, model)
	end

	return self.nodes[id]

end

function PANEL:RebuildTree()

	self.tree:Clear()

	self.nodes = {}
	self.changes = {}

	local order = {
		{
			id     = "inv",
			toggle = function(subnode, id, model)
				if self.changes[id].inv ~= nil then
					subnode.Label:SetTextColor(color_change)
					subnode:SetIcon("icon16/bullet_green.png")
					subnode:SetText(string.format("flag_render_inside = %s", self.changes[id].inv and "true" or "false"))
				else
					subnode.Label:SetTextColor(nil)
					subnode:SetIcon("icon16/bullet_black.png")
					subnode:SetText(string.format("flag_render_inside = %s", model.inv and "true" or "false"))
				end
			end
		},
		{
			id   = "flat",
			toggle = function(subnode, id, model)
				if self.changes[id].flat ~= nil then
					subnode.Label:SetTextColor(color_change)
					subnode:SetIcon("icon16/bullet_green.png")
					subnode:SetText(string.format("flag_flat_shading = %s", self.changes[id].flat and "true" or "false"))
				else
					subnode.Label:SetTextColor(nil)
					subnode:SetIcon("icon16/bullet_black.png")
					subnode:SetText(string.format("flag_flat_shading = %s", model.flat and "true" or "false"))
				end
			end
		}
	}

	for id, model in ipairs(self.models) do
		local node = self:CreateModelNode(id, model)

		node.subnodes = {}

		for i, property in ipairs(order) do
			node.subnodes[property.id] = node:AddNode("")
			node.subnodes[property.id].toggle = property.toggle
			node.subnodes[property.id]:toggle(id, model)
		end
	end

end


-- -----------------------------------------------------------------------------
function PANEL:CreateGhost(id, material, color, data)

	if not data then
		self.ghosts[id] = nil
		return
	end

	self.ghosts[id] = {
		pos = data.pos, ang = data.ang, r = color.r/255, g = color.g/255, b = color.b/255, mdl = data.mdl, mat = material, scale = Matrix()
	}
	self.ghosts[id].scale:SetScale(data.scale or Vector(1, 1, 1))

end

-- -----------------------------------------------------------------------------
function PANEL:DrawGhosts()

	cam.IgnoreZ(true)

	for id, ghost in pairs(self.ghosts) do
		if id == "hover" then
			continue
		end

		self.csmodel:SetModel(ghost.mdl)
		self.csmodel:SetPos(self.controller:LocalToWorld(ghost.pos))
		self.csmodel:SetAngles(self.controller:LocalToWorldAngles(ghost.ang))
		self.csmodel:EnableMatrix("RenderMultiply", ghost.scale)
		self.csmodel:SetupBones()

		render.ModelMaterialOverride(ghost.mat)
		render.SetColorModulation(ghost.r, ghost.g, ghost.b)

		self.csmodel:DrawModel()
	end

	local ghost = self.ghosts.hover
	if ghost then
		self.csmodel:SetModel(ghost.mdl)
		self.csmodel:SetPos(self.controller:LocalToWorld(ghost.pos))
		self.csmodel:SetAngles(self.controller:LocalToWorldAngles(ghost.ang))
		self.csmodel:EnableMatrix("RenderMultiply", ghost.scale)
		self.csmodel:SetupBones()

		render.ModelMaterialOverride(ghost.mat)
		render.SetColorModulation(ghost.r, ghost.g, ghost.b)

		self.csmodel:DrawModel()
	end

	cam.IgnoreZ(false)

	render.ModelMaterialOverride(nil)
	render.SetColorModulation(1, 1, 1)

end


-- -----------------------------------------------------------------------------
vgui.Register("p2m_editor", PANEL, "DFrame")
