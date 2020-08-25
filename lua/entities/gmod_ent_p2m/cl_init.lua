-- -----------------------------------------------------------------------------
include("shared.lua")
include("p2m/p2mlib.lua")

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
local p2m = p2mlib

p2m.getmodels = p2m.getmodels or {}
p2m.getmeshes = p2m.getmeshes or {}
p2m.models    = p2m.models or {}
p2m.meshes    = p2m.meshes or {}
p2m.users     = p2m.users or {}
p2m.marks     = p2m.marks or {}

p2m.debug = false
concommand.Add("prop2mesh_debug", function()
	p2m.debug = not p2m.debug
end)

local meshBuildTime = CreateClientConVar("prop2mesh_build_time", 0.001, true, false, "Lower to reduce stuttering", 0.001, 0.1)
local globalDisable = CreateClientConVar("prop2mesh_disable_rendering", "0", true, false)


-- -----------------------------------------------------------------------------
p2m.hardcap_current = p2m.hardcap_current or 0
local hardcap_maximum = 10000000

local softcap_current = 0
local softcap_maximum = CreateClientConVar("prop2mesh_max_tris_softcap", 1000000, true, false, "max number of triangles on screen", 0, hardcap_maximum)


-- -----------------------------------------------------------------------------
local inMenu, globalSuppress
hook.Add("OnSpawnMenuOpen", "p2m.suppress", function()
	inMenu = true
end)
hook.Add("OnSpawnMenuClose", "p2m.suppress", function()
	inMenu = false
end)
hook.Add("PreRender", "P2M.PreRender", function()
	globalSuppress = inMenu or gui.IsGameUIVisible() or FrameTime() == 0
	softcap_current = 0
end)


-- -----------------------------------------------------------------------------
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

	if self.Mesh then
		self:DrawFakeController()
		self:DrawModel()
	elseif self.MeshGroup then
		self:DrawMeshGroup()
	end

end


-- -----------------------------------------------------------------------------
function ENT:DrawFakeController()

	local mins, maxs = self:GetHitBoxBounds(0, 0)
	if not mins or not maxs then
		mins, maxs = self:GetModelBounds()
	end

	render.SuppressEngineLighting(true)

	render.SetMaterial(self.Material2)
	render.DrawBox(self:GetPos(), self:GetAngles(), mins, maxs, self:GetColor(), true)

	render.SuppressEngineLighting(false)

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

	self:DrawModel()

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
function ENT:GetRenderMeshes()

	local parts = p2m.GetMeshes(self:GetCRC(), self:GetTextureScale())
	if parts and #parts > 0 then
		if #parts == 1 then
			self.Mesh = { Mesh = parts[1], Material = self.Material1, Matrix = self.ScaleM }
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
function ENT:Think()

	if globalDisable:GetBool() or globalSuppress or self.suppress then
		return
	end

	if self.checkmodels then
		self.checkmodels = p2m.RequestModels(self)
		self.checkmeshes = not self.checkmodels
		self.checksoftcap = self:GetPlayer() ~= LocalPlayer()
	end

	if self.checkmeshes then
		self.checkmeshes = p2m.RequestMeshes(self)
		self.checkbounds = not self.checkmeshes
	end

	if self.checkbounds then
		local mins, maxs = p2m.GetBounds(self)
		if mins and maxs then
			self:SetRenderBounds(mins, maxs)
			self.checkbounds = nil
		end
	end

	if self.checkmscale then
		local scalar = self:GetMeshScale()
		if scalar == 1 then
			self.ScaleV = nil
			self.ScaleM = nil
		else
			self.ScaleV = Vector(scalar, scalar, scalar)
			self.ScaleM = Matrix()
			self.ScaleM:SetScale(self.ScaleV)
		end
		self.checkmscale = nil
	end

	self:GetRenderMeshes()

	if self.Mesh then
		local mat = self:GetMaterial()
		if not self.Material2 or self.Material2:GetName() ~= mat then
			self.Material2 = mat == "" and self.Material1 or Material(mat)
		end
	end

	if self:GetColor().a ~= 255 then
		self.RenderGroup = RENDERGROUP_BOTH
	else
		self.RenderGroup = RENDERGROUP_OPAQUE
	end

end


-- -----------------------------------------------------------------------------
function ENT:Initialize()

	self.Material1 = Material("p2m/grid") -- getrendermesh default
	self.Material2 = Material("p2m/grid") -- for the fake controller when using getrendermesh

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
			p2m.ClearUser(crc, ent)
		end
	end)

end


-- -----------------------------------------------------------------------------
function ENT:GetModelCount()

	return p2m.models[self:GetCRC()] and p2m.models[self:GetCRC()].mcount or 0

end

function ENT:GetTriangleCount()

	return p2m.models[self:GetCRC()] and p2m.models[self:GetCRC()].tcount or 0

end


-- -----------------------------------------------------------------------------
local class = "gmod_ent_p2m"

local function Snapshot(controller)

	if not IsValid(controller) or controller:GetClass() ~= class then
		return
	end

	controller.checkmodels = true
	controller.checkmscale = true

end

hook.Add("OnEntityCreated", "P2M.Init", Snapshot)

net.Receive("NetP2M.UpdateAll", function()
	hook.Run("OnEntityCreated", net.ReadEntity())
end)


-- -----------------------------------------------------------------------------
function p2m.ClearUser(crc, ent)

	if not p2m.users[crc] then
		return
	end

	p2m.users[crc][ent] = nil

	if next(p2m.users[crc]) == nil then
		p2m.users[crc] = nil
		p2m.marks[crc] = CurTime()
	end

end


-- -----------------------------------------------------------------------------
function p2m.DeleteMark(crc)

	if p2m.meshes[crc] then
		for tscale, parts in pairs(p2m.meshes[crc]) do
			for _, part in pairs(parts) do
				if IsValid(part) then
					part:Destroy()
				end
				part = nil
			end
			if p2m.models[crc] then
				p2m.hardcap_current = p2m.hardcap_current - p2m.models[crc].tcount
			end
		end
	end

	for _, field in pairs({ "getmodels", "getmeshes", "models", "meshes", "users", "marks" }) do
		if p2m[field] then
			p2m[field][crc] = nil
		end
	end

end

function p2m.FlushMarks()

	for crc, time in pairs(p2m.marks) do
		p2m.DeleteMark(crc)
	end

end

function p2m.FlushMeshes()

	for crc, time in pairs(p2m.meshes) do
		p2m.DeleteMark(crc)
	end

end

timer.Create("P2M.DeleteMarks", 30, 0, function()
	local ct = CurTime()
	for crc, time in pairs(p2m.marks) do
		if ct - time > 300 then -- 5 minutes
			p2m.DeleteMark(crc)
			if p2m.debug then
				p2m.debugmsg("Deleted ", crc)
			end
		end
	end
end)


-- -----------------------------------------------------------------------------
function p2m.RequestModels(controller)

	if not IsValid(controller) or controller:GetClass() ~= class then
		return true
	end

	local crc = controller:GetCRC()
	if not crc then
		return true
	end

	if not p2m.models[crc] then
		if not p2m.getmodels[crc] then
			p2m.getmodels[crc] = { status = "init", from = controller }
			if p2m.debug then
				p2m.debugmsg("Model Request Started ", crc)
			end
		end
		if p2m.getmodels[crc].status == "init" then
			p2m.getmodels[crc].time = CurTime()
			if p2m.debug then
				p2m.debugmsg("Model Request Halted ", crc)
			end
		end
	else
		if p2m.debug then
			p2m.debugmsg("Model Request Ignored ", crc)
		end
	end

	if not p2m.users[crc] then
		p2m.users[crc] = {}
	end
	p2m.users[crc][controller] = CurTime()

	return false

end


-- -----------------------------------------------------------------------------
local vCountWarn = true

function p2m.BuildMeshes(crc, tscale)

	if not p2m.models[crc] or p2m.meshes[crc] and p2m.meshes[crc][tscale] then
		return
	end

	local parts, mins, maxs = p2m.modelsToMeshes(true, util.JSONToTable(util.Decompress(p2m.models[crc].data)), tscale, true)
	if not parts then
		return
	end

	if mins and maxs then
		p2m.models[crc].mins = mins
		p2m.models[crc].maxs = maxs
	end

	local vcount = 0
	for i = 1, #parts do
		vcount = vcount + #parts[i]
	end

	p2m.models[crc].vcount = vcount
	p2m.models[crc].tcount = vcount / 3

	if p2m.hardcap_current + (vcount / 3) > hardcap_maximum then -- if over cap, delete marks and check again
		p2m.FlushMarks()
	end
	if p2m.hardcap_current + (vcount / 3) > hardcap_maximum then -- if still over, oh well
		chat.AddText(Color(255, 0, 0), string.format("Hardcap of %d triangles in RAM reached. This shouldn't ever happen!", hardcap_maximum))
		p2m.marks[crc] = CurTime()
		return
	end
	p2m.hardcap_current = p2m.hardcap_current + (vcount / 3)

	local meshes = {}
	for i = 1, #parts do
		meshes[#meshes + 1] = Mesh()
		meshes[#meshes]:BuildFromTriangles(parts[i])
	end

	if #parts > 1 then
		if vCountWarn then
			chat.AddText(Color(255, 125, 125), "Vertex count has exceeded 65000, dynamic lighting will not work on this mesh!")
			vCountWarn =nil
		end
	end

	return #meshes > 0 and meshes

end


-- -----------------------------------------------------------------------------
function p2m.RequestMeshes(controller)

	if not IsValid(controller) or controller:GetClass() ~= class then
		return true
	end

	local crc = controller:GetCRC()
	if not crc or not p2m.models[crc] then
		return true
	end

	local tscale = controller:GetTextureScale()
	if p2m.meshes[crc] and p2m.meshes[crc][tscale] or p2m.getmeshes[crc] and p2m.getmeshes[crc][tscale] then
		if p2m.debug then
			p2m.debugmsg("Mesh Request Ignored ", crc)
		end
		return false
	end

	if not p2m.getmeshes[crc] then
		p2m.getmeshes[crc] = {}
	end

	p2m.getmeshes[crc][tscale] = coroutine.create(function()
		local ret = p2m.BuildMeshes(crc, tscale)
		if ret then
			if not p2m.meshes[crc] then
				p2m.meshes[crc] = {}
			end
			p2m.meshes[crc][tscale] = ret

			if p2m.debug then
				p2m.debugmsg("Mesh Request Success ", crc)
			end
		else
			if p2m.debug then
				p2m.debugmsg("Mesh Request Failure ", crc)
			end
		end

		coroutine.yield(true)
	end)

	if p2m.debug then
		p2m.debugmsg("Mesh Request Started ", crc)
	end

	return false

end


-- -----------------------------------------------------------------------------
function p2m.GetBounds(controller)

	if not IsValid(controller) or controller:GetClass() ~= class then
		return
	end

	local crc = controller:GetCRC()
	if not crc or not p2m.models[crc] then
		return
	end

	return p2m.models[crc].mins, p2m.models[crc].maxs

end


-- -----------------------------------------------------------------------------
function p2m.GetMeshes(crc, tscale)

	return p2m.meshes[crc] and p2m.meshes[crc][tscale]

end


-- -----------------------------------------------------------------------------
local pbar_num

hook.Add("Think", "P2M.Think", function()

	local crc, request = next(p2m.getmodels)
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
			p2m.getmodels[crc] = nil
		end
	end

	local crc, request = next(p2m.getmeshes)
	if crc and request then
		local tscale, thread = next(request)
		if tscale and thread then
			local mark = SysTime()
			while SysTime() - mark < meshBuildTime:GetFloat() do
				local succ, done, progress = coroutine.resume(thread)
				pbar_num = progress
				if not succ or done then
					request[tscale] = nil
					break
				end
			end
		else
			p2m.getmeshes[crc] = nil
			pbar_num = nil
		end
	end

end)

local pbar_border = Color(0,0,0)
local pbar_inside = Color(0,255,0)
local pbar_faded = Color(165,255,165)

hook.Add("HUDPaint", "P2M.ProgressBar", function()

	if not pbar_num then
		return
	end

	local w = 96
	local h = 24
	local x = ScrW() - w - 24
	local y = h

	draw.RoundedBox(2, x, y, w, h, pbar_border)
	draw.RoundedBox(2, x + 2, y + 2, pbar_num*(w - 4), h - 4, pbar_inside)
	draw.RoundedBoxEx(2, x + 2, y + 2, pbar_num*(w - 4), (h - 4)*0.333, pbar_faded, true, true)
	surface.SetDrawColor(255,255,0,255)
	surface.DrawRect(x + 2 + pbar_num*(w - 6), y + 2, 2, h - 4)

end)


-- -----------------------------------------------------------------------------
net.Receive("NetP2M.GetModels", function()

	local crc     = net.ReadString()
	local request = p2m.getmodels[crc]

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
			p2m.models[crc] = { data = data, mcount = #temp }
			if p2m.debug then
				p2m.debugmsg("Model Request Success ", crc)
			end
		else
			if p2m.debug then
				p2m.debugmsg("Model Request Failed ", crc)
			end
		end
		request.status = "kill"
	end

end)


-- -----------------------------------------------------------------------------
function p2m.debugmsg(msg, crc)

	MsgC(Color(255, 255, 255), "P2M ", Color(255, 125, 125), msg or "", Color(255, 125, 0), crc or "", "\n")

end

function p2m.dump()

	print("\ngetmodels")
	PrintTable(p2m.getmodels)

	print("\ngetmeshes")
	PrintTable(p2m.getmeshes)

	print("\nmodels")
	PrintTable(p2m.models)

	print("\nmeshes")
	PrintTable(p2m.meshes)

	print("\nusers")
	PrintTable(p2m.users)

	print("\nmarks")
	PrintTable(p2m.marks)

	print("\nhardcap", p2m.hardcap_current)

end
