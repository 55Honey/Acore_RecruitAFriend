## lua-recruit-a-friend
Lua script for Azerothcore with ElunaLua to connect accounts from different players and reward the recruiter for bringing active players.

## lua-scroll-of-resurrection
Lua script for Azerothcore with ElunaLua to connect accounts from different players and reward the recruiter for bringing back former, inactive players.

**Proudly hosted on [ChromieCraft](https://www.chromiecraft.com/)**
#### Find me on patreon: https://www.patreon.com/Honeys

## Requirements:
Compile your [Azerothcore](https://github.com/azerothcore/azerothcore-wotlk) with [Eluna Lua](https://www.azerothcore.org/catalogue-details.html?id=131435473).
The ElunaLua module itself doesn't require much setup/config. Just specify the subfolder where to put your lua_scripts in its .conf file.

If the directory was not changed, add the .lua script to your `../lua_scripts/` directory.
Adjust the top part of the .lua file with the config flags.

## Optional acore_cms support
The [acore_cms](https://github.com/azerothcore/acore-cms)-RAF-module supports this Lua. It allows to add and monitor RAF links and rewards from the website.

## Admin usage:
Adjust the top part of the .lua file with the config flags. The most important decisions are:
- max duration of the RAF/SOR-link(default 30 days)
- target level for a succesful link and a reward to the recruiter/resurrected
- check for same IP yes/no, auto end RAF/SOR if same IP yes/no (default check:yes, end: no)
- text for the RAF/SOR-reward mail(s) (see Lua for defaults)
- rewards as item id and amount (see Lua for defaults)
- maps to allow summoning to (default Eastern Kingdoms, Kalimdor and Outland/Bloodelf+Draenei starting zones.)

`.bindraf $recruit $recruiter` binds the accounts to each other for a RAF link. It is advised to use this from SOAP during account creation. One recruiter can have multiple recruits. Restricted by `Config.minGMRankForBind`. Once the recruit reaches the target level, the recruiter will receive a reward based on their amount of already finished recruits. Target level, item and amount for certain reward levels are all config flags.
`.bindsor $resurrected $recruiter` binds the accounts to each other for a SOR link.

The RAF/SOR creates a custom db scheme specified in the config flags. Inside the scheme is a table to store all current and past RAF/SOR links.
- `time_stamp` is the moment of creation in UNIX-time
- `ip_abuse_counter` is increased everytime recruiter and recruit have the same IPs during login or summon 
- `kick_counter` is increased everytime a player gets kicked because they reached the allowed number of actions specified in `Config.abuseTreshold`.
- `reward_level` stores how many recruiters of that account have succesfully reached the RAF link up to `Config.targetLevel`.
- `comment` is for maintaining queries and not used by the scripts at all
- all other columns in `recruit_a_friend_links` and `recruit_a_friend_rewards` as well as their SOR counterparts are account id's

Optionally:

`.forcebindraf $recruit $recruiter` same as .bindraf but ignores past binds. Previously unbound, succesful or timed out doesn't matter.
`.forcebindsor $recruit $recruiter` same as .bindsor but ignores past binds. Previously unbound, succesful or timed out doesn't matter.

## Player Usage:
- `.raf`        prints your account id and also prints help
- `.raf help`   prints your account id and also prints help
- `.raf list`   shows the account ids of all your recruits
- `.raf summon` allows the recruiter so summon the recruit. The recruit can not summon.

- `.sor`        prints your account id and also prints help
- `.sor help`   prints your account id and also prints help
- `.sor list`   shows the account ids of all accounts you've resurrected
- `.sor summon` allows the recruiter so summon the resurrected. The resurrected can not summon.

Players have 30 days (config flag) to reach the target level (default 55 for RAF, 60 for SOR).
For RAF, if the recruit succeeds, their recruiter gets a reward. There is a counter in place and rewards change with a higher amount of succesful recruits. Default rewards are pets, a bag and potions/elixirs.
For SOR, if the resurrected succeeds, both parties get a reward. Rewards for the resurrected player default to flasks and an 18-slot bag. Recruiter rewards align with the RAF system's defaults.


## Config:
See the lua file for a description of the config flags.


## Default settings/rewards:
- There should be an option in the account creation page to determine a recruiter account. Recruiters can type `.raf`/`.sof` to find out about their account id.
- Once connected, recruiters can summon their recruits/resurrecteds without a limit. Abuse might lead to kicks which are logged.
- Using the same IP for recruiter and recruit/resurrected is restricted by default and also prevents teleporting and is logged.
- For RAF only: Once a recruit reaches the target level of 55, their recruiter gains a reward. The default rewards are a Mini-Thor pet for the first recruit, a 14-slot bag for the second recruit, the Diablos-Stone pet for the fifth recruit and a Tyrael's Hilt pet for the 10th recruit to reach the target level of 55. For the 4th recruit, the 6th - 9th recruit and any recruit past 10, the recruiter will receive a set of 4 stacks of potions/elixirs.
- For SOR only: Once a recruit reaches the target level of 60, their recruiter gains a reward. The default rewards are a set of 4 stacks of potions/elixirs. The resurrected will gain a set of flasks and an 18-slot bag.
- If the recruit/resurrected fails to reach level 55/60 within 30 days, the RAF/SOR-links are removed at the next login.
- If the recruit/resurrected and the recruiter share an IP, they receive a warning that "possible abuse was logged" at login. If they share an IP while trying to summon, the summoning is blocked and they also see the "possible abuse was logged" message.
