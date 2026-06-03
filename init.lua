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

-- Storage reference to keep data safe across server restarts
local storage = minetest.get_mod_storage()

-- Load data from persistent storage
local saved_data = storage:get_string("mastery_data")
if saved_data and saved_data ~= "" then
    mastery.players = minetest.deserialize(saved_data) or {}
end

-- Save helper function
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

-- Helper to sort and grab top players for a specific level key
local function get_top_players(lvl_key, limit)
    local leaderboard = {}
    
    -- Copy database entries into a sortable array layout
    for name, stats in pairs(mastery.players) do
        table.insert(leaderboard, {name = name, level = stats[lvl_key] or 1})
    end
    
    -- Sort descending (highest level first)
    table.sort(leaderboard, function(a, b)
        return a.level > b.level
    end)
    
    return leaderboard
end

-- ==========================================
--            CHAT COMMANDS ENGINE
-- ==========================================

minetest.register_chatcommand("level", {
    params = "[top]",
    description = "Check your mastery levels or view the global leaderboards",
    func = function(name, param)
        local data = mastery.init_player(name)
        
        -- PATH A: User requested the leaderboard leaderboard
        if param == "top" then
            local main_top = get_top_players("main_level")
            local mine_top = get_top_players("mining_lvl")
            local wood_top = get_top_players("lumberjack_lvl")
            local farm_top = get_top_players("farming_lvl")
            
            local out = {}
            table.insert(out, minetest.colorize("#f7cb43", "=== TECHBLOX GLOBAL LEADERS ==="))
            
            -- Helper line builder to cleanly format top 3 slots
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
        
        -- PATH B: Default /level command (Shows individual player metrics)
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

-- Update our existing add_xp routine to auto-save updates safely
function mastery.add_xp(player, category, amount)
    local name = player:get_player_name()
    local data = mastery.init_player(name)
    
    local xp_key = category .. "_xp"
    local lvl_key = category .. "_lvl"
    local req_key = category .. "_xp_needed"
    
    data[xp_key] = data[xp_key] + amount
    
    -- Sub-mastery level validation calculation
    if data[xp_key] >= data[req_key] then
        data[xp_key] = data[xp_key] - data[req_key]
        data[lvl_key] = data[lvl_key] + 1
        data[req_key] = math.floor(mastery.config.base_sub_xp * (data[lvl_key] ^ mastery.config.sub_exponent))
        
        minetest.chat_send_player(name, minetest.colorize("#7cdb54", "[Mastery] Your " .. string.upper(category) .. " skill advanced to Level " .. data[lvl_key] .. "!"))
    end
    
    -- Global Main Level updating processing loop 
    data.main_xp = data.main_xp + amount
    if data.main_xp >= data.main_xp_needed then
        data.main_xp = data.main_xp - data.main_xp_needed
        data.main_level = data.main_level + 1
        data.main_xp_needed = math.floor(mastery.config.base_main_xp * (data.main_level ^ mastery.config.main_exponent))
        
        minetest.chat_send_all(minetest.colorize("#f7cb43", "[Techblox] " .. name .. " has achieved Main Level " .. data.main_level .. "!"))
    end
    
    save_all_data() -- Keep player files synchronized
end

-- Remainder of hooks remain identically intact (register_on_dignode, etc.)
