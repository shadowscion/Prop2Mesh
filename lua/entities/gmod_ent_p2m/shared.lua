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
properties.Add("p2m_export_e2", {

	MenuLabel = "Export to E2",
	Order     = 0,
	MenuIcon  = "icon16/connect.png",

	Filter = function(self, ent, ply)

		if not IsValid(ent) or ent:GetClass() ~= "gmod_ent_p2m" then
			return false
		end
		if ent:GetPlayer() ~= LocalPlayer() then
			return false
		end
		return true

	end,

	Action = function(self, ent)

		local crc = ent:GetCRC()
		if not p2mlib or not crc or not p2mlib.models[crc] or not p2mlib.models[crc].data then
			return
		end
		if crc ~= util.CRC(p2mlib.models[crc].data) then
			return
		end

		local header = string.format("local P2M = p2mCreate(entity():pos(), entity():angles(), %d, %f)\n\n", ent:GetTextureScale(), ent:GetMeshScale())
		local footer = "\nP2M:p2mBuild()\n\n"

		local export = { "@name\n@inputs\n@outputs\n@persist\n@trigger\n\n", header }
		local mcount = 0

		for k, model in SortedPairsByMemberValue(util.JSONToTable(util.Decompress(p2mlib.models[crc].data)), "mdl") do
			if not model.scale and not model.clips then
				export[#export + 1] = string.format("P2M:p2mPushModel(\"%s\", vec(%f, %f, %f), ang(%f, %f, %f))\n",
					model.mdl, model.pos.x, model.pos.y, model.pos.z, model.ang.p, model.ang.y, model.ang.r)

			elseif model.scale and not model.clips then
				export[#export + 1] = string.format("P2M:p2mPushModel(\"%s\", vec(%f, %f, %f), ang(%f, %f, %f), vec(%f, %f, %f))\n",
					model.mdl, model.pos.x, model.pos.y, model.pos.z, model.ang.p, model.ang.y, model.ang.r, model.scale.x, model.scale.y, model.scale.z)

			elseif model.scale and model.clips then
				local sclips = {}
				for i, clip in ipairs(model.clips) do
					local pos = clip.n * clip.d
					if i ~= #model.clips then
						sclips[#sclips + 1] = string.format("vec(%f, %f, %f), vec(%f, %f, %f), ", pos.x, pos.y, pos.z, clip.n.x, clip.n.y, clip.n.z)
					else
						sclips[#sclips + 1] = string.format("vec(%f, %f, %f), vec(%f, %f, %f)", pos.x, pos.y, pos.z, clip.n.x, clip.n.y, clip.n.z)
					end
				end
				export[#export + 1] = string.format("P2M:p2mPushModel(\"%s\", vec(%f, %f, %f), ang(%f, %f, %f), vec(%f, %f, %f), %d, array(%s))\n",
					model.mdl, model.pos.x, model.pos.y, model.pos.z, model.ang.p, model.ang.y, model.ang.r, model.scale.x, model.scale.y, model.scale.z, model.inv and 1 or 0, table.concat(sclips))

			elseif not model.scale and model.clips then
				local sclips = {}
				for i, clip in ipairs(model.clips) do
					local pos = clip.n * clip.d
					if i ~= #model.clips then
						sclips[#sclips + 1] = string.format("vec(%f, %f, %f), vec(%f, %f, %f), ", pos.x, pos.y, pos.z, clip.n.x, clip.n.y, clip.n.z)
					else
						sclips[#sclips + 1] = string.format("vec(%f, %f, %f), vec(%f, %f, %f)", pos.x, pos.y, pos.z, clip.n.x, clip.n.y, clip.n.z)
					end
				end
				export[#export + 1] = string.format("P2M:p2mPushModel(\"%s\", vec(%f, %f, %f), ang(%f, %f, %f), %d, array(%s))\n",
					model.mdl, model.pos.x, model.pos.y, model.pos.z, model.ang.p, model.ang.y, model.ang.r, model.inv and 1 or 0, table.concat(sclips))

			end

			mcount = mcount + 1
			if mcount == 250 then
				export[#export + 1] = footer
				export[#export + 1] = header
				mcount = 0
			end
		end

		export[#export + 1] = footer

	    openE2Editor()
	    if wire_expression2_editor then
	        wire_expression2_editor:NewTab()
	        wire_expression2_editor:SetCode(table.concat(export))
	        spawnmenu.ActivateTool("wire_expression2")
	    end

	end,
	Receive = function( self, length, player )
	end
} )
