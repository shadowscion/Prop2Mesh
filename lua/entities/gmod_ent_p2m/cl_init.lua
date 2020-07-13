include("shared.lua")

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
                    self:ResetMeshes()
                end)
            end
        end
    end
end)

function ENT:Initialize()
    self.matrix = Matrix()
    self:SetRenderBounds(
        Vector(self:GetRMinX(), self:GetRMinY(), self:GetRMinZ()),
        Vector(self:GetRMaxX(), self:GetRMaxY(), self:GetRMaxZ()))
    self.boxtime = CurTime()
end

function ENT:OnRemove()
    self:RemoveMeshes()
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
        normal = (a.normal * (1 - t) + (b.normal * t)):GetNormalized(),
        u = a.u,
        v = a.v,
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

function ENT:ResetMeshes()
    self:RemoveMeshes()

    local models = util.JSONToTable(util.Decompress(self.packets))

    --PrintTable(models)

    local cached = {}
    local build = {}
    local angle = Angle()
    self.meshes = {}

    self.rebuild = coroutine.create(function()
        for _, model in ipairs(models) do
            local meshes = cached[model.mdl]
            if not meshes then
                meshes = util.GetModelMeshes(model.mdl)
                if meshes then
                    cached[model.mdl] = meshes
                else
                    continue
                end
            end
            local modeltri = {}
            if model.clips then
                for k = 1, #meshes do
                    local verts = meshes[k].triangles
                    if not verts then
                        continue
                    end
                    for i, v in ipairs(verts) do
                        local pos = Vector(v.pos)
                        if model.scale then
                            pos = pos * model.scale
                        end
                        table.insert(modeltri, {
                            pos = pos,
                            normal = v.normal,
                            u = v.u,
                            v = v.v,
                        })
                    end
                end
                for i, clip in ipairs(model.clips) do
                    modeltri = ClipMesh(modeltri, clip.n, clip.d)
                end
                local new = {}
                for i = 1, #modeltri do
                    local normal = Vector(modeltri[i].normal)
                    normal:Rotate(model.ang)

                    local pos = Vector(modeltri[i].pos)
                    local vec, _ = LocalToWorld(pos, angle, self:LocalToWorld(model.pos), self:LocalToWorldAngles(model.ang))

                    table.insert(new, {
                        pos = self:WorldToLocal(vec),
                        normal = normal,
                        u = modeltri[i].u,
                        v = modeltri[i].v,
                    })
                    coroutine.yield(false)
                end
                modeltri = new
            else
                for k = 1, #meshes do
                    local verts = meshes[k].triangles
                    if not verts then
                        continue
                    end
                    for i = 1, #verts do
                        local normal = Vector(verts[i].normal)
                        normal:Rotate(model.ang)

                        local pos = Vector(verts[i].pos)
                        if model.scale then
                            pos = pos * model.scale
                        end
                        local vec, _ = LocalToWorld(pos, angle, self:LocalToWorld(model.pos), self:LocalToWorldAngles(model.ang))

                        table.insert(modeltri, {
                            pos = self:WorldToLocal(vec),
                            normal = normal,
                            u = verts[i].u,
                            v = verts[i].v,
                        })
                        coroutine.yield(false)
                    end
                end
            end
            if #build + #modeltri >= 65535 then
                local m = Mesh()
                m:BuildFromTriangles(build)
                table.insert(self.meshes, m)
                build = {}
            end
            for i = 1, #modeltri, 3 do
                for j = 0, 2 do
                    table.insert(build, modeltri[i + j])
                    coroutine.yield(false)
                end
            end
            coroutine.yield(false)
        end
        if #build > 0 then
            local m = Mesh()
            m:BuildFromTriangles(build)
            table.insert(self.meshes, m)
        end
        coroutine.yield(true)
    end)
end

function ENT:Think()
    if self.rebuild then
        local mark = SysTime()
        while SysTime() - mark < 0.002 do
            local _, msg = coroutine.resume(self.rebuild)
            if msg then
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
