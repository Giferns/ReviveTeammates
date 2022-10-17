#include <amxmodx>
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
	NO_MOVE
};

new g_eCvars[CVARS];

enum _:PlayerData
{
	REVIVE_COUNT
};

new g_ePlayerData[MAX_PLAYERS + 1][PlayerData];

new g_iAccessFlags, g_iPreventFlags;

new HookChain:g_pHook_ResetMaxSpeed;

public plugin_init()
{
	register_plugin("Revive Teammates: Restrictions", VERSION, AUTHORS);

	register_dictionary("rt_library.txt");

	RegisterHookChain(RG_CSGameRules_CleanUpMap, "CSGameRules_CleanUpMap_Post", .post = 1);
	DisableHookChain(g_pHook_ResetMaxSpeed = RegisterHookChain(RG_CBasePlayer_ResetMaxSpeed, "CBasePlayer_ResetMaxSpeed_Post", .post = 1));

	RegisterCvars();
	
	g_iPreventFlags = (PLAYER_PREVENT_CLIMB|PLAYER_PREVENT_JUMP);
}

public plugin_cfg()
{
	UTIL_UploadConfigs();

	g_iAccessFlags = read_flags(g_eCvars[ACCESS]);

	if(g_eCvars[NO_MOVE])
	{
		EnableHookChain(g_pHook_ResetMaxSpeed);
	}
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
	{
		set_entvar(iActivator, var_maxspeed, 1.0);
	}
}

public rt_revive_start(const id, const activator, const modes_struct:mode)
{
	if((get_user_flags(activator) & g_iAccessFlags) != g_iAccessFlags)
	{
		client_print_color(activator, print_team_red, "%L %L", activator, "RT_CHAT_TAG", activator, "RT_NO_ACCESS");
		return PLUGIN_HANDLED;
	}

	if(m_iCurrentRound < g_eCvars[MIN_ROUND])
	{
		client_print_color(activator, print_team_red, "%L %L", activator, "RT_CHAT_TAG", activator, "RT_MIN_ROUND", g_eCvars[MIN_ROUND]);
		return PLUGIN_HANDLED;
	}

	if(mode == MODE_REVIVE && g_ePlayerData[activator][REVIVE_COUNT] >= g_eCvars[MAX_REVIVES])
	{
		client_print_color(activator, print_team_red, "%L %L", activator, "RT_CHAT_TAG", activator, "RT_REVIVE_COUNT");
		return PLUGIN_HANDLED;
	}

	if(mode == MODE_REVIVE && get_member(id, m_iNumSpawns) > g_eCvars[MAX_SPAWNS])
	{
		client_print_color(activator, print_team_red, "%L %L", activator, "RT_CHAT_TAG", activator, "RT_MAX_SPAWNS");
		return PLUGIN_HANDLED;
	}

	if(g_eCvars[BOMB] && rg_is_bomb_planted())
	{
		client_print_color(activator, print_team_red, "%L %L", activator, "RT_CHAT_TAG", activator, "RT_BOMB");
		return PLUGIN_HANDLED;
	}

	if(g_eCvars[DUEL] && rg_users_count(0))
	{
		client_print_color(activator, print_team_red, "%L %L", activator, "RT_CHAT_TAG", activator, "RT_DUEL");
		return PLUGIN_HANDLED;
	}

	if(g_eCvars[SURVIVOR] && rg_users_count(1))
	{
		client_print_color(activator, print_team_red, "%L %L", activator, "RT_CHAT_TAG", activator, "RT_SURVIVOR");
		return PLUGIN_HANDLED;
	}

	if(g_eCvars[NO_MOVE])
	{
		set_entvar(activator, var_iuser3, get_entvar(activator, var_iuser3) | g_iPreventFlags);
		set_entvar(activator, var_velocity, NULL_VECTOR);
		rg_reset_maxspeed(activator);
	}

	if(g_eCvars[NO_FIRE])
	{
		set_member(activator, m_bIsDefusing, true);
	}

	return PLUGIN_CONTINUE;
}

public rt_revive_loop_pre(const id, const activator, const Float:timer, modes_struct:mode)
{
	if(g_eCvars[BOMB] && rg_is_bomb_planted())
	{
		client_print_color(activator, print_team_red, "%L %L", activator, "RT_CHAT_TAG", activator, "RT_BOMB");
		return PLUGIN_HANDLED;
	}

	if(g_eCvars[DUEL] && rg_users_count(0))
	{
		client_print_color(activator, print_team_red, "%L %L", activator, "RT_CHAT_TAG", activator, "RT_DUEL");
		return PLUGIN_HANDLED;
	}

	if(g_eCvars[SURVIVOR] && rg_users_count(1))
	{
		client_print_color(activator, print_team_red, "%L %L", activator, "RT_CHAT_TAG", activator, "RT_SURVIVOR");
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public rt_revive_cancelled(const id, const activator, const modes_struct:mode)
{
	if(g_eCvars[NO_MOVE])
	{
		set_entvar(activator, var_iuser3, get_entvar(activator, var_iuser3) & ~g_iPreventFlags);
		rg_reset_maxspeed(activator);
	}

	if(g_eCvars[NO_FIRE])
	{
		set_member(activator, m_bIsDefusing, false);
	}
}

public rt_revive_end(const id, const activator, const modes_struct:mode)
{
	new modes_struct:iMode = get_entvar(UTIL_GetEntityById(id), var_iuser3);

	if(iMode != MODE_PLANT)
	{
		if(iMode != MODE_PLANT && mode == MODE_REVIVE)
		{
			g_ePlayerData[activator][REVIVE_COUNT]++;
		}
	}

	if(g_eCvars[NO_MOVE])
	{
		set_entvar(activator, var_iuser3, get_entvar(activator, var_iuser3) & ~g_iPreventFlags);
		rg_reset_maxspeed(activator);
	}

	if(g_eCvars[NO_FIRE])
	{
		set_member(activator, m_bIsDefusing, false);
	}
}

stock rg_users_count(mode)
{
	new iAliveTs, iAliveCTs;
	rg_initialize_player_counts(iAliveTs, iAliveCTs);

	switch(mode)
	{
		case 0:
		{
			if(iAliveTs == 1 && iAliveCTs == 1)
			{
				return 1;
			}
		}
		case 1:
		{
			if(iAliveTs == 1 || iAliveCTs == 1)
			{
				return 1;
			}
		}
	}

	return 0;
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
		0.0),
		g_eCvars[NO_FIRE]
	);
	bind_pcvar_num(create_cvar(
		"rt_bomb",
		"1",
		FCVAR_NONE,
		"You cannot resurrect/plant if there is a bomb",
		true,
		0.0),
		g_eCvars[BOMB]
	);
	bind_pcvar_num(create_cvar(
		"rt_duel",
		"1",
		FCVAR_NONE,
		"You can't resurrect/plant if there are 1x1 left",
		true,
		0.0),
		g_eCvars[DUEL]
	);
	bind_pcvar_num(create_cvar(
		"rt_survivor",
		"0",
		FCVAR_NONE,
		"You cannot resurrect/plant if there is 1 live player left in one of the teams",
		true,
		0.0),
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
		"Cannot move during resurrection/planting",
		true,
		0.0),
		g_eCvars[NO_MOVE]
	);
}