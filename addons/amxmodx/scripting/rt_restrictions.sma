#include <amxmodx>
#include <reapi>
#include <rt_api>

#define m_iCurrentRound (get_member_game(m_iTotalRoundsPlayed) + 1)

enum CVARS
{
	ACCESS[32],
	MAX_REVIVES,
	MAX_SPAWNS,
	NO_FIRE,
	BOMB,
	DUEL,
	SURVIVOR,
	MIN_ROUND,
	NO_MOVE,
	WIN_DIFF,
	REVIVE_COST,
	PLANTING_COST,
	Float:REMAINING_TIME,
	FORCE_FWD_MODE
};

new g_eCvars[CVARS];

enum _:PlayerData
{
	REVIVE_COUNT
};

new g_ePlayerData[MAX_PLAYERS + 1][PlayerData];

new g_iAccessFlags, g_iPreventFlags;

new HookChain:g_pHook_ResetMaxSpeed;

public plugin_precache()
{
	RegisterCvars();
	UploadConfigs();
}

public plugin_init()
{
	register_plugin("Revive Teammates: Restrictions", VERSION, AUTHORS);

	register_dictionary("rt_library.txt");

	RegisterHookChain(RG_CSGameRules_CleanUpMap, "CSGameRules_CleanUpMap_Post", .post = 1);
	DisableHookChain(g_pHook_ResetMaxSpeed = RegisterHookChain(RG_CBasePlayer_ResetMaxSpeed, "CBasePlayer_ResetMaxSpeed_Post", .post = 1));

	g_iPreventFlags = (PLAYER_PREVENT_CLIMB|PLAYER_PREVENT_JUMP);
}

public plugin_cfg()
{
	g_iAccessFlags = read_flags(g_eCvars[ACCESS]);

	if(g_eCvars[NO_MOVE] == 1)
		EnableHookChain(g_pHook_ResetMaxSpeed);
}

public CSGameRules_CleanUpMap_Post()
{
	arrayset(g_ePlayerData[0][_:0], 0, sizeof(g_ePlayerData) * sizeof(g_ePlayerData[]));
}

public client_disconnected(id)
{
	g_ePlayerData[id][REVIVE_COUNT] = 0;
}

public CBasePlayer_ResetMaxSpeed_Post(const iActivator)
{
	if(get_entvar(iActivator, var_iuser3) & g_iPreventFlags)
		set_entvar(iActivator, var_maxspeed, 1.0);
}

public rt_revive_start(const iEnt, const id, const iActivator, const modes_struct:eMode)
{
	if((get_user_flags(iActivator) & g_iAccessFlags) != g_iAccessFlags)
	{
		UTIL_NotifyClient(iActivator, print_team_red, "RT_NO_ACCESS");
		return PLUGIN_HANDLED;
	}

	if(m_iCurrentRound < g_eCvars[MIN_ROUND])
	{
		UTIL_NotifyClient(iActivator, print_team_red, "RT_MIN_ROUND", g_eCvars[MIN_ROUND]);
		return PLUGIN_HANDLED;
	}

	if(g_eCvars[BOMB] && rg_is_bomb_planted())
	{
		UTIL_NotifyClient(iActivator, print_team_red, "RT_BOMB");
		return PLUGIN_HANDLED;
	}

	if(g_eCvars[SURVIVOR] && rg_users_count(1))
	{
		UTIL_NotifyClient(iActivator, print_team_red, "RT_SURVIVOR");
		return PLUGIN_HANDLED;
	}

	if(g_eCvars[DUEL] && rg_users_count(0))
	{
		UTIL_NotifyClient(iActivator, print_team_red, "RT_DUEL");
		return PLUGIN_HANDLED;
	}

	if(g_eCvars[WIN_DIFF] && (rg_get_team_wins_row(g_eCvars[WIN_DIFF]) == TeamName:get_member(iActivator, m_iTeam)))
	{
		UTIL_NotifyClient(iActivator, print_team_red, "RT_WINS_DOMINATION");
		return PLUGIN_HANDLED;
	}

	if(g_eCvars[REMAINING_TIME] && rg_get_remaining_time() <= g_eCvars[REMAINING_TIME])
	{
		UTIL_NotifyClient(iActivator, print_team_red, "RT_REMAINING_TIME");
		return PLUGIN_HANDLED;
	}

	switch(eMode)
	{
		case MODE_REVIVE:
		{
			if(g_ePlayerData[iActivator][REVIVE_COUNT] >= g_eCvars[MAX_REVIVES])
			{
				UTIL_NotifyClient(iActivator, print_team_red, "RT_REVIVE_COUNT");
				return PLUGIN_HANDLED;
			}

			if(get_member(id, m_iNumSpawns) > g_eCvars[MAX_SPAWNS])
			{
				UTIL_NotifyClient(iActivator, print_team_red, "RT_MAX_SPAWNS");
				return PLUGIN_HANDLED;
			}

			if(get_member(iActivator, m_iAccount) < g_eCvars[REVIVE_COST])
			{
				UTIL_NotifyClient(iActivator, print_team_red, "RT_NO_MONEY");
				return PLUGIN_HANDLED;
			}
		}
		case MODE_PLANT:
		{
			if(get_member(iActivator, m_iAccount) < g_eCvars[PLANTING_COST])
			{
				UTIL_NotifyClient(iActivator, print_team_red, "RT_NO_MONEY");
				return PLUGIN_HANDLED;
			}
		}
	}

	if(g_eCvars[NO_MOVE] == 1)
	{
		set_entvar(iActivator, var_iuser3, get_entvar(iActivator, var_iuser3) | g_iPreventFlags);
		set_entvar(iActivator, var_velocity, NULL_VECTOR);
		rg_reset_maxspeed(iActivator);
	}

	if(g_eCvars[NO_FIRE])
		set_member(iActivator, m_bIsDefusing, true);

	return PLUGIN_CONTINUE;
}

public rt_revive_loop_pre(const iEnt, const id, const iActivator, const Float:timer, modes_struct:eMode)
{
	if(g_eCvars[BOMB] && rg_is_bomb_planted())
	{
		UTIL_NotifyClient(iActivator, print_team_red, "RT_BOMB");
		return PLUGIN_HANDLED;
	}

	if(g_eCvars[DUEL] && rg_users_count(0))
	{
		UTIL_NotifyClient(iActivator, print_team_red, "RT_DUEL");
		return PLUGIN_HANDLED;
	}

	if(g_eCvars[SURVIVOR] && rg_users_count(1))
	{
		UTIL_NotifyClient(iActivator, print_team_red, "RT_SURVIVOR");
		return PLUGIN_HANDLED;
	}

	if(g_eCvars[REMAINING_TIME] && rg_get_remaining_time() <= g_eCvars[REMAINING_TIME])
	{
		UTIL_NotifyClient(iActivator, print_team_red, "RT_REMAINING_TIME");
		return PLUGIN_HANDLED;
	}

	if(g_eCvars[NO_MOVE] == 2)
	{
		static Float:vPlOrigin[3], Float:vEntOrigin[3];
		get_entvar(iActivator, var_origin, vPlOrigin);
		get_entvar(iEnt, var_vuser4, vEntOrigin);

		if(vector_distance(vPlOrigin, vEntOrigin) > get_entvar(iEnt, var_fuser2))
		{
			UTIL_NotifyClient(iActivator, print_team_red, "RT_MAX_DISTANCE");
			return PLUGIN_HANDLED;
		}
	}

	return PLUGIN_CONTINUE;
}

public rt_revive_loop_post(const iEnt, const id, const iActivator, const Float:timer, modes_struct:eMode)
{
	if(g_eCvars[FORCE_FWD_MODE] && g_eCvars[NO_MOVE] == 1)
	{
		set_entvar(iActivator, var_maxspeed, 1.0);
	}
}

public rt_revive_cancelled(const iEnt, const id, const iActivator, const modes_struct:eMode)
{
	if(iActivator == NULLENT)
		return;

	if(g_eCvars[NO_MOVE] == 1)
	{
		set_entvar(iActivator, var_iuser3, get_entvar(iActivator, var_iuser3) & ~g_iPreventFlags);
		rg_reset_maxspeed(iActivator);
	}

	if(g_eCvars[NO_FIRE])
		set_member(iActivator, m_bIsDefusing, false);
}

public rt_revive_end(const iEnt, const id, const iActivator, const modes_struct:eMode)
{
	switch(eMode)
	{
		case MODE_REVIVE:
		{
			static modes_struct:iMode;
			iMode = get_entvar(iEnt, var_iuser3);

			if(iMode != MODE_PLANT)
			{
				g_ePlayerData[iActivator][REVIVE_COUNT]++;

				rg_add_account(iActivator, -g_eCvars[REVIVE_COST]);
			}
		}
		case MODE_PLANT: rg_add_account(iActivator, -g_eCvars[PLANTING_COST]);
	}

	if(g_eCvars[NO_MOVE] == 1)
	{
		set_entvar(iActivator, var_iuser3, get_entvar(iActivator, var_iuser3) & ~g_iPreventFlags);
		rg_reset_maxspeed(iActivator);
	}

	if(g_eCvars[NO_FIRE])
		set_member(iActivator, m_bIsDefusing, false);
}

stock rg_users_count(eMode)
{
	static iAliveTs, iAliveCTs;
	rg_initialize_player_counts(iAliveTs, iAliveCTs);

	if(eMode == 0 && (iAliveTs == 1 && iAliveCTs == 1))
		return 1;
	else if(eMode == 1 && (iAliveTs == 1 || iAliveCTs == 1))
		return 1;

	return 0;
}

stock Float:rg_get_remaining_time()
{
	return (float(get_member_game(m_iRoundTimeSecs)) - get_gametime() + Float:get_member_game(m_fRoundStartTimeReal));
}

stock TeamName:rg_get_team_wins_row(const iWins)
{
	if(get_member_game(m_iNumConsecutiveCTLoses) >= iWins)
		return TEAM_TERRORIST;
	else if(get_member_game(m_iNumConsecutiveTerroristLoses) >= iWins)
		return TEAM_CT;

	return TEAM_UNASSIGNED;
}

public RegisterCvars()
{
	bind_pcvar_string(create_cvar(
		"rt_access",
		"",
		FCVAR_NONE,
		"Access flags for resurrection/planting"),
		g_eCvars[ACCESS],
		charsmax(g_eCvars[ACCESS])
	);
	bind_pcvar_num(create_cvar(
		"rt_max_revives",
		"3",
		FCVAR_NONE,
		"Maximum number of resurrections per round",
		true,
		1.0),
		g_eCvars[MAX_REVIVES]
	);
	bind_pcvar_num(create_cvar(
		"rt_max_spawns",
		"2",
		FCVAR_NONE,
		"Maximum number of spawns per player per round",
		true,
		1.0),
		g_eCvars[MAX_SPAWNS]
	);
	bind_pcvar_num(create_cvar(
		"rt_no_fire",
		"1",
		FCVAR_NONE,
		"Block shooting during resurrection/planting",
		true,
		0.0,
		true,
		1.0),
		g_eCvars[NO_FIRE]
	);
	bind_pcvar_num(create_cvar(
		"rt_bomb",
		"1",
		FCVAR_NONE,
		"You cannot resurrect/plant if there is a bomb",
		true,
		0.0,
		true,
		1.0),
		g_eCvars[BOMB]
	);
	bind_pcvar_num(create_cvar(
		"rt_duel",
		"1",
		FCVAR_NONE,
		"You can't resurrect/plant if there are 1x1 left",
		true,
		0.0,
		true,
		1.0),
		g_eCvars[DUEL]
	);
	bind_pcvar_num(create_cvar(
		"rt_survivor",
		"0",
		FCVAR_NONE,
		"You cannot resurrect/plant if there is 1 live player left in one of the teams",
		true,
		0.0,
		true,
		1.0),
		g_eCvars[SURVIVOR]
	);
	bind_pcvar_num(create_cvar(
		"rt_min_round",
		"1",
		FCVAR_NONE,
		"From which round is resurrection/planting available",
		true,
		1.0),
		g_eCvars[MIN_ROUND]
	);
	bind_pcvar_num(create_cvar(
		"rt_no_move",
		"1",
		FCVAR_NONE,
		"Unable to move during resurrection/planting. 0 - allowed, 1 - not allowed, 2 - allowed, but close to corpse",
		true,
		0.0,
		true,
		2.0),
		g_eCvars[NO_MOVE]
	);
	bind_pcvar_num(create_cvar(
		"rt_revive_cost",
		"0",
		FCVAR_NONE,
		"Cost of resurrection",
		true,
		0.0),
		g_eCvars[REVIVE_COST]
	);
	bind_pcvar_num(create_cvar(
		"rt_planting_cost",
		"0",
		FCVAR_NONE,
		"Cost of planting",
		true,
		0.0),
		g_eCvars[PLANTING_COST]
	);
	bind_pcvar_num(create_cvar(
		"rt_wins_domination",
		"5",
		FCVAR_NONE,
		"Prohibition of resurrection/planting for the dominant team(consecutive wins)",
		true,
		0.0),
		g_eCvars[WIN_DIFF]
	);
	bind_pcvar_float(create_cvar(
		"rt_remaining_time",
		"30.0",
		FCVAR_NONE,
		"Prohibition of resurrection/planting until the end of the round",
		true,
		0.0),
		g_eCvars[REMAINING_TIME]
	);

	new pCvar = get_cvar_pointer("rt_force_fwd_mode");
	if(pCvar)
	{
		bind_pcvar_num(pCvar, g_eCvars[FORCE_FWD_MODE]);
	}
}