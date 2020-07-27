-- -----------------------------------------------------------------------------
include("shared.lua")
include("cl_fixup.lua")

local drawhud = {}


-- -----------------------------------------------------------------------------
function ENT:Initialize()
	self.matrix = Matrix()
	self:SetRenderBounds(
		Vector(self:GetRMinX(), self:GetRMinY(), self:GetRMinZ()),
		Vector(self:GetRMaxX(), self:GetRMaxY(), self:GetRMaxZ()))
	self.tricount = 0
	self.progress = 0
end


-- -----------------------------------------------------------------------------
function ENT:OnRemove()
	self:RemoveMeshes()
	drawhud[self] = nil
end

function ENT:RemoveMeshes()
	if self.meshes then
		for _, m in pairs(self.meshes) do
			if m:IsValid() then
				m:Destroy()
			end
		end
	end
end


-- -----------------------------------------------------------------------------
local function LinePlane(a, b, n, d)
	local ap = a.pos
	local cp = b.pos - a.pos
	local t = (d - n:Dot(ap)) / n:Dot(cp)
	if t < 0 then
		return a
	end
	if t > 1 then
		return b
	end
	return {
		pos = ap + cp*t,
		normal = ((1 - t)*a.normal + t*b.normal):GetNormalized(),
		u = (1 - t)*a.u + t*b.u,
		v = (1 - t)*a.v + t*b.v,
	}
end

local function ClipMesh(oldVertList, clipPlane, clipLength)
	local newVertList = {}
	for i = 1, #oldVertList, 3 do
		local vertLookup = {}
		local vert1 = oldVertList[i + 0]
		local vert2 = oldVertList[i + 1]
		local vert3 = oldVertList[i + 2]
		local vert4
		local vert5
		local length1 = clipPlane:Dot(vert1.pos) - clipLength
		local length2 = clipPlane:Dot(vert2.pos) - clipLength
		local length3 = clipPlane:Dot(vert3.pos) - clipLength

		if length1 < 0 and length2 > 0 and length3 > 0 then
			vert4 = LinePlane(vert2, vert1, clipPlane, clipLength)
			vert5 = LinePlane(vert3, vert1, clipPlane, clipLength)
			vertLookup = { 4, 2, 3, 4, 3, 5 }
		elseif length1 > 0 and length2 < 0 and  length3 > 0 then
			vert4 = LinePlane(vert1, vert2, clipPlane, clipLength)
			vert5 = LinePlane(vert3, vert2, clipPlane, clipLength)
			vertLookup = { 1, 4, 5, 1, 5, 3 }
		elseif length1 > 0 and length3 < 0 and length2 > 0 then
			vert4 = LinePlane(vert2, vert3, clipPlane, clipLength)
			vert5 = LinePlane(vert1, vert3, clipPlane, clipLength)
			vertLookup = { 1, 2, 4, 1, 4, 5 }
		elseif length1 > 0 and length2 < 0 and length3 < 0 then
			vert4 = LinePlane(vert1, vert2, clipPlane, clipLength)
			vert5 = LinePlane(vert1, vert3, clipPlane, clipLength)
			vertLookup = { 1, 4, 5 }
		elseif length1 < 0 and length2 > 0 and length3 < 0 then
			vert4 = LinePlane(vert2, vert1, clipPlane, clipLength)
			vert5 = LinePlane(vert2, vert3, clipPlane, clipLength)
			vertLookup = { 4, 2, 5 }
		elseif length1 < 0 and length2 < 0 and length3 > 0 then
			vert4 = LinePlane(vert3, vert1, clipPlane, clipLength)
			vert5 = LinePlane(vert3, vert2, clipPlane, clipLength)
			vertLookup = { 4, 5, 3 }
		elseif length1 > 0 and length2 > 0 and length3 > 0 then
			vertLookup = { 1, 2, 3 }
		end

		local lookup = { vert1, vert2, vert3, vert4, vert5 }
		for _, index in pairs(vertLookup) do
			table.insert(newVertList, lookup[index])
		end

		coroutine.yield(false)
	end

	return newVertList
end


-- -----------------------------------------------------------------------------
local angle = Angle()
local angle90 = Angle(0, 90, 0)
function ENT:ResetMeshes()
	self:RemoveMeshes()

	self.meshes = {}

	local vertexcount = 0
	local meshverts = {}
	local infocache = {}

	local mVertex = Matrix()
	local mModel = Matrix()
	local mSelf = Matrix()
	mSelf:SetTranslation(self:GetPos())
	mSelf:SetAngles(self:GetAngles())
	local mSelfInverse = mSelf:GetInverse()

	drawhud[self] = true

	self.rebuild = coroutine.create(function()
		for _, model in pairs(self.models) do
			-- model info
			local meshdata = infocache[model.mdl]
			if not meshdata then
				meshdata = util.GetModelMeshes(model.mdl)
				if meshdata then
					infocache[model.mdl] = meshdata
				else
					continue
				end
			end

			-- hud update
			self.progress = _ / #self.models

			-- fixup
			local ang = model.ang
			local scale = model.scale

			local fix = p2mfix[model.mdl]
			if not fix then
				fix = p2mfix[string.GetPathFromFilename(model.mdl)]
			end
			if fix then
				ang = Angle(ang.p, ang.y, ang.r)
				ang:RotateAroundAxis(ang:Up(), 90)

				if model.clips then
					for _, clip in ipairs(model.clips) do
						clip.n:Rotate(-angle90)
					end
				end
				if scale then
					if model.holo then
						scale = Vector(scale.y, scale.x, scale.z)
					else
						scale = Vector(scale.x, scale.z, scale.y)
					end
				end
			end

			-- fake entity
			mModel:SetTranslation(model.pos)
			mModel:SetAngles(ang)
			mModel = mSelf * mModel

			-- vertices
			local modelverts = {}
			if model.clips then
				-- create scaled vert list
				for _, part in ipairs(meshdata) do
					for _, vert in ipairs(part.triangles) do
						table.insert(modelverts, {
							pos = scale and vert.pos * scale or vert.pos,
							normal = vert.normal,
							u = vert.u,
							v = vert.v,
						})
						coroutine.yield(false)
					end
				end

				-- create clipped vert list
				for _, clip in ipairs(model.clips) do
					modelverts = ClipMesh(modelverts, clip.n, clip.d)
				end

				-- localize vert list
				local temp = {}
				for _, vert in ipairs(modelverts) do
					mVertex:SetTranslation(vert.pos)

					local normal = Vector(vert.normal.x, vert.normal.y, vert.normal.z)
					normal:Rotate(ang)

					table.insert(temp, {
						pos = (mSelfInverse * (mModel * mVertex)):GetTranslation(),
						normal = normal,
						u = vert.u,
						v = vert.v,
					})
					coroutine.yield(false)
				end

				-- visclip renderinside flag
				if model.inv then
					for i = #temp, 1, -1 do
						table.insert(temp, temp[i])
						coroutine.yield(false)
					end
				end
				modelverts = temp
			else
				for _, part in ipairs(meshdata) do
					for _, vert in ipairs(part.triangles) do
						if scale then
							mVertex:SetTranslation(vert.pos * scale)
						else
							mVertex:SetTranslation(vert.pos)
						end

						local normal = Vector(vert.normal.x, vert.normal.y, vert.normal.z)
						normal:Rotate(ang)

						table.insert(modelverts , {
							pos = (mSelfInverse * (mModel * mVertex)):GetTranslation(),
							normal = normal,
							u = vert.u,
							v = vert.v,
						})
						coroutine.yield(false)
					end
				end
			end

			-- create meshes
			if #meshverts + #modelverts >= 65535 then
				local m = Mesh()
				m:BuildFromTriangles(meshverts)
				table.insert(self.meshes, m)
				meshverts = {}
			end
			for _, vert in ipairs(modelverts) do
				table.insert(meshverts, vert)
				vertexcount = vertexcount + 1
				coroutine.yield(false)
			end
		end

		-- create meshes
		local m = Mesh()
		m:BuildFromTriangles(meshverts)
		table.insert(self.meshes, m)

		self.tricount = vertexcount / 3

		coroutine.yield(true)
	end)
end


-- -----------------------------------------------------------------------------
function ENT:Think()
	if self.rebuild then
		local mark = SysTime()
		while SysTime() - mark < 0.01 do
			local _, msg = coroutine.resume(self.rebuild)
			if msg then
				drawhud[self] = nil
				self.rebuild = nil
				break
			end
		end
	end
end


-- -----------------------------------------------------------------------------
local red = Color(255, 0, 0, 15)
function ENT:Draw()
	if self:GetNWBool("hidemodel") then
		if self.materialName ~= self:GetMaterial() then
			self.materialName = self:GetMaterial()
			if self.materialName ~= "" then
				self.material = Material(self.materialName)
			end
		end
		if self.material and not self.material:IsError() then
			render.SetMaterial(self.material)
		else
			self:DrawModel()
		end
	else
		self:DrawModel()
	end
	if self.meshes then
		self.matrix:SetTranslation(self:GetPos())
		self.matrix:SetAngles(self:GetAngles())
		cam.PushModelMatrix(self.matrix)
		for _, m in pairs(self.meshes) do
			if not m:IsValid() then
				continue
			end
			m:Draw()
		end
		cam.PopModelMatrix()
	end
	if self.boxtime then
		if not self.models or self.rebuild then
			return
		end
		if LocalPlayer():UserID() ~= self:GetNetworkedInt("ownerid") then
			return
		end
		if CurTime() - self.boxtime > 3 then
			self.boxtime = nil
			return
		end
		render.SetColorMaterial()
		local min, max = self:GetRenderBounds()
		render.DrawWireframeBox(self:GetPos(), self:GetAngles(), min, max, red)
		render.DrawBox(self:GetPos(), self:GetAngles(), min, max, red)
	end
end


-- -----------------------------------------------------------------------------
hook.Add("HUDPaint", "meshtools.LoadOverlay", function()
	for ent, _ in pairs(drawhud) do
		if not IsValid(ent) then
			drawhud[ent] = nil
			continue
		end
		if not ent.rebuild then
			drawhud[ent] = nil
			continue
		end
		local scr = ent:GetPos():ToScreen()
		local perc = ent.progress or 0

		local w = 96
		local h = 32

		surface.SetDrawColor(50, 50, 50, 150)
		surface.DrawRect(scr.x, scr.y, w, h)

		surface.SetDrawColor(0, 0, 0, 150)
		surface.DrawOutlinedRect(scr.x, scr.y, w, h)

		surface.SetDrawColor(80, 160, 80, 150)
		surface.DrawRect(scr.x + 1, scr.y + 1, (w - 2)*perc, h - 2)

		surface.SetTextColor(255, 255, 255)
		surface.SetFont("BudgetLabel")
		local str = string.format("%d%%", perc*100)
		local tw, th = surface.GetTextSize(str)
		surface.SetTextPos(scr.x + w*0.5 - tw*0.5, scr.y + h*0.5 - th*0.5)
		surface.DrawText(str)
	end
end)

-- -----------------------------------------------------------------------------
net.Receive("p2m_stream", function()
	local self = net.ReadEntity()
	if IsValid(self) then
		local packetid = net.ReadUInt(16)
		if packetid == 1 then
			self.packets = ""
		end
		local packetln = net.ReadUInt(32)
		local packetst = net.ReadData(packetln, packetln)

		self.packets = self.packets .. packetst

		local done = net.ReadBool()
		if done then
			local crc = net.ReadString()
			if crc == util.CRC(self.packets) then
				timer.Simple(0.1, function()
					self.models = util.JSONToTable(util.Decompress(self.packets))
					self:ResetMeshes()
				end)
			end
		end
	end
end)


-- -----------------------------------------------------------------------------
hook.Add("OnEntityCreated", "p2m_refresh", function(self)
	if not IsValid(self) then
		return
	end
	if self:GetClass() ~= "gmod_ent_p2m" then
		return
	end
	if self.models then
		self:ResetMeshes()
	else
		net.Start("p2m_refresh")
		net.WriteEntity(self)
		net.SendToServer()
	end
end)

concommand.Add("p2m_refresh_all", function()
	net.Start("p2m_refresh")
	net.SendToServer()
end)
