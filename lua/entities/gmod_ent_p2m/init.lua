AddCSLuaFile("cl_fixup.lua")
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

util.AddNetworkString("p2m_stream")

function ENT:Initialize()
    self:SetModel("models/hunter/plates/plate.mdl")
    self:SetMaterial("models/debug/debugwhite")
    self:DrawShadow(false)

    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)

    local phys = self:GetPhysicsObject()
    if phys:IsValid() then
        phys:EnableMotion(false)
        phys:Wake()
    end
end

function ENT:BuildFromTable(tbl)
    duplicator.ClearEntityModifier(self, "p2m_packets")
    local function get()
        local ret = {}
        for _, ent in ipairs(tbl) do
            if not IsValid(ent) then
                continue
            end

            local data = {}
            data.pos, data.ang = WorldToLocal(ent:GetPos(), ent:GetAngles(), self:GetPos(), self:GetAngles())
            data.mdl = string.lower(ent:GetModel())

            local scale = ent:GetManipulateBoneScale(0)
            if scale.x ~= 1 or scale.y ~= 1 or scale.z ~= 1 then
                data.scale = scale
            end

            local clips = ent.ClipData
            if clips then
                for _, clip in ipairs(clips) do
                    if clip.inside then
                        continue
                    end
                    data.clips = data.clips or {}
                    table.insert(data.clips, { n = clip.n:Forward(), d = clip.d + clip.n:Forward():Dot(ent:OBBCenter()) })
                end
            end
            table.insert(ret, data)

            coroutine.yield(false)
        end
        return ret
    end
    self.compile = coroutine.create(function()
        local json = util.Compress(util.TableToJSON(get()))
        local packets = {}
        for i = 1, string.len(json), 32000 do
            local c = string.sub(json, i, i + math.min(32000, string.len(json) - i + 1) - 1)
            table.insert(packets, { c, string.len(c) })
        end

        packets.crc = util.CRC(json)

        self:Network(packets)

        duplicator.StoreEntityModifier(self, "p2m_packets", packets)

        coroutine.yield(true)
    end)
end

function ENT:Network(packets, ply)
    timer.Simple(0.1, function()
        for i, packet in ipairs(packets) do
            net.Start("p2m_stream")
                net.WriteEntity(self)
                net.WriteUInt(i, 16)
                net.WriteUInt(packet[2], 32)
                net.WriteData(packet[1], packet[2])
                if i == #packets then
                    net.WriteBool(true)
                    net.WriteString(packets.crc)
                else
                    net.WriteBool(false)
                end
            if ply then net.Send(ply) else net.Broadcast() end
        end
    end)
end

duplicator.RegisterEntityModifier("p2m_packets", function (ply, self, packets)
    print(ply)
    self:SetNetworkedInt("ownerid", ply:UserID())
    self:Network(packets)
end)

function ENT:PostEntityPaste(ply, ent, createdEntities)
    if not IsValid(ply) then
        return
    end
    ent:SetNetworkedInt("ownerid", ply:UserID())
    ply:AddCount("gmod_ent_p2m", ent)
    ply:AddCleanup("gmod_ent_p2m", ent)
end

function ENT:Think()
    if self.compile then
        local mark = SysTime()
        while SysTime() - mark < 0.002 do
            local _, msg = coroutine.resume(self.compile)
            if msg then
                self.compile = nil
                break
            end
        end
    end
end
