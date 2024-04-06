#include <amxmodx>
#include <reapi>
#include <rt_api>

public stock const PLUGIN[] = "Revive Teammates: Timer";
public stock const CFG_FILE[] = "addons/amxmodx/configs/rt_configs/rt_timer.cfg";

enum CVARS {
	TIMER_TYPE,
	REVIVE_COLORS[MAX_COLORS_LENGTH],
	REVIVE_COORDS[MAX_COORDS_LENGTH],
	PLANTING_COLORS[MAX_COLORS_LENGTH],
	PLANTING_COORDS[MAX_COORDS_LENGTH]
};

new g_eCvars[CVARS];

enum HudData {
	COLOR_R,
	COLOR_G,
	COLOR_B,
	Float:COORD_X,
	Float:COORD_Y
};

new g_eHudData[Modes][HudData];

enum TimeData {
	Float:GLOBAL_TIME,
	CEIL_TIME,
	Float:START_TIME,
};

new g_eTimeData[TimeData];

new const TIMER_BEGIN[]			= "[ | ";
new const TIMER_ADD[]			= "- ";
new const TIMER_END[]			= "]";
new const TIMER_REPLACE_SYMB[]	= "| -";
new const TIMER_REPLACE_WITH[]	= "| |";

new g_szTimer[MAX_PLAYERS + 1][64];

new g_iHudSyncObj;

public plugin_precache() {
	CreateCvars();
	
	server_cmd("exec %s", CFG_FILE);
	server_exec();

	new szHudColors[3][4];

	if(parse(g_eCvars[REVIVE_COLORS], szHudColors[0], charsmax(szHudColors[]),
	szHudColors[1], charsmax(szHudColors[]), szHudColors[2], charsmax(szHudColors[])) == 3) {
		g_eHudData[MODE_REVIVE][COLOR_R] = str_to_num(szHudColors[0]);
		g_eHudData[MODE_REVIVE][COLOR_G] = str_to_num(szHudColors[1]);
		g_eHudData[MODE_REVIVE][COLOR_B] = str_to_num(szHudColors[2]);
	}

	if(parse(g_eCvars[PLANTING_COLORS], szHudColors[0], charsmax(szHudColors[]),
	szHudColors[1], charsmax(szHudColors[]), szHudColors[2], charsmax(szHudColors[])) == 3) {
		g_eHudData[MODE_PLANT][COLOR_R] = str_to_num(szHudColors[0]);
		g_eHudData[MODE_PLANT][COLOR_G] = str_to_num(szHudColors[1]);
		g_eHudData[MODE_PLANT][COLOR_B] = str_to_num(szHudColors[2]);
	}

	new szHudCoords[2][8];

	if(parse(g_eCvars[REVIVE_COORDS], szHudCoords[0], charsmax(szHudCoords[]), szHudCoords[1], charsmax(szHudCoords[])) == 2) {
		g_eHudData[MODE_REVIVE][COORD_X] = str_to_float(szHudCoords[0]);
		g_eHudData[MODE_REVIVE][COORD_Y] = str_to_float(szHudCoords[1]);
	}

	if(parse(g_eCvars[PLANTING_COORDS], szHudCoords[0], charsmax(szHudCoords[]), szHudCoords[1], charsmax(szHudCoords[])) == 2) {
		g_eHudData[MODE_PLANT][COORD_X] = str_to_float(szHudCoords[0]);
		g_eHudData[MODE_PLANT][COORD_Y] = str_to_float(szHudCoords[1]);
	}
}

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHORS);

	register_dictionary("rt_library.txt");
	
	if(!g_eCvars[TIMER_TYPE])
		g_iHudSyncObj = CreateHudSyncObj();

	g_eTimeData[GLOBAL_TIME] = get_pcvar_float(get_cvar_pointer("rt_revive_time"));
	g_eTimeData[CEIL_TIME] = floatround(g_eTimeData[GLOBAL_TIME], floatround_ceil);
	g_eTimeData[START_TIME] = (1.0 - g_eTimeData[GLOBAL_TIME] / float(g_eTimeData[CEIL_TIME])) * 100.0;
}

public rt_revive_start(const iEnt, const id, const iActivator, const Modes:eMode) {
	switch(g_eCvars[TIMER_TYPE]) {
		case 0: {
			formatex(g_szTimer[id], charsmax(g_szTimer[]), TIMER_BEGIN);

			for(new i; i < floatround(g_eTimeData[GLOBAL_TIME]); i++)
				add(g_szTimer[id], charsmax(g_szTimer[]), TIMER_ADD);

			add(g_szTimer[id], charsmax(g_szTimer[]), TIMER_END);

			DisplayHUDMessage(iActivator, id, eMode);
		}
		case 1: {
			rg_send_bartime2(iActivator, g_eTimeData[CEIL_TIME], g_eTimeData[START_TIME]);

			if(eMode == MODE_REVIVE && is_user_connected(id))
				rg_send_bartime2(id, g_eTimeData[CEIL_TIME], g_eTimeData[START_TIME]);
		}
	}
}

public rt_revive_loop_post(const iEnt, const id, const iActivator, const Float:timer, Modes:eMode) {
	if(!g_eCvars[TIMER_TYPE]) {
		replace(g_szTimer[id], charsmax(g_szTimer[]), TIMER_REPLACE_SYMB, TIMER_REPLACE_WITH);

		DisplayHUDMessage(iActivator, id, eMode);
	}
}

public rt_revive_cancelled(const iEnt, const id, const iActivator, const Modes:eMode) {
	switch(g_eCvars[TIMER_TYPE]) {
		case 0: {
			if(iActivator != RT_NULLENT)
				ClearSyncHud(iActivator, g_iHudSyncObj);
		}
		case 1: {
			if(iActivator != RT_NULLENT)
				rg_send_bartime(iActivator, 0);
			
			if(eMode == MODE_REVIVE && id != RT_NULLENT)
				rg_send_bartime(id, 0);
		}
	}
}

stock DisplayHUDMessage(const id, const dead, const Modes:eMode) {
	set_hudmessage(g_eHudData[eMode][COLOR_R], g_eHudData[eMode][COLOR_G], g_eHudData[eMode][COLOR_B],
	g_eHudData[eMode][COORD_X], g_eHudData[eMode][COORD_Y], .holdtime = g_eTimeData[GLOBAL_TIME]);
	ShowSyncHudMsg(id, g_iHudSyncObj, g_szTimer[dead]);
}

public CreateCvars() {
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
	bind_pcvar_string(create_cvar(
		"rt_revive_hud_colors",
		"0 255 0",
		FCVAR_NONE,
		"HUD's colors at resurrection"),
		g_eCvars[REVIVE_COLORS],
		charsmax(g_eCvars[REVIVE_COLORS])
	);
	bind_pcvar_string(create_cvar(
		"rt_revive_hud_coords",
		"-1.0 0.6",
		FCVAR_NONE,
		"HUD's coordinates at resurrection"),
		g_eCvars[REVIVE_COORDS],
		charsmax(g_eCvars[REVIVE_COORDS])
	);
	bind_pcvar_string(create_cvar(
		"rt_planting_hud_colors",
		"255 0 0",
		FCVAR_NONE,
		"HUD's colors at planting"),
		g_eCvars[PLANTING_COLORS],
		charsmax(g_eCvars[PLANTING_COLORS])
	);
	bind_pcvar_string(create_cvar(
		"rt_planting_hud_coords",
		"-1.0 0.6",
		FCVAR_NONE,
		"HUD's coordinates at planting"),
		g_eCvars[PLANTING_COORDS],
		charsmax(g_eCvars[PLANTING_COORDS])
	);
}