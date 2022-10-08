<h1 align="center">Revive Teammates Modular</h1>

## Usage

Download the archive and unpack it
- In addons\amxmodx\configs\plugins-rt.ini comment out unnecessary modules
- Configure modules. (Settings are located in addons\amxmodx\configs\rt_configs)
- Compile the plugins ([how to compile?](https://dev-cs.ru/threads/246/))
- Place files from the archive on the server according to the hierarchy of the archive

## Cvars

<details>
<summary>rt_bonus.cfg</summary>

| Cvar | Variables | Description |
|------|:---------:|------------:|
| rt_weapons | weapon_* | What weapons should be given to the player after resurrection(no more than 6)(otherwise standard from game.cfg) |
| rt_health | min 1.0 | The number of health of the resurrected player |
| rt_armor_type | 1/2 or 0 | 0 - do not issue armor, 1 - bulletproof vest, 2 - bulletproof vest with helmet |
| rt_armor | min 1 | Number of armor of the resurrected player |
| rt_frags | min 1 | Number of frags for resurrection |

</details>

<details>
<summary>rt_core.cfg</summary>

| Cvar | Variables | Description |
|------|:---------:|------------:|
| rt_revive_time | min 1.0 | Duration of the player's resurrection(in seconds) |
| rt_revive_antiflood | min 1.0 | Duration of anti-flood resurrection(in seconds) |

</details>
