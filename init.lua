-- watershedmini 0.2.2 by paramat
-- For latest stable Minetest and back to 0.4.8
-- Depends default
-- License: code WTFPL, textures CC BY-SA

-- map level to 4008, above clouds
-- xyz limits set to +/-2000
-- spawn player at map y

-- Parameters

local ZOOM = 16 -- Must be 2^n. Reduce octaves to avoid spread of highest octave being < 1

local XMIN = -2000 -- Map limits
local XMAX = 2000
local YMIN = 2000
local YMAX = 6000
local ZMIN = -2000
local ZMAX = 2000

local YWAT = 4008 -- Sea surface y

local TERCEN = YWAT - 128/ZOOM
local TERSCA = 512/ZOOM
local XLSAMP = 0.1
local BASAMP = 0.3
local MIDAMP = 0.1
local CANAMP = 0.4
local ATANAMP = 1.1
local BLENEXP = 2
local TRIVER = -0.028
local TSTREAM = -0.004
local TLAVA = 2

local HITET = 0.35
local LOTET = -0.35
local ICETET = -0.7
local HIHUT = 0.35
local LOHUT = -0.35

-- 3D noise for terrain

local np_terrain = {
	offset = 0,
	scale = 1,
	spread = {x=384/ZOOM, y=192/ZOOM, z=384/ZOOM},
	seed = 593,
	octaves = 4,
	persist = 0.67
}

-- 2D noise for mid terrain / streambed height

local np_mid = {
	offset = 0,
	scale = 1,
	spread = {x=768/ZOOM, y=768/ZOOM, z=768/ZOOM},
	seed = 85546,
	octaves = 5,
	persist = 0.5
}

-- 2D noise for base terrain / riverbed height

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
	octaves = 3,
	persist = 0.5
}

-- 3D noise for humidity

local np_humid = {
	offset = 0,
	scale = 1,
	spread = {x=1024/ZOOM, y=1024/ZOOM, z=1024/ZOOM},
	seed = -55500,
	octaves = 3,
	persist = 0.5
}

-- 2D noise for magma surface

local np_magma = {
	offset = 0,
	scale = 1,
	spread = {x=128/ZOOM, y=128/ZOOM, z=128/ZOOM},
	seed = -13,
	octaves = 2,
	persist = 0.5
}

-- Stuff

dofile(minetest.get_modpath("watershedmini").."/nodes.lua")

-- Set mapgen parameters

minetest.register_on_mapgen_init(function(mgparams)
	minetest.set_mapgen_params({mgname="singlenode"})
end)

-- Spawn player

function spawnplayer(player)
	player:setpos({x=0, y=4024, z=0})
end

minetest.register_on_newplayer(function(player)
	spawnplayer(player)
end)

minetest.register_on_respawnplayer(function(player)
	spawnplayer(player)
	return true
end)

-- On generated function

minetest.register_on_generated(function(minp, maxp, seed)
	if minp.x < XMIN or maxp.x > XMAX
	or minp.y < YMIN or maxp.y > YMAX
	or minp.z < ZMIN or maxp.z > ZMAX then
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
	local c_destone = minetest.get_content_id("default:desert_stone")
	local c_snowblock = minetest.get_content_id("default:snowblock")
	local c_ice = minetest.get_content_id("default:ice")
	local c_obsidian = minetest.get_content_id("default:obsidian")
	local c_lava = minetest.get_content_id("default:lava_source")
	
	local c_freshwater = minetest.get_content_id("watershedmini:freshwater")
	local c_stone = minetest.get_content_id("watershedmini:stone")
	local c_grass = minetest.get_content_id("watershedmini:grass")
	local c_drygrass = minetest.get_content_id("watershedmini:drygrass")
	local c_icydirt = minetest.get_content_id("watershedmini:icydirt")
	local c_appleaf = minetest.get_content_id("watershedmini:appleleaf")
	local c_needles = minetest.get_content_id("watershedmini:needles")
	local c_junleaf = minetest.get_content_id("watershedmini:jungleleaf")
	local c_acaleaf = minetest.get_content_id("watershedmini:acacialeaf")
	-- perlinmap stuff
	local sidelen = x1 - x0 + 1 -- chunk sidelength
	local chulens = {x=sidelen, y=sidelen, z=sidelen} -- chunk dimensions
	local minposxyz = {x=x0, y=y0, z=z0} -- 3D and 2D perlinmaps start from these co-ordinates
	local minposxz = {x=x0, y=z0}
	-- 3D and 2D perlinmaps
	local nvals_terrain = minetest.get_perlin_map(np_terrain, chulens):get3dMap_flat(minposxyz)
	local nvals_temp = minetest.get_perlin_map(np_temp, chulens):get3dMap_flat(minposxyz)
	local nvals_humid = minetest.get_perlin_map(np_humid, chulens):get3dMap_flat(minposxyz)
	
	local nvals_mid = minetest.get_perlin_map(np_mid, chulens):get2dMap_flat(minposxz)
	local nvals_base = minetest.get_perlin_map(np_base, chulens):get2dMap_flat(minposxz)
	local nvals_xlscale = minetest.get_perlin_map(np_xlscale, chulens):get2dMap_flat(minposxz)
	local nvals_magma = minetest.get_perlin_map(np_magma, chulens):get2dMap_flat(minposxz)
	
	-- mapgen loop
	local nixyz = 1 -- 3D and 2D perlinmap indexes
	local nixz = 1
	for z = z0, z1 do -- for each xy plane progressing northwards
		for y = y0, y1 do -- for each x row progressing upwards
			local vi = area:index(x0, y, z) -- voxelmanip index for first node in this x row
			for x = x0, x1 do -- for each node do
				local n_absterrain = math.abs(nvals_terrain[nixyz])
				local n_temp = nvals_temp[nixyz]
				local n_humid = nvals_humid[nixyz]
				
				local n_absmid = math.abs(nvals_mid[nixz])
				local n_absbase = math.abs(nvals_base[nixz])
				local n_xlscale = nvals_xlscale[nixz]
				local n_magma = nvals_magma[nixz]

				local n_invbase = (1 - n_absbase)
				local terblen = (math.max(n_invbase, 0)) ^ BLENEXP
				local grad = math.atan((TERCEN - y) / TERSCA) * ATANAMP
				local densitybase = n_invbase * BASAMP + n_xlscale * XLSAMP + grad
				local densitymid = n_absmid * MIDAMP + densitybase
				local canexp = 0.5 + terblen * 0.5
				local canamp = terblen * CANAMP
				local density = n_absterrain ^ canexp * canamp * n_absmid + densitymid

				local triver = TRIVER * n_absbase -- river threshold
				local tstream = TSTREAM * (1 - n_absmid) -- stream threshold
				local tlava = TLAVA * (1 - n_magma ^ 4 * terblen ^ 16 * 0.6) -- lava threshold
				
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

				if densitybase >= tlava then -- lava
					if densitybase >= 0 then
						data[vi] = c_lava
					end
				elseif densitybase >= tlava - math.min(0.6 + density * 6, 0.6) and density < 0 then -- obsidian
					data[vi] = c_obsidian
				elseif density >= 0 then -- ground
					if y < YWAT then
						data[vi] = c_sand
					elseif biome == 2 then
						data[vi] = c_snowblock
					elseif biome == 3 then
						data[vi] = c_needles
					elseif grad < -1 then
						if biome == 7 then
							data[vi] = c_destone
						else
							data[vi] = c_stone
						end
					elseif biome == 1 then
						data[vi] = c_icydirt
					elseif biome == 4 then
						data[vi] = c_drygrass
					elseif biome == 5 then
						data[vi] = c_appleaf
					elseif biome == 6 then
						data[vi] = c_grass
					elseif biome == 7 then
						data[vi] = c_desand
					elseif biome == 8 then
						data[vi] = c_acaleaf
					elseif biome == 9 then
						data[vi] = c_junleaf
					end
				elseif y <= YWAT then -- sea water
					if n_temp <= ICETET then
						data[vi] = c_ice
					else
						data[vi] = c_water
					end
				elseif densitybase >= triver then -- river water
					data[vi] = c_freshwater
				elseif densitybase >= tstream then -- stream water
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
