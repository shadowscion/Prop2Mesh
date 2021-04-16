--[[

]]
include("shared.lua")

local prop2mesh = prop2mesh

local defaultmat = Material(prop2mesh.defaultmat)
local debugwhite = Material("models/debug/debugwhite")
local wireframe = Material("models/wireframe")

local net = net
local cam = cam
local table = table
local render = render
local string = string

local empty = { Mesh = Mesh(), Material = Material("models/debug/debugwhite") }
empty.Mesh:BuildFromTriangles({{pos = Vector()},{pos = Vector()},{pos = Vector()}})


--[[

]]
local recycle = {}
local garbage = {}

function prop2mesh.getMeshInfo(crc, uvs)
	local mdata = recycle[crc] and recycle[crc].meshes[uvs]
	if mdata then
		return mdata.pcount, mdata.vcount
	end
	return
end

function prop2mesh.getMeshData(crc, unzip)
	local dat = recycle[crc] and recycle[crc].zip
	if not unzip or not dat then
		return dat
	end
	return util.JSONToTable(util.Decompress(dat))
end

concommand.Add("prop2mesh_dump", function()
	PrintTable(recycle)
	PrintTable(garbage)
end)

timer.Create("prop2trash", 1, 0, function()
	local curtime = SysTime()
	for crc, usedtime in pairs(garbage) do
		if curtime - usedtime > 3 then
			if recycle[crc] and recycle[crc].meshes then
				for uvs, meshdata in pairs(recycle[crc].meshes) do
					if meshdata.basic then
						if IsValid(meshdata.basic.Mesh) then
							print("destroying", meshdata.basic.Mesh)
							meshdata.basic.Mesh:Destroy()
							meshdata.basic.Mesh = nil
						end
					end
					if meshdata.complex then
						for m, meshpart in pairs(meshdata.complex) do
							if IsValid(meshpart) then
								print("destroying", meshpart)
								meshpart:Destroy()
								meshdata.complex[m] = nil
							end
						end
					end
				end
			end
			recycle[crc] = nil
			garbage[crc] = nil
		end
	end
end)

local function checkdownload(self, crc)
	if recycle[crc] then
		return true
	end

	recycle[crc] = { users = {}, meshes = {} }

	net.Start("prop2mesh_download")
	net.WriteEntity(self)
	net.WriteString(crc)
	net.SendToServer()

	return false
end

local function setuser(self, crc, bool)
	if not recycle[crc] then
		garbage[crc] = nil
		return
	end
	if bool then
		recycle[crc].users[self] = true
		garbage[crc] = nil
	else
		recycle[crc].users[self] = nil
		if not next(recycle[crc].users) then
			garbage[crc] = SysTime()
		end
	end
end

local function checkmesh(crc, uvs)
	if not recycle[crc] or not recycle[crc].zip or recycle[crc].meshes[uvs] then
		return recycle[crc].meshes[uvs]
	end
	recycle[crc].meshes[uvs] = {}
	prop2mesh.getMesh(crc, uvs, recycle[crc].zip)
end

hook.Add("prop2mesh_hook_meshdone", "prop2mesh_meshlab", function(crc, uvs, mdata)
	if not mdata or not crc or not uvs then
		return
	end

	recycle[crc].meshes[uvs] = mdata

	if #mdata.meshes == 1 then
		local imesh = Mesh()
		imesh:BuildFromTriangles(mdata.meshes[1])
		mdata.basic = { Mesh = imesh, Material = defaultmat }
	else
		mdata.complex = {}
		for i = 1, #mdata.meshes do
			local imesh = Mesh()
			imesh:BuildFromTriangles(mdata.meshes[i])
			mdata.complex[i] = imesh
		end
	end

	mdata.meshes = nil
	mdata.ready = true

	local mins = mdata.vmins
	local maxs = mdata.vmaxs

	if mins and maxs then
		for user in pairs(recycle[crc].users) do
			for k, info in pairs(user.prop2mesh_controllers) do
				if IsValid(info.ent) and info.crc == crc and info.uvs == uvs then
					info.ent:SetRenderBounds(mins, maxs)
				end
			end
		end
	end
end)


--[[

]]
local cvar = CreateClientConVar("prop2mesh_render_disable", 0, true, false)
local draw_disable = cvar:GetBool()

cvars.AddChangeCallback("prop2mesh_render_disable", function(cvar, old, new)
    draw_disable = tobool(new)
end, "swapdrawdisable")

local draw_wireframe
concommand.Add("prop2mesh_render_wireframe", function(ply, cmd, args)
	draw_wireframe = not draw_wireframe
end)


--[[

]]
local function getComplex(crc, uvs)
	local meshes = recycle[crc] and recycle[crc].meshes[uvs]
	return meshes and meshes.complex
end

local vec = Vector()
local function drawModel(self)
	if draw_disable then
		local min, max = self:GetRenderBounds()
		local color = self:GetColor()
		vec.x = color.r/255
		vec.y = color.g/255
		vec.z = color.b/255
		debugwhite:SetVector("$color", vec)
		render.SetMaterial(debugwhite)
		render.DrawBox(self:GetPos(), self:GetAngles(), min, max)
		render.DrawWireframeBox(self:GetPos(), self:GetAngles(), min, max, color_black, true)
		return
	end
	if draw_wireframe and self.isowner then
		render.SetBlend(1)
		render.SetColorModulation(1, 1, 1)
		render.ModelMaterialOverride(wireframe)
		self:DrawModel()
		render.ModelMaterialOverride()
	else
		self:DrawModel()
	end
	local complex = getComplex(self.crc, self.uvs)
	if complex then
		local matrix = self:GetWorldTransformMatrix()
		if self.scale then
			matrix:SetScale(self.scale)
		end
		cam.PushModelMatrix(matrix)
		for i = 1, #complex do
			complex[i]:Draw()
		end
		cam.PopModelMatrix()
	end
end

local function drawMesh(self)
	local meshes = recycle[self.crc] and recycle[self.crc].meshes[self.uvs]
	return meshes and meshes.basic or empty
end

local matrix = Matrix()
local function refresh(self, info)
	if not IsValid(info.ent) then
		info.ent = ents.CreateClientside("base_anim")
		info.ent:SetModel("models/hunter/plates/plate.mdl")
		info.ent:DrawShadow(false)
		info.ent.Draw = drawModel
		info.ent.GetRenderMesh = drawMesh
		info.ent:Spawn()
		info.ent:Activate()
	end

	info.ent:SetParent(self)
	info.ent:SetPos(self:GetPos())
	info.ent:SetAngles(self:GetAngles())
	info.ent:SetMaterial(info.mat)
	info.ent:SetColor(info.col)
	info.ent:SetRenderMode(info.col.a == 255 and RENDERMODE_NORMAL or RENDERMODE_TRANSCOLOR)
	info.ent.RenderGroup = info.col.a == 255 and RENDERGROUP_OPAQUE or RENDERGROUP_BOTH

	if info.scale.x ~= 1 or info.scale.y ~= 1 or info.scale.z ~= 1 then
		matrix:SetScale(info.scale)
		info.ent:EnableMatrix("RenderMultiply", matrix)
		info.ent.scale = info.scale
	else
		info.ent:DisableMatrix("RenderMultiply")
		info.ent.scale = nil
	end

	info.ent.crc = info.crc
	info.ent.uvs = info.uvs
	info.ent.isowner = self.isowner

	if checkdownload(self, info.crc) then
		local mdata = checkmesh(info.crc, info.uvs)
		if mdata and mdata.ready then
			info.ent:SetRenderBounds(mdata.vmins, mdata.vmaxs)
		end
	end

	setuser(self, info.crc, true)
end

local function refreshAll(self, prop2mesh_controllers)
	for k, info in pairs(prop2mesh_controllers) do
		refresh(self, info)
	end
end


local function discard(self, prop2mesh_controllers)
	for _, info in pairs(prop2mesh_controllers) do
		if info.ent and IsValid(info.ent) then
			info.ent:Remove()
			info.ent = nil
		end
		setuser(self, info.crc, false)
	end
end


--[[

]]
function ENT:Initialize()
	self.prop2mesh_controllers = {}
end

function ENT:Draw()
	self:DrawModel()
end

function ENT:Think()
	if not self.prop2mesh_sync then
		if CPPI then
			self.isowner = self:CPPIGetOwner() == LocalPlayer()
		else
			self.isowner = true
		end

		refreshAll(self, self.prop2mesh_controllers)

		net.Start("prop2mesh_sync")
		net.WriteEntity(self)
		net.WriteString(self.prop2mesh_synctime or "")
		net.SendToServer()

		self.prop2mesh_refresh = nil
		self.prop2mesh_sync = true
	end

	if self.prop2mesh_refresh then
		refreshAll(self, self.prop2mesh_controllers)

		self.prop2mesh_refresh = nil
	end
end

function ENT:OnRemove()
	local snapshot = self.prop2mesh_controllers
	if not snapshot or next(snapshot) == nil then
		return
	end
	timer.Simple(0, function()
		if IsValid(self) then
			return
		end
		discard(self, snapshot)
	end)
end

function ENT:GetAllDataReady()
	for k, info in ipairs(self.prop2mesh_controllers) do
		local crc = info.crc
		if not crc or crc == "!none" then
			goto CONTINUE
		end

		if not recycle[crc] or not recycle[crc].zip then
			return false
		else
			local meshes = recycle[crc].meshes[info.uvs]
			if meshes and not meshes.ready then
				return false
			end
		end

		::CONTINUE::
	end

	return true
end

function ENT:GetDownloadProgress()
	local max
	for i = 1, #self.prop2mesh_controllers do
		local stream = recycle[self.prop2mesh_controllers[i].crc].stream
		if stream then
			if not max then max = 0 end
			local progress = stream:GetProgress()
			if max < progress then
				max = progress
			end
		end
	end
	return max
end


--[[

]]
local kvpass = {}
kvpass.crc = function(self, info, val)
	local crc = info.crc
	info.crc = val

	local keepdata
	for k, v in pairs(self.prop2mesh_controllers) do
		if v.crc == crc then
			keepdata = true
			break
		end
	end

	if not keepdata then
		setuser(self, crc, false)
	end
end

local function safeuvs(val)
	val = math.abs(math.floor(tonumber(val) or 0))
	if val > 512 then val = 512 end
	return val
end

kvpass.uvs = function(self, info, val)
	info.uvs = safeuvs(val)
end

-- https:--github.com/wiremod/wire/blob/1a0c31105d5a02a243cf042ea413867fb569ab4c/lua/wire/wireshared.lua#L56
local function normalizedFilepath(path)
    local null = string.find(path, "\x00", 1, true)

    if null then
        path = string.sub(path, 1, null - 1)
    end

    local tbl = string.Explode("[/\\]+", path, true)
    local i = 1

    while i <= #tbl do
        if tbl[i] == "." or tbl[i] == "" then
            table.remove(tbl, i)
        elseif tbl[i] == ".." then
            table.remove(tbl, i)

            if i > 1 then
                i = i - 1
                table.remove(tbl, i)
            end
        else
            i = i + 1
        end
    end

    return table.concat(tbl, "/")
end

local baddies = {
	["effects/ar2_altfire1"] = true,
	["engine/writez"] = true,
	["pp/copy"] = true,
}

local function safemat(val)
	val = string.sub(val, 1, 260)
	local path = string.StripExtension(normalizedFilepath(string.lower(val)))
	if baddies[path] then return "" end
	return val
end

kvpass.mat = function(self, info, val)
	info.mat = safemat(val)
end


--[[

]]
net.Receive("prop2mesh_update", function(len)
	local self = net.ReadEntity()
	if not prop2mesh.isValid(self) then
		return
	end

	local synctime = net.ReadString()

	for index, update in pairs(net.ReadTable()) do
		local info = self.prop2mesh_controllers[index]
		if not info then
			self.prop2mesh_sync = nil
			return
		end
		for key, val in pairs(update) do
			if kvpass[key] then kvpass[key](self, info, val) else info[key] = val end
		end
		refresh(self, info)
	end

	self.prop2mesh_synctime = synctime
	self.prop2mesh_triggertool = true
	self.prop2mesh_triggereditor = prop2mesh.editor and true
end)

net.Receive("prop2mesh_sync", function(len)
	local self = net.ReadEntity()
	if not prop2mesh.isValid(self) then
		return
	end

	discard(self, self.prop2mesh_controllers)

	self.prop2mesh_synctime = net.ReadString()
	self.prop2mesh_controllers = {}

	for i = 1, net.ReadUInt(8) do
		self.prop2mesh_controllers[i] = {
			crc   = net.ReadString(),
			uvs   = safeuvs(net.ReadUInt(12)),
			mat   = safemat(net.ReadString()),
			col   = Color(net.ReadUInt(8), net.ReadUInt(8), net.ReadUInt(8), net.ReadUInt(8)),
			scale = Vector(net.ReadFloat(), net.ReadFloat(), net.ReadFloat()),
			index = i,
		}
	end

	self.prop2mesh_refresh = true
	self.prop2mesh_triggertool = true
	self.prop2mesh_triggereditor = prop2mesh.editor and true
end)

prop2mesh.downloads = 0
net.Receive("prop2mesh_download", function(len)
	local crc = net.ReadString()
	recycle[crc].stream = net.ReadStream(nil, function(data)
		if not recycle[crc] then
			recycle[crc] = { users = {}, meshes = {} }
		end
		if crc == util.CRC(data) then
			recycle[crc].zip = data
			for user in pairs(recycle[crc].users) do
				for k, info in pairs(user.prop2mesh_controllers) do
					if info.crc == crc then
						checkmesh(crc, info.uvs)
					end
				end
			end
		else
			garbage[crc] = SysTime() + 500
		end
		recycle[crc].stream = nil
		prop2mesh.downloads = math.max(0, prop2mesh.downloads - 1)
	end)
	prop2mesh.downloads = prop2mesh.downloads + 1
end)

hook.Add("NotifyShouldTransmit", "prop2mesh_sync", function(self, bool)
	if bool then self.prop2mesh_sync = nil end
end)

hook.Add("OnGamemodeLoaded", "prop2mesh_sync", function()
	for k, self in ipairs(ents.FindByClass("sent_prop2mesh*")) do
		self.prop2mesh_sync = nil
	end
end)