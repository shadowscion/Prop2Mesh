AddCSLuaFile()
DEFINE_BASECLASS("sent_prop2mesh")

ENT.PrintName   = "sent_prop2mesh_legacy"
ENT.Author      = "shadowscion"
ENT.AdminOnly   = false
--ENT.Spawnable   = true
--ENT.Category    = "prop2mesh"
ENT.RenderGroup = RENDERGROUP_BOTH

cleanup.Register("sent_prop2mesh_legacy")

if CLIENT then
	local cvar = CreateClientConVar("prop2mesh_legacy_hide", 0, true, false)
	local draw_disable = cvar:GetBool()

	cvars.AddChangeCallback("prop2mesh_legacy_hide", function(cvar, old, new)
	    draw_disable = tobool(new)
	end, "swaplegacyhide")

	function ENT:Draw()
		if draw_disable then
			return
		end
		self:DrawModel()
	end

	return
end


function ENT:Think()
	local info = self.prop2mesh_controllers[1]
	if info then
		local val = self:GetColor()

		if info.col.r ~= val.r or info.col.g ~= val.g or info.col.b ~= val.b or info.col.a ~= val.a then
			info.col.r = val.r
			info.col.g = val.g
			info.col.b = val.b
			info.col.a = val.a

			self:AddControllerUpdate(1, "col")
		end

		local val = self:GetMaterial()

		if info.mat ~= val and not string.find(val, ";") then
			info.mat = val

			self:AddControllerUpdate(1, "mat")
		end
	end

	BaseClass.Think(self)
end

function ENT:AddController(uvs, scale)
	for k, v in pairs(self.prop2mesh_controllers) do
		self:RemoveController(k)
	end

	BaseClass.AddController(self)

	self:SetControllerUVS(1, uvs)
	self:SetControllerScale(1, scale)

	return self.prop2mesh_controllers[1]
end

function ENT:PostEntityPaste()
	duplicator.ClearEntityModifier(self, "p2m_mods")
	duplicator.ClearEntityModifier(self, "p2m_packets")
	duplicator.ClearEntityModifier(self, "prop2mesh")
end


-- COMPATIBILITY
local function getLegacyMods(data)
	local uvs, scale
	if istable(data) then
		uvs = tonumber(data.tscale)
		scale = tonumber(data.mscale)
		if scale then
			scale = Vector(scale, scale, scale)
		end
	end
	return uvs, scale
end

local function getLegacyParts(data)
	local parts
	if istable(data) then
		local zip = {}
		for i = 1, #data do
			zip[#zip + 1] = data[i][1]
		end
		zip = table.concat(zip)
		if util.CRC(zip) == data.crc then
			local json = util.JSONToTable(util.Decompress(zip))
			if next(json) then
				parts = {}
				for k, v in ipairs(json) do
					local part = { pos = v.pos, ang = v.ang, clips = v.clips, bodygroup = v.bgrp }

					if v.scale and (v.scale.x ~= 1 or v.scale.y ~= 1 or v.scale.z ~= 1) then
						part.scale = v.scale
					end

					if v.obj then
						local crc = util.CRC(v.obj)
						if not parts.custom then parts.custom = {} end
						parts.custom[crc] = v.obj

						part.objd = crc
						part.objn = v.name or crc
						part.vsmooth = tonumber(v.smooth)
						part.vinvert = v.flip and 1 or nil
						part.vinside = v.inv and 1 or nil
					else
						if v.holo then part.holo = v.mdl else part.prop = v.mdl end

						part.vinside = v.inv and 1 or nil
						part.vsmooth = v.flat and 1 or nil
					end

					parts[#parts + 1] = part
				end
			end
		end
	end
	return parts
end

local function getLegacyInfo(data)
	if not data then
		return
	end
	local uvs, scale = getLegacyMods(data.p2m_mods)
	return uvs, scale, getLegacyParts(data.p2m_packets)
end

local function getLegacyClips(data)
	if not data then
		return
	end

	local clip1 = data.proper_clipping
	local clip2 = data.clips

	data.proper_clipping = nil
	data.clips = nil

	return clip1, clip2
end

duplicator.RegisterEntityClass("gmod_ent_p2m", function(ply, data)
	local compat = ents.Create("sent_prop2mesh_legacy")
	if not IsValid(compat) then
		return false
	end

	local clip1, clip2 = getLegacyClips(data.EntityMods)

	duplicator.DoGeneric(compat, data)
	compat:Spawn()
	compat:Activate()

	if CPPI and compat.CPPISetOwner then
		compat:CPPISetOwner(ply)
	end

	compat:SetPlayer(ply)

	local uvs, scale, parts = getLegacyInfo(data.EntityMods)

	compat:AddController(uvs, scale)
	compat:SetControllerData(1, parts)

	if clip1 or clip2 then
		local clips = {}
		if clip1 then -- proper clipping
			for i = 1, #clip1 do
				local clip = clip1[i]
				local norm = clip[1]
				clips[#clips + 1] = { norm.x, norm.y, norm.z, clip[2] }
			end
		elseif clip2 then -- stinky visclip adv
			for i = 1, #clip2 do
				local clip = clip2[i]
				local norm = clip.n:Forward()
				local dist = clip.d
				if clip.new then
					dist = dist + norm:Dot(compat:OBBCenter())
				end
				clips[#clips + 1] = { norm.x, norm.y, norm.z, dist }
			end
		end
		if next(clips) then
			for _, clip in pairs(clips) do
				compat:AddControllerClip(1, unpack(clip))
			end
		end
	end

	return compat
end, "Data")
