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
    
    local hud_id = player:hud_add({
        hud_elem_type = "text",
        position = {x = 0.5, y = 0.15},
        alignment = {x = 0, y = 0},
        offset = {x = 0, y = 0},
        number = color,
        text = text,
        scale = {x = 100, y = 100},
    })
    
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
        
        minetest.chat_send_player(name, minetest.colorize("#7cdb54", "[Mastery] Your " .. string.upper(category) .. " skill advanced to Level " .. data[lvl_key] .. "!"))
    end
    
    -- Global Main Level Progression Loop
    data.main_xp = data.main_xp + amount
    if data.main_xp >= data.main_xp_needed then
        data.main_xp = data.main_xp - data.main_xp_needed
        data.main_level = data.main_level + 1
        data.main_xp_needed = math.floor(mastery.config.base_main_xp * (data.main_level ^ mastery.config.main_exponent))
        
        minetest.chat_send_all(minetest.colorize("#f7cb43", "[Techblox] " .. name .. " has achieved Main Level " .. data.main_level .. "!"))
    end
    
    save_all_data()
end

-- ==========================================
--          FORMSPEC FORMS GENERATOR
-- ==========================================

-- Personal Statistics GUI Formspec
local function show_personal_stats_form(player_name)
    local data = mastery.init_player(player_name)
    
    -- Progress Bar width calculation logic
    local function get_progress_bar(current, max)
        local percentage = math.min(100, math.floor((current / max) * 100))
        return "box[2.5,0.4;5.0,0.15;#333333]box[2.5,0.4;" .. (5.0 * (percentage / 100)) .. ",0.15;#7cdb54]"
    end

    local form = "size[8,6.5]" ..
        "background[0,0;8,6.5;techblox_mastery_bg.png;true]" ..
        "label[2.8,0.5;" .. minetest.formspec_escape("=== TECHBLOX PROFILE ===") .. "]" ..
        
        -- Main Character Level Track
        "label[0.5,1.5;MAIN LEVEL:]" ..
        "label[2.5,1.5;" .. data.main_level .. "  (" .. data.main_xp .. " / " .. data.main_xp_needed .. " XP)]" ..
        
        -- Individual Sub-Mastery Stats
        "label[0.5,2.7;" .. minetest.colorize("#54b6db", "MINING:") .. "]" ..
        "label[2.5,2.7;Lvl " .. data.mining_lvl .. "  (" .. data.mining_xp .. " / " .. data.mining_xp_needed .. " XP)]" ..
        
        "label[0.5,3.7;" .. minetest.colorize("#7cdb54", "LUMBERJACK:") .. "]" ..
        "label[2.5,3.7;Lvl " .. data.lumberjack_lvl .. "  (" .. data.lumberjack_xp .. " / " .. data.lumberjack_xp_needed .. " XP)]" ..
        
        "label[0.5,4.7;" .. minetest.colorize("#e2a45c", "FARMING:") .. "]" ..
        "label[2.5,4.7;Lvl " .. data.farming_lvl .. "  (" .. data.farming_xp .. " / " .. data.farming_xp_needed .. " XP)]" ..
        
        "button_exit[2.5,5.7;3,0.8;close;Close Menu]"
        
    minetest.show_formspec(player_name, "techblox_mastery:personal", form)
end

-- Global Leaderboards GUI Formspec (Accepts active selection modes)
local function show_leaderboard_form(player_name, view_mode)
    view_mode = view_mode or "main"
    
    -- Translate mode strings to internal database keys
    local db_keys = {
        main = {key = "main_level", title = "Global Main Levels", color = "#f7cb43"},
        mining = {key = "mining_lvl", title = "Top Miners", color = "#54b6db"},
        lumberjack = {key = "lumberjack_lvl", title = "Top Lumberjacks", color = "#7cdb54"},
        farming = {key = "farming_lvl", title = "Top Farmers", color = "#e2a45c"}
    }
    
    local current = db_keys[view_mode]
    local top_list = get_top_players(current.key)
    
    -- Setup sizing base
    local form = "size[9,7.5]" ..
        "background[0,0;9,7.5;techblox_leaderboard_bg.png;true]" ..
        
        -- 4 Top Toggle Buttons (Acting as custom navigation tabs)
        "button[0.2,0.3;2,0.8;tab_main;Main Level]" ..
        "button[2.4,0.3;2,0.8;tab_mining;Mining]" ..
        "button[4.6,0.3;2,0.8;tab_lumberjack;Lumberjack]" ..
        "button[6.8,0.3;2,0.8;tab_farming;Farming]" ..
        
        -- Header text elements
        "label[0.5,1.6;" .. minetest.formspec_escape(minetest.colorize(current.color, "=== LEADERBOARD: " .. string.upper(current.title) .. " ===")) .. "]"
        
    -- Render Top 10 slots dynamically if records exist
    local y_pos = 2.3
    for i = 1, 10 do
        local entry = top_list[i]
        local row_text = " " .. i .. ". "
        
        if entry then
            row_text = row_text .. entry.name .. " - (Level " .. entry.level .. ")"
        else
            row_text = row_text .. "---"
        end
        
        form = form .. "label[0.8," .. y_pos .. ";" .. minetest.formspec_escape(row_text) .. "]"
        y_pos = y_pos + 0.45
    end
    
    form = form .. "button_exit[3,7.0;3,0.6;close;Exit Leaders]"
    
    minetest.show_formspec(player_name, "techblox_mastery:leaderboard", form)
end

-- Formspec submission handlers 
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if not player or not player:is_player() then return end
    local name = player:get_player_name()
    
    -- Only respond to interactions matching our custom mod namespace
    if formname == "techblox_mastery:leaderboard" then
        if fields.tab_main then
            show_leaderboard_form(name, "main")
        elseif fields.tab_mining then
            show_leaderboard_form(name, "mining")
        elseif fields.tab_lumberjack then
            show_leaderboard_form(name, "lumberjack")
        elseif fields.tab_farming then
            show_leaderboard_form(name, "farming")
        end
    end
end)

-- ==========================================
--            ENGINE HOOKS & EVENTS
-- ==========================================

minetest.register_on_dignode(function(pos, oldnode, digger)
    if not digger or not digger:is_player() then return end
    
    local node_name = oldnode.name
    
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
    description = "Check your personal mastery stats or view global ranking formspecs",
    func = function(name, param)
        if param == "top" then
            -- Open the dashboard starting on the global Main Level tab view
            show_leaderboard_form(name, "main")
        else
            -- Default window showing individual level specs
            show_personal_stats_form(name)
        end
        return true
    end,
})
