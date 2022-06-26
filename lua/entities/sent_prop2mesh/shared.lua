--[[

]]
DEFINE_BASECLASS("base_anim")

ENT.PrintName   = "sent_prop2mesh"
ENT.Author      = "shadowscion"
ENT.AdminOnly   = false
ENT.RenderGroup = RENDERGROUP_BOTH

cleanup.Register("sent_prop2mesh")

if SERVER then
	util.AddNetworkString("prop2mesh_export")
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
		if not IsValid(ent) then return false end
		if not gamemode.Call("CanProperty", pl, "prop2mesh", ent) then return false end
		if prop2mesh.isValid(ent) then
			return next(ent.prop2mesh_controllers) ~= nil
		end
		return ent:GetClass() == "gmod_wire_expression2" and ent:GetNW2Bool("has_prop2mesh")
	end,

	Action = function(self, ent) -- CLIENT
		if ent:GetClass() == "gmod_wire_expression2" then
			self:RequestExport(ent, 1)
			return
		end

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
		prop2mesh.editor:RequestSetEntity(ent)
	end,

	Receive = function(self, len, pl) -- SERVER
		local ent = net.ReadEntity()
		local type = net.ReadUInt(8)

		if not self:Filter(ent, pl) then return end
		if type ~= 1 and type ~= 2 then return end

		local ret
		if ent:GetClass() == "gmod_wire_expression2" then
			ret = {}
			for k in pairs(ent.context.data.prop2mesh) do
				if next(k.prop2mesh_controllers) ~= nil then
					table.insert(ret, k)
				end
			end
		else
			ret = {ent}
		end

		if next(ret) then
			net.Start("prop2mesh_export")
			net.WriteUInt(type, 8)
			net.WriteUInt(#ret, 32)
			for i = 1, #ret do
				net.WriteUInt(ret[i]:EntIndex(), 32)
			end
			net.Send(pl)
		end
	end,

	RequestExport = function(self, ent, type)
		self:MsgStart()
		net.WriteEntity(ent)
		net.WriteUInt(type or 1, 8) // 1 == export obj, 2 == export e2
		self:MsgEnd()
	end,

	MenuOpen = function(self, option, ent, tr)
		if ent:GetClass() ~= "gmod_wire_expression2" then
			option.m_Image:SetImage("icon16/image_edit.png")
			option.m_Image:SetImageColor(Color(255, 255, 255))
			option:SetText("Edit prop2mesh")

			--[[
			local submenu = option:AddSubMenu()

			submenu:AddOption("Export all as .obj", function()
				self:RequestExport(ent, 1)
			end):SetImage("icon16/car.png")

			local opt, sub = submenu:AddOption("Export all to E2", function()
				self:RequestExport(ent, 2)
			end)

			opt:SetImage("icon16/cog.png")
			opt.m_Image:SetImageColor(Color(255, 125, 125))
			]]

			return
		end

		option.m_Image:SetImage("icon16/cog.png")
		option.m_Image:SetImageColor(Color(255, 125, 125))
		option:SetText("Export all E2M as .obj")
	end,
})
