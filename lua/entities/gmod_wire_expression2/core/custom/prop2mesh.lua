E2Lib.RegisterExtension("prop2mesh", true, "Allows E2 chips to create and manipulate prop2mesh entities")

local E2Lib, WireLib, prop2mesh, math =
      E2Lib, WireLib, prop2mesh, math


--[[
]]
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
local _ALP    = -11

local cooldowns = {}
cooldowns[_BUILD] = 10
cooldowns[_UVS] = 10

local errors = {}
errors[_BUILD] = "\nDon't spam e:p2mBuild"
errors[_UVS] = "\nDon't spam e:p2mSetUV"

local function canspam(check, wait, time)
	if not check or time - check > wait then
		return true
	end
	return false
end

local function antispam(self, action, index)
	if not self.prop2mesh_e2_antispam then
		self.prop2mesh_e2_antispam = {}
	end

	local time = CurTime()
	local wait = cooldowns[action]

	if not index then
		if self.prop2mesh_e2_antispam[action] == time then
			return false
		end
		if not wait or (wait and canspam(self.prop2mesh_e2_antispam[action], wait, time)) then
			self.prop2mesh_e2_antispam[action] = time
			return true
		end
		error(errors[action])
		return false
	else
		if not self.prop2mesh_e2_antispam[index] then
			self.prop2mesh_e2_antispam[index] = {}
		end
		if self.prop2mesh_e2_antispam[index][action] == time then
			return false
		end
		if not wait or (wait and canspam(self.prop2mesh_e2_antispam[index][action], wait, time)) then
			self.prop2mesh_e2_antispam[index][action] = time
			return true
		end
		error(errors[action])
		return false
	end
end

local function checkvalid(context, self, action, index, restricted)
	if not E2Lib.isOwner(context, self) or not prop2mesh.isValid(self) then
		return false
	end
	if restricted and not self.prop2mesh_e2_resevoir then
		return false
	end
	if index and not self.prop2mesh_controllers[index] then
		error(string.format("\ncontroller index %d does not exist on %s!", index, tostring(self)))
	end
	if action then
		return antispam(self, action, index)
	end
	return true
end


--[[
]]
__e2setcost(10)

e2function void entity:p2mSetAlpha(number index, number alpha)
	if checkvalid(self, this, _ALP, index) then
		this:SetControllerAlpha(index, alpha)
	end
end
e2function void entity:p2mSetColor(number index, vector color)
	if checkvalid(self, this, _COL, index) then
		this:SetControllerCol(index, Color(color[1], color[2], color[3]))
	end
end
e2function void entity:p2mSetColor(number index, vector4 color)
	if checkvalid(self, this, _COL, index) then
		this:SetControllerCol(index, Color(color[1], color[2], color[3], color[4]))
	end
end
e2function void entity:p2mSetMaterial(number index, string material)
	if checkvalid(self, this, _MAT, index) then
		this:SetControllerMat(index, WireLib.IsValidMaterial(material))
	end
end
e2function void entity:p2mSetScale(number index, vector scale)
	if checkvalid(self, this, _SCALE, index) then
		this:SetControllerScale(index, Vector(scale[1], scale[2], scale[3]))
	end
end
e2function void entity:p2mSetUV(number index, number uvs)
	if checkvalid(self, this, _UVS, index) then
		this:SetControllerUVS(index, math.Clamp(math.floor(math.abs(uvs)), 0, 512))
	end
end


--[[
]]
e2function void entity:p2mSetPos(vector pos)
	if checkvalid(self, this, _POS) then
		WireLib.setPos(this, Vector(pos[1], pos[2], pos[3]))
	end
end
e2function void entity:p2mSetAng(angle ang)
	if checkvalid(self, this, _ANG) then
		WireLib.setAng(this, Angle(ang[1], ang[2], ang[3]))
	end
end
e2function void entity:p2mSetNodraw(number bool)
	if checkvalid(self, this, _NODRAW) then
		this:SetNoDraw(tobool(bool))
	end
end
e2function void entity:p2mSetModel(string model)
	if checkvalid(self, this, _MODEL, nil, true) then
		this:SetModel(model)
	end
end


--[[
]]
__e2setcost(25)

local function Check_Parents(child, parent)
	while IsValid(parent:GetParent()) do
		parent = parent:GetParent()
		if parent == child then
			return false
		end
	end

	return true
end

e2function void entity:p2mSetParent(entity parent)
	if not IsValid(parent) or not E2Lib.isOwner(self, parent) or not checkvalid(self, this, _PARENT) then
		return
	end
	if not Check_Parents(this, parent) then
		return
	end
	if parent:GetParent() and parent:GetParent():IsValid() and parent:GetParent() == this then
		return
	end
	this:SetParent(parent)
end

e2function void entity:p2mDeparent()
	if checkvalid(self, this, _PARENT) then
		this:SetParent(nil)
	end
end


--[[
]]
registerCallback("construct", function(self)
	self.data.prop2mesh = {}
end)

registerCallback("destruct", function(self)
	for ent, mode in pairs(self.data.prop2mesh) do
		if ent then
			ent:Remove()
		end
	end
end)

local function p2mCreate(context, pos, ang, count)
	if not count then
		count = 1
	end
	count = math.abs(math.ceil(count))

	if count > 16 then
		error("controller limit is 16 per entity")
	end

	local self = ents.Create("sent_prop2mesh")

	self:SetNoDraw(true)
	self:SetModel("models/hunter/plates/plate.mdl")
	WireLib.setPos(self, pos)
	WireLib.setAng(self, ang)
	self:Spawn()

	if not IsValid(self) then
		return NULL
	end

	if CPPI then
		self:CPPISetOwner(context.player)
	end

	self:SetPlayer(context.player)
	self:SetSolid(SOLID_NONE)
	self:SetMoveType(MOVETYPE_NONE)
	self:DrawShadow(false)
	self:Activate()

	self:CallOnRemove("wire_expression2_p2m", function(e)
		context.data.prop2mesh[e] = nil
	end)

	context.data.prop2mesh[self] = true

	self.DoNotDuplicate = true
	self.prop2mesh_e2_resevoir = {}

	for i = 1, count do
		self:AddController()
	end

	return self
end

__e2setcost(50)

e2function entity p2mCreate(number count, vector pos, angle ang)
	return p2mCreate(self, Vector(pos[1], pos[2], pos[3]), Angle(ang[1], ang[2], ang[3]), count)
end


--[[
]]
__e2setcost(100)

local function p2mBuild(context, self)  -- maybe queue this
	for k, v in pairs(self.prop2mesh_e2_resevoir) do
		if self.prop2mesh_controllers[k] then
			self:SetControllerData(k, v)
		end
	end
	self.prop2mesh_e2_resevoir = {}
end

e2function number entity:p2mBuild()
	if not checkvalid(self, this, _BUILD, nil, true) then
		return
	end
	p2mBuild(self, this)
end


--[[
]]
__e2setcost(5)

local function toVec(vec)
	return vec and Vector(vec[1], vec[2], vec[3]) or Vector()
end

local function toAng(ang)
	return ang and Angle(ang[1], ang[2], ang[3]) or Angle()
end

local function isVector(op0)
	return istable(op0) and #op0 == 3 or type(op0) == "Vector"
end

local function errorcheck(context, self, index)
	if not self.prop2mesh_controllers[index] then
		error(string.format("\ncontroller index %d does not exist on %s!", index, tostring(self)))
	end
	if not self.prop2mesh_e2_resevoir[index] then
		self.prop2mesh_e2_resevoir[index] = {}
	end
	if #self.prop2mesh_e2_resevoir[index] + 1 > 250 then
		error("model limit is 250 per controller")
	end
end

local function checkClips(clips)
	if #clips == 0 or #clips % 2 ~= 0 then
		return
	end
	local swap = {}
	for i = 1, #clips, 2 do
		local op1 = clips[i]
		local op2 = clips[i + 1]

		if not isVector(op1) or not isVector(op2) then
			goto CONTINUE
		end

		local normal = toVec(op2)
		normal:Normalize()

		swap[#swap + 1] = { d = toVec(op1):Dot(normal), n = normal }

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

local function p2mPushModel(context, self, index, model, pos, ang, scale, clips, vinside, vsmooth, bodygroup, submodels, submodelswl)
	errorcheck(context, self, index)

	if scale then
		scale = toVec(scale)
		if scale.x == 1 and scale.y == 1 and scale.z == 1 then
			scale = nil
		end
	end

	if clips then clips = checkClips(clips) end
	if submodels then submodels = checkSubmodels(submodels) end

	if bodygroup then
		bodygroup = math.floor(math.abs(bodygroup))
		if bodygroup == 0 then
			bodygroup = nil
		end
	end

	self.prop2mesh_e2_resevoir[index][#self.prop2mesh_e2_resevoir[index] + 1] = {
		prop = model,
		pos = toVec(pos),
		ang = toAng(ang),
		scale = scale,
		clips = clips,
		vinside = tobool(vinside) and 1 or nil,
		vsmooth = tobool(vsmooth) and 1 or nil,
		bodygroup = bodygroup,
		submodels = submodels,
		submodelswl = tobool(submodelswl) and 1 or nil,
	}

	return #self.prop2mesh_e2_resevoir[index]
end

--BYTABLE
local stypes = {
	model     = "s",
	ang       = "a",
	pos       = "v",
	scale     = "v",
	inside    = "n",
	flat      = "n",
	bodygroup = "n",
	clips     = "r",
	submodels = "r",
	submodelswl = "n",
}

e2function void entity:p2mPushModel(index, table data)
	if checkvalid(self, this, nil, index, true) then
		local real = {}
		for k, v in pairs(data.stypes) do
			if stypes[k] == v then -- add aliases
				real[k] = data.s[k]
			end
		end
		p2mPushModel(self, this, index, real.model, real.pos, real.ang, real.scale, real.clips, real.inside, real.flat, real.bodygroup, real.submodels, real.submodelswl)
	end
end


--NOSCALE
e2function void entity:p2mPushModel(index, string model, vector pos, angle ang)
	if checkvalid(self, this, nil, index, true) then
		p2mPushModel(self, this, index, model, pos, ang)
	end
end
--NOSCALE,RFLAGS
e2function void entity:p2mPushModel(index, string model, vector pos, angle ang, number renderinside, number renderflat)
	if checkvalid(self, this, nil, index, true) then
		p2mPushModel(self, this, index, model, pos, ang, nil, nil, renderinside, renderflat)
	end
end
--NOSCALE,RFLAGS,CLIPS
e2function void entity:p2mPushModel(index, string model, vector pos, angle ang, number renderinside, number renderflat, array clips)
	if checkvalid(self, this, nil, index, true) then
		p2mPushModel(self, this, index, model, pos, ang, nil, clips, renderinside, renderflat)
	end
end
--NOSCALE,RFLAGS,BODYGROUP
e2function void entity:p2mPushModel(index, string model, vector pos, angle ang, number renderinside, number renderflat, number bodygroup)
	if checkvalid(self, this, nil, index, true) then
		p2mPushModel(self, this, index, model, pos, ang, nil, nil, renderinside, renderflat, bodygroup)
	end
end
--NOSCALE,RFLAGS,BODYGROUP,CLIPS
e2function void entity:p2mPushModel(index, string model, vector pos, angle ang, number renderinside, number renderflat, number bodygroup, array clips)
	if checkvalid(self, this, nil, index, true) then
		p2mPushModel(self, this, index, model, pos, ang, nil, clips, renderinside, renderflat, bodygroup)
	end
end
--NOSCALE,RFLAGS,BODYGROUP,HIDESUBMODELS
e2function void entity:p2mPushModel(index, string model, array hidesubmodels, vector pos, angle ang, number renderinside, number renderflat, number bodygroup)
	if checkvalid(self, this, nil, index, true) then
		p2mPushModel(self, this, index, model, pos, ang, nil, nil, renderinside, renderflat, bodygroup, hidesubmodels)
	end
end
--NOSCALE,RFLAGS,BODYGROUP,CLIPS,HIDESUBMODELS
e2function void entity:p2mPushModel(index, string model, array hidesubmodels, vector pos, angle ang, number renderinside, number renderflat, number bodygroup, array clips)
	if checkvalid(self, this, nil, index, true) then
		p2mPushModel(self, this, index, model, pos, ang, nil, clips, renderinside, renderflat, bodygroup, hidesubmodels)
	end
end


--SCALE
e2function void entity:p2mPushModel(index, string model, vector pos, angle ang, vector scale)
	if checkvalid(self, this, nil, index, true) then
		p2mPushModel(self, this, index, model, pos, ang, scale)
	end
end
--SCALE,RFLAGS
e2function void entity:p2mPushModel(index, string model, vector pos, angle ang, vector scale, number renderinside, number renderflat)
	if checkvalid(self, this, nil, index, true) then
		p2mPushModel(self, this, index, model, pos, ang, scale, nil, renderinside, renderflat)
	end
end
--SCALE,RFLAGS,CLIPS
e2function void entity:p2mPushModel(index, string model, vector pos, angle ang, vector scale, number renderinside, number renderflat, array clips)
	if checkvalid(self, this, nil, index, true) then
		p2mPushModel(self, this, index, model, pos, ang, scale, clips, renderinside, renderflat)
	end
end
--SCALE,RFLAGS,BODYGROUP
e2function void entity:p2mPushModel(index, string model, vector pos, angle ang, vector scale, number renderinside, number renderflat, number bodygroup)
	if checkvalid(self, this, nil, index, true) then
		p2mPushModel(self, this, index, model, pos, ang, scale, nil, renderinside, renderflat, bodygroup)
	end
end
--SCALE,RFLAGS,BODYGROUP,CLIPS
e2function void entity:p2mPushModel(index, string model, vector pos, angle ang, vector scale, number renderinside, number renderflat, number bodygroup, array clips)
	if checkvalid(self, this, nil, index, true) then
		p2mPushModel(self, this, index, model, pos, ang, scale, clips, renderinside, renderflat, bodygroup)
	end
end
--SCALE,RFLAGS,BODYGROUP,HIDESUBMODELS
e2function void entity:p2mPushModel(index, string model, array hidesubmodels, vector pos, angle ang, vector scale, number renderinside, number renderflat, number bodygroup)
	if checkvalid(self, this, nil, index, true) then
		p2mPushModel(self, this, index, model, pos, ang, scale, nil, renderinside, renderflat, bodygroup, hidesubmodels)
	end
end
--SCALE,RFLAGS,BODYGROUP,CLIPS,HIDESUBMODELS
e2function void entity:p2mPushModel(index, string model, array hidesubmodels, vector pos, angle ang, vector scale, number renderinside, number renderflat, number bodygroup, array clips)
	if checkvalid(self, this, nil, index, true) then
		p2mPushModel(self, this, index, model, pos, ang, scale, clips, renderinside, renderflat, bodygroup, hidesubmodels)
	end
end
