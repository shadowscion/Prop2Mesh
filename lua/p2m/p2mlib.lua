-- -----------------------------------------------------------------------------
p2mlib = p2mlib or {}
local p2mlib = p2mlib

include("p2m/funkymodels.lua")


-- -----------------------------------------------------------------------------
local _MESH_VERTEX_LIMIT  = 65000
local _HIGHPOLY_THRESHOLD = 30000


-- -----------------------------------------------------------------------------
local math = math
local string = string

local coroutine_yield = coroutine.yield

local Vector = Vector
local vec = Vector()
local add = vec.Add
local dot = vec.Dot
local cross = vec.Cross
local normalize = vec.Normalize
local rotate = vec.Rotate

local math_abs = math.abs
local math_min = math.min
local math_max = math.max

local a90 = Angle(0, -90, 0)


-- -----------------------------------------------------------------------------
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
	--local scale = 1 / scale
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

-- method https://github.com/chenchenyuyu/DEMO/blob/b6bf971a302c71403e0e34e091402982dfa3cd2d/app/src/pages/vr/decal/decalGeometry.js#L102
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

local function calcbounds(min, max, pos)
	if pos.x < min.x then min.x = pos.x elseif pos.x > max.x then max.x = pos.x end
	if pos.y < min.y then min.y = pos.y elseif pos.y > max.y then max.y = pos.y end
	if pos.z < min.z then min.z = pos.z elseif pos.z > max.z then max.z = pos.z end
end


-- -----------------------------------------------------------------------------
function p2mlib.modelsToMeshes(threaded, models, texmul, getbounds, splitByModel)
	if texmul then
		if texmul == 0 then texmul = nil else texmul = 1 / texmul end
	end

	local meshcache = {}
	local meshparts = { {} }
	local nextpart  = meshparts[1]

	local mins, maxs
	if getbounds then
		mins = Vector(-1, -1, -1)
		maxs = Vector(1, 1, 1)
	end

	local mCount = #models

	for m = 1, mCount do
		local model = models[m]
		if not model or not model.mdl or p2mlib.isBlocked(model.mdl) then
			continue
		end

		-- temporarily cache model meshes
		local meshes
		if meshcache[model.mdl] then
			meshes = meshcache[model.mdl][model.bgrp or 0]
		else
			meshcache[model.mdl] = {}
		end
		if not meshes then
			meshes = util.GetModelMeshes(model.mdl, 0, model.bgrp or 0)
			if meshes then
				meshes.isFunky = p2mlib.isFunky(model.mdl)
				meshcache[model.mdl][model.bgrp or 0] = meshes
			else
				continue
			end
		end

		-- setup
		local mCountFrac = m * (1 / mCount)
		local mScale = model.scale
		local mClips = model.clips
		local mFunky

		-- some model are weird
		if meshes.isFunky then
			local rotated = Angle(model.ang)
			rotated:RotateAroundAxis(rotated:Up(), 90)

			mFunky = {}
			for p = 1, #meshes do
				local valid, special = pcall(meshes.isFunky, p, #meshes, rotated, model.ang)
				if valid then
					local ang = special or rotated
					mFunky[p] = { ang = ang, diff = ang ~= rotated }
				else
					mFunky[p] = { ang = rotated }
				end
			end

			if mScale then
				if model.holo then
					mScale = Vector(mScale.y, mScale.x, mScale.z)
				else
					mScale = Vector(mScale.x, mScale.z, mScale.y)
				end
			end

			if mClips then
				local clips = {}
				for c = 1, #mClips do
					local normal = Vector(mClips[c].n)
					rotate(normal, a90)
					clips[#clips + 1] = {
						no = mClips[c].n,
						n = normal,
						d = mClips[c].d,
					}
				end
				mClips = clips
			end
		end

		-- attempt to prevent lag spikes
		local highpoly
		if threaded then
			local vertcount = 0
			for p = 1, #meshes do
				vertcount = vertcount + #meshes[p].triangles
			end
			highpoly = vertcount > _HIGHPOLY_THRESHOLD
		end

		-- model vertex manipulations
		local modelverts = {}
		for p = 1, #meshes do
			local partmesh   = meshes[p].triangles
			local partrotate = mFunky and mFunky[p]
			local partverts  = {}

			for v = 1, #partmesh do
				local vert   = partmesh[v]
				local pos    = Vector(vert.pos)
				local normal = Vector(vert.normal)

				if mScale then
					if partrotate and partrotate.diff then
						pos.x = pos.x * model.scale.x
						pos.y = pos.y * model.scale.y
						pos.z = pos.z * model.scale.z
					else
						pos.x = pos.x * mScale.x
						pos.y = pos.y * mScale.y
						pos.z = pos.z * mScale.z
					end
				end

				local vcopy = {
					pos    = pos,
					normal = normal,
					rotate = partrotate,
				}

				if not texmul then
					vcopy.u = vert.u
					vcopy.v = vert.v
				end

				partverts[#partverts + 1] = vcopy

				if highpoly then
					coroutine_yield(false, mCountFrac, true)
				end
			end

			if mClips then
				if partrotate then
					for c = 1, #mClips do
						partverts = applyClippingPlane(partverts, partrotate.diff and mClips[c].no or mClips[c].n, mClips[c].d, not texmul)
						if highpoly then
							coroutine_yield(false, mCountFrac, true)
						end
					end
				else
					for c = 1, #mClips do
						partverts = applyClippingPlane(partverts, mClips[c].n, mClips[c].d, not texmul)
						if highpoly then
							coroutine_yield(false, mCountFrac, true)
						end
					end
				end
			end

			for v = 1, #partverts do
				local vert = partverts[v]
				if vert.rotate then
					rotate(vert.normal, vert.rotate.ang or model.ang)
					rotate(vert.pos, vert.rotate.ang or model.ang)
					vert.rotate = nil
				else
					rotate(vert.normal, model.ang)
					rotate(vert.pos, model.ang)
				end
				add(vert.pos, model.pos)

				modelverts[#modelverts + 1] = vert

				if highpoly then
					coroutine_yield(false, mCountFrac, true)
				end
			end
		end

		-- texture coordinates
		if texmul then
			for i = 1, #modelverts, 3 do
				local normal = cross(modelverts[i + 2].pos - modelverts[i].pos, modelverts[i + 1].pos - modelverts[i].pos)
				normalize(normal)

				local boxDir = getBoxDir(normal)
				modelverts[i + 0].u, modelverts[i + 0].v = getBoxUV(modelverts[i + 0].pos, boxDir, texmul)
				modelverts[i + 1].u, modelverts[i + 1].v = getBoxUV(modelverts[i + 1].pos, boxDir, texmul)
				modelverts[i + 2].u, modelverts[i + 2].v = getBoxUV(modelverts[i + 2].pos, boxDir, texmul)

				-- not implemented
				-- if model.sharp then
				-- 	modelverts[i + 0].normal = Vector(normal)
				-- 	modelverts[i + 1].normal = Vector(normal)
				-- 	modelverts[i + 2].normal = Vector(normal)
				-- end

				if highpoly then
					coroutine_yield(false, mCountFrac, true)
				end
			end
		end

		-- duplicate verts in reverse if renderinside flag
		if model.inv then
			for i = #modelverts, 1, -1 do
				modelverts[#modelverts + 1] = copy(modelverts[i])
				modelverts[#modelverts].normal = -modelverts[#modelverts].normal
				if highpoly then
					coroutine_yield(false, mCountFrac, true)
				end
			end
		end

		-- vertex groups
		if #nextpart + #modelverts > _MESH_VERTEX_LIMIT or splitByModel then
			meshparts[#meshparts + 1] = {}
			nextpart = meshparts[#meshparts]
		end

		for v = 1, #modelverts do
			nextpart[#nextpart + 1] = modelverts[v]
			if getbounds then
				calcbounds(mins, maxs, modelverts[v].pos)
			end
		end

		if threaded then
			coroutine_yield(false, mCountFrac, false)
		end
	end

	return meshparts, mins, maxs
end


-- -----------------------------------------------------------------------------
function p2mlib.exportToOBJ(models, tscale)
	local meshparts = p2mlib.modelsToMeshes(false, models, tscale, false, true)

	local concat  = table.concat
	local format  = string.format

	local p_verts = "v %f %f %f\n"
	local p_norms = "vn %f %f %f\n"
	local p_uvws  = "vt %f %f\n"
	local p_faces = "f %d/%d/%d %d/%d/%d %d/%d/%d\n"
	local p_parts = "#PART NUMBER %d\n"

	local function push(tbl, pattern, ...)
		tbl[#tbl + 1] = format(pattern, ...)
	end

	local t_output = {}
	local vnum = 1

	for i = 2, #meshparts do
		local part = meshparts[i]

		local s_verts = {}
		local s_norms = {}
		local s_uvws  = {}
		local s_faces = {}

		for j = 1, #part, 3 do
			local v1 = part[j + 0]
			local v2 = part[j + 1]
			local v3 = part[j + 2]

			push(s_verts, p_verts, v1.pos.x, v1.pos.y, v1.pos.z)
			push(s_verts, p_verts, v2.pos.x, v2.pos.y, v2.pos.z)
			push(s_verts, p_verts, v3.pos.x, v3.pos.y, v3.pos.z)

			push(s_norms, p_norms, v1.normal.x, v1.normal.y, v1.normal.z)
			push(s_norms, p_norms, v2.normal.x, v2.normal.y, v2.normal.z)
			push(s_norms, p_norms, v3.normal.x, v3.normal.y, v3.normal.z)

			push(s_uvws, p_uvws, v1.u, v1.v)
			push(s_uvws, p_uvws, v2.u, v2.v)
			push(s_uvws, p_uvws, v3.u, v3.v)

			push(s_faces, p_faces, vnum, vnum, vnum, vnum + 2, vnum + 2, vnum + 2, vnum + 1, vnum + 1, vnum + 1)
			vnum = vnum + 3
		end

		t_output[#t_output + 1] = concat({
			format("\no model %d\n", i - 1),
			concat(s_verts),
			concat(s_norms),
			concat(s_uvws),
			concat(s_faces)
		})
	end

	return concat(t_output)
end


-- -----------------------------------------------------------------------------
function p2mlib.exportToE2(models, tscale, mscale)
	if not models then
		return
	end

	table.sort(models, function(a, b)
		return a.pos.x < b.pos.x
	end)

	local sortByClipped = {}
	for k, v in ipairs(models) do
		if not v.clips then
			sortByClipped[#sortByClipped + 1] = v
		else
			table.insert(sortByClipped, 1, v)
		end
	end
	models = sortByClipped

	local pcount = 1
	local mcount = 0
	local mlimit = 250

	local header = {
		"@name\n@inputs\n@outputs\n@persist\n@trigger\n\n\n#--- CREATE CONTROLLERS\nBase = entity()\n",
		string.format("TScale = %d\nMScale = %d\n\n", tscale, mscale)
	}

	local footer = { "\n\n#--- BUILD CONTROLLERS\n" }
	local body   = { "\n#--- PUSH MODELS\n" }

	for k, model in ipairs(models) do
		if p2mlib.isFunky(model.mdl) and model.scale and model.holo then
			model.scale = Vector(model.scale.y, model.scale.z, model.scale.x)
		end

		if mcount == 0 then
			header[#header + 1] = string.format("P2M%d = p2mCreate(Base:pos(), Base:angles(), TScale, MScale)\nP2M%d:p2mSetParent(Base)\n\n", pcount, pcount)
			footer[#footer + 1] = string.format("P2M%d:p2mBuild()\n", pcount)
		end

		if not model.scale and not model.clips then
			body[#body + 1] = string.format("P2M%d:p2mPushModel(\"%s\", vec(%f, %f, %f), ang(%f, %f, %f))\n",
				pcount, model.mdl, model.pos.x, model.pos.y, model.pos.z, model.ang.p, model.ang.y, model.ang.r)

		elseif model.scale and not model.clips then
			local x, y, z = model.scale.x, model.scale.y, model.scale.z
			body[#body + 1] = string.format("P2M%d:p2mPushModel(\"%s\", vec(%f, %f, %f), ang(%f, %f, %f), vec(%f, %f, %f))\n",
				pcount, model.mdl, model.pos.x, model.pos.y, model.pos.z, model.ang.p, model.ang.y, model.ang.r, x, y, z)

		elseif model.scale and model.clips then
			local sclips = {}
			for i, clip in ipairs(model.clips) do
				local pos = clip.n * clip.d
				if i ~= #model.clips then
					sclips[#sclips + 1] = string.format("vec(%f, %f, %f), vec(%f, %f, %f), ", pos.x, pos.y, pos.z, clip.n.x, clip.n.y, clip.n.z)
				else
					sclips[#sclips + 1] = string.format("vec(%f, %f, %f), vec(%f, %f, %f)", pos.x, pos.y, pos.z, clip.n.x, clip.n.y, clip.n.z)
				end
			end
			local x, y, z = model.scale.x, model.scale.y, model.scale.z
			body[#body + 1] = string.format("P2M%d:p2mPushModel(\"%s\", vec(%f, %f, %f), ang(%f, %f, %f), vec(%f, %f, %f), %d, array(%s))\n",
				pcount, model.mdl, model.pos.x, model.pos.y, model.pos.z, model.ang.p, model.ang.y, model.ang.r, x, y, z, model.inv and 1 or 0, table.concat(sclips))

		elseif not model.scale and model.clips then
			local sclips = {}
			for i, clip in ipairs(model.clips) do
				local pos = clip.n * clip.d
				if i ~= #model.clips then
					sclips[#sclips + 1] = string.format("vec(%f, %f, %f), vec(%f, %f, %f), ", pos.x, pos.y, pos.z, clip.n.x, clip.n.y, clip.n.z)
				else
					sclips[#sclips + 1] = string.format("vec(%f, %f, %f), vec(%f, %f, %f)", pos.x, pos.y, pos.z, clip.n.x, clip.n.y, clip.n.z)
				end
			end
			body[#body + 1] = string.format("P2M%d:p2mPushModel(\"%s\", vec(%f, %f, %f), ang(%f, %f, %f), %d, array(%s))\n",
				pcount, model.mdl, model.pos.x, model.pos.y, model.pos.z, model.ang.p, model.ang.y, model.ang.r, model.inv and 1 or 0, table.concat(sclips))

		end

		mcount = mcount + 1
		if mcount == mlimit then
			body[#body + 1] = "\n\n"
			pcount = pcount + 1
			mcount = 0
		end
	end

	openE2Editor()
	if wire_expression2_editor then
		local code = table.concat( { table.concat(header), table.concat(body), table.concat(footer) })

		wire_expression2_editor:NewTab()
		wire_expression2_editor:SetCode(code)
		spawnmenu.ActivateTool("wire_expression2")
	end
end
