--A net extension which allows sending large streams of data without overflowing the reliable channel
--Keep it in lua/autorun so it will be shared between addons
prop2mesh.Stream = {}
prop2mesh.Stream.ReadStreamQueues = {}            --This holds a read stream for each player, or one read stream for the server if running on the CLIENT
prop2mesh.Stream.WriteStreams = {}            --This holds the write streams
prop2mesh.Stream.SendSize = 20000            --This is the maximum size of each stream to send
prop2mesh.Stream.Timeout = 30            --How long the data should exist in the store without being used before being destroyed
prop2mesh.Stream.MaxServerReadStreams = 128  --The maximum number of keep-alives to have queued. This should prevent naughty players from flooding the network with keep-alive messages.
prop2mesh.Stream.MaxServerChunks = 3200 --Maximum number of pieces the stream can send to the server. 64 MB
prop2mesh.Stream.MaxTries = 3 --Maximum times the client may retry downloading the whole data
prop2mesh.Stream.MaxKeepalive = 15 --Maximum times the client may request data stay live

prop2mesh.Stream.ReadStream = {}
--Send the data sender a request for data
function prop2mesh.Stream.ReadStream:Request()
	if self.downloads == prop2mesh.Stream.MaxTries * self.numchunks then self:Remove() return end
	self.downloads = self.downloads + 1
	-- print("Requesting",self.identifier,false,false,#self.chunks)

	net.Start("p2mNetStreamRequest")
	net.WriteUInt(self.identifier, 32)
	net.WriteBit(false)
	net.WriteBit(false)
	net.WriteUInt(#self.chunks, 32)
	if CLIENT then net.SendToServer() else net.Send(self.player) end

	timer.Create("p2mNetStreamReadTimeout" .. self.identifier, prop2mesh.Stream.Timeout/2, 1, function() self:Request() end)

end

--Received data so process it
function prop2mesh.Stream.ReadStream:Read(size)
	timer.Remove("p2mNetStreamReadTimeout" .. self.identifier)

	local progress = net.ReadUInt(32)
	if self.chunks[progress] then return end

	local crc = net.ReadString()
	local data = net.ReadData(size)

	if crc == util.CRC(data) then
		self.chunks[progress] = data
	end
	if #self.chunks == self.numchunks then
		self.returndata = table.concat(self.chunks)
		if self.compressed then
			self.returndata = util.Decompress(self.returndata)
		end
		self:Remove()
	else
		self:Request()
	end

end

--Gets the download progress
function prop2mesh.Stream.ReadStream:GetProgress()
	return #self.chunks/self.numchunks
end

--Pop the queue and start the next task
function prop2mesh.Stream.ReadStream:Remove()

	local ok, err = xpcall(self.callback, debug.traceback, self.returndata)
	if not ok then ErrorNoHalt(err) end

	net.Start("p2mNetStreamRequest")
	net.WriteUInt(self.identifier, 32)
	net.WriteBit(false)
	net.WriteBit(true)
	if CLIENT then net.SendToServer() else net.Send(self.player) end

	timer.Remove("p2mNetStreamReadTimeout" .. self.identifier)
	timer.Remove("p2mNetStreamKeepAlive" .. self.identifier)

	if self == self.queue[1] then
		table.remove(self.queue, 1)
		local nextInQueue = self.queue[1]
		if nextInQueue then
			timer.Remove("p2mNetStreamKeepAlive" .. nextInQueue.identifier)
			nextInQueue:Request()
		else
			prop2mesh.Stream.ReadStreamQueues[self.player] = nil
		end
	else
		for k, v in ipairs(self.queue) do
			if v == self then
				table.remove(self.queue, k)
				break
			end
		end
	end
end

prop2mesh.Stream.ReadStream.__index = prop2mesh.Stream.ReadStream

prop2mesh.Stream.WriteStream = {}

-- The player wants some data
function prop2mesh.Stream.WriteStream:Write(ply)
	local progress = net.ReadUInt(32)+1
	local chunk = self.chunks[progress]
	if chunk then
		self.clients[ply].progress = progress
		net.Start("p2mNetStreamDownload")
		net.WriteUInt(#chunk.data, 32)
		net.WriteUInt(progress, 32)
		net.WriteString(chunk.crc)
		net.WriteData(chunk.data, #chunk.data)
		if CLIENT then net.SendToServer() else net.Send(ply) end
	end
end

-- The player notified us they finished downloading or cancelled
function prop2mesh.Stream.WriteStream:Finished(ply)
	self.clients[ply].finished = true
	if self.callback then
		local ok, err = xpcall(self.callback, debug.traceback, ply)
		if not ok then ErrorNoHalt(err) end
	end
end

-- Get player's download progress
function prop2mesh.Stream.WriteStream:GetProgress(ply)
	return self.clients[ply].progress / #self.chunks
end

-- If the stream owner cancels it, notify everyone who is subscribed
function prop2mesh.Stream.WriteStream:Remove()
	local sendTo = {}
	for ply, client in pairs(self.clients) do
		if not client.finished then
			client.finished = true
			if ply:IsValid() then sendTo[#sendTo+1] = ply end
		end
	end

	net.Start("p2mNetStreamDownload")
	net.WriteUInt(0, 32)
	net.WriteUInt(self.identifier, 32)
	if SERVER then net.Send(sendTo) else net.SendToServer() end
	prop2mesh.Stream.WriteStreams[self.identifier] = nil
end

prop2mesh.Stream.WriteStream.__index = prop2mesh.Stream.WriteStream

--Store the data and write the file info so receivers can request it.
local identifier = 1
function prop2mesh.WriteStream(data, callback, dontcompress)

	if not isstring(data) then
		error("bad argument #1 to 'WriteStream' (string expected, got " .. type(data) .. ")", 2)
	end
	if callback ~= nil and not isfunction(callback) then
		error("bad argument #2 to 'WriteStream' (function expected, got " .. type(callback) .. ")", 2)
	end

	local compressed = not dontcompress
	if compressed then
		data = util.Compress(data) or ""
	end

	if #data == 0 then
		net.WriteUInt(0, 32)
		return
	end

	local numchunks = math.ceil(#data / prop2mesh.Stream.SendSize)
	if CLIENT and numchunks > prop2mesh.Stream.MaxServerChunks then
		ErrorNoHalt("prop2mesh.WriteStream request is too large! ", #data/1048576, "MiB")
		net.WriteUInt(0, 32)
		return
	end

	local chunks = {}
	for i=1, numchunks do
		local datachunk = string.sub(data, (i - 1) * prop2mesh.Stream.SendSize + 1, i * prop2mesh.Stream.SendSize)
		chunks[i] = {
			data = datachunk,
			crc = util.CRC(datachunk),
		}
	end

	local startid = identifier
	while prop2mesh.Stream.WriteStreams[identifier] do
		identifier = identifier % 1024 + 1
		if identifier == startid then
			ErrorNoHalt("Netstream is full of WriteStreams!")
			net.WriteUInt(0, 32)
			return
		end
	end

	local stream = {
		identifier = identifier,
		chunks = chunks,
		compressed = compressed,
		numchunks = numchunks,
		callback = callback,
		clients = setmetatable({},{__index = function(t,k)
			local r = {
				finished = false,
				downloads = 0,
				keepalives = 0,
				progress = 0,
			} t[k]=r return r
		end})
	}
	setmetatable(stream, prop2mesh.Stream.WriteStream)

	prop2mesh.Stream.WriteStreams[identifier] = stream
	timer.Create("p2mNetStreamWriteTimeout" .. identifier, prop2mesh.Stream.Timeout, 1, function() stream:Remove() end)

	net.WriteUInt(numchunks, 32)
	net.WriteUInt(identifier, 32)
	net.WriteBool(compressed)

	return stream
end

--If the receiver is a player then add it to a queue.
--If the receiver is the server then add it to a queue for each individual player
function prop2mesh.ReadStream(ply, callback)

	if CLIENT then
		ply = NULL
	else
		if type(ply) ~= "Player" then
			error("bad argument #1 to 'ReadStream' (Player expected, got " .. type(ply) .. ")", 2)
		elseif not ply:IsValid() then
			error("bad argument #1 to 'ReadStream' (Tried to use a NULL entity!)", 2)
		end
	end
	if not isfunction(callback) then
		error("bad argument #2 to 'ReadStream' (function expected, got " .. type(callback) .. ")", 2)
	end

	local queue = prop2mesh.Stream.ReadStreamQueues[ply]
	if queue then
		if SERVER and #queue == prop2mesh.Stream.MaxServerReadStreams then
			ErrorNoHalt("Receiving too many ReadStream requests from ", ply)
			return
		end
	else
		queue = {} prop2mesh.Stream.ReadStreamQueues[ply] = queue
	end

	local numchunks = net.ReadUInt(32)
	if numchunks == nil then
		return
	elseif numchunks == 0 then
		local ok, err = xpcall(callback, debug.traceback, "")
		if not ok then ErrorNoHalt(err) end
		return
	end
	if SERVER and numchunks > prop2mesh.Stream.MaxServerChunks then
		ErrorNoHalt("ReadStream requests from ", ply, " is too large! ", numchunks * prop2mesh.Stream.SendSize / 1048576, "MiB")
		return
	end

	local identifier = net.ReadUInt(32)
	local compressed = net.ReadBool()
	--print("Got info", numchunks, identifier, compressed)

	for _, v in ipairs(queue) do
		if v.identifier == identifier then
			ErrorNoHalt("Tried to start a new ReadStream for an already existing stream!")
			return
		end
	end

	local stream = {
		identifier = identifier,
		chunks = {},
		compressed = compressed,
		numchunks = numchunks,
		callback = callback,
		queue = queue,
		player = ply,
		downloads = 0
	}
	setmetatable(stream, prop2mesh.Stream.ReadStream)

	queue[#queue + 1] = stream
	if #queue > 1 then
		timer.Create("p2mNetStreamKeepAlive" .. identifier, prop2mesh.Stream.Timeout / 2, 0, function()
			net.Start("p2mNetStreamRequest")
			net.WriteUInt(identifier, 32)
			net.WriteBit(true)
			if CLIENT then net.SendToServer() else net.Send(ply) end
		end)
	else
		stream:Request()
	end

	return stream
end

if SERVER then

	util.AddNetworkString("p2mNetStreamRequest")
	util.AddNetworkString("p2mNetStreamDownload")

end

--Stream data is requested
net.Receive("p2mNetStreamRequest", function(len, ply)

	local identifier = net.ReadUInt(32)
	local stream = prop2mesh.Stream.WriteStreams[identifier]

	if stream then
		ply = ply or NULL
		local client = stream.clients[ply]

		if not client.finished then
			local keepalive = net.ReadBit() == 1
			if keepalive then
				if client.keepalives < prop2mesh.Stream.MaxKeepalive then
					client.keepalives = client.keepalives + 1
					timer.Adjust("p2mNetStreamWriteTimeout" .. identifier, prop2mesh.Stream.Timeout, 1)
				end
			else
				local completed = net.ReadBit() == 1
				if completed then
					stream:Finished(ply)
				else
					if client.downloads < prop2mesh.Stream.MaxTries * #stream.chunks then
						client.downloads = client.downloads + 1
						stream:Write(ply)
						timer.Adjust("p2mNetStreamWriteTimeout" .. identifier, prop2mesh.Stream.Timeout, 1)
					else
						client.finished = true
					end
				end
			end
		end
	end

end)

--Download the stream data
net.Receive("p2mNetStreamDownload", function(len, ply)

	ply = ply or NULL
	local queue = prop2mesh.Stream.ReadStreamQueues[ply]
	if queue then
		local size = net.ReadUInt(32)
		if size > 0 then
			queue[1]:Read(size)
		else
			local id = net.ReadUInt(32)
			for k, v in ipairs(queue) do
				if v.identifier == id then
					v:Remove()
					break
				end
			end
		end
	end

end)
