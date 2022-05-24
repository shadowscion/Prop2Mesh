
---- construct library
prop2mesh.primitive = {}
prop2mesh.primitive.constructors = {}

local addon = prop2mesh.primitive
local constructors = addon.constructors

local math = math
local table = table
local Vector = Vector

local pi = math.pi
local tau = math.pi*2

local vec = Vector()
local add = vec.Add
local mul = vec.Mul
local div = vec.Div
local sub = vec.Sub
local dot = vec.Dot
local cross = vec.Cross
local rotate = vec.Rotate

local construct_simpleton, insert_simpleton

local function map(x, in_min, in_max, out_min, out_max)
    return (x - in_min)*(out_max - out_min)/(in_max - in_min) + out_min
end

do
	----
	local function construct_autosmooth(vertices, smoothrad) -- credit to Sevii
		if smoothrad == 1 then return end

		local norms = setmetatable({}, {__index = function(t, k) local r=setmetatable({}, {__index=function(t, k) local r=setmetatable({}, {__index=function(t, k) local r={} t[k]=r return r end}) t[k]=r return r end}) t[k]=r return r end})
		for _, vertex in ipairs(vertices) do
			local pos = vertex.pos
			local norm = norms[pos[1]][pos[2]][pos[3]]
			norm[#norm+1] = vertex.normal
		end

		for _, vertex in ipairs(vertices) do
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

	local function construct_triangulate(primitive)
		local uv = 1/48
		local vertex = primitive.vertex
		local triangle = {}

		local getUV = not primitive.skipUV

		for k, face in ipairs(primitive.index) do
			local t1 = face[1]
			local t2 = face[2]
			for j = 3, #face do
				local t3 = face[j]
				local v1, v2, v3 = vertex[t1], vertex[t3], vertex[t2]
				local normal = (v3 - v1):Cross(v2 - v1)
				normal:Normalize()

				v1 = {pos = v1, normal = normal}
				v2 = {pos = v2, normal = normal}
				v3 = {pos = v3, normal = normal}

				if getUV then
					local nx, ny, nz = math.abs(normal.x), math.abs(normal.y), math.abs(normal.z)
					if nx > ny and nx > nz then

						local nw = normal.x < 0 and -1 or 1
						v1.u = v1.pos.z*nw*uv
						v1.v = v1.pos.y*uv
						v2.u = v2.pos.z*nw*uv
						v2.v = v2.pos.y*uv
						v3.u = v3.pos.z*nw*uv
						v3.v = v3.pos.y*uv
					elseif ny > nz then

						local nw = normal.y < 0 and -1 or 1
						v1.u = v1.pos.x*uv
						v1.v = v1.pos.z*nw*uv
						v2.u = v2.pos.x*uv
						v2.v = v2.pos.z*nw*uv
						v3.u = v3.pos.x*uv
						v3.v = v3.pos.z*nw*uv
					else

						local nw = normal.z < 0 and 1 or -1
						v1.u = v1.pos.x*nw*uv
						v1.v = v1.pos.y*uv
						v2.u = v2.pos.x*nw*uv
						v2.v = v2.pos.y*uv
						v3.u = v3.pos.x*nw*uv
						v3.v = v3.pos.y*uv
					end
				end

				triangle[#triangle + 1] = v1
				triangle[#triangle + 1] = v2
				triangle[#triangle + 1] = v3
				t2 = t3
			end
		end

		if tonumber(primitive.smoothNormals) then
			construct_autosmooth(triangle, math.cos(math.rad(tonumber(primitive.smoothNormals))))
		end

		primitive.triangle = triangle
	end

	local function construct_error(msg, col, triangulate)
		MsgC(Color(255, 255, 0), "error constructing primitive\n")
		MsgC(col or Color(255, 0, 0), string.format("%s\n", msg or ""))

		local primitive = {iserror = true}

		primitive.vertex = {
			Vector(12, -12, -12),
			Vector(12, 12, -12),
			Vector(12, 12, 12),
			Vector(12, -12, 12),
			Vector(-12, -12, -12),
			Vector(-12, 12, -12),
			Vector(-12, 12, 12),
			Vector(-12, -12, 12),
		}

		primitive.physics = {primitive.vertex}

		if triangulate then
			primitive.index = {
				{1, 2, 3, 4},
				{2, 6, 7, 3},
				{6, 5, 8, 7},
				{5, 1, 4, 8},
				{4, 3, 7, 8},
				{5, 6, 2, 1},
			}

			construct_triangulate(primitive)
		end

		return primitive
	end

	addon.construct_get = function(name, args, nophys, triangulate)
		if constructors[name] then
			if not istable(args) then
				return construct_error("arguments must be a table")
			end

			local succ, ret = constructors[name].func(args, nophys, triangulate)

			if not succ then
				return construct_error(ret, nil, triangulate)
			end
			if not ret then
				return construct_error(string.format("(%s) (no return value)", name), nil, triangulate)
			end
			if not istable(ret.vertex) then
				return construct_error(string.format("(%s) (vertex field must be a table)", name), nil, triangulate)
			end
			if ret.physics and not istable(ret.physics) then
				return construct_error(string.format("(%s) (physics field must be a table)", name), nil, triangulate)
			end
			if ret.index and not istable(ret.index) then
				return construct_error(string.format("(%s) (index field must be a table)", name), nil, triangulate)
			end

			if triangulate then
				local sv = string.gsub(string.lower(args.modv or ""), " ", "")
				local _, _, normals = string.find(sv, "normals=(%d+)")

				ret.smoothNormals = tonumber(normals)
				ret.skipUV = tobool(args.skipUV)

				pcall(isfunction(triangulate) and triangulate or construct_triangulate, ret)
			end

			return ret
		end
		return construct_error(string.format("(%s) (non-existing constructor function)", name), nil, triangulate)
	end

	addon.construct_register = function(name, func, ...)
		constructors[name] = {func = function(args, nophys, triangulate)
			return pcall(func, args, nophys, triangulate)
		end, data = {...}}
		return constructors[name]
	end

	----
	local simpletons = {}

	local function register_simpleton(name, vertex, index)
		simpletons[name] = {vertex = vertex, index = index}
	end

	function construct_simpleton(name, pos, ang, scale, offsetT)
		local simpleton = simpletons[name]
		if not simpleton then return end

		local vertex = {}
		for k, v in ipairs(simpleton.vertex) do
			local vert = Vector(v)
			if scale then
				mul(vert, scale)
			end
			if ang then
				rotate(vert, ang)
			end
			if pos then
				add(vert, pos)
			end
			vertex[k] = vert
		end

		local index
		if offsetT then
			index = {}
			for i = 1, #simpleton.index do
				local t = {}
				for j = 1, #simpleton.index[i] do
					t[j] = simpleton.index[i][j] + offsetT
				end
				index[i] = t
			end
		end

		return vertex, index or false
	end

	function insert_simpleton(vertex, index, physics, convexID, simpletonV, simpletonI)
		if simpletonI and index then
			for i = 1, #simpletonI do
				index[#index + 1] = simpletonI[i]
			end
		end
		if simpletonV then
			local convex
			if physics then
				if not convexID then convexID = #physics + 1 end
				if not physics[convexID] then physics[convexID] = {} end
				convex = physics[convexID]
			end
			for i = 1, #simpletonV do
				if vertex then
					vertex[#vertex + 1] = simpletonV[i]
				end
				if convex then
					convex[#convex + 1] = simpletonV[i]
				end
			end
		end
	end

	register_simpleton("slider_wedge",{Vector(-0.5,-0.5,0.5),Vector(-0.5,0.5,0.3),Vector(-0.5,-0.5,0.3),Vector(0.5,-0,-0.5),Vector(0.5,-0.5,0.3),Vector(0.5,-0.5,0.5),Vector(0.5,0.5,0.5),Vector(0.5,0.5,0.3),Vector(-0.5,0.5,0.5),Vector(-0.5,0,-0.5)},
		{{9,1,6,7},{9,2,3,1},{1,3,5,6},{6,5,8,7},{7,8,2,9},{3,10,4,5},{8,4,10,2},{2,10,3},{5,4,8}})

	register_simpleton("slider_spike",{Vector(0.5,-0.5,0.3),Vector(-0.5,-0.5,0.5),Vector(-0.5,-0.5,0.3),Vector(0.5,0.5,0.3),Vector(0,0,-0.5),Vector(-0.5,0.5,0.3),Vector(0.5,0.5,0.5),Vector(0.5,-0.5,0.5),Vector(-0.5,0.5,0.5)},
		{{3,5,1},{6,5,3},{1,5,4},{4,5,6},{9,6,3,2},{2,3,1,8},{8,1,4,7},{7,4,6,9},{7,9,2,8}})

	register_simpleton("slider_cube",{Vector(-0.5,0.5,-0.5),Vector(-0.5,0.5,0.5),Vector(0.5,0.5,-0.5),Vector(0.5,0.5,0.5),Vector(-0.5,-0.5,-0.5),Vector(-0.5,-0.5,0.5),Vector(0.5,-0.5,-0.5),Vector(0.5,-0.5,0.5)},
		{{1,5,6,2},{5,7,8,6},{7,3,4,8},{3,1,2,4},{4,2,6,8},{1,3,7,5}})
end

--[[
addon.construct_register(, function(args, nophys, triangulate)
	local vertex, index, physics

	if triangulate then

	end

	if not nophys then
		physics = vertex
	end

	return {vertex = vertex, index = index, physics = {physics}}
end)
]]


----
do
	local flippers = {Vector(1, 1, 1), Vector(1, -1, 1), Vector(-1, 1, 1), Vector(-1, -1, 1)}

	addon.construct_register("rail_slider", function(args, nophys, triangulate)
		local tooth = "slider_" .. args.tooth

		local px = args.px or 24
		local py = args.py or 38
		local pz = args.pz or 16
		local dx = args.pdx or 24
		local dy = args.pdy or 1
		local dz = args.pdz or 8
		local dw = args.pd or 14

		local flange = args.flange
		local double = args.double
		local mirror = args.mirror

		dw = math.max(dw, double and dy*2 or dy)
		if dw == dy then flange = false end

		if not mirror then
			px = 0
		else
			px = math.max(px, dx*0.5)
			py = math.max(py, 0.5)
		end

		local scale = Vector(dx, dy, dz)
		local pos = Vector(px, py + dy*0.5 - 0.5, 0)
		local flangeScale = Vector(dx, dw, 0.5)
		local flangePos = Vector(px, py + flangeScale.y*0.5 - 0.5, dz*0.5 + flangeScale.z*0.5)

		if double then
			double = Vector(px, py + flangeScale.y - 0.5 - dy*0.5, 0)
		end

		local vertex, index, physics

		vertex = {}
		if triangulate then index = {} end
		if not nophys then physics = {} end

		insert_simpleton(vertex, index, physics, nil, construct_simpleton("slider_cube", Vector(0, 0, pz), nil, Vector(math.max(dx, px) + 1, math.max(dy, py) + 1, 1), index and #vertex))

		for i = 1, #flippers do
			if i > 2 and not mirror then
				break
			end

			local flip = flippers[i]

			insert_simpleton(vertex, index, physics, nil, construct_simpleton(tooth, pos*flip, nil, scale, index and #vertex))

			if flange then
				insert_simpleton(vertex, index, physics, nil, construct_simpleton("slider_cube", flangePos*flip, nil, flangeScale, index and #vertex))
			end
			if double then
				insert_simpleton(vertex, index, physics, nil, construct_simpleton(tooth, double*flip, nil, scale, index and #vertex))
			end
		end

		return {vertex = vertex, index = index, physics = physics}
	end)
end

----
addon.construct_register("cone", function(args, nophys, triangulate)
	local vertex, index, physics

	local maxseg = args.maxseg or 32
	if maxseg < 3 then maxseg = 3 elseif maxseg > 32 then maxseg = 32 end
	local numseg = args.numseg or 32
	if numseg < 1 then numseg = 1 elseif numseg > maxseg then numseg = maxseg end

	local dx = (args.dx or 1)*0.5
	local dy = (args.dy or 1)*0.5
	local dz = (args.dz or 1)*0.5

	local tx = map(args.tx or 0, -1, 1, -2, 2)
	local ty = map(args.ty or 0, -1, 1, -2, 2)

	vertex = {}
	for i = 0, numseg do
		local a = math.rad((i/maxseg)* -360)
		vertex[#vertex + 1] = Vector(math.sin(a)*dx, math.cos(a)*dy, -dz)
	end

	local c0 = #vertex
	local c1 = c0 + 1
	local c2 = c0 + 2

	vertex[#vertex + 1] = Vector(0, 0, -dz)
	vertex[#vertex + 1] = Vector(-dx*tx, dy*ty, dz)

	if triangulate then
		index = {}
		for i = 1, c0 - 1 do
			index[#index + 1] = {i, i + 1, c2}
			index[#index + 1] = {i, c1, i + 1}
		end
		if numseg ~= maxseg then
			index[#index + 1] = {c0, c1, c2}
			index[#index + 1] = {c0 + 1, 1, c2}
		end
	end

	if not nophys then
		if numseg ~= maxseg then
			physics = {{vertex[c1], vertex[c2]}, {vertex[c1], vertex[c2]}}
			for i = 1, c0 do
				if (i - 1 <= maxseg*0.5) then
					table.insert(physics[1], vertex[i])
				end
				if (i - 0 >= maxseg*0.5) then
					table.insert(physics[2], vertex[i])
				end
			end
		else
			physics = {vertex}
		end
	end

	return {vertex = vertex, index = index, physics = physics}
end)

----
addon.construct_register("cube", function(args, nophys, triangulate)
	local vertex, index, physics

	local dx = (args.dx or 1)*0.5
	local dy = (args.dy or 1)*0.5
	local dz = (args.dz or 1)*0.5

	local tx = 1 - (args.tx or 0)
	local ty = 1 - (args.ty or 0)

	if tx == 0 and ty == 0 then
		vertex = {
			Vector(dx, -dy, -dz),
			Vector(dx, dy, -dz),
			Vector(-dx, -dy, -dz),
			Vector(-dx, dy, -dz),
			Vector(0, 0, dz),
		}
	else
		vertex = {
			Vector(dx, -dy, -dz),
			Vector(dx, dy, -dz),
			Vector(dx*tx, dy*ty, dz),
			Vector(dx*tx, -dy*ty, dz),
			Vector(-dx, -dy, -dz),
			Vector(-dx, dy, -dz),
			Vector(-dx*tx, dy*ty, dz),
			Vector(-dx*tx, -dy*ty, dz),
		}
	end

	if triangulate then
		if tx == 0 and ty == 0 then
			index = {
				{1, 2, 5},
				{2, 4, 5},
				{4, 3, 5},
				{3, 1, 5},
				{3, 4, 2, 1},
			}
		else
			index = {
				{1, 2, 3, 4},
				{2, 6, 7, 3},
				{6, 5, 8, 7},
				{5, 1, 4, 8},
				{4, 3, 7, 8},
				{5, 6, 2, 1},
			}
		end
	end

	if not nophys then
		physics = vertex
	end

	return {vertex = vertex, index = index, physics = {physics}}
end)

----
addon.construct_register("cube_magic", function(args, nophys, triangulate)
	local vertex, index, physics

	local dx = (args.dx or 1)*0.5
	local dy = (args.dy or 1)*0.5
	local dz = (args.dz or 1)*0.5

	local tx = 1 - (args.tx or 0)
	local ty = 1 - (args.ty or 0)

	local dt = math.min(args.dt or 1, dx, dy)

	if dt == dx or dt == dy then
		return addon.construct_get("cube", args, nophys, triangulate)
	end

	local sv = string.gsub(string.lower(args.modv or ""), " ", "")
	local _, _, sides = string.find(sv, "sides=(%d%d%d%d%d%d)")

	if not sides then
		sides = {true,true,true,true,true,true}
	else
		local ret = {}
		for i = 1, 6 do
			ret[i] = tobool(sides[i])
		end
		sides = ret
		local valid
		for k, v in pairs(sides) do
			if v == true then
				valid = true
				break
			end
		end
		if not valid then sides = {true,true,true,true,true,true} end
	end

	local normals = {
		Vector(1, 0, 0):Angle(),
		Vector(-1, 0, 0):Angle(),
		Vector(0, 1, 0):Angle(),
		Vector(0, -1, 0):Angle(),
		Vector(0, 0, 1):Angle(),
		Vector(0, 0, -1):Angle(),
	}

	local a = Vector(1, -1, -1)
	local b = Vector(1, 1, -1)
	local c = Vector(1, 1, 1)
	local d = Vector(1, -1, 1)

	vertex = {}
	if not nophys then physics = {} end
	if triangulate then index = {} end

	local ibuffer = 1

	for k, v in ipairs(normals) do
		if not sides[k] then
			ibuffer = ibuffer - 8
		else
			local vec = Vector(a)

			vec:Rotate(v)

			vec.x = vec.x*dx
			vec.y = vec.y*dy
			vec.z = vec.z*dz

			if vec.z > 0 then
				vec.x = vec.x*tx
				vec.y = vec.y*ty
			end

			vertex[#vertex + 1] = vec
			vertex[#vertex + 1] = vec - vec:GetNormalized()*dt

			local vec = Vector(b)

			vec:Rotate(v)

			vec.x = vec.x*dx
			vec.y = vec.y*dy
			vec.z = vec.z*dz

			if vec.z > 0 then
				vec.x = vec.x*tx
				vec.y = vec.y*ty
			end

			vertex[#vertex + 1] = vec
			vertex[#vertex + 1] = vec - vec:GetNormalized()*dt

			local vec = Vector(c)

			vec:Rotate(v)

			vec.x = vec.x*dx
			vec.y = vec.y*dy
			vec.z = vec.z*dz

			if vec.z > 0 then
				vec.x = vec.x*tx
				vec.y = vec.y*ty
			end

			vertex[#vertex + 1] = vec
			vertex[#vertex + 1] = vec - vec:GetNormalized()*dt

			local vec = Vector(d)

			vec:Rotate(v)

			vec.x = vec.x*dx
			vec.y = vec.y*dy
			vec.z = vec.z*dz

			if vec.z > 0 then
				vec.x = vec.x*tx
				vec.y = vec.y*ty
			end

			vertex[#vertex + 1] = vec
			vertex[#vertex + 1] = vec - vec:GetNormalized()*dt

			if not nophys then
				local count = #vertex
				physics[#physics + 1] = {
					vertex[count - 0],
					vertex[count - 1],
					vertex[count - 2],
					vertex[count - 3],
					vertex[count - 4],
					vertex[count - 5],
					vertex[count - 6],
					vertex[count - 7],
				}
			end

			if triangulate then
				local n = (k - 1)*8 + ibuffer
				index[#index + 1] = {n + 0, n + 2, n + 4, n + 6}
				index[#index + 1] = {n + 3, n + 1, n + 7, n + 5}
				index[#index + 1] = {n + 1, n + 0, n + 6, n + 7}
				index[#index + 1] = {n + 2, n + 3, n + 5, n + 4}
				index[#index + 1] = {n + 5, n + 7, n + 6, n + 4}
				index[#index + 1] = {n + 0, n + 1, n + 3, n + 2}
			end
		end
	end

	return {vertex = vertex, index = index, physics = physics}
end)

----
addon.construct_register("cube_tube", function(args, nophys, triangulate)
	local vertex, index, physics

	local dx = (args.dx or 1)*0.5
	local dy = (args.dy or 1)*0.5
	local dz = (args.dz or 1)*0.5
	local dt = math.min(args.dt or 1, dx, dy)

	if dt == dx or dt == dy then
		return addon.construct_get("cube", args, nophys, triangulate)
	end

	local numseg = args.numseg or 4
	if numseg > 4 then numseg = 4 elseif numseg < 1 then numseg = 1 end

	local numring = 4*math.Round((args.subdiv or 32)/4)
	if numring < 4 then numring = 4 elseif numring > 32 then numring = 32 end

	local cube_angle = Angle(0, 90, 0)
	local cube_corner0 = Vector(1, 0, 0)
	local cube_corner1 = Vector(1, 1, 0)
	local cube_corner2 = Vector(0, 1, 0)

	local ring_steps0 = numring/4
	local ring_steps1 = numring/2
	local capped = numseg ~= 4
	if triangulate then
		index = capped and {{8, 7, 1, 4}} or {}
	end

	vertex = {}

	if not nophys then
		physics = {}
	end

	for i = 0, numseg - 1 do
		cube_corner0:Rotate(cube_angle)
		cube_corner1:Rotate(cube_angle)
		cube_corner2:Rotate(cube_angle)

		local part
		if not nophys then part = {} end

		vertex[#vertex + 1] = Vector(cube_corner0.x*dx, cube_corner0.y*dy, -dz)
		vertex[#vertex + 1] = Vector(cube_corner1.x*dx, cube_corner1.y*dy, -dz)
		vertex[#vertex + 1] = Vector(cube_corner2.x*dx, cube_corner2.y*dy, -dz)
		vertex[#vertex + 1] = Vector(cube_corner0.x*dx, cube_corner0.y*dy, dz)
		vertex[#vertex + 1] = Vector(cube_corner1.x*dx, cube_corner1.y*dy, dz)
		vertex[#vertex + 1] = Vector(cube_corner2.x*dx, cube_corner2.y*dy, dz)

		local count_end0 = #vertex
		if triangulate then
			index[#index + 1] = {count_end0 - 5, count_end0 - 4, count_end0 - 1, count_end0 - 2}
			index[#index + 1] = {count_end0 - 4, count_end0 - 3, count_end0 - 0, count_end0 - 1}
		end

		local ring_angle = -i*90
		for j = 0, ring_steps0 do
			local a = math.rad((j/numring)* -360 + ring_angle)
			vertex[#vertex + 1] = Vector(math.sin(a)*(dx - dt), math.cos(a)*(dy - dt), -dz)
			vertex[#vertex + 1] = Vector(math.sin(a)*(dx - dt), math.cos(a)*(dy - dt), dz)
		end

		local count_end1 = #vertex
		if not nophys then
			physics[#physics + 1] = {
				vertex[count_end0 - 0],
				vertex[count_end0 - 3],
				vertex[count_end0 - 4],
				vertex[count_end0 - 1],
				vertex[count_end1 - 0],
				vertex[count_end1 - 1],
				vertex[count_end1 - ring_steps1*0.5],
				vertex[count_end1 - ring_steps1*0.5 - 1],
			}
			physics[#physics + 1] = {
				vertex[count_end0 - 2],
				vertex[count_end0 - 5],
				vertex[count_end0 - 4],
				vertex[count_end0 - 1],
				vertex[count_end1 - ring_steps1],
				vertex[count_end1 - ring_steps1 - 1],
				vertex[count_end1 - ring_steps1*0.5],
				vertex[count_end1 - ring_steps1*0.5 - 1],
			}
		end

		if triangulate then
			index[#index + 1] = {count_end0 - 1, count_end0 - 0, count_end1 - 0}
			index[#index + 1] = {count_end0 - 1, count_end1 - ring_steps1, count_end0 - 2}
			index[#index + 1] = {count_end0 - 4, count_end1 - 1, count_end0 - 3}
			index[#index + 1] = {count_end0 - 4, count_end0 - 5, count_end1 - ring_steps1 - 1}

			for j = 0, ring_steps0 - 1 do
				local count_end2 = count_end1 - j*2
				index[#index + 1] = {count_end0 - 1, count_end2, count_end2 - 2}
				index[#index + 1] = {count_end0 - 4, count_end2 - 3, count_end2 - 1}
				index[#index + 1] = {count_end2, count_end2 - 1, count_end2 - 3, count_end2 - 2}
			end

			if capped and i == numseg  - 1 then
				index[#index + 1] = {count_end0, count_end0 - 3, count_end1 - 1, count_end1}
			end
		end
	end

	return {vertex = vertex, index = index, physics = physics}
end)

----
addon.construct_register("cylinder", function(args, nophys, triangulate)
	local vertex, index, physics

	local maxseg = args.maxseg or 32
	if maxseg < 3 then maxseg = 3 elseif maxseg > 32 then maxseg = 32 end
	local numseg = args.numseg or 32
	if numseg < 1 then numseg = 1 elseif numseg > maxseg then numseg = maxseg end

	local dx = (args.dx or 1)*0.5
	local dy = (args.dy or 1)*0.5
	local dz = (args.dz or 1)*0.5

	local tx = 1 - (args.tx or 0)
	local ty = 1 - (args.ty or 0)

	vertex = {}
	if tx == 0 and ty == 0 then
		for i = 0, numseg do
			local a = math.rad((i/maxseg)* -360)
			vertex[#vertex + 1] = Vector(math.sin(a)*dx, math.cos(a)*dy, -dz)
		end
	else
		for i = 0, numseg do
			local a = math.rad((i/maxseg)* -360)
			vertex[#vertex + 1] = Vector(math.sin(a)*dx, math.cos(a)*dy, -dz)
			vertex[#vertex + 1] = Vector(math.sin(a)*(dx*tx), math.cos(a)*(dy*ty), dz)
		end
	end

	local c0 = #vertex
	local c1 = c0 + 1
	local c2 = c0 + 2

	vertex[#vertex + 1] = Vector(0, 0, -dz)
	vertex[#vertex + 1] = Vector(0, 0, dz)

	if triangulate then
		index = {}
		if tx == 0 and ty == 0 then
			for i = 1, c0 - 1 do
				index[#index + 1] = {i, i + 1, c2}
				index[#index + 1] = {i, c1, i + 1}
			end

			if numseg ~= maxseg then
				index[#index + 1] = {c0, c1, c2}
				index[#index + 1] = {c0 + 1, 1, c2}
			end
		else
			for i = 1, c0 - 2, 2 do
				index[#index + 1] = {i, i + 2, i + 3, i + 1}
				index[#index + 1] = {i, c1, i + 2}
				index[#index + 1] = {i + 1, i + 3, c2}
			end

			if numseg ~= maxseg then
				index[#index + 1] = {c1, c2, c0, c0 - 1}
				index[#index + 1] = {c1, 1, 2, c2}
			end
		end
	end

	if not nophys then
		if numseg ~= maxseg then
			physics = {{vertex[c1], vertex[c2]}, {vertex[c1], vertex[c2]}}
			if tx == 0 and ty == 0 then
				for i = 1, c0 do
					if (i - 1 <= maxseg*0.5) then
						table.insert(physics[1], vertex[i])
					end
					if (i - 1 >= maxseg*0.5) then
						table.insert(physics[2], vertex[i])
					end
				end
			else
				for i = 1, c0 do
					if i - (maxseg > 3 and 2 or 1) <= maxseg then
						table.insert(physics[1], vertex[i])
					end
					if i - 1 >= maxseg then
						table.insert(physics[2], vertex[i])
					end
				end
			end
		else
			physics = {vertex}
		end
	end

	return {vertex = vertex, index = index, physics = physics}
end)

----
addon.construct_register("dome", function(args, nophys, triangulate)
	args.isdome = true
	return addon.construct_get("sphere", args, nophys, triangulate)
end)

----
addon.construct_register("pyramid", function(args, nophys, triangulate)
	local vertex, index, physics

	local dx = (args.dx or 1)*0.5
	local dy = (args.dy or 1)*0.5
	local dz = (args.dz or 1)*0.5

	local tx = map(args.tx or 0, -1, 1, -2, 2)
	local ty = map(args.ty or 0, -1, 1, -2, 2)

	vertex = {
		Vector(dx, -dy, -dz),
		Vector(dx, dy, -dz),
		Vector(-dx, -dy, -dz),
		Vector(-dx, dy, -dz),
		Vector(-dx*tx, dy*ty, dz),
	}

	if triangulate then
		index = {
			{1, 2, 5},
			{2, 4, 5},
			{4, 3, 5},
			{3, 1, 5},
			{3, 4, 2, 1},
		}
	end

	if not nophys then
		physics = vertex
	end

	return {vertex = vertex, index = index, physics = {physics}}
end)

----
addon.construct_register("sphere", function(args, nophys, triangulate)
	local vertex, index, physics

	local numseg = 2*math.Round((args.numseg or 32)/2)
	if numseg < 4 then numseg = 4 elseif numseg > 32 then numseg = 32 end

	local dx = (args.dx or 1)*0.5
	local dy = (args.dy or 1)*0.5
	local dz = (args.dz or 1)*0.5

	local isdome = args.isdome

	if triangulate then
		vertex, index = {}, {}

		for y = 0, isdome and numseg*0.5 or numseg do
			local v = y/numseg
			local t = v*pi

			local cosPi = math.cos(t)
			local sinPi = math.sin(t)

			for x = 0, numseg  do
				local u = x/numseg
				local p = u*tau

				local cosTau = math.cos(p)
				local sinTau = math.sin(p)

				vertex[#vertex + 1] = Vector(-dx*cosTau*sinPi, dy*sinTau*sinPi, dz*cosPi)
			end

			if y > 0 then
				local i = #vertex - 2*(numseg + 1)
				while (i + numseg + 2) < #vertex do
					index[#index + 1] = {i + 1, i + 2, i + numseg + 3, i + numseg + 2}
					i = i + 1
				end
			end
		end

		if isdome then
			local buf = #vertex
			local cap = {}

			for i = 0, numseg do
				cap[#cap + 1] = i + buf - numseg
			end

			index[#index + 1] = cap
		end
	end

	if not nophys then
		local limit = 12
		if triangulate and numseg < limit then
			physics = vertex
		else
			local numseg = limit
			local numseg = numseg*0.5

			physics = {}
			for y = 0, isdome and numseg*0.5 or numseg do
				local v = y/numseg
				local t = v*pi

				local cosPi = math.cos(t)
				local sinPi = math.sin(t)

				for x = 0, numseg do
					local u = x/numseg
					local p = u*tau

					local cosTau = math.cos(p)
					local sinTau = math.sin(p)

					physics[#physics + 1] = Vector(-dx*cosTau*sinPi, dy*sinTau*sinPi, dz*cosPi)
				end
			end
		end
		if SERVER then
			vertex = physics
		end
	end

	return {vertex = vertex, index = index, physics = {physics}}
end)

----
addon.construct_register("torus", function(args, nophys, triangulate)
	local vertex, index, physics

	local maxseg = args.maxseg or 32
	if maxseg < 3 then maxseg = 3 elseif maxseg > 32 then maxseg = 32 end
	local numseg = args.numseg or 32
	if numseg < 1 then numseg = 1 elseif numseg > maxseg then numseg = maxseg end
	local numring = args.subdiv or 16
	if numring < 3 then numring = 3 elseif numring > 32 then numring = 32 end

	local dx = (args.dx or 1)*0.5
	local dy = (args.dy or 1)*0.5
	local dz = (args.dz or 1)*0.5
	local dt = math.min((args.dt or 1)*0.5, dx, dy)

	if dt == dx or dt == dy then
	end

	if triangulate then
		vertex = {}
		for j = 0, numring do
			for i = 0, maxseg do
				local u = i/maxseg*tau
				local v = j/numring*tau
				vertex[#vertex + 1] = Vector((dx + dt*math.cos(v))*math.cos(u), (dy + dt*math.cos(v))*math.sin(u), dz*math.sin(v))
			end
		end

		index = {}
		for j = 1, numring do
			for i = 1, numseg do
				index[#index + 1] = {(maxseg + 1)*j + i, (maxseg + 1)*(j - 1) + i, (maxseg + 1)*(j - 1) + i + 1, (maxseg + 1)*j + i + 1}
			end
		end

		if numseg ~= maxseg then
			local cap1 = {}
			local cap2 = {}

			for j = 1, numring do
				cap1[#cap1 + 1] = (maxseg + 1)*j + 1
				cap2[#cap2 + 1] = (maxseg + 1)*(numring - j) + numseg + 1
			end

			index[#index + 1] = cap1
			index[#index + 1] = cap2
		end
	end

	if not nophys then
		local numring = math.min(8, numring) -- we want a lower detailed physics model
		local pvertex = {}
		for j = 0, numring do
			for i = 0, maxseg do
				local u = i/maxseg*tau
				local v = j/numring*tau
				pvertex[#pvertex + 1] = Vector((dx + dt*math.cos(v))*math.cos(u), (dy + dt*math.cos(v))*math.sin(u), dz*math.sin(v))
			end
		end

		physics = {}
		for j = 1, numring do
			for i = 1, numseg do
				if not physics[i] then
					physics[i] = {}
				end
				local part = physics[i]
				part[#part + 1] = pvertex[(maxseg + 1)*j + i]
				part[#part + 1] = pvertex[(maxseg + 1)*(j - 1) + i]
				part[#part + 1] = pvertex[(maxseg + 1)*(j - 1) + i + 1]
				part[#part + 1] = pvertex[(maxseg + 1)*j + i + 1]
			end
		end
		if SERVER then
			vertex = pvertex
		end
	end

	return {vertex = vertex, index = index, physics = physics}
end)

----
addon.construct_register("tube", function(args, nophys, triangulate)
	local vertex, index, physics

	local maxseg = args.maxseg or 32
	if maxseg < 3 then maxseg = 3 elseif maxseg > 32 then maxseg = 32 end
	local numseg = args.numseg or 32
	if numseg < 1 then numseg = 1 elseif numseg > maxseg then numseg = maxseg end

	local dx = (args.dx or 1)*0.5
	local dy = (args.dy or 1)*0.5
	local dz = (args.dz or 1)*0.5
	local dt = math.min(args.dt or 1, dx, dy)

	if dt == dx or dt == dy then -- MAY NEED TO REFACTOR THIS IN THE FUTURE IF CYLINDER MODIFIERS ARE CHANGED
		return addon.construct_get("cylinder", args, nophys, triangulate)
	end

	local tx = 1 - (args.tx or 0)
	local ty = 1 - (args.ty or 0)
	local iscone = tx == 0 and ty == 0

	vertex = {}
	if iscone then
		for i = 0, numseg do
			local a = math.rad((i/maxseg)* -360)
			vertex[#vertex + 1] = Vector(math.sin(a)*dx, math.cos(a)*dy, -dz)
			vertex[#vertex + 1] = Vector(math.sin(a)*(dx - dt), math.cos(a)*(dy - dt), -dz)
		end
	else
		for i = 0, numseg do
			local a = math.rad((i/maxseg)* -360)
			vertex[#vertex + 1] = Vector(math.sin(a)*dx, math.cos(a)*dy, -dz)
			vertex[#vertex + 1] = Vector(math.sin(a)*(dx*tx), math.cos(a)*(dy*ty), dz)
			vertex[#vertex + 1] = Vector(math.sin(a)*(dx - dt), math.cos(a)*(dy - dt), -dz)
			vertex[#vertex + 1] = Vector(math.sin(a)*((dx - dt)*tx), math.cos(a)*((dy - dt)*ty), dz)
		end
	end

	local c0 = #vertex
	local c1 = c0 + 1
	local c2 = c0 + 2

	vertex[#vertex + 1] = Vector(0, 0, -dz)
	vertex[#vertex + 1] = Vector(0, 0, dz)

	if triangulate then
		index = {}
		if iscone then
			for i = 1, c0 - 2, 2 do
				index[#index + 1] = {i + 3, i + 2, i + 0, i + 1} -- bottom
				index[#index + 1] = {i + 0, i + 2, c2} -- outside
				index[#index + 1] = {i + 3, i + 1, c2} -- inside
			end

			if numseg ~= maxseg then
				local i = numseg*2 + 1
				index[#index + 1] = {i, i + 1, c2}
				index[#index + 1] = {2, 1, c2}
			end
		else
			for i = 1, c0 - 4, 4 do
				index[#index + 1] = {i + 0, i + 2, i + 6, i + 4} -- bottom
				index[#index + 1] = {i + 4, i + 5, i + 1, i + 0} -- outside
				index[#index + 1] = {i + 2, i + 3, i + 7, i + 6} -- inside
				index[#index + 1] = {i + 5, i + 7, i + 3, i + 1} -- top
			end

			if numseg ~= maxseg then
				local i = numseg*4 + 1
				index[#index + 1] = {i + 2, i + 3, i + 1, i + 0}
				index[#index + 1] = {1, 2, 4, 3}
			end
		end
	end

	if not nophys then
		physics = {}
		if iscone then
			for i = 1, c0 - 2, 2 do
				physics[#physics + 1] = {vertex[c2], vertex[i], vertex[i + 1], vertex[i + 2], vertex[i + 3]}
			end
		else
			for i = 1, c0 - 4, 4 do
				physics[#physics + 1] = {vertex[i], vertex[i + 1], vertex[i + 2], vertex[i + 3], vertex[i + 4], vertex[i + 5], vertex[i + 6], vertex[i + 7]}
			end
		end
	end

	return {vertex = vertex, index = index, physics = physics}
end)

----
addon.construct_register("wedge", function(args, nophys, triangulate)
	local vertex, index, physics

	local dx = (args.dx or 1)*0.5
	local dy = (args.dy or 1)*0.5
	local dz = (args.dz or 1)*0.5

	local tx = map(args.tx or 0, -1, 1, -2, 2)
	local ty = 1 - (args.ty or 0)

	if ty == 0 then
		vertex = {
			Vector(dx, -dy, -dz),
			Vector(dx, dy, -dz),
			Vector(-dx, -dy, -dz),
			Vector(-dx, dy, -dz),
			Vector(-dx*tx, 0, dz),
		}
	else
		vertex = {
			Vector(dx, -dy, -dz),
			Vector(dx, dy, -dz),
			Vector(-dx, -dy, -dz),
			Vector(-dx, dy, -dz),
			Vector(-dx*tx, dy*ty, dz),
			Vector(-dx*tx, -dy*ty, dz),
		}
	end

	if triangulate then
		if ty == 0 then
			index = {
				{1, 2, 5},
				{2, 4, 5},
				{4, 3, 5},
				{3, 1, 5},
				{3, 4, 2, 1},
			}
		else
			index = {
				{1, 2, 5, 6},
				{2, 4, 5},
				{4, 3, 6, 5},
				{3, 1, 6},
				{3, 4, 2, 1},
			}
		end
	end

	if not nophys then
		physics = vertex
	end

	return {vertex = vertex, index = index, physics = {physics}}
end)

----
addon.construct_register("wedge_corner", function(args, nophys, triangulate)
	local vertex, index, physics

	local dx = (args.dx or 1)*0.5
	local dy = (args.dy or 1)*0.5
	local dz = (args.dz or 1)*0.5

	local tx = map(args.tx or 0, -1, 1, -2, 2)
	local ty = map(args.ty or 0, -1, 1, 0, 2)

	vertex = {
		Vector(dx, dy, -dz),
		Vector(-dx, -dy, -dz),
		Vector(-dx, dy, -dz),
		Vector(-dx*tx, dy*ty, dz),
	}

	if triangulate then
		index = {
			{1, 3, 4},
			{2, 1, 4},
			{3, 2, 4},
			{1, 2, 3},
		}
	end

	if not nophys then
		physics = vertex
	end

	return {vertex = vertex, index = index, physics = {physics}}
end)







