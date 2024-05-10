#include <amxmodx>
#include <hamsandwich>
#include <reapi>
#include <rt_api>

public stock const PLUGIN[] = "Revive Teammates: Bonus";
public stock const CFG_FILE[] = "addons/amxmodx/configs/rt_configs/rt_bonus.cfg";

#define MAX_SPAWN_WEAPONS 6

enum CVARS {
	WEAPONS[MAX_FMT_LENGTH],
	WEAPONS_MAPS[MAX_FMT_LENGTH],
	Float:REVIVE_HEALTH,
	Float:PLANTING_HEALTH,
	Float:HEALTH,
	ARMOR_TYPE,
	ARMOR,
	FRAGS,
	NO_DEATHPOINT
};

new g_eCvars[CVARS];

new g_iWeapons;
new g_szWeapon[MAX_SPAWN_WEAPONS][32];

public plugin_precache() {
	CreateCvars();

	server_cmd("exec %s", CFG_FILE);
	server_exec();
}

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHORS);
	
	register_dictionary("rt_library.txt");
}

public plugin_cfg() {
	new szMapName[MAX_MAPNAME_LENGTH], szWeapon[32];
	get_mapname(szMapName, charsmax(szMapName));
	
	if(g_eCvars[WEAPONS_MAPS][0] != EOS && containi(szMapName, "awp_") != -1) {
		while(argbreak(g_eCvars[WEAPONS_MAPS], szWeapon, charsmax(szWeapon), g_eCvars[WEAPONS_MAPS], charsmax(g_eCvars[WEAPONS_MAPS])) != -1) {
			if(g_iWeapons == MAX_SPAWN_WEAPONS)
				break;

			copy(g_szWeapon[g_iWeapons++], charsmax(g_szWeapon[]), szWeapon);
		}

		return;
	}

	if(g_eCvars[WEAPONS][0] != EOS) {
		while(argbreak(g_eCvars[WEAPONS], szWeapon, charsmax(szWeapon), g_eCvars[WEAPONS], charsmax(g_eCvars[WEAPONS])) != -1) {
			if(g_iWeapons == MAX_SPAWN_WEAPONS)
				break;

			copy(g_szWeapon[g_iWeapons++], charsmax(g_szWeapon[]), szWeapon);
		}
	}
}

public rt_revive_end(const iEnt, const iPlayer, const iActivator, const Modes:eMode) {
	switch(eMode) {
		case MODE_REVIVE: {
			new Modes:iMode = Modes:get_entvar(iEnt, var_iuser3);

			if(iMode != MODE_PLANT) {
				if(g_eCvars[REVIVE_HEALTH])
					rg_add_health_to_player(iActivator, g_eCvars[REVIVE_HEALTH]);

				if(g_eCvars[HEALTH])
					set_entvar(iPlayer, var_health, floatclamp(g_eCvars[HEALTH], 1.0, Float:get_entvar(iPlayer, var_max_health)));

				if(g_eCvars[ARMOR])
					rg_set_user_armor(iPlayer, g_eCvars[ARMOR], ArmorType:g_eCvars[ARMOR_TYPE]);

				if(g_iWeapons > 0) {
					rg_remove_all_items(iPlayer);

					for(new i; i <= g_iWeapons; i++) {
						new iWeapon = rg_give_item(iPlayer, g_szWeapon[i]);

						if(!is_nullent(iWeapon)) {
							new WeaponIdType:iWeaponType = WeaponIdType:get_member(iWeapon, m_iId);

							if(iWeaponType != WEAPON_KNIFE && iWeaponType != WEAPON_SHIELDGUN)
								rg_set_user_bpammo(iPlayer, iWeaponType, rg_get_iteminfo(iWeapon, ItemInfo_iMaxAmmo1));
						}
					}
				}

				if(g_eCvars[FRAGS])
					ExecuteHamB(Ham_AddPoints, iActivator, g_eCvars[FRAGS], false);
				
				if(g_eCvars[NO_DEATHPOINT])
					set_member(iPlayer, m_iDeaths, max(get_member(iPlayer, m_iDeaths) - 1, 0));
			}
		}
		case MODE_PLANT: {
			if(g_eCvars[PLANTING_HEALTH])
				rg_add_health_to_player(iActivator, g_eCvars[PLANTING_HEALTH]);
		}
	}
}

stock rg_add_health_to_player(const iPlayer, const Float:flHealth) {
	set_entvar(iPlayer, var_health, floatclamp(Float:get_entvar(iPlayer, var_health) + flHealth, 1.0, Float:get_entvar(iPlayer, var_max_health)));
}

public CreateCvars() {
	bind_pcvar_string(create_cvar(
		"rt_weapons",
		"weapon_knife weapon_deagle",
		FCVAR_NONE,
		"What weapons should be given to the player after resurrection(no more than 6)(otherwise standard from game.cfg)"),
		g_eCvars[WEAPONS],
		charsmax(g_eCvars[WEAPONS])
	);
	bind_pcvar_string(create_cvar(
		"rt_weapons_maps",
		"weapon_knife weapon_awp",
		FCVAR_NONE,
		"What weapons should be given to the player after resurrection on 'awp_' maps(no more than 6)(otherwise standard from game.cfg)"),
		g_eCvars[WEAPONS_MAPS],
		charsmax(g_eCvars[WEAPONS_MAPS])
	);
	bind_pcvar_float(create_cvar(
		"rt_revive_health",
		"0.0",
		FCVAR_NONE,
		"How much more health to add after resurrection",
		true,
		0.0),
		g_eCvars[REVIVE_HEALTH]
	);
	bind_pcvar_float(create_cvar(
		"rt_planting_health",
		"0.0",
		FCVAR_NONE,
		"How much more health to add after planting",
		true,
		0.0),
		g_eCvars[PLANTING_HEALTH]
	);
	bind_pcvar_float(create_cvar(
		"rt_health",
		"100.0",
		FCVAR_NONE,
		"The number of health of the resurrected player",
		true,
		1.0),
		g_eCvars[HEALTH]
	);
	bind_pcvar_num(create_cvar(
		"rt_armor_type",
		"2",
		FCVAR_NONE,
		"0 - do not issue armor, 1 - bulletproof vest, 2 - bulletproof vest with helmet",
		true,
		0.0,
        true,
        2.0),
		g_eCvars[ARMOR_TYPE]
	);
	bind_pcvar_num(create_cvar(
		"rt_armor",
		"100",
		FCVAR_NONE,
		"Number of armor of the resurrected player",
		true,
		0.0),
		g_eCvars[ARMOR]
	);
	bind_pcvar_num(create_cvar(
		"rt_frags",
		"1",
		FCVAR_NONE,
		"Number of frags for resurrection",
		true,
		0.0),
		g_eCvars[FRAGS]
	);
	bind_pcvar_num(create_cvar(
		"rt_restore_death",
		"0",
		FCVAR_NONE,
		"Remove the death point of a dead player after resurrection",
		true,
		0.0,
		true,
		1.0),
		g_eCvars[NO_DEATHPOINT]
	);
}