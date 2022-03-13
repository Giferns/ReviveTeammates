#pragma semicolon 1

#include <amxmodx>
#include <reapi>

#include <revive_teammates>

public stock const PluginName[]     = "Revive teammates: Restriction";
public stock const PluginVersion[]  = "0.0.1";
public stock const PluginAuthor[]   = "m4ts";
public stock const PluginURL[]      = "https://github.com/ma4ts";

#define AUTO_CREATE_CONFIG // Auto create config file in `configs/plugins` folder
const BLINK_COUNT					= 3;
const DEFAULT_USE_DISTANCE			= 64;

enum cvars_struct	{
	Cvar__ReviveAccess, // Access flag to revive teammate's (see amxconst.inc)
	Float: Cvar__AccessTime, // Access to the teammate's revival after the start of the round in seconds
	Cvar__ReviveCost, // How much does it cost to revive a teammate? (U can set 0 or blank)
	Cvar__MaxRoundRevives, // How many times per round can one team revive
	Cvar__MaxPlayerRevives,	// How many times per round can one player be revived
	Cvar__MaxPlayerCanRevives, // How many times per round can one player revive
	bool: Cvar__ActivatorCanShoot
};
new g_eCvars[cvars_struct];

new g_iRevives[TeamName]; // How many times per round can one team revive

new g_iPlayerRevives[MAX_PLAYERS + 1]; // How many times per round can one player revive

new g_msgBlinkAcct;

//Resetting all counters every round and when player has been disconnected
public CSGameRules_RestartRound_Post()	{
	for (new id = 1; id <= MaxClients; id++)	{
		if (!is_user_connected(id))
			continue;

		g_iPlayerRevives[id] = 0;
	}

	g_iRevives[TEAM_CT] = 0;
	g_iRevives[TEAM_TERRORIST] = 0;
}
public client_disconnected(id)	{
	g_iPlayerRevives[id] = 0;
}

public rt_revive_start(const id, const activator)    {
	if (g_eCvars[Cvar__ReviveAccess] != -1 && ~get_user_flags(activator) & g_eCvars[Cvar__ReviveAccess])	{
		client_print(0, print_center, "No have access (%n)", activator);

		return PLUGIN_HANDLED;
	}

	if (g_eCvars[Cvar__AccessTime] && (get_gametime() - get_member_game(m_fRoundStartTime) < g_eCvars[Cvar__AccessTime]))	{
		client_print(0, print_center, "Round time %.1f - %1.f", get_gametime(), get_member_game(m_fRoundStartTime));

		return PLUGIN_HANDLED;
	}

	if (g_eCvars[Cvar__MaxRoundRevives] && g_iRevives[get_member(id, m_iTeam)] > g_eCvars[Cvar__MaxRoundRevives])	{
		client_print(0, print_center, "Max revives in round for u team (%n)", activator);

		return PLUGIN_HANDLED;
	}

	if (g_eCvars[Cvar__MaxPlayerCanRevives] && g_iPlayerRevives[activator] > g_eCvars[Cvar__MaxPlayerCanRevives])	{
		client_print(0, print_center, "You revived max teammates (%n)", activator);

		return PLUGIN_HANDLED;
	}

	if (g_eCvars[Cvar__MaxPlayerRevives] && get_member(id, m_iNumSpawns) > g_eCvars[Cvar__MaxPlayerRevives])	{
		client_print(0, print_center, "Can't revive this player (%n)", activator);

		return PLUGIN_HANDLED;
	}

	if (g_eCvars[Cvar__ReviveCost] && get_member(activator, m_iAccount) < g_eCvars[Cvar__ReviveCost])	{
		message_begin(MSG_ONE, g_msgBlinkAcct, _, activator);
		write_byte(BLINK_COUNT);
		message_end();

		return PLUGIN_HANDLED;
	}

	if (!g_eCvars[Cvar__ActivatorCanShoot] && get_member(activator, m_bCanShoot))	{
		set_member(activator, m_bCanShoot, false);
	}

	return PLUGIN_CONTINUE;
}

public rt_revive_loop_pre(const id, const activator)	{
	enum origin_struct	{
		origin_id,
		origin_activator
	};
	new Float: flOrigin[origin_struct][3];

	get_entvar(id, var_origin, flOrigin[origin_id]);
	get_entvar(activator, var_origin, flOrigin[origin_activator]);

	if (get_distance_f(flOrigin[origin_id], flOrigin[origin_activator]) > DEFAULT_USE_DISTANCE)	{
		client_print(0, print_center, "Daleko blyat");

		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public rt_revive_end(const id, const activator, bool: success)	{
	if (!get_member(activator, m_bCanShoot))
		set_member(activator, m_bCanShoot, true);

	if (!success)
		return;

	g_iPlayerRevives[activator]++;
	g_iRevives[get_member(id, m_iTeam)]++;

	if (g_eCvars[Cvar__ReviveCost])
		rg_add_account(activator, -g_eCvars[Cvar__ReviveCost]);
}

new g_szTemp[4];
public plugin_init()    {
	register_plugin(PluginName, PluginVersion, PluginAuthor);

	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Post", 1);

	g_msgBlinkAcct = get_user_msgid("BlinkAcct");

	new pCvar;

	pCvar = create_cvar(
		"rt_revive_access_flag",
		"",
		_, // FCVAR_NONE
		"Access flag(s) to revive teammate's (see amxconst.inc)^n@note You can leave an empty value for all players"
	);

	bind_pcvar_string(pCvar, g_szTemp, charsmax(g_szTemp));
	g_eCvars[Cvar__ReviveAccess] = (g_szTemp[0] || g_szTemp[0] != '0') ? read_flags(g_szTemp) : -1;

	pCvar = create_cvar(
		"rt_access_time",
		"0.0",
		_, // FCVAR_NONE
		"Access to the teammate's revival after the start of the round in seconds"
	);
	bind_pcvar_float(pCvar, g_eCvars[Cvar__AccessTime]);

	pCvar = create_cvar(
		"rt_revive_cost",
		"700",
		_, // FCVAR_NONE
		"How much does it cost to revive a teammate? (U can set 0 for no restriction)",
		true, 0.0,
		true, get_cvar_float("mp_maxmoney")
	);
	bind_pcvar_num(pCvar, g_eCvars[Cvar__ReviveCost]);

	pCvar = create_cvar(
		"rt_max_round_revives",
		"5",
		_, // FCVAR_NONE
		"How many times per round can one team revive"
	);
	bind_pcvar_num(pCvar, g_eCvars[Cvar__MaxRoundRevives]);

	pCvar = create_cvar(
		"rt_max_player_revives",
		"1",
		_, // FCVAR_NONE
		"How many times per round can one player be revived"
	);
	bind_pcvar_num(pCvar, g_eCvars[Cvar__MaxPlayerRevives]);

	pCvar = create_cvar(
		"rt_max_player_can_revive",
		"3",
		_, // FCVAR_NONE
		"How many times per round can one player revive"
	);
	bind_pcvar_num(pCvar, g_eCvars[Cvar__MaxPlayerCanRevives]);

	pCvar = create_cvar(
		"rt_activator_can_shoot",
		"0",
		_, // FCVAR_NONE
		"Can shoot's activators"
	);
	bind_pcvar_num(pCvar, g_eCvars[Cvar__ActivatorCanShoot]);

	#if defined AUTO_CREATE_CONFIG
		AutoExecConfig(true, "rt_restrictions");
	#endif
}