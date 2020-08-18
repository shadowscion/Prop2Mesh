-- -----------------------------------------------------------------------------
include("shared.lua")
include("p2m/p2mlib.lua")

--[[

	todo:
		clear caches if not used after some amount of time
]]

local max_frame_time = CreateClientConVar("prop2mesh_build_time", 0.001, true, false, "Lower to reduce stuttering", 0.001, 0.1)

local disable_rendering
CreateClientConVar("prop2mesh_disable_rendering", "0", true, false)
cvars.AddChangeCallback("prop2mesh_disable_rendering", function(convar_name, value_old, value_new)
	disable_rendering = value_new ~= "0"
end)



-- -----------------------------------------------------------------------------
local coroutine = coroutine
local string = string
local render = render
local table = table
local cam = cam
local net = net


-- -----------------------------------------------------------------------------
local p2mlib = p2mlib

local p2m_getmodels = {}
local p2m_getmeshes = {}
local p2m_models    = {}
local p2m_meshes    = {}
local p2m_usedby    = {}


-- -----------------------------------------------------------------------------
function P2M_Flush(gb)
	for crc, scales in pairs(p2m_meshes) do
		for scale, parts in pairs(scales) do
			for p, part in ipairs(parts) do
				part:Destroy()
				part = nil
			end
		end
	end
	p2m_meshes    = {}
	p2m_getmodels = {}
	p2m_getmeshes = {}
	p2m_models    = {}
	p2m_usedby    = {}
	if gb then collectgarbage() end
end


-- -----------------------------------------------------------------------------
function P2M_Dump()
	local msg = {}
	for crc, v in pairs(p2m_models) do
		msg[#msg + 1] = string.format("\tcrc: %s\n", crc)
		msg[#msg + 1] = string.format("\t\tmodels: %d\n", v.count)
		msg[#msg + 1] = string.format("\t\ttriangles: %d\n", v.triangles)
	end
	MsgC(Color(255,255,0), "Models:\n", Color(255,255,255), table.concat(msg))

	local msg = {}
	for crc, scales in pairs(p2m_meshes) do
		msg[#msg + 1] = string.format("\tcrc: %s\n", crc)
		for scale, parts in pairs(scales) do
			msg[#msg + 1] = string.format("\t\tuv scale: %d\n", scale)
			msg[#msg + 1] = string.format("\t\t\timeshes: %d\n", #parts)
		end
	end
	MsgC(Color(255,255,0), "Meshes:\n", Color(255,255,255), table.concat(msg))

	local msg = {}
	for crc, v in pairs(p2m_usedby) do
		msg[#msg + 1] = string.format("\tcrc: %s\n", crc)
		for ent, time in pairs(v) do
			msg[#msg + 1] = string.format("\t\tent: %s\n", tostring(ent))
		end
	end
	MsgC(Color(255,255,0), "Used By:\n", Color(255,255,255), table.concat(msg))
end


-- -----------------------------------------------------------------------------
local function P2M_ClearUsed(crc, ent)
	if p2m_usedby[crc] then
		p2m_usedby[crc][ent] = nil
		if next(p2m_usedby[crc]) == nil then
			p2m_usedby[crc] = nil
		end
	end
end


-- -----------------------------------------------------------------------------
local function P2M_GetMeshes(crc, scale)
	return p2m_meshes[crc] and p2m_meshes[crc][scale]
end


-- -----------------------------------------------------------------------------
local function P2M_BuildMeshes(crc, scale)
	if not p2m_models[crc] then
		return
	end

	local models = util.JSONToTable(util.Decompress(p2m_models[crc].data))
	local bounds
	if not p2m_models[crc].mins or not p2m_models[crc].maxs then
		bounds = true
	end
	if not p2m_models[crc].count then
		p2m_models[crc].count = #models
	end

	local meshparts, mins, maxs = p2mlib.modelsToMeshes(true, models, scale, bounds)
	if meshparts then
		local vcount  = 0
		local imeshes = {}
		for k, part in ipairs(meshparts) do
			local imesh = Mesh()
			imesh:BuildFromTriangles(part)
			imeshes[#imeshes + 1] = imesh
			vcount = vcount + #part
			coroutine.yield(false, 1)
		end

		if not p2m_meshes[crc] then
			p2m_meshes[crc] = {}
		end

		p2m_meshes[crc][scale] = imeshes
		p2m_models[crc].triangles = vcount / 3
	end
	if mins and maxs then
		p2m_models[crc].mins = mins
		p2m_models[crc].maxs = maxs
	end

	models = nil
end


-- -----------------------------------------------------------------------------
local function P2M_CheckMeshes(crc, scale)
	if not p2m_models[crc] then
		return
	end
	scale = math.floor(scale or 0)
	if p2m_meshes[crc] and p2m_meshes[crc][scale] then
		-- checkvalid
		return
	end
	if p2m_getmeshes[crc] and p2m_getmeshes[crc][scale] then
		return
	end
	if not p2m_getmeshes[crc] then
		p2m_getmeshes[crc] = {}
	end
	p2m_getmeshes[crc][scale] = coroutine.create(function()
		P2M_BuildMeshes(crc, scale)
		coroutine.yield(true)
	end)
end


-- -----------------------------------------------------------------------------
local pbar
local pbar_border = Color(0,0,0)
local pbar_inside = Color(0,255,0)
local pbar_faded = Color(165,255,165)

hook.Add("HUDPaint", "p2m.progressbar", function()
	if not pbar then
		return
	end

	local w = 96
	local h = 24
	local x = ScrW() - w - 24
	local y = h

	draw.RoundedBox(2, x, y, w, h, pbar_border)
	draw.RoundedBox(2, x + 2, y + 2, pbar*(w - 4), h - 4, pbar_inside)
	draw.RoundedBoxEx(2, x + 2, y + 2, pbar*(w - 4), (h - 4)*0.333, pbar_faded, true, true)

	surface.SetDrawColor(255,255,0,255)
	surface.DrawRect(x + 2 + pbar*(w - 6), y + 2, 2, h - 4)
end)

local function P2M_HandleGetMeshes()
	local crc, request = next(p2m_getmeshes)
	if crc and request then
		local scale, thread = next(request)
		if scale and thread then
			local mark = SysTime()
			while SysTime() - mark < max_frame_time:GetFloat() do
				local succ, done, progress = coroutine.resume(thread)
				pbar = progress
				if not succ or done then
					request[scale] = nil
					break
				end
			end
		else
			p2m_getmeshes[crc] = nil
			pbar = nil
		end
	end
end
hook.Add("Think", "p2mthink.getmeshes", P2M_HandleGetMeshes)


-- -----------------------------------------------------------------------------
local function P2M_CheckModels(crc, ent)
	if not p2m_usedby[crc] then
		p2m_usedby[crc] = {}
	end
	p2m_usedby[crc][ent] = CurTime()
	if not p2m_models[crc] then
		if not p2m_getmodels[crc] then
			p2m_getmodels[crc] = { status = "init", time = CurTime(), from = ent }
		else
			if p2m_getmodels[crc].status == "init" then
				p2m_getmodels[crc].time = CurTime()
			end
		end
		return false
	else
	end
	return true
end


-- -----------------------------------------------------------------------------
local function P2M_HandleGetModels()
	local crc, request = next(p2m_getmodels)
	if crc and request then
		if request.status == "init" and CurTime() - request.time > 0.5 then
			if IsValid(request.from) then
				net.Start("p2mnet.getmodels")
				net.WriteEntity(request.from)
				net.SendToServer()
				request.status = "wait"
			else
				request.status = "kill"
			end
		end
		if request.status == "kill" then
			p2m_getmodels[crc] = nil
		end
	end
end
hook.Add("Think", "p2mthink.getmodels", P2M_HandleGetModels)


-- -----------------------------------------------------------------------------
local function P2M_HandleNetModels()
	local crc     = net.ReadString()
	local request = p2m_getmodels[crc]

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
			p2m_models[crc] = { data = data }
		else
		end
		request.status = "kill"
	end
end
net.Receive("p2mnet.getmodels", P2M_HandleNetModels)


-- -----------------------------------------------------------------------------
function ENT:GetModelCount()
	return p2m_models[self:GetCRC()] and p2m_models[self:GetCRC()].count or 0
end

function ENT:GetTriangleCount()
	return p2m_models[self:GetCRC()] and p2m_models[self:GetCRC()].triangles or 0
end


-- -----------------------------------------------------------------------------
function ENT:Initialize()
	self.rmatrix = Matrix()
	self.boxcolor1 = HSVToColor(math.random(0, 360), 1, 1)
	self.boxcolor1.a = 50
	self.boxcolor2 = Color(self.boxcolor1.r, self.boxcolor1.g, self.boxcolor1.b, 10)
end


-- -----------------------------------------------------------------------------
function ENT:Draw()
	self:DrawModel()
	if disable_rendering or self.checkmodels or self.checkmeshes then
		return
	end
	local meshes = P2M_GetMeshes(self:GetCRC(), self:GetTextureScale())
	if meshes then
		cam.PushModelMatrix(self.rmatrix)
		for m = 1, #meshes do
			meshes[m]:Draw()
		end
		cam.PopModelMatrix()
	else
	end
	--[[
	cam.IgnoreZ(true)
	local mins, maxs = self:GetRenderBounds()
	render.DrawWireframeBox(self:GetPos(), self:GetAngles(), mins, maxs, self.boxcolor1)
	render.SetColorMaterial()
	render.DrawBox(self:GetPos(), self:GetAngles(), mins, maxs, self.boxcolor2)
	local mins, maxs = self:GetModelBounds()
	render.DrawWireframeBox(self:GetPos(), self:GetAngles(), mins, maxs, self.boxcolor1)
	cam.IgnoreZ(false)
	]]
end


-- -----------------------------------------------------------------------------
function ENT:OnRemove()
	local crc = self:GetCRC()
	local ent = self
	timer.Simple(0, function()
		if not self:IsValid() then
			P2M_ClearUsed(crc, ent)
		end
	end)
end


-- -----------------------------------------------------------------------------
function ENT:CheckScale()
	local models = p2m_models[self:GetCRC()]
	if models and models.mins and models.maxs then
		local scalar = self:GetMeshScale()
		if scalar == 1 then
			self.rescale = nil
			self.lerpscale_a = nil
			self.lerpscale_b = nil
			self.meshscale_v = nil
			self.meshscale_n = nil
		else
			if self.meshscale_n ~= scalar then
				self.rescale = 0
				self.meshscale_n = scalar
				self.lerpscale_a = Vector(1, 1, 1)
				self.lerpscale_b = self.lerpscale_a * scalar

				self:SetRenderBounds(models.mins * scalar, models.maxs * scalar)
			end
		end
		return nil
	end
	return true
end

function ENT:DoScale()
	self.rescale = math.min(1, self.rescale + FrameTime() * 2)
	self.meshscale_v = LerpVector(self.rescale, self.lerpscale_a, self.lerpscale_b)
	if self.rescale == 1 then
		self.rescale = nil
	end
end


-- -----------------------------------------------------------------------------
function ENT:CheckRenderBounds()
	local models = p2m_models[self:GetCRC()]
	if models and models.mins and models.maxs then
		self:SetRenderBounds(models.mins, models.maxs)
		return nil
	end
	return true
end


-- -----------------------------------------------------------------------------
function ENT:Think()
	if disable_rendering then
		return
	end

	self.rmatrix = self:GetWorldTransformMatrix()
	if self.meshscale_v then
		self.rmatrix:Scale(self.meshscale_v)
	end

	if self.checkmodels and self:GetCRC() then
		P2M_CheckModels(self:GetCRC(), self)
		self.checkmeshes = true
		self.checkmodels = nil
	end
	if self.checkmeshes then
		if p2m_models[self:GetCRC()] then
			P2M_CheckMeshes(self:GetCRC(), self:GetTextureScale())
			self.checkmeshes = nil
		end
	end

	if self.checkbounds then
		self.checkbounds = self:CheckRenderBounds()
	end
	if self.checkscale then
		self.checkscale = self:CheckScale()
	end
	if self.rescale then
		self:DoScale()
	end

	if self:GetColor().a ~= 255 then
		self.RenderGroup = RENDERGROUP_BOTH
	else
		self.RenderGroup = RENDERGROUP_OPAQUE
	end
end


-- -----------------------------------------------------------------------------
local class = "gmod_ent_p2m"
local function Snapshot(self)
	if not self:IsValid() or self:GetClass() ~= class then
		return
	end
	self.checkmodels = true
	self.checkbounds = true
	self.checkscale  = true
end
hook.Add("OnEntityCreated", "p2m_created", Snapshot)

net.Receive("p2mnet.invalidate", function()
	hook.Run("OnEntityCreated", net.ReadEntity())
end)
