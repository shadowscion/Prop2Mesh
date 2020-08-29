-- -----------------------------------------------------------------------------
TOOL.Category   = "Render"
TOOL.Name       = "#tool.prop2mesh.name"
TOOL.Command    = nil

local ent_class = "gmod_ent_p2m"


-- -----------------------------------------------------------------------------
if SERVER then

	list.Add( "OverrideMaterials", "p2m/grid")

	TOOL.Controller = nil
	TOOL.Selection  = {}

	local controller_col = Color(0, 0, 255, 125)
	local controller_mat = "models/debug/debugwhite"

	local class_whitelist = {
		prop_physics       = { col = Color(255, 125, 125, 125), mat = "models/debug/debugwhite" },
		starfall_hologram  = { col = Color(255, 125, 255, 125), mat = "models/debug/debugwhite" },
		gmod_wire_hologram = { col = Color(125, 255, 125, 125), mat = "models/debug/debugwhite", IsOwner = function(ply, ent) return ent:GetPlayer() == ply end },
	}


	-- -----------------------------------------------------------------------------
	local function IsOwner(ply, ent)

		if CPPI and ent:CPPIGetOwner() ~= ply then
			return false
		end

		return true

	end

	local function CanSelect(ply, ent)

		local disp = class_whitelist[ent:GetClass()]
		if not disp then
			return false
		end

		local checkOwner = disp.IsOwner or IsOwner
		if not checkOwner(ply, ent) then
			return false
		end

		return disp

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

	local function MakeEnt(trace, owner, tscale, mscale)

		local ent = ents.Create(ent_class)

		ent:SetModel("models/hunter/plates/plate.mdl")
		ent:SetMaterial("p2m/grid")
		ent:SetPos(trace.HitPos)
		ent:SetAngles(GetHitAngle(trace))
		ent:Spawn()
		ent:Activate()

		ent:SetPlayer(owner)
		ent:SetTextureScale(tscale)
		ent:SetMeshScale(mscale)

		undo.Create(ent_class)
			undo.AddEntity(ent)
			undo.SetPlayer(owner)
		undo.Finish()

		duplicator.StoreEntityModifier(ent, "material", { MaterialOverride = ent:GetMaterial() })

		return ent

	end

	-- -----------------------------------------------------------------------------
	function TOOL:Deploy()

		if self:GetStage() == 0 and IsValid(self.Controller) and next(self.Selection) ~= nil then
			self:SetStage(1)
		end

	end


	-- -----------------------------------------------------------------------------
	function TOOL:LeftClick(trace)

		if not trace.Hit then
			return false
		end

		if self:GetStage() == 0 then
			if trace.HitWorld or IsOwner(self:GetOwner(), trace.Entity) then
				MakeEnt(trace, self:GetOwner(), self:GetClientNumber("o_texture_scale"), self:GetClientNumber("o_mesh_scale"))
				return true
			end
		elseif trace.Entity == self.Controller and next(self.Selection) == nil and self:GetOwner():KeyDown(IN_USE) then
			self.Controller:SetTextureScale(self:GetClientNumber("o_texture_scale"))
			self:SetController()
			self:SetStage(0)
			return true
		end

		return false

	end


	-- -----------------------------------------------------------------------------
	function TOOL:RightClick(trace)

		if not trace.Hit then
			return false
		end

		if self:GetStage() == 0 and not self.Controller then
			if IsOwner(self:GetOwner(), trace.Entity) and trace.Entity:GetClass() == ent_class then
				self:SetController(trace.Entity)
				self:SetStage(1)
				return true
			end
		end

		if self:GetStage() == 1 and self.Controller then
			if next(self.Selection) == nil then
				if self:GetOwner():KeyDown(IN_USE) then
					self.Controller:SetTextureScale(self:GetClientNumber("o_texture_scale"))
					self:SetController()
					self:SetStage(0)
					return true
				end
			end

			if trace.Entity == self.Controller and next(self.Selection) ~= nil then
				self:Finalize()
			else
				if self:GetOwner():KeyDown(IN_SPEED) then
					self:SelectByFilter(trace, ents.FindInSphere(trace.HitPos, math.Clamp(self:GetClientNumber("s_radius"), 0, 2048)))
				elseif self:GetOwner():KeyDown(IN_WALK) then
					self:SelectByFilter(trace, trace.Entity:GetChildren())
				else
					if self:GetClientNumber("s_ignore_props") == 1 and self:GetClientNumber("s_ignore_holos") == 0 then
						local class_whitelist = {
							gmod_wire_hologram = true,
							starfall_hologram = true,
						}

						local find = {}
						local cone = ents.FindInCone(trace.StartPos, trace.Normal, trace.HitPos:Distance(trace.StartPos) * 2, math.cos(math.rad(3)))

						for k, ent in ipairs(cone) do
							if class_whitelist[ent:GetClass()] and CanSelect(self:GetOwner(), ent) then
								find[#find + 1] = { ent = ent, len = (trace.StartPos - ent:GetPos()):LengthSqr() }
							end
						end

						for k, v in SortedPairsByMemberValue(find, "len") do
							if self.Selection[v.ent] then
								self:DeselectEntity(v.ent)
							else
								self:SelectEntity(v.ent)
							end
							break
						end
					else
						if self.Selection[trace.Entity] then
							self:DeselectEntity(trace.Entity)
						else
							self:SelectEntity(trace.Entity)
						end
					end
				end
			end

			return true
		end

		return false

	end


	-- -----------------------------------------------------------------------------
	function TOOL:Reload(trace)

		if self:GetStage() == 0 or next(self.Selection) == nil then
			self:SetController()
			self:SetStage(0)
		end

		for ent, _ in pairs(self.Selection) do
			self:DeselectEntity(ent)
		end
		self.Selection = {}

	end


	-- -----------------------------------------------------------------------------
	function TOOL:SelectByFilter(trace, group)

		local ign_invis       = self:GetClientNumber("s_ignore_invisible") ~= 0
		local ign_parented    = self:GetClientNumber("s_ignore_parented") ~= 0
		local ign_constrained = self:GetClientNumber("s_ignore_constrained") ~= 0

		local class_blacklist  = {
			prop_physics       = self:GetClientNumber("s_ignore_props") ~= 0,
			starfall_hologram  = self:GetClientNumber("s_ignore_holos") ~= 0,
			gmod_wire_hologram = self:GetClientNumber("s_ignore_holos") ~= 0,
		}

		local by_col
		local by_mat
		if trace.Entity and not trace.HitWorld then
			if self:GetClientNumber("s_mask_by_color") ~= 0 then
				by_col = self.Selection[trace.Entity] and self.Selection[trace.Entity].old_col or trace.Entity:GetColor()
			end
			if self:GetClientNumber("s_mask_by_material") ~= 0 then
				by_mat = self.Selection[trace.Entity] and self.Selection[trace.Entity].old_mat or trace.Entity:GetMaterial()
			end
		end

		for k, ent in ipairs(group) do
			if self.Selection[ent] then
				goto skip
			end

			-- whitelist
			local disp = CanSelect(self:GetOwner(), ent)
			if not disp then
				goto skip
			end

			-- filters
			if class_blacklist[ent:GetClass()] then
				goto skip
			end
			if ign_parented and ent:GetParent():IsValid() then
				goto skip
			end
			if ign_constrained and ent:IsConstrained() then
				goto skip
			end
			if ign_invis and ent:GetColor().a == 0 then
				goto skip
			end

			-- masks
			if by_col then
				local c = ent:GetColor()
				if c.r ~= by_col.r or c.g ~= by_col.g or c.b ~= by_col.b or c.a ~= by_col.a then
					goto skip
				end
			end
			if by_mat and ent:GetMaterial() ~= by_mat then
				goto skip
			end

			-- select
			self.Selection[ent] = {
				old_col = ent:GetColor(),
				old_mat = ent:GetMaterial(),
				old_mod = ent:GetRenderMode(),
			}
			if disp.col then
				ent:SetColor(disp.col)
				ent:SetRenderMode(RENDERMODE_TRANSALPHA)
			end
			if disp.mat then
				ent:SetMaterial(disp.mat)
			end
			ent:CallOnRemove("p2mtoolsel", function(e)
				self.Selection[e] = nil
			end)

			::skip::
		end

	end


	-- -----------------------------------------------------------------------------
	function TOOL:SelectEntity(ent)
		if self.Selection[ent] then
			return
		end

		local disp = CanSelect(self:GetOwner(), ent)
		if not disp then
			return
		end

		self.Selection[ent] = {
			old_col = ent:GetColor(),
			old_mat = ent:GetMaterial(),
			old_mod = ent:GetRenderMode(),
		}
		if disp.col then
			ent:SetColor(disp.col)
			ent:SetRenderMode(RENDERMODE_TRANSALPHA)
		end
		if disp.mat then
			ent:SetMaterial(disp.mat)
		end
		ent:CallOnRemove("p2mtoolsel", function(e)
			self.Selection[e] = nil
		end)

	end


	-- -----------------------------------------------------------------------------
	function TOOL:DeselectEntity(ent)

		if not self.Selection[ent] then
			return
		end

		ent:SetColor(self.Selection[ent].old_col)
		ent:SetMaterial(self.Selection[ent].old_mat)
		ent:SetRenderMode(self.Selection[ent].old_mod)
		ent:RemoveCallOnRemove("p2mtoolsel")
		self.Selection[ent] = nil

	end


	-- -----------------------------------------------------------------------------
	function TOOL:SetController(ent)

		if self.Controller then
			self.Controller:SetColor(self.Controller.old_col)
			self.Controller:SetMaterial(self.Controller.old_mat)
			self.Controller:SetRenderMode(self.Controller.old_mod)
			self.Controller.old_col = nil
			self.Controller.old_mat = nil
			self.Controller.old_mod = nil
			self.Controller:RemoveCallOnRemove("p2mtoolctrl")
			self.Controller = nil

			return

		elseif ent then
			self.Controller = ent
			self.Controller.old_col = self.Controller:GetColor()
			self.Controller.old_mat = self.Controller:GetMaterial()
			self.Controller.old_mod = self.Controller:GetRenderMode()
			self.Controller:SetColor(controller_col)
			self.Controller:SetMaterial(controller_mat)
			self.Controller:SetRenderMode(RENDERMODE_TRANSALPHA)
			self.Controller:CallOnRemove("p2mtoolctrl", function()
				self.Controller = nil
				for ent, _ in pairs(self.Selection) do
					self:DeselectEntity(ent)
				end
				self.Selection = {}
				self:SetStage(0)
			end)
		end

		return self.Controller

	end


	-- -----------------------------------------------------------------------------
	local special = {}
	special.prop_physics = function(entry, ent)

		local scale = ent:GetManipulateBoneScale(0)
		if scale.x ~= 1 or scale.y ~= 1 or scale.z ~= 1 then
			entry.scale = scale
		end

		local clips = ent.ClipData or ent.EntityMods and ent.EntityMods.clips
		if clips then
			for _, clip in ipairs(clips) do
				if not clip.n or not clip.d then
					goto invalid
				end
				if clip.inside then
					entry.inv = true
				end
				if not entry.clips then
					entry.clips = {}
				end

				local normal = clip.n:Forward()
				entry.clips[#entry.clips + 1] = { n = normal, d = clip.d + normal:Dot(ent:OBBCenter()) }

				::invalid::
			end
		end

	end
	special.gmod_wire_hologram = function(entry, ent)

		local holo
		for k, v in pairs(ent:GetTable().OnDieFunctions.holo_cleanup.Args[1].data.holos) do
			if v.ent == ent then
				holo = { scale = v.scale, clips = v.clips }
				break
			end
		end
		if not holo then
			return
		end

		entry.holo = true

		if holo.scale then
			if holo.scale.x ~= 1 or holo.scale.y ~= 1 or holo.scale.z ~= 1 then
				entry.scale = Vector(holo.scale)
			end
		end

		if holo.clips then
			for k, v in pairs(holo.clips) do
				if v.localentid == 0 then -- this is a global clip... what to do here?
					goto invalid
				end
				local clipTo = Entity(v.localentid)
				if not IsValid(clipTo) then
					goto invalid
				end
				if not entry.clips then
					entry.clips = {}
				end

				local normal = ent:WorldToLocal(clipTo:LocalToWorld(v.normal:GetNormalized()) - clipTo:GetPos() + ent:GetPos())
				local origin = ent:WorldToLocal(clipTo:LocalToWorld(v.origin))
				entry.clips[#entry.clips + 1] = { n = normal, d = normal:Dot(origin) }

				::invalid::
			end
		end

	end
	special.starfall_hologram = function(entry, ent)

		entry.holo = true

		if ent.scale then
			entry.scale = Vector(ent.scale)
		end

		if ent.clips then
			for k, v in pairs(ent.clips) do
				if not IsValid(v.entity) then
					goto invalid
				end
				if not entry.clips then
					entry.clips = {}
				end

				local normal = ent:WorldToLocal(v.entity:LocalToWorld(v.normal:GetNormalized()) - v.entity:GetPos() + ent:GetPos())
				local origin = ent:WorldToLocal(v.entity:LocalToWorld(v.origin))
				entry.clips[#entry.clips + 1] = { n = normal, d = normal:Dot(origin) }

				::invalid::
			end
		end

	end


	-- -----------------------------------------------------------------------------
	local function getBodygroupMask(ent)

		local mask = 0
		local offset = 1

		for index = 0, ent:GetNumBodyGroups() - 1 do
			local bg = ent:GetBodygroup(index)
			mask = mask + offset * bg
			offset = offset * ent:GetBodygroupCount(index)
		end

		return mask

	end


	-- -----------------------------------------------------------------------------
	function TOOL:Finalize()

		local pos = self.Controller:GetPos()
		local ang = self.Controller:GetAngles()

		if self:GetClientNumber("o_autocenter") == 1 or self.Controller:GetMeshScale() ~= 1 then
			pos = Vector()
			local num = 0
			for ent, _ in pairs(self.Selection) do
				pos = pos + ent:GetPos()
				num = num + 1
			end
			pos = pos * (1 / num)
		end

		local data = {}
		for ent, _ in pairs(self.Selection) do
			local entry = {
				mdl = string.lower(ent:GetModel())
			}
			entry.pos, entry.ang = WorldToLocal(ent:GetPos(), ent:GetAngles(), pos, ang)

			local bgrp = getBodygroupMask(ent)
			if bgrp ~= 0 then
				entry.bgrp = bgrp
			end

			local hasSpecial = special[ent:GetClass()]
			if hasSpecial then
				hasSpecial(entry, ent)
			end

			data[#data + 1] = entry
		end

		self.Controller:SetModelsFromTable(data)

		self:SetController()
		for ent, _ in pairs(self.Selection) do
			self:DeselectEntity(ent)
		end
		self.Selection = {}
		self:SetStage(0)

	end

	return

end


-- -----------------------------------------------------------------------------
function TOOL:LeftClick(trace)
	return true
end

function TOOL:RightClick(trace)
	return true
end

function TOOL:Reload(trace)
	return true
end


-- -----------------------------------------------------------------------------
language.Add("tool.prop2mesh.name", "Prop to Mesh")
language.Add("tool.prop2mesh.desc", "Convert groups of props into a single mesh")

TOOL.Information = {
	{ name = "left_spawn",         stage = 0 },
	{ name = "right_select",       stage = 0 },
	{ name = "right_select_rents", stage = 1, icon2 = "gui/key.png" },
	{ name = "right_select_pents", stage = 1, icon2 = "gui/key.png" },
	{ name = "reload_deselect1",   stage = 1 },
	{ name = "right_select_ctrl",  stage = 1 },
	{ name = "left_select_upd",   stage = 1, icon2 = "gui/key.png" },
}

language.Add("tool.prop2mesh.left_spawn", "Left click to spawn a controller")
language.Add("tool.prop2mesh.right_select", "Right click to select a controller")
language.Add("tool.prop2mesh.right_select_rents", "Hold SPRINT key and right click to filter and select multiple entities")
language.Add("tool.prop2mesh.right_select_pents", "Hold WALK key and right click to filter and select entities parented to target")
language.Add("tool.prop2mesh.left_select_upd", "Hold USE and left click a selected controller to update texture scale")
language.Add("tool.prop2mesh.reload_deselect1", "Deselect all entities, again to deselect the controller")
language.Add("tool.prop2mesh.right_select_ctrl", "Right click the selected controller again to finalize")

local ConVars = {
	["s_radius"]             = 512,
	["s_ignore_parented"]    = 0,
	["s_ignore_constrained"] = 0,
	["s_ignore_invisible"]   = 1,
	["s_ignore_holos"]       = 0,
	["s_ignore_props"]       = 0,
	["s_mask_by_color"]      = 0,
	["s_mask_by_material"]   = 0,
	["o_texture_scale"]      = 0,
	["o_mesh_scale"]         = 1,
	["o_autocenter"]         = 0,
	["t_hud_enabled"]        = 1,
}
TOOL.ClientConVar = ConVars

local help_font = "DebugFixedSmall"

local function SetDefaults()

	for var, _ in pairs(ConVars) do
		local convar = GetConVar("prop2mesh_" .. var)
		if convar then
			convar:Revert()
		end
	end

	GetConVar("prop2mesh_build_time"):Revert()

end


-- -----------------------------------------------------------------------------
local function DForm_ToolBehavior(self)

	local panel = vgui.Create("DForm")
	panel:SetName("Tool Behavior")

	local help = panel:Help("General filters")
	help:DockMargin(0, 0, 0, 0)
	help:SetFont(help_font)
	help.Paint = function(_, w, h)
		surface.SetDrawColor(0, 0, 0, 255)
		surface.DrawLine(0, h - 1, w, h - 1)
	end

	panel:CheckBox("Select entities with same color", "prop2mesh_s_mask_by_color")
	panel:CheckBox("Select entities with same material", "prop2mesh_s_mask_by_material")
	panel:CheckBox("Ignore invisible entities", "prop2mesh_s_ignore_invisible")
	panel:CheckBox("Ignore parented entities", "prop2mesh_s_ignore_parented")
	panel:CheckBox("Ignore constrained entities", "prop2mesh_s_ignore_constrained")

	local help = panel:Help("Class filters")
	help:DockMargin(0, 0, 0, 0)
	help:SetFont(help_font)
		help.Paint = function(_, w, h)
		surface.SetDrawColor(0, 0, 0, 255)
		surface.DrawLine(0, h - 1, w, h - 1)
	end

	panel:CheckBox("Ignore props", "prop2mesh_s_ignore_props")
	panel:CheckBox("Ignore holos", "prop2mesh_s_ignore_holos")

	local help = panel:Help("Misc settings")
	help:DockMargin(0, 0, 0, 0)
	help:SetFont(help_font)
	help.Paint = function(_, w, h)
		surface.SetDrawColor(0, 0, 0, 255)
		surface.DrawLine(0, h - 1, w, h - 1)
	end

	panel:NumSlider("Selection radius", "prop2mesh_s_radius", 0, 2048, 0)
	panel:ControlHelp("Hold SPRINT while right clicking to select all unfiltered entities within this radius")

	panel:CheckBox("Enable tool HUD", "prop2mesh_t_hud_enabled")

	return panel

end


-- -----------------------------------------------------------------------------
local function DForm_EntityOptions(self)

	local panel = vgui.Create("DForm")
	panel:SetName("Entity Options")

	local slider = panel:NumSlider("Texture scale", "prop2mesh_o_texture_scale", 0, 128, 0)
	slider.Label:SetTooltip("Hold USE and left click a selected controller to update this")
	panel:ControlHelp("Uniformly rescale texture coordinates")

	local slider = panel:NumSlider("Mesh scale", "prop2mesh_o_mesh_scale", 0.01, 1, 2)
	slider.Label:SetTooltip("Note: scaled meshes always auto center")
	panel:ControlHelp("Rescale the entire mesh")

	local cbox = panel:CheckBox("Autocenter", "prop2mesh_o_autocenter")
	panel:ControlHelp("Center the mesh around average position of selection local to the controller")

	slider.OnValueChanged = function(_, value)
		if value ~= 1 then
			if not cbox:GetChecked() then
				cbox:SetChecked(true)
			end
			cbox.Button:SetDisabled(true)
		else
			cbox:SetChecked(cbox.Button.m_bValue)
			cbox.Button:SetDisabled(false)
		end
	end

	return panel

end


-- -----------------------------------------------------------------------------
local function DForm_ClientOptions(self)

	local panel = vgui.Create("DForm")
	panel:SetName("Client Options")

	local slider = panel:NumSlider("Mesh build speed", "prop2mesh_build_time", 0.001, 0.1, 3)
	panel:ControlHelp("Maximum time between frames while building a mesh")

	local cvar = GetConVar("prop2mesh_max_tris_softcap")
	local slider = panel:NumSlider("Triangle limit", "prop2mesh_max_tris_softcap", cvar:GetMin(), cvar:GetMax(), 0)
	slider:GetTextArea():SetWide(54)

	panel:ControlHelp("Limit drawing of triangles belonging to other players")

	panel:CheckBox("Disable rendering", "prop2mesh_disable_rendering")

	return panel

end


-- -----------------------------------------------------------------------------
local function DForm_Statistics(self)

	local panel = vgui.Create("DForm")
	panel:SetName("Statistics")
	panel:DockPadding(0, 0, 0, 10)

	local dtree = vgui.Create("DTree", panel)
	dtree:SetTall(128)
	dtree:Dock(FILL)
	panel:AddItem(dtree)

	dtree.OnNodeSelected = function()
		dtree:SetSelectedItem()
	end

	panel.Header.OnCursorEntered = function()
		dtree:Clear()
		local struct = {}
		for _, controller in ipairs(ents.FindByClass(ent_class)) do
			local owner = controller:GetPlayer()
			if IsValid(owner) then
				if not struct[owner] then
					struct[owner] = {
						root = dtree:AddNode(owner:Nick(), "icon16/user.png"),
						num_ctrl = 0,
						num_mdls = 0,
						num_tris = 0,
					}
					struct[owner].node_ctrl = struct[owner].root:AddNode("", "icon16/bullet_black.png")
					struct[owner].node_mdls = struct[owner].root:AddNode("", "icon16/bullet_black.png")
					struct[owner].node_tris = struct[owner].root:AddNode("", "icon16/bullet_black.png")
					struct[owner].root:SetExpanded(true, true)
				end

				struct[owner].num_ctrl = struct[owner].num_ctrl + 1
				struct[owner].num_mdls = struct[owner].num_mdls + controller:GetModelCount()
				struct[owner].num_tris = struct[owner].num_tris + controller:GetTriangleCount()

				struct[owner].node_ctrl:SetText(string.format("%d controllers", struct[owner].num_ctrl))
				struct[owner].node_mdls:SetText(string.format("%d models", struct[owner].num_mdls))
				struct[owner].node_tris:SetText(string.format("%d triangles", struct[owner].num_tris))
			end
		end
	end

	local button = panel:Button("Output info to console")
	button.DoClick = p2mlib.dump

	return panel

end


-- -----------------------------------------------------------------------------
TOOL.BuildCPanel = function(self)

	local button = self:Button("Reset tool options")
	button.DoClick = SetDefaults

	self:AddPanel(DForm_ToolBehavior(self))
	self:AddPanel(DForm_EntityOptions(self))
	self:AddPanel(DForm_ClientOptions(self))
	self:AddPanel(DForm_Statistics(self))

end


-- -----------------------------------------------------------------------------
local string = string
local render = render
local draw = draw

local overlay_font = "TargetID"
local overlay_color = Color(255,255,255)
local overlay_ent

function TOOL:DrawHUD()

	if self:GetClientNumber("t_hud_enabled") == 0 then
		overlay_ent = nil
		return
	end

	local trace = LocalPlayer():GetEyeTrace()
	if not trace.Hit then
		overlay_ent = nil
		return
	end

	if IsValid(overlay_ent) then

		if trace.Entity ~= overlay_ent and trace.Entity:GetClass() == ent_class then
			overlay_ent = trace.Entity
			return
		end

		local dir = overlay_ent:GetPos() - trace.StartPos
		if dir:LengthSqr() > 1000000 or (trace.HitPos - trace.StartPos):GetNormalized():Dot(dir:GetNormalized()) < 0.667 then
			overlay_ent = nil
			return
		end

		local pos = overlay_ent:GetPos()
		local ang = overlay_ent:GetAngles()

		cam.Start3D()
			local mins, maxs = overlay_ent:GetModelBounds()
			render.DrawWireframeBox(pos, ang, mins, maxs, overlay_ent.OutlineColor1)

			mins, maxs = overlay_ent:GetRenderBounds()
			render.DrawWireframeBox(pos, ang, mins, maxs, overlay_ent.OutlineColor1)
			render.SetColorMaterial()
			render.DrawBox(pos, ang, mins, maxs, overlay_ent.OutlineColor2)
		cam.End3D()

		overlay_color.r = overlay_ent.OutlineColor1.r
		overlay_color.g = overlay_ent.OutlineColor1.g
		overlay_color.b = overlay_ent.OutlineColor1.b

		local scr = pos:ToScreen()
		local x = math.Round(scr.x) - 64
		local y = math.Round(scr.y) - 128

		local owner = overlay_ent:GetPlayer()
		draw.DrawText(string.format("owner: %s", IsValid(owner) and owner:Nick() or "none"), overlay_font, x, y, overlay_color, TEXT_ALIGN_LEFT)
		draw.DrawText(string.format("models: %d", overlay_ent:GetModelCount()), overlay_font, x, y + 16, overlay_color, TEXT_ALIGN_LEFT)
		draw.DrawText(string.format("triangles: %d", overlay_ent:GetTriangleCount()), overlay_font, x, y + 32, overlay_color, TEXT_ALIGN_LEFT)
		draw.DrawText(string.format("tex scale: %d", overlay_ent:GetTextureScale()), overlay_font, x, y + 48, overlay_color, TEXT_ALIGN_LEFT)
		draw.DrawText(string.format("mesh scale: %d", overlay_ent:GetMeshScale()), overlay_font, x, y + 64, overlay_color, TEXT_ALIGN_LEFT)

	else

		if trace.Entity:GetClass() == ent_class then
			overlay_ent = trace.Entity
		end

	end

end
