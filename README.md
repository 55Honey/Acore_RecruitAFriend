## RecruitAFriend
Lua script for Azerothcore with ElunaLua to connect accounts from different players and reward the recruiter for bringing active players.

### This repo is work in progress

## Requirements:
Compile your [Azerothcore](https://github.com/azerothcore/azerothcore-wotlk) with [Eluna Lua](https://www.azerothcore.org/catalogue-details.html?id=131435473).
The ElunaLua module itself doesn't require much setup/config. Just specify the subfolder where to put your lua_scripts in its .conf file.

If the directory was not changed, add the .lua script to your `../lua_scripts/` directory.
Adjust the top part of the .lua file with the config flags.

## Admin usage:
Adjust the top part of the .lua file with the config flags.
`.bindraf $recruit $recruiter` binds the accounts to each other. It is advised to use this from SOAP during account creation. One recruiter can have multiple recruits. Restricted by `Config.minGMRankForBind`. Once the recruit reaches the target level, the recruiter will receive a reward based on their amount of already finished recruits. Target level, item and amount for certain reward levels are all config flags.

## Player Usage:
- `.raf`        prints your account id and also prints help
- `.raf help`   prints your account id and also prints help
- `.raf list`   shows the account ids of all your recruits
- `.raf summon` allows the recruiter so summon the recruit. The recruit can not summon.


#### Find me on patreon: https://www.patreon.com/Honeys
