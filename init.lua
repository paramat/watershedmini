-- watershedmini 0.1.0 by paramat
-- For latest stable Minetest and back to 0.4.8
-- Depends default
-- License: code WTFPL, textures CC BY-SA

-- Parameters

local ZOOM = 32

local YMIN = -33000 -- Approximate base of realm stone
local YMAX = 33000 -- Approximate top of atmosphere / mountains / floatlands
local TERCEN = -160/ZOOM -- Terrain 'centre', average seabed level
local YWAT = 0 -- Sea surface y

local TERSCA = 512/ZOOM -- Vertical terrain scale
local XLSAMP = 0.2 -- Extra large scale height variation amplitude
local BASAMP = 0.4 -- Base terrain amplitude
local CANAMP = 0.4 -- Canyon terrain maximum amplitude
local ATANAMP = 1.1 -- Arctan function amplitude, smaller = more and larger floatlands above ridges

local TRIV = -0.02 -- Maximum densitybase threshold for river water

local HITET = 0.35 -- High temperature threshold
local LOTET = -0.35 -- Low ..
local ICETET = -0.7 -- Ice ..
local HIHUT = 0.35 -- High humidity threshold
local LOHUT = -0.35 -- Low ..

-- 3D noise for rough terrain

local np_rough = {
	offset = 0,
	scale = 1,
	spread = {x=512/ZOOM, y=512/ZOOM, z=512/ZOOM},
	seed = 593,
	octaves = 4,
	persist = 0.67
}

-- 3D noise for smooth terrain

local np_smooth = {
	offset = 0,
	scale = 1,
	spread = {x=512/ZOOM, y=512/ZOOM, z=512/ZOOM},
	seed = 593,
	octaves = 4,
	persist = 0.33
}

-- 2D noise for base terrain / riverbed height, terrain blend, river and river sand depth

local np_base = {
	offset = 0,
	scale = 1,
	spread = {x=4096/ZOOM, y=4096/ZOOM, z=4096/ZOOM},
	seed = 8890,
	octaves = 3,
	persist = 0.33
}

-- 2D noise for extra large scale height variation

local np_xlscale = {
	offset = 0,
	scale = 1,
	spread = {x=8192/ZOOM, y=8192/ZOOM, z=8192/ZOOM},
	seed = -72,
	octaves = 3,
	persist = 0.33
}

-- 3D noise for temperature

local np_temp = {
	offset = 0,
	scale = 1,
	spread = {x=1024/ZOOM, y=1024/ZOOM, z=1024/ZOOM},
	seed = 9130,
	octaves = 2,
	persist = 0.5
}

-- 3D noise for humidity

local np_humid = {
	offset = 0,
	scale = 1,
	spread = {x=1024/ZOOM, y=1024/ZOOM, z=1024/ZOOM},
	seed = -55500,
	octaves = 2,
	persist = 0.5
}

-- Stuff

dofile(minetest.get_modpath("watershedmini").."/nodes.lua")

-- Set mapgen parameters

minetest.register_on_mapgen_init(function(mgparams)
	minetest.set_mapgen_params({mgname="singlenode"})
end)

-- On generated function

minetest.register_on_generated(function(minp, maxp, seed)
	if minp.y < YMIN or maxp.y > YMAX then
		return
	end

	local t1 = os.clock()
	local x1 = maxp.x
	local y1 = maxp.y
	local z1 = maxp.z
	local x0 = minp.x
	local y0 = minp.y
	local z0 = minp.z
	
	print ("[watershedmini] chunk minp ("..x0.." "..y0.." "..z0..")")
	-- voxelmanip stuff
	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip") -- min, max points for emerged area/voxelarea
	local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax} -- voxelarea helper for indexes
	local data = vm:get_data() -- get flat array of voxelarea content ids
	-- content ids
	local c_air = minetest.get_content_id("air")
	local c_water = minetest.get_content_id("default:water_source")
	local c_sand = minetest.get_content_id("default:sand")
	local c_desand = minetest.get_content_id("default:desert_sand")
	local c_snowblock = minetest.get_content_id("default:snowblock")
	local c_ice = minetest.get_content_id("default:ice")
	
	local c_freshwater = minetest.get_content_id("watershedmini:freshwater")
	local c_grass = minetest.get_content_id("watershedmini:grass")
	local c_drygrass = minetest.get_content_id("watershedmini:drygrass")
	local c_icydirt = minetest.get_content_id("watershedmini:icydirt")
	local c_appleaf = minetest.get_content_id("watershedmini:appleleaf")
	local c_junleaf = minetest.get_content_id("watershedmini:jungleleaf")
	-- perlinmap stuff
	local sidelen = x1 - x0 + 1 -- chunk sidelength
	local chulens = {x=sidelen, y=sidelen, z=sidelen} -- chunk dimensions
	local minposxyz = {x=x0, y=y0, z=z0} -- 3D and 2D perlinmaps start from these co-ordinates
	local minposxz = {x=x0, y=z0}
	-- 3D and 2D perlinmaps
	local nvals_rough = minetest.get_perlin_map(np_rough, chulens):get3dMap_flat(minposxyz)
	local nvals_smooth = minetest.get_perlin_map(np_smooth, chulens):get3dMap_flat(minposxyz)
	local nvals_temp = minetest.get_perlin_map(np_temp, chulens):get3dMap_flat(minposxyz)
	local nvals_humid = minetest.get_perlin_map(np_humid, chulens):get3dMap_flat(minposxyz)
	
	local nvals_base = minetest.get_perlin_map(np_base, chulens):get2dMap_flat(minposxz)
	local nvals_xlscale = minetest.get_perlin_map(np_xlscale, chulens):get2dMap_flat(minposxz)
	
	-- mapgen loop
	local nixyz = 1 -- 3D and 2D perlinmap indexes
	local nixz = 1
	for z = z0, z1 do -- for each xy plane progressing northwards
		for y = y0, y1 do -- for each x row progressing upwards
			local vi = area:index(x0, y, z) -- voxelmanip index for first node in this x row
			for x = x0, x1 do -- for each node do
				local n_rough = nvals_rough[nixyz]
				local n_smooth = nvals_smooth[nixyz]
				local n_temp = nvals_temp[nixyz]
				local n_humid = nvals_humid[nixyz]
				
				local n_base = nvals_base[nixz]
				local n_xlscale = nvals_xlscale[nixz]

				local grad = math.atan((TERCEN - y) / TERSCA) * ATANAMP
				local densitybase = (1 - math.abs(n_base)) * BASAMP + n_xlscale * XLSAMP + grad
				local terblen = math.max(1 - math.abs(n_base), 0)
				local terblenexp = terblen ^ 2
				local canexp = 0.5 + terblenexp
				local canamp = 0.02 + terblenexp * 0.4
				local densitycan =
				(math.abs(n_rough * terblenexp + n_smooth * (1 - terblenexp))) ^ canexp * canamp
				local density = densitybase + densitycan
				-- other values
				local triv = TRIV * (1 - terblen) -- river threshold
				
				local biome = false -- select biome for node
				if n_temp < LOTET then
					if n_humid < LOHUT then
						biome = 1 -- tundra
					elseif n_humid > HIHUT then
						biome = 3 -- taiga
					else
						biome = 2 -- snowy plains
					end
				elseif n_temp > HITET then
					if n_humid < LOHUT then
						biome = 7 -- desert
					elseif n_humid > HIHUT then
						biome = 9 -- rainforest
					else
						biome = 8 -- savanna
					end
				else
					if n_humid < LOHUT then
						biome = 4 -- dry grassland
					elseif n_humid > HIHUT then
						biome = 6 -- deciduous forest
					else
						biome = 5 -- grassland
					end
				end

				if density >= 0 then -- ground
					if y < YWAT then
						data[vi] = c_sand
					elseif biome == 1 then
						data[vi] = c_icydirt
					elseif biome == 2 or biome == 3 then
						data[vi] = c_snowblock
					elseif biome == 4 then
						data[vi] = c_drygrass
					elseif biome == 5 then
						data[vi] = c_appleaf
					elseif biome == 6 then
						data[vi] = c_grass
					elseif biome == 7 then
						data[vi] = c_desand
					elseif biome == 8 then
						data[vi] = c_drygrass
					elseif biome == 9 then
						data[vi] = c_junleaf
					end
				elseif y <= YWAT then -- sea water
					if n_temp <= ICETET then
						data[vi] = c_ice
					else
						data[vi] = c_water
					end
				elseif densitybase >= triv then -- river water
					data[vi] = c_freshwater
				end

				nixyz = nixyz + 1 -- increment perlinmap and voxelarea indexes along x row
				nixz = nixz + 1
				vi = vi + 1
			end
			nixz = nixz - 80
		end
		nixz = nixz + 80
	end
	-- voxelmanip stuff
	vm:set_data(data)
	vm:set_lighting({day=0, night=0})
	vm:calc_lighting()
	vm:write_to_map(data)
	
	local chugent = math.ceil((os.clock() - t1) * 1000) -- chunk generation time
	print ("[watershedmini] "..chugent.." ms")
end)
