-- -----------------------------------------------------------------------------
local checkluatype = SF.CheckLuaType
local registerprivilege = SF.Permissions.registerPrivilege

local LIMIT_MODELS = 250 -- per controller
local LIMIT_CLIPS  = 10  -- per model

local function p2mOnDestroy(p2m, p2mdata, ply)
	p2mdata[p2m] = nil
end

local ent_class = "gmod_ent_p2m"

local ActionCooldown = {
	["build"] = 10,
}

local function P2M_Cooldown(controller, action)
	if not controller.P2MSFAntiSpam[action] or CurTime() - controller.P2MSFAntiSpam[action] > ActionCooldown[action] then
		controller.P2MSFAntiSpam[action] = CurTime()
		return true
	end
	return false
end

local function P2M_AntiSpam(controller, action)
	if not controller.P2MSFAntiSpam then
		controller.P2MSFAntiSpam = {}
	end
	if ActionCooldown[action] then
		return P2M_Cooldown(controller, action)
	end
	if controller.P2MSFAntiSpam[action] and controller.P2MSFAntiSpam[action] == CurTime() then
		return false
	end
	controller.P2MSFAntiSpam[action] = CurTime()
	return true
end


-- -----------------------------------------------------------------------------
SF.RegisterLibrary("p2m")
SF.RegisterType("p2m", true, false, nil, "Entity")

return function(instance)
local checkpermission = instance.player ~= SF.Superuser and SF.Permissions.check or function() end


-- -----------------------------------------------------------------------------
local p2m_library = instance.Libraries.p2m
local p2m_methods, p2m_meta, wrap, unwrap = instance.Types.p2m.Methods, instance.Types.p2m, instance.Types.p2m.Wrap, instance.Types.p2m.Unwrap
local ents_methods, ent_meta, ewrap, eunwrap = instance.Types.Entity.Methods, instance.Types.Entity, instance.Types.Entity.Wrap, instance.Types.Entity.Unwrap
local ang_meta, awrap, aunwrap = instance.Types.Angle, instance.Types.Angle.Wrap, instance.Types.Angle.Unwrap
local vec_meta, vwrap, vunwrap = instance.Types.Vector, instance.Types.Vector.Wrap, instance.Types.Vector.Unwrap
local mtx_meta, mwrap, munwrap = instance.Types.VMatrix, instance.Types.VMatrix.Wrap, instance.Types.VMatrix.Unwrap

local getent
instance:AddHook("initialize", function()
	instance.data.p2ms = {p2ms = {}}
	getent = instance.Types.Entity.GetEntity
	p2m_meta.__tostring = ent_meta.__tostring
end)

instance:AddHook("deinitialize", function()
	local p2ms = instance.data.p2ms.p2ms
	for p2m, _ in pairs(p2ms) do
		if p2m:IsValid() then
			p2m:RemoveCallOnRemove("starfall_p2m_delete")
			p2mOnDestroy(p2m, p2ms, instance.player)
			p2m:Remove()
		end
	end
end)

local function getp2m(self)
	local ent = unwrap(self)
	if ent:IsValid() then
		return ent
	else
		SF.Throw("Entity is not valid.", 3)
	end
end


-- -----------------------------------------------------------------------------
function p2m_library.create(pos, ang, uvscale, meshscale)
	local pos = vunwrap(pos)
	local ang = aunwrap(ang)

	local ply = instance.player
	local p2mdata = instance.data.p2ms.p2ms

	local p2ment = ents.Create(ent_class)
	if p2ment and p2ment:IsValid() then
		p2ment:SetPlayer(ply)
		p2ment:SetPos(SF.clampPos(pos))
		p2ment:SetAngles(ang)
		p2ment:SetModel("models/hunter/plates/plate.mdl")
		p2ment:SetMaterial("p2m/grid")
		p2ment:CallOnRemove("starfall_p2m_delete", p2mOnDestroy, p2mdata, ply)
		p2ment:Spawn()

		p2ment:SetSolid(SOLID_NONE)
		p2ment:SetMoveType(MOVETYPE_NONE)
		p2ment:DrawShadow(false)
		p2ment:Activate()

		p2ment.isSFP2M = true
		p2ment.DoNotDuplicate = true
		p2ment.SFP2MResevoir = {}

		if uvscale ~= nil then
			checkluatype(uvscale, TYPE_NUMBER)
			controller:SetNWInt("P2M_TSCALE", math.Clamp(uvscale, 0, 512))
		end
		if meshscale ~= nil then
			checkluatype(meshscale, TYPE_NUMBER)
			controller:SetNWFloat("P2M_MSCALE", math.Clamp(meshscale, 0.1, 1))
		end

		if ply ~= SF.Superuser then gamemode.Call("PlayerSpawnedSENT", ply, p2ment) end

		p2mdata[p2ment] = true

		return wrap(p2ment)
	end
end

function p2m_methods:pushModel(model, pos, ang, scale, invert, flat, clips)
	local p2ment = getp2m(self)
	if #p2ment.SFP2MResevoir > LIMIT_MODELS then
		SF.Throw("You have reached the model hardcap on this p2m controller", 3)
		return
	end

	checkluatype(model, TYPE_STRING)

	local entry  = {
		mdl = SF.NormalizePath(model),
		pos = vunwrap(pos),
		ang = aunwrap(ang),
	}

	if scale ~= nil then
		entry.scale = vunwrap(scale)
	end

	if invert ~= nil then
		checkluatype(invert, TYPE_BOOL)
		entry.inv = invert
	end

	if flat ~= nil then
		checkluatype(flat, TYPE_BOOL)
		entry.flat = flat
	end

	if clips ~= nil then
		checkluatype(clips, TYPE_TABLE)

		if #clips == 0 or #clips % 2 ~= 0 then
			SF.Throw("Clips table must contain an even number of elements", 3)
		end

		local array = {}

		for i = 1, #clips, 2 do
			if i > LIMIT_CLIPS*2 then
				break
			end

			local origin = vunwrap(clips[i + 0])
			local normal = vunwrap(clips[i + 1])
			normal:Normalize()

			array[#array + 1] = { n = normal, d = origin:Dot(normal) }

			::invalid::
		end

		if #array > 0 then
			entry.clips = array
		end
	end

	p2ment.SFP2MResevoir[#p2ment.SFP2MResevoir + 1] = entry
end

function p2m_methods:build()
	local p2ment = getp2m(self)
	if not P2M_AntiSpam(p2ment, "build") then
		SF.Throw("Don't spam", 3)
	end
	if #p2ment.SFP2MResevoir > 0 then
		p2ment:SetModelsFromTable(p2ment.SFP2MResevoir)
		p2ment.SFP2MResevoir= {}
	end
end


end
