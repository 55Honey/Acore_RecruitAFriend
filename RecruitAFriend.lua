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
------------------------------------------------------------------------------------------------
-- PLAYER GUIDE: - as the new player(RECRUIT): make yourself RECRUITED by typing ".recruitafriend bind $FriendsCharacterName"
--               - as the new player(RECRUIT): unbind your account from a RECRUITER by typing ".recruitafriend unbind"
--               - as the existing player (RECRUITER): summon your friend with ".recruitafriend summon $FriendsCharacterName"
--               - once the RECRUIT reaches a level set in config, the RECRUITER receives a reward.
------------------------------------------------------------------------------------------------


local Config = {}

-- Name of Eluna dB scheme
Config.customDbName = "ac_eluna"
--max level the ONLY character on the players account may have to become a recruit
Config.maxAllowedLevel = 9
--max number of simultaneous recruits
Config.maxAllowedRecruits = 5
--set to 1 to print error messages to the console. Any other value including nil turns it of.
Config.printErrorsToConsole = 1
-- min GM level to bind accounts without accessing it
Config.minGMRankForCopy = 3
-- max RAF duration in seconds. 2,592,000 = 30days
Config.maxRAFduration = 2592000

------------------------------------------
-- NO ADJUSTMENTS REQUIRED BELOW THIS LINE
------------------------------------------
local PLAYER_EVENT_ON_LOGIN = 3          -- (event, player)
local PLAYER_EVENT_ON_LEVEL_CHANGE = 13  -- (event, player, oldLevel)
local PLAYER_EVENT_ON_COMMAND = 42       -- (event, player, command) - player is nil if command used from console. Can return false

CharDBQuery('CREATE DATABASE IF NOT EXISTS `'..Config.customDbName..'`;');
CharDBQuery('CREATE TABLE IF NOT EXISTS `'..Config.customDbName..'`.`recruit_a_friend` (`account_id` INT(11) NOT NULL, `recruiter_account` INT(11) DEFAULT 0, `time_stamp` INT(11) DEFAULT 0, PRIMARY KEY (`account_id`) );');


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

    if commandArray[1] == "recruitafriend" then

        playerAccountId = player:GetAccountId()
        --let the RECRUITED player remove the existing connection
        if commandArray[2] == "unbind" then
            Data_SQL = CharDBQuery('DELETE FROM `'..Config.customDbName..'`.`recruit_a_friend` WHERE ´account_id` = '..playerAccountId..';');
            RAF_cleanup()
            return false
        end

        -- provide syntax help
        if commandArray[2] == "help" or commandArray[3] == nil then
            RAF_printHelp()
            RAF_cleanup()
            return false
        end

        characterGuid = tostring(player:GetGUID())
        characterGuid = tonumber(characterGuid)

        if commandArray[2] == "bind" then

            --check if this account already has other characters created on it
            Data_SQL = CharDBQuery('SELECT `guid` FROM `characters` WHERE ´account` = '..playerAccountId..' LIMIT 2;');
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

            --check if this account is already linked
            Data_SQL = nil
            local Data_SQL
            Data_SQL = CharDBQuery('SELECT `account_id` FROM `'..Config.customDbName..'`.`recruit_a_friend` WHERE ´account_id` = '..playerAccountId..' LIMIT 1;');
            if Data_SQl ~= nil then
                player:SendBroadcastMessage("Your account is already bound to. Aborting.")
                if Config.printErrorsToConsole == 1 then print("RAF bind failed from AccoundId "..playerAccountId..". This account is already bound.") end
                RAF_cleanup()
                return false
            end

            --check if the RECRUITER account has a maximum of Config.maxAllowedRecruits
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

            Data_SQL = CharDBQuery('SELECT `account_id` FROM `'..Config.customDbName..'`.`recruit_a_friend` WHERE ´recruiter_account` = '..recruiterAccountId..' LIMIT '..Config.maxAllowedRecruits..';');
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

            -- bind the accounts to each other
            Data_SQL = CharDBQuery('DELETE FROM `'..Config.customDbName..'`.`recruit_a_friend` WHERE ´account_id` = '..playerAccountId..';');
            Data_SQL = CharDBQuery('INSERT INTO `'..Config.customDbName..'`.`recruit_a_friend` VALUES (`'..playerAccountId..'`, `'..recruiterAccountId..'`, `'..GetGameTime()..'`);');
            RAF_cleanup()
            return false
        else
            -- print help also, if nothing matched the 2nd argument
            RAF_printHelp()
            RAF_cleanup()
            return false
        end
    elseif commandArray[1] == "recruitafriend" then

    end
    return false
end

function RAF_login(event, player)
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

    -- check for the same IP when a RECRUITER logs in
    playerAccountId = player:GetAccountId()
    playerIP = Player:GetPlayerIP()
    Data_SQL = CharDBQuery('SELECT account_id FROM `'..Config.customDbName..'`.`recruit_a_friend` WHERE `recruiter_account` = "'..playerAccountId..'" LIMIT '..Config.maxAllowedRecruits..';');
    if Data_SQL ~= nil then
        repeat
            recruitAccountId = Data_SQL:GetUInt32(0)
            DataSQL2 = AuthDBQuery('SELECT last_ip FROM `account` WHERE `id` = '..recruitAccountId..';');
            print("tostring(playerIP) = "..tostring(playerIP))
            print("tostring(Data_SQL2:GetString(0)) = "..tostring(Data_SQL2:GetString(0)))
            if tostring(playerIP) == tostring(Data_SQL2:GetString(0)) then
                Data_SQL = CharDBQuery('DELETE FROM `'..Config.customDbName..'`.`recruit_a_friend` WHERE ´recruiter_account` = '..playerAccountId..';');
                player:SendBroadcastMessage("Your Recruit-A-Friend link was removed.")
                if Config.printErrorsToConsole == 1 then print("RAF link removed due to same IP for RECRUITER "..playerAccountId..".") end
                RAF_cleanup()
                return false
            end
        until not Data_SQL:NextRow()
    end

    -- check for the same IP when a RECRUIT logs in
    playerAccountId = player:GetAccountId()
    playerIP = Player:GetPlayerIP()
    Data_SQL = CharDBQuery('SELECT recruiter_account FROM `'..Config.customDbName..'`.`recruit_a_friend` WHERE `account_id` = "'..playerAccountId..'" LIMIT 1;');
    if Data_SQL ~= nil then
        recruiterAccountId = Data_SQL:GetUInt32(0)
        Data_SQL2 = AuthDBQuery('SELECT last_ip FROM `account` WHERE `id` = '..recruiterAccountId..';');
        if tostring(playerIP) == tostring(Data_SQL2:GetString(0)) then
            Data_SQL = CharDBQuery('DELETE FROM `'..Config.customDbName..'`.`recruit_a_friend` WHERE ´recruiter_account` = '..playerAccountId..';');
            player:SendBroadcastMessage("Your Recruit-A-Friend link was removed.")
            if Config.printErrorsToConsole == 1 then print("RAF link removed due to same IP for RECRUITER "..playerAccountId..".") end
            RAF_cleanup()
            return false
        end
    end

    -- check for RAF timeout on login of the RECRUIT
    Data_SQL = CharDBQuery('SELECT `time_stamp` FROM `'..Config.customDbName..'`.`recruit_a_friend` WHERE ´account_id` = '..playerAccountId..' LIMIT 1;');
    if Data_SQL ~= nil then linkTime = Data_SQL:GetUInt32(0) end
    -- todo: not done here

    --remove the RAF link after the period given in config
    if Config.maxRAFduration + linkTime < GetGameTime() then
        Data_SQL = CharDBQuery('DELETE FROM `'..Config.customDbName..'`.`recruit_a_friend` WHERE ´account_id` = '..playerAccountId..';');
        player:SendBroadcastMessage("Your Recruit-A-Friend link was removed because it timed out.")
        if Config.printErrorsToConsole == 1 then print("RAF link removed due to timeout for RECRUIT "..playerAccountId..".") end
        RAF_cleanup()
        return false
    end

    -- todo: check for the reward conditions being fulfilled AFTER ip check and BEFORE timeout check

    -- check for RAF timeout on login of the RECRUITER
    Data_SQL = CharDBQuery('SELECT `account_id` FROM `'..Config.customDbName..'`.`recruit_a_friend` WHERE ´recruiter_account` = '..playerAccountId..' LIMIT '..Config.maxAllowedRecruits..';');
    if Data_SQL ~= nil then
        repeat
            recruitAccountId = Data_SQL:GetUInt32(0)
            Data_SQL2 = CharDBQuery('SELECT `time_stamp` FROM `'..Config.customDbName..'`.`recruit_a_friend` WHERE ´recruiter_account` = '..recruitAccountId..' LIMIT 1;');
            if Data_SQL2 ~= nil then linkTime = Data_SQL2:GetUInt32(0) end
            --remove the RAF link after the period given in config
            if Config.maxRAFduration + linkTime < GetGameTime() then
                Data_SQL = CharDBQuery('DELETE FROM `'..Config.customDbName..'`.`recruit_a_friend` WHERE ´account_id` = '..recruitAccountId..';');
                player:SendBroadcastMessage("Your Recruit-A-Friend link was removed because it timed out.")
                if Config.printErrorsToConsole == 1 then print("RAF link removed due to timeout for RECRUIT "..recruitAccountId..".") end
                RAF_cleanup()
                return false
            end
        until not Data_SQL:NextRow()
    end


    -- todo: add rested at login while in RAF with Player:SetRestBonus( restBonus )

    RAF_cleanup()
    return false
end

function RAF_levelChange()
    -- todo: give rewards and end RAF
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

function RAF_printHelp()
    player:SendBroadcastMessage("Syntax to become a recruit: .recruitafriend bind $FriendsCharacterName")
    player:SendBroadcastMessage("Syntax to stop being a recruit: .recruitafriend unbind")
    player:SendBroadcastMessage("Syntax to summon the recruit: .recruitafriend bind $FriendsCharacterName")
    RAF_cleanup()
    return false
end

RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, RAF_command)
RegisterPlayerEvent(PLAYER_EVENT_ON_LOGIN, RAF_login)
RegisterPlayerEvent(PLAYER_EVENT_ON_LEVEL_CHANGE, RAF_levelChange)
