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
	Cvar__ReviveTime, // Revive time in seconds
	Cvar__RevivedHealth,
	Cvar__DeathModel[MAX_RESOURCE_PATH_LENGTH] // Model
};

enum forwards_struct	{
	Forward_ReviveStart,
	Forward_ReviveLoop_Pre,
	Forward_ReviveLoop_Post,
	Forward_ReviveEnd
};

new g_eCvars[cvars_struct];
new g_eForwards[forwards_struct];

new Array: g_aEntityData;

public EntityHook_Use(const ent, const activator, caller, USE_TYPE: useType, Float: value)	{
	if (is_nullent(ent) || get_member_game(m_bRoundTerminating) || activator != caller || !IsPlayer(activator) \
		|| get_member(activator, m_iTeam) != get_member(get_entvar(ent, var_owner), m_iTeam))
		return;

	if (!ArraySize(g_aEntityData))	{
		set_entvar(ent, var_fuser1, g_eCvars[Cvar__ReviveTime]);
	}

	set_entvar(ent, var_iuser1, ArrayPushCell(g_aEntityData, activator));
}

public EntityHook_Think(const ent)	{
	if (is_nullent(ent))
		return;

	new Float: flNextThink = 1.0;
	new player = get_entvar(ent, var_owner);

	new Float: flTimeUntilRespawn = get_entvar(ent, var_fuser1);

	for (new i, activator; i < ArraySize(g_aEntityData); i++)	{
		activator = ArrayGetCell(g_aEntityData, i);

		if (is_user_alive(player) || get_member(player, m_iTeam) == TEAM_SPECTATOR)	{
			engfunc(EngFunc_RemoveEntity, ent);
			ExecuteForward(g_eForwards[Forward_ReviveEnd], _, player, activator, false /* success = false */);

			return;
		}

		if (!(get_entvar(activator, var_button) & IN_USE))	{
			ArrayDeleteItem(g_aEntityData, i);
			ExecuteForward(g_eForwards[Forward_ReviveEnd], _, player, activator, false /* success = false */);

			return;
		}

		new retVal;
		ExecuteForward(g_eForwards[Forward_ReviveStart], retVal, activator, get_entvar(ent, var_owner));

		if (retVal == PLUGIN_HANDLED)	{
			ExecuteForward(g_eForwards[Forward_ReviveEnd], _, player, activator, false /* success = false */);

			return;
		}

		ExecuteForward(g_eForwards[Forward_ReviveLoop_Pre], retVal, player, activator, flTimeUntilRespawn);

		if (retVal == PLUGIN_HANDLED)	{
			ExecuteForward(g_eForwards[Forward_ReviveEnd], _, player, activator, false /* success = false */);

			return;
		}

		if (flTimeUntilRespawn <= 0.0)	{
			rg_round_respawn(player);
			rg_give_default_items(player);

			ExecuteForward(g_eForwards[Forward_ReviveEnd], _, player, activator, true /* success = true */);
		}

		ExecuteForward(g_eForwards[Forward_ReviveLoop_Post], _, player, activator, flTimeUntilRespawn, flNextThink);
	}

	set_entvar(ent, var_fuser1, --flTimeUntilRespawn);
	set_entvar(ent, var_nextthink, get_gametime() + flNextThink);
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

		arg_delay, //((pev->animtime - gpGlobals->time) * 100). Must : delay/100
		arg_sequence,
		arg_class_id,
		arg_team_id,

		arg_player_id
	};

	#pragma unused arg_delay, arg_team_id

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
	//https://github.com/s1lentq/ReGameDLL_CS/blob/c002edd5b18a8408e299bc6cccfec2c7de56ba3d/regamedll/dlls/player.cpp#L8721 ma'faka
	entityData[entity_coords][coord_x] = float(get_msg_arg_int(arg_coord_x) / 128);
	entityData[entity_coords][coord_y] = float(get_msg_arg_int(arg_coord_y) / 128);
	entityData[entity_coords][coord_z] = float(get_msg_arg_int(arg_coord_z) / 128);

	//get corpse angles
	entityData[entity_angles][coord_x] = get_msg_arg_float(arg_angle_x);
	entityData[entity_angles][coord_y] = get_msg_arg_float(arg_angle_y);
	entityData[entity_angles][coord_z] = get_msg_arg_float(arg_angle_z);

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
		set_entvar(entity, var_body, get_msg_arg_int(arg_class_id));
		//set_entvar(entity, var_skin, get_entvar(player, var_skin));
		set_entvar(entity, var_sequence, get_msg_arg_int(arg_sequence));
		//set_entvar(entity, var_gaitsequence, get_entvar(player, var_gaitsequence));
	}

	if (!g_aEntityData)
		g_aEntityData = ArrayCreate();

	set_entvar(entity, var_nextthink, get_gametime() + 0.01);

	SetUse(entity, "EntityHook_Use");
	SetThink(entity, "EntityHook_Think");

	return PLUGIN_HANDLED;
}

//clear entityes
public CSGameRules_CleanUpMap_Post()	{
	new ent = NULLENT;

	while ((ent = rg_find_ent_by_class(ent, DEATH_CLASSNAME)))	{
		engfunc(EngFunc_RemoveEntity, ent);
	}

	ArrayClear(g_aEntityData);
}

//Hook "+use" on entity
public HamHook_ObjectCaps_Pre(const entity)	{
	if (!FClassnameIs(entity, DEATH_CLASSNAME))
		return HAM_IGNORED;

	SetHamReturnInteger(FCAP_ONOFF_USE);

	return HAM_OVERRIDE; //	Still calls the target function, but returns whatever is set with SetHamReturn*()
} 

public plugin_init()	{
	RegisterHookChain(RG_CSGameRules_CleanUpMap, "CSGameRules_CleanUpMap_Post", 1);

	RegisterHam(Ham_ObjectCaps, "info_target", "HamHook_ObjectCaps_Pre", 0);

	register_message(get_user_msgid("ClCorpse"), "MessageHook_ClCorpse");

	g_eForwards[Forward_ReviveStart] = CreateMultiForward("rt_revive_start", ET_CONTINUE, FP_CELL, FP_CELL);
	g_eForwards[Forward_ReviveLoop_Pre] = CreateMultiForward("rt_revive_loop_pre", ET_CONTINUE, FP_CELL, FP_CELL, FP_CELL);
	g_eForwards[Forward_ReviveLoop_Post] = CreateMultiForward("rt_revive_loop_post", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL, FP_VAL_BYREF);
	g_eForwards[Forward_ReviveEnd] = CreateMultiForward("rt_revive_end", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
}

//need cvars in precache for death model
public plugin_precache()	{
	register_plugin(PluginName, PluginVersion, PluginAuthor);

	new szTemp[64], pCvar;

	pCvar = create_cvar(
		"rt_revive_time",
		"7",
		_, // FCVAR_NONE
		"Revive time in seconds"
	);
	bind_pcvar_num(pCvar, g_eCvars[Cvar__ReviveTime]);

	pCvar = create_cvar(
		"rt_revived_health",
		"50",
		_, // FCVAR_NONE
		"How much health to give to a reborn player?"
	);
	bind_pcvar_num(pCvar, g_eCvars[Cvar__RevivedHealth]);

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
