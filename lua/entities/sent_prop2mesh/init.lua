--[[

]]
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local net = net
local util = util
local table = table
local pairs = pairs
local ipairs = ipairs
local prop2mesh = prop2mesh


--[[

]]
util.AddNetworkString("prop2mesh_sync")
util.AddNetworkString("prop2mesh_update")
util.AddNetworkString("prop2mesh_download")

net.Receive("prop2mesh_sync", function(len, pl)
	local self = net.ReadEntity()
	if not prop2mesh.isValid(self) then
		return
	end
	if not self.prop2mesh_syncwith then
		self.prop2mesh_syncwith = {}
	end
	self.prop2mesh_syncwith[pl] = net.ReadString()
end)

net.Receive("prop2mesh_download", function(len, pl)
	local self = net.ReadEntity()
	if not prop2mesh.isValid(self) then
		return
	end
	local crc = net.ReadString()
	if self.prop2mesh_partlists[crc] then
		net.Start("prop2mesh_download")
		net.WriteString(crc)
		net.WriteStream(self.prop2mesh_partlists[crc])
		net.Send(pl)
	end
end)


--[[

]]
function ENT:Initialize()
	self:DrawShadow(false)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)

	self.prop2mesh_controllers = {}
	self.prop2mesh_partlists = {}
	self.prop2mesh_sync = true
end

function ENT:SetPlayer(pl)
	self:SetVar("Founder", pl)
end

function ENT:GetPlayer()
	return self:GetVar("Founder", NULL)
end

function ENT:Think()
	if self.prop2mesh_upload_queue then
		self:SetNetworkedBool("uploading", true)
		return
	end

	if self.prop2mesh_sync then
		self.prop2mesh_updates = nil
		self.prop2mesh_synctime = SysTime() .. ""
		self.prop2mesh_syncwith = nil
		self.prop2mesh_sync = nil

		self:SendControllers()
	else
		if self.prop2mesh_syncwith then
			local syncwith = {}
			for pl, pltime in pairs(self.prop2mesh_syncwith) do
				if IsValid(pl) and pltime ~= self.prop2mesh_synctime then
					syncwith[#syncwith + 1] = pl
				end
			end

			if next(syncwith) then
				self:SendControllers(syncwith)
			end

			self.prop2mesh_syncwith = nil
		end
		if self.prop2mesh_updates then
			self.prop2mesh_synctime = SysTime() .. ""

			net.Start("prop2mesh_update")
			net.WriteEntity(self)
			net.WriteString(self.prop2mesh_synctime)

			for index, update in pairs(self.prop2mesh_updates) do
				for key in pairs(update) do
					update[key] = self.prop2mesh_controllers[index][key]
				end
			end

			net.WriteTable(self.prop2mesh_updates)
			net.Broadcast()

			self.prop2mesh_updates = nil
		else
			if self:GetNetworkedBool("uploading") then
				self:SetNetworkedBool("uploading", false)
			end
		end
	end
end

function ENT:PreEntityCopy()
	duplicator.StoreEntityModifier(self, "prop2mesh", {
		[1] = self.prop2mesh_controllers,
		[2] = self.prop2mesh_partlists,
	})
end

function ENT:PostEntityCopy()
	duplicator.ClearEntityModifier(self, "prop2mesh")
end

function ENT:PostEntityPaste()
	duplicator.ClearEntityModifier(self, "prop2mesh")
end

duplicator.RegisterEntityModifier("prop2mesh", function(ply, self, dupe)
	if not prop2mesh.isValid(self) then
		return
	end
	local dupe_controllers = dupe[1]
	if istable(dupe_controllers) and next(dupe_controllers) and table.IsSequential(dupe_controllers) then
		self.prop2mesh_sync = true

		local dupe_data = dupe[2]
		local dupe_lookup = {}

		self.prop2mesh_controllers = {}
		for k, v in ipairs(dupe_controllers) do
			local info = self:AddController()
			self:SetControllerCol(k, v.col)
			self:SetControllerMat(k, v.mat)
			self:SetControllerUVS(k, v.uvs)
			self:SetControllerScale(k, v.scale)

			if dupe_data and dupe_data[v.crc] then
				dupe_lookup[v.crc] = true
				info.crc = v.crc
			end
		end

		self.prop2mesh_partlists = {}
		for crc in pairs(dupe_lookup) do
			self.prop2mesh_partlists[crc] = dupe_data[crc]
		end
	end
end)

function ENT:AddController()
	table.insert(self.prop2mesh_controllers, prop2mesh.getEmpty())
	self.prop2mesh_sync = true
	return self.prop2mesh_controllers[#self.prop2mesh_controllers]
end

function ENT:RemoveController(index)
	if not self.prop2mesh_controllers[index] then
		return false
	end

	local crc = self.prop2mesh_controllers[index].crc
	table.remove(self.prop2mesh_controllers, index)

	local keepdata
	for k, info in pairs(self.prop2mesh_controllers) do
		if info.crc == crc then
			keepdata = true
			break
		end
	end

	if not keepdata then
		self.prop2mesh_partlists[crc] = nil
	end

	self.prop2mesh_sync = true

	return true
end

function ENT:SendControllers(syncwith)
	net.Start("prop2mesh_sync")

	net.WriteEntity(self)
	net.WriteString(self.prop2mesh_synctime)
	net.WriteUInt(#self.prop2mesh_controllers, 8)

	for i = 1, #self.prop2mesh_controllers do
		local info = self.prop2mesh_controllers[i]
		net.WriteString(info.crc)
		net.WriteUInt(info.uvs, 12)
		net.WriteString(info.mat)
		net.WriteUInt(info.col.r, 8)
		net.WriteUInt(info.col.g, 8)
		net.WriteUInt(info.col.b, 8)
		net.WriteUInt(info.col.a, 8)
		net.WriteFloat(info.scale.x)
		net.WriteFloat(info.scale.y)
		net.WriteFloat(info.scale.z)
	end

	if syncwith then
		net.Send(syncwith)
	else
		net.Broadcast()
	end
end

function ENT:AddControllerUpdate(index, key)
	if self.prop2mesh_sync or not self.prop2mesh_controllers[index] then
		return
	end
	if not self.prop2mesh_updates then self.prop2mesh_updates = {} end
	if not self.prop2mesh_updates[index] then self.prop2mesh_updates[index] = {} end
	self.prop2mesh_updates[index][key] = true
end

function ENT:SetControllerCol(index, val)
	local info = self.prop2mesh_controllers[index]
	if (info and IsColor(val)) and (info.col.r ~= val.r or info.col.g ~= val.g or info.col.b ~= val.b or info.col.a ~= val.a) then
		info.col.r = val.r
		info.col.g = val.g
		info.col.b = val.b
		info.col.a = val.a
		self:AddControllerUpdate(index, "col")
	end
end

function ENT:SetControllerMat(index, val)
	local info = self.prop2mesh_controllers[index]
	if (info and isstring(val)) and (info.mat ~= val) then
		info.mat = val
		self:AddControllerUpdate(index, "mat")
	end
end

function ENT:SetControllerScale(index, val)
	local info = self.prop2mesh_controllers[index]
	if (info and isvector(val)) and (info.scale.x ~= val.x or info.scale.y ~= val.y or info.scale.z ~= val.z) then
		info.scale.x = val.x
		info.scale.y = val.y
		info.scale.z = val.z
		self:AddControllerUpdate(index, "scale")
	end
end

function ENT:SetControllerUVS(index, val)
	local info = self.prop2mesh_controllers[index]
	if (info and isnumber(val)) and (info.uvs ~= val) then
		info.uvs = val
		self:AddControllerUpdate(index, "uvs")
	end
end

function ENT:ResetControllerData(index)
	if self.prop2mesh_controllers[index] then
		self.prop2mesh_controllers[index].crc = "!none"
		self:AddControllerUpdate(index, "crc")
	end
end

function ENT:SetControllerData(index, partlist, uvs)
	local info = self.prop2mesh_controllers[index]
	if not info or not partlist then
		return
	end

	if not next(partlist) then
		self:ResetControllerData(index)
		return
	end

	prop2mesh.sanitizeCustom(partlist)

	local json = util.TableToJSON(partlist)
	if not json then
		return
	end

	local data = util.Compress(json)
	local dcrc = util.CRC(data)
	local icrc = info.crc

	if icrc == dcrc then
		return
	end

	self.prop2mesh_partlists[dcrc] = data

	info.crc = dcrc
	self:AddControllerUpdate(index, "crc")
	if uvs then
		info.uvs = uvs
		self:AddControllerUpdate(index, "uvs")
	end

	local keepdata
	for k, v in pairs(self.prop2mesh_controllers) do
		if v.crc == icrc then
			keepdata = true
			break
		end
	end
	if not keepdata then
		self.prop2mesh_partlists[icrc] = nil
	end
end

function ENT:GetControllerData(index, nodecomp)
	if not self.prop2mesh_controllers[index] then
		return
	end
	local ret = self.prop2mesh_partlists[self.prop2mesh_controllers[index].crc]
	if not ret or nodecomp then
		return ret
	end
	return util.JSONToTable(util.Decompress(ret))
end

function ENT:ToolDataByINDEX(index, tool)
	if not self.prop2mesh_controllers[index] then
		return false
	end

	local pos = self:GetPos()
	local ang = self:GetAngles()

	if tool:GetClientNumber("tool_setautocenter") ~= 0 then
		pos = Vector()
		local num = 0
		for ent, _ in pairs(tool.selection) do
			pos = pos + ent:GetPos()
			num = num + 1
		end
		pos = pos * (1 / num)
	end

	self:SetControllerData(index, prop2mesh.partsFromEnts(tool.selection, pos, ang), tool:GetClientNumber("tool_setuvsize"))
end

function ENT:ToolDataAUTO(tool)
	local autocenter = tool:GetClientNumber("tool_setautocenter") ~= 0
	local pos, ang, num

	if autocenter then
		pos = Vector()
		ang = self:GetAngles()
		num = 0
	else
		pos = self:GetPos()
		ang = self:GetAngles()
	end

	local sorted = {}
	for k, v in pairs(tool.selection) do
		local vmat = v.mat
		if vmat == "" then vmat = prop2mesh.defaultmat end

		if not sorted[vmat] then
			sorted[vmat] = {}
		end
		local key = string.format("%d %d %d %d", v.col.r, v.col.g, v.col.b, v.col.a)
		if not sorted[vmat][key] then
			sorted[vmat][key] = {}
		end
		table.insert(sorted[vmat][key], k)
		if autocenter then
			pos = pos + k:GetPos()
			num = num + 1
		end
	end

	if autocenter then
		pos = pos * (1 / num)
	end

	local uvs = tool:GetClientNumber("tool_setuvsize")

	for kmat, vmat in pairs(sorted) do
		for kcol, vcol in pairs(vmat) do
			local parts = prop2mesh.partsFromEnts(vcol, pos, ang)
			if parts then
				local info = self:AddController()
				local temp = string.Explode(" ", kcol)
				info.col = Color(temp[1], temp[2], temp[3], temp[4])
				info.mat = kmat
				info.uvs = parts.uvs or uvs
				if parts.uvs then parts.uvs = nil end
				self:SetControllerData(#self.prop2mesh_controllers, parts)
			end
		end
	end
end
