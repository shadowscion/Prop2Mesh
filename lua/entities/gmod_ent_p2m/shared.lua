-- -----------------------------------------------------------------------------
ENT.Base      = "base_anim"
ENT.PrintName = "P2M Controller"
ENT.Author    = "shadowscion"
ENT.Editable  = false
ENT.Spawnable = false
ENT.AdminOnly = false
ENT.RenderGroup = RENDERGROUP_BOTH

cleanup.Register("gmod_ent_p2m")


-- -----------------------------------------------------------------------------
function ENT:GetPlayer()
	return self:GetNWEntity("Founder", NULL)
end


-- -----------------------------------------------------------------------------
function ENT:CanProperty(ply, property)
	if property == "p2m_edit" then
		return ply == self:GetPlayer()
	end
	return false
end


-- -----------------------------------------------------------------------------
function ENT:SetupDataTables()
	-- self:NetworkVar("Int", 0, "RMinX", { KeyName = "rminx", Edit = { category = "Render Bounds", title = "X Min", type = "Int", order = 1, min = -1000, max = 1000 } } )
	-- self:NetworkVar("Int", 1, "RMinY", { KeyName = "rminy", Edit = { category = "Render Bounds", title = "Y Min", type = "Int", order = 2, min = -1000, max = 1000 } } )
	-- self:NetworkVar("Int", 2, "RMinZ", { KeyName = "rminz", Edit = { category = "Render Bounds", title = "Z Min", type = "Int", order = 3, min = -1000, max = 1000 } } )
	-- self:NetworkVar("Int", 3, "RMaxX", { KeyName = "rmaxx", Edit = { category = "Render Bounds", title = "X Max", type = "Int", order = 4, min = -1000, max = 1000 } } )
	-- self:NetworkVar("Int", 4, "RMaxY", { KeyName = "rmaxy", Edit = { category = "Render Bounds", title = "Y Max", type = "Int", order = 5, min = -1000, max = 1000 } } )
	-- self:NetworkVar("Int", 5, "RMaxZ", { KeyName = "rmaxz", Edit = { category = "Render Bounds", title = "Z Max", type = "Int", order = 6, min = -1000, max = 1000 } } )

	self:NetworkVar("Int", 0, "RMinX")
	self:NetworkVar("Int", 1, "RMinY")
	self:NetworkVar("Int", 2, "RMinZ")
	self:NetworkVar("Int", 3, "RMaxX")
	self:NetworkVar("Int", 4, "RMaxY")
	self:NetworkVar("Int", 5, "RMaxZ")

	if CLIENT then
		self:NetworkVarNotify("RMinX", self.OnRMinXChanged)
		self:NetworkVarNotify("RMinY", self.OnRMinYChanged)
		self:NetworkVarNotify("RMinZ", self.OnRMinZChanged)
		self:NetworkVarNotify("RMaxX", self.OnRMaxXChanged)
		self:NetworkVarNotify("RMaxY", self.OnRMaxYChanged)
		self:NetworkVarNotify("RMaxZ", self.OnRMaxZChanged)
	end
end


-- -----------------------------------------------------------------------------
if CLIENT then
	function ENT:OnRMinXChanged(varname, oldvalue, newvalue)
		local min, max = self:GetRenderBounds()
		min.x = newvalue
		self:SetRenderBounds(min, max)
		self.boxtime = CurTime()
	end
	function ENT:OnRMinYChanged(varname, oldvalue, newvalue)
		local min, max = self:GetRenderBounds()
		min.y = newvalue
		self:SetRenderBounds(min, max)
		self.boxtime = CurTime()
	end
	function ENT:OnRMinZChanged(varname, oldvalue, newvalue)
		local min, max = self:GetRenderBounds()
		min.z = newvalue
		self:SetRenderBounds(min, max)
		self.boxtime = CurTime()
	end
	function ENT:OnRMaxXChanged(varname, oldvalue, newvalue)
		local min, max = self:GetRenderBounds()
		max.x = newvalue
		self:SetRenderBounds(min, max)
		self.boxtime = CurTime()
	end
	function ENT:OnRMaxYChanged(varname, oldvalue, newvalue)
		local min, max = self:GetRenderBounds()
		max.y = newvalue
		self:SetRenderBounds(min, max)
		self.boxtime = CurTime()
	end
	function ENT:OnRMaxZChanged(varname, oldvalue, newvalue)
		local min, max = self:GetRenderBounds()
		max.z = newvalue
		self:SetRenderBounds(min, max)
		self.boxtime = CurTime()
	end
else
	function ENT:SetDefaultRenderBounds()
		self:SetRMinX(-100)
		self:SetRMinY(-100)
		self:SetRMinZ(-100)
		self:SetRMaxX(100)
		self:SetRMaxY(100)
		self:SetRMaxZ(100)
	end
end

properties.Add("p2m_edit", {
	MenuLabel = "Inspect Models",
	Order     = 90005,
	MenuIcon  = "icon16/bricks.png",

	Filter = function(self, ent, ply)
		if IsValid(ent) then
			if ent:GetClass() ~= "gmod_ent_p2m" then return false end
			return gamemode.Call("CanProperty", ply, "p2m_edit", ent)
		end
		return false
	end,

	Action = function(self, ent)
		local cpanel = spawnmenu.ActiveControlPanel()
		if IsValid(cpanel) then
			cpanel:SetExpanded(false)
		end

		local scale = Matrix()
		local ghost = ents.CreateClientProp("models/error.mdl")
		ghost:SetMaterial("models/wireframe")
		ghost:Spawn()
		ghost.RenderOverride = function()
			cam.IgnoreZ(true)
			render.SuppressEngineLighting(true)
			if ghost.clips then
				local state = render.EnableClipping(true)
				for k, clip in ipairs(ghost.clips) do
					local normal = ghost:LocalToWorld(clip.n) - ghost:GetPos()
					local origin = ghost:LocalToWorld(clip.n * clip.d)
					render.PushCustomClipPlane(normal, normal:Dot(origin))
				end
				ghost:DrawModel()
				for k, clip in ipairs(ghost.clips) do
					render.PopCustomClipPlane()
				end
				render.EnableClipping(state)
			else
				ghost:DrawModel()
			end
			render.SuppressEngineLighting(false)
			cam.IgnoreZ(false)
		end

		local window = g_ContextMenu:Add("DFrame")
		local h = math.floor(ScrH() / 2)
		local w = math.floor(h * 0.75)
		window:SetPos(ScrW() - w - 50, ScrH() - 50 - h)
		window:SetSize(w, h)
		window:SetTitle(tostring(ent))
		window.OnClose = function()
			if IsValid(ghost) then
				ghost:Remove()
			end
			if IsValid(ent) then
				ent:RemoveCallOnRemove("p2m_edit")
			end
		end
		ent:CallOnRemove("p2m_edit", function()
			if IsValid(ghost) then
				ghost:Remove()
			end
			if IsValid(window) then
				window:Close()
			end
		end)

		local tree = vgui.Create("DTree", window)
		tree:Dock(FILL)
		tree:DockMargin(0, 0, 0, 2)
		local changes = {}

		if ent.models then
			for k, v in ipairs(ent.models) do
				local node = tree:AddNode(string.GetFileFromFilename(v.mdl), "icon16/bullet_black.png")
				node.index = k
				node.Label.OnCursorEntered = function()
					ghost:SetColor(node.Label:GetTextColor() or Color(125, 255, 125))
					ghost:SetModel(v.mdl)
					ghost:SetPos(ent:LocalToWorld(v.pos))
					ghost:SetAngles(ent:LocalToWorldAngles(v.ang))
					if v.scale then
						scale:SetScale(v.scale)
						ghost:EnableMatrix("RenderMultiply", scale)
					else
						ghost:DisableMatrix("RenderMultiply")
					end
					ghost.clips = v.clips
					ghost:SetupBones()
					node.Label:InvalidateLayout(true)
				end
			end
			tree.DoRightClick = function(pnl, node)
				local menu = DermaMenu()
				if changes[node.index] then
					menu:AddOption("Undo mark for deletion", function()
						node.Label:SetTextColor()
						node:SetIcon("icon16/bullet_black.png")
						changes[node.index] = nil
					end):SetIcon("icon16/brick_add.png")
				else
					menu:AddOption("Mark for deletion", function()
						node.Label:SetTextColor(Color(255, 0, 0))
						node:SetIcon("icon16/bullet_red.png")
						changes[node.index] = true
					end):SetIcon("icon16/brick_delete.png")
				end
				menu:AddSpacer()
				menu:AddOption("Cancel"):SetIcon("icon16/cancel.png")
				menu:Open()
			end
		end

		local confirm = vgui.Create("DButton", window)
		confirm:Dock(BOTTOM)
		confirm:SetText("Confirm Changes")
		confirm.DoClick = function()
			if table.Count(changes) > 0 then
				self:MsgStart()
					net.WriteEntity(ent)
					net.WriteTable(changes)
				self:MsgEnd()
				window:Close()
			end
		end
	end,

	Receive = function(self, length, ply)
		local ent = net.ReadEntity()
		if not self:Filter(ent, ply)then
			return
		end
		ent:RemoveFromTable(net.ReadTable())
	end,
})
