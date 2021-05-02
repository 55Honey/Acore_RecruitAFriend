--
-- Created by IntelliJ IDEA.
-- User: Silvia
-- Date: 08/03/2021
-- Time: 20:39
-- To change this template use File | Settings | File Templates.
-- Originally created by Honey for Azerothcore
-- requires ElunaLua module


-- This module allows players to connect accounts with their friends to gain benefits
------------------------------------------------------------------------------------------------
-- ADMIN GUIDE:  -  compile the core with ElunaLua module
--               -  adjust config in this file
--               -  add this script to ../lua_scripts/
--               -  use the given commands via SOAP from the website to add/remove links (requires changes to acore-cms):
--               -  bind a recruiter: .bindraf $newRecruitId $existingRecruiterId
--               -  players need a way to know their own account id, so they can share it
------------------------------------------------------------------------------------------------
-- PLAYER GUIDE: - as the new player(RECRUIT): make yourself RECRUITED by selecting your recruiters ID during account creation on the website
--               - as the existing player (RECRUITER): summon your friend with ".raf summon $FriendsCharacterName"
--               - once the RECRUIT reaches a level set in config, the RECRUITER receives a reward.
--               - same IP restricts or removes the bind (sorry families, roommates and the like)
------------------------------------------------------------------------------------------------

local Config = {}
local Config_maps = {}

-- Name of Eluna dB scheme
Config.customDbName = "ac_eluna"
-- set to 1 to print error messages to the console. Any other value including nil turns it off.
Config.printErrorsToConsole = 1
-- min GM level to bind accounts
Config.minGMRankForBind = 3
-- max RAF duration in seconds. 2,592,000 = 30days
Config.maxRAFduration = 2592000
-- set to 1 to grant always rested. Any other value including nil turns it off.
Config.grantRested = 1
-- set to 1 to print a login message. Any other value including nil turns it off.
Config.displayLoginMessage = 1
-- the level which a player must reach to reward it's recruiter and automatically end RAF
Config.targetLevel = 29
-- maximum number of RAF related command uses before a kick. Includes summon requests.
Config.abuseTreshold = 100
-- allowed maps for summoning. additional maps can be added with a table.insert() line.
-- Remove or comment all table.insert below to forbid summoning
-- Eastern kingdoms
table.insert(Config_maps, 0)
-- Kalimdor
table.insert(Config_maps, 1)
-- Outland
--table.insert(Config_maps, 530)
-- Northrend
--table.insert(Config_maps, 571)
------------------------------------------
-- NO ADJUSTMENTS REQUIRED BELOW THIS LINE
------------------------------------------
local PLAYER_EVENT_ON_LOGIN = 3          -- (event, player)
local PLAYER_EVENT_ON_LEVEL_CHANGE = 13  -- (event, player, oldLevel)
local PLAYER_EVENT_ON_COMMAND = 42       -- (event, player, command) - player is nil if command used from console. Can return false

CharDBExecute('CREATE DATABASE IF NOT EXISTS `'..Config.customDbName..'`;');
CharDBExecute('CREATE TABLE IF NOT EXISTS `'..Config.customDbName..'`.`recruit_a_friend` (`account_id` INT(11) NOT NULL, `recruiter_account` INT(11) DEFAULT 0, `time_stamp` INT(11) DEFAULT 0, PRIMARY KEY (`account_id`) );');

--globals:
RAF_xpPerLevel = {}
RAF_recruiterAccount = {}
RAF_timeStamp = {}
RAF_abuseCounter = {}
--global table which reads the required XP per level one single time on load from the db instead of one value every levelup event
local RAF_Data_SQL
local RAF_row = 1
local RAF_Data_SQL = WorldDBQuery('SELECT Experience FROM player_xp_for_level WHERE Level <= 80;')
if RAF_Data_SQL ~= nil then
    repeat
        RAF_xpPerLevel[RAF_row] = RAF_Data_SQL:GetUInt32(0)
        RAF_row = RAF_row + 1
    until not RAF_Data_SQL:NextRow()
else
    print("RAF: Error reading player_xp_for_level from tha database.")
end
RAF_Data_SQL = nil
RAF_row = nil

--global table which stores all RAF links
local RAF_Data_SQL
local RAF_id
RAF_Data_SQL = CharDBQuery('SELECT * FROM `'..Config.customDbName..'`.`recruit_a_friend`;')
if RAF_Data_SQL ~= nil then
    repeat
        RAF_id = RAF_Data_SQL:GetUInt32(0)
        RAF_recruiterAccount[RAF_id] = RAF_Data_SQL:GetUInt32(1)
        RAF_timeStamp[RAF_id] = RAF_Data_SQL:GetUInt32(2)
    until not RAF_Data_SQL:NextRow()
else
    print("RAF: Found no linked accounts in the recruit_a_friend table. Possibly there are none yet.")
end

--todo: check all variables for reset and if actually used

local function RAF_command(event, player, command)
    local commandArray = {}
    -- split the command variable into several strings which can be compared individually
    commandArray = RAF_splitString(command)

    if commandArray[2] ~= nil then
        commandArray[2] = commandArray[2]:gsub("[';\\, ]", "")
        if commandArray[3] ~= nil then
            commandArray[3] = commandArray[3]:gsub("[';\\, ]", "")
        end
    end

    if commandArray[1] == "bindraf" then
        local playerAccount = player:GetAccountId()
        if player ~= nil then
            RAF_checkAbuse(playerAccount)
        end

        if player:GetGMRank() >= Config.minGMRankForBind then
            -- GM/SOAP command to force bind from console or ingame commands
            if commandArray[2] ~= nil and commandArray[3] ~= nil then
                if commandArray[3] == tonumber(commandArray[3]) then
                    -- todo: next line is broken. Can't get an account id from an account name
                    local accountId = GetPlayerByName(commandArray[2]):GetAccountId()
                    RAF_recruiterAccount[accountId] = commandArray[3]
                    RAF_timeStamp[accountId] = GetGameTime()
                    CharDBExecute('DELETE * FROM `'..Config.customDbName..'`.`recruit_a_friend` WHERE `account_id` = '..accountId..';')
                    CharDBExecute('INSERT INTO `'..Config.customDbName..'`.`recruit_a_friend` VALUES ('..accountId', '..RAF_recruiterAccount[accountId]..', '..RAF_timeStamp[accountId]..');')
                end
            end
            return false
        end

    elseif commandArray[1] == "raf" then
        local playerAccount = player:GetAccountId()
        if player ~= nil then
            RAF_checkAbuse(playerAccount)
        end

        -- provide syntax help
        if commandArray[2] == "list" then
        -- print all recruits bound to this account by charname
            player:SendBroadcastMessage("Your current recruits are: "..RAF_returnValues(RAF_recruiterAccount, player:GetAccountId, "none"))

        elseif commandArray[2] == "help" or commandArray[3] == nil then
            player:SendBroadcastMessage("Syntax to list all recruits: .raf list")
            player:SendBroadcastMessage("Syntax to summon the recruit: .raf summon $FriendsCharacterName")
            player:SendBroadcastMessage("Only the recruiter can summon the recruit. The recruit can NOT summon. You must be in a party/raid with each other.")
            RAF_cleanup()
            return false


        elseif commandArray[2] == "summon" and commandArray[3] ~= nil and player ~= nil then

            -- check if the target is a recruit of the player
            local summonPlayer = GetPlayerByName(commandArray[3])
            if summonPlayer == nil then
                player:SendBroadcastMessage("Target not found. Check spelling and capitalization.")
                return false
            end
            if RAF_recruiterAccount[GetPlayerByName(summonPlayer):GetAccountId()] ~= player:GetAccountId() then
                player:SendBroadcastMessage("The requested player is not your recruit.")
                return false
            end
            --todo: check for same IP

            -- do the zone/combat checks and possibly summon
            local mapId = player:GetMapId()
            -- allow to proceed if the player is on one of the maps listed above
            if RAF_hasValue(Config_maps, mapId) then
                --allow to proceed if the player is not in combat
                if not player:IsInCombat() then
                    local group = player:GetGroup()
                    local groupPlayers = group:GetMembers()
                    for _, v in pairs(groupPlayers) do
                        if v:GetName() == commandArray[3] then
                            v:SummonPlayer(player)
                        end
                    end
                else
                    player:SendBroadcastMessage("Summoning is not possible in combat.")
                end
                return false
            else
                player:SendBroadcastMessage("Summoning is not possible here.")
            end
            return false

        else
            -- print help also, if nothing matched the 2nd argument
            player:SendBroadcastMessage("Syntax to list all recruits: .raf list")
            player:SendBroadcastMessage("Syntax to summon the recruit: .raf summon $FriendsCharacterName")
            player:SendBroadcastMessage("Only the recruiter can summon the recruit. The recruit can NOT summon. You must be in a party/raid with each other.")
            RAF_cleanup()
            return false
        end
    end
    return false
end

local function RAF_login(event, player)
    local accountId = player:GetAccountId()

    -- display login message
    if Config.displayLoginMessage == 1 then
        player:SendBroadcastMessage("This server features a Recruit-a-friend module. Type .raf for help.")
    end

    --reset abuse counter
    RAF_abuseCounter[accountId] = 0
    
    -- check for an existing RAF connection when a RECRUIT or RECRUITER logs in
    recruiterId = RAF_recruiterAccount[player:GetAccountId()]
    if recruiterId == nil then
        return false
    end

    -- check for RAF timeout on login of the RECRUIT, possibly remove the link
    if RAF_timeStamp[accountId] == 0 then
        return false
    end

    if GetGameTime() > RAF_timeStamp[accountId] + Config.maxRAFduration then
        RAF_timeStamp[accountId] = 0
        CharDBExecute('UPDATE `'..Config.customDbName..'`.`recruit_a_friend` SET time_stamp = 0 WHERE `account_id` = '..accountId..';')
        return false
    end

    -- add 1 full level of rested at login while in RAF
    if Config.grantRested == 1 then
        player:SetRestBonus(RAF_xpPerLevel[player:GetLevel()])
    end    

    RAF_cleanup()
    return false
end

local function RAF_levelChange(event, player, oldLevel)

    local accountId = player:GetAccountId()
    -- check for RAF timeout on login of the RECRUIT, possibly remove the link
    if oldLevel + 1 >= Config.targetLevel then
        RAF_timeStamp[accountId] = 0
        CharDBExecute('UPDATE `'..Config.customDbName..'`.`recruit_a_friend` SET time_stamp = 0 WHERE `account_id` = '..accountId..';')
        GrantReward(RAF_recruiterAccount[accountId])
        return false
    end

    recruiterId = RAF_recruiterAccount[player:GetAccountId()]
    if recruiterId == nil then
        return false
    end

    if RAF_timeStamp[accountId] == 0 then
        return false
    end

    -- add 1 full level of rested at levelup while in RAF and not at maxlevel with Player:SetRestBonus( restBonus )
    if Config.grantRested == 1 then
        player:SetRestBonus(RAF_xpPerLevel[oldLevel + 1])
    end 
end


function RAF_cleanup()
    --todo: remove extra variables
    --set all variables to nil
    playerLevel = nil
    playerAccountId = nil
    recruiterAccountId = nil
    recruitAccountId = nil
    recruiterName = nily
    Data_SQL = nil
    Data_SQL2 = nil
    characterGuid = nil
    commandArray = nil
    existingRecruits = nil
    linkTime = nil
    playerIP = nil
end

function RAF_splitString(inputstr, seperator)
    if seperator == nil then
        seperator = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..seperator.."]+)") do
        table.insert(t, str)
    end
    return t
end

function RAF_hasValue (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

function RAF_returnValues(tab, val, default)
    local returnString
    for index, value in ipairs(tab) do
        if value == val then
            if returnString == nil then
                returnString = index
            else
                returnString = returnString.." "..index
            end
        end
    end
    return default
end

function RAF_checkAbuse(accountId)
    if RAF_abuseCounter[accountId] > Config.abuseTreshold then
        player:KickPlayer()
        print("RAF: account id "..accountId.." was kicked because of too many .raf commands.")
    end
    RAF_abuseCounter[accountId] = RAF_AbuseCounter[accountId] + 1
end

function GrantReward(accountId)
    -- Todo: Do something here
end


RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, RAF_command)
RegisterPlayerEvent(PLAYER_EVENT_ON_LOGIN, RAF_login)
RegisterPlayerEvent(PLAYER_EVENT_ON_LEVEL_CHANGE, RAF_levelChange)

