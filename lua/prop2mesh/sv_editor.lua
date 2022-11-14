--[[

]]
util.AddNetworkString("prop2mesh_upload")
util.AddNetworkString("prop2mesh_upload_start")

local net = net
local util = util
local table = table
local next = next
local pairs = pairs
local pcall = pcall
local istable = istable
local isnumber = isnumber
local isvector = isvector
local isangle = isangle

local function canUpload(pl, self)
	if not IsValid(pl) then return false end
	if not prop2mesh.isValid(self) then return false end
	if CPPI and self:CPPIGetOwner() ~= pl then return false end
	return true
end


--[[

]]
local safeControllerValues = {
	uvs = function(val)
		return isnumber(val) and math.Clamp(math.abs(math.floor(val)), 0, 512) or nil
	end,
	scale = function(val)
		return (istable(val) and #val == 3) and Vector(unpack(val)) or nil
	end,
	name = function(val)
		return isstring(val) and string.sub(val, 1, 64) or nil
	end,
	col = function(val)
		return (istable(val) and table.Count(val) == 4) and val or nil
	end,
	mat = function(val)
		return isstring(val) and val or nil
	end,
	linkpos = function(val)
		return (istable(val) and #val == 3) and Vector(unpack(val)) or nil
	end,
	linkang = function(val)
		return (istable(val) and #val == 3) and Angle(unpack(val)) or nil
	end,
	remove = function(val)
		return tobool(val)
	end,
}

local safePartValues = {
	vsmooth = function(partlist, partID, val)
		if isnumber(val) then
			partlist[partID].vsmooth = (partlist[partID].objd and val) or (val ~= 0 and 1 or nil)
		end
	end,
	vinvert = function(partlist, partID, val)
		if isnumber(val) then
			partlist[partID].vinvert = val ~= 0 and 1 or nil
		end
	end,
	vinside = function(partlist, partID, val)
		if isnumber(val) then
			partlist[partID].vinside = val ~= 0 and 1 or nil
		end
	end,
	pos = function(partlist, partID, val)
		if not istable(val) or #val ~= 3 then
			partlist[partID].pos = Vector()
			return
		end
		partlist[partID].pos = Vector(unpack(val))
	end,
	ang = function(partlist, partID, val)
		if not istable(val) or #val ~= 3 then
			partlist[partID].ang = Angle()
			return
		end
		partlist[partID].ang = Angle(unpack(val))
	end,
	scale = function(partlist, partID, val)
		if istable(val) and #val == 3 and (val[1] ~= 1 or val[2] ~= 1 or val[3] ~= 1) then
			partlist[partID].scale = Vector(unpack(val))
			return
		end
		partlist[partID].scale = nil
	end,
	submodels = function(partlist, partID, val)
		if not istable(val) then
			return
		end
		for k, v in pairs(val) do
			if tobool(v) then
				val[k] = 1
			else
				val[k] = nil
			end
		end
		partlist[partID].submodels = next(val) and val or nil
	end
}
-- safePartValues.submodelswl = function(partlist, partID, val)
-- 	if isnumber(val) then
-- 		partlist[partID].submodelswl = val ~= 0 and 1 or nil
-- 	end
-- end

local function applyUpdate(self, pl, updateHandler)
	if updateHandler.controllerAltered then
		for controllerID, edits in pairs(updateHandler.controllerAltered) do
			if edits.remove then
				self:RemoveController(controllerID)
			else
				if edits.uvs then
					self:SetControllerUVS(controllerID, edits.uvs)
				end
				if edits.scale then
					self:SetControllerScale(controllerID, edits.scale)
				end
				if edits.name then
					self:SetControllerName(controllerID, edits.name)
				end
				if edits.col then
					self:SetControllerCol(controllerID, edits.col)
				end
				if edits.mat then
					self:SetControllerMat(controllerID, edits.mat)
				end
				if edits.linkpos then
					self:SetControllerLinkPos(controllerID, edits.linkpos)
				end
				if edits.linkang then
					self:SetControllerLinkAng(controllerID, edits.linkang)
				end
			end
		end
	end

	self:SetNetworkedBool("uploading", true)
	for controllerID, data in pairs(updateHandler.dataAltered) do
		self:SetControllerData(controllerID, data)
	end
	self.prop2mesh_upload_queue = nil

	if prop2mesh.enablelog then
		prop2mesh.log(string.format("[%s] uploads complete, applying changes", tostring(pl)))
	end
end

local function prepareUpdate(self, pl, set, add, mod)
	local updateHandler = {
		dataAltered = {},
		upload_ask = {},
		upload_get = {},
	}

	for controllerID, controllerSets in pairs(set) do
		for setKey, setVal in pairs(controllerSets) do
			if safeControllerValues[setKey] then
				controllerSets[setKey] = safeControllerValues[setKey](setVal)
			else
				controllerSets[setKey] = nil
			end
		end
		if not next(controllerSets) then
			set[controllerID] = nil
		end
	end
	if next(set) then
		updateHandler.controllerAltered = set
	end

	for controllerID, controllerMods in pairs(mod) do
		local controllerData = self:GetControllerData(controllerID) or {}
		for partID, partAttr in pairs(controllerMods) do
			for partAttrKey, partAttrVal in pairs(partAttr) do
				if safePartValues[partAttrKey] and partAttrKey ~= "kill" then
					safePartValues[partAttrKey](controllerData, partID, partAttrVal)
				end
			end
			for partAttrKey, partAttrVal in pairs(partAttr) do
				if partAttrKey == "kill" then
					controllerData[partID] = nil
				end
			end
		end

		local dataAltered = {}
		for partID, partAttr in pairs(controllerData) do
			if isnumber(partID) then
				dataAltered[#dataAltered + 1] = partAttr
			end
		end
		dataAltered.custom = controllerData.custom

		if not updateHandler.dataAltered[controllerID] then
			updateHandler.dataAltered[controllerID] = {}
		end
		updateHandler.dataAltered[controllerID] = dataAltered
	end

	for controllerID, controllerAdds in pairs(add) do
		if not updateHandler.dataAltered[controllerID] then
			updateHandler.dataAltered[controllerID] = self:GetControllerData(controllerID) or {}
		end
		for _, addAttr in pairs(controllerAdds) do
			if addAttr.objd then
				local partAttr = {
					objd = addAttr.objd,
					objn = addAttr.objn or addAttr.objd,
				}
				local partID = table.insert(updateHandler.dataAltered[controllerID], partAttr)

				for addAttrKey, addAttrVal in pairs(addAttr) do
					if safePartValues[addAttrKey] then
						safePartValues[addAttrKey](updateHandler.dataAltered[controllerID], partID, addAttrVal)
					end
				end

				if not updateHandler.dataAltered[controllerID].custom or (updateHandler.dataAltered[controllerID].custom and not updateHandler.dataAltered[controllerID].custom[tonumber(partAttr.objd)]) then
					if not updateHandler.upload_ask[partAttr.objd] then
						updateHandler.upload_ask[partAttr.objd] = { controllers = {} }
					end
					updateHandler.upload_ask[partAttr.objd].controllers[controllerID] = true
				end
			end
		end
	end

	if next(updateHandler.upload_ask) then
		self.prop2mesh_upload_queue = updateHandler
		local keys = table.GetKeys(updateHandler.upload_ask)
		net.Start("prop2mesh_upload_start")
		net.WriteUInt(self:EntIndex(), 16)
		net.WriteUInt(#keys, 8)
		for i = 1, #keys do
			net.WriteString(keys[i])
		end
		net.Send(pl)

		if prop2mesh.enablelog then
			prop2mesh.log(string.format("[%s] requesting %d uploads", tostring(pl), #keys))
		end
	else
		applyUpdate(self, pl, updateHandler)
	end
end

net.Receive("prop2mesh_upload_start", function(len, pl)
	if pl.prop2mesh_antispam then
		local wait = SysTime() - pl.prop2mesh_antispam
		if wait < 1 then
			pl:ChatPrint(string.format("Wait %d more seconds before uploading again", 1 - wait))
			return
		end
	end
	pl.prop2mesh_antispam = SysTime()

	local self = Entity(net.ReadUInt(16) or 0)
	if not canUpload(pl, self) then
		return
	end
	if self.prop2mesh_upload_queue then
		return
	end

	local set, add, mod
	if net.ReadBool() then set = net.ReadTable() else set = {} end
	if net.ReadBool() then add = net.ReadTable() else add = {} end
	if net.ReadBool() then mod = net.ReadTable() else mod = {} end

	local ok, err = pcall(prepareUpdate, self, pl, set, add, mod)
	if not ok then
		print(pl, err)
	end
end)

function prop2mesh.handleUpdate(data, ent, pl, uploadCRC)
	local updateHandler = ent.prop2mesh_upload_queue
	local decomp = util.Decompress(data)
	if uploadCRC == tostring(util.CRC(decomp)) then
		updateHandler.upload_get[uploadCRC] = updateHandler.upload_ask[uploadCRC]
		updateHandler.upload_get[uploadCRC].data = decomp
		updateHandler.upload_ask[uploadCRC] = nil
	else
		updateHandler.upload_ask[uploadCRC] = nil
	end

	if next(updateHandler.upload_ask) then
		return
	end

	for uid, upload in pairs(updateHandler.upload_get) do
		for controllerID in pairs(upload.controllers) do
			if updateHandler.dataAltered[controllerID] and updateHandler.dataAltered[controllerID] then
				if not updateHandler.dataAltered[controllerID].custom then
					updateHandler.dataAltered[controllerID].custom = {}
				end
				updateHandler.dataAltered[controllerID].custom[uid] = upload.data
			end
		end
	end

	applyUpdate(ent, pl, updateHandler)
end

net.Receive("prop2mesh_upload", function(len, pl)
	local self = Entity(net.ReadUInt(16) or 0)
	if not canUpload(pl, self) then
		return
	end

	local uploadCRC = net.ReadString()

	prop2mesh.ReadStream(pl, function(data)
		prop2mesh.handleUpdate(data, self, pl, uploadCRC)
	end)
end)
