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
--               -  write to the DB in `recruit_a_friend` from the website to add/remove links
--                  or use the given commands
------------------------------------------------------------------------------------------------
-- PLAYER GUIDE: - as the new player(RECRUIT): make yourself RECRUITED by typing ".recruitafriend bind $FriendsCharacterName"
--               - as the new player(RECRUIT): unbind your account from a RECRUITER by typing ".recruitafriend unbind"
--               - as the existing player (RECRUITER): summon your friend with ".recruitafriend summon $FriendsCharacterName"
--               - once the RECRUIT reaches a level set in config, the RECRUITER receives a reward.
--               - same IP restricts or removes the bind (sorry families and roommates)
------------------------------------------------------------------------------------------------


local Config = {}
local Config_maps = {}

-- Name of Eluna dB scheme
Config.customDbName = "ac_eluna"
-- max level the ONLY character on the players account may have to become a recruit
Config.maxAllowedLevel = 9
-- max number of simultaneous recruits
Config.maxAllowedRecruits = 5
-- set to 1 to print error messages to the console. Any other value including nil turns it off.
Config.printErrorsToConsole = 1
-- min GM level to bind accounts without accessing it
Config.minGMRankForBind = 2
-- max RAF duration in seconds. 2,592,000 = 30days
Config.maxRAFduration = 2592000
-- set to 1 to grant always rested. Any other value including nil turns it off.
Config.grantRested = 1
-- set to 1 to print a login message. Any other value including nil turns it off.
Config.displayLoginMessage = 1
-- set to 1 to ban automatically when IP abuse is detected. Any other value including nil turns it off.
Config.autoBan = 1
-- duration in seconds for an automatic ban
Config.autoBanTime = 300
-- the level which a player must reach to reward it's recruiter and automatically end RAF
Config.targetLevel = 29
-- allowed maps for summoning. additional maps can be added with a table.insert() line.
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

local RAF_Data_SQL
local RAF_row = 1
--global table which reads the required XP per level one single time on load from the db instead of one value every levelup event
RAF_xpPerLevel = {}
RAF_Data_SQL = WorldDBQuery('SELECT Experience FROM player_xp_for_level WHERE Level <= 80;')
repeat
    RAF_xpPerLevel[RAF_row] = RAF_Data_SQL:GetUInt32(0)
    RAF_row = RAF_row + 1
until not RAF_Data_SQL:NextRow()
RAF_Data_SQL = nil
RAF_row = nil


local function RAF_command(event, player, command)
    local playerLevel
    local playerAccountId
    local recruiterAccountId
    local recruiterName
    local Data_SQL
    local characterGuid
    local commandArray = {}
    local existingRecruits
    local playerIP
    -- split the command variable into several strings which can be compared individually
    commandArray = RAF_splitString(command)
    if commandArray[1] == "ForceBindRAF" then
    -- todo: add GM command to force bind from console

    elseif commandArray[1] == "recruitafriend" then
        -- prevent use from console
        if player == nil then
            print("This command is not meant to be used from the console.")
            RAF_cleanup()
            return false
        end

        playerAccountId = player:GetAccountId()
        --let the RECRUITED player remove the existing connection
        if commandArray[2] == "unbind" then
            CharDBExecute('UPDATE `'..Config.customDbName..'`.`recruit_a_friend` SET `time_stamp` = 0 WHERE `recruiter_account` = '..playerAccountId..';');
            RAF_cleanup()
            return false
        end

        -- provide syntax help
        if commandArray[2] == "help" or commandArray[3] == nil then
            player:SendBroadcastMessage("Syntax to become a recruit: .recruitafriend bind $FriendsCharacterName")
            player:SendBroadcastMessage("Syntax to stop being a recruit: .recruitafriend unbind")
            player:SendBroadcastMessage("Syntax to summon the recruit: .recruitafriend summon $FriendsCharacterName")
            player:SendBroadcastMessage("Only the recruiter can summon the recruit. The recruit can NOT summon. You must be in a party/raid with each other.")
            RAF_cleanup()
            return false
        end

        characterGuid = tostring(player:GetGUID())
        characterGuid = tonumber(characterGuid)

        if commandArray[2] == "bind" then

            --check if this account already has other characters created on it
            Data_SQL = CharDBQuery('SELECT `guid` FROM `characters` WHERE `account` = '..playerAccountId..' LIMIT 2;');
            repeat
                if characterGuid ~= nil and characterGuid ~= Data_SQL:GetUInt32(0) then
                    player:SendBroadcastMessage("You have more characters than this one already. Aborting.")
                    if Config.printErrorsToConsole == 1 then print("RAF bind failed from AccoundId "..playerAccountId..". More characters existing.") end
                    RAF_cleanup()
                    return false
                end
            until not Data_SQL:NextRow()

            --check if the character is not higher level than allowed in config
            playerLevel = player:GetLevel()
            if playerLevel > Config.maxAllowedLevel then
                player:SendBroadcastMessage("Your character is too high level already. The permitted maximum is level "..Config.maxAllowedLevel.." Aborting.")
                if Config.printErrorsToConsole == 1 then print("RAF bind failed from AccoundId "..playerAccountId..". Too high level.") end
                RAF_cleanup()
                return false
            end

            -- check if the 3rd argument is a character name
            recruiterName = commandArray[3]
            Data_SQL = CharDBQuery('SELECT `guid` FROM `characters` WHERE `name` = "'..recruiterName..'" LIMIT 1;');
            if Data_SQL ~= nil then
                recruiterAccountId = Data_SQL:GetUInt32(0)
            else
                player:SendBroadcastMessage("The requested player does not exist. Check spelling and capitalization. Aborting.")
                if Config.printErrorsToConsole == 1 then print("RAF bind failed from AccoundId "..playerAccountId..". Recruiter character "..recruiterName.." doesnt exist.") end
                RAF_cleanup()
                return false
            end
            
            --check if this account is already linked
            Data_SQL = nil
            local Data_SQL
            Data_SQL = CharDBQuery('SELECT `recruiter_account` FROM `'..Config.customDbName..'`.`recruit_a_friend` WHERE `account_id` = '..playerAccountId..' LIMIT 1;');
            if Data_SQL ~= nil then
                player:SendBroadcastMessage("Your account was already bound in RAF. Aborting.")
                if Config.printErrorsToConsole == 1 then print("RAF bind failed from AccoundId "..playerAccountId..". This account was already bound.") end
                RAF_cleanup()
                return false
            end

            --check if the RECRUITER account has a maximum of Config.maxAllowedRecruits
            Data_SQL = CharDBQuery('SELECT `account_id` FROM `'..Config.customDbName..'`.`recruit_a_friend` WHERE `recruiter_account` = '..recruiterAccountId..' LIMIT '..Config.maxAllowedRecruits..';');
            existingRecruits = 0
            if Data_SQL ~= nil then
                repeat
                    existingRecruits = existingRecruits + 1
                until not Data_SQL:NextRow()
            end
            if existingRecruits >= Config.maxAllowedRecruits then
                player:SendBroadcastMessage("Too many RAF links on target recruiter account. Aborting.")
                if Config.printErrorsToConsole == 1 then print("RAF bind failed from AccoundId "..playerAccountId..". Target account has too many binds.") end
                RAF_cleanup()
                return false
            end

            print("playerAccountId: "..playerAccountId)
            print("recruiterAccountId: "..recruiterAccountId)
            local GameTime = tonumber(tostring(GetGameTime()))
            -- bind the accounts to each other
            CharDBExecute('DELETE FROM `'..Config.customDbName..'`.`recruit_a_friend` WHERE `account_id` = '..playerAccountId..';');
            CharDBExecute('INSERT INTO `'..Config.customDbName..'`.`recruit_a_friend` VALUES ('..playerAccountId..', '..recruiterAccountId..', '..GameTime..');');
            RAF_cleanup()
            return false
        elseif commandArray[2] == "summon" and commandArray[3] ~= nil then

            -- check if the target is a recruit of the player
            local Data_SQL2
            Data_SQL = CharDBQuery('SELECT `account_id` FROM `'..Config.customDbName..'`.`recruit_a_friend` WHERE `recruiter_account` = '..playerAccountId..' AND `time_stamp` > 0 LIMIT '..Config.maxAllowedRecruits..';');
            if Data_SQL ~= nil then
                repeat
                    Data_SQL2 = CharDBQuery('Select `account` FROM `characters` WHERE `name` = '..commandArray[2]..';')
                    if Data_SQL2 == nil then
                        player:SendBroadcastMessage("The requested player does not exist. Check spelling and capitalization. Aborting.")
                        RAF_cleanup()
                        return false
                    else   
                        if Data_SQL:GetUInt32(0) ~= Data_SQL2:GetUInt32(0) then
                            player:SendBroadcastMessage("The requested player is not your recruit. Check spelling and capitalization. Aborting.")
                            RAF_cleanup()
                            return false
                        end
                    end
                until not Data_SQL:NextRow()
            end

            -- do the zone/combat checks and possibly summon
            local mapId = player:GetMapId()
            -- allow to proceed if the player is on one of the maps listed above
            if has_value(Config_maps, mapId) then
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
        elseif commandArray[2] == "list" then
            -- print all recruits bound to this account by charname
            local Data_SQL2
            Data_SQL = CharDBQuery('SELECT `account_id` FROM `'..Config.customDbName..'`.`recruit_a_friend` WHERE `recruiter_account` = '..playerAccountId..' AND `time_stamp` > 0 LIMIT '..Config.maxAllowedRecruits..';');
            if Data_SQL ~= nil then
                repeat
                    Data_SQL2 = CharDBQuery('SELECT `name` FROM `characters` WHERE `account` = '..Data_SQL:GetUInt32(0)..';')
                    player:SendBroadcastMessage(Data_SQL2:GetString(0))
                until not Data_SQL:NextRow()
            end
        else
            -- print help also, if nothing matched the 2nd argument
            player:SendBroadcastMessage("Syntax to become a recruit: .recruitafriend bind $FriendsCharacterName")
            player:SendBroadcastMessage("Syntax to stop being a recruit: .recruitafriend unbind")
            player:SendBroadcastMessage("Syntax to summon the recruit: .recruitafriend summon $FriendsCharacterName")
            player:SendBroadcastMessage("Only the recruiter can summon the recruit. The recruit can NOT summon. You must be in a party/raid with each other.")
            RAF_cleanup()
            return false
        end
    end
    return false
end

local function RAF_login(event, player)
    local playerLevel
    local playerAccountId
    local recruiterAccountId
    local recruitAccountId
    local recruiterName
    local Data_SQL
    local Data_SQL2
    local characterGuid
    local commandArray = {}
    local existingRecruits
    local linkTime
    local playerIP
    local isRecruiter
    local isRecruit
    
    -- display login message
    if Config.displayLoginMessage == 1 then
        player:SendBroadcastMessage("This server features a Recruit-a-friend module. Type .recruitafriend for help.")
    end
    
    -- check for the same IP when a RECRUITER logs in
    playerAccountId = player:GetAccountId()
    playerIP = player:GetPlayerIP()
    Data_SQL = CharDBQuery('SELECT account_id FROM `'..Config.customDbName..'`.`recruit_a_friend` WHERE `recruiter_account` = "'..playerAccountId..'" LIMIT '..Config.maxAllowedRecruits..';');
    if Data_SQL ~= nil then
        isRecruiter = 1
        repeat
            recruitAccountId = Data_SQL:GetUInt32(0)
            DataSQL2 = AuthDBQuery('SELECT last_ip FROM `account` WHERE `id` = '..recruitAccountId..';');
            print("A tostring(playerIP) = "..tostring(playerIP))
            print("B tostring(Data_SQL2:GetString(0)) = "..tostring(Data_SQL2:GetString(0)))
            if tostring(playerIP) == tostring(Data_SQL2:GetString(0)) then
                CharDBExecute('UPDATE `'..Config.customDbName..'`.`recruit_a_friend` SET `time_stamp` = 0 WHERE `recruiter_account` = '..playerAccountId..';');
                player:SendBroadcastMessage("Your Recruit-A-Friend link was removed.")
                if Config.printErrorsToConsole == 1 then print("RAF link removed due to same IP for RECRUITER "..playerAccountId..".") end
                if config.autoBan == 1 then
                    result = Ban(2, tostring(playerIP), Config.autoBanTime, "RAF abuse", "RAF")
                    if Config.printErrorsToConsole == 1 then print("Automatic ban for possible IP abuse in RAF for IP "..tostring(playerIP)..".") end;
                end
                RAF_cleanup()
                return false
            end
        until not Data_SQL:NextRow()
    end

    -- check for the same IP when a RECRUIT logs in
    playerAccountId = player:GetAccountId()
    playerIP = player:GetPlayerIP()
    Data_SQL = CharDBQuery('SELECT recruiter_account FROM `'..Config.customDbName..'`.`recruit_a_friend` WHERE `account_id` = "'..playerAccountId..'" LIMIT 1;');
    if Data_SQL ~= nil then
        isRecruit = 1
        recruiterAccountId = Data_SQL:GetUInt32(0)
        Data_SQL2 = AuthDBQuery('SELECT last_ip FROM `account` WHERE `id` = '..recruiterAccountId..';');
        if tostring(playerIP) == tostring(Data_SQL2:GetString(0)) then
            CharDBExecute('UPDATE `'..Config.customDbName..'`.`recruit_a_friend` SET `time_stamp` = 0 WHERE `recruiter_account` = '..playerAccountId..';');
            player:SendBroadcastMessage("Your Recruit-A-Friend link was removed.")
            if Config.printErrorsToConsole == 1 then print("RAF link removed due to same IP for RECRUITER "..playerAccountId..".") end
                if config.autoBan == 1 then
                    result = Ban(2, tostring(playerIP), Config.autoBanTime, "RAF abuse", "RAF")
                    if Config.printErrorsToConsole == 1 then print("Automatic ban for possible IP abuse in RAF for IP "..tostring(playerIP)..".") end;
                end
            RAF_cleanup()
            return false
        end
    end

    -- check for RAF timeout on login of the RECRUIT, possibly remove the link
    Data_SQL = CharDBQuery('SELECT `time_stamp` FROM `'..Config.customDbName..'`.`recruit_a_friend` WHERE `account_id` = '..playerAccountId..' LIMIT 1;');
    if Data_SQL ~= nil then linkTime = Data_SQL:GetUInt32(0) end
    if Config.maxRAFduration + linkTime < GetGameTime() then
        CharDBExecute('DELETE FROM `'..Config.customDbName..'`.`recruit_a_friend` WHERE `account_id` = '..playerAccountId..';');
        player:SendBroadcastMessage("Your Recruit-A-Friend link was removed because it timed out.")
        if Config.printErrorsToConsole == 1 then print("RAF link removed due to timeout for RECRUIT "..playerAccountId..".") end
        RAF_cleanup()
        return false
    end

    -- check for RAF timeout on login of the RECRUITER, possibly remove the link
    Data_SQL = CharDBQuery('SELECT `account_id` FROM `'..Config.customDbName..'`.`recruit_a_friend` WHERE `recruiter_account` = '..playerAccountId..' LIMIT '..Config.maxAllowedRecruits..';');
    if Data_SQL ~= nil then
        repeat
            recruitAccountId = Data_SQL:GetUInt32(0)
            Data_SQL2 = CharDBQuery('SELECT `time_stamp` FROM `'..Config.customDbName..'`.`recruit_a_friend` WHERE `recruiter_account` = '..recruitAccountId..' LIMIT 1;');
            if Data_SQL2 ~= nil then linkTime = Data_SQL2:GetUInt32(0) end
            if Config.maxRAFduration + linkTime < GetGameTime() then
                CharDBExecute('DELETE FROM `'..Config.customDbName..'`.`recruit_a_friend` WHERE `account_id` = '..recruitAccountId..';');
                player:SendBroadcastMessage("Your Recruit-A-Friend link was removed because it timed out.")
                if Config.printErrorsToConsole == 1 then print("RAF link removed due to timeout for RECRUIT "..recruitAccountId..".") end
                RAF_cleanup()
                return false
            end
        until not Data_SQL:NextRow()
    end

    
    -- add 1 full level of rested at login while in RAF with Player:SetRestBonus( restBonus )
    if Config.grantRested == 1 and isRecruit == 1 then
        player:SetRestBonus(RAF_xpPerLevel[oldLevel + 1])
    end    

    RAF_cleanup()
    return false
end

local function RAF_levelChange(event, player, oldLevel)
    local isRecruit = 0
    local playerAccountId = player:GetAccountId()
    local playerIP = Player:GetPlayerIP()
    local Data_SQL = CharDBQuery('SELECT recruiter_account FROM `'..Config.customDbName..'`.`recruit_a_friend` WHERE `account_id` = "'..playerAccountId..'" AND `time_stamp` > 0 LIMIT 1;');
    if Data_SQL ~= nil then
        isRecruit = 1
    end
                    
    -- todo: give reward(s) via mail to the recruiter and end RAF when target level is reached

    -- add 1 full level of rested at levelup while in RAF and not at maxlevel with Player:SetRestBonus( restBonus )
    if Config.grantRested == 1 and isRecruit == 1 then
        player:SetRestBonus(RAF_xpPerLevel[oldLevel + 1])
    end 
end


function RAF_cleanup()
    --set all variables to nil
    playerLevel = nil
    playerAccountId = nil
    recruiterAccountId = nil
    recruitAccountId = nil
    recruiterName = nil
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


local function RAF_hasValue (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, RAF_command)
RegisterPlayerEvent(PLAYER_EVENT_ON_LOGIN, RAF_login)
RegisterPlayerEvent(PLAYER_EVENT_ON_LEVEL_CHANGE, RAF_levelChange)
