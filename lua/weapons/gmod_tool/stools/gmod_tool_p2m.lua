--[[
	Prop To Mesh Tool
	by shadowscion
]]--

TOOL.Category   = "Render"
TOOL.Name       = "#tool.gmod_tool_p2m.listname"
TOOL.Command    = nil
TOOL.ConfigName = ""

TOOL.ClientConVar = {
	["radius"] = 64,
	["ignore_parented"] = 0,
	["ignore_constrained"] = 0,
	["ignore_invisible"] = 1,
	["ignore_holos"] = 1,
	["ignore_props"] = 0,
	["bymaterial"] = 0,
	["bycolor"] = 0,
	["texscale"] = 0,
}

local colors = {}
colors.controller = Color(0, 0, 255, 200)
colors.selected = Color(231, 75, 60, 200)


-- -----------------------------------------------------------------------------
-- Server/Shared
if SERVER then
	TOOL.CookieJar = {}
end

local function IsPropOwner(ply, ent, singleplayer)
	if singleplayer then return true end
	if CPPI then return ent:CPPIGetOwner() == ply end

	for k, v in pairs(g_SBoxObjects) do
		for b, j in pairs(v) do
			for _, e in pairs(j) do
				if e == ent and k == ply:UniqueID() then return true end
			end
		end
	end

	return false
end


-- -----------------------------------------------------------------------------
-- TOOL: Selection class whitelist
local blocked = {
	["worldspawn"] = true
}
local allowed = {
	["prop_physics"] = {
		checkValid = function(tool, ent)
			if tool:GetClientNumber("ignore_props") == 1 then
				return false
			end
			return IsPropOwner(tool:GetOwner(), ent, game.SinglePlayer())
		end,
		selectColor = Color(231, 75, 60, 200)
	},
	["gmod_wire_hologram"] = {
		checkValid = function(tool, ent)
			if tool:GetClientNumber("ignore_holos") == 1 then
				return false
			end
			return tool:GetOwner() == ent:GetPlayer()
		end,
		selectColor = Color(75, 231, 60, 200)
	}
}

function TOOL:CanSelect(ent)
	if self.CookieJar[ent] then
		return false
	end
	if not IsValid(ent) then
		return false
	end
	local class = ent:GetClass()
	if blocked[class] then
		return false
	end
	if not allowed[class] or not allowed[class].checkValid or not allowed[class].checkValid(self, ent) then
		return false
	end
	if self:GetClientNumber("ignore_invisible") == 1 then
		if ent:GetColor().a == 0 then
			return false
		end
	end
	if self:GetClientNumber("ignore_parented") == 1 then
		if IsValid(ent:GetParent()) then
			return false
		end
	end
	if self:GetClientNumber("ignore_constrained") == 1 then
		if ent:IsConstrained() then
			return false
		end
	end
	return allowed[class].selectColor
end

function TOOL:SelectEntity(ent, notify)
	local check = self:CanSelect(ent)
	if not check then
		return false
	end

	self.CookieJar[ent] = {
		Color = ent:GetColor(),
		Mode = ent:GetRenderMode(),
	}

	ent:SetColor(check or colors.selected)
	ent:SetRenderMode(RENDERMODE_TRANSALPHA)

	ent:CallOnRemove("p2m_selected", function(e)
		self.CookieJar[e] = nil
	end)

	return true
end

function TOOL:DeselectEntity(ent, notify)
	if not self.CookieJar[ent] or not IsValid(ent) then
		return false
	end

	ent:SetColor(self.CookieJar[ent].Color)
	ent:SetRenderMode(self.CookieJar[ent].Mode)
	ent:RemoveCallOnRemove("p2m_selected")

	self.CookieJar[ent] = nil

	return true
end

local function GetHitAngle(trace)
	local ang
	if math.abs(trace.HitNormal.x) < 0.001 and math.abs(trace.HitNormal.y) < 0.001 then
		ang = Vector(0, 0, trace.HitNormal.z):Angle()
	else
		ang = trace.HitNormal:Angle()
	end
	ang.p = ang.p + 90
	return ang
end

local function PowerOfTwo(n)
	return math.pow(2, math.ceil(math.log(n) / math.log(2)))
end

-- -----------------------------------------------------------------------------
-- TOOL: Left Click - Spawning controller
function TOOL:LeftClick(trace)
	if CLIENT then
		return true
	end

	if self:GetStage() ~= 0 or IsValid(self.Controller) then
		return false
	end

	if trace.HitWorld or IsPropOwner(self:GetOwner(), trace.Entity, game.SinglePlayer()) then
		if trace.Entity:GetClass() == "gmod_ent_p2m" then
			return false
		end

		local new = ents.Create("gmod_ent_p2m")
		new:SetModel("models/hunter/plates/plate.mdl")
		new:SetMaterial("models/debug/debugwhite")
		new:SetPos(trace.HitPos)
		new:SetAngles(GetHitAngle(trace))
		new:Spawn()
		new:Activate()
		new:SetPlayer(self:GetOwner())

		local doScaleTextures = self:GetClientNumber("texscale")
		if doScaleTextures > 0 then
			new:SetTextureScale(PowerOfTwo(math.Clamp(doScaleTextures, 4, 128)))
		end

		duplicator.StoreEntityModifier(new, "material", { MaterialOverride = "models/debug/debugwhite" })

		self:GetOwner():AddCount("gmod_ent_p2m", new)
		self:GetOwner():AddCleanup("gmod_ent_p2m", new)
		self:GetOwner():ChatPrint("You can edit this prop2mesh controller using the context menu (hold C and right click it).")

		undo.Create("gmod_ent_p2m")
			undo.AddEntity(new)
			undo.SetPlayer(self:GetOwner())
		undo.Finish()

		return true
	end

	return false
end


-- -----------------------------------------------------------------------------
-- TOOL: Right Click - Select entities
local function ValidController(ply, ent)
	if not IsValid(ent) then
		return false
	end
	if ent:GetClass() ~= "gmod_ent_p2m" then
		return false
	end
	if not IsPropOwner(ply, ent, game.SinglePlayer()) then
		return false
	end
	return true
end

function TOOL:RightClick(trace)
	if CLIENT then
		return true
	end

	if self:GetStage() == 0 then
		if not ValidController(self:GetOwner(), trace.Entity) then
			self:GetOwner():ChatPrint("Select a prop2mesh controller first!")
			return false
		end

		self.Controller = trace.Entity
		self.Controller.p2m_oldmode = self.Controller:GetRenderMode()
		self.Controller.p2m_oldcolor = self.Controller:GetColor()
		self.Controller:SetRenderMode(RENDERMODE_TRANSALPHA)
		self.Controller:SetColor(colors.controller)

		self.Controller:CallOnRemove("p2m_controller", function(e)
			for ent, _ in pairs(self.CookieJar) do
				self:DeselectEntity(ent)
			end
			self.CookieJar = {}
			self.Controller = nil
		end)

		self:SetStage(1)

		return true
	end

	if self:GetStage() == 1 then
		if trace.Entity ~= self.Controller then
			if self:GetOwner():KeyDown(IN_SPEED) or self:GetOwner():KeyDown(IN_WALK) then
				local byMat, byCol
				if IsValid(trace.Entity) then
					if self:GetClientNumber("bymaterial") == 1 then
						byMat = trace.Entity:GetMaterial()
					end
					if self:GetClientNumber("bycolor") == 1 then
						if self.CookieJar[trace.Entity] then
							byCol = self.CookieJar[trace.Entity].Color
						else
							byCol = trace.Entity:GetColor()
						end
					end
				end
				local group
				if self:GetOwner():KeyDown(IN_SPEED) then
					local radius = math.Clamp(self:GetClientNumber("radius"), 0, 1000)
					group = ents.FindInSphere(trace.HitPos, radius)
				else
					if not IsValid(trace.Entity) then
						return
					end
					group = trace.Entity:GetChildren()
				end
				if not group then
					return
				end
				for _, ent in pairs(group) do
					if byMat then
						if ent:GetMaterial() ~= byMat then
							continue
						end
					end
					if byCol then
						local color = ent:GetColor()
						if color.a ~= byCol.a or color.r ~= byCol.r or color.g ~= byCol.g or color.b ~= byCol.b then
							continue
						end
					end
					self:SelectEntity(ent, false)
				end
			else
				if self.CookieJar[trace.Entity] then
					self:DeselectEntity(trace.Entity, false)
					return true
				end
				self:SelectEntity(trace.Entity, false)
			end
			return true
		else
			if self.Controller.BuildFromTable then
				self.Controller:BuildFromTable(table.GetKeys(self.CookieJar))
			end
			for ent, _ in pairs(self.CookieJar) do
				self:DeselectEntity(ent)
			end
			self.CookieJar = {}
			self.Controller:RemoveCallOnRemove("p2m_controller")
			self.Controller:SetRenderMode(self.Controller.p2m_oldmode)
			self.Controller:SetColor(self.Controller.p2m_oldcolor)
			self.Controller = nil
			self:SetStage(0)
		end

		return false
	end

	return true
end


-- -----------------------------------------------------------------------------
-- TOOL: Reload - Clearing selection or resetting controller
function TOOL:Reload(trace)
	if CLIENT then
		return true
	end

	for ent, _ in pairs(self.CookieJar) do
		self:DeselectEntity(ent)
	end
	self.CookieJar = {}
	if IsValid(self.Controller) then
		self.Controller:RemoveCallOnRemove("p2m_controller")
		self.Controller:SetRenderMode(self.Controller.p2m_oldmode)
		self.Controller:SetColor(self.Controller.p2m_oldcolor)
		self.Controller = nil
	end
	self:SetStage(0)

	return false
end


-- -----------------------------------------------------------------------------
-- Client
if SERVER then return end

-- TOOL: Language
language.Add("tool.gmod_tool_p2m.listname", "Prop to Mesh")
language.Add("tool.gmod_tool_p2m.name", "Prop to Mesh")
language.Add("tool.gmod_tool_p2m.desc", "Converts groups of props to a single clientside mesh.")
language.Add("Undone_gmod_ent_p2m", "Undone P2M controller")
language.Add("Cleaned_gmod_ent_p2m", "Cleaned up P2M controller")
language.Add("Cleanup_gmod_ent_p2m", "P2M controllers")

TOOL.Information = {}

local function ToolInfo(name, desc, stage)
	table.insert(TOOL.Information, {
		name = name,
		stage = stage,
	})
	language.Add("tool.gmod_tool_p2m." .. name, desc)
end

-- left click
ToolInfo("left_1", "Spawn a new mesh controller", 0)

-- Right click
ToolInfo("right_1", "Select a mesh controller", 0)
ToolInfo("right_2a", "Select a single entity, select the mesh controller again to finalize", 1)
ToolInfo("right_2b", "Hold SPRINT key to area select", 1)
ToolInfo("right_2c", "Hold WALK key to select by parent", 1)
ToolInfo("right_2d", "Deselect all entities", 1)

-- Reload
ToolInfo("reload_1", "Deselect all entities", 0)


-- -----------------------------------------------------------------------------
-- TOOL: CPanel
function TOOL.BuildCPanel(self)
	local panel = self
	panel:SetName("P2M - Tool Behavior")

	panel:NumSlider("Area radius select", "gmod_tool_p2m_radius", 0, 1000)
	panel:ControlHelp("Hold shift while right clicking to select all entities within this radius of your click position")
	panel:Help("You can further filter your radius selection with these options")
	panel:CheckBox("Select entities with the same material", "gmod_tool_p2m_bymaterial")
	panel:CheckBox("Select entities with the same color", "gmod_tool_p2m_bycolor")
	panel:CheckBox("Ignore invisible entities", "gmod_tool_p2m_ignore_invisible")
	panel:CheckBox("Ignore parented entities", "gmod_tool_p2m_ignore_parented")
	panel:CheckBox("Ignore constrained entities", "gmod_tool_p2m_ignore_constrained")
	panel:CheckBox("Ignore prop_physics", "gmod_tool_p2m_ignore_props")
	panel:CheckBox("Ignore gmod_wire_hologram", "gmod_tool_p2m_ignore_holos")

	local panel = vgui.Create("DForm")
	panel:SetName("P2M - Experimental")
	self:AddPanel(panel)
	local tex = panel:NumSlider("Texture scale", "gmod_tool_p2m_texscale", 0, 128, 0)
	tex.OnValueChanged = function(_, value)
		if value < 2 then
			if tex:GetValue() ~= 0 then
				tex:SetValue(0)
			end
		else
			value = PowerOfTwo(value)
			if tex:GetValue() ~= value then
				tex:SetValue(value)
			end
		end
	end
	panel:ControlHelp("Attempts to uniformly rescale texture coordinates")

	local panel = vgui.Create("DForm")
	panel:SetName("P2M - Clientside Options")
	self:AddPanel(panel)

	panel:NumSlider("Mesh build speed", "p2m_build_time", 0.001, 0.1, 3)
	panel:ControlHelp("This sets the maximum time between frames during the mesh building process")
	panel:CheckBox("Allow texture scaling", "p2m_allow_texscale")
	panel:CheckBox("Disable rendering", "p2m_disable_rendering")
	panel:Button("Refresh all", "p2m_refresh_all")
end

local white = Color(255, 255, 255, 255)
local black = Color(0, 0, 0, 255)

function TOOL:DrawAxis(ent, alpha)
	local pos = ent:GetPos()
	local scr = pos:ToScreen()

	local f = (pos + ent:GetForward()*3):ToScreen()
	surface.SetDrawColor(0, 255, 0, alpha)
	surface.DrawLine(scr.x, scr.y, f.x, f.y)

	local r = (pos + ent:GetRight()*3):ToScreen()
	surface.SetDrawColor(255, 0, 0, alpha)
	surface.DrawLine(scr.x, scr.y, r.x, r.y)

	local u = (pos + ent:GetUp()*3):ToScreen()
	surface.SetDrawColor(0, 0, 255, alpha)
	surface.DrawLine(scr.x, scr.y, u.x, u.y)
end

function TOOL:DrawHUD(test)
	local trace = LocalPlayer():GetEyeTrace()
	if not trace.Hit then
		return
	end
	if not trace.Entity or trace.Entity:IsWorld() then
		return
	end

	if trace.Entity:GetClass() == "gmod_ent_p2m" then
		self:DrawAxis(trace.Entity, 255)

		local pos = trace.Entity:GetPos()
		local scr = pos:ToScreen()

		scr.x = math.Round(scr.x) - 48
		scr.y = math.Round(scr.y) - 96

		draw.DrawText("models: " .. (trace.Entity.models and #trace.Entity.models or 0), "BudgetLabel", scr.x, scr.y, white, TEXT_ALIGN_LEFT)
		draw.DrawText("triangles: " .. (trace.Entity.tricount or 0), "BudgetLabel", scr.x, scr.y + 16, white, TEXT_ALIGN_LEFT)
	end
end
