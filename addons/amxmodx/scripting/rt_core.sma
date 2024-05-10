#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <rt_api>

public stock const PLUGIN[] = "Revive Teammates: Core";
public stock const CFG_FILE[] = "addons/amxmodx/configs/rt_configs/rt_core.cfg";

enum CVARS {
	Float:REVIVE_TIME,
	Float:ANTIFLOOD_TIME,
	Float:CORPSE_TIME,
	Float:SEARCH_RADIUS,
	FORCE_FWD_MODE
};

new g_eCvars[CVARS];

enum Forwards {
	ReviveStart,
	ReviveLoop_Pre,
	ReviveLoop_Post,
	ReviveEnd,
	ReviveCancelled,
	CreatingCorpseStart,
	CreatingCorpseEnd
};

new g_eForwards[Forwards];

new g_iPluginLoaded;

new Float:g_flLastUse[MAX_PLAYERS + 1], g_iTimeUntil[MAX_PLAYERS + 1];

new Float:g_fSpawnOrigin[3];
new HookChain:g_iGetPlayerSpawnSpot_HookChain;

public plugin_precache() {
	CreateCvars();

	server_cmd("exec %s", CFG_FILE);
	server_exec();
}

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHORS);

	register_dictionary("rt_library.txt");

	register_message(get_user_msgid("ClCorpse"), "MessageHook_ClCorpse");

	RegisterHookChain(RG_CSGameRules_CleanUpMap, "CSGameRules_CleanUpMap_Post", true);
	RegisterHookChain(RG_CBasePlayer_UseEmpty, "CBasePlayer_UseEmpty_Pre", false);
	g_iGetPlayerSpawnSpot_HookChain = RegisterHookChain(RG_CSGameRules_GetPlayerSpawnSpot, "CSGameRules_GetPlayerSpawnSpot_Pre", false);
	DisableHookChain(g_iGetPlayerSpawnSpot_HookChain);
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Pre", .post = 0);

	g_eForwards[ReviveStart] = CreateMultiForward("rt_revive_start", ET_STOP, FP_CELL, FP_CELL, FP_CELL, FP_CELL);
	g_eForwards[ReviveLoop_Pre] = CreateMultiForward("rt_revive_loop_pre", ET_STOP, FP_CELL, FP_CELL, FP_CELL, FP_FLOAT, FP_CELL);
	g_eForwards[ReviveLoop_Post] = CreateMultiForward("rt_revive_loop_post", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL, FP_FLOAT, FP_CELL);
	g_eForwards[ReviveEnd] = CreateMultiForward("rt_revive_end", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL, FP_CELL);
	g_eForwards[ReviveCancelled] = CreateMultiForward("rt_revive_cancelled", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL, FP_CELL);
	g_eForwards[CreatingCorpseStart] = CreateMultiForward("rt_creating_corpse_start", ET_STOP, FP_CELL, FP_CELL);
	g_eForwards[CreatingCorpseEnd] = CreateMultiForward("rt_creating_corpse_end", ET_IGNORE, FP_CELL, FP_CELL, FP_ARRAY);

	g_iPluginLoaded = is_plugin_loaded("rt_planting.amxx", true);
}

public CBasePlayer_Spawn_Pre(id) {
	PlayerSpawnOrDisconnect(id);
}

public client_disconnected(id) {
	g_flLastUse[id] = 0.0;

	PlayerSpawnOrDisconnect(id);
}

PlayerSpawnOrDisconnect(id) {
	new iActivator = UTIL_RemoveCorpses(id, DEAD_BODY_CLASSNAME);

	if(is_user_connected(iActivator)) {
		UTIL_NotifyClient(iActivator, print_team_red, "%l%l", "RT_CHAT_TAG", "RT_DISCONNECTED");
		UTIL_ResetEntityThink(g_eForwards[ReviveCancelled], RT_NULLENT, id, iActivator, MODE_NONE);
	}
}

public CSGameRules_CleanUpMap_Post() {
	UTIL_RemoveCorpses(0, DEAD_BODY_CLASSNAME);
}

public CBasePlayer_UseEmpty_Pre(const iActivator) {
	if(~get_entvar(iActivator, var_flags) & FL_ONGROUND)
		return;

	new iEnt = RT_NULLENT;

	new Float:vPlOrigin[3], Float:vEntOrigin[3];
	get_entvar(iActivator, var_origin, vPlOrigin);

	while((iEnt = rg_find_ent_by_class(iEnt, DEAD_BODY_CLASSNAME)) > 0) {
		if(!is_nullent(iEnt)) {
			get_entvar(iEnt, var_vuser4, vEntOrigin);

			if(ExecuteHam(Ham_FVecInViewCone, iActivator, vEntOrigin) && vector_distance(vPlOrigin, vEntOrigin) < g_eCvars[SEARCH_RADIUS]) {
				Corpse_Use(iEnt, iActivator);
				return;
			}
		}
	}
}

public CSGameRules_GetPlayerSpawnSpot_Pre(const iPlayer) {
	DisableHookChain(g_iGetPlayerSpawnSpot_HookChain);

	set_entvar(iPlayer, var_flags, get_entvar(iPlayer, var_flags) | FL_DUCKING);

	set_entvar(iPlayer, var_velocity, NULL_VECTOR);
	set_entvar(iPlayer, var_v_angle, NULL_VECTOR);

	new Float:fAngles[3];
	get_entvar(iPlayer, var_angles, fAngles);
	fAngles[0] = fAngles[2] = 0.0;
	set_entvar(iPlayer, var_angles, fAngles);

	set_entvar(iPlayer, var_punchangle, NULL_VECTOR);
	set_entvar(iPlayer, var_fixangle, 1);

	engfunc(EngFunc_SetSize, iPlayer, Float:{-16.000000, -16.000000, -18.000000}, Float:{16.000000, 16.000000, 32.000000});
	engfunc(EngFunc_SetOrigin, iPlayer, g_fSpawnOrigin);

	SetHookChainReturn(ATYPE_INTEGER, RT_NULLENT);
	return HC_SUPERCEDE;
}

public Corpse_Use(const iEnt, const iActivator) {
	if(is_nullent(iEnt) || get_member_game(m_bRoundTerminating) || !ExecuteHam(Ham_IsPlayer, iActivator))
		return;

	new iPlayer = get_entvar(iEnt, var_owner);
	new TeamName:iActTeam = TeamName:get_member(iActivator, m_iTeam);
	new TeamName:iPlTeam = TeamName:get_member(iPlayer, m_iTeam);
	new TeamName:iEntTeam = TeamName:get_entvar(iEnt, var_team);
	new Modes:eCurrentMode = (iActTeam == iPlTeam) ? MODE_REVIVE : MODE_PLANT;

	if(g_iPluginLoaded == INVALID_PLUGIN_ID && eCurrentMode == MODE_PLANT)
		return;

	if(iActTeam == TEAM_SPECTATOR || iPlTeam == TEAM_SPECTATOR)
		return;

	if(iEntTeam != iPlTeam) {
		UTIL_NotifyClient(iActivator, print_team_red, "%l%l", "RT_CHAT_TAG", "RT_CHANGE_TEAM");
		return;
	}

	if(get_entvar(iEnt, var_iuser1)) {
		UTIL_NotifyClient(iActivator, print_team_red, "%l%l", "RT_CHAT_TAG", "RT_ACTIVATOR_EXISTS");
		return;
	}

	if(!is_user_alive(iActivator)) {
		UTIL_ResetEntityThink(g_eForwards[ReviveCancelled], iEnt, iPlayer, iActivator, eCurrentMode);
		return;
	}

	new fwRet;
	ExecuteForward(g_eForwards[ReviveStart], fwRet, iEnt, iPlayer, iActivator, eCurrentMode);

	if(fwRet == PLUGIN_HANDLED) {
		UTIL_ResetEntityThink(g_eForwards[ReviveCancelled], iEnt, iPlayer, iActivator, eCurrentMode);
		return;
	}

	new Float:flGameTime = get_gametime();

	if(g_flLastUse[iActivator] > flGameTime) {
		UTIL_NotifyClient(iActivator, print_team_red, "%l%l", "RT_CHAT_TAG", "RT_ANTI_FLOOD");
		UTIL_ResetEntityThink(g_eForwards[ReviveCancelled], iEnt, iPlayer, iActivator, eCurrentMode);
		return;
	}

	g_flLastUse[iActivator] = flGameTime + g_eCvars[ANTIFLOOD_TIME];

	UTIL_NotifyClient(iActivator, print_team_blue, "%l%l", "RT_CHAT_TAG", eCurrentMode == MODE_REVIVE ? "RT_TIMER_REVIVE" : "RT_TIMER_PLANT", iPlayer);

	g_iTimeUntil[iActivator] = 0;

	set_entvar(iEnt, var_iuser1, iActivator);
	set_entvar(iEnt, var_iuser2, eCurrentMode);
	set_entvar(iEnt, var_fuser1, flGameTime + g_eCvars[REVIVE_TIME]);
	set_entvar(iEnt, var_fuser3, g_eCvars[REVIVE_TIME]);
	set_entvar(iEnt, var_nextthink, flGameTime + 0.1);
}

public Corpse_Think(const iEnt) {
	if(is_nullent(iEnt))
		return;

	new iPlayer = get_entvar(iEnt, var_owner);
	new iActivator = get_entvar(iEnt, var_iuser1);
	new Float:flGameTime = get_gametime();

	if(!iActivator) {
		if(g_eCvars[CORPSE_TIME] && Float:get_entvar(iEnt, var_fuser4) < flGameTime) {
			UTIL_RemoveCorpses(iPlayer, DEAD_BODY_CLASSNAME);
			return;
		}

		set_entvar(iEnt, var_nextthink, flGameTime + 1.0);
		return;
	}

	new TeamName:iPlTeam = TeamName:get_member(iPlayer, m_iTeam);
	new TeamName:iEntTeam = TeamName:get_entvar(iEnt, var_team);
	new Modes:eCurrentMode = Modes:get_entvar(iEnt, var_iuser2);

	if(iEntTeam != iPlTeam) {
		UTIL_NotifyClient(iActivator, print_team_red, "%l%l", "RT_CHAT_TAG", "RT_CHANGE_TEAM");
		UTIL_ResetEntityThink(g_eForwards[ReviveCancelled], iEnt, iPlayer, iActivator, eCurrentMode);
		return;
	}

	if(~get_entvar(iActivator, var_button) & IN_USE) {
		UTIL_NotifyClient(iActivator, print_team_red, "%l%l", "RT_CHAT_TAG", eCurrentMode == MODE_REVIVE ? "RT_CANCELLED_REVIVE" : "RT_CANCELLED_PLANT");
		UTIL_ResetEntityThink(g_eForwards[ReviveCancelled], iEnt, iPlayer, iActivator, eCurrentMode);
		return;
	}

	new Float:flTimeUntil[2];
	flTimeUntil[0] = Float:get_entvar(iEnt, var_fuser1);
	flTimeUntil[1] = Float:get_entvar(iEnt, var_fuser3);

	g_iTimeUntil[iActivator]++;

	if(g_iTimeUntil[iActivator] == 10 || g_eCvars[FORCE_FWD_MODE]) {
		flTimeUntil[1] -= 1.0;

		if(!is_user_alive(iActivator)) {
			UTIL_ResetEntityThink(g_eForwards[ReviveCancelled], iEnt, iPlayer, iActivator, eCurrentMode);
			return;
		}

		new fwRet;
		ExecuteForward(g_eForwards[ReviveLoop_Pre], fwRet, iEnt, iPlayer, iActivator, flTimeUntil[1], eCurrentMode);

		if(fwRet == PLUGIN_HANDLED) {
			UTIL_ResetEntityThink(g_eForwards[ReviveCancelled], iEnt, iPlayer, iActivator, eCurrentMode);
			return;
		}
	}

	if(flGameTime > flTimeUntil[0]) {
		new Modes:iMode = Modes:get_entvar(iEnt, var_iuser3);

		if(eCurrentMode == MODE_REVIVE && iMode != MODE_PLANT) {
			UTIL_NotifyClient(iActivator, print_team_red, "%l%l", "RT_CHAT_TAG", "RT_REVIVE", iPlayer);
			UTIL_NotifyClient(iPlayer, print_team_red, "%l%l", "RT_CHAT_TAG", "RT_REVIVED", iActivator);

			get_entvar(iActivator, var_origin, g_fSpawnOrigin);

			UTIL_RemoveCorpses(iPlayer, DEAD_BODY_CLASSNAME);

			EnableHookChain(g_iGetPlayerSpawnSpot_HookChain);
			rg_round_respawn(iPlayer);
			DisableHookChain(g_iGetPlayerSpawnSpot_HookChain);

			if(is_user_alive(iPlayer))
				engfunc(EngFunc_SetOrigin, iPlayer, g_fSpawnOrigin);
		}

		if(!is_user_alive(iActivator)) {
			UTIL_ResetEntityThink(g_eForwards[ReviveCancelled], iEnt, iPlayer, iActivator, eCurrentMode);
			return;
		}

		ExecuteForward(g_eForwards[ReviveEnd], _, iEnt, iPlayer, iActivator, eCurrentMode);

		return;
	}

	if(g_iTimeUntil[iActivator] == 10 || g_eCvars[FORCE_FWD_MODE]) {
		if(!is_user_alive(iActivator)) {
			UTIL_ResetEntityThink(g_eForwards[ReviveCancelled], iEnt, iPlayer, iActivator, eCurrentMode);
			return;
		}

		ExecuteForward(g_eForwards[ReviveLoop_Post], _, iEnt, iPlayer, iActivator, flTimeUntil[1], eCurrentMode);

		g_iTimeUntil[iActivator] = 0;
	}

	set_entvar(iEnt, var_fuser3, flTimeUntil[1]);
	set_entvar(iEnt, var_nextthink, flGameTime + 0.1);
}

public MessageHook_ClCorpse() {
	if(get_member_game(m_bRoundTerminating))
		return PLUGIN_HANDLED;

	enum {
		arg_body = 10,
		arg_id = 12
	};

	new iPlayer = get_msg_arg_int(arg_id);
	new TeamName:iPlTeam = TeamName:get_member(iPlayer, m_iTeam);

	if(iPlTeam == TEAM_SPECTATOR)
		return PLUGIN_HANDLED;

	new iEnt = rg_create_entity("info_target");

	new fwRet;
	ExecuteForward(g_eForwards[CreatingCorpseStart], fwRet, iEnt, iPlayer);

	if(fwRet == PLUGIN_HANDLED) {
		set_entvar(iEnt, var_flags, FL_KILLME);
		set_entvar(iEnt, var_nextthink, 0.0);
		return PLUGIN_HANDLED;
	}

	new szModel[32], szModelPath[MAX_RESOURCE_PATH_LENGTH];

	get_user_info(iPlayer, "model", szModel, charsmax(szModel));
	formatex(szModelPath, charsmax(szModelPath), "models/player/%s/%s.mdl", szModel, szModel);
	set_entvar(iEnt, var_modelindex, engfunc(EngFunc_ModelIndex, szModelPath));
	set_entvar(iEnt, var_model, szModelPath);
	set_entvar(iEnt, var_renderfx, kRenderFxDeadPlayer);
	set_entvar(iEnt, var_renderamt, float(iPlayer));

	set_entvar(iEnt, var_classname, DEAD_BODY_CLASSNAME);
	set_entvar(iEnt, var_body, get_msg_arg_int(arg_body));
	set_entvar(iEnt, var_sequence, get_entvar(iPlayer, var_sequence));
	set_entvar(iEnt, var_frame, 255.0);
	set_entvar(iEnt, var_skin, get_entvar(iPlayer, var_skin));
	set_entvar(iEnt, var_owner, iPlayer);
	set_entvar(iEnt, var_team, iPlTeam);

	new Float:fOrigin[3];
	get_entvar(iPlayer, var_origin, fOrigin);
	engfunc(EngFunc_SetOrigin, iEnt, fOrigin);

	new Float:fAngles[3];
	get_entvar(iPlayer, var_angles, fAngles);
	set_entvar(iEnt, var_angles, fAngles);

	engfunc(EngFunc_GetBonePosition, iEnt, 2, fOrigin, fAngles);
	set_entvar(iEnt, var_vuser4, fOrigin);

	set_entvar(iEnt, var_fuser2, g_eCvars[SEARCH_RADIUS]);

	set_entvar(iEnt, var_nextthink, get_gametime() + 1.0);
	SetThink(iEnt, "Corpse_Think");

	if(g_eCvars[CORPSE_TIME])
		set_entvar(iEnt, var_fuser4, get_gametime() + g_eCvars[CORPSE_TIME]);

	fOrigin[2] += 20.0;

	ExecuteForward(g_eForwards[CreatingCorpseEnd], _, iEnt, iPlayer, PrepareArray(_:fOrigin, sizeof(fOrigin)));

	return PLUGIN_HANDLED;
}

public CreateCvars() {
	bind_pcvar_float(create_cvar(
		"rt_revive_time",
		"3.0",
		FCVAR_NONE,
		"Duration of the player's resurrection(in seconds)",
		true,
		1.0),
		g_eCvars[REVIVE_TIME]
	);
	bind_pcvar_float(create_cvar(
		"rt_revive_antiflood",
		"3.0",
		FCVAR_NONE,
		"Duration of anti-flood resurrection(in seconds)",
		true,
		1.0),
		g_eCvars[ANTIFLOOD_TIME]
	);
	bind_pcvar_float(create_cvar(
		"rt_corpse_time",
		"30.0",
		FCVAR_NONE,
		"Duration of a corpse's life (in seconds). If you set it to 0, the corpse lives until the end of the round.",
		true,
		0.0),
		g_eCvars[CORPSE_TIME]
	);
	bind_pcvar_float(create_cvar(
		"rt_search_radius",
		"64.0",
		FCVAR_NONE,
		"Search radius for a corpse",
		true,
		1.0),
		g_eCvars[SEARCH_RADIUS]
	);
	bind_pcvar_num(create_cvar(
		"rt_force_fwd_mode",
		"0",
		FCVAR_NONE,
		"Execute forwards more often. Set this to 1 if 'rt_no_move 1' didn't work properly.",
		true,
		0.0,
		true,
		1.0),
		g_eCvars[FORCE_FWD_MODE]
	);
}