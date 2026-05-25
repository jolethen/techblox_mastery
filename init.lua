local storage = minetest.get_mod_storage()
techblox_mastery = {}

-- Mastery definitions
local masteries = {"lumberjack", "farming", "combat"}

-- Helper: Safe way to add mastery
function techblox_mastery.add_mastery(playername, category, amount)
    if not playername then return end
    
    -- Nil proofing
    local key = playername .. "_" .. category
    local current = storage:get_int(key)
    storage:set_int(key, current + amount)
    
    -- Bridge to XP_Redo (Master Branch)
    if minetest.get_modpath("xp_redo") then
        xp_redo.add_xp(playername, amount)
    end
    
    -- Refresh HUD for the player
    techblox_mastery.update_hud(playername)
end

-- HUD Management: Non-intrusive
local player_huds = {}

function techblox_mastery.update_hud(playername)
    local player = minetest.get_player_by_name(playername)
    if not player then return end
    
    -- Clear old HUD
    if player_huds[playername] then
        player:hud_remove(player_huds[playername])
    end
    
    -- Build small text string
    local text = "Masteries: "
    for _, cat in ipairs(masteries) do
        local val = storage:get_int(playername .. "_" .. cat)
        text = text .. cat:sub(1,1):upper() .. ":" .. val .. " | "
    end
    
    -- Create HUD at the top center
    player_huds[playername] = player:hud_add({
        hud_elem_type = "text",
        position = {x = 0.5, y = 0.05},
        name = "mastery_hud",
        text = text,
        number = 0xFFFFFF,
        alignment = {x = 0, y = 0},
    })
end

-- Initialize HUD on join
minetest.register_on_joinplayer(function(player)
    techblox_mastery.update_hud(player:get_player_name())
end)

-- Example Hook: Lumberjack
minetest.register_on_dignode(function(pos, oldnode, digger)
    if not digger or not digger:is_player() then return end
    if oldnode.name:find("tree") or oldnode.name:find("log") then
        techblox_mastery.add_mastery(digger:get_player_name(), "lumberjack", 1)
    end
end)
