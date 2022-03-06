#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <reapi>

public stock const PluginName[]     = "Revive teammates: Core";
public stock const PluginVersion[]  = "0.0.1";
public stock const PluginAuthor[]   = "m4ts";
public stock const PluginURL[]      = "https://github.com/ma4ts";

#define AUTO_CREATE_CONFIG								// Auto create config file in `configs/plugins` folder

enum cvars_struct	{
	Cvar__ReviveAccess,									// Access flag to revive teammate's (see amxconst.inc)
	Cvar__ReviveTime,									// Revive time in seconds
	Cvar__ReviveDistance,								// The distance to the dead teammate
	Cvar__AccessTime,									// Access to the teammate's revival after the start of the round in seconds
	Cvar__ReviveCost,									// How much does it cost to revive a teammate? (U can set 0 or blank)
	Cvar__RevivedHealth,								// How much health to give to a reborn player
	Cvar__MaxRoundRevives,								// How many times per round can one team revive
	Cvar__MaxPlayerRevives,								// How many times per round can one player be revived
	Cvar__MaxPlayerCanRevives,							// How many times per round can one player revive
	Cvar__DeathModel[MAX_RESOURCE_PATH_LENGTH]			// Model
};
new g_eCvars[cvars_struct];

public plugin_init()	{
	
}

//need cvars in precache for death model
public plugin_precache()	{
	register_plugin(PluginName, PluginVersion, PluginAuthor);

	new szTemp[64], pCvar;

	pCvar = create_cvar(
		"rt_revive_access_flag",
		"",
		_, // FCVAR_NONE
		"Access flag(s) to revive teammate's (see amxconst.inc)^n@note You can leave an empty value for all players"
	);

	bind_pcvar_string(pCvar, szTemp, charsmax(szTemp));
	g_eCvars[Cvar__ReviveAccess] = szTemp[0] ? read_flags(szTemp) : -1;

	pCvar = create_cvar(
		"rt_revive_time",
		"7",
		_, // FCVAR_NONE
		"Revive time in seconds"
	);
	bind_pcvar_num(pCvar, g_eCvars[Cvar__ReviveTime]);

	pCvar = create_cvar(
		"rt_revive_distance",
		"64",
		_, // FCVAR_NONE,
		"The distance to the dead teammate for can revive^n@note Set 64 please"
	);
	bind_pcvar_num(pCvar, g_eCvars[Cvar__ReviveDistance]);

	pCvar = create_cvar(
		"rt_access_time",
		"15",
		_, // FCVAR_NONE
		"Access to the teammate's revival after the start of the round in seconds"
	);
	bind_pcvar_num(pCvar, g_eCvars[Cvar__AccessTime]);

	pCvar = create_cvar(
		"rt_revive_cost",
		"0",
		_, // FCVAR_NONE
		"How much does it cost to revive a teammate? (U can set 0 or blank)",
		true, 0.0,
		true, get_cvar_float("mp_maxmoney")
	);

	pCvar = create_cvar(
		"rt_revived_health",
		"50",
		_, // FCVAR_NONE
		"How much health to give to a reborn player?"
	);
	bind_pcvar_num(pCvar, g_eCvars[Cvar__RevivedHealth]);

	pCvar = create_cvar(
		"rt_max_round_revives",
		"5",
		_, // FCVAR_NONE
		"How many times per round can one team revive"
	);
	bind_pcvar_num(pCvar, g_eCvars[Cvar__MaxRoundRevives]);

	pCvar = create_cvar(
		"rt_max_player_revives",
		"1",
		_, // FCVAR_NONE
		"How many times per round can one player be revived"
	);
	bind_pcvar_num(pCvar, g_eCvars[Cvar__MaxPlayerRevives]);

	pCvar = create_cvar(
		"rt_max_player_can_revive",
		"3",
		_, // FCVAR_NONE
		"How many times per round can one player revive"
	);
	bind_pcvar_num(pCvar, g_eCvars[Cvar__MaxPlayerCanRevives]);

	pCvar = create_cvar(
		"rt_death_model",
		"models/revive/cross.mdl",
		_, // FCVAR_NONE
		"Model on death player^n@note U can leave an empty value"
	);

	bind_pcvar_string(pCvar, szTemp, charsmax(szTemp));

	#if defined AUTO_CREATE_CONFIG
		AutoExecConfig(true, "revive_teammates");
	#endif

	if (szTemp[0])	{
		if (file_exists(szTemp))	{
			precache_model(szTemp);

			copy(g_eCvars[Cvar__DeathModel], charsmax(g_eCvars[Cvar__DeathModel]), szTemp);
		}
		else
			log_error(AMX_ERR_NATIVE, "Model '%s' is not exists", szTemp);
	}
}


