-- -----------------------------------------------------------------------------
DEFINE_BASECLASS("base_anim")

ENT.PrintName   = "P2M Controller"
ENT.Author      = "shadowscion"
ENT.AdminOnly   = false
ENT.Spawnable   = false
ENT.RenderGroup = RENDERGROUP_OPAQUE

cleanup.Register("gmod_ent_p2m")


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


-- -----------------------------------------------------------------------------
properties.Add("p2m_options", {
	PrependSpacer = true,
	Order     = 3001,
	MenuLabel = "P2M",
	MenuIcon  = "icon16/disk.png",

	Filter = function(self, ent, ply)

		if not IsValid(ent) or ent:GetClass() ~= "gmod_ent_p2m" then
			return false
		end
		if ent:GetPlayer() ~= LocalPlayer() then
			return false
		end
		return true

	end,

	MenuOpen = function(self, dmenu, ent, tr)
		local crc = ent:GetCRC()
		if not p2mlib or not crc or not p2mlib.models[crc] or not p2mlib.models[crc].data then
			return
		end
		if crc ~= util.CRC(p2mlib.models[crc].data) then
			return
		end

		local sub = dmenu:AddSubMenu()

		sub:AddOption("Edit models", function()
		end):SetIcon("icon16/bricks.png")

		sub:AddOption("Export to E2", function()
			p2mlib.exportToE2(util.JSONToTable(util.Decompress(p2mlib.models[crc].data)), ent:GetTextureScale(), ent:GetMeshScale())
		end):SetIcon("icon16/cog.png")

		-- sub:AddOption("as .obj", function()
		-- 	file.CreateDir("prop2mesh/exportobj")
		-- 	Derma_StringRequest("", ".OBJ filename", "",
		-- 	function(text)
		-- 		local filename = string.gsub(string.StripExtension(string.GetFileFromFilename(text)), "%W","")
		-- 		file.Write(string.format("prop2mesh/exportobj/%s.txt", filename), "testa")
		-- 	end, function() end)
		-- end):SetIcon("icon16/bullet_black.png")
	end,
})
