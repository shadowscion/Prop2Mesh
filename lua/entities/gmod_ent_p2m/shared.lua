ENT.Base      = "base_anim"
ENT.PrintName = "P2M Controller"
ENT.Author    = "shadowscion"
ENT.Category  = "Realism"
ENT.Editable  = true
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.RenderGroup = RENDERGROUP_BOTH

--duplicator.Allow("gmod_ent_p2m")
cleanup.Register("gmod_ent_p2m")

function ENT:SpawnFunction(ply, trace, ClassName)
    if not trace.Hit then
        return
    end

    local ang
    if math.abs(trace.HitNormal.x) < 0.001 and math.abs(trace.HitNormal.y) < 0.001 then
        ang = Vector(0, 0, trace.HitNormal.z):Angle()
    else
        ang = trace.HitNormal:Angle()
    end
    ang.p = ang.p + 90

    local ent = ents.Create(ClassName)
    ent:SetPos(trace.HitPos)
    ent:SetAngles(ang)
    ent:Spawn()
    ent:Activate()
    ent:SetCollisionGroup(COLLISION_GROUP_NONE)
    timer.Simple(0.1, function()
        ent:SetNetworkedInt("ownerid", ply:UserID())
        ent:SetDefaultRenderBounds()
    end)

    ply:AddCount("gmod_ent_p2m", ent)
    ply:AddCleanup("gmod_ent_p2m", ent)
    ply:ChatPrint("You can edit this prop2mesh controller using the context menu (hold C and right click it).")

    undo.Create("gmod_ent_p2m")
        undo.AddEntity(ent)
        undo.SetPlayer(ply)
    undo.Finish()

    return ent
end

function ENT:CanProperty(ply, property)
    if property == "remover" then return true end
    if property == "editentity" then return true end
    return false
end

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "RMinX", { KeyName = "rminx", Edit = { category = "Render Bounds", title = "X Min", type = "Int", order = 1, min = -1000, max = 1000 } } )
    self:NetworkVar("Int", 1, "RMinY", { KeyName = "rminy", Edit = { category = "Render Bounds", title = "Y Min", type = "Int", order = 2, min = -1000, max = 1000 } } )
    self:NetworkVar("Int", 2, "RMinZ", { KeyName = "rminz", Edit = { category = "Render Bounds", title = "Z Min", type = "Int", order = 3, min = -1000, max = 1000 } } )
    self:NetworkVar("Int", 3, "RMaxX", { KeyName = "rmaxx", Edit = { category = "Render Bounds", title = "X Max", type = "Int", order = 4, min = -1000, max = 1000 } } )
    self:NetworkVar("Int", 4, "RMaxY", { KeyName = "rmaxy", Edit = { category = "Render Bounds", title = "Y Max", type = "Int", order = 5, min = -1000, max = 1000 } } )
    self:NetworkVar("Int", 5, "RMaxZ", { KeyName = "rmaxz", Edit = { category = "Render Bounds", title = "Z Max", type = "Int", order = 6, min = -1000, max = 1000 } } )

    if CLIENT then
        self:NetworkVarNotify("RMinX", self.OnRMinXChanged)
        self:NetworkVarNotify("RMinY", self.OnRMinYChanged)
        self:NetworkVarNotify("RMinZ", self.OnRMinZChanged)
        self:NetworkVarNotify("RMaxX", self.OnRMaxXChanged)
        self:NetworkVarNotify("RMaxY", self.OnRMaxYChanged)
        self:NetworkVarNotify("RMaxZ", self.OnRMaxZChanged)
    end
end

if CLIENT then
    function ENT:OnRMinXChanged(varname, oldvalue, newvalue)
        local min, max = self:GetRenderBounds()
        min.x = newvalue
        self:SetRenderBounds(min, max)
        self.boxtime = CurTime()
    end
    function ENT:OnRMinYChanged(varname, oldvalue, newvalue)
        local min, max = self:GetRenderBounds()
        min.y = newvalue
        self:SetRenderBounds(min, max)
        self.boxtime = CurTime()
    end
    function ENT:OnRMinZChanged(varname, oldvalue, newvalue)
        local min, max = self:GetRenderBounds()
        min.z = newvalue
        self:SetRenderBounds(min, max)
        self.boxtime = CurTime()
    end
    function ENT:OnRMaxXChanged(varname, oldvalue, newvalue)
        local min, max = self:GetRenderBounds()
        max.x = newvalue
        self:SetRenderBounds(min, max)
        self.boxtime = CurTime()
    end
    function ENT:OnRMaxYChanged(varname, oldvalue, newvalue)
        local min, max = self:GetRenderBounds()
        max.y = newvalue
        self:SetRenderBounds(min, max)
        self.boxtime = CurTime()
    end
    function ENT:OnRMaxZChanged(varname, oldvalue, newvalue)
        local min, max = self:GetRenderBounds()
        max.z = newvalue
        self:SetRenderBounds(min, max)
        self.boxtime = CurTime()
    end
else
    function ENT:SetDefaultRenderBounds()
        self:SetRMinX(-100)
        self:SetRMinY(-100)
        self:SetRMinZ(-100)
        self:SetRMaxX(100)
        self:SetRMaxY(100)
        self:SetRMaxZ(100)
    end
end
