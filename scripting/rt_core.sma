#include <amxmodx>
#include <rt_api>

enum CVARS
{
	Float:REVIVE_TIME,
	Float:ANTIFLOOD_TIME
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

new Float:g_flLastUse[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin("Revive Teammates: Core", VERSION, AUTHORS);

	register_dictionary("rt_library.txt");

	register_message(get_user_msgid("ClCorpse"), "MessageHook_ClCorpse");

	RegisterHookChain(RG_CSGameRules_CleanUpMap, "CSGameRules_CleanUpMap_Post", .post = 1);
	RegisterHookChain(RG_CBasePlayer_UseEmpty, "CBasePlayer_UseEmpty", .post = 0);

	bind_pcvar_float(create_cvar("rt_revive_time", "3.0", FCVAR_NONE, "Duration of the player's resurrection(in seconds)", true, 1.0), g_eCvars[REVIVE_TIME]);
	bind_pcvar_float(create_cvar("rt_revive_antiflood", "3.0", FCVAR_NONE, "Duration of anti-flood resurrection(in seconds)", true, 1.0), g_eCvars[ANTIFLOOD_TIME]);

	g_eForwards[ReviveStart] = CreateMultiForward("rt_revive_start", ET_CONTINUE, FP_CELL, FP_CELL, FP_CELL);
	g_eForwards[ReviveLoop_Pre] = CreateMultiForward("rt_revive_loop_pre", ET_CONTINUE, FP_CELL, FP_CELL, FP_CELL, FP_CELL, FP_CELL);
	g_eForwards[ReviveLoop_Post] = CreateMultiForward("rt_revive_loop_post", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL, FP_CELL, FP_CELL);
	g_eForwards[ReviveEnd] = CreateMultiForward("rt_revive_end", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
	g_eForwards[ReviveCancelled] = CreateMultiForward("rt_revive_cancelled", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
}

public plugin_cfg()
{
	UTIL_UploadConfigs();
}

public CSGameRules_CleanUpMap_Post()
{
	UTIL_RemoveAllEnts();
}

public CBasePlayer_UseEmpty(const iActivator)
{
	new iEntity = NULLENT;

	new Float:vPlOrigin[3], Float:vBoneOrigin[3][3];

	get_entvar(iActivator, var_origin, vPlOrigin);

	while((iEntity = rg_find_ent_by_class(iEntity, DEAD_BODY_CLASSNAME)) > 0)
	{
		engfunc(EngFunc_GetBonePosition, iEntity, 2, vBoneOrigin[0]);
		engfunc(EngFunc_GetBonePosition, iEntity, 8, vBoneOrigin[1]);
		engfunc(EngFunc_GetBonePosition, iEntity, 48, vBoneOrigin[2]);

		for(new i; i < 3; i++)
		{
			if(is_in_viewcone(iActivator, vBoneOrigin[i]) && get_distance_f(vPlOrigin, vBoneOrigin[i]) <= 64.0)
			{
				Corpse_Think(iEntity);
				set_entvar(iEntity, var_nextthink, get_gametime() + 1.0);
				Corpse_Use(iEntity, iActivator);

				break;
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

	new Float:flTimer = g_eCvars[REVIVE_TIME], Float:flGameTime = get_gametime();

	new iPlayer = get_entvar(iEnt, var_owner);

	new TeamName:iActTeam = get_member(iActivator, m_iTeam), TeamName:iPlTeam = get_member(iPlayer, m_iTeam);
	
	if(iActTeam == TEAM_SPECTATOR || iPlTeam == TEAM_SPECTATOR)
	{
		return;
	}
	
	if(g_flLastUse[iActivator] > flGameTime)
	{
		client_print_color(iActivator, print_team_red, "%L %L", iActivator, "RT_CHAT_TAG", iActivator, "RT_ANTI_FLOOD");
		return;
	}

	g_flLastUse[iActivator] = flGameTime + g_eCvars[ANTIFLOOD_TIME];

	new fwRet;

	if(iActTeam == iPlTeam)
	{
		ExecuteForward(g_eForwards[ReviveStart], fwRet, iPlayer, iActivator, MODE_REVIVE);
	}
	else
	{
		ExecuteForward(g_eForwards[ReviveStart], fwRet, iPlayer, iActivator, MODE_PLANT);
	}

	if(fwRet == PLUGIN_HANDLED)
	{
		if(iActTeam == iPlTeam)
		{
			ExecuteForward(g_eForwards[ReviveCancelled], _, iPlayer, iActivator, MODE_REVIVE);
		}
		else
		{
			ExecuteForward(g_eForwards[ReviveCancelled], _, iPlayer, iActivator, MODE_PLANT);
		}

		return;
	}

	set_entvar(iEnt, var_fuser1, flTimer);
	set_entvar(iEnt, var_iuser1, iActivator);
}

public Corpse_Think(const iEnt)
{
	if(is_nullent(iEnt))
	{
		return;
	}
	
	new iPlayer = get_entvar(iEnt, var_owner), iActivator = get_entvar(iEnt, var_iuser1);
	
	if(!is_user_connected(iPlayer) || is_user_alive(iPlayer) || get_member(iPlayer, m_iTeam) == TEAM_SPECTATOR)
	{
		UTIL_RemoveAllEnts(iPlayer);
		return;
	}
	
	new Float:flNextThink = 1.0;
	
	if(!iActivator)
	{
		set_entvar(iEnt, var_nextthink, get_gametime() + flNextThink);
		return;
	}

	new TeamName:iActTeam = get_member(iActivator, m_iTeam), TeamName:iPlTeam = get_member(iPlayer, m_iTeam);
	new modes_struct: eCurrentMode = (iActTeam == iPlTeam) ? MODE_REVIVE : MODE_PLANT;
	
	new Float:flTimeUntil = get_entvar(iEnt, var_fuser1);
	
	if(~get_entvar(iActivator, var_button) & IN_USE)
	{
		flTimeUntil = g_eCvars[REVIVE_TIME];
		set_entvar(iEnt, var_fuser1, flTimeUntil);

		ExecuteForward(g_eForwards[ReviveCancelled], _, iPlayer, iActivator, eCurrentMode);

		return;
	}
	
	new fwRet;
	
	ExecuteForward(g_eForwards[ReviveLoop_Pre], fwRet, iPlayer, iActivator, flTimeUntil, flNextThink, eCurrentMode);
	
	if(fwRet == PLUGIN_HANDLED)
	{
		flTimeUntil = g_eCvars[REVIVE_TIME];
		set_entvar(iEnt, var_fuser1, flTimeUntil);

		ExecuteForward(g_eForwards[ReviveCancelled], _, iPlayer, iActivator, eCurrentMode);
		
		return;
	}
	
	if(--flTimeUntil <= 0.0)
	{
		if(iActTeam == iPlTeam)
		{
			rg_round_respawn(iPlayer);

			new Float:fOrigin[3];
			get_entvar(iActivator, var_origin, fOrigin);

			set_entvar(iPlayer, var_flags, get_entvar(iPlayer, var_flags) | FL_DUCKING);
			engfunc(EngFunc_SetSize, iPlayer, Float:{-16.000000, -16.000000, -18.000000}, Float:{16.000000, 16.000000, 32.000000});
			engfunc(EngFunc_SetOrigin, iPlayer, fOrigin);
			
			client_print_color(iActivator, print_team_blue, "%L %L", iActivator, "RT_CHAT_TAG", iActivator, "RT_REVIVE", iPlayer);
			
			UTIL_RemoveAllEnts(iPlayer);

			ExecuteForward(g_eForwards[ReviveEnd], _, iPlayer, iActivator, eCurrentMode);

			return;
		}
		else
		{
			flTimeUntil = g_eCvars[REVIVE_TIME];

			client_print_color(iActivator, print_team_red, "%L %L", iActivator, "RT_CHAT_TAG", iActivator, "RT_PLANTING", iPlayer);
			
			ExecuteForward(g_eForwards[ReviveEnd], _, iPlayer, iActivator, eCurrentMode);

			return;
		}
	}
	
	ExecuteForward(g_eForwards[ReviveLoop_Post], _, iPlayer, iActivator, flTimeUntil, flNextThink, eCurrentMode);
	
	set_entvar(iEnt, var_fuser1, flTimeUntil);
	set_entvar(iEnt, var_nextthink, get_gametime() + flNextThink);
}

public MessageHook_ClCorpse()
{
	enum
	{
		arg_model = 1,
		arg_class_id = 10,
		arg_player_id = 12
	};

	new iPlayer = get_msg_arg_int(arg_player_id);

	if(!is_user_connected(iPlayer) || is_user_alive(iPlayer))
	{
		return PLUGIN_HANDLED;
	}

	new iEntity = rg_create_entity("info_target");

	if(is_nullent(iEntity))
	{
		return PLUGIN_HANDLED;
	}

	new szTemp[MAX_RESOURCE_PATH_LENGTH], szModel[MAX_RESOURCE_PATH_LENGTH];

	get_msg_arg_string(arg_model, szTemp, charsmax(szTemp));
	formatex(szModel, charsmax(szModel), "models/player/%s/%s.mdl", szTemp, szTemp);

	engfunc(EngFunc_SetModel, iEntity, szModel);

	set_entvar(iEntity, var_classname, DEAD_BODY_CLASSNAME);
	set_entvar(iEntity, var_body, get_msg_arg_int(arg_class_id));
	set_entvar(iEntity, var_sequence, get_entvar(iPlayer, var_sequence));
	set_entvar(iEntity, var_owner, iPlayer);
	set_entvar(iEntity, var_frame, 255.0);
	set_entvar(iEntity, var_skin, get_entvar(iPlayer, var_skin));

	new Float:fOrigin[3];
	get_entvar(iPlayer, var_origin, fOrigin);
	engfunc(EngFunc_SetOrigin, iEntity, fOrigin);

	new Float:fAngles[3];
	get_entvar(iPlayer, var_angles, fAngles);
	set_entvar(iEntity, var_angles, fAngles);

	SetThink(iEntity, "Corpse_Think");

	set_entvar(iEntity, var_armorvalue, get_entvar(iPlayer, var_armorvalue))

	return PLUGIN_HANDLED;
}