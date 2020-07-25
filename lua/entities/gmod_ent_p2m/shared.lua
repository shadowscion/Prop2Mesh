ENT.Base      = "base_anim"
ENT.PrintName = "P2M Controller"
ENT.Author    = "shadowscion"
ENT.Editable  = true
ENT.Spawnable = false
ENT.AdminOnly = false
ENT.RenderGroup = RENDERGROUP_BOTH

cleanup.Register("gmod_ent_p2m")

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
