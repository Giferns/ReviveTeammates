#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>

public stock const PluginName[]     = "Revive teammates: Core";
public stock const PluginVersion[]  = "0.0.1";
public stock const PluginAuthor[]   = "m4ts";
public stock const PluginURL[]      = "https://github.com/ma4ts";

#define AUTO_CREATE_CONFIG // Auto create config file in `configs/plugins` folder
#define IsPlayer(%0) (0 < %0 <= MaxClients)

new const DEATH_CLASSNAME[]			= "death__model";

enum cvars_struct	{
	Cvar__ReviveAccess, // Access flag to revive teammate's (see amxconst.inc)
	Cvar__ReviveTime, // Revive time in seconds
	Cvar__AccessTime, // Access to the teammate's revival after the start of the round in seconds
	Cvar__ReviveCost, // How much does it cost to revive a teammate? (U can set 0 or blank)
	Cvar__RevivedHealth, // How much health to give to a reborn player
	Cvar__MaxRoundRevives, // How many times per round can one team revive
	Cvar__MaxPlayerRevives,	// How many times per round can one player be revived
	Cvar__MaxPlayerCanRevives, // How many times per round can one player revive
	Cvar__DeathModel[MAX_RESOURCE_PATH_LENGTH] // Model
};

new g_eCvars[cvars_struct];
new g_iRevives[TeamName]; // How many times per round can one team revive

new g_iPlayerRevives[MAX_PLAYERS + 1]; // How many times per round can one player revive

//Resetting all counters every round and when player has been disconnected
public CSGameRules_RestartRound_Post()	{
	for (new id = 1; id <= MaxClients; id++)	{
		if (!is_user_connected(id))
			continue;

		g_iPlayerRevives[id] = 0;
	}

	g_iRevives[TEAM_CT] = 0;
	g_iRevives[TEAM_TERRORIST] = 0;
}
public client_disconnected(id)	{
	g_iPlayerRevives[id] = 0;
}

//Hook "+use" on entity
public HamHook_ObjectCaps_Pre(const entity)	{
	if (!FClassnameIs(entity, DEATH_CLASSNAME))
		return HAM_IGNORED;

	SetHamReturnInteger(FCAP_ONOFF_USE);

	return HAM_OVERRIDE; //	Still calls the target function, but returns whatever is set with SetHamReturn*()
}

//https://wiki.alliedmods.net/Half-Life_1_Game_Events#ClCorpse
public MessageHook_ClCorpse()	{
	new entity = rg_create_entity("info_target");

	if (is_nullent(entity))
		return PLUGIN_CONTINUE;

	enum	{
		arg_model = 1,

		arg_coord_x,
		arg_coord_y,
		arg_coord_z,

		arg_angle_x,
		arg_angle_y,
		arg_angle_z,
/*
		arg_delay,
		arg_sequence,
		arg_class_id,
		arg_team_id,
*/
		arg_player_id = 12
	};

	enum coords_struct	{
		Float: coord_x,
		Float: coord_y,
		Float: coord_z
	};

	enum entity_struct	{
		entity_coords[coords_struct],
		entity_angles[coords_struct]
	};

	new entityData[entity_struct];

	//get corpse coords
	entityData[entity_coords][coord_x] = float(get_msg_arg_int(arg_coord_x));
	entityData[entity_coords][coord_y] = float(get_msg_arg_int(arg_coord_y));
	entityData[entity_coords][coord_z] = float(get_msg_arg_int(arg_coord_z));

	//get corpse angles
	entityData[entity_angles][coord_x] = float(get_msg_arg_int(arg_angle_x));
	entityData[entity_angles][coord_y] = float(get_msg_arg_int(arg_angle_y));
	entityData[entity_angles][coord_z] = float(get_msg_arg_int(arg_angle_z));

	new szTemp[MAX_RESOURCE_PATH_LENGTH], bool: bCustomModel;

	bCustomModel = bool: (g_eCvars[Cvar__DeathModel] || g_eCvars[Cvar__DeathModel][0] != '0');

	if (bCustomModel)
		copy(szTemp, charsmax(szTemp), g_eCvars[Cvar__DeathModel]);
	else	{
		get_msg_arg_string(arg_model, szTemp, charsmax(szTemp));
		formatex(szTemp, charsmax(szTemp), "models/player/%s/%s.mdl", szTemp, szTemp);
	}

	new player = get_msg_arg_int(arg_player_id);

	engfunc(EngFunc_SetModel, entity, szTemp);
	engfunc(EngFunc_SetOrigin, entity, entityData[entity_coords]);

	set_entvar(entity, var_classname, DEATH_CLASSNAME);
	set_entvar(entity, var_angles, entityData[entity_angles]);
	set_entvar(entity, var_framerate, 1.0);
	set_entvar(entity, var_owner, player);

	if (!bCustomModel)	{
		set_entvar(entity, var_body, get_entvar(player, var_body));
		set_entvar(entity, var_skin, get_entvar(player, var_skin));
		set_entvar(entity, var_sequence, get_entvar(player, var_sequence));
		set_entvar(entity, var_gaitsequence, get_entvar(player, var_gaitsequence));
	}

	SetUse(entity, "EntityHook_Use");

	return PLUGIN_HANDLED;
}

public EntityHook_Use(const ent, const activator, const caller, USE_TYPE: useType, Float: value)	{
	if (is_nullent(ent) || get_member_game(m_bRoundTerminating) || activator != caller || !IsPlayer(activator) \
		|| get_member(activator, m_iTeam) != get_member(get_entvar(ent, var_owner), m_iTeam))
		return;

	if (g_eCvars[Cvar__ReviveAccess] != -1 && ~get_user_flags(activator) & g_eCvars[Cvar__ReviveAccess])
		return;

	if (g_eCvars[Cvar__AccessTime] && (get_gametime() - get_member_game(m_fRoundStartTime) < g_eCvars[Cvar__AccessTime]))
		return;


}

public plugin_init()	{
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Post", 1);
	RegisterHookChain(RG_CSGameRules_CleanUpMap, "CSGameRules_CleanUpMap_Post", 1);

	RegisterHam(Ham_ObjectCaps, "info_target", "HamHook_ObjectCaps_Pre", 0);

	register_message(get_user_msgid("ClCorpse"), "MessageHook_ClCorpse");
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
	g_eCvars[Cvar__ReviveAccess] = (szTemp[0] || szTemp[0] != '0') ? read_flags(szTemp) : -1;

	pCvar = create_cvar(
		"rt_revive_time",
		"7",
		_, // FCVAR_NONE
		"Revive time in seconds"
	);
	bind_pcvar_num(pCvar, g_eCvars[Cvar__ReviveTime]);

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
