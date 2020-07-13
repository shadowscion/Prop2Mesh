--[[
    Prop To Mesh Tool
    by shadowscion
]]--

TOOL.Category   = "Render"
TOOL.Name       = "#tool.gmod_tool_p2m.listname"
TOOL.Command    = nil
TOOL.ConfigName = ""

TOOL.ClientConVar = {
    ["radius"] = 64,
    ["visclips"] = 1,
}


---------------------------------------------------------------
-- Server/Shared
if SERVER then
    TOOL.Controller = NULL
    TOOL.CookieJar = {}
end


-- TOOL: Make sure we can use the entity
local function IsPropOwner(ply, ent, singleplayer)
    if singleplayer then return true end
    if CPPI then return ent:CPPIGetOwner() == ply end

    for k, v in pairs(g_SBoxObjects) do
        for b, j in pairs(v) do
            for _, e in pairs(j) do
                if e == ent and k == ply:UniqueID() then return true end
            end
        end
    end

    return false
end

function TOOL:CanManipulateNoTrace(ply, ent, world)
    if not ply then return false end

    if ent:IsWorld() then return world end
    if string.find(ent:GetClass(), "npc_") or ent:GetClass() == "player" or ent:GetClass() == "prop_ragdoll" then return false end
    if not IsPropOwner(ply, ent, game.SinglePlayer()) then return false end

    return true
end

function TOOL:CanManipulate(ply, trace, world)
    if not ply then return false end
    if not trace.Hit then return false end
    if not trace.Entity then return false end

    if trace.Entity:IsWorld() then return world end
    if string.find(trace.Entity:GetClass(), "npc_") or trace.Entity:GetClass() == "player" or trace.Entity:GetClass() == "prop_ragdoll" then return false end
    if not IsPropOwner(ply, trace.Entity, game.SinglePlayer()) then return false end

    return true
end


-- TOOL: Add entity to tool selection
local colors = {
    [1] = Color(0, 0, 255, 200),
    [2] = Color(231, 75, 60, 200),
}

function TOOL:OnKeyPropRemove(e)
    self.Controller = NULL
    self:DeselectAllEntities()
    self:SetStage(0)
end

function TOOL:SelectEntity(ent, notify)
    if self.CookieJar[ent] then return false end

    self.CookieJar[ent] = {
        Color = ent:GetColor(),
        Mode = ent:GetRenderMode(),
    }

    ent:SetColor(table.Count(self.CookieJar) == 1 and colors[1] or colors[2])
    ent:SetRenderMode(RENDERMODE_TRANSALPHA)

    ent:CallOnRemove("p2m_selected", function(e)
        if self.Controller == e then
            self:OnKeyPropRemove(e)
            return
        end

        self.CookieJar[e] = nil
    end)

    return true
end


-- TOOL: Remove entity from tool selection
function TOOL:DeselectEntity(ent, notify)
    if not self.CookieJar[ent] then return false end
    if not IsValid(ent) then self.CookieJar[ent] = nil return false end

    ent:SetColor(self.CookieJar[ent].Color)
    ent:SetRenderMode(self.CookieJar[ent].Mode)
    ent:RemoveCallOnRemove("p2m_selected")

    self.CookieJar[ent] = nil

    return true
end


-- TOOL: Remove all entities from tool selection
function TOOL:DeselectAllEntities()
    for ent, _ in pairs(self.CookieJar) do
        self:DeselectEntity(ent)
    end
    self.Controller = NULL
    self.CookieJar = {}
end


-- TOOL: Left Click - Spawning controller
function TOOL:LeftClick(trace)
    if CLIENT then return true end
    if self:GetStage() ~= 0 then return false end
    if not self:CanManipulate(self:GetOwner(), trace, true) then return false end

    if trace.Entity:GetClass() == "gmod_ent_p2m" then
        return true
    end

    local create_new = ents.Create("gmod_ent_p2m")

    create_new:SetPos(trace.HitPos)
    create_new:SetAngles(trace.HitNormal:Angle() + Angle(90, 0, 0))
    create_new:Spawn()
    create_new:Activate()

    create_new:SetNetworkedInt("ownerid", self:GetOwner():UserID())
    create_new:SetDefaultRenderBounds()

    self:GetOwner():AddCount("gmod_ent_p2m", create_new)
    self:GetOwner():AddCleanup("gmod_ent_p2m", create_new)
    self:GetOwner():ChatPrint("You can edit this mesh base using the context menu (hold C and right click it).")

    undo.Create("gmod_ent_p2m")
        undo.AddEntity(create_new)
        undo.SetPlayer(self:GetOwner())
    undo.Finish()

    create_new:SetCollisionGroup(COLLISION_GROUP_NONE)

    return true
end


-- TOOL: Right Click - Select entities
function TOOL:RightClick(trace)
    if CLIENT then return true end
    if not self:CanManipulate(self:GetOwner(), trace, false) then return false end

    local doRadius = self:GetOwner():KeyDown(IN_SPEED)

    if not doRadius and self.CookieJar[trace.Entity] then
        if self.Controller == trace.Entity then
            if table.Count(self.CookieJar) <= 1 then
                self:GetOwner():ChatPrint("You must select at least one prop!")
                return false
            else
                local tbl = table.GetKeys(self.CookieJar)
                table.RemoveByValue(tbl, self.Controller)
                self.Controller:BuildFromTable(tbl)
            end

            self.Controller = NULL
            self:DeselectAllEntities()
            self:SetStage(0)

            return true
        end

        self:DeselectEntity(trace.Entity, false)

        return true
    end

    if self:GetStage() == 0 then
        if trace.Entity:GetClass() ~= "gmod_ent_p2m" then
            self:GetOwner():ChatPrint("Select a mesh base first!")
            return false
        end

        self:SelectEntity(trace.Entity, false)
        self.Controller = trace.Entity
        self:SetStage(1)

        return true
    end

    if doRadius then
        local radius = math.Clamp(self:GetClientNumber("radius"), 64, 4096)
        for _, ent in pairs(ents.FindInSphere(trace.HitPos, radius)) do
            if not self:CanManipulateNoTrace(self:GetOwner(), ent, false) then
                continue
            end
            self:SelectEntity(ent, false)
        end
    else
        self:SelectEntity(trace.Entity, false)
    end

    return true
end


-- TOOL: Reload - Clearing selection or resetting controller
function TOOL:Reload(trace)
    if CLIENT then return true end
    if not trace.Hit then return false end
    if not trace.Entity then return false end

    if trace.Entity:IsWorld() then
        self:DeselectAllEntities()
        self:SetStage(0)

        return true
    end

    return false
end


---------------------------------------------------------------
-- Client
if SERVER then return end

-- TOOL: Language
language.Add("tool.gmod_tool_p2m.listname", "Prop to Mesh")
language.Add("tool.gmod_tool_p2m.name", "Prop to Mesh")
language.Add("tool.gmod_tool_p2m.desc", "Converts groups of props to a single clientside mesh.")
language.Add("Undone_gmod_ent_p2m", "Undone P2M Base")
language.Add("Cleaned_gmod_ent_p2m", "Cleaned up P2M Base")
language.Add("Cleanup_gmod_ent_p2m", "P2M Bases")

TOOL.Information = {}

local function ToolInfo(name, desc, stage)
    table.insert(TOOL.Information, { name = name, stage = stage })
    language.Add("tool.gmod_tool_p2m." .. name, desc)
end

-- left click
ToolInfo("left_1", "Spawn a new mesh base", 0)

-- Right click
ToolInfo("right_1", "Select a mesh base", 0)
ToolInfo("right_2", "Select a entities for conversion, select the mesh base again to finalize", 1)

-- Reload
ToolInfo("reload_1", "Deselect all entities", 0)

-- TOOL: CPanel
function TOOL.BuildCPanel(self)
    self.Paint = function(pnl, w, h)
        draw.RoundedBox(0, 0, 0, w, 20, Color(50, 50, 50, 255))
        draw.RoundedBox(0, 1, 1, w - 2, 18, Color(125, 125, 125, 255))
    end

    self:AddControl("Slider", {
        Label = "Radius select amount.",
        Command = "gmod_tool_p2m_radius",
        min = 0,
        max = 500,
    })

    self:AddControl("Toggle", {
        Label = "Enable visclip support.",
        Command = "gmod_tool_p2m_visclips",
    })
end

local white = Color(255, 255, 255, 255)
local black = Color(0, 0, 0, 255)

function TOOL:DrawHUD()
    local trace = LocalPlayer():GetEyeTrace()
    if not trace.Hit then return end
    if not trace.Entity or trace.Entity:IsWorld() then return end

    if trace.Entity:GetClass() == "gmod_ent_p2m" and self:GetStage() == 0 then
        if trace.Entity:GetNetworkedInt("ownerid") ~= LocalPlayer():UserID() then return end
        if trace.Entity.rebuild then return end

        local pos = trace.Entity:GetPos()
        local fade = 1 - math.min(500, pos:Distance(EyePos())) / 500

        if fade == 0 then return end

        pos = pos:ToScreen()

        white.a = 255*fade
        black.a = 255*fade

        local str = string.format("Models: %d", trace.Entity.models and #trace.Entity.models or 0)
        draw.SimpleTextOutlined(str, "DebugFixedSmall", pos.x, pos.y, white, 0, 0, 1, black)
        local str = string.format("Triangles: %d", trace.Entity.tricount or 0)
        draw.SimpleTextOutlined(str, "DebugFixedSmall", pos.x, pos.y + 16, white, 0, 0, 1, black)
    end
end
