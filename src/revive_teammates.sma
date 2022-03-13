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

const Float: MIN_USE_DELAY			= 1.0;

enum cvars_struct	{
	Float: Cvar__ReviveTime, // Revive time in seconds
	Float: Cvar__RevivedHealth,
	Cvar__DeathModel[MAX_RESOURCE_PATH_LENGTH] // Model
};

enum forwards_struct	{
	Forward_OnReviveStart,
	Forward_ReviveStart,
	Forward_ReviveLoop_Pre,
	Forward_ReviveLoop_Post,
	Forward_ReviveEnd
};

new g_eCvars[cvars_struct];
new g_eForwards[forwards_struct];

new Float: g_flLastUse[MAX_PLAYERS + 1];

public EntityHook_Use(const ent, const activator, caller, USE_TYPE: useType, Float: value)	{
	if (is_nullent(ent) || get_member_game(m_bRoundTerminating) || activator != caller || !IsPlayer(activator) \
		|| get_member(activator, m_iTeam) != get_member(get_entvar(ent, var_owner), m_iTeam))
		return;

	new Float: gametime = get_gametime();

	if (gametime < g_flLastUse[activator] - MIN_USE_DELAY)	{
		return;
	}
	g_flLastUse[activator] = gametime;

	new Array: aActivators = get_entvar(ent, var_iuser1);

	if (!aActivators)
		aActivators = ArrayCreate();

	if (!ArraySize(aActivators))	{
		set_entvar(ent, var_fuser1, g_eCvars[Cvar__ReviveTime]);
		
		ExecuteForward(g_eForwards[Forward_OnReviveStart], _, get_entvar(ent, var_owner), activator);
	}

	ArrayPushCell(aActivators, activator);
	set_entvar(ent, var_iuser1, aActivators);
}

public EntityHook_Think(const ent)	{
	if (is_nullent(ent))
		return;

	new Array: aActivators = get_entvar(ent, var_iuser1);
	new Float: flNextThink = 1.0;

	if (!aActivators)	{
		set_entvar(ent, var_nextthink, get_gametime() + flNextThink);
		return;
	}

	new player = get_entvar(ent, var_owner);

	new Float: flTimeUntilRespawn = get_entvar(ent, var_fuser1);

	for (new i, activator; i < ArraySize(aActivators); i++)	{
		activator = ArrayGetCell(aActivators, i);

		if (is_user_alive(player) || get_member(player, m_iTeam) == TEAM_SPECTATOR)	{
			engfunc(EngFunc_RemoveEntity, ent);
			ExecuteForward(g_eForwards[Forward_ReviveEnd], _, player, activator, false /* success = false */);

			return;
		}

		if (!(get_entvar(activator, var_button) & IN_USE))	{
			ArrayDeleteItem(aActivators, i);
			ExecuteForward(g_eForwards[Forward_ReviveEnd], _, player, activator, false /* success = false */);

			set_entvar(ent, var_nextthink, get_gametime() + flNextThink);

			return;
		}

		new retVal;
		ExecuteForward(g_eForwards[Forward_ReviveStart], retVal, player, activator);

		if (retVal == PLUGIN_HANDLED)	{
			ExecuteForward(g_eForwards[Forward_ReviveEnd], _, player, activator, false /* success = false */);

			set_entvar(ent, var_nextthink, get_gametime() + flNextThink);

			return;
		}

		ExecuteForward(g_eForwards[Forward_ReviveLoop_Pre], retVal, player, activator, flTimeUntilRespawn);

		if (retVal == PLUGIN_HANDLED)	{
			ExecuteForward(g_eForwards[Forward_ReviveEnd], _, player, activator, false /* success = false */);

			set_entvar(ent, var_nextthink, get_gametime() + flNextThink);

			return;
		}

		if (flTimeUntilRespawn <= 0.0)	{
			rg_round_respawn(player);
			rg_give_default_items(player);

			set_entvar(player, var_health, g_eCvars[Cvar__RevivedHealth]);

			new Float: flOrigin[3];
			get_entvar(ent, var_origin, flOrigin);

			flOrigin[2] += 30.0;

			engfunc(EngFunc_SetOrigin, player, flOrigin);

			ArrayDestroy(aActivators);
			engfunc(EngFunc_RemoveEntity, ent);

			ExecuteForward(g_eForwards[Forward_ReviveEnd], _, player, activator, true /* success = true */);

			return;
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

	new szTemp[MAX_RESOURCE_PATH_LENGTH], szModel[MAX_RESOURCE_PATH_LENGTH], bool: bCustomModel;

	bCustomModel = bool: (g_eCvars[Cvar__DeathModel][0] != EOS);

	if (bCustomModel)
		copy(szModel, charsmax(szModel), g_eCvars[Cvar__DeathModel]);
	else	{
		get_msg_arg_string(arg_model, szTemp, charsmax(szTemp));
		formatex(szModel, charsmax(szModel), "models/player/%s/%s.mdl", szTemp, szTemp);
	}

	new player = get_msg_arg_int(arg_player_id);

	engfunc(EngFunc_SetModel, entity, szModel);
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

	set_entvar(entity, var_nextthink, get_gametime() + 0.01);

	SetUse(entity, "EntityHook_Use");
	SetThink(entity, "EntityHook_Think");

	return PLUGIN_HANDLED;
}

//clear entityes
public CSGameRules_CleanUpMap_Post()	{
	new ent = NULLENT;

	while ((ent = rg_find_ent_by_class(ent, DEATH_CLASSNAME)))	{		
		new Array: aActivators = get_entvar(ent, var_iuser1);
		if (aActivators)
			ArrayDestroy(aActivators);

		engfunc(EngFunc_RemoveEntity, ent);
	}
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

	g_eForwards[Forward_OnReviveStart] = CreateMultiForward("rt_on_revive_start", ET_IGNORE, FP_CELL, FP_CELL);
	g_eForwards[Forward_ReviveStart] = CreateMultiForward("rt_revive_start", ET_CONTINUE, FP_CELL, FP_CELL);
	g_eForwards[Forward_ReviveLoop_Pre] = CreateMultiForward("rt_revive_loop_pre", ET_CONTINUE, FP_CELL, FP_CELL, FP_CELL);
	g_eForwards[Forward_ReviveLoop_Post] = CreateMultiForward("rt_revive_loop_post", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL, FP_VAL_BYREF);
	g_eForwards[Forward_ReviveEnd] = CreateMultiForward("rt_revive_end", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
}

//need cvars in precache for death model
public plugin_precache()	{
	register_plugin(PluginName, PluginVersion, PluginAuthor);

	new pCvar;

	pCvar = create_cvar(
		"rt_revive_time",
		"7.0",
		_, // FCVAR_NONE
		"Revive time in seconds"
	);
	bind_pcvar_float(pCvar, g_eCvars[Cvar__ReviveTime]);

	pCvar = create_cvar(
		"rt_revived_health",
		"50.0",
		_, // FCVAR_NONE
		"How much health to give to a reborn player?"
	);
	bind_pcvar_float(pCvar, g_eCvars[Cvar__RevivedHealth]);

	pCvar = create_cvar(
		"rt_death_model",
		"models/revive/cross.mdl",
		_, // FCVAR_NONE
		"Model on death player^n@note U can leave an empty value"
	);

	bind_pcvar_string(pCvar, g_eCvars[Cvar__DeathModel], charsmax(g_eCvars[Cvar__DeathModel]));

	#if defined AUTO_CREATE_CONFIG
		AutoExecConfig(true, "revive_teammates");
	#endif

	if (g_eCvars[Cvar__DeathModel][0])	{
		if (file_exists(g_eCvars[Cvar__DeathModel]))	{
			precache_model(g_eCvars[Cvar__DeathModel]);
		}
		else
			log_error(AMX_ERR_NATIVE, "Model '%s' is not exists", g_eCvars[Cvar__DeathModel]);
	}
}
