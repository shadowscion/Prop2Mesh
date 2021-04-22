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
local kvpass = {}

kvpass.vsmooth = function(data, index, val)
	if isnumber(val) then
		data[index].vsmooth = (data[index].objd and val) or (val ~= 0 and 1 or nil)
	end
end

kvpass.vinvert = function(data, index, val)
	if isnumber(val) then
		data[index].vinvert = val ~= 0 and 1 or nil
	end
end

kvpass.vinside = function(data, index, val)
	if isnumber(val) then
		data[index].vinside = val ~= 0 and 1 or nil
	end
end

kvpass.pos = function(data, index, val)
	if istable(val) and #val == 3 then
		data[index].pos = Vector(unpack(val))
	else
		data[index].pos = Vector()
	end
end

kvpass.ang = function(data, index, val)
	if istable(val) and #val == 3 then
		data[index].ang = Angle(unpack(val))
	else
		data[index].ang = Angle()
	end
end

kvpass.scale = function(data, index, val)
	if istable(val) and #val == 3 and (val[1] ~= 1 or val[2] ~= 1 or val[3] ~= 1) then
		data[index].scale = Vector(unpack(val))
	else
		data[index].scale = nil
	end
end


--[[

]]
local function makeUpdateChanges(self, index, updates, forceSet)
	local currentData = self:GetControllerData(index)
	if not currentData then
		return
	end

	for pi, pdata in pairs(updates) do
		if pdata.kill then
			currentData[pi] = nil
		else
			for k, v in pairs(pdata) do
				local func = kvpass[k]
				if func then
					func(currentData, pi, v)
				end
			end
		end
	end

	local updatedData = { custom = currentData.custom }

	for k, v in pairs(currentData) do
		if tonumber(k) then
			updatedData[#updatedData + 1] = v
		end
	end

	if forceSet then
		if next(updatedData) then
			self:SetControllerData(index, updatedData)
		else
			self:ResetControllerData(index)
		end
	end

	return updatedData
end

local function insertUpdateChanges(self, index, partlist, updates)
	local currentData
	if updates then
		currentData = makeUpdateChanges(self, index, updates, false)
	else
		currentData = self:GetControllerData(index)
	end
	if not currentData then
		return
	end

	for i = 1, #currentData do
		partlist[#partlist + 1] = currentData[i]
	end
	if currentData.custom then
		for crc, data in pairs(currentData.custom) do
			partlist.custom[crc] = data
		end
	end
end

local function applyUpload(self)
	local finalData = {}

	for id, upload in pairs(self.prop2mesh_upload_ready) do
		for index, changes in pairs(upload.controllers) do
			if not finalData[index] then
				finalData[index] = { custom = {} }
			end

			local ok, err = pcall(insertUpdateChanges, self, index, finalData[index], changes.modme)
			if not ok then
				print(err)
			end

			if changes.setme then
				if changes.setme.uvs then self:SetControllerUVS(index, changes.setme.uvs) end
				if changes.setme.scale then self:SetControllerScale(index, Vector(unpack(changes.setme.scale))) end
			end

			finalData[index].custom[id] = upload.data

			for i = 1, #changes.addme do
				finalData[index][#finalData[index] + 1] = changes.addme[i]
			end
		end
	end

	for index, partlist in pairs(finalData) do
		if next(partlist) then
			self:SetControllerData(index, partlist)
		else
			self:ResetControllerData(index)
		end
	end

	self.prop2mesh_upload_ready = nil
	self.prop2mesh_upload_queue = nil
end


--[[

]]
net.Receive("prop2mesh_upload_start", function(len, pl)
	if pl.prop2mesh_antispam then
		local wait = SysTime() - pl.prop2mesh_antispam
		if wait < 1 then
			pl:ChatPrint(string.format("Wait %d more seconds before uploading again", 1 - wait))
			return
		end
	end

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

	if not next(add) then
		if next(set) or next(mod) then
			self:SetNetworkedBool("uploading", true)

			for index, updates in pairs(set) do
				if updates.uvs then
					self:SetControllerUVS(index, updates.uvs)
				end
				if updates.scale then
					self:SetControllerScale(index, Vector(unpack(updates.scale)))
				end
			end

			for index, updates in pairs(mod) do
				pcall(makeUpdateChanges, self, index, updates, true)
			end

			self.prop2mesh_upload_queue = true
			timer.Simple(0, function()
				self.prop2mesh_upload_queue = nil
			end)
		end

		return
	end

	pl.prop2mesh_antispam = SysTime()

	local uploadQueue = {}
	local uploadReady = {}

	for index, parts in pairs(add) do
		if not self.prop2mesh_controllers[index] then
			goto CONTINUE
		end

		local data = self.prop2mesh_partlists[self.prop2mesh_controllers[index].crc]
		if data then
			data = util.JSONToTable(util.Decompress(data)) -- dangerrrrr
			data = data.custom
		end

		for k, part in pairs(parts) do
			local crc = part.objd
			if crc then
				local datagrab = data and data[tonumber(crc)] or nil
				local utable = datagrab and uploadReady or uploadQueue

				if not utable[crc] then
					utable[crc] = { controllers = {}, data = datagrab }
				end
				if not utable[crc].controllers[index] then
					utable[crc].controllers[index] = {
						addme = {},
						setme = set[index],
						modme = mod[index],
					}
				end

				for key, val in pairs(part) do
					local func = kvpass[key]
					if func then
						func(parts, k, val)
					end
				end

				table.insert(utable[crc].controllers[index].addme, part)
			end
		end

		::CONTINUE::
	end

	if next(uploadQueue) then
		self.prop2mesh_upload_queue = uploadQueue
		self.prop2mesh_upload_ready = uploadReady

		local keys = table.GetKeys(uploadQueue)
		net.Start("prop2mesh_upload_start")
		net.WriteUInt(self:EntIndex(), 16)
		net.WriteUInt(#keys, 8)
		for i = 1, #keys do
			net.WriteString(keys[i])
		end
		net.Send(pl)

	elseif next(uploadReady) then
		self:SetNetworkedBool("uploading", true)

		self.prop2mesh_upload_queue = uploadQueue
		self.prop2mesh_upload_ready = uploadReady

		applyUpload(self)
	end
end)

net.Receive("prop2mesh_upload", function(len, pl)
	local self = Entity(net.ReadUInt(16) or 0)
	if not canUpload(pl, self) then
		return
	end

	local crc = net.ReadString()

	net.ReadStream(pl, function(data)
		if not canUpload(pl, self) then
			return
		end

		local decomp = util.Decompress(data)
		if crc == tostring(util.CRC(decomp)) then
			self.prop2mesh_upload_ready[crc] = self.prop2mesh_upload_queue[crc]
			self.prop2mesh_upload_ready[crc].data = decomp
			self.prop2mesh_upload_queue[crc] = nil
		else
			self.prop2mesh_upload_queue[crc] = nil
		end

		if next(self.prop2mesh_upload_queue) then
			return
		end

		applyUpload(self)
	end)
end)

