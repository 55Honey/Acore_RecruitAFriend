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
--               -  bind a recruiter: .bindsor $ResurrectedAccountId $existingRecruiterId
------------------------------------------------------------------------------------------------
-- PLAYER GUIDE: - as the new player(RESURRECTED): make yourself RESURRECTED by selecting your recruiters ID on the website
--               - as the existing player (RECRUITER): summon your friend with ".sor summon $FriendsCharacterName"
--               - discover your own account id by typing ".sor help"
--               - once the RESURRECTED reaches a level set in config, the RECRUITER receives a reward.
--               - same IP possibly restricts or removes the bind (sorry families, roommates and the like)
------------------------------------------------------------------------------------------------

local Config = {}
local Config_maps = {}
local Config_rewards = {}
local Config_amounts = {}
local Config_defaultRewards = {}
local Config_defaultAmounts = {}
local Config_resurrectRewards = {}
local Config_resurrectAmounts = {}

-- Name of Eluna dB scheme
Config.customDbName = "ac_eluna"

-- set to 1 to print error messages to the console. Any other value including nil turns it off.
Config.printErrorsToConsole = 1

-- min GM level to bind accounts
Config.minGMRankForBind = 3

-- min GM level to read data
Config.minGMRankForRead = 2

-- max SOR duration in seconds. 2,592,000 = 30days
Config.maxSORduration = 2592000

-- set to 1 to grant resurrected accounts always rested. Any other value including nil turns it off.
Config.grantRested = 1

-- set to 1 to print a login message. Any other value including nil turns it off.
Config.displayLoginMessage = 1

-- the level which a player must reach to reward it's recruiter and automatically end SOR
Config.targetLevel = 60

-- set to 1 to grant always rested for premium past Config.targetLevel. Any other value including nil turns it off.
-- the same feature exists in the RecruitAFriend.lua. Only one of them is required to be 1. Setting both to 1 causes
-- additional load but yields no benefit.
Config.premiumFeature = 0

-- maximum number of SOR related command uses before a kick. Includes summon requests.
Config.abuseTreshold = 1000

-- determines if there is a check for summoner and target being on the same Ip
Config.checkSameIp = 1

-- set to 1 to end SOR if linked accounts share an IP on the first infraction. Any other value including nil turns it off.
Config.endSOROnSameIP = 0

-- text for the mail to send when rewarding a recruiter
Config.mailText = "Hello Adventurer!\nYou've earned a reward for bringing your friends back to Chromie.\nDon't stop here, there might be more goods to gain.\n\n"

-- text for the mail to send when a resurrected player has reached the target level
Config.mailTextResurrected = "Hello Adventurer!\nYou've earned a reward for successfully returning to Chromie.\nWe're glad to have you around. Welcome back!\n\n"

-- modify's the mail database to prevent returning of rewards. Changes sender from character to creature. Config.senderGUID points to a creature if this is 1
Config.preventReturn = 1

-- GUID/ID of the player/creature. If Config.preventReturn = 1, you need to put creature ID. Else player GUID. 0 = No sender aka "From: Unknown". Creature 10667 is "Chromie".
Config.senderGUID = 10667

-- stationary used in the mail sent to the player. (41 Normal Mail, 61 GM/Blizzard Support, 62 Auction, 64 Valentines, 65 Christmas) Note: Use 62, 64, and 65 At your own risk.
Config.mailStationery = 41

-- should links on the same IP be removed automatically on startup / reload?
Config.AutoKillSameIPLinks = 1

-- rewards towards the recruiter for certain amounts of resurrected accounts who reached the target level. If not defined for a level, send the whole set of defaultRewards
--Config_rewards[1] =
--Config_rewards[3] = 14046    -- Runecloth Bag - 14-slot
--Config_rewards[5] =
--Config_rewards[10] =

-- amount of rewards per reward_level FOR RECRUITERS
Config_amounts[1] = 1
Config_amounts[3] = 1
Config_amounts[5] = 1
Config_amounts[10] = 1

-- default rewards if nothing is set in Config_rewards for a certain level. May be changed. May NOT be removed. FOR RECRUITERS
Config_defaultRewards[1] = 9155   -- Battle elixir spellpower
Config_defaultRewards[2] = 9187   -- Battle elixir agility
Config_defaultRewards[3] = 9206   -- Battle elixir strength
Config_defaultRewards[4] = 5634   -- Potion of Free Action

Config_defaultAmounts[1] = 10
Config_defaultAmounts[2] = 10
Config_defaultAmounts[3] = 10
Config_defaultAmounts[4] = 9

-- rewards for the resurrected player when reaching the target
Config_resurrectRewards[1] = 13510
Config_resurrectRewards[2] = 13511
Config_resurrectRewards[3] = 13512
Config_resurrectRewards[4] = 17966

Config_resurrectAmounts[1] = 5
Config_resurrectAmounts[2] = 5
Config_resurrectAmounts[3] = 5
Config_resurrectAmounts[4] = 1

-- The following are the allowed maps to summon to. Additional maps can be added with a table.insert() line.
-- Remove or comment all table.insert below to forbid summoning
-- Eastern kingdoms
table.insert(Config_maps, 0)
-- Kalimdor
table.insert(Config_maps, 1)
-- Outland
table.insert(Config_maps, 530)
-- Northrend
--table.insert(Config_maps, 571)
------------------------------------------
-- NO ADJUSTMENTS REQUIRED BELOW THIS LINE
------------------------------------------

local PLAYER_EVENT_ON_LOGIN = 3          -- (event, player)
local PLAYER_EVENT_ON_LEVEL_CHANGE = 13  -- (event, player, oldLevel)
local PLAYER_EVENT_ON_COMMAND = 42       -- (event, player, command) - player is nil if command used from console. Can return false

CharDBQuery('CREATE DATABASE IF NOT EXISTS `'..Config.customDbName..'`;');
CharDBQuery('CREATE TABLE IF NOT EXISTS `'..Config.customDbName..'`.`scroll_of_resurrection_links` (`account_id` INT NOT NULL, `recruiter_account` INT DEFAULT 0, `time_stamp` INT DEFAULT 0, `ip_abuse_counter` INT DEFAULT 0, `kick_counter` INT DEFAULT 0, `comment` varchar(255) DEFAULT "", PRIMARY KEY (`account_id`) );');
CharDBQuery('CREATE TABLE IF NOT EXISTS `'..Config.customDbName..'`.`scroll_of_resurrection_rewards` (`recruiter_account` INT DEFAULT 0, `reward_level` INT DEFAULT 0, PRIMARY KEY (`recruiter_account`) );');

--sanity check
if Config_defaultRewards[1] == nil or Config_defaultRewards[2] == nil or Config_defaultRewards[3] == nil or Config_defaultRewards[4] == nil then
    PrintError("SOR: The Config_defaultRewards value was removed for at least one flag ([1]-[4] are required.)")
end

if Config.AutoKillSameIPLinks == 1 then
    CharDBQuery('UPDATE `'..Config.customDbName..'`.scroll_of_resurrection_links SET time_stamp = 0 WHERE ip_abuse_counter > 5 AND time_stamp > 1;')
end

--globals:
SOR_xpPerLevel = {}
SOR_recruiterAccount = {}
SOR_timeStamp = {}
SOR_abuseCounter = {}
SOR_sameIpCounter = {}
SOR_kickCounter = {}
SOR_lastIP = {}
SOR_rewardLevel = {}

local function SOR_numeralise(n)
    n = tostring(n)
    if string.sub(n, -1) == "1" then
        n = n.."st"
    elseif string.sub(n, -1) == "2" then
        n = n.."nd"
    elseif string.sub(n, -1) == "3" then
        n = n.."rd"
    else
        n = n.."th"
    end
    return n
end

-- unix to date conversion based on http://www.ethernut.de/api/gmtime_8c_source.html
local floor=math.floor

local DSEC=24*60*60 -- secs in a day
local YSEC=365*DSEC -- secs in a year
local LSEC=YSEC+DSEC    -- secs in a leap year
local FSEC=4*YSEC+DSEC  -- secs in a 4-year interval
local BASE_DOW=4    -- 1970-01-01 was a Thursday
local BASE_YEAR=1970    -- 1970 is the base year

local _days={
    -1, 30, 58, 89, 119, 150, 180, 211, 242, 272, 303, 333, 364
}
local _lpdays={}
for i=1,2  do _lpdays[i]=_days[i]   end
for i=3,13 do _lpdays[i]=_days[i]+1 end

local function SOR_gmtime(t)
    local y,j,m,d,w,h,n,s
    local mdays=_days
    s=t
    -- First calculate the number of four-year-interval, so calculation
    -- of leap year will be simple. Btw, because 2000 IS a leap year and
    -- 2100 is out of range, this formula is so simple.
    y=floor(s/FSEC)
    s=s-y*FSEC
    y=y*4+BASE_YEAR         -- 1970, 1974, 1978, ...
    if s>=YSEC then
        y=y+1           -- 1971, 1975, 1979,...
        s=s-YSEC
        if s>=YSEC then
            y=y+1       -- 1972, 1976, 1980,... (leap years!)
            s=s-YSEC
            if s>=LSEC then
                y=y+1   -- 1971, 1975, 1979,...
                s=s-LSEC
            else        -- leap year
                mdays=_lpdays
            end
        end
    end
    j=floor(s/DSEC)
    s=s-j*DSEC
    local m=1
    while mdays[m]<j do m=m+1 end
    m=m-1
    local d=j-mdays[m]
    -- Calculate day of week. Sunday is 0
    w=(floor(t/DSEC)+BASE_DOW)%7
    -- Calculate the time of day from the remaining seconds
    h=floor(s/3600)
    s=s-h*3600
    n=floor(s/60)
    s=s-n*60
    d = SOR_numeralise(d)
    return(({"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"})[m]..', '..d..' '..y..' '..h..':'..n..':'..s)
end

local function SOR_PreventReturn(playerGUID)
    if Config.preventReturn == 1 then
        CharDBExecute('UPDATE `mail` SET `messageType` = 3 WHERE `sender` = '..Config.senderGUID..' AND `receiver` = '..playerGUID..' AND `messageType` = 0;')
    end
end

local function SOR_cleanup()
    --todo: check variables for required cleanups
    --set all non local runtime variables to nil
end

local function SOR_splitString(inputstr, seperator)
    if seperator == nil then
        seperator = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..seperator.."]+)") do
        table.insert(t, str)
    end
    return t
end

local function SOR_hasValue (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

local function SOR_hasIndex (tab, val)
    for index, value in ipairs(tab) do
        if index == val then
            return true
        end
    end
    return false
end

local function SOR_checkAbuse(accountId)
    if SOR_abuseCounter[accountId] == nil then
        SOR_abuseCounter[accountId] = 1
    else
        SOR_abuseCounter[accountId] = SOR_abuseCounter[accountId] + 1
    end

    if SOR_abuseCounter[accountId] > Config.abuseTreshold then
        return true
    end
    return false
end

local function SOR_command(event, player, command, chatHandler)
    local commandArray = {}
    -- split the command variable into several strings which can be compared individually
    commandArray = SOR_splitString(command)

    if commandArray[1] ~= "bindsor" and commandArray[1] ~= "forcebindsor" and commandArray[1] ~= "sor" then
        return
    end

    if commandArray[2] ~= nil then
        commandArray[2] = commandArray[2]:gsub("[';\\, ]", "")
        if commandArray[3] ~= nil then
            commandArray[3] = commandArray[3]:gsub("[';\\, ]", "")
        end
    end

    if commandArray[1] == "bindsor" then

        if player ~= nil then
            if player:GetGMRank() < Config.minGMRankForBind then
                if Config.printErrorsToConsole == 1 then PrintInfo("Account "..player:GetAccountId().." tried the .bindsor command without sufficient rights.") end
                return
            end
        end

        local commandSource
        if player == nil then
            commandSource = "worldserver console"
        else
            commandSource = "account id: "..tostring(player:GetAccountId())
        end
        -- GM/SOAP command to bind from console or ingame commands
        if commandArray[2] ~= nil and commandArray[3] ~= nil then
            local accountId = tonumber(commandArray[2])
            if SOR_recruiterAccount[accountId] == nil then
                SOR_recruiterAccount[accountId] = tonumber(commandArray[3])
                SOR_timeStamp[accountId] = (tonumber(tostring(GetGameTime())))
                CharDBExecute('REPLACE INTO `'..Config.customDbName..'`.`scroll_of_resurrection_links` VALUES ('..accountId..', '..SOR_recruiterAccount[accountId]..', '..SOR_timeStamp[accountId]..', 0, 0, "");')
                chatHandler:SendSysMessage(commandSource.." has succesfully used the .bindsor command on resurrected account "..accountId.." and recruiter "..SOR_recruiterAccount[accountId]..".")
            else
                chatHandler:SendSysMessage("The selected account "..accountId.." is already resurrected by "..SOR_recruiterAccount[accountId]..".")
            end
        else
            chatHandler:SendSysMessage("Admin/GM Syntax: .bindsor $resurrected_account $recruiter binds the accounts to each other.")
            chatHandler:SendSysMessage("Admin/GM Syntax: .forcebindsor $resurrected_account $recruiter same as .bindsor but ignores past binds. Previously unbound, succesful or timed out doesn't matter.")
        end
        SOR_cleanup()
        return false

    elseif commandArray[1] == "forcebindsor" then

        if player ~= nil then
            if player:GetGMRank() < Config.minGMRankForBind then
                if Config.printErrorsToConsole == 1 then PrintInfo("Account "..player:GetAccountId().." tried the .forcebindsor command without sufficient rights.") end
                return
            end
        end

        local commandSource
        if player == nil then
            commandSource = "worldserver console"
        else
            commandSource = "account id: "..tostring(player:GetAccountId())
        end
        -- GM/SOAP command to force bind from console or ingame commands
        if commandArray[2] ~= nil and commandArray[3] ~= nil then
            local accountId = tonumber(commandArray[2])
            SOR_recruiterAccount[accountId] = tonumber(commandArray[3])
            SOR_timeStamp[accountId] = (tonumber(tostring(GetGameTime())))
            CharDBExecute('REPLACE INTO `'..Config.customDbName..'`.`scroll_of_resurrection_links` VALUES ('..accountId..', '..SOR_recruiterAccount[accountId]..', '..SOR_timeStamp[accountId]..', 0, 0, "");')
            chatHandler:SendSysMessage(commandSource.." has succesfully used the .forcebindsor command on resurrected account "..accountId.." and recruiter "..SOR_recruiterAccount[accountId]..".")
        else
            chatHandler:SendSysMessage("Admin/GM Syntax: .bindsor $resurrected_account $recruiter binds the accounts to each other.")
            chatHandler:SendSysMessage("Admin/GM Syntax: .forcebindsor $resurrected_account $recruiter same as .bindsor but ignores past binds. Previously unbound, succesful or timed out doesn't matter.")
        end
        SOR_cleanup()
        return false


    elseif commandArray[1] == "sor" then

        if player ~= nil then
            if SOR_checkAbuse(player:GetAccountId()) == true then
                local resurrectedId
                player:KickPlayer()
                for index, value in pairs(SOR_recruiterAccount) do
                    if value == player:GetAccountId() then
                        resurrectedId = index
                    end
                end
                if SOR_kickCounter[resurrectedId] == nil then
                    SOR_kickCounter[resurrectedId] = 1
                else
                    SOR_kickCounter[resurrectedId] = SOR_kickCounter[resurrectedId] + 1
                    CharDBExecute('UPDATE `'..Config.customDbName..'`.`scroll_of_resurrection_links` SET `kick_counter` = '..SOR_kickCounter[resurrectedId]..' WHERE `account_id` = '..resurrectedId..';')
                    if Config.printErrorsToConsole == 1 then PrintError("SOR: account id "..player:GetAccountId().." was kicked because of too many .sor commands.") end
                end
            end
        end

        -- list all accounts resurrected by this account
        if commandArray[2] == "list" then

            if player == nil then
                chatHandler:SendSysMessage("'.sor list' is not meant to be used from the console.")
                return false
            end

            -- print all resurrected accounts bound to this account by charname
            local idList
            for index, value in pairs(SOR_recruiterAccount) do
                if value == player:GetAccountId() then
                    if SOR_timeStamp[index] > 1 then
                        if idList == nil then
                            idList = index
                        else
                            idList = idList.." "..index
                        end
                    end
                end
            end
            if idList == nil then
                idList = "none"
            end


            chatHandler:SendSysMessage("Your current resurrected accounts are: "..idList)
            SOR_cleanup()
            return false

        elseif commandArray[2] == "summon" then
            if player == nil then
                chatHandler:SendSysMessage("'.sor summon' is not meant to be used from the console.")
                return false
            end

            if commandArray[3] == nil then
                chatHandler:SendSysMessage("'.sor summon' requires the name of the target. Use '.sor summon $Name'")
                return false
            else
                commandArray[3] = commandArray[3]:gsub("^%l", string.upper)
            end

            -- check if the target is resurrected by the player
            local summonPlayer = GetPlayerByName(commandArray[3])
            if summonPlayer == nil then
                chatHandler:SendSysMessage("Target not found. Check spelling and capitalization.")
                SOR_cleanup()
                return false
            end

            if SOR_recruiterAccount[summonPlayer:GetAccountId()] ~= player:GetAccountId() then
                chatHandler:SendSysMessage("The requested player is not resurrected by you.")
                SOR_cleanup()
                return false
            end

            if SOR_timeStamp[summonPlayer:GetAccountId()] == 0 or SOR_timeStamp[summonPlayer:GetAccountId()] == 1 then
                chatHandler:SendSysMessage("The requested player is not resurrected by you anymore.")
                SOR_cleanup()
                return false
            end

            -- do the zone/combat checks and possibly summon
            local mapId = player:GetMapId()
            -- allow to proceed if the player is on one of the maps listed above
            if SOR_hasValue(Config_maps, mapId) then
                --allow to proceed if the player is not in combat
                if not player:IsInCombat() then
                    local group = player:GetGroup()
                    if group == nil then
                        chatHandler:SendSysMessage("You must be in a party or raid to summon your resurrected friend.")
                        return false
                    end
                    local groupPlayers = group:GetMembers()
                    for _, v in pairs(groupPlayers) do
                        if v:GetName() == commandArray[3] then
                            if player:GetPlayerIP() == v:GetPlayerIP() and Config.checkSameIp == 1 and SOR_timeStamp[summonPlayer:GetAccountId()] >= 2 then
                                chatHandler:SendSysMessage("Possible abuse detected. Aborting. This action is logged.")
                                if SOR_sameIpCounter[summonPlayer:GetAccountId()] == nil then
                                    SOR_sameIpCounter[summonPlayer:GetAccountId()] = 1
                                    CharDBExecute('UPDATE `'..Config.customDbName..'`.`scroll_of_resurrection_links` SET ip_abuse_counter = '..SOR_sameIpCounter[summonPlayer:GetAccountId()]..' WHERE `account_id` = '..summonPlayer:GetAccountId()..';')
                                    SOR_cleanup()
                                    return false
                                else
                                    SOR_sameIpCounter[summonPlayer:GetAccountId()] = SOR_sameIpCounter[summonPlayer:GetAccountId()] + 1
                                    CharDBExecute('UPDATE `'..Config.customDbName..'`.`scroll_of_resurrection_links` SET ip_abuse_counter = '..SOR_sameIpCounter[summonPlayer:GetAccountId()]..' WHERE `account_id` = '..summonPlayer:GetAccountId()..';')
                                    SOR_cleanup()
                                    return false
                                end
                            end
                            v:SummonPlayer(player)
                        end
                    end
                else
                    chatHandler:SendSysMessage("Summoning is not possible in combat.")
                end
                return false
            else
                chatHandler:SendSysMessage("Summoning is not possible here.")
            end
            return false

        elseif commandArray[2] == "unbind" and commandArray[3] == nil then
            if player == nil then
                chatHandler:SendSysMessage("Console can not have resurrected accounts to remove.")
                return false
            end

            local accountId = player:GetAccountId()
            if SOR_recruiterAccount[accountId] ~= nil and SOR_timeStamp[accountId] > 1 then
                SOR_timeStamp[accountId] = 0
                CharDBExecute('UPDATE `'..Config.customDbName..'`.`scroll_of_resurrection_links` SET time_stamp = 0 WHERE `account_id` = '..accountId..';')
                chatHandler:SendSysMessage("Your Scroll-of-Resurrection link was removed by choice.")
            else
                chatHandler:SendSysMessage("Your account is not resurrected (anymore).")
            end

            return false

        elseif commandArray[2] == "help" or commandArray[2] == nil then
            if player == nil then
                chatHandler:SendSysMessage("Admin/GM Syntax: .bindsor $resurrected_account $recruiter binds the accounts to each other.")
                chatHandler:SendSysMessage("Admin/GM Syntax: .forcebindsor $resurrected_account $recruiter same as .bindsor but ignores past binds. Previously unbound, succesful or timed out doesn't matter.")
            else
                chatHandler:SendSysMessage("Your account id is: "..player:GetAccountId())
            end

            chatHandler:SendSysMessage("Syntax to list all resurrected accounts: .sor list")
            chatHandler:SendSysMessage("Syntax to summon the resurrected: .sor summon $FriendsCharacterName")
            chatHandler:SendSysMessage("Only the recruiter can summon the resurrected friend. The resurrected account can NOT summon. You must be in a party/raid with each other.")
            SOR_cleanup()
            return false

        elseif commandArray[2] == "lookup" then
            if player == nil or player:GetGMRank() >= Config.minGMRankForRead then
                if commandArray[3] == nil then
                    chatHandler:SendSysMessage('Expected syntax: .sor lookup $accountId')
                    return false
                end

                commandArray[3] = tonumber(commandArray[3])
                if SOR_recruiterAccount[commandArray[3]] ~= nil then

                    chatHandler:SendSysMessage('SOR Data for account '..commandArray[3]..':')
                    chatHandler:SendSysMessage('Recruiter account: '..SOR_recruiterAccount[commandArray[3]])

                    if SOR_timeStamp[commandArray[3]] == 0 then
                        chatHandler:SendSysMessage('The SOR link was removed or expired.')
                    elseif SOR_timeStamp[commandArray[3]] == 1 then
                        chatHandler:SendSysMessage('The SOR link was succesful but is over.')
                    elseif SOR_timeStamp[commandArray[3]] == -1 then
                        chatHandler:SendSysMessage('The SOR link is permanently activated for a contributor.')
                    else
                        chatHandler:SendSysMessage('The SOR link is active and was activated at '..SOR_gmtime(SOR_timeStamp[commandArray[3]]))
                    end
                    chatHandler:SendSysMessage('Same IP counter: '..SOR_sameIpCounter[commandArray[3]])
                    chatHandler:SendSysMessage('Kick counter: '..SOR_kickCounter[commandArray[3]])
                    if SOR_rewardLevel[commandArray[3]] ~=nil then
                        chatHandler:SendSysMessage('Reward Level: '..SOR_rewardLevel[commandArray[3]])
                    else
                        chatHandler:SendSysMessage('Reward Level: 0')
                    end
                else
                    chatHandler:SendSysMessage('Account with ID '..commandArray[3]..' has not been resurrected.')
                end
                return false
            end
        end
    end
end

local function SOR_login(event, player)
    local accountId = player:GetAccountId()

    -- display login message
    if Config.displayLoginMessage == 1 then
        player:SendBroadcastMessage("This server features a Scroll-of-Resurrection module. Type .sor for help.")
    end

    SOR_lastIP[accountId] = player:GetPlayerIP()

    -- check for an existing SOR connection when a RESURRECTED or RECRUITER logs in
    local recruiterId = SOR_recruiterAccount[player:GetAccountId()]
    if recruiterId == nil and SOR_hasIndex(SOR_recruiterAccount, player:GetAccountId()) == false then
        return false
    end

    -- check for SOR timeout on login of the RESURRECTED, possibly remove the link
    if SOR_timeStamp[accountId] <= 1 then
        if SOR_timeStamp[accountId] == -1 and Config.premiumFeature == 1 then
            player:SetRestBonus(SOR_xpPerLevel[player:GetLevel()])
            return false
        else
            return false
        end
    end

    --reset abuse counter
    SOR_abuseCounter[accountId] = 0

    local targetDuration = SOR_timeStamp[accountId] + Config.maxSORduration
    if (tonumber(tostring(GetGameTime()))) > targetDuration then
        SOR_timeStamp[accountId] = 0
        CharDBExecute('UPDATE `'..Config.customDbName..'`.`scroll_of_resurrection_links` SET time_stamp = 0 WHERE `account_id` = '..accountId..';')
        player:SendBroadcastMessage("Your SOR link has reached the time-limit and expired.")
        return false
    end

    -- add 1 full level of rested at login while in SOR
    if Config.grantRested == 1 then
        player:SetRestBonus(SOR_xpPerLevel[player:GetLevel()])
    end

    -- same IP check
    local recruiterId = SOR_recruiterAccount[accountId]
    if SOR_lastIP[accountId] == SOR_lastIP[recruiterId] then
        if Config.endSOROnSameIP == 1 then
            player:SendBroadcastMessage("The SOR link was removed")
            CharDBExecute('UPDATE `'..Config.customDbName..'`.`scroll_of_resurrection_links` SET time_stamp = 0 WHERE `account_id` = '..accountId..';')
            SOR_timeStamp[accountId] = 0
        else
            player:SendBroadcastMessage("Scroll of Resurrection: Possible abuse detected. This action is logged.")
            if SOR_sameIpCounter[accountId] == nil then
                SOR_sameIpCounter[accountId] = 1
            else
                SOR_sameIpCounter[accountId] = SOR_sameIpCounter[accountId] + 1
            end
            CharDBExecute('UPDATE `'..Config.customDbName..'`.`scroll_of_resurrection_links` SET ip_abuse_counter = '..SOR_sameIpCounter[accountId]..' WHERE `account_id` = '..accountId..';')
        end
    end

    SOR_cleanup()
    return false
end

local function GrantReward(recruiterId,player)

    local recruiterCharacter
    if SOR_rewardLevel[recruiterId] == nil then
        SOR_rewardLevel[recruiterId] = 1
        CharDBExecute('REPLACE INTO `'..Config.customDbName..'`.`scroll_of_resurrection_rewards` VALUES ('..recruiterId..', '..SOR_rewardLevel[recruiterId]..');')
    else
        SOR_rewardLevel[recruiterId] = SOR_rewardLevel[recruiterId] + 1
        CharDBExecute('UPDATE `'..Config.customDbName..'`.`scroll_of_resurrection_rewards` SET reward_level = '..SOR_rewardLevel[recruiterId]..' WHERE `recruiter_account` = '..recruiterId..';')
    end

    local Data_SQL = CharDBQuery('SELECT `guid` FROM `characters` WHERE `account` = '..recruiterId..' LIMIT 1;')
    if Data_SQL ~= nil then
        recruiterCharacter = Data_SQL:GetUInt32(0)
    else
        if Config.printErrorsToConsole == 1 then PrintError("SOR: No character found on recruiter account with id "..recruiterId..", which was eligable for a SOR reward of level "..SOR_recruiterAccount[recruiterId]..".") end
        return
    end

    --reward the recruiter
    local rewardLevel = SOR_rewardLevel[recruiterId]
    if Config_rewards[rewardLevel] == nil then
        --send the default set
        SendMail("SOR reward level "..rewardLevel, Config.mailText, recruiterCharacter, Config.senderGUID, Config.mailStationery, 0, 0, 0, Config_defaultRewards[1], Config_defaultAmounts[1], Config_defaultRewards[2], Config_defaultAmounts[2], Config_defaultRewards[3], Config_defaultAmounts[3], Config_defaultRewards[4], Config_defaultAmounts[4])
    else
        SendMail("SOR reward level "..rewardLevel, Config.mailText, recruiterCharacter, Config.senderGUID, Config.mailStationery, 0, 0, 0, Config_rewards[rewardLevel], Config_amounts[rewardLevel])
    end
    SOR_PreventReturn(recruiterCharacter)
    --reward the recruit
    local playerGUID = player:GetGUIDLow()
    SendMail("Scroll OF Resurrection Reward", Config.mailTextResurrected, playerGUID, Config.senderGUID, Config.mailStationery, 0, 0, 0, Config_resurrectRewards[1], Config_resurrectAmounts[1], Config_resurrectRewards[2], Config_resurrectAmounts[2], Config_resurrectRewards[3], Config_resurrectAmounts[3], Config_resurrectRewards[4], Config_resurrectAmounts[4])
end

local function SOR_levelChange(event, player, oldLevel)

    local accountId = player:GetAccountId()
    -- check for SOR timeout on login of the RESURRECTED, possibly remove the link
    if SOR_recruiterAccount[accountId] == nil or SOR_timeStamp[accountId] <= 1 then
        if SOR_timeStamp[accountId] == -1 and Config.premiumFeature == 1 then
            player:SetRestBonus(SOR_xpPerLevel[oldLevel + 1])
            return false
        else
            return false
        end
    end

    if oldLevel + 1 >= Config.targetLevel then
        -- set time_stamp to 1 and Grant rewards
        SOR_timeStamp[accountId] = 1
        CharDBExecute('UPDATE `'..Config.customDbName..'`.`scroll_of_resurrection_links` SET time_stamp = 1 WHERE `account_id` = '..accountId..';')
        GrantReward(SOR_recruiterAccount[accountId],player)
        player:SendBroadcastMessage("Your SOR link has reached the level-limit. Your recruiter has earned a reward. Go and bring your friends, too!")
        return false
    end

    local recruiterId = SOR_recruiterAccount[accountId]
    if recruiterId == nil then
        return false
    end

    -- add 1 full level of rested at levelup while in SOR and not at maxlevel with Player:SetRestBonus( restBonus )
    if Config.grantRested == 1 then
        player:SetRestBonus(SOR_xpPerLevel[oldLevel + 1])
    end
end

--INIT sequence:
--global table which reads the required XP per level one single time on load from the db instead of one value every levelup event
local SOR_Data_SQL
local SOR_row = 1
local SOR_Data_SQL = WorldDBQuery('SELECT Experience FROM player_xp_for_level WHERE Level <= 80;')
if SOR_Data_SQL ~= nil then
    repeat
        SOR_xpPerLevel[SOR_row] = SOR_Data_SQL:GetUInt32(0)
        SOR_row = SOR_row + 1
    until not SOR_Data_SQL:NextRow()
else
    PrintError("SOR: Error reading player_xp_for_level from tha database.")
end
SOR_Data_SQL = nil
SOR_row = nil

--global table which stores already granted rewards
local SOR_Data_SQL
local SOR_id
SOR_Data_SQL = CharDBQuery('SELECT * FROM `'..Config.customDbName..'`.`scroll_of_resurrection_rewards`;')
if SOR_Data_SQL ~= nil then
    repeat
        SOR_id = tonumber(SOR_Data_SQL:GetUInt32(0))
        SOR_rewardLevel[SOR_id] = tonumber(SOR_Data_SQL:GetUInt32(1))
    until not SOR_Data_SQL:NextRow()
else
    PrintError("SOR: Found no granted rewards in the scroll_of_resurrection_rewards table. Possibly there are none yet.")
end

--global table which stores all SOR links
local SOR_Data_SQL
local SOR_id
SOR_Data_SQL = CharDBQuery('SELECT * FROM `'..Config.customDbName..'`.`scroll_of_resurrection_links`;')

if SOR_Data_SQL ~= nil then
    repeat
        SOR_id = tonumber(SOR_Data_SQL:GetUInt32(0))
        SOR_recruiterAccount[SOR_id] = tonumber(SOR_Data_SQL:GetUInt32(1))
        SOR_timeStamp[SOR_id] = tonumber(SOR_Data_SQL:GetInt32(2))
        SOR_sameIpCounter[SOR_id] = SOR_Data_SQL:GetUInt32(3)
        SOR_kickCounter[SOR_id] = tonumber(SOR_Data_SQL:GetUInt32(4))
    until not SOR_Data_SQL:NextRow()
else
    PrintError("SOR: Found no linked accounts in the scroll_of_resurrection_links table. Possibly there are none yet.")
end

RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, SOR_command)
RegisterPlayerEvent(PLAYER_EVENT_ON_LOGIN, SOR_login)
RegisterPlayerEvent(PLAYER_EVENT_ON_LEVEL_CHANGE, SOR_levelChange)
