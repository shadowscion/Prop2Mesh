-- -----------------------------------------------------------------------------
include("shared.lua")
include("p2m/p2mlib.lua")
include("p2m/editor.lua")

local notification = notification
local coroutine = coroutine
local surface = surface
local string = string
local render = render
local table = table
local pairs = pairs
local draw = draw
local next = next
local cam = cam
local net = net


-- -----------------------------------------------------------------------------
local p2mlib = p2mlib

p2mlib.getmodels = p2mlib.getmodels or {}
p2mlib.getmeshes = p2mlib.getmeshes or {}
p2mlib.models    = p2mlib.models or {}
p2mlib.meshes    = p2mlib.meshes or {}
p2mlib.users     = p2mlib.users or {}
p2mlib.marks     = p2mlib.marks or {}

p2mlib.debug = false
concommand.Add("prop2mesh_debug", function()
	p2mlib.debug = not p2mlib.debug
end)

local meshBuildTime = CreateClientConVar("prop2mesh_build_time", 0.001, true, false, "Lower to reduce stuttering", 0.001, 0.1)
local globalDisable = CreateClientConVar("prop2mesh_disable_rendering", "0", true, false)
local modelHide = CreateClientConVar("prop2mesh_disable_cubes", "0", true, false)


-- -----------------------------------------------------------------------------
p2mlib.hardcap_current = p2mlib.hardcap_current or 0
local hardcap_maximum = 10000000

local softcap_current = 0
local softcap_maximum = CreateClientConVar("prop2mesh_max_tris_softcap", 1000000, true, false, "max number of triangles on screen", 0, hardcap_maximum)


-- -----------------------------------------------------------------------------
local inMenu, globalSuppress, fakeModel, fakeModelHide
hook.Add("OnSpawnMenuOpen", "p2mlib.suppress", function()
	inMenu = true
end)
hook.Add("OnSpawnMenuClose", "p2mlib.suppress", function()
	inMenu = false
end)
hook.Add("PreRender", "P2M.PreRender", function()
	if not IsValid(fakeModel) then
		fakeModel = ClientsideModel("models/hunter/plates/plate.mdl")
		fakeModel:SetNoDraw(true)
	end
	fakeModelHide = modelHide:GetBool()
	globalSuppress = inMenu or gui.IsGameUIVisible() or FrameTime() == 0
	softcap_current = 0
end)


-- -----------------------------------------------------------------------------
local splitViews = {
	function (self) return -self:GetForward() end,
	function (self) return self:GetForward() end,
	function (self) return -self:GetRight() end,
	function (self) return self:GetRight() end,
	function (self) return -self:GetUp() end,
	function (self) return self:GetUp() end,
	function() return EyeVector() end,
}

local enableNotify = GetConVar("prop2mesh_t_hud_enabled")
local enableSplitView

concommand.Add("prop2mesh_splitview", function(ply, cmd, args)

	if enableSplitView and enableSplitView == #splitViews then
		enableSplitView = nil
		if enableNotify:GetBool() then
			notification.AddLegacy("P2M: Split view off", NOTIFY_HINT, 2)
		end
		return
	end

	if args[1] then
		local enum = math.Clamp(math.floor(tonumber(args[1])), 0, #splitViews)
		if enum == 0 then
			enableSplitView = nil
			if enableNotify:GetBool() then
				notification.AddLegacy("P2M: Split view off", NOTIFY_HINT, 2)
			end
			return
		end
		enableSplitView = enum
	else
		enableSplitView = (enableSplitView or 0) + 1
	end

	if enableNotify:GetBool() then
		notification.AddLegacy(string.format("P2M: Split view mode %d", enableSplitView), NOTIFY_HINT, 2)
	end
end)


-- -----------------------------------------------------------------------------
local drawflat = Material("debug/debugdrawflat")

function ENT:Draw()

	if globalDisable:GetBool() or globalSuppress then
		if self.MeshGroup or self.Mesh then
			self.MeshGroup = nil
			self.Mesh = nil
		end
		self:DrawOutline()
		self:DrawModel()
		return
	end

	if self.checksoftcap then
		softcap_current = softcap_current + self:GetTriangleCount()
		self.suppress = softcap_current > softcap_maximum:GetInt()
	end

	if self.suppress or self.checkmodels or self.checkmeshes then
		if self.MeshGroup or self.Mesh then
			self.MeshGroup = nil
			self.Mesh = nil
		end
		self:DrawOutline()
		self:DrawModel()
		return
	end

	if enableSplitView and self:GetPlayer() == LocalPlayer() then
		self:DrawSplitView()
	else
		if self.Mesh then
			if self.doFlash then
				render.ModelMaterialOverride(drawflat)
			else
				render.ModelMaterialOverride(self.MaterialMeshes)
			end
			self:DrawFakeController()
			self:DrawModel()
			render.ModelMaterialOverride(nil)
		elseif self.MeshGroup then
			self:DrawModel()
			render.SetMaterial(self.MaterialMeshes)
			self:DrawMeshGroup()
		else
			self:DrawModel()
		end
	end

end


-- -----------------------------------------------------------------------------
local wireframe = Material("models/debug/debugwhite")

function ENT:DrawSplitView()

	if not self.Mesh and not self.MeshGroup then
		self:DrawModel()
		return
	end

	local state  = render.EnableClipping(true)

	local mins, maxs = self:GetRenderBounds()
	local origin = self:LocalToWorld((mins + maxs)*0.5)
	local normal = splitViews[enableSplitView](IsValid(self:GetParent()) and self:GetParent() or self)
	local dirdot = normal:Dot(origin)

	if self.Mesh then

		render.ModelMaterialOverride(self.MaterialMeshes)
		self:DrawFakeController()
		render.PushCustomClipPlane(normal, dirdot)
		self:DrawModel()
		render.PopCustomClipPlane()

		render.PushCustomClipPlane(-normal, -dirdot)
		render.ModelMaterialOverride(wireframe)
		render.SetColorModulation(1, 1, 1)
		render.SetBlend(0.025)
		render.SuppressEngineLighting(true)
		self:DrawModel()
		render.SuppressEngineLighting(false)
		render.SetBlend(1)
		render.PopCustomClipPlane()
		render.ModelMaterialOverride(nil)

	else

		render.PushCustomClipPlane(normal, dirdot)
		self:DrawModel()
		render.SetMaterial(self.MaterialMeshes)
		self:DrawMeshGroup()
		render.PopCustomClipPlane()

		render.PushCustomClipPlane(-normal, -dirdot)
		render.SetColorModulation(1, 1, 1)
		render.SetBlend(0.025)
		render.SuppressEngineLighting(true)
		self:DrawModel()
		render.SetMaterial(wireframe)
		self:DrawMeshGroup()
		render.SuppressEngineLighting(false)
		render.SetBlend(1)
		render.PopCustomClipPlane()

	end

	render.EnableClipping(state)

end


-- -----------------------------------------------------------------------------
local str_hidemodel = "P2M_HIDEMODEL"
function ENT:DrawFakeController()
	if not fakeModel or fakeModelHide or self:GetNWBool(str_hidemodel) then
		return
	end

	fakeModel:SetPos(self:GetPos())
	fakeModel:SetAngles(self:GetAngles())
	fakeModel:SetupBones()
	fakeModel:DrawModel()
end


-- -----------------------------------------------------------------------------
function ENT:DrawOutline()

	local mins, maxs = self:GetRenderBounds()
	render.DrawWireframeBox(self:GetPos(), self:GetAngles(), mins, maxs, self.OutlineColor1, true)

	render.SetColorMaterial()
	render.DrawBox(self:GetPos(), self:GetAngles(), mins, maxs, self.OutlineColor2, true)

	mins, maxs = self:GetModelBounds()
	render.DrawWireframeBox(self:GetPos(), self:GetAngles(), mins, maxs, self.OutlineColor1, true)

end


-- -----------------------------------------------------------------------------
function ENT:DrawMeshGroup()

	if not self.MeshGroup then
		return
	end

	local matrix = self:GetWorldTransformMatrix()
	if self.ScaleV then
		matrix:SetScale(self.ScaleV)
	end

	cam.PushModelMatrix(matrix)
		for i = 1, #self.MeshGroup do
			self.MeshGroup[i]:Draw()
		end
	cam.PopModelMatrix()

end


-- -----------------------------------------------------------------------------
function ENT:GetRenderMesh()

	return self.Mesh

end


-- -----------------------------------------------------------------------------
function ENT:GetRenderMaterial()

	local mat = self:GetMaterial()

	if self.MaterialName ~= mat then
		self.MaterialName = mat
		self.MaterialMeshes = self.MaterialName == "" and self.MaterialDefault or Material(self.MaterialName)
	end

end


-- -----------------------------------------------------------------------------
function ENT:GetRenderMeshes()

	local parts = p2mlib.GetMeshes(self:GetCRC(), self:GetTextureScale())
	if parts and #parts > 0 then
		if #parts == 1 then
			self.Mesh = { Mesh = parts[1], Material = self.MaterialDefault, Matrix = self.ScaleM }
		else
			self.MeshGroup = parts
			self.Mesh = nil
		end
	else
		self.MeshGroup = nil
		self.Mesh = nil
	end

end


-- -----------------------------------------------------------------------------
function ENT:GetRenderScale()
	local scalar = self:GetMeshScale()
	if self.ScaleN ~= scalar then
		self.ScaleN = scalar
		if scalar == 1 then
			self.ScaleV = nil
			self.ScaleM = nil
		else
			self.ScaleV = Vector(scalar, scalar, scalar)
			self.ScaleM = Matrix()
			self.ScaleM:SetScale(self.ScaleV)
		end
	end
end


-- -----------------------------------------------------------------------------
function ENT:Think()

	if globalDisable:GetBool() or globalSuppress or self.suppress then
		return
	end

	if self.checkmodels then
		self.checkmodels = p2mlib.RequestModels(self)
		self.checkmeshes = not self.checkmodels
		self.checksoftcap = self:GetPlayer() ~= LocalPlayer()
	end

	if self.checkmeshes then
		self.checkmeshes = p2mlib.RequestMeshes(self)
		self.checkbounds = not self.checkmeshes
	end

	if self.checkbounds then
		local mins, maxs = p2mlib.GetBounds(self)
		if mins and maxs then
			self:SetRenderBounds(mins, maxs)
			self.checkbounds = nil
		end
	end

	self:GetRenderMeshes()
	self:GetRenderMaterial()
	self:GetRenderScale()

	if self:GetColor().a ~= 255 then
		self.RenderGroup = RENDERGROUP_BOTH
	else
		self.RenderGroup = RENDERGROUP_OPAQUE
	end

end


-- -----------------------------------------------------------------------------
function ENT:Initialize()

	self.MaterialDefault = Material("hunter/myplastic") -- getrendermesh default
	self.MaterialMeshes = Material("p2m/grid") -- for the fake controller when using getrendermesh

	self.OutlineColor1 = HSVToColor(math.random(0, 360), 0.75, 0.95)
	self.OutlineColor1.a = 25
	self.OutlineColor2 = Color(self.OutlineColor1.r, self.OutlineColor1.g, self.OutlineColor1.b, 10)

end


-- -----------------------------------------------------------------------------
function ENT:OnRemove()

	local crc = self:GetCRC()
	local ent = self

	timer.Simple(0, function()
		if not self:IsValid() then
			p2mlib.ClearUser(crc, ent)
		end
	end)

end


-- -----------------------------------------------------------------------------
function ENT:GetModelCount()

	return p2mlib.models[self:GetCRC()] and p2mlib.models[self:GetCRC()].mcount or 0

end

function ENT:GetTriangleCount()

	return p2mlib.models[self:GetCRC()] and p2mlib.models[self:GetCRC()].tcount or 0

end



-- -----------------------------------------------------------------------------
local class = "gmod_ent_p2m"

local function Snapshot(controller)

	if not IsValid(controller) or controller:GetClass() ~= class then
		return
	end

	controller.checkmodels = true

end

hook.Add("OnEntityCreated", "P2M.Init", Snapshot)

net.Receive("NetP2M.UpdateAll", function()
	local controller = net.ReadEntity()
	if not IsValid(controller) then
		return
	end

	local old_crc = net.ReadString()

	p2mlib.ClearUser(old_crc, controller)

	hook.Run("OnEntityCreated", controller)
end)


-- -----------------------------------------------------------------------------
function p2mlib.ClearUser(crc, ent)

	if not crc or not p2mlib.users[crc] then
		return
	end

	p2mlib.users[crc][ent] = nil

	if next(p2mlib.users[crc]) == nil then
		p2mlib.users[crc] = nil
		p2mlib.marks[crc] = CurTime()
	end

	if p2mlib.debug then
		p2mlib.debugmsg("Cleared ", crc)
	end

end


-- -----------------------------------------------------------------------------
function p2mlib.DeleteMark(crc)

	if p2mlib.meshes[crc] then
		for tscale, parts in pairs(p2mlib.meshes[crc]) do
			for _, part in pairs(parts) do
				if IsValid(part) then
					part:Destroy()
				end
				part = nil
			end
			if p2mlib.models[crc] then
				p2mlib.hardcap_current = p2mlib.hardcap_current - p2mlib.models[crc].tcount
			end
		end
	end

	for _, field in pairs({ "getmodels", "getmeshes", "models", "meshes", "users", "marks" }) do
		if p2mlib[field] then
			p2mlib[field][crc] = nil
		end
	end

	if p2mlib.debug then
		p2mlib.debugmsg("Deleted ", crc)
	end

end

function p2mlib.FlushMarks(gc)

	for crc, time in pairs(p2mlib.marks) do
		p2mlib.DeleteMark(crc)
	end

	if gc then
		timer.Simple(1, function() collectgarbage() end)
	end

end

function p2mlib.FlushMeshes(gc)

	for crc, time in pairs(p2mlib.meshes) do
		p2mlib.DeleteMark(crc)
	end

	if gc then
		timer.Simple(1, function() collectgarbage() end)
	end

end

-- concommand.Add("prop2mesh_flush", function()
-- 	p2mlib.FlushMeshes()
-- end)

timer.Create("P2M.DeleteMarks", 30, 0, function()
	local ct = CurTime()
	for crc, time in pairs(p2mlib.marks) do
		if ct - time > 300 then -- 5 minutes
			p2mlib.DeleteMark(crc)
		end
	end
end)


-- -----------------------------------------------------------------------------
function p2mlib.RequestModels(controller)

	if not IsValid(controller) or controller:GetClass() ~= class then
		return true
	end

	local crc = controller:GetCRC()
	if not crc then
		return true
	end

	if not p2mlib.models[crc] then
		if not p2mlib.getmodels[crc] then
			p2mlib.getmodels[crc] = { status = "init", time = CurTime(), from = controller }
			if p2mlib.debug then
				p2mlib.debugmsg("Model Request Started ", crc)
			end
		elseif p2mlib.getmodels[crc].status == "init" then
			p2mlib.getmodels[crc].time = CurTime()
			if p2mlib.debug then
				p2mlib.debugmsg("Model Request Halted ", crc)
			end
		end
	else
		if p2mlib.debug then
			p2mlib.debugmsg("Model Request Ignored ", crc)
		end
	end

	if not p2mlib.users[crc] then
		p2mlib.users[crc] = {}
	end
	p2mlib.users[crc][controller] = CurTime()

	return false

end


-- -----------------------------------------------------------------------------
local vCountWarn = true

function p2mlib.BuildMeshes(crc, tscale)

	if not p2mlib.models[crc] or p2mlib.meshes[crc] and p2mlib.meshes[crc][tscale] then
		return
	end

	local parts, mins, maxs = p2mlib.partsToMeshes(true, util.JSONToTable(util.Decompress(p2mlib.models[crc].data)), tscale, true)
	if not parts then
		return
	end

	if mins and maxs then
		p2mlib.models[crc].mins = mins
		p2mlib.models[crc].maxs = maxs
	end

	local vcount = 0
	for i = 1, #parts do
		vcount = vcount + #parts[i]
	end

	p2mlib.models[crc].vcount = vcount
	p2mlib.models[crc].tcount = vcount / 3

	if p2mlib.hardcap_current + (vcount / 3) > hardcap_maximum then -- if over cap, delete marks and check again
		p2mlib.FlushMarks(true)
	end
	if p2mlib.hardcap_current + (vcount / 3) > hardcap_maximum then -- if still over, oh well
		chat.AddText(Color(255, 0, 0), string.format("Hardcap of %d triangles in RAM reached. This shouldn't ever happen!", hardcap_maximum))
		p2mlib.marks[crc] = CurTime()
		return
	end
	p2mlib.hardcap_current = p2mlib.hardcap_current + (vcount / 3)

	local meshes = {}
	for i = 1, #parts do
		meshes[#meshes + 1] = Mesh()
		meshes[#meshes]:BuildFromTriangles(parts[i])
	end

	if vCountWarn and #parts > 1 then
		chat.AddText(Color(255, 125, 125), "Vertex count has exceeded 65000, dynamic lighting will not work on this mesh!")
		vCountWarn = nil
	end

	return #meshes > 0 and meshes

end


-- -----------------------------------------------------------------------------
function p2mlib.RequestMeshes(controller)

	if not IsValid(controller) or controller:GetClass() ~= class then
		return true
	end

	local crc = controller:GetCRC()
	if not crc or not p2mlib.models[crc] then
		return true
	end

	if p2mlib.marks[crc] then
		p2mlib.marks[crc] = nil
	end

	local tscale = controller:GetTextureScale()
	if p2mlib.meshes[crc] and p2mlib.meshes[crc][tscale] or p2mlib.getmeshes[crc] and p2mlib.getmeshes[crc][tscale] then
		if p2mlib.debug then
			p2mlib.debugmsg("Mesh Request Ignored ", crc)
		end
		return false
	end

	if not p2mlib.getmeshes[crc] then
		p2mlib.getmeshes[crc] = {}
	end

	p2mlib.getmeshes[crc][tscale] = coroutine.create(function()
		local ret = p2mlib.BuildMeshes(crc, tscale)
		if ret then
			if not p2mlib.meshes[crc] then
				p2mlib.meshes[crc] = {}
			end
			p2mlib.meshes[crc][tscale] = ret

			if p2mlib.debug then
				p2mlib.debugmsg("Mesh Request Success ", crc)
			end
		else
			if p2mlib.debug then
				p2mlib.debugmsg("Mesh Request Failure ", crc)
			end
		end

		coroutine.yield(true)
	end)

	if p2mlib.debug then
		p2mlib.debugmsg("Mesh Request Started ", crc)
	end

	return false

end


-- -----------------------------------------------------------------------------
function p2mlib.GetBounds(controller)

	if not IsValid(controller) or controller:GetClass() ~= class then
		return
	end

	local crc = controller:GetCRC()
	if not crc or not p2mlib.models[crc] then
		return
	end

	return p2mlib.models[crc].mins, p2mlib.models[crc].maxs

end


-- -----------------------------------------------------------------------------
function p2mlib.GetMeshes(crc, tscale)

	return p2mlib.meshes[crc] and p2mlib.meshes[crc][tscale]

end


-- -----------------------------------------------------------------------------
local progress_slow = "P2M: Building mesh..."
local progress_fast = "P2M: Building mesh"

hook.Add("Think", "P2M.Think", function()

	local crc, request = next(p2mlib.getmodels)
	if crc and request then
		if request.status == "init" and CurTime() - request.time > 0.5 then
			if IsValid(request.from) then
				net.Start("NetP2M.GetModels")
				net.WriteEntity(request.from)
				net.SendToServer()
				request.status = "wait"
			else
				request.status = "kill"
			end
		end
		if request.status == "kill" then
			p2mlib.getmodels[crc] = nil
		end
	end

	local crc, request = next(p2mlib.getmeshes)
	if crc and request then
		local tscale, thread = next(request)
		if tscale and thread then
			local mark = SysTime()
			while SysTime() - mark < meshBuildTime:GetFloat() do
				local succ, done, progress, highpoly = coroutine.resume(thread)
				notification.AddProgress("P2M.Progress", highpoly and progress_slow or progress_fast, progress)
				if not succ or done then
					request[tscale] = nil
					break
				end
			end
		else
			notification.Kill("P2M.Progress")
			p2mlib.getmeshes[crc] = nil
		end
	end

end)


-- -----------------------------------------------------------------------------
net.Receive("NetP2M.GetModels", function()

	local crc     = net.ReadString()
	local request = p2mlib.getmodels[crc]

	if not request then
		return
	end

	local packetid = net.ReadUInt(16)
	if packetid == 1 then
		request.data = {}
	end

	local packetlen = net.ReadUInt(32)
	local packetstr = net.ReadData(packetlen)

	request.data[#request.data + 1] = packetstr

	if net.ReadBool() then
		local data = table.concat(request.data)
		if crc == util.CRC(data) then
			local temp = util.JSONToTable(util.Decompress(data))
			p2mlib.models[crc] = { data = data, mcount = #temp }
			if p2mlib.debug then
				p2mlib.debugmsg("Model Request Success ", crc)
			end
		else
			if p2mlib.debug then
				p2mlib.debugmsg("Model Request Failed ", crc)
			end
		end
		request.status = "kill"
	end

end)


-- -----------------------------------------------------------------------------
function p2mlib.debugmsg(msg, crc)

	MsgC(Color(255, 255, 255), "P2M ", Color(255, 125, 125), msg or "", Color(255, 125, 0), crc or "", "\n")

end

local function dumpCRC(dat, crc, nick)

	local dat = dat or p2mlib.models[crc]
	if not dat then
		return
	end

	local mins = dat.mins or Vector()
	local maxs = dat.maxs or Vector()
	local marked = p2mlib.marks[crc]

	if nick then
		MsgC("\n", Color(255, 255, 255), crc, Color(255, 125, 0), "\n\tplayer", Color(255, 255, 255), " = ", Color(0, 255, 255), nick)
	else
		MsgC("\n", Color(255, 255, 255), crc)
	end

	MsgC(
		Color(255, 0, 0), "\n\tmarked", Color(255, 255, 255), " = ", Color(marked and 0 or 255, 255, 0) , marked and "TRUE" or "false",
		Color(255, 0, 0), "\n\tmodels", Color(255, 255, 255), " = ", Color(255, 255, 0), dat.mcount,
		Color(255, 0, 0), "\n\tverts", Color(255, 255, 255), "  = ", Color(255, 255, 0), dat.vcount,
		Color(255, 0, 0), "\n\ttris", Color(255, 255, 255), "   = ", Color(255, 255, 0), dat.tcount,
		Color(255, 0, 0), "\n\tmins", Color(255, 255, 255), "   = ", Color(255, 255, 0), string.format("%d, %d, %d", mins.x, mins.y, mins.z),
		Color(255, 0, 0), "\n\tmaxs", Color(255, 255, 255), "   = ", Color(255, 255, 0), string.format("%d, %d, %d", maxs.x, maxs.y, maxs.z)
	)

end

function p2mlib.dump(crc, nick)

	if crc then
		dumpCRC(nil, crc, nick)
		return
	end

	for crc, dat in pairs(p2mlib.models) do
		dumpCRC(dat, crc)
	end

end
