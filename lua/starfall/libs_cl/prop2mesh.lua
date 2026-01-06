
local CheckLuaType, CheckPerms, RegisterPrivilege = SF.CheckLuaType, SF.Permissions.check, SF.Permissions.registerPrivilege
local prop2mesh = prop2mesh

local function checkOwner( ply, ent )
    if CPPI then
        local owner = ent:CPPIGetOwner() or ( ent.GetPlayer and ent:GetPlayer() )
        if owner then
            return owner == ply
        end
    end

    return true
end

local function checkValid( ply, self, action, index )
    if not checkOwner( ply, self ) or not prop2mesh.isValid( self ) then
        return false
    end
    if index and not self.prop2mesh_controllers[index] then
        SF.Throw( string.format( "controller index %d does not exist on %s!", index, tostring( self) ), 3 )
        return false
    end
    return true
end

return function( instance )
    local CheckType = instance.CheckType
    local p2m_library = instance.Libraries.p2m
    local owrap, ounwrap = instance.WrapObject, instance.UnwrapObject
    local ents_methods, wrap, unwrap = instance.Types.Entity.Methods, instance.Types.Entity.Wrap, instance.Types.Entity.Unwrap
    local ang_meta, aunwrap = instance.Types.Angle, instance.Types.Angle.Unwrap
    local vec_meta, vunwrap = instance.Types.Vector, instance.Types.Vector.Unwrap
    local col_meta, cwrap, cunwrap = instance.Types.Color, instance.Types.Color.Wrap, instance.Types.Color.Unwrap

    local recycle = prop2mesh.recycle

    --- Manually sets controller info from a table clientside. It's important to note that this does not set the controller info serverside, so any modifications made to this P2M, dupe copying, etc. will not copy the inputted info
    -- @param number index index of controller
    -- @param table controllerData controller table to insert
    function ents_methods:p2mSetControllerInfo(index, controllerData)
        CheckType(self, ents_metatable)
        local ent = unwrap(self)

        CheckLuaType(index, TYPE_NUMBER)
        if not checkValid(instance.player, ent, nil, index, true) then
            return
        end

        CheckLuaType(controllerData, TYPE_TABLE)
        controllerData = instance.Unsanitize(controllerData)

        local controller = ent.prop2mesh_controllers[index]
        local controllerDataComp = util.Compress(util.TableToJSON(controllerData))
        local dataCRC = util.CRC(controllerDataComp)
        controller.crc = dataCRC

        recycle[dataCRC] = { users = {[ent] = true}, meshes = {} }
        prop2mesh.handleDownload(dataCRC, controllerDataComp)
        prop2mesh.refresh(ent, controller)
    end
end
