#include <amxmodx>
#include <reapi>
#include <rt_api>

public stock const PLUGIN[] = "Revive Teammates: Restrictions";
public stock const CFG_FILE[] = "addons/amxmodx/configs/rt_configs/rt_restrictions.cfg";

#define m_iCurrentRound (get_member_game(m_iTotalRoundsPlayed) + 1)

enum CVARS {
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

enum _:PlayerData {
	REVIVE_COUNT
};

const PREVENT_FLAGS = (PLAYER_PREVENT_CLIMB|PLAYER_PREVENT_JUMP);

new g_ePlayerData[MAX_PLAYERS + 1][PlayerData];

new g_iAccessFlags;

public plugin_precache() {
	CreateCvars();

	server_cmd("exec %s", CFG_FILE);
	server_exec();
}

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHORS);

	register_dictionary("rt_library.txt");

	RegisterHookChain(RG_CSGameRules_CleanUpMap, "CSGameRules_CleanUpMap_Post", true);
}

public plugin_cfg() {
	g_iAccessFlags = read_flags(g_eCvars[ACCESS]);

	if(g_eCvars[NO_MOVE] == 1)
		RegisterHookChain(RG_CBasePlayer_PreThink, "CBasePlayer_PreThink_Pre");
}

public CSGameRules_CleanUpMap_Post() {
	arrayset(g_ePlayerData[0][_:0], 0, sizeof(g_ePlayerData) * sizeof(g_ePlayerData[]));
}

public client_disconnected(iPlayer) {
	g_ePlayerData[iPlayer][REVIVE_COUNT] = 0;
}

public CBasePlayer_PreThink_Pre(const iPlayer) {
	if(is_user_alive(iPlayer) && (get_entvar(iPlayer, var_iuser3) & PREVENT_FLAGS))
		set_entvar(iPlayer, var_maxspeed, 1.0);
}

public rt_revive_start(const iEnt, const iPlayer, const iActivator, const Modes:eMode) {
	if(~get_user_flags(iActivator) & g_iAccessFlags) {
		NotifyClient(iActivator, print_team_red, "RT_NO_ACCESS");
		return PLUGIN_HANDLED;
	}

	if(m_iCurrentRound < g_eCvars[MIN_ROUND]) {
		NotifyClient(iActivator, print_team_red, "RT_MIN_ROUND", g_eCvars[MIN_ROUND]);
		return PLUGIN_HANDLED;
	}

	if(g_eCvars[BOMB] && rg_is_bomb_planted()) {
		NotifyClient(iActivator, print_team_red, "RT_BOMB");
		return PLUGIN_HANDLED;
	}

	if(g_eCvars[DUEL] && rg_users_count(false)) {
		NotifyClient(iActivator, print_team_red, "RT_DUEL");
		return PLUGIN_HANDLED;
	}

	if(g_eCvars[SURVIVOR] && rg_users_count(true)) {
		NotifyClient(iActivator, print_team_red, "RT_SURVIVOR");
		return PLUGIN_HANDLED;
	}

	if(g_eCvars[REMAINING_TIME] && rg_get_remaining_time() <= g_eCvars[REMAINING_TIME]) {
		NotifyClient(iActivator, print_team_red, "RT_REMAINING_TIME");
		return PLUGIN_HANDLED;
	}

	if(g_eCvars[WIN_DIFF] && (rg_get_team_wins_row(g_eCvars[WIN_DIFF]) == TeamName:get_member(iActivator, m_iTeam))) {
		NotifyClient(iActivator, print_team_red, "RT_WINS_DOMINATION");
		return PLUGIN_HANDLED;
	}

	switch(eMode) {
		case MODE_REVIVE: {
			if(g_ePlayerData[iActivator][REVIVE_COUNT] >= g_eCvars[MAX_REVIVES]) {
				NotifyClient(iActivator, print_team_red, "RT_REVIVE_COUNT");
				return PLUGIN_HANDLED;
			}

			if(get_member(iPlayer, m_iNumSpawns) > g_eCvars[MAX_SPAWNS]) {
				NotifyClient(iActivator, print_team_red, "RT_MAX_SPAWNS");
				return PLUGIN_HANDLED;
			}

			if(get_member(iActivator, m_iAccount) < g_eCvars[REVIVE_COST]) {
				NotifyClient(iActivator, print_team_red, "RT_NO_MONEY");
				return PLUGIN_HANDLED;
			}
		}
		case MODE_PLANT: {
			if(get_member(iActivator, m_iAccount) < g_eCvars[PLANTING_COST]) {
				NotifyClient(iActivator, print_team_red, "RT_NO_MONEY");
				return PLUGIN_HANDLED;
			}
		}
	}

	if(g_eCvars[NO_MOVE] == 1) {
		set_entvar(iActivator, var_iuser3, get_entvar(iActivator, var_iuser3) | PREVENT_FLAGS);
		set_entvar(iActivator, var_velocity, NULL_VECTOR);
		set_entvar(iActivator, var_maxspeed, 1.0);
	}

	if(g_eCvars[NO_FIRE])
		set_member(iActivator, m_bIsDefusing, true);

	return PLUGIN_CONTINUE;
}

public rt_revive_loop_pre(const iEnt, const iPlayer, const iActivator, const Float:fTimer, Modes:eMode) {
	if(g_eCvars[BOMB] && rg_is_bomb_planted()) {
		NotifyClient(iActivator, print_team_red, "RT_BOMB");
		return PLUGIN_HANDLED;
	}

	if(g_eCvars[DUEL] && rg_users_count(false)) {
		NotifyClient(iActivator, print_team_red, "RT_DUEL");
		return PLUGIN_HANDLED;
	}

	if(g_eCvars[SURVIVOR] && rg_users_count(true)) {
		NotifyClient(iActivator, print_team_red, "RT_SURVIVOR");
		return PLUGIN_HANDLED;
	}

	if(g_eCvars[REMAINING_TIME] && rg_get_remaining_time() <= g_eCvars[REMAINING_TIME]) {
		NotifyClient(iActivator, print_team_red, "RT_REMAINING_TIME");
		return PLUGIN_HANDLED;
	}

	if(g_eCvars[NO_MOVE] == 2) {
		new Float:fVecPlOrigin[3], Float:fVecEntOrigin[3];
		get_entvar(iActivator, var_origin, fVecPlOrigin);
		get_entvar(iEnt, var_vuser4, fVecEntOrigin);

		if(vector_distance(fVecPlOrigin, fVecEntOrigin) > Float:get_entvar(iEnt, var_fuser2)) {
			NotifyClient(iActivator, print_team_red, "RT_MAX_DISTANCE");
			return PLUGIN_HANDLED;
		}
	}

	return PLUGIN_CONTINUE;
}

public rt_revive_loop_post(const iEnt, const iPlayer, const iActivator, const Float:fTimer, Modes:eMode) {
	if(g_eCvars[FORCE_FWD_MODE] && g_eCvars[NO_MOVE] == 1)
		set_entvar(iActivator, var_maxspeed, 1.0);
}

public rt_revive_cancelled(const iEnt, const iPlayer, const iActivator, const Modes:eMode) {
	if(iActivator == RT_NULLENT)
		return;

	if(g_eCvars[NO_MOVE] == 1) {
		set_entvar(iActivator, var_iuser3, get_entvar(iActivator, var_iuser3) & ~PREVENT_FLAGS);
		rg_reset_maxspeed(iActivator);
	}

	if(g_eCvars[NO_FIRE])
		set_member(iActivator, m_bIsDefusing, false);
}

public rt_revive_end(const iEnt, const iPlayer, const iActivator, const Modes:eMode) {
	switch(eMode) {
		case MODE_REVIVE: {
			new Modes:iMode = Modes:get_entvar(iEnt, var_iuser3);

			if(iMode != MODE_PLANT) {
				g_ePlayerData[iActivator][REVIVE_COUNT]++;

				rg_add_account(iActivator, -g_eCvars[REVIVE_COST]);
			}
		}
		case MODE_PLANT: { rg_add_account(iActivator, -g_eCvars[PLANTING_COST]); }
	}

	if(g_eCvars[NO_MOVE] == 1) {
		set_entvar(iActivator, var_iuser3, get_entvar(iActivator, var_iuser3) & ~PREVENT_FLAGS);
		rg_reset_maxspeed(iActivator);
	}

	if(g_eCvars[NO_FIRE])
		set_member(iActivator, m_bIsDefusing, false);
}

stock rg_users_count(const bool:bMode1x1 = false) {
	new iAliveTs, iAliveCTs;
	rg_initialize_player_counts(iAliveTs, iAliveCTs);

	if(!bMode1x1 && (iAliveTs == 1 && iAliveCTs == 1))
		return 1;

	if(bMode1x1 && (iAliveTs == 1 || iAliveCTs == 1))
		return 1;

	return 0;
}

stock Float:rg_get_remaining_time() {
	return (float(get_member_game(m_iRoundTimeSecs)) - get_gametime() + Float:get_member_game(m_fRoundStartTimeReal));
}

stock TeamName:rg_get_team_wins_row(const iWins) {
	if(get_member_game(m_iNumConsecutiveCTLoses) >= iWins)
		return TEAM_TERRORIST;

	if(get_member_game(m_iNumConsecutiveTerroristLoses) >= iWins)
		return TEAM_CT;

	return TEAM_UNASSIGNED;
}

public CreateCvars() {
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
		bind_pcvar_num(pCvar, g_eCvars[FORCE_FWD_MODE]);
}