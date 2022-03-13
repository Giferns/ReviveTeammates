#include <amxmodx>
#include <revive_teammates>

public stock const PluginName[]     = "Revive teammates: Hud";
public stock const PluginVersion[]  = "0.0.1";
public stock const PluginAuthor[]   = "m4ts";
public stock const PluginURL[]      = "https://github.com/ma4ts";

new const TIMER_BEGIN[]				= "[ | ";
new const TIMER_ADD[]				= "- ";
new const TIMER_END[]				= "]";
new const TIMER_REPLACE_SYMB[]		= "| -";
new const TIMER_REPLACE_WITH[]		= "| |";

new g_iHudSyncObj;
new g_szTimer[64];

public rt_on_revive_start(const id, const activator)	{
	new pCvar = get_cvar_pointer("rt_revive_time");
	new iTime = get_pcvar_num(pCvar);

	formatex(g_szTimer, charsmax(g_szTimer), TIMER_BEGIN);

	for (new i; i < iTime; i++)	{
		add(g_szTimer, charsmax(g_szTimer), TIMER_ADD);
	}

	add(g_szTimer, charsmax(g_szTimer), TIMER_END);

	display_timer(activator, .holdtime = 1.0);
}

public rt_revive_loop_post(const id, const activator, const Float: timer, &Float: nextthink)    {
	replace(g_szTimer, charsmax(g_szTimer), TIMER_REPLACE_SYMB, TIMER_REPLACE_WITH);

	display_timer(activator, nextthink);
}

stock display_timer(id, Float: holdtime)	{
	set_hudmessage(55, 155, 55, -1.0, 0.61, .holdtime = holdtime);
	ShowSyncHudMsg(id, g_iHudSyncObj, g_szTimer);
}

public plugin_init()    {
	register_plugin(PluginName, PluginVersion, PluginAuthor);

	g_iHudSyncObj = CreateHudSyncObj();
}