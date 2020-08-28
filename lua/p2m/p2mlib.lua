p2mlib = p2mlib or {}

local p2mlib = p2mlib

local _MESH_VERTEX_LIMIT  = 65000
local _HIGHPOLY_THRESHOLD = 15000

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

function p2mlib.modelsToMeshes(threaded, models, texmul, getbounds)
	if texmul == 0 then texmul = nil else texmul = 1 / texmul end

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

				if highpoly then
					coroutine_yield(false, mCountFrac, true)
				end
			end
		end

		-- duplicate verts in reverse if renderinside flag
		if model.inv then
			for i = #modelverts, 1, -1 do
				modelverts[#modelverts + 1] = modelverts[i]
			end
		end

		-- vertex groups
		if #nextpart + #modelverts > _MESH_VERTEX_LIMIT then
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


local path        = string.GetPathFromFilename
local lower       = string.lower
local funkyFolder = {}
local funkyModel  = {}
local blockModel  = {}

function p2mlib.isBlocked(model)
	return blockModel[model]
end

function p2mlib.isFunky(model)
	if funkyModel[model] then
		return funkyModel[model]
	elseif funkyFolder[path(model)] then
		return funkyFolder[path(model)]
	end
	return false
end

local pushTo
local function push(str, func)
	if pushTo then
		pushTo[lower(str)] = func or true
	end
end


-- FOLDERS
pushTo = funkyFolder
push("models/props_phx/construct/glass/")
push("models/props_phx/construct/plastic/")
push("models/props_phx/construct/windows/")
push("models/props_phx/construct/wood/")
push("models/props_phx/misc/")
push("models/props_phx/trains/tracks/")
push("models/squad/sf_bars/")
push("models/squad/sf_plates/")
push("models/squad/sf_tris/")
push("models/squad/sf_tubes/")
push("models/weapons/")
push("models/fueltank/")
push("models/phxtended/")
push("models/combine_turrets/")
push("models/bull/gates/")
push("models/bull/various/")
push("models/jaanus/wiretool/")
push("models/kobilica/")
push("models/sprops/trans/wheel_f/")
push("models/sprops/trans/wheels_g/")
push("models/sprops/trans/wheel_big_g/")


-- MODELS
pushTo = funkyModel
push("models/sprops/trans/fender_a/a_fender30.mdl")
push("models/sprops/trans/fender_a/a_fender35.mdl")
push("models/sprops/trans/fender_a/a_fender40.mdl")
push("models/sprops/trans/fender_a/a_fender45.mdl")
push("models/balloons/balloon_classicheart.mdl")
push("models/balloons/balloon_dog.mdl")
push("models/balloons/balloon_star.mdl")
push("models/balloons/hot_airballoon.mdl")
push("models/balloons/hot_airballoon_basket.mdl")
push("models/chairs/armchair.mdl")
push("models/combinecannon/cironwall.mdl")
push("models/combinecannon/remnants.mdl")
push("models/dynamite/dynamite.mdl")
push("models/extras/info_speech.mdl")
push("models/food/burger.mdl")
push("models/food/hotdog.mdl")
push("models/gibs/helicopter_brokenpiece_01.mdl")
push("models/gibs/helicopter_brokenpiece_02.mdl")
push("models/gibs/helicopter_brokenpiece_03.mdl")
push("models/gibs/helicopter_brokenpiece_04_cockpit.mdl")
push("models/gibs/helicopter_brokenpiece_05_tailfan.mdl")
push("models/gibs/helicopter_brokenpiece_06_body.mdl")
push("models/gibs/shield_scanner_gib1.mdl")
push("models/gibs/shield_scanner_gib2.mdl")
push("models/gibs/shield_scanner_gib3.mdl")
push("models/gibs/shield_scanner_gib4.mdl")
push("models/gibs/shield_scanner_gib5.mdl")
push("models/gibs/shield_scanner_gib6.mdl")
push("models/gibs/strider_gib1.mdl")
push("models/gibs/strider_gib2.mdl")
push("models/gibs/strider_gib3.mdl")
push("models/gibs/strider_gib4.mdl")
push("models/gibs/strider_gib5.mdl")
push("models/gibs/strider_gib6.mdl")
push("models/gibs/strider_gib7.mdl")
push("models/hunter/plates/plate1x3x1trap.mdl")
push("models/hunter/plates/plate1x4x2trap.mdl")
push("models/hunter/plates/plate1x4x2trap1.mdl")
push("models/items/357ammo.mdl")
push("models/items/357ammobox.mdl")
push("models/items/ammocrate_ar2.mdl")
push("models/items/ammocrate_grenade.mdl")
push("models/items/ammocrate_rockets.mdl")
push("models/items/ammocrate_smg1.mdl")
push("models/items/crossbowrounds.mdl")
push("models/items/cs_gift.mdl")
push("models/lamps/torch.mdl")
push("models/maxofs2d/button_01.mdl")
push("models/maxofs2d/button_03.mdl")
push("models/maxofs2d/button_04.mdl")
push("models/maxofs2d/button_06.mdl")
push("models/maxofs2d/button_slider.mdl")
push("models/maxofs2d/camera.mdl")
push("models/maxofs2d/logo_gmod_b.mdl")
push("models/mechanics/articulating/arm_base_b.mdl")
push("models/props_c17/doll01.mdl")
push("models/props_c17/door01_left.mdl")
push("models/props_c17/door02_double.mdl")
push("models/props_c17/suitcase_passenger_physics.mdl")
push("models/props_c17/trappropeller_blade.mdl")
push("models/props_canal/mattpipe.mdl")
push("models/props_canal/winch01b.mdl")
push("models/props_canal/winch02b.mdl")
push("models/props_canal/winch02c.mdl")
push("models/props_canal/winch02d.mdl")
push("models/props_combine/breen_tube.mdl")
push("models/props_combine/breenbust.mdl")
push("models/props_combine/breenbust_chunk01.mdl")
push("models/props_combine/breenbust_chunk02.mdl")
push("models/props_combine/breenbust_chunk04.mdl")
push("models/props_combine/breenbust_chunk05.mdl")
push("models/props_combine/breenbust_chunk06.mdl")
push("models/props_combine/breenbust_chunk07.mdl")
push("models/props_combine/breenchair.mdl")
push("models/props_combine/breenclock.mdl")
push("models/props_combine/breenpod.mdl")
push("models/props_combine/breenpod_inner.mdl")
push("models/props_combine/bunker_gun01.mdl")
push("models/props_combine/bustedarm.mdl")
push("models/props_combine/cell_01_pod_cheap.mdl")
push("models/props_combine/combine_ballsocket.mdl")
push("models/props_combine/combine_mine01.mdl")
push("models/props_combine/combine_tptimer.mdl")
push("models/props_combine/combinebutton.mdl")
push("models/props_combine/combinethumper001a.mdl")
push("models/props_combine/combinethumper002.mdl")
push("models/props_combine/eli_pod_inner.mdl")
push("models/props_combine/health_charger001.mdl")
push("models/props_combine/introomarea.mdl")
push("models/props_combine/soldier_bed.mdl")
push("models/props_combine/stalkerpod_physanim.mdl")
push("models/props_doors/door01_dynamic.mdl")
push("models/props_doors/door03_slotted_left.mdl")
push("models/props_doors/doorklab01.mdl")
push("models/props_junk/ravenholmsign.mdl")
push("models/props_lab/blastdoor001a.mdl")
push("models/props_lab/blastdoor001b.mdl")
push("models/props_lab/blastdoor001c.mdl")
push("models/props_lab/citizenradio.mdl")
push("models/props_lab/clipboard.mdl")
push("models/props_lab/crematorcase.mdl")
push("models/props_lab/hevplate.mdl")
push("models/props_lab/huladoll.mdl")
push("models/props_lab/kennel_physics.mdl")
push("models/props_lab/keypad.mdl")
push("models/props_lab/ravendoor.mdl")
push("models/props_lab/tpswitch.mdl")
push("models/props_phx/amraam.mdl")
push("models/props_phx/box_amraam.mdl")
push("models/props_phx/box_torpedo.mdl")
push("models/props_phx/cannon.mdl")
push("models/props_phx/carseat2.mdl")
push("models/props_phx/carseat3.mdl")
push("models/props_phx/construct/metal_angle180.mdl")
push("models/props_phx/construct/metal_angle90.mdl")
push("models/props_phx/construct/metal_dome180.mdl")
push("models/props_phx/construct/metal_dome90.mdl")
push("models/props_phx/construct/metal_plate1.mdl")
push("models/props_phx/construct/metal_plate1x2.mdl")
push("models/props_phx/construct/metal_plate2x2.mdl")
push("models/props_phx/construct/metal_plate2x4.mdl")
push("models/props_phx/construct/metal_plate4x4.mdl")
push("models/props_phx/construct/metal_plate_curve.mdl")
push("models/props_phx/construct/metal_plate_curve180.mdl")
push("models/props_phx/construct/metal_plate_curve2.mdl")
push("models/props_phx/construct/metal_plate_curve2x2.mdl")
push("models/props_phx/construct/metal_wire1x1x1.mdl")
push("models/props_phx/construct/metal_wire1x1x2.mdl")
push("models/props_phx/construct/metal_wire1x1x2b.mdl")
push("models/props_phx/construct/metal_wire1x2.mdl")
push("models/props_phx/construct/metal_wire1x2b.mdl")
push("models/props_phx/construct/metal_wire_angle180x1.mdl")
push("models/props_phx/construct/metal_wire_angle180x2.mdl")
push("models/props_phx/construct/metal_wire_angle90x1.mdl")
push("models/props_phx/construct/metal_wire_angle90x2.mdl")
push("models/props_phx/facepunch_logo.mdl")
push("models/props_phx/games/chess/black_king.mdl")
push("models/props_phx/games/chess/black_knight.mdl")
push("models/props_phx/games/chess/board.mdl")
push("models/props_phx/games/chess/white_king.mdl")
push("models/props_phx/games/chess/white_knight.mdl")
push("models/props_phx/gears/bevel9.mdl")
push("models/props_phx/gears/rack18.mdl")
push("models/props_phx/gears/rack36.mdl")
push("models/props_phx/gears/rack70.mdl")
push("models/props_phx/gears/rack9.mdl")
push("models/props_phx/gears/spur9.mdl")
push("models/props_phx/huge/road_curve.mdl")
push("models/props_phx/huge/road_long.mdl")
push("models/props_phx/huge/road_medium.mdl")
push("models/props_phx/huge/road_short.mdl")
push("models/props_phx/mechanics/slider1.mdl")
push("models/props_phx/mechanics/slider2.mdl")
push("models/props_phx/mk-82.mdl")
push("models/props_phx/playfield.mdl")
push("models/props_phx/torpedo.mdl")
push("models/props_phx/trains/double_wheels_base.mdl")
push("models/props_phx/trains/fsd-overrun.mdl")
push("models/props_phx/trains/fsd-overrun2.mdl")
push("models/props_phx/trains/monorail1.mdl")
push("models/props_phx/trains/monorail_curve.mdl")
push("models/props_phx/trains/wheel_base.mdl")
push("models/props_phx/wheels/breakable_tire.mdl")
push("models/props_phx/wheels/magnetic_large_base.mdl")
push("models/props_phx/wheels/magnetic_med_base.mdl")
push("models/props_phx/wheels/magnetic_small_base.mdl")
push("models/props_phx/ww2bomb.mdl")
push("models/props_trainstation/passengercar001.mdl")
push("models/props_trainstation/passengercar001_dam01a.mdl")
push("models/props_trainstation/passengercar001_dam01c.mdl")
push("models/props_trainstation/train_outro_car01.mdl")
push("models/props_trainstation/train_outro_porch01.mdl")
push("models/props_trainstation/train_outro_porch02.mdl")
push("models/props_trainstation/train_outro_porch03.mdl")
push("models/props_trainstation/wrecked_train.mdl")
push("models/props_trainstation/wrecked_train_02.mdl")
push("models/props_trainstation/wrecked_train_divider_01.mdl")
push("models/props_trainstation/wrecked_train_door.mdl")
push("models/props_trainstation/wrecked_train_panel_01.mdl")
push("models/props_trainstation/wrecked_train_panel_02.mdl")
push("models/props_trainstation/wrecked_train_panel_03.mdl")
push("models/props_trainstation/wrecked_train_rack_01.mdl")
push("models/props_trainstation/wrecked_train_rack_02.mdl")
push("models/props_trainstation/wrecked_train_seat.mdl")
push("models/props_vehicles/mining_car.mdl")
push("models/props_vehicles/van001a_nodoor_physics.mdl")
push("models/props_wasteland/cranemagnet01a.mdl")
push("models/props_wasteland/wood_fence01a.mdl")
push("models/props_wasteland/wood_fence01b.mdl")
push("models/props_wasteland/wood_fence01c.mdl")
push("models/quarterlife/fsd-overrun-toy.mdl")
push("models/sprops/trans/train/double_24.mdl")
push("models/sprops/trans/train/double_36.mdl")
push("models/sprops/trans/train/double_48.mdl")
push("models/sprops/trans/train/double_72.mdl")
push("models/sprops/trans/train/single_24.mdl")
push("models/sprops/trans/train/single_36.mdl")
push("models/sprops/trans/train/single_48.mdl")
push("models/sprops/trans/train/single_72.mdl")
push("models/thrusters/jetpack.mdl")
push("models/vehicles/prisoner_pod.mdl")
push("models/vehicles/prisoner_pod_inner.mdl")
push("models/vehicles/vehicle_van.mdl")
push("models/vehicles/vehicle_vandoor.mdl")
push("models/props_mining/control_lever01.mdl")
push("models/props_lab/tpplug.mdl")
push("models/vehicles/pilot_seat.mdl")
push("models/autocannon/semiautocannon_25mm.mdl")
push("models/autocannon/semiautocannon_37mm.mdl")
push("models/autocannon/semiautocannon_45mm.mdl")
push("models/autocannon/semiautocannon_57mm.mdl")
push("models/autocannon/semiautocannon_76mm.mdl")
push("models/engines/emotorlarge.mdl")
push("models/engines/emotormed.mdl")
push("models/engines/emotorsmall.mdl")
push("models/engines/gasturbine_l.mdl")
push("models/engines/gasturbine_m.mdl")
push("models/engines/gasturbine_s.mdl")
push("models/engines/linear_l.mdl")
push("models/engines/linear_m.mdl")
push("models/engines/linear_s.mdl")
push("models/engines/radial7l.mdl")
push("models/engines/radial7m.mdl")
push("models/engines/radial7s.mdl")
push("models/engines/transaxial_l.mdl")
push("models/engines/transaxial_m.mdl")
push("models/engines/transaxial_s.mdl")
push("models/engines/turbine_l.mdl")
push("models/engines/turbine_m.mdl")
push("models/engines/turbine_s.mdl")
push("models/engines/wankel_2_med.mdl")
push("models/engines/wankel_2_small.mdl")
push("models/engines/wankel_3_med.mdl")
push("models/engines/wankel_4_med.mdl")
push("models/howitzer/howitzer_105mm.mdl")
push("models/howitzer/howitzer_122mm.mdl")
push("models/howitzer/howitzer_155mm.mdl")
push("models/howitzer/howitzer_203mm.mdl")
push("models/howitzer/howitzer_240mm.mdl")
push("models/howitzer/howitzer_290mm.mdl")
push("models/howitzer/howitzer_75mm.mdl")
push("models/machinegun/machinegun_20mm_compact.mdl")
push("models/machinegun/machinegun_30mm_compact.mdl")
push("models/machinegun/machinegun_40mm_compact.mdl")
push("models/rotarycannon/kw/14_5mmrac.mdl")
push("models/rotarycannon/kw/20mmrac.mdl")
push("models/rotarycannon/kw/30mmrac.mdl")
push("models/holograms/tetra.mdl")
push("models/holograms/hexagon.mdl")
push("models/holograms/icosphere.mdl")
push("models/holograms/icosphere2.mdl")
push("models/holograms/icosphere3.mdl")
push("models/holograms/prism.mdl")
push("models/holograms/sphere.mdl")
push("models/props_mining/switch01.mdl")
push("models/props_mining/switch_updown01.mdl")
push("models/props_mining/diesel_generator.mdl")
push("models/props_mining/ceiling_winch01.mdl")
push("models/props_mining/elevator_winch_cog.mdl")
--push("models/props_mining/diesel_generator_crank.mdl") -- special
push("models/nova/chair_plastic01.mdl")
push("models/nova/chair_wood01.mdl")
push("models/nova/chair_office02.mdl")
push("models/nova/chair_office01.mdl")
push("models/props/de_inferno/hr_i/inferno_vintage_radio/inferno_vintage_radio.mdl")
push("models/radar/radar_sp_mid.mdl")
push("models/radar/radar_sp_sml.mdl")
push("models/radar/radar_sp_big.mdl")
push("models/props/coop_kashbah/coop_stealth_boat/coop_stealth_boat_animated.mdl")


-- SPECIAL FOLDERS
pushTo = funkyFolder

push("models/sprops/trans/wheel_b/", function(partnum, numparts, rotated, normal)
	if partnum == 1 then return rotated else return normal end
end)
push("models/sprops/trans/wheel_d/", function(partnum, numparts, rotated, normal)
	if partnum == 1 or partnum == 2 then return rotated else return normal end
end)


-- SPECIAL MODELS
pushTo = funkyModel

local fix = function(partnum, numparts, rotated, normal)
	if partnum == 1 then return rotated else return normal end
end
push("models/sprops/trans/miscwheels/thin_moto15.mdl", fix)
push("models/sprops/trans/miscwheels/thin_moto20.mdl", fix)
push("models/sprops/trans/miscwheels/thin_moto25.mdl", fix)
push("models/sprops/trans/miscwheels/thin_moto30.mdl", fix)
push("models/sprops/trans/miscwheels/thick_moto15.mdl", fix)
push("models/sprops/trans/miscwheels/thick_moto20.mdl", fix)
push("models/sprops/trans/miscwheels/thick_moto25.mdl", fix)
push("models/sprops/trans/miscwheels/thick_moto30.mdl", fix)

local fix = function(partnum, numparts, rotated, normal)
	if partnum == 1 or partnum == 2 then return rotated else return normal end
end
push("models/sprops/trans/miscwheels/tank15.mdl", fix)
push("models/sprops/trans/miscwheels/tank20.mdl", fix)
push("models/sprops/trans/miscwheels/tank25.mdl", fix)
push("models/sprops/trans/miscwheels/tank30.mdl", fix)
