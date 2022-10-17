#include <amxmodx>
#include <rt_api>

enum CVARS
{
	Float:REVIVE_TIME,
	Float:ANTIFLOOD_TIME,
	Float:CORPSE_TIME
};

new g_eCvars[CVARS];

enum Forwards
{
	ReviveStart,
	ReviveLoop_Pre,
	ReviveLoop_Post,
	ReviveEnd,
	ReviveCancelled
};

new g_eForwards[Forwards];

const Float:MAX_PLAYER_USE_RADIUS = 64.0;

new g_iPluginLoaded;

new Float:g_flLastUse[MAX_PLAYERS + 1], g_iTimeUntil[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin("Revive Teammates: Core", VERSION, AUTHORS);

	register_dictionary("rt_library.txt");

	register_message(get_user_msgid("ClCorpse"), "MessageHook_ClCorpse");

	RegisterHookChain(RG_CSGameRules_CleanUpMap, "CSGameRules_CleanUpMap_Post", .post = 1);
	RegisterHookChain(RG_CBasePlayer_UseEmpty, "CBasePlayer_UseEmpty_Pre", .post = 0);

	RegisterCvars();
	
	g_eForwards[ReviveStart] = CreateMultiForward("rt_revive_start", ET_STOP, FP_CELL, FP_CELL, FP_CELL);
	g_eForwards[ReviveLoop_Pre] = CreateMultiForward("rt_revive_loop_pre", ET_STOP, FP_CELL, FP_CELL, FP_FLOAT, FP_CELL);
	g_eForwards[ReviveLoop_Post] = CreateMultiForward("rt_revive_loop_post", ET_IGNORE, FP_CELL, FP_CELL, FP_FLOAT, FP_CELL);
	g_eForwards[ReviveEnd] = CreateMultiForward("rt_revive_end", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
	g_eForwards[ReviveCancelled] = CreateMultiForward("rt_revive_cancelled", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);

	g_iPluginLoaded = is_plugin_loaded("rt_planting.amxx", true);
}

public plugin_cfg()
{
	UTIL_UploadConfigs();
}

public plugin_end()
{
	DestroyForward(g_eForwards[ReviveStart]);
	DestroyForward(g_eForwards[ReviveLoop_Pre]);
	DestroyForward(g_eForwards[ReviveLoop_Post]);
	DestroyForward(g_eForwards[ReviveEnd]);
	DestroyForward(g_eForwards[ReviveCancelled]);
}

public client_disconnected(id)
{
	UTIL_RemoveCorpses(id);

	g_flLastUse[id] = 0.0;
}

public CSGameRules_CleanUpMap_Post()
{
	UTIL_RemoveCorpses();
}

public CBasePlayer_UseEmpty_Pre(const iActivator)
{
	if(~get_entvar(iActivator, var_flags) & FL_ONGROUND)
	{
		return;
	}

	new Float:vPlOrigin[3], Float:vPlViewOfs[3], Float:vPlAngle[3], Float:vBoneOrigin[3];

	get_entvar(iActivator, var_origin, vPlOrigin);
	get_entvar(iActivator, var_view_ofs, vPlViewOfs);
	get_entvar(iActivator, var_v_angle, vPlAngle);
	
	engfunc(EngFunc_MakeVectors, vPlAngle);
	global_get(glb_v_forward, vPlAngle);
	
	for(new i; i < 3; i++)
	{
		vPlOrigin[i] += vPlViewOfs[i];
		vPlAngle[i] = vPlAngle[i] * MAX_PLAYER_USE_RADIUS * 2.0 + vPlOrigin[i];
	}

	new iEnt = NULLENT, pHit;

	while((iEnt = rg_find_ent_by_class(iEnt, DEAD_BODY_CLASSNAME)) > 0)
	{
		for(new iBone = 1; iBone <= 54; iBone++)
		{
			engfunc(EngFunc_GetBonePosition, iEnt, iBone, vBoneOrigin);
	
			if(vector_distance(vPlOrigin, vBoneOrigin) < MAX_PLAYER_USE_RADIUS)
			{
				engfunc(EngFunc_TraceModel, vPlOrigin, vPlAngle, HULL_POINT, iEnt, 0);
				pHit = get_tr2(0, TR_pHit);
						
				if(pHit == iEnt && !is_nullent(pHit))
				{
					Corpse_Use(iEnt, iActivator);

					return;
				}
			}
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

	if(!is_user_connected(iPlayer) || is_user_alive(iPlayer))
	{
		return;
	}

	new TeamName:iActTeam = get_member(iActivator, m_iTeam), TeamName:iPlTeam = get_member(iPlayer, m_iTeam);
	new modes_struct:eCurrentMode = (iActTeam == iPlTeam) ? MODE_REVIVE : MODE_PLANT;
	
	if(g_iPluginLoaded == INVALID_PLUGIN_ID && eCurrentMode == MODE_PLANT)
	{
		return;
	}

	if(iActTeam == TEAM_SPECTATOR || iPlTeam == TEAM_SPECTATOR)
	{
		return;
	}

	if(get_entvar(iEnt, var_iuser1))
	{
		client_print_color(iActivator, print_team_red, "%L %L", iActivator, "RT_CHAT_TAG", iActivator, "RT_ACTIVATOR_EXISTS");

		return;
	}

	new fwRet;

	ExecuteForward(g_eForwards[ReviveStart], fwRet, iPlayer, iActivator, eCurrentMode);

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

	new TeamName:iEntTeam = get_entvar(iEnt, var_team);

	if(iEntTeam != iPlTeam)
	{
		client_print_color(iActivator, print_team_red, "%L %L", iActivator, "RT_CHAT_TAG", iActivator, "RT_CHANGE_TEAM");

		UTIL_ResetEntityThink(g_eForwards[ReviveCancelled], iEnt, iPlayer, iActivator, eCurrentMode);

		return;
	}

	switch(eCurrentMode)
	{
		case MODE_REVIVE:
		{
			client_print_color(iActivator, print_team_blue, "%L %L", iActivator, "RT_CHAT_TAG", iActivator, "RT_TIMER_REVIVE", iPlayer);
		}
		case MODE_PLANT:
		{
			client_print_color(iActivator, print_team_blue, "%L %L", iActivator, "RT_CHAT_TAG", iActivator, "RT_TIMER_PLANT", iPlayer);
		}
	}

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
	new TeamName:iActTeam = get_member(iActivator, m_iTeam), TeamName:iPlTeam = get_member(iPlayer, m_iTeam);
	new modes_struct:eCurrentMode = (iActTeam == iPlTeam) ? MODE_REVIVE : MODE_PLANT;

	new Float:flGameTime = get_gametime();
	
	if(!iActivator && get_entvar(iEnt, var_fuser4) < flGameTime)
	{
		UTIL_RemoveCorpses(iPlayer);

		return;
	}

	if(!is_user_connected(iPlayer) || is_user_alive(iPlayer))
	{
		client_print_color(iActivator, print_team_red, "%L %L", iActivator, "RT_CHAT_TAG", iActivator, "RT_DISCONNECTED");

		UTIL_ResetEntityThink(g_eForwards[ReviveCancelled], iEnt, iPlayer, iActivator, eCurrentMode);

		return;
	}

	if(~get_entvar(iActivator, var_button) & IN_USE || !is_user_alive(iActivator))
	{
		switch(eCurrentMode)
		{
			case MODE_REVIVE:
			{
				client_print_color(iActivator, print_team_red, "%L %L", iActivator, "RT_CHAT_TAG", iActivator, "RT_CANCELLED_REVIVE", iPlayer);
			}
			case MODE_PLANT:
			{
				client_print_color(iActivator, print_team_red, "%L %L", iActivator, "RT_CHAT_TAG", iActivator, "RT_CANCELLED_PLANT", iPlayer);
			}
		}
		
		UTIL_ResetEntityThink(g_eForwards[ReviveCancelled], iEnt, iPlayer, iActivator, eCurrentMode);

		return;
	}
	
	new Float:flTimeUntil[2];
	flTimeUntil[0] = Float:get_entvar(iEnt, var_fuser1);
	flTimeUntil[1] = Float:get_entvar(iEnt, var_fuser3);

	g_iTimeUntil[iActivator]++;

	if(g_iTimeUntil[iActivator] == 10)
	{
		new fwRet;

		ExecuteForward(g_eForwards[ReviveLoop_Pre], fwRet, iPlayer, iActivator, flTimeUntil[1], eCurrentMode);

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
			
			UTIL_RemoveCorpses(iPlayer);
		}

		ExecuteForward(g_eForwards[ReviveEnd], _, iPlayer, iActivator, eCurrentMode);

		return;
	}
	
	if(g_iTimeUntil[iActivator] == 10)
	{
		ExecuteForward(g_eForwards[ReviveLoop_Post], _, iPlayer, iActivator, flTimeUntil[1], eCurrentMode);

		flTimeUntil[1] -= 1.0;
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

	if(!is_user_connected(iPlayer) || is_user_alive(iPlayer) || TeamName:get_member(iPlayer, m_iTeam) == TEAM_SPECTATOR)
	{
		return PLUGIN_HANDLED;
	}

	new iEnt = rg_create_entity("info_target");

	if(is_nullent(iEnt))
	{
		return PLUGIN_CONTINUE;
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
	set_entvar(iEnt, var_team, TeamName:get_member(iPlayer, m_iTeam));

	new Float:fOrigin[3];
	get_entvar(iPlayer, var_origin, fOrigin);
	engfunc(EngFunc_SetOrigin, iEnt, fOrigin);

	new Float:fAngles[3];
	get_entvar(iPlayer, var_angles, fAngles);
	set_entvar(iEnt, var_angles, fAngles);

	SetThink(iEnt, "Corpse_Think");

	set_entvar(iEnt, var_fuser4, get_gametime() + g_eCvars[CORPSE_TIME]);

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
		"Duration of the corpse's life(in seconds)",
		true,
		10.0),
		g_eCvars[CORPSE_TIME]
	);
}