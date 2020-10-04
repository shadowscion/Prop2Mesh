-- -----------------------------------------------------------------------------
AddCSLuaFile("p2m/p2mlib.lua")
AddCSLuaFile("p2m/funkymodels.lua")
AddCSLuaFile("p2m/editor.lua")
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

resource.AddFile("materials/p2m/grid.vmt")


-- -----------------------------------------------------------------------------
util.AddNetworkString("NetP2M.GetModels")
util.AddNetworkString("NetP2M.UpdateAll")
util.AddNetworkString("NetP2M.MakeChanges")


-- -----------------------------------------------------------------------------
function ENT:Initialize()

	self:DrawShadow(false)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)

	local phys = self:GetPhysicsObject()
	if phys:IsValid() then
		phys:EnableMotion(false)
		phys:Wake()
	end

end


-- -----------------------------------------------------------------------------
function ENT:SetPlayer(ply)

	ply:AddCount("gmod_ent_p2m", self)
	ply:AddCleanup("gmod_ent_p2m", self)

	self:SetNWEntity("Founder", ply)
	self:SetNWString("FounderID", ply:SteamID64())

end


-- -----------------------------------------------------------------------------
function ENT:SetTextureScale(scale)

	local scale = math.floor(scale * 0.5) * 2

	duplicator.StoreEntityModifier(self, "p2m_mods", { tscale = scale } )

	self:SetNWInt("P2M_TSCALE", scale)

	self:Invalidate()

end


-- -----------------------------------------------------------------------------
function ENT:SetMeshScale(scale)

	local scale = math.Clamp(scale, 0.1, 1)

	duplicator.StoreEntityModifier(self, "p2m_mods", { mscale = scale } )

	self:SetNWFloat("P2M_MSCALE", scale)

	--self:Invalidate()

end


-- -----------------------------------------------------------------------------
function ENT:Invalidate(ply, notify_old)

	timer.Simple(0.1, function()
		net.Start("NetP2M.UpdateAll")
		net.WriteEntity(self)
		if notify_old then
			net.WriteString(notify_old)
		end
		if ply then net.Send(ply) else net.Broadcast() end
	end)

end


-- -----------------------------------------------------------------------------
function ENT:SetModelsFromTable(data, notify_old)

	duplicator.ClearEntityModifier(self, "p2m_packets")

	local json = util.Compress(util.TableToJSON(data))
	local packets = {}
	for i = 1, string.len(json), 32000 do
		local c = string.sub(json, i, i + math.min(32000, string.len(json) - i + 1) - 1)
		packets[#packets + 1] = { c, string.len(c) }
	end

	packets.crc = util.CRC(json)

	self:SetNWString("P2M_CRC", packets.crc)

	self:Invalidate(nil, notify_old)

	duplicator.StoreEntityModifier(self, "p2m_packets", packets)

end


-- -----------------------------------------------------------------------------
function ENT:AddModelsToTable(data)

	local packets = self:GetPacketsAsTable()

	if not packets then
		return
	end

	for i = 1, #data do
		packets[#packets + 1] = data[i]
	end

	self:SetModelsFromTable(packets, self:GetCRC())

end


-- -----------------------------------------------------------------------------
function ENT:GetPackets()

	return self.EntityMods and self.EntityMods.p2m_packets

end

function ENT:GetPacketsAsTable()

	local packets = self:GetPackets()
	if packets and packets.crc == self:GetCRC() then
		local data = {}
		for i, packet in ipairs(packets) do
			data[#data + 1] = packet[1]
		end
		return util.JSONToTable(util.Decompress(table.concat(data)))
	else
		return nil
	end

end


-- -----------------------------------------------------------------------------
net.Receive("NetP2M.GetModels", function(len, ply)

	local controller = net.ReadEntity()
	if not IsValid(controller) or controller:GetClass() ~= "gmod_ent_p2m" then
		return
	end

	local packets = controller:GetPackets()
	if packets and packets.crc == controller:GetCRC() then
		for i, packet in ipairs(packets) do
			net.Start("NetP2M.GetModels")
				net.WriteString(packets.crc)
				net.WriteUInt(i, 16)
				net.WriteUInt(packet[2], 32)
				net.WriteData(packet[1], packet[2])
				net.WriteBool(i == #packets)
			net.Send(ply)
		end
	end

end)


-- -----------------------------------------------------------------------------
local safeData = {}

safeData.inv = function(value, data)
	data.inv = tobool(value) or nil
end

safeData.flat = function(value, data)
	data.flat = tobool(value) or nil
end

safeData.flip = function(value, data)
	data.flip = tobool(value) or nil
end

safeData.smooth = function(value, data)
	local num = tonumber(value or 0)
	data.smooth = num > 0 and math.Clamp(math.abs(num), 0, 180) or nil
end

safeData.pos = function(value, data, unsetZero)
	if type(value) ~= "Vector" then
		data.pos = Vector()
		return
	end
	data.pos = Vector(math.Clamp(value.x, -16384, 16834), math.Clamp(value.y, -16384, 16834), math.Clamp(value.z, -16384, 16834))
end

safeData.ang = function(value, data, unsetZero)
	if type(value) ~= "Angle" then
		data.ang = Angle()
		return
	end
	data.ang = Angle(math.Clamp(value.p, -16384, 16834), math.Clamp(value.y, -16384, 16834), math.Clamp(value.r, -16384, 16834))
	data.ang:Normalize()
end

safeData.scale = function(value, data)
	if type(value) ~= "Vector" then
		data.scale = Vector(1,1,1)
		return
	end
	data.scale = Vector(math.Clamp(value.x, -16384, 16834), math.Clamp(value.y, -16384, 16834), math.Clamp(value.z, -16384, 16834))
end

net.Receive("NetP2M.MakeChanges", function(len, ply)

	local controller = net.ReadEntity()
	if not IsValid(controller) or controller:GetClass() ~= "gmod_ent_p2m" or controller:GetPlayer() ~= ply then
		return
	end

	local netSize_changes = net.ReadUInt(32)
	local netData_changes = util.JSONToTable(util.Decompress(net.ReadData(netSize_changes)))

	if next(netData_changes) == nil then
		return
	end

	local mesh_update
	if netData_changes.edits or netData_changes.additions then
		mesh_update = {}

		local p2mData_old = controller:GetPacketsAsTable()
		if p2mData_old then
			for partID, partData in ipairs(p2mData_old) do
				if netData_changes.edits and netData_changes.edits[partID] then
					if netData_changes.edits[partID].delete then
						goto skip
					else
						for changeKey, changeValue in pairs(netData_changes.edits[partID]) do
							if safeData[changeKey] then
								safeData[changeKey](changeValue, partData)
							end
						end
					end
				end

				mesh_update[#mesh_update + 1] = partData

				::skip::
			end
		end

		if netData_changes.additions then
			for k, partData in pairs(netData_changes.additions) do
				if not partData.obj or type(partData.obj) ~= "string" then
					continue
				end

				local data = {}

				data.name = string.lower(string.Trim(partData.name or "no_name"))
				data.obj  = partData.obj

				safeData.smooth(partData.smooth, data)
				safeData.flip(partData.flip, data)
				safeData.inv(partData.inv, data)
				safeData.pos(partData.pos, data)
				safeData.ang(partData.ang, data)
				safeData.scale(partData.scale, data)

				mesh_update[#mesh_update + 1] = data
			end
		end
	end

	if netData_changes.settings then
		if netData_changes.settings.P2M_TSCALE then
			controller:SetTextureScale(math.Clamp(math.abs(netData_changes.settings.P2M_TSCALE), 0, 512))
		end
		if netData_changes.settings.P2M_MSCALE then
			controller:SetMeshScale(netData_changes.settings.P2M_MSCALE)
		end
		if netData_changes.settings.color then
			local color = netData_changes.settings.color
			color.r = math.Clamp(color.r, 0, 255)
			color.g = math.Clamp(color.g, 0, 255)
			color.b = math.Clamp(color.b, 0, 255)
			color.a = math.Clamp(color.a, 0, 255)

			local rendermode = controller:GetRenderMode()
			if rendermode == RENDERMODE_NORMAL or rendermode == RENDERMODE_TRANSALPHA then
				rendermode = color.a == 255 and RENDERMODE_NORMAL or RENDERMODE_TRANSALPHA
				controller:SetRenderMode(rendermode)
			else
				rendermode = nil
			end

			controller:SetColor(color)
			duplicator.StoreEntityModifier(controller, "colour", { Color = color, RenderMode = rendermode })
		end
		if netData_changes.settings.material then
			if list.Contains("OverrideMaterials", netData_changes.settings.material) and netData_changes.settings.material ~= "" then
				controller:SetMaterial(netData_changes.settings.material)
				duplicator.StoreEntityModifier(controller, "material",  { MaterialOverride = netData_changes.settings.material })
			end
		end
	end

	if mesh_update then
		controller:SetModelsFromTable(mesh_update, controller:GetCRC())
	end

end)


-- -----------------------------------------------------------------------------
duplicator.RegisterEntityClass("gmod_ent_p2m", function(ply, data)

	local controller = ents.Create(data.Class)
	if not IsValid(controller) then
		return false
	end

	duplicator.DoGeneric(controller, data)
	controller:Spawn()
	controller:Activate()
	controller:SetPlayer(ply)

	if data.EntityMods then
		if data.EntityMods.p2m_packets then
			controller:SetNWString("P2M_CRC", data.EntityMods.p2m_packets.crc)
		end
		if data.EntityMods.p2m_mods then
			controller:SetNWInt("P2M_TSCALE", data.EntityMods.p2m_mods.tscale or 0)
			controller:SetNWFloat("P2M_MSCALE", data.EntityMods.p2m_mods.mscale or 1)
		end
	end

	controller:Invalidate()

	return controller

end, "Data")
