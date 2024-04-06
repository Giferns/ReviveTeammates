#include <amxmodx>
#include <fakemeta>
#include <reapi>
#include <rt_api>

public stock const PLUGIN[] = "Revive Teammates: Effects";
public stock const CFG_FILE[] = "addons/amxmodx/configs/rt_configs/rt_effects.cfg";

new const CORPSE_SPRITE_CLASSNAME[] = "rt_corpse_sprite";

enum CVARS {
	SPECTATOR,
	NOTIFY_DHUD,
	REVIVE_COLORS[MAX_COLORS_LENGTH],
	REVIVE_COORDS[MAX_COORDS_LENGTH],
	PLANTING_COLORS[MAX_COLORS_LENGTH],
	PLANTING_COORDS[MAX_COORDS_LENGTH],
	CORPSE_SPRITE[MAX_RESOURCE_PATH_LENGTH],
	Float:SPRITE_SCALE
};

new g_eCvars[CVARS];

enum DHudData {
	COLOR_R,
	COLOR_G,
	COLOR_B,
	Float:COORD_X,
	Float:COORD_Y
};

new g_eDHudData[Modes][DHudData];

new Float:g_fTime;

public plugin_precache() {
	CreateCvars();
	
	server_cmd("exec %s", CFG_FILE);
	server_exec();

	if(g_eCvars[CORPSE_SPRITE][0] != EOS)
		precache_model(g_eCvars[CORPSE_SPRITE]);

	new szHudColors[3][4];

	if(parse(g_eCvars[REVIVE_COLORS], szHudColors[0], charsmax(szHudColors[]),
	szHudColors[1], charsmax(szHudColors[]), szHudColors[2], charsmax(szHudColors[])) == 3) {
		g_eDHudData[MODE_REVIVE][COLOR_R] = str_to_num(szHudColors[0]);
		g_eDHudData[MODE_REVIVE][COLOR_G] = str_to_num(szHudColors[1]);
		g_eDHudData[MODE_REVIVE][COLOR_B] = str_to_num(szHudColors[2]);
	}

	if(parse(g_eCvars[PLANTING_COLORS], szHudColors[0], charsmax(szHudColors[]),
	szHudColors[1], charsmax(szHudColors[]), szHudColors[2], charsmax(szHudColors[])) == 3) {
		g_eDHudData[MODE_PLANT][COLOR_R] = str_to_num(szHudColors[0]);
		g_eDHudData[MODE_PLANT][COLOR_G] = str_to_num(szHudColors[1]);
		g_eDHudData[MODE_PLANT][COLOR_B] = str_to_num(szHudColors[2]);
	}

	new szHudCoords[2][8];

	if(parse(g_eCvars[REVIVE_COORDS], szHudCoords[0], charsmax(szHudCoords[]), szHudCoords[1], charsmax(szHudCoords[])) == 2) {
		g_eDHudData[MODE_REVIVE][COORD_X] = str_to_float(szHudCoords[0]);
		g_eDHudData[MODE_REVIVE][COORD_Y] = str_to_float(szHudCoords[1]);
	}

	if(parse(g_eCvars[PLANTING_COORDS], szHudCoords[0], charsmax(szHudCoords[]), szHudCoords[1], charsmax(szHudCoords[])) == 2) {
		g_eDHudData[MODE_PLANT][COORD_X] = str_to_float(szHudCoords[0]);
		g_eDHudData[MODE_PLANT][COORD_Y] = str_to_float(szHudCoords[1]);
	}
}

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHORS);

	register_dictionary("rt_library.txt");

	if(g_eCvars[CORPSE_SPRITE][0] != EOS)
		register_forward(FM_AddToFullPack, "AddToFullPack_Pre", false);
}

public plugin_cfg() {
	g_fTime = get_pcvar_float(get_cvar_pointer("rt_revive_time"));
}

public AddToFullPack_Pre(es, e, ent, host, flags, player, pSet) {
	if(player || !FClassnameIs(ent, CORPSE_SPRITE_CLASSNAME))
		return FMRES_IGNORED;

	if(TeamName:get_entvar(ent, var_team) != TeamName:get_member(host, m_iTeam)) {
		forward_return(FMV_CELL, false);
		return FMRES_SUPERCEDE;
	}

	return FMRES_IGNORED;
}

public rt_revive_start(const iEnt, const id, const iActivator, const Modes:eMode) {
	switch(eMode) {
		case MODE_REVIVE: {
			if(g_eCvars[SPECTATOR]) {
				rg_internal_cmd(id, "specmode", "4");
				set_entvar(id, var_iuser2, iActivator);
				set_member(id, m_hObserverTarget, iActivator);
				set_member(id, m_flNextObserverInput, get_gametime() + 1.25);
			}

			if(g_eCvars[NOTIFY_DHUD]) {
				DisplayDHUDMessage(iActivator, "%l", eMode, "RT_DHUD_REVIVE", id);
				DisplayDHUDMessage(id, "%l", eMode, "RT_DHUD_REVIVE2", iActivator);
			}
		}
		case MODE_PLANT: {
			if(g_eCvars[NOTIFY_DHUD])
				DisplayDHUDMessage(iActivator, "%l", eMode, "RT_DHUD_PLANTING", id);
		}
	}
}

public rt_revive_cancelled(const iEnt, const id, const iActivator, const Modes:eMode) {
	if(g_eCvars[NOTIFY_DHUD]) {
		if(iActivator != RT_NULLENT)
			ClearDHUDMessages(iActivator);

		if(id != RT_NULLENT)
			ClearDHUDMessages(id);
	}
}

public rt_revive_end(const iEnt, const id, const iActivator, const Modes:eMode) {
	if(g_eCvars[NOTIFY_DHUD]) {
		ClearDHUDMessages(iActivator);
		ClearDHUDMessages(id);
	}
}

public rt_creating_corpse_end(const iEnt, const id, const origin[3]) {
	if(g_eCvars[CORPSE_SPRITE][0] == EOS)
		return;

	new iEntSprite = rg_create_entity("info_target");

	new Float:fOrigin[3];

	for(new i; i < 3; i++)
		fOrigin[i] = float(origin[i]);

	engfunc(EngFunc_SetOrigin, iEntSprite, fOrigin);
	engfunc(EngFunc_SetModel, iEntSprite, g_eCvars[CORPSE_SPRITE]);

	set_entvar(iEntSprite, var_classname, CORPSE_SPRITE_CLASSNAME);
	set_entvar(iEntSprite, var_owner, id);
	set_entvar(iEntSprite, var_iuser1, iEnt);
	set_entvar(iEntSprite, var_team, TeamName:get_entvar(iEnt, var_team));
	set_entvar(iEntSprite, var_scale, g_eCvars[SPRITE_SCALE]);
	set_entvar(iEntSprite, var_renderfx, kRenderFxNone);
	set_entvar(iEntSprite, var_rendercolor, Float:{255.0, 255.0, 255.0});
	set_entvar(iEntSprite, var_rendermode, kRenderTransAlpha);
	set_entvar(iEntSprite, var_renderamt, 255.0);
	set_entvar(iEntSprite, var_nextthink, get_gametime() + 0.1);

	SetThink(iEntSprite, "Corpse_Sprite_Think");
}

public Corpse_Sprite_Think(const iEnt) {
	if(is_nullent(get_entvar(iEnt, var_iuser1))) {
		UTIL_RemoveCorpses(get_entvar(iEnt, var_owner), CORPSE_SPRITE_CLASSNAME);
		return;
	}

	set_entvar(iEnt, var_nextthink, get_gametime() + 0.1);
}

stock DisplayDHUDMessage(const id, const szFmtRules[], const Modes:eMode, any:...) {
	new szMessage[MAX_MESSAGE_LENGTH];
	SetGlobalTransTarget(id);
	vformat(szMessage, charsmax(szMessage), szFmtRules, 4);

	set_dhudmessage(g_eDHudData[eMode][COLOR_R], g_eDHudData[eMode][COLOR_G], g_eDHudData[eMode][COLOR_B],
	g_eDHudData[eMode][COORD_X], g_eDHudData[eMode][COORD_Y], .holdtime = g_fTime);
	show_dhudmessage(id, szMessage);
}

stock ClearDHUDMessages(const id, const iChannel = 8) {
	for(new i; i < iChannel; i++)
		show_dhudmessage(id, "");
}

public CreateCvars() {
	bind_pcvar_num(create_cvar(
		"rt_spectator",
		"1",
		FCVAR_NONE,
		"Automatically observe the resurrecting player",
		true,
		0.0,
		true,
		1.0),
		g_eCvars[SPECTATOR]
	);
	bind_pcvar_num(create_cvar(
		"rt_notify_dhud",
		"1",
		FCVAR_NONE,
		"Notification above the timer(DHUD)",
		true,
		0.0,
		true,
		1.0),
		g_eCvars[NOTIFY_DHUD]
	);
	bind_pcvar_string(create_cvar(
		"rt_revive_dhud_colors",
		"0 255 0",
		FCVAR_NONE,
		"DHUD's color at resurrection"),
		g_eCvars[REVIVE_COLORS],
		charsmax(g_eCvars[REVIVE_COLORS])
	);
	bind_pcvar_string(create_cvar(
		"rt_revive_dhud_coords",
		"-1.0 0.8",
		FCVAR_NONE,
		"DHUD's coordinates at resurrection"),
		g_eCvars[REVIVE_COORDS],
		charsmax(g_eCvars[REVIVE_COORDS])
	);
	bind_pcvar_string(create_cvar(
		"rt_planting_dhud_colors",
		"255 0 0",
		FCVAR_NONE,
		"DHUD's color at planting"),
		g_eCvars[PLANTING_COLORS],
		charsmax(g_eCvars[PLANTING_COLORS])
	);
	bind_pcvar_string(create_cvar(
		"rt_planting_dhud_coords",
		"-1.0 0.8",
		FCVAR_NONE,
		"DHUD's coordinates at planting"),
		g_eCvars[PLANTING_COORDS],
		charsmax(g_eCvars[PLANTING_COORDS])
	);
	bind_pcvar_string(create_cvar(
		"rt_corpse_sprite",
		"sprites/rt/corpse_sprite2.spr",
		FCVAR_NONE,
		"Resurrection sprite over a corpse. To disable the function, leave the cvar empty"),
		g_eCvars[CORPSE_SPRITE],
		charsmax(g_eCvars[CORPSE_SPRITE])
	);
	bind_pcvar_float(create_cvar(
		"rt_sprite_scale",
		"0.15",
		FCVAR_NONE,
		"Sprite scale",
		true,
		0.1,
		true,
		0.5),
		g_eCvars[SPRITE_SCALE]
	);
}