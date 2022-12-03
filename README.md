<h1 align="center">Revive Teammates Modular</h1>
<p align="center">
  <a href="https://t.me/revive_teammates">
  <img src="https://img.shields.io/badge/discussions-on%20Telegram%20group-informational?style=flat-square&logo=googlechat" alt="Telegram">
</p>

## Usage

Download the archive and unpack it
- In addons\amxmodx\configs\plugins-rt.ini comment out unnecessary modules
- Configure modules. (Settings are located in addons\amxmodx\configs\rt_configs)
- Compile the plugins ([how to compile?](https://dev-cs.ru/threads/246/))
- Place files from the archive on the server according to the hierarchy of the archive

## Cvars

<details>
<summary>rt_bonus.cfg</summary>

| Cvar | Def Var | Min Var | Max Var | Description |
|------|:-------:|:-------:|:-------:|------------:|
| rt_weapons | weapon_* | - | - | What weapons should be given to the player after resurrection(no more than 6)(otherwise standard from game.cfg) |
| rt_weapons_maps | weapon_* | - | - | What weapons should be given to the player after resurrection on 'awp_' maps(no more than 6)(otherwise standard from game.cfg) |
| rt_revive_health | 0.0 | 0.0 | - | How much more health to add after resurrection |
| rt_planting_health | 0.0 | 0.0 | - | How much more health to add after planting |
| rt_health | 100.0 | 1.0 | - | The number of health of the resurrected player |
| rt_armor_type | 2 | 0 | 2 | 0 - do not issue armor, 1 - bulletproof vest, 2 - bulletproof vest with helmet |
| rt_armor | 100 | 0 | - | Number of armor of the resurrected player |
| rt_frags | 1 | 0 | - | Number of frags for resurrection |
| rt_restore_death | 0 | 0 | 1 | Remove the death point of a dead player after resurrection |

</details>

<details>
<summary>rt_core.cfg</summary>

| Cvar | Def Var | Min Var | Max Var | Description |
|------|:-------:|:-------:|:-------:|------------:|
| rt_revive_time | 3.0 | 1.0 | - | Duration of the player's resurrection(in seconds) |
| rt_revive_antiflood | 3.0 | 1.0 | - | Duration of anti-flood resurrection(in seconds) |
| rt_corpse_time | 30.0 | 0.0 | - | Duration of a corpse's life (in seconds). If you set it to 0, the corpse lives until the end of the round. |
| rt_search_radius | 64.0 | 1.0 | - | Search radius for a corpse |

</details>

<details>
<summary>rt_effects.cfg</summary>

| Cvar | Def Var | Min Var | Max Var | Description |
|------|:-------:|:-------:|:-------:|------------:|
| rt_spectator | 1 | 0 | 1 | Automatically observe the resurrecting player |
| rt_notify_dhud | 1 | 0 | 1 | Notification under Timer(DHUD) |
| rt_revive_glow | #5da130 | - | - | The color of the corpse being resurrected(HEX) |
| rt_planting_glow | #9b2d30 | - | - | The color of the corpse being planted(HEX) |
| rt_corpse_sprite | sprites/rt/corpse_sprite2.spr | - | - | Resurrection sprite over a corpse. To disable the function, leave the cvar empty |
| rt_sprite_scale | 0.15 | 0.1 | 0.5 | Sprite scale |

</details>

<details>
<summary>rt_planting.cfg</summary>

| Cvar | Def Var | Min Var | Max Var | Description |
|------|:-------:|:-------:|:-------:|------------:|
| rt_explosion_damage | 255.0 | 1.0 | - | Explosion damage |
| rt_explosion_radius | 200.0 | 1.0 | - | Explosion radius |
| rt_max_planting | 3 | 1 | - | Maximum number of planting corpses per round |

</details>

<details>
<summary>rt_restrictions.cfg</summary>

| Cvar | Def Var | Min Var | Max Var | Description |
|------|:-------:|:-------:|:-------:|------------:|
| rt_access | - | - | - | Access flags for resurrection/planting |
| rt_max_revives | 3 | 1 | - | Maximum number of resurrections per round |
| rt_max_spawns | 2 | 1 | - | Maximum number of spawns per player per round |
| rt_no_fire | 1 | 0 | 1 | Block shooting during resurrection/planting |
| rt_bomb | 1 | 0 | 1 | You cannot resurrect/plant if there is a bomb |
| rt_duel | 1 | 0 | 1 | You can't resurrect/plant if there are 1x1 left |
| rt_survivor | 0 | 1 | 1 | You cannot resurrect/plant if there is 1 live player left in one of the teams |
| rt_min_round | 1 | 1 | - | From which round is resurrection/planting available |
| rt_no_move | 1 | 0 | 2 | Unable to move during resurrection/planting. 0 - allowed, 1 - not allowed, 2 - allowed, but close to corpse |
| rt_revive_cost | 0 | 0 | - | Cost of resurrection |
| rt_planting_cost | 0 | 0 | - | Cost of planting |
| rt_wins_domination | 5 | 0 | - | Prohibition of resurrection/mining for the dominant team(consecutive wins) |
| rt_remaining_time | 30.0 | 0.0 | - | Prohibition resurrection/planting if there is little time left until the end of the round |

</details>

<details>
<summary>rt_sounds.cfg</summary>

| Cvar | Def Var | Min Var | Max Var | Description |
|------|:-------:|:-------:|:-------:|------------:|
| rt_sound_radius | 250.0 | 1.0 | - | The radius in which to count the nearest players |
| rt_nearby_players | 0 | 0 | 2 | Play the resurrection/landing sound for nearby players. 0 - off, 1 - only ending sounds, 2 - all sounds |

</details>

<details>
<summary>rt_timer.cfg</summary>

| Cvar | Def Var | Min Var | Max Var | Description |
|------|:-------:|:-------:|:-------:|------------:|
| rt_timer_type | 1 | 0 | 1 | 0 - HUD, 1 - bartime(orange line) |

</details>

<details>
<summary>rt_sounds.ini</summary>

```ini
[revive_start]
rt/revive_start.wav
[revive_loop]
rt/revive_loop.wav
[revive_end]
rt/revive_end.wav
[plant_start]
rt/plant_start.wav
[plant_loop]
rt/plant_loop.wav
[plant_end]
rt/plant_end.wav
```

</details>