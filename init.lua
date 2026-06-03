-- techblox_mastery/init.lua

local mastery = {
    players = {},
    config = {
        base_sub_xp = 100,
        sub_exponent = 1.2,
        base_main_xp = 500,
        main_exponent = 1.3,
    }
}

-- Persistent storage engine
local storage = minetest.get_mod_storage()
local saved_data = storage:get_string("mastery_data")
if saved_data and saved_data ~= "" then
    mastery.players = minetest.deserialize(saved_data) or {}
end

local function save_all_data()
    storage:set_string("mastery_data", minetest.serialize(mastery.players))
end

function mastery.init_player(player_name)
    if not mastery.players[player_name] then
        mastery.players[player_name] = {
            main_level = 1,
            main_xp = 0,
            main_xp_needed = mastery.config.base_main_xp,
            
            lumberjack_lvl = 1,
            lumberjack_xp = 0,
            lumberjack_xp_needed = mastery.config.base_sub_xp,
            
            mining_lvl = 1,
            mining_xp = 0,
            mining_xp_needed = mastery.config.base_sub_xp,
            
            farming_lvl = 1,
            farming_xp = 0,
            farming_xp_needed = mastery.config.base_sub_xp,
        }
        save_all_data()
    end
    return mastery.players[player_name]
end

local function get_top_players(lvl_key)
    local leaderboard = {}
    for name, stats in pairs(mastery.players) do
        table.insert(leaderboard, {name = name, level = stats[lvl_key] or 1})
    end
    table.sort(leaderboard, function(a, b) return a.level > b.level end)
    return leaderboard
end

-- Custom Top-Center HUD Notification (Bypasses bottom status bars entirely)
local function trigger_hud_popup(player, xp_amount, type_label)
    local text = " +" .. xp_amount .. " " .. string.upper(type_label) .. " XP"
    local color = 0x54b6db -- Mining Blue
    
    if type_label == "lumberjack" then color = 0x7cdb54 end -- Green
    if type_label == "farming" then color = 0xe2a45c end    -- Yellow
    
    -- Add temporary text element at the top center of the screen
    local hud_id = player:hud_add({
        hud_elem_type = "text",
        position = {x = 0.5, y = 0.15}, -- 50% across, 15% down from top
        alignment = {x = 0, y = 0},     -- Perfectly centered
        offset = {x = 0, y = 0},
        number = color,
        text = text,
        scale = {x = 100, y = 100},
    })
    
    -- Auto-delete the HUD text after 1.5 seconds so it doesn't linger
    minetest.after(1.5, function()
        if player and player:is_player() then
            player:hud_remove(hud_id)
        end
    end)
end

function mastery.add_xp(player, category, amount)
    local name = player:get_player_name()
    local data = mastery.init_player(name)
    
    local xp_key = category .. "_xp"
    local lvl_key = category .. "_lvl"
    local req_key = category .. "_xp_needed"
    
    if not data[xp_key] then return end
    data[xp_key] = data[xp_key] + amount
    
    -- Sub-Mastery Progression Loop
    if data[xp_key] >= data[req_key] then
        data[xp_key] = data[xp_key] - data[req_key]
        data[lvl_key] = data[lvl_key] + 1
        data[req_key] = math.floor(mastery.config.base_sub_xp * (data[lvl_key] ^ mastery.config.sub_exponent))
        
        -- Send Level 1 & 2 alerts straight to private chat logs!
        minetest.chat_send_player(name, minetest.colorize("#7cdb54", "[Mastery] Your " .. string.upper(category) .. " skill advanced to Level " .. data[lvl_key] .. "!"))
    end
    
    -- Global Main Level Progression Loop
    data.main_xp = data.main_xp + amount
    if data.main_xp >= data.main_xp_needed then
        data.main_xp = data.main_xp - data.main_xp_needed
        data.main_level = data.main_level + 1
        data.main_xp_needed = math.floor(mastery.config.base_main_xp * (data.main_level ^ mastery.config.main_exponent))
        
        -- Server-wide milestone broadcast
        minetest.chat_send_all(minetest.colorize("#f7cb43", "[Techblox] " .. name .. " has achieved Main Level " .. data.main_level .. "!"))
    end
    
    save_all_data()
end

-- ==========================================
--            ENGINE HOOKS & EVENTS
-- ==========================================

minetest.register_on_dignode(function(pos, oldnode, digger)
    if not digger or not digger:is_player() then return end
    
    local node_name = oldnode.name
    
    -- Group evaluations (Works for fists, standard tools, and modded elements)
    local is_tree = minetest.get_item_group(node_name, "tree") > 0 or minetest.get_item_group(node_name, "log") > 0
    local is_crop = minetest.get_item_group(node_name, "crop") > 0 or minetest.get_item_group(node_name, "cropex") > 0 or minetest.get_item_group(node_name, "flora") > 0 or minetest.get_item_group(node_name, "plant") > 0
    
    local xp_reward = 1
    local mastery_type = "mining"
    
    if is_tree then
        mastery_type = "lumberjack"
        xp_reward = 10
    elseif is_crop then
        mastery_type = "farming"
        xp_reward = 8
    else
        -- Every block dug outside of farming/trees feeds directly into mining
        mastery_type = "mining"
        xp_reward = 1
    end
    
    trigger_hud_popup(digger, xp_reward, mastery_type)
    mastery.add_xp(digger, mastery_type, xp_reward)
end)

minetest.register_on_joinplayer(function(player)
    mastery.init_player(player:get_player_name())
end)

-- ==========================================
--            CHAT COMMANDS ENGINE
-- ==========================================

minetest.register_chatcommand("level", {
    params = "[top]",
    description = "Check your mastery levels or view the global leaderboards",
    func = function(name, param)
        local data = mastery.init_player(name)
        
        if param == "top" then
            local main_top = get_top_players("main_level")
            local mine_top = get_top_players("mining_lvl")
            local wood_top = get_top_players("lumberjack_lvl")
            local farm_top = get_top_players("farming_lvl")
            
            local out = {}
            table.insert(out, minetest.colorize("#f7cb43", "=== TECHBLOX GLOBAL LEADERS ==="))
            
            local function add_leader_line(title, color, dataset)
                table.insert(out, minetest.colorize(color, "--- " .. title .. " ---"))
                for i = 1, 3 do
                    if dataset[i] then
                        table.insert(out, " " .. i .. ". " .. dataset[i].name .. " (Lvl " .. dataset[i].level .. ")")
                    else
                        table.insert(out, " " .. i .. ". ---")
                    end
                end
            end
            
            add_leader_line("MAIN LEVEL OVERALL", "#f7cb43", main_top)
            add_leader_line("MINING MASTERY", "#54b6db", mine_top)
            add_leader_line("LUMBERJACK MASTERY", "#7cdb54", wood_top)
            add_leader_line("FARMING MASTERY", "#e2a45c", farm_top)
            
            return true, table.concat(out, "\n")
        end
        
        local msg = {
            minetest.colorize("#f7cb43", "=== YOUR SKILL LEVELS ==="),
            " Main Level: " .. data.main_level .. " [" .. data.main_xp .. "/" .. data.main_xp_needed .. " XP]",
            minetest.colorize("#54b6db", " Mining Level: ") .. data.mining_lvl .. " [" .. data.mining_xp .. "/" .. data.mining_xp_needed .. " XP]",
            minetest.colorize("#7cdb54", " Lumberjack Level: ") .. data.lumberjack_lvl .. " [" .. data.lumberjack_xp .. "/" .. data.lumberjack_xp_needed .. " XP]",
            minetest.colorize("#e2a45c", " Farming Level: ") .. data.farming_lvl .. " [" .. data.farming_xp .. "/" .. data.farming_xp_needed .. " XP]",
            minetest.colorize("#aaaaaa", "Type '/level top' to see the global leaderboard!")
        }
        
        return true, table.concat(msg, "\n")
    end,
})
