local MAX_GENERATION = 128
local GROWTH_INTERVAL = 1
local MOD_NAME = core.get_current_modname()
local finished_trees = {}
local LEAF_SPAWN_RADIUS = 4
local NEIGHBOR_OFFSETS = {
    {x=1,y=0,z=0},{x=-1,y=0,z=0},
    {x=0,y=1,z=0},{x=0,y=-1,z=0},
    {x=0,y=0,z=1},{x=0,y=0,z=-1}
}

local MOD_LEAVES = MOD_NAME..":leaves"
local MOD_TREE = MOD_NAME..":tree"
local DEFAULT_LEAVES = "default:leaves"
local DEFAULT_TREE = "default:tree"
local default_leaves_def = minetest.registered_nodes[DEFAULT_LEAVES]
local default_tree_def = minetest.registered_nodes[DEFAULT_TREE]

local my_leaves_def = table.copy(default_leaves_def)
local my_tree_def = table.copy(default_tree_def)

my_leaves_def.description = "Massive Tree Leaves"

local function force_get_node(pos, cb)
    local existing = minetest.get_node_or_nil(pos)

    if not existing then
        core.emerge_area(pos, pos, function(blockpos, action, calls_remaining, param)
            if calls_remaining == 0 then
                force_get_node(pos, cb)
            end
        end)
        return
    end
    cb(existing, pos)
end

local function generate_tree_id(pos)
    return minetest.get_us_time() .. ":" .. minetest.pos_to_string(pos)
end

local function spawn_leaves(pos, parent_generation, tree_id)
    for _, offset in ipairs(NEIGHBOR_OFFSETS) do
        local neighbor_pos = vector.add(pos, offset)

        force_get_node(neighbor_pos, function(node, p)
            if node.name ~= "air" then return end

            core.set_node(p, {name = MOD_LEAVES})

            local meta = core.get_meta(p)
            meta:set_int("generation", (parent_generation or 1) + 1)
            meta:set_string("tree_id", tree_id)

        end)
    end
end

my_leaves_def.on_construct = function(pos)
    core.get_node_timer(pos):start(GROWTH_INTERVAL + math.random(GROWTH_INTERVAL))
end

my_leaves_def.after_place_node = function(pos)
    local meta = core.get_meta(pos)

    meta:set_int("generation", 0)
    meta:set_string("tree_id", generate_tree_id(pos))
end

my_leaves_def.on_timer = function(pos)
    local meta = core.get_meta(pos)
    local tree_id = meta:get_string("tree_id")

    if finished_trees[tree_id] then
        core.set_node(pos, { name = DEFAULT_LEAVES })
        return false
    end

    local generation = meta:get_int("generation")

    if generation >= MAX_GENERATION then
        finished_trees[tree_id] = true
        return
    end

    local light_level = core.get_node_light(pos, 0.5) or 0


    local min_pos = vector.subtract(pos, LEAF_SPAWN_RADIUS)
    local max_pos = vector.add(pos, LEAF_SPAWN_RADIUS)
    local nearby_trees = core.find_nodes_in_area(min_pos, max_pos, {MOD_TREE})

    -- Make plant growth more likely in hotter spots.
    if math.random(math.abs(math.pow(core.get_humidity(pos), 2))) == 1 then
        return true
    end

    if light_level <= 10 and #nearby_trees > 0 and math.random(#nearby_trees) then
        core.set_node(pos, { name = MOD_TREE })
        return
    end

    if #nearby_trees > 0 and math.pow(math.random(#nearby_trees), 2) == 1 then
                -- WORTH TRYING! Another idea is to favor upward growth when many trees and downward when less tree.
                -- The idea is that branches will grow down and the trunk up.
        if light_level >= 14 then
            spawn_leaves(pos, generation, tree_id)
        elseif light_level >= 13 then
            spawn_leaves(vector.add(pos, {x=0,y=-1,z=0}), generation, tree_id)
        end

        -- TRY - SMALL CHANCE THAT A LEAFE IS SPAWNED That will keep growing for a bit longer.
    end

    return true
end

core.register_node(MOD_TREE, my_tree_def)
core.register_node(MOD_LEAVES, my_leaves_def)

local MOD_ROTTEN_TREE = MOD_NAME..":rotten_tree"
local MOD_ROTTEN_TREE_SAG = MOD_NAME..":rotten_tree_sag"
local SAG_DELAY = 0.4

if true then

    -- copy the default tree node definition (deep copy)
    local rotten_tree_def = table.copy(default_tree_def)

    -- modify properties for rotten behavior
    rotten_tree_def.description = "Rotten Tree"


    -- make a copy of the tiles table
    rotten_tree_def.tiles = table.copy(rotten_tree_def.tiles)

    -- darken only the top faces (first two tiles)
    rotten_tree_def.tiles[1] = rotten_tree_def.tiles[1].."^[colorize:#3a2f2f:120"
    rotten_tree_def.tiles[2] = rotten_tree_def.tiles[2].."^[colorize:#3a2f2f:120"

    rotten_tree_def.groups = table.copy(default_tree_def.groups)
    rotten_tree_def.groups.falling_node = 1  -- allow it to fall


    -- on_player_walk triggers only if the node can fall
    rotten_tree_def.on_player_walk = function(pos, player)
        local below = {x = pos.x, y = pos.y - 1, z = pos.z}
        local node_below = minetest.get_node(below)
        local def = minetest.registered_nodes[node_below.name]

        if def and (def.walkable == false or def.buildable_to) then
            local timer = minetest.get_node_timer(pos)
            if not timer:is_started() then
                local node = minetest.get_node(pos)

                minetest.swap_node(pos, {
                    name = MOD_ROTTEN_TREE_SAG,
                })

                minetest.sound_play("default_tool_breaks", {
                    pos = pos,
                    gain = 1.0,
                    max_hear_distance = 16,
                })

                minetest.get_node_timer(pos):start(SAG_DELAY)
            end
        end
    end

    minetest.register_node(MOD_ROTTEN_TREE_SAG, {
        description = "Rotten Tree (Sagging)",
        tiles = rotten_tree_def.tiles,
        drawtype = "nodebox",
        paramtype = "light",
        paramtype2 = rotten_tree_def.paramtype2 or "facedir",

        node_box = {
            type = "fixed",
            fixed = {-0.5, -0.625, -0.5, 0.5, 0.375, 0.5}
        },

        groups = table.copy(rotten_tree_def.groups),
        drop = MOD_ROTTEN_TREE,

        on_timer = function(pos)
            local node = minetest.get_node(pos)

            minetest.swap_node(pos, {
                name = MOD_ROTTEN_TREE,
                param2 = node.param2
            })

            minetest.sound_play("default_tool_breaks", {
                pos = pos,
                gain = 1.0,
                max_hear_distance = 16,
            })

            minetest.check_for_falling(pos)
        end,
    })

    core.register_lbm({
        name = MOD_NAME..":make_rotten_tree",
        nodenames = {MOD_TREE},
        run_at_every_load = true,
        action = function(pos)
            local seed = minetest.hash_node_position(pos)
            local rng = PcgRandom(seed)

            -- 20% chance for this node to become rotten
            if rng:next(1, 100) <= 20 then
                local radius = 5

                -- check nearby leaves (within 1 node)
                local nearby_leaves = minetest.find_nodes_in_area(
                    vector.add(pos, radius),
                    vector.subtract(pos, radius),
                    {DEFAULT_LEAVES}
                )

                if #nearby_leaves == 0 then
                    minetest.set_node(pos, {name = MOD_ROTTEN_TREE})
                end
            end
        end,
    })

    -- register the new node
    minetest.register_node(MOD_ROTTEN_TREE, rotten_tree_def)

    minetest.register_globalstep(function(dtime)
        for _, player in ipairs(minetest.get_connected_players()) do
            local pos = player:get_pos()
            local under = {
                x = math.floor(pos.x),
                y = math.floor(pos.y - 0.1),
                z = math.floor(pos.z),
            }

            local node_name = minetest.get_node(under).name
            local node_def = minetest.registered_nodes[node_name]
            if node_def and node_def.on_player_walk then
                node_def.on_player_walk(under, player)
            end
        end
    end)
end

if core.registered_nodes["fireflies:firefly"] then
    --  Consider creating a new lbm every week or so.
    core.register_lbm({
        name = MOD_NAME..":fireflies",
        nodenames = {MOD_TREE},
        run_at_every_load = true,
        action = function(pos)
            local seed = minetest.hash_node_position(pos)
            -- Using PcgRandom to prevent a tree spawning way to many fireflies.
            local rng = PcgRandom(seed)

            if rng:next(1, 75) == 1 then
                local radius = 10

                local np = {
                    x = pos.x + rng:next(-radius, radius),
                    y = pos.y + rng:next(-radius, radius),
                    z = pos.z + rng:next(-radius, radius)
                }

                if core.get_node(np).name ~= "air" then
                    return
                end

                core.set_node(np, {name = "fireflies:hidden_firefly"})
            end
        end
    })
end


-- The SEED

local MOD_SEED = MOD_NAME..":seed"

core.register_node(MOD_SEED, {
    description = "Massive Tree Seed",
    tiles = {"massive_tree_seed.png"},  -- replace with your seed texture
    inventory_image = "massive_tree_seed.png",
    wield_image = "massive_tree_seed.png",
    drawtype = "signlike",          -- like farming seeds
    paramtype = "light",
    paramtype2 = "wallmounted",     -- allows place_param2 usage
    groups = {snappy=3, seed=1, flammable=2, attached_node=1},
    walkable = false,
    sunlight_propagates = true,
    selection_box = {type = "wallmounted"},

    on_construct = function(pos)
        -- core.set_node(pointed_thing.above, {name = MOD_SEED})
        core.get_node_timer(pos):start(GROWTH_INTERVAL + math.random(GROWTH_INTERVAL))
    end,

    on_timer = function(pos)
        -- Replace seed with tree trunk
        core.set_node(pos, {name = MOD_TREE})

        -- Spawn initial leaf above
        local leaf_pos = vector.add(pos, {x=0, y=1, z=0})
        core.set_node(leaf_pos, {name = MOD_LEAVES})

        local meta = core.get_meta(leaf_pos)
        meta:set_int("generation", 1)
        meta:set_string("tree_id", generate_tree_id(pos))

        return false  -- stop timer
    end,
})
