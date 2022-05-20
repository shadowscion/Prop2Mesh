

----------------------------------------------------------------
prop2mesh.primitive = {}

local addon = prop2mesh.primitive
local shapes = {}
addon.primitive_shapes = shapes

local function primitive_build(vars)
	if not shapes[vars.type] then
		return false
	end
	local shape = shapes[vars.type](vars, true)
	if not shape then
		return false
	end
	return addon.primitive_triangulate(shape.vertex, shape.index)
end
addon.primitive_build = primitive_build

local function primitive_triangulate(vertices, indices)
	local uv = 1/48
	local tris = {}
	for k, face in ipairs(indices) do
		local t1 = face[1]
		local t2 = face[2]
		for j = 3, #face do
			local t3 = face[j]
			local v1, v2, v3 = vertices[t1], vertices[t3], vertices[t2]
			local normal = (v3 - v1):Cross(v2 - v1)
			normal:Normalize()

			v1 = {pos = v1, normal = normal}
			v2 = {pos = v2, normal = normal}
			v3 = {pos = v3, normal = normal}

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

			tris[#tris + 1] = v1
			tris[#tris + 1] = v2
			tris[#tris + 1] = v3
			t2 = t3
		end
	end
	return tris
end
addon.primitive_triangulate = primitive_triangulate


----------------------------------------------------------------
local math = math
local pi = math.pi
local tau = math.pi*2
local Vector = Vector

local function map(x, in_min, in_max, out_min, out_max)
    return (x - in_min)*(out_max - out_min)/(in_max - in_min) + out_min
end

local function primitive_triangulate(vertices, indices)
	local uv = 1/48
	local tris = {}
	for k, face in ipairs(indices) do
		local t1 = face[1]
		local t2 = face[2]
		for j = 3, #face do
			local t3 = face[j]
			local v1, v2, v3 = vertices[t1], vertices[t3], vertices[t2]
			local normal = (v3 - v1):Cross(v2 - v1)
			normal:Normalize()

			v1 = {pos = v1, normal = normal}
			v2 = {pos = v2, normal = normal}
			v3 = {pos = v3, normal = normal}

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

			tris[#tris + 1] = v1
			tris[#tris + 1] = v2
			tris[#tris + 1] = v3
			t2 = t3
		end
	end
	return tris
end
addon.primitive_triangulate = primitive_triangulate


----------------------------------------------------------------
--[[
local name = "generic"
shapes[name] = function(vars, nophys)
	local vertex, index, phys

	--local dx = (vars.dx or 1)*0.5
	--local dy = (vars.dy or 1)*0.5
	--local dz = (vars.dz or 1)*0.5

	if CLIENT then

	end

	if not nophys then

	end

	return {vertex = vertex, index = index, phys = {phys}}
end
]]


----------------------------------------------------------------
local name = "cube"
shapes[name] = function(vars, nophys)
	local vertex, index, phys

	local dx = (vars.dx or 1)*0.5
	local dy = (vars.dy or 1)*0.5
	local dz = (vars.dz or 1)*0.5

	local tx = 1 - (vars.tx or 0)
	local ty = 1 - (vars.ty or 0)

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

	if CLIENT then
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
		phys = vertex
	end

	return {vertex = vertex, index = index, phys = {phys}}
end


----------------------------------------------------------------
local name = "wedge"
shapes[name] = function(vars, nophys)
	local vertex, index, phys

	local dx = (vars.dx or 1)*0.5
	local dy = (vars.dy or 1)*0.5
	local dz = (vars.dz or 1)*0.5

	local tx = map(vars.tx or 0, -1, 1, -2, 2)
	local ty = 1 - (vars.ty or 0)

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

	if CLIENT then
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
		phys = vertex
	end

	return {vertex = vertex, index = index, phys = {phys}}
end


----------------------------------------------------------------
local name = "wedge_corner"
shapes[name] = function(vars, nophys)
	local vertex, index, phys

	local dx = (vars.dx or 1)*0.5
	local dy = (vars.dy or 1)*0.5
	local dz = (vars.dz or 1)*0.5

	local tx = map(vars.tx or 0, -1, 1, -2, 2)
	local ty = map(vars.ty or 0, -1, 1, 0, 2)

	vertex = {
		Vector(dx, dy, -dz),
		Vector(-dx, -dy, -dz),
		Vector(-dx, dy, -dz),
		Vector(-dx*tx, dy*ty, dz),
	}

	if CLIENT then
		index = {
			{1, 3, 4},
			{2, 1, 4},
			{3, 2, 4},
			{1, 2, 3},
		}
	end

	if not nophys then
		phys = vertex
	end

	return {vertex = vertex, index = index, phys = {phys}}
end


----------------------------------------------------------------
local name = "pyramid"
shapes[name] = function(vars, nophys)
	local vertex, index, phys

	local dx = (vars.dx or 1)*0.5
	local dy = (vars.dy or 1)*0.5
	local dz = (vars.dz or 1)*0.5

	local tx = map(vars.tx or 0, -1, 1, -2, 2)
	local ty = map(vars.ty or 0, -1, 1, -2, 2)

	vertex = {
		Vector(dx, -dy, -dz),
		Vector(dx, dy, -dz),
		Vector(-dx, -dy, -dz),
		Vector(-dx, dy, -dz),
		Vector(-dx*tx, dy*ty, dz),
	}

	if CLIENT then
		index = {
			{1, 2, 5},
			{2, 4, 5},
			{4, 3, 5},
			{3, 1, 5},
			{3, 4, 2, 1},
		}
	end

	if not nophys then
		phys = vertex
	end

	return {vertex = vertex, index = index, phys = {phys}}
end


----------------------------------------------------------------
local name = "cone"
shapes[name] = function(vars, nophys)
	local vertex, index, phys

	local maxseg = vars.maxseg or 32
	if maxseg < 3 then maxseg = 3 elseif maxseg > 32 then maxseg = 32 end
	local numseg = vars.numseg or 32
	if numseg < 1 then numseg = 1 elseif numseg > maxseg then numseg = maxseg end

	local dx = (vars.dx or 1)*0.5
	local dy = (vars.dy or 1)*0.5
	local dz = (vars.dz or 1)*0.5

	local tx = map(vars.tx or 0, -1, 1, -2, 2)
	local ty = map(vars.ty or 0, -1, 1, -2, 2)

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

	if CLIENT then
		index = {}
		for i = 1, c0 do
			index[#index + 1] = {i, i + 1, c2}
			if i < c0 then
				index[#index + 1] = {i, c1, i + 1}
			end
		end

		if numseg ~= maxseg then
			index[#index + 1] = {c0, c1, c2}
			index[#index + 1] = {c0 + 1, 1, c2}
		end
	end

	if not nophys then
		if numseg ~= maxseg then
			phys = {{vertex[c1], vertex[c2]}, {vertex[c1], vertex[c2]}}
			for i = 1, c0 do
				if (i - 1 <= maxseg*0.5) then
					table.insert(phys[1], vertex[i])
				end
				if (i - 1 >= maxseg*0.5) then
					table.insert(phys[2], vertex[i])
				end
			end
		else
			phys = {vertex}
		end
	end

	return {vertex = vertex, index = index, phys = phys}
end


----------------------------------------------------------------
local name = "cylinder"
shapes[name] = function(vars, nophys)
	local vertex, index, phys

	local maxseg = vars.maxseg or 32
	if maxseg < 3 then maxseg = 3 elseif maxseg > 32 then maxseg = 32 end
	local numseg = vars.numseg or 32
	if numseg < 1 then numseg = 1 elseif numseg > maxseg then numseg = maxseg end

	local dx = (vars.dx or 1)*0.5
	local dy = (vars.dy or 1)*0.5
	local dz = (vars.dz or 1)*0.5

	local tx = 1 - (vars.tx or 0)
	local ty = 1 - (vars.ty or 0)

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

	if CLIENT then
		index = {}
		if tx == 0 and ty == 0 then
			for i = 1, c0 do
				index[#index + 1] = {i, i + 1, c2}
				if i < c0 then
					index[#index + 1] = {i, c1, i + 1}
				end
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
			phys = {{vertex[c1], vertex[c2]}, {vertex[c1], vertex[c2]}}
			if tx == 0 and ty == 0 then
				for i = 1, c0 do
					if (i - 1 <= maxseg*0.5) then
						table.insert(phys[1], vertex[i])
					end
					if (i - 1 >= maxseg*0.5) then
						table.insert(phys[2], vertex[i])
					end
				end
			else
				for i = 1, c0 do
					if i - (maxseg > 3 and 2 or 1) <= maxseg then
						table.insert(phys[1], vertex[i])
					end
					if i - 1 >= maxseg then
						table.insert(phys[2], vertex[i])
					end
				end
			end
		else
			phys = {vertex}
		end
	end

	return {vertex = vertex, index = index, phys = phys}
end


----------------------------------------------------------------
local name = "tube"
shapes[name] = function(vars, nophys)
	local vertex, index, phys

	local maxseg = vars.maxseg or 32
	if maxseg < 3 then maxseg = 3 elseif maxseg > 32 then maxseg = 32 end
	local numseg = vars.numseg or 32
	if numseg < 1 then numseg = 1 elseif numseg > maxseg then numseg = maxseg end

	local dx = (vars.dx or 1)*0.5
	local dy = (vars.dy or 1)*0.5
	local dz = (vars.dz or 1)*0.5
	local dt = math.min(vars.dt or 1, dx, dy)

	if dt == dx or dt == dy then -- MAY NEED TO REFACTOR THIS IN THE FUTURE IF CYLINDER MODIFIERS ARE CHANGED
		return shapes["cylinder"](vars, nophys)
	end

	local tx = 1 - (vars.tx or 0)
	local ty = 1 - (vars.ty or 0)
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

	if CLIENT then
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
		phys = {}
		if iscone then
			for i = 1, c0 - 2, 2 do
				phys[#phys + 1] = {vertex[c2], vertex[i], vertex[i + 1], vertex[i + 2], vertex[i + 3]}
			end
		else
			for i = 1, c0 - 4, 4 do
				phys[#phys + 1] = {vertex[i], vertex[i + 1], vertex[i + 2], vertex[i + 3], vertex[i + 4], vertex[i + 5], vertex[i + 6], vertex[i + 7]}
			end
		end
	end

	return {vertex = vertex, index = index, phys = phys}
end


----------------------------------------------------------------
local name = "torus"
shapes[name] = function(vars, nophys)
	local vertex, index, phys

	local maxseg = vars.maxseg or 32
	if maxseg < 3 then maxseg = 3 elseif maxseg > 32 then maxseg = 32 end
	local numseg = vars.numseg or 32
	if numseg < 1 then numseg = 1 elseif numseg > maxseg then numseg = maxseg end
	local numring = vars.numring or 16
	if numring < 3 then numring = 3 elseif numring > 32 then numring = 32 end

	local dx = (vars.dx or 1)*0.5
	local dy = (vars.dy or 1)*0.5
	local dz = (vars.dz or 1)*0.5
	local dt = math.min((vars.dt or 1)*0.5, dx, dy)

	if dt == dx or dt == dy then
	end

	if CLIENT then
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

		phys = {}
		for j = 1, numring do
			for i = 1, numseg do
				if not phys[i] then
					phys[i] = {}
				end
				local part = phys[i]
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

	return {vertex = vertex, index = index, phys = phys}
end


----------------------------------------------------------------
local name = "sphere"
shapes[name] = function(vars, nophys)
	local vertex, index, phys

	local numseg = 2*math.Round((vars.numseg or 32)/2)
	if numseg < 4 then numseg = 4 elseif numseg > 32 then numseg = 32 end

	local dx = (vars.dx or 1)*0.5
	local dy = (vars.dy or 1)*0.5
	local dz = (vars.dz or 1)*0.5

	local isdome = vars.isdome

	if CLIENT then
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
		if CLIENT and numseg < limit then
			phys = vertex
		else
			local numseg = limit
			local numseg = numseg*0.5

			phys = {}
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

					phys[#phys + 1] = Vector(-dx*cosTau*sinPi, dy*sinTau*sinPi, dz*cosPi)
				end
			end
		end
		if SERVER then
			vertex = phys
		end
	end

	return {vertex = vertex, index = index, phys = {phys}}
end


----------------------------------------------------------------
local name = "dome"
shapes[name] = function(vars, nophys)
	vars.isdome = true
	return shapes["sphere"](vars, nophys)
end


----------------------------------------------------------------
local name = "cube_tube"
shapes[name] = function(vars, nophys)
	local vertex, index, phys

	local dx = (vars.dx or 1)*0.5
	local dy = (vars.dy or 1)*0.5
	local dz = (vars.dz or 1)*0.5
	local dt = math.min(vars.dt or 1, dx, dy)

	if dt == dx or dt == dy then
		return shapes["cube"](vars, nophys)
	end

	local numseg = vars.numseg or 4
	if numseg > 4 then numseg = 4 elseif numseg < 1 then numseg = 1 end

	local numring = 4*math.Round((vars.numring or 32)/4)
	if numring < 4 then numring = 4 elseif numring > 32 then numring = 32 end

	local cube_angle = Angle(0, 90, 0)
	local cube_corner0 = Vector(1, 0, 0)
	local cube_corner1 = Vector(1, 1, 0)
	local cube_corner2 = Vector(0, 1, 0)

	local ring_steps0 = numring/4
	local ring_steps1 = numring/2
	local capped = numseg ~= 4
	if CLIENT then
		index = capped and {{8, 7, 1, 4}} or {}
	end

	vertex = {}

	if not nophys then
		phys = {}
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
		if CLIENT then
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
			phys[#phys + 1] = {
				vertex[count_end0 - 0],
				vertex[count_end0 - 3],
				vertex[count_end0 - 4],
				vertex[count_end0 - 1],
				vertex[count_end1 - 0],
				vertex[count_end1 - 1],
				vertex[count_end1 - ring_steps1*0.5],
				vertex[count_end1 - ring_steps1*0.5 - 1],
			}
			phys[#phys + 1] = {
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

		if CLIENT then
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

	return {vertex = vertex, index = index, phys = phys}
end
