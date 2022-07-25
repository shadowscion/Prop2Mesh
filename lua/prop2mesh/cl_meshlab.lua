--[[

]]
local prop2mesh = prop2mesh

local util = util
local string = string
local coroutine = coroutine
local notification = notification

local next = next
local SysTime = SysTime
local tonumber = tonumber

local Vector = Vector
local vec = Vector()
local div = vec.Div
local mul = vec.Mul
local add = vec.Add
local dot = vec.Dot
local cross = vec.Cross
local normalize = vec.Normalize
local rotate = vec.Rotate

local math_cos = math.cos
local math_rad = math.rad
local math_abs = math.abs
local math_min = math.min
local math_max = math.max

local string_format = string.format
local string_explode = string.Explode
local string_gsub = string.gsub
local string_trim = string.Trim
local table_concat = table.concat
local table_remove = table.remove

local a90 = Angle(0, -90, 0)

local cvar = CreateClientConVar("prop2mesh_render_disable_obj", 0, true, false)
local disable_obj = cvar:GetBool()

cvars.AddChangeCallback("prop2mesh_render_disable_obj", function(cvar, old, new)
    disable_obj = tobool(new)
end, "swapdrawdisable_obj")


--[[

]]
local function calcbounds(min, max, pos)
	if pos.x < min.x then min.x = pos.x elseif pos.x > max.x then max.x = pos.x end
	if pos.y < min.y then min.y = pos.y elseif pos.y > max.y then max.y = pos.y end
	if pos.z < min.z then min.z = pos.z elseif pos.z > max.z then max.z = pos.z end
end

local function copy(v)
	return {
		pos    = Vector(v.pos),
		normal = Vector(v.normal),
		u      = v.u,
		v      = v.v,
		rotate = v.rotate,
	}
end

local function sign(n)
	if n == 0 then
		return 0
	else
		return n > 0 and 1 or -1
	end
end

local function getBoxDir(vec)
	local x, y, z = math_abs(vec.x), math_abs(vec.y), math_abs(vec.z)
	if x > y and x > z then
		return vec.x < -0 and -1 or 1
	elseif y > z then
		return vec.y < 0 and -2 or 2
	end
	return vec.z < 0 and -3 or 3
end

local function getBoxUV(vert, dir, scale)
	if dir == -1 or dir == 1 then
		return vert.z * sign(dir) * scale, vert.y * scale
	elseif dir == -2 or dir == 2 then
		return vert.x * scale, vert.z * sign(dir) * scale
	else
		return vert.x * -sign(dir) * scale, vert.y * scale
	end
end

local function clip(v1, v2, plane, length, getUV)
	local d1 = dot(v1.pos, plane) - length
	local d2 = dot(v2.pos, plane) - length
	local t  = d1 / (d1 - d2)
	local vert = {
		pos    = v1.pos + t * (v2.pos - v1.pos),
		normal = v1.normal + t * (v2.normal - v1.normal),
		rotate = v1.rotate or v2.rotate,
	}
	if getUV then
		vert.u = v1.u + t * (v2.u - v1.u)
		vert.v = v1.v + t * (v2.v - v1.v)
	end
	return vert
end

-- method https:--github.com/chenchenyuyu/DEMO/blob/b6bf971a302c71403e0e34e091402982dfa3cd2d/app/src/pages/vr/decal/decalGeometry.js#L102
local function applyClippingPlane(verts, plane, length, getUV)
	local temp = {}
	for i = 1, #verts, 3 do
		local d1 = length - dot(verts[i + 0].pos, plane)
		local d2 = length - dot(verts[i + 1].pos, plane)
		local d3 = length - dot(verts[i + 2].pos, plane)

		local ov1 = d1 > 0
		local ov2 = d2 > 0
		local ov3 = d3 > 0

		local total = (ov1 and 1 or 0) + (ov2 and 1 or 0) + (ov3 and 1 or 0)

		local nv1, nv2, nv3, nv4

		if total == 0 then
			temp[#temp + 1] = verts[i + 0]
			temp[#temp + 1] = verts[i + 1]
			temp[#temp + 1] = verts[i + 2]
		elseif total == 1 then
			if ov1 then
				nv1 = verts[i + 1]
				nv2 = verts[i + 2]
				nv3 = clip(verts[i + 0], nv1, plane, length, getUV)
				nv4 = clip(verts[i + 0], nv2, plane, length, getUV)

				temp[#temp + 1] = copy(nv1)
				temp[#temp + 1] = copy(nv2)
				temp[#temp + 1] = nv3
				temp[#temp + 1] = nv4
				temp[#temp + 1] = copy(nv3)
				temp[#temp + 1] = copy(nv2)
			elseif ov2 then
				nv1 = verts[i + 0]
				nv2 = verts[i + 2]
				nv3 = clip(verts[i + 1], nv1, plane, length, getUV)
				nv4 = clip(verts[i + 1], nv2, plane, length, getUV)

				temp[#temp + 1] = nv3
				temp[#temp + 1] = copy(nv2)
				temp[#temp + 1] = copy(nv1)
				temp[#temp + 1] = copy(nv2)
				temp[#temp + 1] = copy(nv3)
				temp[#temp + 1] = nv4
			elseif ov3 then
				nv1 = verts[i + 0]
				nv2 = verts[i + 1]
				nv3 = clip(verts[i + 2], nv1, plane, length, getUV)
				nv4 = clip(verts[i + 2], nv2, plane, length, getUV)

				temp[#temp + 1] = copy(nv1)
				temp[#temp + 1] = copy(nv2)
				temp[#temp + 1] = nv3
				temp[#temp + 1] = nv4
				temp[#temp + 1] = copy(nv3)
				temp[#temp + 1] = copy(nv2)
			end
		elseif total == 2 then
			if not ov1 then
				nv1 = copy(verts[i + 0])
				nv2 = clip(nv1, verts[i + 1], plane, length, getUV)
				nv3 = clip(nv1, verts[i + 2], plane, length, getUV)

				temp[#temp + 1] = nv1
				temp[#temp + 1] = nv2
				temp[#temp + 1] = nv3
			elseif not ov2 then
				nv1 = copy(verts[i + 1])
				nv2 = clip(nv1, verts[i + 2], plane, length, getUV)
				nv3 = clip(nv1, verts[i + 0], plane, length, getUV)

				temp[#temp + 1] = nv1
				temp[#temp + 1] = nv2
				temp[#temp + 1] = nv3
			elseif not ov3 then
				nv1 = copy(verts[i + 2])
				nv2 = clip(nv1, verts[i + 0], plane, length, getUV)
				nv3 = clip(nv1, verts[i + 1], plane, length, getUV)

				temp[#temp + 1] = nv1
				temp[#temp + 1] = nv2
				temp[#temp + 1] = nv3
			end
		end
	end
	return temp
end


--[[

]]
local function getVertsFromPrimitive(partnext, meshtex, vmins, vmaxs, direct)
    partnext.primitive.skip_bounds = true
    partnext.primitive.skip_tangents = true
    partnext.primitive.skip_inside = true
    partnext.primitive.skip_invert = true
    partnext.primitive.skip_uv = meshtex and true

	if partnext.vsmooth == 1 and partnext.primitive then
		partnext.primitive.skip_normals = true
	end

	local _, submeshes = prop2mesh.primitive.construct.get(partnext.primitive.construct, partnext.primitive, false, false)
	submeshes = submeshes and submeshes.tris

	if not submeshes then
		return
	end

	local partpos = partnext.pos
	local partang = partnext.ang
	local partscale = partnext.scale
	local partclips = partnext.clips

	local partverts = {}
	local modeluv = not meshtex

	local submeshdata  = submeshes
	local submeshverts = {}

	for vertid = 1, #submeshdata do
		local vert   = submeshdata[vertid]
		local pos    = Vector(vert.pos)
		local normal = Vector(vert.normal)

		if partscale then
			pos.x = pos.x * partscale.x
			pos.y = pos.y * partscale.y
			pos.z = pos.z * partscale.z
		end

		local vcopy = {
			pos    = pos,
			normal = normal,
			rotate = submeshfix,
		}

		if modeluv then
			vcopy.u = vert.u
			vcopy.v = vert.v
		end

		submeshverts[#submeshverts + 1] = vcopy
	end

	if partclips then
		for clipid = 1, #partclips do
			submeshverts = applyClippingPlane(submeshverts, partclips[clipid].n, partclips[clipid].d, modeluv)
		end
	end

	for vertid = 1, #submeshverts do
		local vert = submeshverts[vertid]
		if vert.rotate then
			rotate(vert.normal, vert.rotate.ang or partang)
			rotate(vert.pos, vert.rotate.ang or partang)
			vert.rotate = nil
		else
			rotate(vert.normal, partang)
			rotate(vert.pos, partang)
		end
		add(vert.pos, partpos)
		partverts[#partverts + 1] = vert
		calcbounds(vmins, vmaxs, vert.pos)
	end

	if #partverts == 0 then
		return
	end

	local nflat = partnext.vsmooth == 1
	if meshtex or nflat then
		for pv = 1, #partverts, 3 do
			local normal = cross(partverts[pv + 2].pos - partverts[pv].pos, partverts[pv + 1].pos - partverts[pv].pos)
			normalize(normal)

			if nflat then
				partverts[pv    ].normal = Vector(normal)
				partverts[pv + 1].normal = Vector(normal)
				partverts[pv + 2].normal = Vector(normal)
			end

			if meshtex then
				local boxDir = getBoxDir(normal)
				partverts[pv    ].u, partverts[pv    ].v = getBoxUV(partverts[pv    ].pos, boxDir, meshtex)
				partverts[pv + 1].u, partverts[pv + 1].v = getBoxUV(partverts[pv + 1].pos, boxDir, meshtex)
				partverts[pv + 2].u, partverts[pv + 2].v = getBoxUV(partverts[pv + 2].pos, boxDir, meshtex)
			end
		end
	end

	return partverts
end


local meshmodelcache
local function getVertsFromMDL(partnext, meshtex, vmins, vmaxs, direct)
	local modelpath = partnext.prop or partnext.holo
	if prop2mesh.isBlockedModel(modelpath) then
		return
	end

	local submeshes
	if meshmodelcache[modelpath] then
		submeshes = meshmodelcache[modelpath][partnext.bodygroup or 0]
	else
		meshmodelcache[modelpath] = {}
	end
	if not submeshes then
		submeshes = util.GetModelMeshes(modelpath, 0, partnext.bodygroup or 0)
		if not submeshes then
			return
		end
		submeshes.modelfixer = prop2mesh.getModelFix(modelpath)
		submeshes.modelfixergeneric = isbool(submeshes.modelfixer)
		meshmodelcache[modelpath][partnext.bodygroup or 0] = submeshes
	end

	local partpos = partnext.pos
	local partang = partnext.ang
	local partscale = partnext.scale
	local partclips = partnext.clips
	--local partsubmodels = partnext.submodels

	local submeshfixlookup
	if submeshes.modelfixer then
		local rotated = Angle(partang)
		rotated:RotateAroundAxis(rotated:Up(), 90)

		submeshfixlookup = {}
		for submeshid = 1, #submeshes do
			if submeshes.modelfixergeneric then
				submeshfixlookup[submeshid] = { ang = rotated }
			else
				local ang = submeshes.modelfixer(submeshid, #submeshes, rotated, partang) or rotated
				submeshfixlookup[submeshid] = { ang = ang, diff = ang ~= rotated }
			end
		end

		if partscale then
			if partnext.holo then
				partscale = Vector(partscale.y, partscale.x, partscale.z)
			else
				partscale = Vector(partscale.x, partscale.z, partscale.y)
			end
		end

		if partclips then
			local clips = {}
			for clipid = 1, #partclips do
				local normal = Vector(partclips[clipid].n)
				rotate(normal, a90)
				clips[#clips + 1] = {
					d  = partclips[clipid].d,
					no = partclips[clipid].n,
					n  = normal,
				}
			end
			partclips = clips
		end
	end

	local partverts = {}
	local modeluv = not meshtex

	local submodels_whitelist, submodels_blacklist
	if partnext.submodels then
		if partnext.submodelswl then
			submodels_whitelist = partnext.submodels
		else
			submodels_blacklist = partnext.submodels
		end
	end

	for submeshid = 1, #submeshes do
		if submodels_blacklist then
			if submodels_blacklist[submeshid] then
				goto CONTINUE
			end
		elseif submodels_whitelist then
			if not submodels_whitelist[submeshid] then
				goto CONTINUE
			end
		end

		local submeshdata   = submeshes[submeshid].triangles
		local submeshfix    = submeshfixlookup and submeshfixlookup[submeshid]
		local submeshverts  = {}

		for vertid = 1, #submeshdata do
			local vert   = submeshdata[vertid]
			local pos    = Vector(vert.pos)
			local normal = Vector(vert.normal)

			if partscale then
				if submeshfix and submeshfix.diff then
					pos.x = pos.x * partnext.scale.x
					pos.y = pos.y * partnext.scale.y
					pos.z = pos.z * partnext.scale.z
				else
					pos.x = pos.x * partscale.x
					pos.y = pos.y * partscale.y
					pos.z = pos.z * partscale.z
				end
			end

			local vcopy = {
				pos    = pos,
				normal = normal,
				rotate = submeshfix,
			}

			if modeluv then
				vcopy.u = vert.u
				vcopy.v = vert.v
			end

			submeshverts[#submeshverts + 1] = vcopy
		end

		if partclips then
			if submeshfix then
				for clipid = 1, #partclips do
					submeshverts = applyClippingPlane(submeshverts, submeshfix.diff and partclips[clipid].no or partclips[clipid].n, partclips[clipid].d, modeluv)
				end
			else
				for clipid = 1, #partclips do
					submeshverts = applyClippingPlane(submeshverts, partclips[clipid].n, partclips[clipid].d, modeluv)
				end
			end
		end

		for vertid = 1, #submeshverts do
			local vert = submeshverts[vertid]
			if vert.rotate then
				rotate(vert.normal, vert.rotate.ang or partang)
				rotate(vert.pos, vert.rotate.ang or partang)
				vert.rotate = nil
			else
				rotate(vert.normal, partang)
				rotate(vert.pos, partang)
			end
			add(vert.pos, partpos)
			partverts[#partverts + 1] = vert
			calcbounds(vmins, vmaxs, vert.pos)
		end

		::CONTINUE::
	end

	if #partverts == 0 then
		return
	end

	local nflat = partnext.vsmooth == 1
	if meshtex or nflat then
		for pv = 1, #partverts, 3 do
			local normal = cross(partverts[pv + 2].pos - partverts[pv].pos, partverts[pv + 1].pos - partverts[pv].pos)
			normalize(normal)

			if nflat then
				partverts[pv    ].normal = Vector(normal)
				partverts[pv + 1].normal = Vector(normal)
				partverts[pv + 2].normal = Vector(normal)
			end

			if meshtex then
				local boxDir = getBoxDir(normal)
				partverts[pv    ].u, partverts[pv    ].v = getBoxUV(partverts[pv    ].pos, boxDir, meshtex)
				partverts[pv + 1].u, partverts[pv + 1].v = getBoxUV(partverts[pv + 1].pos, boxDir, meshtex)
				partverts[pv + 2].u, partverts[pv + 2].v = getBoxUV(partverts[pv + 2].pos, boxDir, meshtex)
			end
		end
	end

	return partverts
end

local function getFallbackOBJ(custom, partnext, meshtex, vmins, vmaxs, direct)
	local modeluid = tonumber(partnext.objd)
	local modelobj = custom[modeluid]

	if not modelobj then
		return
	end

	local omins, omaxs = Vector(), Vector()

	local pos = partnext.pos
	local ang = partnext.ang
	local scale = partnext.scale

	if scale then
		if scale.x == 1 and scale.y == 1 and scale.z == 1 then scale = nil end
	end

	for line in string.gmatch(modelobj, "(.-)\n") do
		local temp = string_explode(" ", string_gsub(string_trim(line), "%s+", " "))
		local head = table_remove(temp, 1)

		if head == "v" then
			local vert = Vector(tonumber(temp[1]), tonumber(temp[2]), tonumber(temp[3]))
			if scale then
				vert.x = vert.x * scale.x
				vert.y = vert.y * scale.y
				vert.z = vert.z * scale.z
			end
			calcbounds(omins, omaxs, vert)
		end
	end

	pos = (omins + omaxs)*0.5
	ang = ang or Angle()

	return getVertsFromMDL({ang	= ang, pos	= pos, prop = "models/hunter/blocks/cube025x025x025.mdl", scale = (omaxs - omins)/12}, meshtex, vmins, vmaxs, direct)
end

local function getVertsFromOBJ(custom, partnext, meshtex, vmins, vmaxs, direct)
	if disable_obj then
		return getFallbackOBJ(custom, partnext, meshtex, vmins, vmaxs, direct)
	end

	local modeluid = tonumber(partnext.objd)
	local modelobj = custom[modeluid]

	if not modelobj then
		return
	end

	local pos = partnext.pos
	local ang = partnext.ang
	local scale = partnext.scale

	if pos.x == 0 and pos.y == 0 and pos.z == 0 then pos = nil end
	if ang.p == 0 and ang.y == 0 and ang.r == 0 then ang = nil end
	if scale then
		if scale.x == 1 and scale.y == 1 and scale.z == 1 then scale = nil end
	end

	local vlook = {}
	local vmesh = {}

	local meshtex = meshtex or 1 / 48
	local invert = partnext.vinvert
	local smooth = partnext.vsmooth

	for line in string.gmatch(modelobj, "(.-)\n") do
		local temp = string_explode(" ", string_gsub(string_trim(line), "%s+", " "))
		local head = table_remove(temp, 1)

		if head == "f" then
			local f1 = string_explode("/", temp[1])
			local f2 = string_explode("/", temp[2])

			for i = 3, #temp do
				local f3 = string_explode("/", temp[i])

				local v1, v2, v3

				if invert then
					v1 = { pos = Vector(vlook[tonumber(f3[1])]) }
					v2 = { pos = Vector(vlook[tonumber(f2[1])]) }
					v3 = { pos = Vector(vlook[tonumber(f1[1])]) }
				else
					v1 = { pos = Vector(vlook[tonumber(f1[1])]) }
					v2 = { pos = Vector(vlook[tonumber(f2[1])]) }
					v3 = { pos = Vector(vlook[tonumber(f3[1])]) }
				end

				local normal = cross(v3.pos - v1.pos, v2.pos - v1.pos)
				normalize(normal)

				v1.normal = Vector(normal)
				v2.normal = Vector(normal)
				v3.normal = Vector(normal)

				local boxDir = getBoxDir(normal)
				v1.u, v1.v = getBoxUV(v1.pos, boxDir, meshtex)
				v2.u, v2.v = getBoxUV(v2.pos, boxDir, meshtex)
				v3.u, v3.v = getBoxUV(v3.pos, boxDir, meshtex)

				vmesh[#vmesh + 1] = v1
				vmesh[#vmesh + 1] = v2
				vmesh[#vmesh + 1] = v3

				f2 = f3
			end
		end
		if head == "v" then
			local vert = Vector(tonumber(temp[1]), tonumber(temp[2]), tonumber(temp[3]))
			if scale then
				vert.x = vert.x * scale.x
				vert.y = vert.y * scale.y
				vert.z = vert.z * scale.z
			end
			if ang then
				rotate(vert, ang)
			end
			if pos then
				add(vert, pos)
			end
			vlook[#vlook + 1] = vert
			calcbounds(vmins, vmaxs, vert)
		end

		if not direct then coroutine.yield(false) end
	end

	-- https:--github.com/thegrb93/StarfallEx/blob/b6de9fbe84040e9ebebcbe858c30adb9f7d937b5/lua/starfall/libs_sh/mesh.lua#L229
	-- credit to Sevii
	if smooth and smooth ~= 0 then
		local smoothrad = math_cos(math_rad(smooth))
		if smoothrad ~= 1 then
			local norms = setmetatable({},{__index = function(t,k) local r=setmetatable({},{__index=function(t,k) local r=setmetatable({},{__index=function(t,k) local r={} t[k]=r return r end}) t[k]=r return r end}) t[k]=r return r end})
			for _, vertex in ipairs(vmesh) do
				local pos = vertex.pos
				local norm = norms[pos[1]][pos[2]][pos[3]]
				norm[#norm+1] = vertex.normal
			end

			for _, vertex in ipairs(vmesh) do
				local normal = Vector()
				local count = 0
				local pos = vertex.pos

				for _, norm in ipairs(norms[pos[1]][pos[2]][pos[3]]) do
					if dot(vertex.normal, norm) >= smoothrad then
						add(normal, norm)
						count = count + 1
					end
				end

				if count > 1 then
					div(normal, count)
					vertex.normal = normal
				end
			end
		end
	end

	return #vmesh > 0 and vmesh
end


--[[

]]
local function getMeshFromData(data, uvs, direct, split)
	if not data or not uvs then
		if not direct then coroutine.yield(true) else return end
	end
	local partlist = util.JSONToTable(util.Decompress(data))
	if not partlist then
		if not direct then coroutine.yield(true) else return end
	end

	prop2mesh.loadModelFixer()
	if not meshmodelcache then
		meshmodelcache = {}
	end

	local meshpcount = 0
	local meshvcount = 0
	local vmins = Vector()
	local vmaxs = Vector()
	local meshtex = (uvs and uvs ~= 0) and (1 / uvs) or nil

	local meshlist = { {} }
	local meshnext = meshlist[1]

	local partcount = #partlist

	for partid = 1, partcount do
		local partnext = partlist[partid]
		local partverts

		if partnext.prop or partnext.holo then
			partverts = getVertsFromMDL(partnext, meshtex, vmins, vmaxs, direct)
		elseif partnext.objd and partlist.custom then
			local valid, opv = pcall(getVertsFromOBJ, partlist.custom, partnext, meshtex, vmins, vmaxs, direct)
			if valid and opv then
				partverts = opv
			else
				print(opv)
			end
		elseif partnext.primitive then
			local valid, opv = pcall(getVertsFromPrimitive, partnext, meshtex, vmins, vmaxs, direct)
			if valid and opv then
				partverts = opv
			else
				print(opv)
			end
		end

		if partverts then
			meshpcount = meshpcount + 1

			if partnext.vinside then
				for pv = #partverts, 1, -1 do
					local vdupe = copy(partverts[pv])
					vdupe.normal = -vdupe.normal
					partverts[#partverts + 1] = vdupe
				end
			end

			local partvcount = #partverts
			if #meshnext + partvcount > 63999 or split then
				meshlist[#meshlist + 1] = {}
				meshnext = meshlist[#meshlist]
			end
			for pv = 1, partvcount do
				meshnext[#meshnext + 1] = partverts[pv]
			end
			meshvcount = meshvcount + partvcount
		end

		if not direct then coroutine.yield(false) end
	end

	if not direct then
		coroutine.yield(true, { meshes = meshlist, vcount = meshvcount, vmins = vmins, vmaxs = vmaxs, pcount = meshpcount })
	else
		return meshlist
	end
end


--[[

]]
local meshlabs = {}
function prop2mesh.getMesh(crc, uvs, data)
	if not crc or not uvs or not data then
		return false
	end

	local key = string.format("%s_%s", crc, uvs)
	if not meshlabs[key] then
		meshlabs[key] = { crc = crc, uvs = uvs, data = data, coro = coroutine.create(getMeshFromData) }
		return true
	end

	return false
end

function prop2mesh.getMeshDirect(crc, uvs)
	local data = prop2mesh.getMeshData(crc)
	if not data then
		return
	end

	local meshlist = getMeshFromData(data, uvs, true, true)

	prop2mesh.unloadModelFixer()
	meshmodelcache = nil

	return meshlist
end

local message
local function setmessage(text)
	if not IsValid(message) then
		local parent
		if GetOverlayPanel then parent = GetOverlayPanel() end

		message = vgui.Create("DPanel", parent)

		local green = Color(255, 255, 0)
		local black = Color(0,0,0)
		local font  = "Default"

		message.Paint = function(self, w, h)
			draw.SimpleTextOutlined(self.text, font, 0, 0, green, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, black)
		end

		message.SetText = function(self, txt)
			if self.text ~= txt then
				self.text = txt

				surface.SetFont(font)
				local w, h = surface.GetTextSize(self.text)

				self:SetPos(ScrW() - w - 1, ScrH() - h - 1)
				self:SetSize(w, h)
			end
		end
	end

	message:SetText(text)
	message.time = SysTime()
end

local function pluralf(pattern, number)
	return string.format(pattern, number, number == 1 and "" or "s")
end

hook.Add("Think", "prop2mesh_meshlab", function()
	if not prop2mesh or not prop2mesh.downloads then
		return
	end

	if prop2mesh.downloads > 0 then
		setmessage(pluralf("prop2mesh %d server download%s remaining", prop2mesh.downloads))
	end
	if message and SysTime() - message.time > 0.25 then
		if IsValid(message) then
			message:Remove()
		end
		message = nil
	end

	local key, lab = next(meshlabs)
	if not key or not lab then
		return
	end

	local curtime = SysTime()
	while SysTime() - curtime < 0.05 do
		local ok, err, mdata = coroutine.resume(lab.coro, lab.data, lab.uvs)

		if not ok then
			print(err)
			meshlabs[key] = nil
			break
		end

		if err then
			hook.Run("prop2mesh_hook_meshdone", lab.crc, lab.uvs, mdata)
			meshlabs[key] = nil
			break
		end
	end

	if next(meshlabs) == nil then
		prop2mesh.unloadModelFixer()
		meshmodelcache = nil
	else
		if not message then
			setmessage(pluralf("prop2mesh %d mesh build%s remaining", table.Count(meshlabs)))
		end
	end
end)
