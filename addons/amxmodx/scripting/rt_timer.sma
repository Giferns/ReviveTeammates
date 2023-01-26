#include <amxmodx>
#include <reapi>
#include <rt_api>

enum CVARS
{
	TIMER_TYPE
};

new g_eCvars[CVARS];

enum TimeData
{
	Float:GLOBAL_TIME,
	CEIL_TIME,
	START_TIME,
};

new g_eTimeData[TimeData];

new const TIMER_BEGIN[]			= "[ | ";
new const TIMER_ADD[]			= "- ";
new const TIMER_END[]			= "]";
new const TIMER_REPLACE_SYMB[]	= "| -";
new const TIMER_REPLACE_WITH[]	= "| |";

new g_iHudSyncObj;

new g_szTimer[MAX_PLAYERS + 1][64];

public plugin_precache()
{
	RegisterCvars();
	UploadConfigs();
}

public plugin_init()
{
	register_plugin("Revive Teammates: Timer", VERSION, AUTHORS);

	register_dictionary("rt_library.txt");
	
	if(g_eCvars[TIMER_TYPE] == 0)
		g_iHudSyncObj = CreateHudSyncObj();

	g_eTimeData[GLOBAL_TIME] = get_pcvar_float(get_cvar_pointer("rt_revive_time"));
	g_eTimeData[CEIL_TIME] = floatround(g_eTimeData[GLOBAL_TIME], floatround_ceil);
	g_eTimeData[START_TIME] = floatround((1.0 - g_eTimeData[GLOBAL_TIME] / g_eTimeData[CEIL_TIME]) * 100);
}

public rt_revive_start(const iEnt, const id, const iActivator, const modes_struct:eMode)
{
	switch(g_eCvars[TIMER_TYPE])
	{
		case 0:
		{
			formatex(g_szTimer[id], charsmax(g_szTimer[]), TIMER_BEGIN);

			for(new i; i < floatround(g_eTimeData[GLOBAL_TIME]); i++)
				add(g_szTimer[id], charsmax(g_szTimer[]), TIMER_ADD);

			add(g_szTimer[id], charsmax(g_szTimer[]), TIMER_END);

			DisplayHUDMessage(iActivator, id, eMode);
		}
		case 1:
		{
			rg_send_bartime2(iActivator, g_eTimeData[CEIL_TIME], g_eTimeData[START_TIME]);

			if(eMode == MODE_REVIVE && is_user_connected(id))
				rg_send_bartime2(id, g_eTimeData[CEIL_TIME], g_eTimeData[START_TIME]);
		}
	}
}

public rt_revive_loop_post(const iEnt, const id, const iActivator, const Float:timer, modes_struct:eMode)
{
	if(g_eCvars[TIMER_TYPE] == 0)
	{
		replace(g_szTimer[id], charsmax(g_szTimer[]), TIMER_REPLACE_SYMB, TIMER_REPLACE_WITH);

		DisplayHUDMessage(iActivator, id, eMode);
	}
}

public rt_revive_cancelled(const iEnt, const id, const iActivator, const modes_struct:eMode)
{
	switch(g_eCvars[TIMER_TYPE])
	{
		case 0:
		{
			if(iActivator != NULLENT)
				ClearSyncHud(iActivator, g_iHudSyncObj);
		}
		case 1:
		{
			if(iActivator != NULLENT)
				rg_send_bartime(iActivator, 0);
			
			if(eMode == MODE_REVIVE && id != NULLENT)
				rg_send_bartime(id, 0);
		}
	}
}

stock DisplayHUDMessage(id, dead, const modes_struct:eMode)
{
	switch(eMode)
	{
		case MODE_REVIVE: set_hudmessage(0, 255, 0, -1.0, 0.61, .holdtime = g_eTimeData[GLOBAL_TIME]);
		case MODE_PLANT: set_hudmessage(255, 0, 0, -1.0, 0.61, .holdtime = g_eTimeData[GLOBAL_TIME]);
	}
	
	ShowSyncHudMsg(id, g_iHudSyncObj, g_szTimer[dead]);
}

public RegisterCvars()
{
	bind_pcvar_num(create_cvar(
		"rt_timer_type",
		"1",
		FCVAR_NONE,
		"0 - HUD, 1 - bartime(orange line)",
		true,
		0.0,
		true,
		1.0),
		g_eCvars[TIMER_TYPE]
	);
}