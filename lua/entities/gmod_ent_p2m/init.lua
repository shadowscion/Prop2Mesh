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

local ROTATE = {}
function ROTATE:Add(mdl)
    self[string.lower(mdl)] = true
end

-- gmod folders
ROTATE:Add("models/weapons/")

-- gmod specific
ROTATE:Add("models/thrusters/jetpack.mdl")
ROTATE:Add("models/balloons/balloon_classicheart.mdl")
ROTATE:Add("models/balloons/balloon_dog.mdl")
ROTATE:Add("models/balloons/balloon_star.mdl")
ROTATE:Add("models/balloons/hot_airballoon.mdl")
ROTATE:Add("models/balloons/hot_airballoon_basket.mdl")
ROTATE:Add("models/chairs/armchair.mdl")
ROTATE:Add("models/dynamite/dynamite.mdl")
ROTATE:Add("models/food/burger.mdl")
ROTATE:Add("models/food/hotdog.mdl")
ROTATE:Add("models/props_lab/huladoll.mdl")
ROTATE:Add("models/Gibs/helicopter_brokenpiece_01.mdl")
ROTATE:Add("models/Gibs/helicopter_brokenpiece_02.mdl")
ROTATE:Add("models/Gibs/helicopter_brokenpiece_03.mdl")
ROTATE:Add("models/Gibs/helicopter_brokenpiece_04_cockpit.mdl")
ROTATE:Add("models/Gibs/helicopter_brokenpiece_05_tailfan.mdl")
ROTATE:Add("models/Gibs/helicopter_brokenpiece_06_body.mdl")
ROTATE:Add("models/props_c17/door02_double.mdl")
ROTATE:Add("models/props_c17/door01_left.mdl")
ROTATE:Add("models/props_c17/trappropeller_blade.mdl")
ROTATE:Add("models/props_combine/breenchair.mdl")
ROTATE:Add("models/props_junk/ravenholmsign.mdl")
ROTATE:Add("models/props_lab/blastdoor001a.mdl")
ROTATE:Add("models/props_lab/blastdoor001b.mdl")
ROTATE:Add("models/props_lab/blastdoor001c.mdl")
ROTATE:Add("models/props_lab/kennel_physics.mdl")
ROTATE:Add("models/props_wasteland/wood_fence01a.mdl")
ROTATE:Add("models/lamps/torch.mdl")
ROTATE:Add("models/maxofs2d/button_01.mdl")
ROTATE:Add("models/maxofs2d/button_03.mdl")
ROTATE:Add("models/maxofs2d/button_04.mdl")
ROTATE:Add("models/maxofs2d/button_06.mdl")
ROTATE:Add("models/maxofs2d/button_slider.mdl")
ROTATE:Add("models/maxofs2d/camera.mdl")
ROTATE:Add("models/maxofs2d/logo_gmod_b.mdl")

-- phx folders
ROTATE:Add("models/squad/sf_bars/")
ROTATE:Add("models/squad/sf_plates/")
ROTATE:Add("models/squad/sf_tris/")
ROTATE:Add("models/squad/sf_tubes/")
ROTATE:Add("models/props_phx/trains/tracks/")
ROTATE:Add("models/props_phx/construct/glass/")
ROTATE:Add("models/props_phx/construct/plastic/")
ROTATE:Add("models/props_phx/construct/windows/")
ROTATE:Add("models/props_phx/construct/wood/")
ROTATE:Add("models/phxtended/")
ROTATE:Add("models/props_phx/misc/")

-- phx specific
ROTATE:Add("models/quarterlife/fsd-overrun-toy.mdl")
ROTATE:Add("models/hunter/plates/plate1x3x1trap.mdl")
ROTATE:Add("models/hunter/plates/plate1x4x2trap.mdl")
ROTATE:Add("models/hunter/plates/plate1x4x2trap1.mdl")
ROTATE:Add("models/mechanics/articulating/arm_base_b.mdl")
ROTATE:Add("models/props_phx/amraam.mdl")
ROTATE:Add("models/props_phx/box_amraam.mdl")
ROTATE:Add("models/props_phx/box_torpedo.mdl")
ROTATE:Add("models/props_phx/cannon.mdl")
ROTATE:Add("models/props_phx/carseat2.mdl")
ROTATE:Add("models/props_phx/carseat3.mdl")
ROTATE:Add("models/props_phx/facepunch_logo.mdl")
ROTATE:Add("models/props_phx/mk-82.mdl")
ROTATE:Add("models/props_phx/playfield.mdl")
ROTATE:Add("models/props_phx/torpedo.mdl")
ROTATE:Add("models/props_phx/ww2bomb.mdl")
ROTATE:Add("models/props_phx/construct/metal_angle180.mdl")
ROTATE:Add("models/props_phx/construct/metal_angle90.mdl")
ROTATE:Add("models/props_phx/construct/metal_dome180.mdl")
ROTATE:Add("models/props_phx/construct/metal_dome90.mdl")
ROTATE:Add("models/props_phx/construct/metal_plate1.mdl")
ROTATE:Add("models/props_phx/construct/metal_plate1x2.mdl")
ROTATE:Add("models/props_phx/construct/metal_plate2x2.mdl")
ROTATE:Add("models/props_phx/construct/metal_plate2x4.mdl")
ROTATE:Add("models/props_phx/construct/metal_plate4x4.mdl")
ROTATE:Add("models/props_phx/construct/metal_plate_curve.mdl")
ROTATE:Add("models/props_phx/construct/metal_plate_curve180.mdl")
ROTATE:Add("models/props_phx/construct/metal_plate_curve2.mdl")
ROTATE:Add("models/props_phx/construct/metal_plate_curve2x2.mdl")
ROTATE:Add("models/props_phx/construct/metal_wire1x1x1.mdl")
ROTATE:Add("models/props_phx/construct/metal_wire1x1x2.mdl")
ROTATE:Add("models/props_phx/construct/metal_wire1x1x2b.mdl")
ROTATE:Add("models/props_phx/construct/metal_wire1x2.mdl")
ROTATE:Add("models/props_phx/construct/metal_wire1x2b.mdl")
ROTATE:Add("models/props_phx/construct/metal_wire_angle180x1.mdl")
ROTATE:Add("models/props_phx/construct/metal_wire_angle180x2.mdl")
ROTATE:Add("models/props_phx/construct/metal_wire_angle90x1.mdl")
ROTATE:Add("models/props_phx/construct/metal_wire_angle90x2.mdl")
ROTATE:Add("models/props_phx/games/chess/board.mdl")
ROTATE:Add("models/props_phx/games/chess/white_knight.mdl")
ROTATE:Add("models/props_phx/games/chess/black_knight.mdl")
ROTATE:Add("models/props_phx/games/chess/black_king.mdl")
ROTATE:Add("models/props_phx/games/chess/white_king.mdl")
ROTATE:Add("models/props_phx/gears/spur9.mdl")
ROTATE:Add("models/props_phx/gears/rack18.mdl")
ROTATE:Add("models/props_phx/gears/rack36.mdl")
ROTATE:Add("models/props_phx/gears/rack70.mdl")
ROTATE:Add("models/props_phx/gears/rack9.mdl")
ROTATE:Add("models/props_phx/gears/bevel9.mdl")
ROTATE:Add("models/props_phx/huge/road_curve.mdl")
ROTATE:Add("models/props_phx/huge/road_long.mdl")
ROTATE:Add("models/props_phx/huge/road_medium.mdl")
ROTATE:Add("models/props_phx/huge/road_short.mdl")
ROTATE:Add("models/props_phx/mechanics/slider1.mdl")
ROTATE:Add("models/props_phx/mechanics/slider2.mdl")
ROTATE:Add("models/props_phx/trains/double_wheels_base.mdl")
ROTATE:Add("models/props_phx/trains/fsd-overrun.mdl")
ROTATE:Add("models/props_phx/trains/fsd-overrun2.mdl")
ROTATE:Add("models/props_phx/trains/monorail1.mdl")
ROTATE:Add("models/props_phx/trains/monorail_curve.mdl")
ROTATE:Add("models/props_phx/trains/wheel_base.mdl")
ROTATE:Add("models/props_phx/wheels/magnetic_small_base.mdl")
ROTATE:Add("models/props_phx/wheels/magnetic_large_base.mdl")
ROTATE:Add("models/props_phx/wheels/magnetic_med_base.mdl")
ROTATE:Add("models/props_phx/wheels/breakable_tire.mdl")

function ENT:BuildFromTable(tbl)
    duplicator.ClearEntityModifier(self, "p2m_packets")
    local function get()
        local ret = {}
        for _, ent in ipairs(tbl) do
            if not IsValid(ent) then
                continue
            end

            ent:SetPos(ent:GetPos())
            ent:SetAngles(ent:GetAngles())
            ent:GetPhysicsObject():EnableMotion(false)
            ent:PhysWake()

            local data = {}
            data.pos, data.ang = WorldToLocal(ent:GetPos(), ent:GetAngles(), self:GetPos(), self:GetAngles())
            data.mdl = ent:GetModel()

            local rotated = ROTATE[data.mdl]
            if not rotated then
                rotated = ROTATE[string.GetPathFromFilename(data.mdl)]
            end
            if rotated then
                data.ang:RotateAroundAxis(data.ang:Up(), 90)
            end

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
                    if rotated then
                        local v1, a1 = WorldToLocal(Vector(), ent:LocalToWorldAngles(clip.n), ent:GetPos(), ent:LocalToWorldAngles(Angle(0, 90, 0)))
                        table.insert(data.clips, { n = a1:Forward(), d = clip.d + a1:Forward():Dot(ent:OBBCenter()) })
                    else
                        table.insert(data.clips, { n = clip.n:Forward(), d = clip.d + clip.n:Forward():Dot(ent:OBBCenter())  })
                    end
                end
            end

            -- ent:SetPos(ent:GetPos())
            -- ent:SetAngles(ent:GetAngles())
            -- ent:GetPhysicsObject():EnableMotion( false )

            -- local eang = ent:GetAngles()
            -- local bang = ent:GetBoneMatrix(0):GetAngles()
            -- bang:Normalize()

            -- print(eang, bang)

            -- local rotated
            -- if math.Round(eang.y, 2) ~= math.Round(bang.y, 2) then
            --     --eang:RotateAroundAxis(eang:Up(), 90)
            --     --rotated = true
            -- end

            -- local data = {}
            -- data.pos = self:WorldToLocal(ent:GetPos())
            -- data.ang = self:WorldToLocalAngles(eang)
            -- data.mdl = ent:GetModel()

            -- local clips = ent.ClipData
            -- if clips then
            --     for _, clip in ipairs(clips) do
            --         if clip.inside then
            --             continue
            --         end
            --         data.clips = data.clips or {}
            --         if rotated then
            --             local v1, a1 = WorldToLocal(Vector(), ent:LocalToWorldAngles(clip.n), ent:GetPos(), eang)
            --             table.insert(data.clips, { n = a1:Forward(), d = clip.d + a1:Forward():Dot(ent:OBBCenter()) })
            --         else
            --             table.insert(data.clips, { n = clip.n:Forward(), d = clip.d + clip.n:Forward():Dot(ent:OBBCenter())  })
            --         end
            --     end
            -- end

            -- local scale = ent:GetManipulateBoneScale(0)
            -- if scale.x ~= 1 or scale.y ~= 1 or scale.z ~= 1 then
            --     data.scale = scale
            -- end

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
