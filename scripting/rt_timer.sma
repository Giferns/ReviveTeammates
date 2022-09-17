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

new g_iTime;

public plugin_init()
{
	register_plugin("Revive Teammates: Timer", VERSION, AUTHORS);

	register_dictionary("rt_library.txt");

	bind_pcvar_num(create_cvar("rt_timer_type", "2", FCVAR_NONE, "0 - chat, 1 - HUD, 2 - bartime(strip)", true, 0.0), g_eCvars[TIMER_TYPE]);
	
	g_iTime = get_pcvar_num(get_cvar_pointer("rt_revive_time"));
	
	if(g_eCvars[TIMER_TYPE] == 1)
	{
		g_iHudSyncObj = CreateHudSyncObj();
	}
}

public plugin_cfg()
{
	UTIL_UploadConfigs();
}

public rt_revive_start(const id, const activator, const modes_struct:mode)
{
	new modes_struct:iMode = get_entvar(id, var_euser1);
	
	if(iMode != MODE_PLANT)
	{
		switch(g_eCvars[TIMER_TYPE])
		{
			case 0:
			{
				if(mode == MODE_REVIVE)
				{
					client_print_color(activator, print_team_blue, "%L %L", activator, "RT_CHAT_TAG", activator, "RT_TIMER_REVIVE", id);
				}
				else if(mode == MODE_PLANT)
				{
					client_print_color(activator, print_team_blue, "%L %L", activator, "RT_CHAT_TAG", activator, "RT_TIMER_PLANT", id);
				}
			}
			case 1:
			{
				formatex(g_szTimer[id], charsmax(g_szTimer[]), TIMER_BEGIN);

				for(new i; i < g_iTime; i++)
				{
					add(g_szTimer[id], charsmax(g_szTimer[]), TIMER_ADD);
				}

				add(g_szTimer[id], charsmax(g_szTimer[]), TIMER_END);

				display_timer(activator, id, .holdtime = 1.0);
			}
			case 2:
			{
				rg_send_bartime(activator, g_iTime);
			}
		}
	}
}

public rt_revive_loop_post(const id, const activator, const Float:timer, Float:nextthink)
{
	if(g_eCvars[TIMER_TYPE] == 1)
	{
		replace(g_szTimer[id], charsmax(g_szTimer[]), TIMER_REPLACE_SYMB, TIMER_REPLACE_WITH);

		display_timer(activator, id, nextthink);
	}
}

public rt_revive_cancelled(const id, const activator, const modes_struct:mode)
{
	switch(g_eCvars[TIMER_TYPE])
	{
		case 0:
		{
			if(mode == MODE_REVIVE)
			{
				client_print_color(activator, print_team_blue, "%L %L", activator, "RT_CHAT_TAG", activator, "RT_CANCELLED_REVIVE", id);
			}
			else if(mode == MODE_PLANT)
			{
				client_print_color(activator, print_team_blue, "%L %L", activator, "RT_CHAT_TAG", activator, "RT_CANCELLED_PLANT", id);
			}
		}
		case 1:
		{
			ClearSyncHud(activator, g_iHudSyncObj);
		}
		case 2:
		{
			rg_send_bartime(activator, 0);
		}
	}
}

stock display_timer(id, dead, Float:holdtime)
{
	if(g_eCvars[TIMER_TYPE] == 1)
	{
		set_hudmessage(55, 155, 55, -1.0, 0.61, .holdtime = holdtime);
		ShowSyncHudMsg(id, g_iHudSyncObj, g_szTimer[dead]);
	}
}