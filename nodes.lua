minetest.register_node("watershedmini:stone", {
	description = "Stone",
	tiles = {"default_stone.png"},
	is_ground_content = false,
	groups = {cracky=3},
	drop = "default:cobble",
	sounds = default.node_sound_stone_defaults(),
})

minetest.register_node("watershedmini:appleleaf", {
	description = "Appletree leaves",
	drawtype = "allfaces_optional",
	visual_scale = 1.3,
	tiles = {"default_leaves.png"},
	paramtype = "light",
	is_ground_content = false,
	groups = {snappy=3, flammable=2, leaves=1},
	sounds = default.node_sound_leaves_defaults(),
})

minetest.register_node("watershedmini:jungleleaf", {
	description = "Jungletree leaves",
	drawtype = "allfaces_optional",
	visual_scale = 1.3,
	tiles = {"default_jungleleaves.png"},
	paramtype = "light",
	is_ground_content = false,
	groups = {snappy=3, flammable=2, leaves=1},
	sounds = default.node_sound_leaves_defaults(),
})

minetest.register_node("watershedmini:icydirt", {
	description = "Icy dirt",
	tiles = {"watershedmini_icydirt.png"},
	is_ground_content = false,
	groups = {crumbly=1},
	drop = "default:dirt",
	sounds = default.node_sound_dirt_defaults({
		footstep = {name="default_snow_footstep", gain=0.15},
		dug = {name="default_snow_footstep", gain=0.45},
	}),
})

minetest.register_node("watershedmini:grass", {
	description = "Grass",
	tiles = {"default_grass.png", "default_dirt.png", "default_grass.png"},
	is_ground_content = false,
	groups = {crumbly=3,soil=1},
	drop = "default:dirt",
	sounds = default.node_sound_dirt_defaults({
		footstep = {name="default_grass_footstep", gain=0.25},
	}),
})

minetest.register_node("watershedmini:drygrass", {
	description = "Dry grass",
	tiles = {"watershedmini_drygrass.png"},
	is_ground_content = false,
	groups = {crumbly=1,soil=1},
	drop = "default:dirt",
	sounds = default.node_sound_dirt_defaults({
		footstep = {name="default_grass_footstep", gain=0.4},
	}),
})

minetest.register_node("watershedmini:freshwater", {
	description = "Fresh Water Source",
	inventory_image = minetest.inventorycube("watershedmini_freshwater.png"),
	drawtype = "liquid",
	tiles = {
		{
			name="watershedmini_freshwateranim.png",
			animation={type="vertical_frames",
			aspect_w=16, aspect_h=16, length=2.0}
		}
	},
	special_tiles = {
		{
			name="watershedmini_freshwateranim.png",
			animation={type="vertical_frames",
			aspect_w=16, aspect_h=16, length=2.0},
			backface_culling = false,
		}
	},
	alpha = WATER_ALPHA,
	paramtype = "light",
	is_ground_content = false,
	walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = true,
	drop = "",
	drowning = 1,
	liquidtype = "source",
	liquid_alternative_flowing = "watershedmini:freshwaterflow",
	liquid_alternative_source = "watershedmini:freshwater",
	liquid_viscosity = WATER_VISC,
	liquid_renewable = false,
	liquid_range = 0,
	post_effect_color = {a=64, r=100, g=100, b=200},
	groups = {water=3, liquid=3, puts_out_fire=1},
})
