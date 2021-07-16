local checkluatype = SF.CheckLuaType
local registerprivilege = SF.Permissions.registerPrivilege

local function p2mOnDestroy(p2m, p2mdata, ply)
	p2mdata[p2m] = nil
end

local _COL    = -1
local _MAT    = -2
local _POS    = -3
local _ANG    = -4
local _SCALE  = -5
local _UVS    = -6
local _PARENT = -7
local _MODEL  = -8
local _NODRAW = -9
local _BUILD  = -10
local _ALPHA  = -11
local _LINK   = -12

local cooldowns = {}
cooldowns[_BUILD] = 10
cooldowns[_UVS] = 10

local errors = {}
errors[_BUILD] = "Don't spam p2m:build"
errors[_UVS] = "Don't spam p2m:setUV"

local function canspam(check, wait, time)
	if not check or time - check > wait then
		return true
	end
	return false
end

local function antispam(self, action, index)
	if not self.prop2mesh_sf_antispam then
		self.prop2mesh_sf_antispam = {}
	end

	local time = CurTime()
	local wait = cooldowns[action]

	if not index then
		if self.prop2mesh_sf_antispam[action] == time then
			return false
		end
		if not wait or (wait and canspam(self.prop2mesh_sf_antispam[action], wait, time)) then
			self.prop2mesh_sf_antispam[action] = time
			return true
		end
		SF.Throw(errors[action], 3)
		return false
	else
		if not self.prop2mesh_sf_antispam[index] then
			self.prop2mesh_sf_antispam[index] = {}
		end
		if self.prop2mesh_sf_antispam[index][action] == time then
			return false
		end
		if not wait or (wait and canspam(self.prop2mesh_sf_antispam[index][action], wait, time)) then
			self.prop2mesh_sf_antispam[index][action] = time
			return true
		end
		SF.Throw(errors[action], 3)
		return false
	end
end

local function checkOwner(ply, ent)
    if CPPI then
        local owner = ent:CPPIGetOwner() or (ent.GetPlayer and ent:GetPlayer())
        if owner then
            return owner == ply
        end
    end
    return true
end

local function checkvalid(ply, self, action, index, restricted)
	if not checkOwner(ply, self) or not prop2mesh.isValid(self) then
		return false
	end
	if restricted and not self.prop2mesh_sf_resevoir then
		return false
	end
	if index and not self.prop2mesh_controllers[index] then
		SF.Throw(string.format("controller index %d does not exist on %s!", index, tostring(self)), 3)
		return false
	end
	if action then
		return antispam(self, action, index)
	end
	return true
end

local function errorcheck(self, index)
	if not self.prop2mesh_controllers[index] then
		SF.Throw(string.format("controller index %d does not exist on %s!", index, tostring(self)), 3)
	end
	if not self.prop2mesh_sf_resevoir[index] then
		self.prop2mesh_sf_resevoir[index] = {}
	end
	if #self.prop2mesh_sf_resevoir[index] + 1 > 500 then
		SF.Throw("model limit is 500 per controller", 3)
	end
end

local function toVec(vec)
	return vec and Vector(vec[1], vec[2], vec[3]) or Vector()
end

local function toAng(ang)
	return ang and Angle(ang[1], ang[2], ang[3]) or Angle()
end

local function isVector(op0)
	return type(op0) == "Vector"
end

--- Library for creating and manipulating p2m controllers".
-- @name prop2mesh
-- @class library
-- @libtbl p2m_library
SF.RegisterLibrary("prop2mesh")

--- prop2mesh type
-- @name p2m
-- @class type
-- @libtbl p2m_methods
SF.RegisterType("p2m", true, false, nil, "Entity")

return function(instance)
	local checkpermission = instance.player ~= SF.Superuser and SF.Permissions.check or function() end

	local p2m_library = instance.Libraries.prop2mesh
	local p2m_methods, p2m_meta, wrap, unwrap = instance.Types.p2m.Methods, instance.Types.p2m, instance.Types.p2m.Wrap, instance.Types.p2m.Unwrap
	local ents_methods, ent_meta, ewrap, eunwrap = instance.Types.Entity.Methods, instance.Types.Entity, instance.Types.Entity.Wrap, instance.Types.Entity.Unwrap
	local ang_meta, awrap, aunwrap = instance.Types.Angle, instance.Types.Angle.Wrap, instance.Types.Angle.Unwrap
	local vec_meta, vwrap, vunwrap = instance.Types.Vector, instance.Types.Vector.Wrap, instance.Types.Vector.Unwrap
	local mtx_meta, mwrap, munwrap = instance.Types.VMatrix, instance.Types.VMatrix.Wrap, instance.Types.VMatrix.Unwrap
	local col_meta, cwrap, cunwrap = instance.Types.Color, instance.Types.Color.Wrap, instance.Types.Color.Unwrap

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

	local function checkClips(clips)
		if #clips == 0 or #clips % 2 ~= 0 then
			return
		end
		local swap = {}
		for i = 1, #clips, 2 do
			local op1 = vunwrap(clips[i])
			local op2 = vunwrap(clips[i + 1])

			if not isVector(op1) or not isVector(op2) then
				goto CONTINUE
			end

			local normal = op2
			normal:Normalize()

			swap[#swap + 1] = { d = op1:Dot(normal), n = normal }

			::CONTINUE::
		end
		return swap
	end

	local function checkSubmodels(submodels)
		if #submodels == 0 then
			return
		end
		local swap = {}
		for i = 1, #submodels do
			local n = isnumber(submodels[i]) and math.floor(math.abs(submodels[i]))
			if n > 0 then
				swap[n] = 1
			end
		end
		return next(swap) and swap
	end

	--- Creates a p2m controller.
	-- @param count Number of controllers
	-- @param pos The position to create the p2m ent
	-- @param ang The angle to create the p2m ent
	-- @param uvs (Optional) The uvscale to give the p2m controllers
	-- @param scale (Optional) The meshscale to give the p2m controllers
	-- @return The p2m ent
	function p2m_library.create(count, pos, ang, uvs, scale)
		checkluatype(count, TYPE_NUMBER)
		local count = math.abs(math.ceil(count or 1))
		if count > 64 then
			SF.Throw("controller limit is 64 per entity", 3)
		end

		local pos = vunwrap(pos)
		local ang = aunwrap(ang)
		local ply = instance.player
		local p2mdata = instance.data.p2ms.p2ms

		local ent = ents.Create("sent_prop2mesh")

		ent:SetNoDraw(true)
		ent:SetModel("models/hunter/plates/plate.mdl")
		ent:SetPos(SF.clampPos(pos))
		ent:SetAngles(ang)
		ent:Spawn()

		if not IsValid(ent) then
			return NULL
		end

		if CPPI then
			ent:CPPISetOwner(ply)
		end

		ent:SetPlayer(ply)
		ent:SetSolid(SOLID_NONE)
		ent:SetMoveType(MOVETYPE_NONE)
		ent:DrawShadow(false)
		ent:Activate()

		ent:CallOnRemove("starfall_p2m_delete", p2mOnDestroy, p2mdata, ply)

		ent.DoNotDuplicate = true
		ent.prop2mesh_sf_resevoir = {}

		if uvs then
			checkluatype(uvs, TYPE_NUMBER)
		end
		if scale then
			scale = vunwrap(scale)
			checkluatype(scale, TYPE_VECTOR)
		end

		for i = 1, count do
			ent:AddController()
			if uvs then
				checkluatype(uvs, TYPE_NUMBER)
				ent:SetControllerUVS(i, uvs)
			end
			if scale then
				ent:SetControllerScale(i, scale)
			end
		end

		p2mdata[ent] = true

		if ply ~= SF.Superuser then gamemode.Call("PlayerSpawnedSENT", ply, ent) end

		return wrap(ent)
	end

	--- Adds a model to the build stack.
	-- @param index index oc ontroller
	-- @param model model to add
	-- @param pos local pos offset
	-- @param ang local ang offset
	-- @param scale (optional vec) model scale
	-- @param clips (optional table) table of alternating clip origins and clip normals
	-- @param render_inside (optional bool)
	-- @param render_flat (optional bool) use flat normal shading
	-- @param submodels (optional table) ignore submodels
	-- @param submodelswl (optional bool) submodels as whitelist
	function p2m_methods:pushModel(index, model, pos, ang, scale, clips, vinside, vsmooth, bodygroup, submodels, submodelswl)
		local ent = eunwrap(self)
		checkluatype(index, TYPE_NUMBER)

		errorcheck(ent, index)

		if not checkvalid(instance.player, ent, nil, index, true) then
			return
		end

		checkluatype(model, TYPE_STRING)

		local pos = vunwrap(pos)
		local ang = aunwrap(ang)

		if scale then
			scale = vunwrap(scale)
			if scale.x == 1 and scale.y == 1 and scale.z == 1 then
				scale = nil
			end
		end

		if clips then
			checkluatype(clips, TYPE_TABLE)
			clips = checkClips(clips)
		end

		if submodels then submodels = checkSubmodels(submodels) end

		if bodygroup then
			bodygroup = math.floor(math.abs(bodygroup))
			if bodygroup == 0 then
				bodygroup = nil
			end
		end

		ent.prop2mesh_sf_resevoir[index][#ent.prop2mesh_sf_resevoir[index] + 1] = {
			prop = model,
			pos = pos,
			ang = ang,
			scale = scale,
			clips = clips,
			vinside = tobool(vinside) and 1 or nil,
			vsmooth = tobool(vsmooth) and 1 or nil,
			bodygroup = bodygroup,
			submodels = submodels,
			submodelswl = tobool(submodelswl) and 1 or nil,
		}
	end

	--- Build the model stack.
	function p2m_methods:build()
		local ent = eunwrap(self)
		if not checkvalid(instance.player, ent, _BUILD, nil, true) then
			return
		end
		for k, v in pairs(ent.prop2mesh_sf_resevoir) do
			if ent.prop2mesh_controllers[k] then
				ent:SetControllerData(k, v)
			end
		end
		ent.prop2mesh_sf_resevoir = {}
	end

	---
	-- @return count
	function p2m_methods:getCount()
		local ent = eunwrap(self)
		if not checkvalid(instance.player, ent, nil, nil, nil) then
			return 0
		end
		return #this.prop2mesh_controllers
	end

	---
	-- @param index
	-- @return the color
	function p2m_methods:getColor(index)
		local ent = eunwrap(self)
		checkluatype(index, TYPE_NUMBER)
		if not checkvalid(instance.player, ent, nil, index, nil) then
			return cwrap(Color(255,255,255,255))
		end
		return cwrap(ent:GetControllerCol(index))
	end

	---
	-- @param index
	-- @param the color
	function p2m_methods:setColor(index, color)
		local ent = eunwrap(self)
		checkluatype(index, TYPE_NUMBER)
		if not checkvalid(instance.player, ent, _COL, index, nil) then
			return
		end
		ent:SetControllerCol(index, cunwrap(color))
	end

	---
	-- @param index
	-- @param the alpha
	function p2m_methods:setAlpha(index, alpha)
		local ent = eunwrap(self)
		checkluatype(index, TYPE_NUMBER)
		if not checkvalid(instance.player, ent, _ALPHA, index, nil) then
			return
		end
		checkluatype(alpha, TYPE_NUMBER)
		ent:SetControllerAlpha(index, alpha)
	end

	---
	-- @param index
	-- @return the mat
	function p2m_methods:getMaterial(index)
		local ent = eunwrap(self)
		checkluatype(index, TYPE_NUMBER)
		if not checkvalid(instance.player, ent, nil, index, nil) then
			return ""
		end
		return ent:GetControllerMat(index)
	end

	---
	-- @param index
	-- @param the mat
	function p2m_methods:setMaterial(index, mat)
		local ent = eunwrap(self)
		checkluatype(index, TYPE_NUMBER)
		checkluatype(mat, TYPE_STRING)
		if not checkvalid(instance.player, ent, _MAT, index, nil) then
			return
		end
		ent:SetControllerMat(index, mat)
	end

	---
	-- @param index
	-- @param the scale
	function p2m_methods:setScale(index, scale)
		local ent = eunwrap(self)
		checkluatype(index, TYPE_NUMBER)
		if not checkvalid(instance.player, ent, _SCALE, index, nil) then
			return
		end
		ent:SetControllerScale(index, vunwrap(scale))
	end

	---
	-- @param index
	-- @param the uvs
	function p2m_methods:setUV(index, uvs)
		local ent = eunwrap(self)
		checkluatype(index, TYPE_NUMBER)
		if not checkvalid(instance.player, ent, _UVS, index, nil) then
			return
		end
		checkluatype(uvs, TYPE_NUMBER)
		ent:SetControllerUVS(index, math.Clamp(math.floor(math.abs(uvs)), 0, 512))
	end

	---
	-- @param index
	-- @param link ent
	-- @param link pos
	-- @param link ang
	function p2m_methods:setLink(index, other, pos, ang)
		local ent = eunwrap(self)
		checkluatype(index, TYPE_NUMBER)
		if not checkvalid(instance.player, ent, _LINK, index, nil) then
			return
		end
		other = eunwrap(other)
		if other == ent or not other:IsValid() or not checkOwner(instance.player, other) then
			return
		end
		pos = vunwrap(pos)
		ang = aunwrap(ang)
		ent:SetControllerLinkEnt(index, other)
		ent:SetControllerLinkPos(index, pos)
		ent:SetControllerLinkAng(index, ang)
	end

end

