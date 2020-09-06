-- -----------------------------------------------------------------------------
E2Lib.RegisterExtension("prop2mesh", true, "Allows E2 chips to create and manipulate prop2mesh entities")

local LIMIT_MODELS = 250 -- per controller
local LIMIT_CLIPS  = 5   -- per model


-- -----------------------------------------------------------------------------
local WireLib = WireLib
local E2Lib = E2Lib

local CurTime = CurTime
local string  = string
local Vector  = Vector
local Angle   = Angle
local game    = game


-- -----------------------------------------------------------------------------
registerCallback("construct",
	function(self)
		self.data.p2m = {}
	end
)

registerCallback("destruct",
	function(self)
		for ent, mode in pairs(self.data.p2m) do
			if ent then ent:Remove() end
		end
	end
)


-- -----------------------------------------------------------------------------
local ent_class = "gmod_ent_p2m"

local ActionCooldown = {
	["build"] = 10,
}

local function P2M_Cooldown(controller, action)
	if not controller.P2ME2AntiSpam[action] or CurTime() - controller.P2ME2AntiSpam[action] > ActionCooldown[action] then
		controller.P2ME2AntiSpam[action] = CurTime()
		return true
	end
	return false
end

local function P2M_AntiSpam(controller, action)
	if not controller.P2ME2AntiSpam then
		controller.P2ME2AntiSpam = {}
	end
	if ActionCooldown[action] then
		return P2M_Cooldown(controller, action)
	end
	if controller.P2ME2AntiSpam[action] and controller.P2ME2AntiSpam[action] == CurTime() then
		return false
	end
	controller.P2ME2AntiSpam[action] = CurTime()
	return true
end

local function P2M_CanManipulate(self, controller, action)
	if not IsValid(controller) then
		return false
	end
	if controller:GetClass() ~= ent_class or not controller.E2P2MResevoir then
		return false
	end
	if E2Lib.isOwner(self, controller) or game.SinglePlayer() then
		if not action then
			return true
		else
			return P2M_AntiSpam(controller, action)
		end
	end
	return false
end


-- -----------------------------------------------------------------------------
local function P2M_Create(self, pos, ang, uvscale, meshscale)
	local controller = ents.Create(ent_class)

	controller:SetModel("models/hunter/plates/plate.mdl")
	E2Lib.setMaterial(controller, "p2m/grid")
	WireLib.setPos(controller, pos)
	WireLib.setAng(controller, ang)
	controller:Spawn()

	if not IsValid(controller) then
		return NULL
	end

	controller.DoNotDuplicate = true
	controller:SetSolid(SOLID_NONE)
	controller:SetMoveType(MOVETYPE_NONE)
	controller:DrawShadow(false)
	controller:Activate()

	controller:SetPlayer(self.player)
	if uvscale then
		controller:SetNWInt("P2M_TSCALE", math.Clamp(uvscale, 0, 512))
	end
	if meshscale then
		controller:SetNWFloat("P2M_MSCALE", math.Clamp(meshscale, 0.1, 1))
	end

	controller.E2P2MResevoir = {}

	controller:CallOnRemove("wire_expression2_p2m_remove",
		function(controller)
			self.data.p2m[controller] = nil
		end
	)

	self.data.p2m[controller] = true

	return controller
end


-- -----------------------------------------------------------------------------
local function P2M_Build(e2, controller)
	if #controller.E2P2MResevoir == 0 then
		return false
	end
	if #controller.E2P2MResevoir > LIMIT_MODELS then
		return false, string.format("P2M Controller reached %d model limit!", LIMIT_MODELS)
	end

	controller:SetModelsFromTable(controller.E2P2MResevoir)
	controller.E2P2MResevoir = {}

	return true
end


-- -----------------------------------------------------------------------------
local function isVector(op0)
	return istable(op0) and #op0 == 3 or type(op0) == "Vector"
end

local function P2M_CheckClips(array)
	if #array == 0 or #array % 2 ~= 0 then
		return nil, "Clips array must have an even number of vectors"
	end

	local clips = {}

	for i = 1, #array, 2 do
		if i > LIMIT_CLIPS*2 then
			break
		end
		local op1 = array[i + 0]
		local op2 = array[i + 1]

		if not isVector(op1) or not isVector(op2) then
			goto invalid
		end

		local normal = Vector(op2[1], op2[2], op2[3])
		normal:Normalize()

		clips[#clips + 1] = { n = normal, d = Vector(op1[1], op1[2], op1[3]):Dot(normal) }

		::invalid::
	end

	if #clips > 0 then
		return clips
	end

	return nil, "Clips array has invalid clips"
end


-- -----------------------------------------------------------------------------
local function P2M_CheckModel(model)
	local model = string.lower(string.Trim(model))
	if not string.EndsWith(model, ".mdl") then
		model = model .. ".mdl"
	end
	return model
end


-- -----------------------------------------------------------------------------
__e2setcost(30)

e2function entity p2mCreate(vector pos, angle ang)
	return P2M_Create(self, Vector(pos[1], pos[2], pos[3]), Angle(ang[1], ang[2], ang[3]))
end

e2function entity p2mCreate(vector pos, angle ang, number uvscale)
	return P2M_Create(self, Vector(pos[1], pos[2], pos[3]), Angle(ang[1], ang[2], ang[3]), uvscale)
end

e2function entity p2mCreate(vector pos, angle ang, number uvscale, number meshscale)
	return P2M_Create(self, Vector(pos[1], pos[2], pos[3]), Angle(ang[1], ang[2], ang[3]), uvscale, meshscale)
end


-- -----------------------------------------------------------------------------
__e2setcost(100)

e2function void entity:p2mBuild()
	if not P2M_CanManipulate(self, this, "build") then
		this.E2P2MResevoir = {} -- important!!
		return
	end

	local succ, code = P2M_Build(self, this)
	if not succ and code then
		error(code)
	end
end


-- -----------------------------------------------------------------------------
__e2setcost(15)

e2function void entity:p2mSetPos(vector pos)
	if not P2M_CanManipulate(self, this, "pos") then
		return
	end
	WireLib.setPos(this, Vector(pos[1], pos[2], pos[3]))
end

e2function void entity:p2mSetAng(angle ang)
	if not P2M_CanManipulate(self, this, "ang") then
		return
	end
	WireLib.setAng(this, Angle(ang[1], ang[2], ang[3]))
end

e2function void entity:p2mSetColor(vector color)
	if not P2M_CanManipulate(self, this, "col") then
		return
	end
	WireLib.SetColor(this, Color(color[1], color[2], color[3]))
end

e2function void entity:p2mSetColor(vector4 color)
	if not P2M_CanManipulate(self, this, "col") then
		return
	end
	WireLib.SetColor(this, Color(color[1], color[2], color[3], color[4]))
end

e2function void entity:p2mSetMaterial(string material)
	if not P2M_CanManipulate(self, this, "mat") then
		return
	end
	E2Lib.setMaterial(this, material)
end

e2function void entity:p2mSetModel(string model)
	if not P2M_CanManipulate(self, this, "mdl") then
		return
	end
	this:SetModel(model)
end


-- -----------------------------------------------------------------------------
__e2setcost(40)

local function Check_Parents(child, parent)
	while IsValid(parent:GetParent()) do
		parent = parent:GetParent()
		if parent == child then
			return false
		end
	end

	return true
end

e2function void entity:p2mSetParent(entity target)
	if not P2M_CanManipulate(self, this, "parent") then
		return
	end
	if not IsValid(target) then
		return
	end
	if not E2Lib.isOwner(self, target) then
		return
	end
	if not Check_Parents(this, target) then
		return
	end
	if target:GetParent() and target:GetParent():IsValid() and target:GetParent() == this then
		return
	end
	this:SetParent(target)
end


-- -----------------------------------------------------------------------------
__e2setcost(5)

e2function void entity:p2mPushModel(string model, vector pos, angle ang)
	if #this.E2P2MResevoir > LIMIT_MODELS or not P2M_CanManipulate(self, this) then
		return
	end
	local mdl, msg = P2M_CheckModel(model)
	if not mdl then
		if msg then
			self.player:ChatPrint(msg)
		end
		return
	end
	this.E2P2MResevoir[#this.E2P2MResevoir + 1] = {
		mdl = string.lower(string.Trim(model)),
		pos = Vector(pos[1], pos[2], pos[3]),
		ang = Angle(ang[1], ang[2], ang[3]),
	}
end

e2function void entity:p2mPushModel(string model, vector pos, angle ang, vector scale)
	if #this.E2P2MResevoir > LIMIT_MODELS or not P2M_CanManipulate(self, this) then
		return
	end
	local mdl, msg = P2M_CheckModel(model)
	if not mdl then
		if msg then
			self.player:ChatPrint(msg)
		end
		return
	end
	this.E2P2MResevoir[#this.E2P2MResevoir + 1] = {
		mdl   = mdl,
		pos   = Vector(pos[1], pos[2], pos[3]),
		ang   = Angle(ang[1], ang[2], ang[3]),
		scale = Vector(scale[1], scale[2], scale[3]),
	}
end

__e2setcost(8)

e2function void entity:p2mPushModel(string model, vector pos, angle ang, number rinside, array clips)
	if #this.E2P2MResevoir > LIMIT_MODELS or not P2M_CanManipulate(self, this) then
		return
	end
	local mdl, msg = P2M_CheckModel(model)
	if not mdl then
		if msg then
			self.player:ChatPrint(msg)
		end
		return
	end
	local mclips, msg = P2M_CheckClips(clips)
	if not mclips then
		if msg then
			self.player:ChatPrint(msg)
		end
		return
	end
	this.E2P2MResevoir[#this.E2P2MResevoir + 1] = {
		mdl   = mdl,
		mdl   = string.lower(string.Trim(model)),
		pos   = Vector(pos[1], pos[2], pos[3]),
		ang   = Angle(ang[1], ang[2], ang[3]),
		clips = mclips,
		inv   = tobool(rinside) or nil,
	}
end

e2function void entity:p2mPushModel(string model, vector pos, angle ang, vector scale, number rinside, array clips)
	if #this.E2P2MResevoir > LIMIT_MODELS or not P2M_CanManipulate(self, this) then
		return
	end
	local mdl, msg = P2M_CheckModel(model)
	if not mdl then
		if msg then
			self.player:ChatPrint(msg)
		end
		return
	end
	local mclips, msg = P2M_CheckClips(clips)
	if not mclips then
		if msg then
			self.player:ChatPrint(msg)
		end
		return
	end
	this.E2P2MResevoir[#this.E2P2MResevoir + 1] = {
		mdl   = mdl,
		pos   = Vector(pos[1], pos[2], pos[3]),
		ang   = Angle(ang[1], ang[2], ang[3]),
		scale = Vector(scale[1], scale[2], scale[3]),
		clips = mclips,
		inv   = tobool(rinside) or nil,
	}
end
