
local math =  math
local table = table
local Vector = Vector

prop2mesh.primitive = {}

prop2mesh.primitive.wedge_corner = function(vars)
	local dx = math.Clamp(math.abs(vars.dx or 1), 1, 512)*0.5
	local dy = math.Clamp(math.abs(vars.dy or 1), 1, 512)*0.5
	local dz = math.Clamp(math.abs(vars.dz or 1), 1, 512)*0.5

	local vertices = {
		Vector(dx, dy, -dz),
		Vector(-dx, -dy, -dz),
		Vector(-dx, dy, -dz),
		Vector(-dx, dy, dz),
	}

	local indices = {
		 {1,3,4},
		 {2,1,4},
		 {3,2,4},
		 {1,2,3},
	}

	return prop2mesh.triangulate(vertices, indices)
end

prop2mesh.primitive.wedge = function(vars)
	local dx = math.Clamp(math.abs(vars.dx or 1), 1, 512)*0.5
	local dy = math.Clamp(math.abs(vars.dy or 1), 1, 512)*0.5
	local dz = math.Clamp(math.abs(vars.dz or 1), 1, 512)*0.5

	local vertices = {
		Vector(dx, -dy, -dz),
		Vector(dx, dy, -dz),
		Vector(-dx, -dy, -dz),
		Vector(-dx, dy, -dz),
		Vector(-dx, dy, dz),
		Vector(-dx, -dy, dz),
	}

	local indices = {
		{1,2,5,6},
		{2,4,5},
		{4,3,6,5},
		{3,1,6},
		{3,4,2,1},
	}

	return prop2mesh.triangulate(vertices, indices)
end

prop2mesh.primitive.pyramid = function(vars)
	local dx = math.Clamp(math.abs(vars.dx or 1), 1, 512)*0.5
	local dy = math.Clamp(math.abs(vars.dy or 1), 1, 512)*0.5
	local dz = math.Clamp(math.abs(vars.dz or 1), 1, 512)*0.5

	local vertices = {
		Vector(dx, -dy, -dz),
		Vector(dx, dy, -dz),
		Vector(-dx, -dy, -dz),
		Vector(-dx, dy, -dz),
		Vector(0, 0, dz),
	}

	local indices = {
		{1,2,5},
		{2,4,5},
		{4,3,5},
		{3,1,5},
		{3,4,2,1},
	}

	return prop2mesh.triangulate(vertices, indices)
end

prop2mesh.primitive.cube = function(vars)
	local dx = math.Clamp(math.abs(vars.dx or 1), 1, 512)*0.5
	local dy = math.Clamp(math.abs(vars.dy or 1), 1, 512)*0.5
	local dz = math.Clamp(math.abs(vars.dz or 1), 1, 512)*0.5

	local vertices = {
		Vector(dx, -dy, -dz),
		Vector(dx, dy, -dz),
		Vector(dx, dy, dz),
		Vector(dx, -dy, dz),
		Vector(-dx, -dy, -dz),
		Vector(-dx, dy, -dz),
		Vector(-dx, dy, dz),
		Vector(-dx, -dy, dz),
	}

	local indices = {
		{1,2,3,4},
		{2,6,7,3},
		{6,5,8,7},
		{5,1,4,8},
		{4,3,7,8},
		{5,6,2,1},
	}

	return prop2mesh.triangulate(vertices, indices)
end

prop2mesh.primitive.tube = function(vars)
	local maxsegments = math.Clamp(math.abs(math.floor(vars.maxsegments or 32)), 3, 32)
	local numsegments = math.Clamp(math.abs(math.floor(vars.numsegments or maxsegments)), 1, maxsegments)

	local dx1 = math.Clamp(math.abs(vars.dx or 1), 1, 512)*0.5
	local dx2 = math.Clamp(dx1 - math.abs(vars.thickness or 1), 0, dx1)
	local dy1 = math.Clamp(math.abs(vars.dy or 1), 1, 512)*0.5
	local dy2 = math.Clamp(dy1 - math.abs(vars.thickness or 1), 0, dy1)
	local dz = math.Clamp(math.abs(vars.dz or 1), 1, 512)*0.5

	local vertices = {}
	for i = 0, numsegments do
		local a = math.rad((i / maxsegments) * -360)
		vertices[#vertices + 1] = Vector(math.sin(a)*dx1, math.cos(a)*dy1, dz)
		vertices[#vertices + 1] = Vector(math.sin(a)*dx1, math.cos(a)*dy1, -dz)
		vertices[#vertices + 1] = Vector(math.sin(a)*dx2, math.cos(a)*dy2, dz)
		vertices[#vertices + 1] = Vector(math.sin(a)*dx2, math.cos(a)*dy2, -dz)
	end

	local indices = {}
	for i = 1, #vertices - 4, 4 do
		indices[#indices + 1] = {i + 0, i + 4, i + 6, i + 2}
		indices[#indices + 1] = {i + 4, i + 0, i + 1, i + 5}
		indices[#indices + 1] = {i + 2, i + 6, i + 7, i + 3}
		indices[#indices + 1] = {i + 5, i + 1, i + 3, i + 7}
	end

	if numsegments ~= maxsegments then
		local i = numsegments*4 + 1
		indices[#indices + 1] = {i + 2, i + 0, i + 1, i + 3}
		indices[#indices + 1] = {1, 3, 4, 2}
	end

	return prop2mesh.triangulate(vertices, indices)
end

prop2mesh.primitive.cylinder = function(vars)
	local maxsegments = math.Clamp(math.abs(math.floor(vars.maxsegments or 32)), 3, 32)
	local numsegments = math.Clamp(math.abs(math.floor(vars.numsegments or maxsegments)), 1, maxsegments)

	local dx = math.Clamp(math.abs(vars.dx or 1), 1, 512)*0.5
	local dy = math.Clamp(math.abs(vars.dy or 1), 1, 512)*0.5
	local dz = math.Clamp(math.abs(vars.dz or 1), 1, 512)*0.5

	local vertices = {}
	for i = 0, numsegments do
		local a = math.rad((i / maxsegments) * -360)
		vertices[#vertices + 1] = Vector(math.sin(a)*dx, math.cos(a)*dy, dz)
		vertices[#vertices + 1] = Vector(math.sin(a)*dx, math.cos(a)*dy, -dz)
		vertices[#vertices + 1] = Vector(0, 0, dz)
		vertices[#vertices + 1] = Vector(0, 0, -dz)
	end

	local indices = {}
	for i = 1, #vertices - 4, 4 do
		indices[#indices + 1] = {i + 0, i + 4, i + 6, i + 2}
		indices[#indices + 1] = {i + 4, i + 0, i + 1, i + 5}
		indices[#indices + 1] = {i + 2, i + 6, i + 7, i + 3}
		indices[#indices + 1] = {i + 5, i + 1, i + 3, i + 7}
	end

	if numsegments ~= maxsegments then
		local i = numsegments*4 + 1
		indices[#indices + 1] = {i + 2, i + 0, i + 1, i + 3}
		indices[#indices + 1] = {1, 3, 4, 2}
	end

	return prop2mesh.triangulate(vertices, indices)
end

local arc = math.pi*2

prop2mesh.primitive.torus = function(vars)
	local maxsegments = math.Clamp(math.abs(math.floor(vars.maxsegments or 32)), 3, 32)
	local numsegments = math.Clamp(math.abs(math.floor(vars.numsegments or maxsegments)), 1, maxsegments)
	local numrings = math.Clamp(math.abs(math.floor(vars.numrings or 16)), 3, 32)

	local rad_x1 = math.Clamp(math.abs(vars.dx or 1), 1, 512)*0.5
	local rad_x2 = math.Clamp(math.abs(vars.thickness or 1), 0.5, 512)
	local rad_y1 = math.Clamp(math.abs(vars.dy or 1), 1, 512)*0.5
	local rad_y2 = math.Clamp(math.abs(vars.thickness or 1), 0.5, 512)
	local rad_z = math.Clamp(math.abs(vars.dz or 1), 1, 512)*0.5

	local vertices = {}
	for j = 0, numrings do
		for i = 0, maxsegments do
			local u = i / maxsegments * arc
			local v = j / numrings * arc
			vertices[#vertices + 1] = Vector((rad_x1 + rad_x2*math.cos(v))*math.cos(u), (rad_y1 + rad_y2*math.cos(v))*math.sin(u), rad_z*math.sin(v))
		end
	end

	local indices = {}
	for j = 1, numrings do
		for i = 1, numsegments do
			indices[#indices + 1] = {(maxsegments + 1)*j + i, (maxsegments + 1)*(j - 1) + i, (maxsegments + 1)*(j - 1) + i + 1, (maxsegments + 1)*j + i + 1}
		end
	end

	if numsegments ~= maxsegments then
		local cap1 = {}
		local cap2 = {}

		for j = 1, numrings do
			cap1[#cap1 + 1] = (maxsegments + 1)*j + 1
			cap2[#cap2 + 1] = (maxsegments + 1)*(numrings - j) + numsegments + 1
		end

		indices[#indices + 1] = cap1
		indices[#indices + 1] = cap2
	end

	return prop2mesh.triangulate(vertices, indices)
end
