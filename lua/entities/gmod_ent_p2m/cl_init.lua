-- -----------------------------------------------------------------------------
include("shared.lua")
include("cl_fixup.lua")

local drawhud = {}

local Vector = Vector
local string = string
local surface = surface
local render = render

local p2m_disable = CreateClientConVar("p2m_disable_rendering", "0", true, false)
local p2m_build_time = CreateClientConVar("p2m_build_time", 0.05, true, false, "Lower to reduce stuttering", 0.001, 0.1)


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
local function LineEdgeIntersection(vert1, vert2, plane, length)
	local edge = vert2.pos - vert1.pos
	local lerp = (length - plane:Dot(vert1.pos)) / plane:Dot(edge)
	if lerp < 0 then
		return vert1
	elseif lerp > 1 then
		return vert2
	end
	return {
		pos    = vert1.pos + edge*lerp,
		normal = ((1 - lerp)*vert1.normal + lerp*vert2.normal):GetNormalized(),
		u      = (1 - lerp)*vert1.u + lerp*vert2.u,
		v      = (1 - lerp)*vert1.v + lerp*vert2.v,
	}
end

local function ApplyClippingPlane(verts, plane, length)
	local temp = {}
	for i = 1, #verts, 3 do
		local vert1 = verts[i + 0]
		local vert2 = verts[i + 1]
		local vert3 = verts[i + 2]

		local length1 = plane:Dot(vert1.pos) - length
		local length2 = plane:Dot(vert2.pos) - length
		local length3 = plane:Dot(vert3.pos) - length

		if length1 < 0 and length2 > 0 and length3 > 0 then
			local vert4 = LineEdgeIntersection(vert2, vert1, plane, length)
			local vert5 = LineEdgeIntersection(vert3, vert1, plane, length)

			temp[#temp + 1] = vert4
			temp[#temp + 1] = vert2
			temp[#temp + 1] = vert3
			temp[#temp + 1] = vert4
			temp[#temp + 1] = vert3
			temp[#temp + 1] = vert5

		elseif length1 > 0 and length2 < 0 and length3 > 0 then
			local vert4 = LineEdgeIntersection(vert1, vert2, plane, length)
			local vert5 = LineEdgeIntersection(vert3, vert2, plane, length)

			temp[#temp + 1] = vert1
			temp[#temp + 1] = vert4
			temp[#temp + 1] = vert5
			temp[#temp + 1] = vert1
			temp[#temp + 1] = vert5
			temp[#temp + 1] = vert3

		elseif length1 > 0 and length2 > 0 and length3 < 0 then
			local vert4 = LineEdgeIntersection(vert2, vert3, plane, length)
			local vert5 = LineEdgeIntersection(vert1, vert3, plane, length)

			temp[#temp + 1] = vert1
			temp[#temp + 1] = vert2
			temp[#temp + 1] = vert4
			temp[#temp + 1] = vert1
			temp[#temp + 1] = vert4
			temp[#temp + 1] = vert5

		elseif length1 > 0 and length2 < 0 and length3 < 0 then
			local vert4 = LineEdgeIntersection(vert1, vert2, plane, length)
			local vert5 = LineEdgeIntersection(vert1, vert3, plane, length)

			temp[#temp + 1] = vert1
			temp[#temp + 1] = vert4
			temp[#temp + 1] = vert5

		elseif length1 < 0 and length2 > 0 and length3 < 0 then
			local vert4 = LineEdgeIntersection(vert2, vert1, plane, length)
			local vert5 = LineEdgeIntersection(vert2, vert3, plane, length)

			temp[#temp + 1] = vert4
			temp[#temp + 1] = vert2
			temp[#temp + 1] = vert5

		elseif length1 < 0 and length2 < 0 and length3 > 0 then
			local vert4 = LineEdgeIntersection(vert3, vert1, plane, length)
			local vert5 = LineEdgeIntersection(vert3, vert2, plane, length)

			temp[#temp + 1] = vert4
			temp[#temp + 1] = vert5
			temp[#temp + 1] = vert3

		elseif length1 > 0 and length2 > 0 and length3 > 0 then
			temp[#temp + 1] = vert1
			temp[#temp + 1] = vert2
			temp[#temp + 1] = vert3
		end

		coroutine.yield(false)
	end
	return temp
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
			local meshdata
			if infocache[model.mdl] then
				meshdata = infocache[model.mdl][model.bgrp or 0]
			else
				infocache[model.mdl] = {}
			end
			if not meshdata then
				meshdata = util.GetModelMeshes(model.mdl, 0, model.bgrp or 0)
				if meshdata then
					infocache[model.mdl][model.bgrp or 0] = meshdata
				else
					continue
				end
			end

			-- hud update
			self.progress = _ / #self.models

			-- fixup
			local ang = model.ang
			local scale = model.scale
			local clips

			local fix = p2mfix[model.mdl]
			if not fix then
				fix = p2mfix[string.GetPathFromFilename(model.mdl)]
			end
			if fix then
				ang = Angle(ang.p, ang.y, ang.r)
				ang:RotateAroundAxis(ang:Up(), 90)

				if model.clips then
					clips = {}
					for _, clip in ipairs(model.clips) do
						local normal = Vector(clip.n)
						normal:Rotate(-angle90)
						clips[#clips + 1] = {
							n = normal,
							d = clip.d,
						}
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
			if not clips then
				clips = model.clips
			end

			-- fake entity
			mModel:SetTranslation(model.pos)
			mModel:SetAngles(ang)
			mModel = mSelf * mModel

			-- vertices
			local modelverts = {}
			if clips then
				-- create scaled vert list
				for _, part in ipairs(meshdata) do
					for _, vert in ipairs(part.triangles) do
						modelverts[#modelverts + 1] = {
							pos    = scale and vert.pos * scale or vert.pos,
							normal = vert.normal,
							u      = vert.u,
							v      = vert.v,
						}
						coroutine.yield(false)
					end
				end

				-- create clipped vert list
				for _, clip in ipairs(clips) do
					modelverts = ApplyClippingPlane(modelverts, clip.n, clip.d)
				end

				-- localize vert list
				local temp = {}
				for _, vert in ipairs(modelverts) do
					mVertex:SetTranslation(vert.pos)

					local normal = Vector(vert.normal)
					normal:Rotate(ang)

					temp[#temp + 1] = {
						pos    = (mSelfInverse * (mModel * mVertex)):GetTranslation(),
						normal = normal,
						u      = vert.u,
						v      = vert.v,
					}
					coroutine.yield(false)
				end

				-- visclip renderinside flag
				if model.inv then
					for i = #temp, 1, -1 do
						temp[#temp + 1] = temp[i]
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

						modelverts[#modelverts + 1] = {
							pos    = (mSelfInverse * (mModel * mVertex)):GetTranslation(),
							normal = normal,
							u      = vert.u,
							v      = vert.v,
						}
						coroutine.yield(false)
					end
				end
			end

			-- create meshes
			if #meshverts + #modelverts >= 65535 then
				local m = Mesh()
				m:BuildFromTriangles(meshverts)
				self.meshes[#self.meshes + 1] = m
				meshverts = {}
			end
			for _, vert in ipairs(modelverts) do
				meshverts[#meshverts + 1] = vert
				vertexcount = vertexcount + 1
				coroutine.yield(false)
			end
		end

		-- create meshes
		local m = Mesh()
		m:BuildFromTriangles(meshverts)
		self.meshes[#self.meshes + 1] = m

		self.tricount = vertexcount / 3

		coroutine.yield(true)
	end)
end


-- -----------------------------------------------------------------------------
function ENT:Think()
	self.matrix = self:GetWorldTransformMatrix()
	if p2m_disable:GetBool() then
		if self.rebuild then
			drawhud[self] = nil
			self.rebuild = nil
		end
		return
	end
	if self.rebuild then
		local mark = SysTime()
		while SysTime() - mark < p2m_build_time:GetFloat() do
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
	if p2m_disable:GetBool() then
		self:DrawModel()
		return
	end
	--[[
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
	]]
	self:DrawModel()
	if self.meshes then
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
hook.Add("HUDPaint", "p2m.loadoverlay", function()
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
					if not IsValid(self) or not self.packets then
						return
					end
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
