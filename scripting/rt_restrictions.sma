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
	MIN_ROUND
};

new g_eCvars[CVARS];

enum _:PlayerData
{
	REVIVE_COUNT
};

new g_ePlayerData[MAX_PLAYERS + 1][PlayerData];

new g_iAccessFlags;

public plugin_init()
{
	register_plugin("Revive Teammates: Restrictions", VERSION, AUTHORS);

	register_dictionary("rt_library.txt");

	RegisterHookChain(RG_CSGameRules_CleanUpMap, "CSGameRules_CleanUpMap_Post", .post = 1);

	bind_pcvar_string(create_cvar("rt_access", "", FCVAR_NONE, "Access flags for resurrection/mining"), g_eCvars[ACCESS], charsmax(g_eCvars[ACCESS]));
	bind_pcvar_num(create_cvar("rt_MAX_REVIVES", "3", FCVAR_NONE, "Maximum number of resurrections per round", true, 1.0), g_eCvars[MAX_REVIVES]);
	bind_pcvar_num(create_cvar("rt_max_spawns", "2", FCVAR_NONE, "Maximum number of spawns per player per round", true, 1.0), g_eCvars[MAX_SPAWNS]);
	bind_pcvar_num(create_cvar("rt_no_fire", "1", FCVAR_NONE, "Block shooting during resurrection/mining", true, 0.0), g_eCvars[NO_FIRE]);
	bind_pcvar_num(create_cvar("rt_bomb", "1", FCVAR_NONE, "You cannot resurrect/plant if there is a bomb", true, 0.0), g_eCvars[BOMB]);
	bind_pcvar_num(create_cvar("rt_duel", "1", FCVAR_NONE, "You cannot resurrect/plant if there is a bomb", true, 0.0), g_eCvars[DUEL]);
	bind_pcvar_num(create_cvar("rt_min_round", "1", FCVAR_NONE, "From which round is resurrection/planting available", true, 1.0), g_eCvars[MIN_ROUND]);

	g_iAccessFlags = read_flags(g_eCvars[ACCESS]);
}

public plugin_cfg()
{
	UTIL_UploadConfigs();
}

public CSGameRules_CleanUpMap_Post()
{
	arrayset(g_ePlayerData[0][_:0], 0, sizeof(g_ePlayerData) * sizeof(g_ePlayerData[]));
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

	if(g_ePlayerData[activator][REVIVE_COUNT] >= g_eCvars[MAX_REVIVES])
	{
		client_print_color(activator, print_team_red, "%L %L", activator, "RT_CHAT_TAG", activator, "RT_REVIVE_COUNT");
		return PLUGIN_HANDLED;
	}

	if(get_member(id, m_iNumSpawns) > g_eCvars[MAX_SPAWNS])
	{
		client_print_color(activator, print_team_red, "%L %L", activator, "RT_CHAT_TAG", activator, "RT_MAX_SPAWNS");
		return PLUGIN_HANDLED;
	}

	if(g_eCvars[BOMB] && rg_is_bomb_planted())
	{
		client_print_color(activator, print_team_red, "%L %L", activator, "RT_CHAT_TAG", activator, "RT_BOMB");
		return PLUGIN_HANDLED;
	}

	if(g_eCvars[DUEL] && rg_users_1vs1())
	{
		client_print_color(activator, print_team_red, "%L %L", activator, "RT_CHAT_TAG", activator, "RT_DUEL");
		return PLUGIN_HANDLED;
	}

	if(g_eCvars[NO_FIRE])
	{
		set_member(activator, m_bIsDefusing, true);
	}

	return PLUGIN_CONTINUE;
}

public rt_revive_cancelled(const id, const activator, const modes_struct:mode)
{
	if(g_eCvars[NO_FIRE])
	{
		set_member(activator, m_bIsDefusing, false);
	}
}

public rt_revive_end(const id, const activator, const modes_struct:mode)
{
	if(mode == MODE_REVIVE)
	{
		g_ePlayerData[activator][REVIVE_COUNT]++;
	}

	if(g_eCvars[NO_FIRE])
	{
		set_member(activator, m_bIsDefusing, false);
	}
}

stock bool:rg_users_1vs1()
{
	new iAliveTs, iAliveCTs;
	rg_initialize_player_counts(iAliveTs, iAliveCTs);

	return bool:(iAliveTs == 1 && iAliveCTs == 1);
}