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

new g_iPluginLoaded;

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
	g_eForwards[ReviveLoop_Pre] = CreateMultiForward("rt_revive_loop_pre", ET_CONTINUE, FP_CELL, FP_CELL, FP_CELL, FP_CELL);
	g_eForwards[ReviveLoop_Post] = CreateMultiForward("rt_revive_loop_post", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL, FP_CELL);
	g_eForwards[ReviveEnd] = CreateMultiForward("rt_revive_end", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
	g_eForwards[ReviveCancelled] = CreateMultiForward("rt_revive_cancelled", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);

	g_iPluginLoaded = is_plugin_loaded("rt_planting.amxx", true);
}

public plugin_cfg()
{
	UTIL_UploadConfigs();
}

public client_disconnected(id)
{
	UTIL_RemoveCorpses(id);
}

public CSGameRules_CleanUpMap_Post()
{
	UTIL_RemoveCorpses();
}

public CBasePlayer_UseEmpty(const iActivator)
{
	new iEnt = NULLENT;
	new Float:vPlOrigin[3], Float:vBoneOrigin[6][3];

	get_entvar(iActivator, var_origin, vPlOrigin);

	while((iEnt = rg_find_ent_by_class(iEnt, DEAD_BODY_CLASSNAME)) > 0)
	{
		UTIL_GetPositionBonesCorpse(iEnt, vBoneOrigin);

		for(new i; i < sizeof(vBoneOrigin); i++)
		{
			if(is_in_viewcone(iActivator, vBoneOrigin[i]) && get_distance_f(vPlOrigin, vBoneOrigin[i]) <= 64.0)
			{
				Corpse_Use(iEnt, iActivator);

				return;
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

	new Float:flGameTime = get_gametime();

	if(g_flLastUse[iActivator] > flGameTime)
	{
		client_print_color(iActivator, print_team_red, "%L %L", iActivator, "RT_CHAT_TAG", iActivator, "RT_ANTI_FLOOD");

		set_entvar(iEnt, var_nextthink, 0.0);
		
		ExecuteForward(g_eForwards[ReviveCancelled], _, iPlayer, iActivator, eCurrentMode);
		
		return;
	}

	g_flLastUse[iActivator] = flGameTime + g_eCvars[ANTIFLOOD_TIME];

	new fwRet;

	ExecuteForward(g_eForwards[ReviveStart], fwRet, iPlayer, iActivator, eCurrentMode);

	if(fwRet == PLUGIN_HANDLED)
	{
		set_entvar(iEnt, var_nextthink, 0.0);
		
		ExecuteForward(g_eForwards[ReviveCancelled], _, iPlayer, iActivator, eCurrentMode);

		return;
	}

	set_entvar(iEnt, var_fuser1, g_eCvars[REVIVE_TIME]);
	set_entvar(iEnt, var_iuser1, iActivator);
	set_entvar(iEnt, var_nextthink, get_gametime() + 1.0);
}

public Corpse_Think(const iEnt)
{
	if(is_nullent(iEnt))
	{
		return;
	}
	
	new iPlayer = get_entvar(iEnt, var_owner), iActivator = get_entvar(iEnt, var_iuser1);
	
	if(!is_user_connected(iPlayer) || is_user_alive(iPlayer))
	{
		return;
	}

	new TeamName:iActTeam = get_member(iActivator, m_iTeam), TeamName:iPlTeam = get_member(iPlayer, m_iTeam);
	new modes_struct:eCurrentMode = (iActTeam == iPlTeam) ? MODE_REVIVE : MODE_PLANT;

	if(~get_entvar(iActivator, var_button) & IN_USE || !is_user_alive(iActivator))
	{
		set_entvar(iEnt, var_nextthink, 0.0);

		ExecuteForward(g_eForwards[ReviveCancelled], _, iPlayer, iActivator, eCurrentMode);

		return;
	}
	
	if(!iActivator)
	{
		set_entvar(iEnt, var_nextthink, 0.0);

		return;
	}

	new Float:flTimeUntil = get_entvar(iEnt, var_fuser1);
	
	new fwRet;
	
	ExecuteForward(g_eForwards[ReviveLoop_Pre], fwRet, iPlayer, iActivator, flTimeUntil, eCurrentMode);
	
	if(fwRet == PLUGIN_HANDLED)
	{
		set_entvar(iEnt, var_nextthink, 0.0);

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
			
			UTIL_RemoveCorpses(iPlayer);

			ExecuteForward(g_eForwards[ReviveEnd], _, iPlayer, iActivator, eCurrentMode);

			return;
		}
		else
		{
			ExecuteForward(g_eForwards[ReviveEnd], _, iPlayer, iActivator, eCurrentMode);

			return;
		}
	}
	
	ExecuteForward(g_eForwards[ReviveLoop_Post], _, iPlayer, iActivator, flTimeUntil, eCurrentMode);
	
	set_entvar(iEnt, var_fuser1, flTimeUntil);
	set_entvar(iEnt, var_nextthink, get_gametime() + 1.0);
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
	set_entvar(iEnt, var_body, get_msg_arg_int(arg_class_id));
	set_entvar(iEnt, var_sequence, get_entvar(iPlayer, var_sequence));
	set_entvar(iEnt, var_frame, 255.0);
	set_entvar(iEnt, var_skin, get_entvar(iPlayer, var_skin));
	set_entvar(iEnt, var_owner, iPlayer);

	new Float:fOrigin[3];
	get_entvar(iPlayer, var_origin, fOrigin);
	engfunc(EngFunc_SetOrigin, iEnt, fOrigin);

	new Float:fAngles[3];
	get_entvar(iPlayer, var_angles, fAngles);
	set_entvar(iEnt, var_angles, fAngles);

	SetThink(iEnt, "Corpse_Think");

	set_entvar(iEnt, var_armorvalue, get_entvar(iPlayer, var_armorvalue));

	return PLUGIN_HANDLED;
}