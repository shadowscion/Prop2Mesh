
E2Lib.RegisterExtension("p2m", true, "Allows E2 chips to create and manipulate prop2mesh entities")

local WireLib = WireLib
local E2Lib = E2Lib

local function P2M_AntiSpam(ent, action)
    if not ent.p2mantispam then
        ent.p2mantispam = {}
    end
    if ent.p2mantispam[action] and ent.p2mantispam[action] == CurTime() then
        return false
    end
    ent.p2mantispam[action] = CurTime()
    return true
end

local function P2M_CanManipulate(self, ent, action)
    if not IsValid(ent) then
        return false
    end
    if ent:GetClass() ~= "gmod_ent_p2m" then
        return false
    end
    if action == "compile" and ent.compile then
        return false
    end
    if game.SinglePlayer() then
        return P2M_AntiSpam(ent, action)
    end
    if ent.e2player == self.player then
        return P2M_AntiSpam(ent, action)
    end
    if E2Lib.isOwner(self, ent) then
        return P2M_AntiSpam(ent, action)
    end
    return false
end

local mask = {
    ang = {
        typeid = "a",
        required = true,
        parse = function(tbl)
            return Angle(tbl[1], tbl[2], tbl[3])
        end,
    },
    pos = {
        typeid = "v",
        required = true,
        parse = function(tbl)
            return Vector(tbl[1], tbl[2], tbl[3])
        end,
    },
    mdl = {
        typeid = "s",
        required = true,
        parse = function(str)
            return string.lower(str)
        end,
    },
    clips = {
        typeid = "r",
        parse = function(tbl)
            local clips
            for _, clip in ipairs(tbl) do
                if type(clip) ~= "table" then
                    continue
                end
                if #clip ~= 4 then
                    continue
                end
                local valid = true
                for i = 1, 4 do
                    if type(clip[i]) ~= "number" then
                        valid = false
                        break
                    end
                end
                if valid then
                    if not clips then
                        clips = {}
                    end
                    table.insert(clips, {
                        n = Vector(clip[1], clip[2], clip[3]),
                        d = clip[4],
                    })
                end
            end
            return clips
        end,
    },
}

local function P2M_build(data)
    local tbl = {}
    for k, v in pairs(data.n) do
        local valid = true
        local entry = {}
        for key, typem in pairs(mask) do
            if not v.stypes[key] then
                if typem.required then
                    valid = false
                    break
                end
                continue
            end
            if v.stypes[key] ~= typem.typeid then
                valid = false
                break
            end
            entry[key] = typem.parse(v.s[key])
        end
        if valid then
            table.insert(tbl, entry)
        end
        coroutine.yield(false)
    end
    if #tbl > 0 then
        return tbl
    end
    return nil
end

local function P2M_compile(self, ent, data)
    ent.compile = coroutine.create(function()
        local tbl, min, max = P2M_build(data)
        if not tbl then
            coroutine.yield(true)
            return
        end

        local json = util.Compress(util.TableToJSON(tbl))
        local packets = {}
        for i = 1, string.len(json), 32000 do
            local c = string.sub(json, i, i + math.min(32000, string.len(json) - i + 1) - 1)
            table.insert(packets, { c, string.len(c) })
        end

        packets.crc = util.CRC(json)

        ent:Network(packets)

        --if not ent.e2player then
            duplicator.ClearEntityModifier(ent, "p2m_packets")
            duplicator.StoreEntityModifier(ent, "p2m_packets", packets)
        --end

        coroutine.yield(true)
    end)
end

local function P2M_create(self, pos, ang)
    local ent = ents.Create("gmod_ent_p2m")

    ent:SetModel("models/hunter/plates/plate.mdl")
    E2Lib.setMaterial(ent, "models/debug/debugwhite")
    WireLib.setPos(ent, pos)
    WireLib.setAng(ent, ang)
    ent:Spawn()

    if not IsValid(ent) then
        return NULL
    end

    ent:SetSolid(SOLID_NONE)
    ent:SetMoveType(MOVETYPE_NONE)
    ent:DrawShadow(false)
    ent:Activate()
    ent:SetNetworkedInt("ownerid", self.player:UserID())

    ent:SetRMinX(-6)
    ent:SetRMinY(-6)
    ent:SetRMinZ(-6)
    ent:SetRMaxX(6)
    ent:SetRMaxY(6)
    ent:SetRMaxZ(6)

    ent.e2player = self.player

    ent:CallOnRemove("wire_expression2_p2m_remove",
        function(ent)
            self.data.p2m[ent] = nil
        end
    )

    self.data.p2m[ent] = true

    return ent
end

registerCallback("construct",
    function(self)
        self.data.p2m = {}
    end
)

registerCallback("destruct",
    function(self)
        for ent, _ in pairs(self.data.p2m) do
            ent:Remove()
        end
    end
)

e2function entity p2mCreate(vector pos, angle ang)
    return P2M_create(self, Vector(pos[1], pos[2], pos[3]), Angle(ang[1], ang[2], ang[3]))
end

e2function void entity:p2mHideModel(number hide)
    if not P2M_CanManipulate(self, this, "nide") then
        return
    end
    if not this.e2player then
        return
    end
    this:SetNWBool("hidemodel", hide > 0)
end

e2function void entity:p2mSetData(table data)
    if not P2M_CanManipulate(self, this, "compile") then
        return
    end
    P2M_compile(self, this, data)
end

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
    if not P2M_CanManipulate(self, this, "color") then
        return
    end
    WireLib.SetColor(this, Color(color[1], color[2], color[3]))
end

e2function void entity:p2mSetColor(vector4 color)
    if not P2M_CanManipulate(self, this, "color") then
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

e2function void entity:p2mSetRenderBounds(vector mins, vector maxs)
    if not P2M_CanManipulate(self, this, "bounds") then
        return
    end
    local lower = WireLib.clampPos(Vector(mins[1], mins[2], mins[3]))
    local upper = WireLib.clampPos(Vector(maxs[1], maxs[2], maxs[3]))
    this:SetRMinX(lower.x)
    this:SetRMinY(lower.y)
    this:SetRMinZ(lower.z)
    this:SetRMaxX(upper.x)
    this:SetRMaxY(upper.y)
    this:SetRMaxZ(upper.z)
end

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
