-- -----------------------------------------------------------------------------
AddCSLuaFile("p2m/p2mlib.lua")
AddCSLuaFile("p2m/funkymodels.lua")
AddCSLuaFile("p2m/editor.lua")
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")


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

	self:Invalidate()

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
net.Receive("NetP2M.MakeChanges", function(len, ply)

	local controller = net.ReadEntity()
	if not IsValid(controller) or controller:GetClass() ~= "gmod_ent_p2m" then
		return
	end

	if controller:GetPlayer() ~= ply then
		return
	end

	local models = controller:GetPacketsAsTable()
	if models then
		local size = net.ReadUInt(32)
		local changes = util.JSONToTable(util.Decompress(net.ReadData(size)))
		if next(changes) == nil then
			return
		end

		local data = {}
		for k, v in ipairs(models) do
			if changes[k] then
				if changes[k].delete then
					goto skip
				else
					for change, newvalue in pairs(changes[k]) do
						if type(newvalue) == "boolean" then -- temporary
							v[change] = newvalue or nil
						end
					end
				end
			end

			data[#data + 1] = v

			::skip::
		end

		controller:SetModelsFromTable(data, controller:GetCRC())

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
