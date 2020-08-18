-- -----------------------------------------------------------------------------
DEFINE_BASECLASS("base_anim")

ENT.PrintName   = "Prop 2 Mesh"
ENT.Author      = "shadowscion"
ENT.RenderGroup = RENDERGROUP_OPAQUE


-- -----------------------------------------------------------------------------
function ENT:GetPlayer()
	local ply = self:GetNWEntity("Founder", NULL)
	if not IsValid(ply) then
		ply = player.GetBySteamID64(self:GetNWString("FounderID", "NONE"))
	end
	return ply
end


-- -----------------------------------------------------------------------------
function ENT:GetCRC()
	local value = self:GetNWString("P2M_CRC", "NONE")
	if value == "NONE" then
		return nil
	end
	return value
end


-- -----------------------------------------------------------------------------
function ENT:GetTextureScale()
	return math.max(self:GetNWInt("P2M_TSCALE", 0), 0)
end

function ENT:GetMeshScale()
	return self:GetNWInt("P2M_MSCALE", 1)
end
