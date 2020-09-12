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
		if IsValid(self.controller) and next(self.changes) ~= nil then
			net.Start("NetP2M.MakeChanges")
			net.WriteEntity(self.controller)
			local data = util.Compress(util.TableToJSON(self.changes))
			local size = string.len(data)
			net.WriteUInt(size, 32)
			net.WriteData(data, size)
			net.SendToServer()
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
	self.changes = {}
	self:RebuildTree()

end


-- -----------------------------------------------------------------------------
function PANEL:RebuildTree()
	self.tree:Clear()

	for id, model in ipairs(self.models) do
		local change_delete  = false
		local change_rinside = model.inv
		local change_rflat   = model.flat

		local node_model = self.tree:AddNode(string.GetFileFromFilename(model.mdl), "icon16/brick.png")
		node_model.Label.OnCursorEntered = function()
			self:CreateGhost("hover", wireframe, color_hover, model)
		end
		node_model.Label:SetTooltip(model.mdl)

		node_model.DoRightClick = function()
			local menu = DermaMenu()

			menu:AddOption(change_delete and "Undo mark for deletion" or "Mark for deletion", function()

				if not change_delete then
					self.changes[id] = { delete = true }
					change_delete = true
					node_model.Label:SetTextColor(color_delete)
					self:CreateGhost(id, wireframe, color_delete, model)
				else
					self.changes[id] = nil
					change_delete = nil
					node_model.Label:SetTextColor(nil)
					self:CreateGhost(id)
				end

				node_model:SetIcon(change_delete and "icon16/brick_delete.png" or "icon16/brick.png")

				change_rinside = model.inv
				change_rflat   = model.flag

				if node_model.subnode_inv then node_model.subnode_inv:Remove() end
				if node_model.subnode_flat then node_model.subnode_flat:Remove() end

			end):SetIcon(change_delete and "icon16/brick_add.png" or "icon16/brick_delete.png")

			if change_delete then
				menu:Open()
				return
			end

			menu:AddSpacer()

			menu:AddOption(change_rinside and "Undo render inside" or "Render inside", function()

				if change_delete then return end

				if change_rinside then change_rinside = nil else change_rinside = true end

				if model.inv ~= change_rinside then

					node_model:SetIcon("icon16/brick_add.png")
					node_model.Label:SetTextColor(color_change)
					self:CreateGhost(id, wireframe, color_change, model)

					if not self.changes[id] then
						self.changes[id] = {}
					end

					self.changes[id].inv = change_rinside or false

					node_model.subnode_inv = node_model:AddNode(string.format("render_inside = %s", change_rinside and "TRUE" or "FALSE"), "icon16/bullet_wrench.png")
					node_model:SetExpanded(true)

				else

					node_model:SetIcon("icon16/brick.png")
					node_model.Label:SetTextColor(nil)
					self:CreateGhost(id)

					if self.changes[id] then
						self.changes[id].inv = nil
					end
					if next(self.changes[id]) == nil then
						self.changes[id] = nil
					end

					if node_model.subnode_inv then node_model.subnode_inv:Remove() end

				end

			end):SetIcon(change_rinside and "icon16/camera_delete.png" or "icon16/camera_add.png")

			menu:AddOption(change_rflat and "Undo flat shading" or "Flat shading", function()

				if change_delete then return end

				if change_rflat then change_rflat = nil else change_rflat = true end

				if model.flat ~= change_rflat then

					node_model:SetIcon("icon16/brick_add.png")
					node_model.Label:SetTextColor(color_change)
					self:CreateGhost(id, wireframe, color_change, model)

					if not self.changes[id] then
						self.changes[id] = {}
					end

					self.changes[id].flat = change_rflat or false

					node_model.subnode_flat = node_model:AddNode(string.format("shading_flat = %s", change_rflat and "TRUE" or "FALSE"), "icon16/bullet_wrench.png")
					node_model:SetExpanded(true)

				else

					node_model:SetIcon("icon16/brick.png")
					node_model.Label:SetTextColor(nil)
					self:CreateGhost(id)

					if self.changes[id] then
						self.changes[id].flat = nil
					end
					if next(self.changes[id]) == nil then
						self.changes[id] = nil
					end

					if node_model.subnode_flat then node_model.subnode_flat:Remove() end

				end

			end):SetIcon(change_rflat and "icon16/contrast_low.png" or "icon16/contrast.png")

			menu:Open()
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
