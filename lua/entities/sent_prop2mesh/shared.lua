--[[

]]
DEFINE_BASECLASS("base_anim")

ENT.PrintName   = "sent_prop2mesh"
ENT.Author      = "shadowscion"
ENT.AdminOnly   = false
ENT.Spawnable   = true
ENT.Category    = "prop2mesh"
ENT.RenderGroup = RENDERGROUP_BOTH

cleanup.Register("sent_prop2mesh")

function ENT:SpawnFunction(ply, tr, ClassName)
	if not tr.Hit then
		return
	end

	local ent = ents.Create(ClassName)
	ent:SetModel("models/p2m/cube.mdl")
	ent:SetPos(tr.HitPos + tr.HitNormal)
	ent:Spawn()
	ent:Activate()

	return ent
end

function ENT:GetControllerCol(index)
	return self.prop2mesh_controllers[index] and self.prop2mesh_controllers[index].col
end

function ENT:GetControllerMat(index)
	return self.prop2mesh_controllers[index] and self.prop2mesh_controllers[index].mat
end

function ENT:GetControllerUVS(index)
	return self.prop2mesh_controllers[index] and self.prop2mesh_controllers[index].uvs
end

function ENT:GetControllerCRC(index)
	return self.prop2mesh_controllers[index] and self.prop2mesh_controllers[index].crc
end

function ENT:GetControllerScale(index)
	return self.prop2mesh_controllers[index] and self.prop2mesh_controllers[index].scale
end


--[[

]]
properties.Add("prop2mesh", {
	MenuLabel     = "Edit prop2mesh",
	MenuIcon      = "icon16/image_edit.png",
	PrependSpacer = true,
	Order         = 3001,

	Filter = function(self, ent, pl)
		return prop2mesh.isValid(ent) and gamemode.Call("CanProperty", pl, "prop2mesh", ent)
	end,

	Action = function(self, ent) -- CLIENT
		if not self:Filter(ent, LocalPlayer()) then
			if IsValid(prop2mesh.editor) then
				prop2mesh.editor:Remove()
			end
			return
		end
		if not IsValid(prop2mesh.editor) then
			prop2mesh.editor = g_ContextMenu:Add("prop2mesh_editor")
		elseif prop2mesh.editor.Entity == ent then
			return
		end

		local h = math.floor(ScrH() - 90)
		local w = 420

		prop2mesh.editor:SetPos(ScrW() - w - 30, ScrH() - h - 30)
		prop2mesh.editor:SetSize(w, h)
		prop2mesh.editor:SetDraggable(false)

		if IsValid(prop2mesh.editor.Entity) then
			prop2mesh.editor.Entity:RemoveCallOnRemove("prop2mesh_editor_close")
		end

		prop2mesh.editor.Entity = ent
		prop2mesh.editor.Entity:CallOnRemove("prop2mesh_editor_close", function()
			prop2mesh.editor:Remove()
		end)

		prop2mesh.editor:SetTitle(tostring(prop2mesh.editor.Entity))
		prop2mesh.editor:RemakeTree()
	end,

	Receive = function(self, len, pl) -- SERVER
	end
})
