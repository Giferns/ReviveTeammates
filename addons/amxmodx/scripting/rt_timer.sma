#include <amxmodx>
#include <rt_api>

enum CVARS
{
	TIMER_TYPE
};

new g_eCvars[CVARS];

new const TIMER_BEGIN[]			= "[ | ";
new const TIMER_ADD[]			= "- ";
new const TIMER_END[]			= "]";
new const TIMER_REPLACE_SYMB[]	= "| -";
new const TIMER_REPLACE_WITH[]	= "| |";

new g_iHudSyncObj;

new g_szTimer[MAX_PLAYERS + 1][64];
new Float:g_fTime;

public plugin_init()
{
	register_plugin("Revive Teammates: Timer", VERSION, AUTHORS);

	register_dictionary("rt_library.txt");

	bind_pcvar_num(create_cvar("rt_timer_type", "1", FCVAR_NONE, "0 - HUD, 1 - bartime(orange line)", true, 0.0), g_eCvars[TIMER_TYPE]);
	
	if(g_eCvars[TIMER_TYPE] == 0)
	{
		g_iHudSyncObj = CreateHudSyncObj();
	}
}

public plugin_cfg()
{
	UTIL_UploadConfigs();

	g_fTime = get_pcvar_float(get_cvar_pointer("rt_revive_time"));
}

public rt_revive_start(const id, const activator, const modes_struct:mode)
{
	switch(g_eCvars[TIMER_TYPE])
	{
		case 0:
		{
			formatex(g_szTimer[id], charsmax(g_szTimer[]), TIMER_BEGIN);

			for(new i; i < floatround(g_fTime); i++)
			{
				add(g_szTimer[id], charsmax(g_szTimer[]), TIMER_ADD);
			}

			add(g_szTimer[id], charsmax(g_szTimer[]), TIMER_END);

			DisplayHUDMessage(activator, id, mode);
		}
		case 1:
		{
			rg_send_bartime(activator, floatround(g_fTime));
		}
	}
}

public rt_revive_loop_post(const id, const activator, const Float:timer, modes_struct:mode)
{
	if(g_eCvars[TIMER_TYPE] == 0)
	{
		replace(g_szTimer[id], charsmax(g_szTimer[]), TIMER_REPLACE_SYMB, TIMER_REPLACE_WITH);

		DisplayHUDMessage(activator, id, mode);
	}
}

public rt_revive_cancelled(const id, const activator, const modes_struct:mode)
{
	switch(g_eCvars[TIMER_TYPE])
	{
		case 0:
		{
			ClearSyncHud(activator, g_iHudSyncObj);
		}
		case 1:
		{
			rg_send_bartime(activator, 0);
		}
	}
}

stock DisplayHUDMessage(id, dead, const modes_struct:mode)
{
	switch(mode)
	{
		case MODE_REVIVE:
		{
			set_hudmessage(0, 255, 0, -1.0, 0.61, .holdtime = g_fTime);
		}
		case MODE_PLANT:
		{
			set_hudmessage(255, 0, 0, -1.0, 0.61, .holdtime = g_fTime);
		}
	}
	
	ShowSyncHudMsg(id, g_iHudSyncObj, g_szTimer[dead]);
}
