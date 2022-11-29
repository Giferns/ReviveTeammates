#include <rt_api>

enum CVARS
{
	Float:REVIVE_TIME,
	Float:ANTIFLOOD_TIME,
	Float:CORPSE_TIME,
	Float:SEARCH_RADIUS
};

new g_eCvars[CVARS];

enum Forwards
{
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

public plugin_precache()
{
	RegisterCvars();
	UTIL_UploadConfigs();
}

public plugin_init()
{
	register_plugin("Revive Teammates: Core", VERSION, AUTHORS);

	register_dictionary("rt_library.txt");

	register_message(get_user_msgid("ClCorpse"), "MessageHook_ClCorpse");

	RegisterHookChain(RG_CSGameRules_CleanUpMap, "CSGameRules_CleanUpMap_Post", .post = 1);
	RegisterHookChain(RG_CBasePlayer_UseEmpty, "CBasePlayer_UseEmpty_Pre", .post = 0);
	
	g_eForwards[ReviveStart] = CreateMultiForward("rt_revive_start", ET_STOP, FP_CELL, FP_CELL, FP_CELL, FP_CELL);
	g_eForwards[ReviveLoop_Pre] = CreateMultiForward("rt_revive_loop_pre", ET_STOP, FP_CELL, FP_CELL, FP_CELL, FP_FLOAT, FP_CELL);
	g_eForwards[ReviveLoop_Post] = CreateMultiForward("rt_revive_loop_post", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL, FP_FLOAT, FP_CELL);
	g_eForwards[ReviveEnd] = CreateMultiForward("rt_revive_end", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL, FP_CELL);
	g_eForwards[ReviveCancelled] = CreateMultiForward("rt_revive_cancelled", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL, FP_CELL);
	g_eForwards[CreatingCorpseStart] = CreateMultiForward("rt_creating_corpse_start", ET_STOP, FP_CELL, FP_CELL);
	g_eForwards[CreatingCorpseEnd] = CreateMultiForward("rt_creating_corpse_end", ET_IGNORE, FP_CELL, FP_CELL, FP_ARRAY);

	g_iPluginLoaded = is_plugin_loaded("rt_planting.amxx", true);
}

public plugin_end()
{
	DestroyForward(g_eForwards[ReviveStart]);
	DestroyForward(g_eForwards[ReviveLoop_Pre]);
	DestroyForward(g_eForwards[ReviveLoop_Post]);
	DestroyForward(g_eForwards[ReviveEnd]);
	DestroyForward(g_eForwards[ReviveCancelled]);
	DestroyForward(g_eForwards[CreatingCorpseStart]);
	DestroyForward(g_eForwards[CreatingCorpseEnd]);
}

public client_disconnected(id)
{
	g_flLastUse[id] = 0.0;
}

public CSGameRules_CleanUpMap_Post()
{
	UTIL_RemoveCorpses(0, DEAD_BODY_CLASSNAME);
}

public CBasePlayer_UseEmpty_Pre(const iActivator)
{
	if(~get_entvar(iActivator, var_flags) & FL_ONGROUND)
	{
		return;
	}

	new iEnt = NULLENT, Float:vPlOrigin[3], Float:vEntOrigin[3];
	get_entvar(iActivator, var_origin, vPlOrigin);

	while((iEnt = rg_find_ent_by_class(iEnt, DEAD_BODY_CLASSNAME)) > 0)
	{
		get_entvar(iEnt, var_vuser4, vEntOrigin);

		if(is_in_viewcone(iActivator, vEntOrigin, 1) && vector_distance(vPlOrigin, vEntOrigin) < g_eCvars[SEARCH_RADIUS])
		{
			Corpse_Use(iEnt, iActivator);

			return;
		}
	}
}

public Corpse_Use(const iEnt, const iActivator)
{
	if(is_nullent(iEnt) || get_member_game(m_bRoundTerminating) || !ExecuteHam(Ham_IsPlayer, iActivator))
	{
		return;
	}

	new iPlayer = get_entvar(iEnt, var_owner);

	if(is_user_alive(iPlayer))
	{
		client_print_color(iActivator, print_team_red, "%L %L", iActivator, "RT_CHAT_TAG", iActivator, "RT_DISCONNECTED");

		UTIL_RemoveCorpses(iPlayer, DEAD_BODY_CLASSNAME);

		return;
	}

	new TeamName:iActTeam = get_member(iActivator, m_iTeam), TeamName:iPlTeam = get_member(iPlayer, m_iTeam), TeamName:iEntTeam = get_entvar(iEnt, var_team);
	new modes_struct:eCurrentMode = (iActTeam == iPlTeam) ? MODE_REVIVE : MODE_PLANT;
	
	if(g_iPluginLoaded == INVALID_PLUGIN_ID && eCurrentMode == MODE_PLANT)
	{
		return;
	}

	if(iActTeam == TEAM_SPECTATOR || iPlTeam == TEAM_SPECTATOR)
	{
		return;
	}

	if(iEntTeam != iPlTeam)
	{
		client_print_color(iActivator, print_team_red, "%L %L", iActivator, "RT_CHAT_TAG", iActivator, "RT_CHANGE_TEAM");

		return;
	}

	if(get_entvar(iEnt, var_iuser1))
	{
		client_print_color(iActivator, print_team_red, "%L %L", iActivator, "RT_CHAT_TAG", iActivator, "RT_ACTIVATOR_EXISTS");

		return;
	}

	if(!is_user_alive(iActivator))
	{
		UTIL_ResetEntityThink(g_eForwards[ReviveCancelled], iEnt, iPlayer, iActivator, eCurrentMode);

		return;
	}

	new fwRet;

	ExecuteForward(g_eForwards[ReviveStart], fwRet, iEnt, UTIL_IsUserConnected(iPlayer), UTIL_IsUserConnected(iActivator), eCurrentMode);

	if(fwRet == PLUGIN_HANDLED)
	{
		UTIL_ResetEntityThink(g_eForwards[ReviveCancelled], iEnt, iPlayer, iActivator, eCurrentMode);

		return;
	}

	new Float:flGameTime = get_gametime();

	if(g_flLastUse[iActivator] > flGameTime)
	{
		client_print_color(iActivator, print_team_red, "%L %L", iActivator, "RT_CHAT_TAG", iActivator, "RT_ANTI_FLOOD");

		UTIL_ResetEntityThink(g_eForwards[ReviveCancelled], iEnt, iPlayer, iActivator, eCurrentMode);

		return;
	}

	g_flLastUse[iActivator] = flGameTime + g_eCvars[ANTIFLOOD_TIME];

	client_print_color(iActivator, print_team_blue, "%L %L", iActivator, "RT_CHAT_TAG",
	iActivator, eCurrentMode == MODE_REVIVE ? "RT_TIMER_REVIVE" : "RT_TIMER_PLANT", iPlayer);

	g_iTimeUntil[iActivator] = 0;

	set_entvar(iEnt, var_iuser1, iActivator);
	set_entvar(iEnt, var_fuser1, flGameTime + g_eCvars[REVIVE_TIME]);
	set_entvar(iEnt, var_fuser3, g_eCvars[REVIVE_TIME]);
	set_entvar(iEnt, var_nextthink, flGameTime + 0.1);
}

public Corpse_Think(const iEnt)
{
	if(is_nullent(iEnt))
	{
		return;
	}

	new iPlayer = get_entvar(iEnt, var_owner), iActivator = get_entvar(iEnt, var_iuser1);
	new TeamName:iActTeam = get_member(iActivator, m_iTeam), TeamName:iPlTeam = get_member(iPlayer, m_iTeam), TeamName:iEntTeam = get_entvar(iEnt, var_team);
	new modes_struct:eCurrentMode = (iActTeam == iPlTeam) ? MODE_REVIVE : MODE_PLANT;

	if(iEntTeam != iPlTeam)
	{
		client_print_color(iActivator, print_team_red, "%L %L", iActivator, "RT_CHAT_TAG", iActivator, "RT_CHANGE_TEAM");

		UTIL_ResetEntityThink(g_eForwards[ReviveCancelled], iEnt, iPlayer, iActivator, eCurrentMode);

		return;
	}

	new Float:flGameTime = get_gametime();
	
	if(g_eCvars[CORPSE_TIME] && !iActivator && get_entvar(iEnt, var_fuser4) < flGameTime)
	{
		UTIL_RemoveCorpses(iPlayer, DEAD_BODY_CLASSNAME);

		return;
	}

	if(is_user_alive(iPlayer))
	{
		client_print_color(iActivator, print_team_red, "%L %L", iActivator, "RT_CHAT_TAG", iActivator, "RT_DISCONNECTED");

		UTIL_ResetEntityThink(g_eForwards[ReviveCancelled], iEnt, iPlayer, iActivator, eCurrentMode);
		UTIL_RemoveCorpses(iPlayer, DEAD_BODY_CLASSNAME);

		return;
	}

	if(~get_entvar(iActivator, var_button) & IN_USE || !is_user_alive(iActivator))
	{
		client_print_color(iActivator, print_team_red, "%L %L", iActivator, "RT_CHAT_TAG",
		iActivator, eCurrentMode == MODE_REVIVE ? "RT_CANCELLED_REVIVE" : "RT_CANCELLED_PLANT", iPlayer);
		
		UTIL_ResetEntityThink(g_eForwards[ReviveCancelled], iEnt, iPlayer, iActivator, eCurrentMode);

		return;
	}
	
	new Float:flTimeUntil[2];
	flTimeUntil[0] = Float:get_entvar(iEnt, var_fuser1);
	flTimeUntil[1] = Float:get_entvar(iEnt, var_fuser3);

	g_iTimeUntil[iActivator]++;

	if(g_iTimeUntil[iActivator] == 10)
	{
		flTimeUntil[1] -= 1.0;

		if(!is_user_alive(iActivator))
		{
			UTIL_ResetEntityThink(g_eForwards[ReviveCancelled], iEnt, iPlayer, iActivator, eCurrentMode);

			return;
		}

		new fwRet;

		ExecuteForward(g_eForwards[ReviveLoop_Pre], fwRet, iEnt, UTIL_IsUserConnected(iPlayer), UTIL_IsUserConnected(iActivator), flTimeUntil[1], eCurrentMode);

		if(fwRet == PLUGIN_HANDLED)
		{
			UTIL_ResetEntityThink(g_eForwards[ReviveCancelled], iEnt, iPlayer, iActivator, eCurrentMode);
			
			return;
		}
	}
	
	if(flGameTime > flTimeUntil[0])
	{
		new modes_struct:iMode = get_entvar(iEnt, var_iuser3);

		if(eCurrentMode == MODE_REVIVE && iMode != MODE_PLANT)
		{
			client_print_color(iActivator, print_team_blue, "%L %L", iActivator, "RT_CHAT_TAG", iActivator, "RT_REVIVE", iPlayer);
			client_print_color(iPlayer, print_team_blue, "%L %L", iPlayer, "RT_CHAT_TAG", iPlayer, "RT_REVIVED", iActivator);

			rg_round_respawn(iPlayer);

			new Float:fOrigin[3];
			get_entvar(iActivator, var_origin, fOrigin);
			set_entvar(iPlayer, var_flags, get_entvar(iPlayer, var_flags) | FL_DUCKING);

			engfunc(EngFunc_SetSize, iPlayer, Float:{-16.000000, -16.000000, -18.000000}, Float:{16.000000, 16.000000, 32.000000});
			engfunc(EngFunc_SetOrigin, iPlayer, fOrigin);
			
			UTIL_RemoveCorpses(iPlayer, DEAD_BODY_CLASSNAME);
		}

		if(!is_user_alive(iActivator))
		{
			UTIL_ResetEntityThink(g_eForwards[ReviveCancelled], iEnt, iPlayer, iActivator, eCurrentMode);

			return;
		}

		ExecuteForward(g_eForwards[ReviveEnd], _, iEnt, UTIL_IsUserConnected(iPlayer), UTIL_IsUserConnected(iActivator), eCurrentMode);

		return;
	}
	
	if(g_iTimeUntil[iActivator] == 10)
	{
		if(!is_user_alive(iActivator))
		{
			UTIL_ResetEntityThink(g_eForwards[ReviveCancelled], iEnt, iPlayer, iActivator, eCurrentMode);

			return;
		}
		
		ExecuteForward(g_eForwards[ReviveLoop_Post], _, iEnt, UTIL_IsUserConnected(iPlayer), UTIL_IsUserConnected(iActivator), flTimeUntil[1], eCurrentMode);

		g_iTimeUntil[iActivator] = 0;
	}
	
	set_entvar(iEnt, var_fuser3, flTimeUntil[1]);
	set_entvar(iEnt, var_nextthink, flGameTime + 0.1);
}

public MessageHook_ClCorpse()
{
	enum
	{
		arg_model = 1,
		arg_body = 10,
		arg_id = 12
	};

	new iPlayer = get_msg_arg_int(arg_id);

	if(is_user_alive(iPlayer))
	{
		return PLUGIN_HANDLED;
	}

	new TeamName:iPlTeam = get_member(iPlayer, m_iTeam)

	if(iPlTeam == TEAM_SPECTATOR)
	{
		return PLUGIN_HANDLED;
	}

	new iEnt = rg_create_entity("info_target");

	if(is_nullent(iEnt))
	{
		return PLUGIN_HANDLED;
	}

	new fwRet;

	ExecuteForward(g_eForwards[CreatingCorpseStart], fwRet, iEnt, iPlayer);

	if(fwRet == PLUGIN_HANDLED)
	{
		set_entvar(iEnt, var_flags, FL_KILLME);
		set_entvar(iEnt, var_nextthink, -1.0);

		return PLUGIN_HANDLED;
	}

	new szTemp[MAX_RESOURCE_PATH_LENGTH], szModel[MAX_RESOURCE_PATH_LENGTH];
	get_msg_arg_string(arg_model, szTemp, charsmax(szTemp));
	formatex(szModel, charsmax(szModel), "models/player/%s/%s.mdl", szTemp, szTemp);

	engfunc(EngFunc_SetModel, iEnt, szModel);

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

	SetThink(iEnt, "Corpse_Think");

	if(g_eCvars[CORPSE_TIME])
	{
		set_entvar(iEnt, var_fuser4, get_gametime() + g_eCvars[CORPSE_TIME]);
	}

	new szOriginData[3];

	for(new i; i < 3; i++)
	{
		szOriginData[i] = floatround(fOrigin[i]);
	}

	szOriginData[2] += 20;

	ExecuteForward(g_eForwards[CreatingCorpseEnd], _, iEnt, iPlayer, PrepareArray(szOriginData, sizeof(szOriginData)));

	return PLUGIN_HANDLED;
}

public RegisterCvars()
{
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
}