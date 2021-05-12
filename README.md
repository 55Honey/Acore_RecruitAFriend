## RecruitAFriend
Lua script for Azerothcore with ElunaLua to connect accounts from different players and reward the recruiter for bringing active players.

### This repo is work in progress

## Requirements:
Compile your [Azerothcore](https://github.com/azerothcore/azerothcore-wotlk) with [Eluna Lua](https://www.azerothcore.org/catalogue-details.html?id=131435473).
The ElunaLua module itself doesn't require much setup/config. Just specify the subfolder where to put your lua_scripts in its .conf file.

If the directory was not changed, add the .lua script to your `../lua_scripts/` directory.
Adjust the top part of the .lua file with the config flags.

## Admin usage:
Adjust the top part of the .lua file with the config flags. The most importan decisions are:
- max duration of the raf link(default 30 days)
- target level for a succesful link and a reward to the recruiter
- check for same IP yes/no, auto end RAF if same IP yes/no (default check:yes, end: no)
- text for the RAF-reward mail (see Lua for defaults)
- rewards as item id and amount (see Lua for defaults)
- maps to allow summoning to (default Eastern Kingdoms and Kamlimdor)

`.bindraf $recruit $recruiter` binds the accounts to each other. It is advised to use this from SOAP during account creation. One recruiter can have multiple recruits. Restricted by `Config.minGMRankForBind`. Once the recruit reaches the target level, the recruiter will receive a reward based on their amount of already finished recruits. Target level, item and amount for certain reward levels are all config flags.

The RAF creates a custom db scheme specified in the config flags. Inside the scheme is a table to store all current and past RAF links.
- `time_stamp`is in UNIX-time
- `ip_abuse_counter` is increased everytime recruiter and rectuit have the same IPs during login or summon 
- `kick_counter` is increased everytime a player gets kicked because they reached the allowed number of actions specified in `Config.abuseTreshold`.
- `reward_level` stores how many recruiters of that account have succesfully reached the RAF link up to `Config.targetLevel`.
- all other columns in `recruit_a_friend_links` and `recruit_a_friend_rewards` are account id's

Optionally:

`.forcebindraf $recruit $recruiter` same as .bindraf but ignores past binds. Failed, succesful or timed out doesn't matter.

## Player Usage:
- `.raf`        prints your account id and also prints help
- `.raf help`   prints your account id and also prints help
- `.raf list`   shows the account ids of all your recruits
- `.raf summon` allows the recruiter so summon the recruit. The recruit can not summon.

Players have 30 days (config flag) to reach the target level (default 29). If they succeed, their recruiter gets a reward. There is a counter in place and rewards change with a higher amount of succesful recruits. Default rewards are pets, a bag and potions/elixirs.


#### Find me on patreon: https://www.patreon.com/Honeys

## Config:

See the lua file for a description of the config flags