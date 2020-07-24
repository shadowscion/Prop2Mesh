include("shared.lua")
include("cl_fixup.lua")

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

local drawhud = {}

function ENT:Initialize()
    self.matrix = Matrix()
    self:SetRenderBounds(
        Vector(self:GetRMinX(), self:GetRMinY(), self:GetRMinZ()),
        Vector(self:GetRMaxX(), self:GetRMaxY(), self:GetRMaxZ()))
    self.boxtime = CurTime()
end

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

local angle = Angle()
local angle90 = Angle(0, 90, 0)

function ENT:ResetMeshes()
    self:RemoveMeshes()

    local infocache = {}
    local triangles = {}
    self.meshes = {}
    self.tricount = 0

    drawhud[self] = true

    self.rebuild = coroutine.create(function()
        for _, model in ipairs(self.models) do
            -- caching
            local modelmeshes = infocache[model.mdl]
            if not modelmeshes then
                modelmeshes = util.GetModelMeshes(model.mdl)
                if modelmeshes then
                    infocache[model.mdl] = modelmeshes
                else
                    continue
                end
            end

            self.progress = math.floor((_ / #self.models)*100)

            -- setup
            local scale = model.scale
            local lpos = Vector(model.pos)
            local lang = Angle(model.ang)

            local fix = p2mfix[model.mdl]
            if not fix then
                fix = p2mfix[string.GetPathFromFilename(model.mdl)]
            end
            if fix then
                lang:RotateAroundAxis(lang:Up(), 90)
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

            local wpos = self:LocalToWorld(lpos)
            local wang = self:LocalToWorldAngles(lang)

            -- generate
            local tri = {}
            if model.clips then
                for _, modelmesh in ipairs(modelmeshes) do
                    for _, vertex in ipairs(modelmesh.triangles) do
                        local vpos = Vector(vertex.pos)
                        if scale then
                            vpos = vpos * scale
                        end
                        table.insert(tri, { pos = vpos, normal = vertex.normal, u = vertex.u, v = vertex.v })
                        coroutine.yield(false)
                    end
                end
                for _, clip in ipairs(model.clips) do
                    tri = ClipMesh(tri, clip.n, clip.d)
                end
                local newtri = {}
                for _, vertex in ipairs(tri) do
                    local vnrm = Vector(vertex.normal)
                    vnrm:Rotate(lang)
                    local vpos = Vector(vertex.pos)
                    local vec, ang = LocalToWorld(vpos, angle, wpos, wang)
                    table.insert(newtri, { pos = self:WorldToLocal(vec), normal = vnrm, u = vertex.u, v = vertex.v })
                    coroutine.yield(false)
                end
                if model.inv then
                    for i = #newtri, 1, -1 do
                        table.insert(newtri, newtri[i])
                        coroutine.yield(false)
                    end
                end
                tri = newtri
            else
                for _, modelmesh in ipairs(modelmeshes) do
                    for _, vertex in ipairs(modelmesh.triangles) do
                        local vnrm = Vector(vertex.normal)
                        vnrm:Rotate(lang)
                        local vpos = Vector(vertex.pos)
                        if scale then
                            vpos = vpos * scale
                        end
                        local vec, ang = LocalToWorld(vpos, angle, wpos, wang)
                        table.insert(tri, { pos = self:WorldToLocal(vec), normal = vnrm, u = vertex.u, v = vertex.v })
                        coroutine.yield(false)
                    end
                end
            end
            if #triangles + #tri >= 65535 then
                local m = Mesh()
                m:BuildFromTriangles(triangles)
                table.insert(self.meshes, m)
                self.tricount = self.tricount + #triangles
                triangles = {}
            end
            for _, vertex in ipairs(tri) do
                table.insert(triangles, vertex)
                coroutine.yield(false)
            end
        end
        if #triangles > 0 then
            local m = Mesh()
            m:BuildFromTriangles(triangles)
            table.insert(self.meshes, m)
            self.tricount = self.tricount + #triangles
        end
        self.tricount = self.tricount / 3
        coroutine.yield(true)
    end)
end

function ENT:Think()
    if self.rebuild then
        local mark = SysTime()
        while SysTime() - mark < 0.005 do
            local _, msg = coroutine.resume(self.rebuild)
            if msg then
                drawhud[self] = nil
                self.rebuild = nil
                break
            end
        end
    end
end

local red = Color(255, 0, 0)

function ENT:Draw()
    self:DrawModel()
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
        if LocalPlayer():UserID() ~= self:GetNetworkedInt("ownerid") then
            return
        end
        if CurTime() - self.boxtime > 3 then
            self.boxtime = nil
            return
        end
        local min, max = self:GetRenderBounds()
        render.DrawWireframeBox(self:GetPos(), self:GetAngles(), min, max, red)
    end
end

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

local bc = Color(175, 175, 175, 135)
local tc = Color(225, 225, 225, 255)

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
        draw.WordBox(5, scr.x, scr.y, string.format("Generating Mesh [%d%%]", ent.progress or 0), "DermaDefault", bc, tc)
    end
end)
