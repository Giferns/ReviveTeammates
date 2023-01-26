#include <amxmodx>
#include <fakemeta>
#include <reapi>
#include <rt_api>

enum CVARS
{
	SPECTATOR,
	NOTIFY_DHUD,
	REVIVE_GLOW[32],
	PLANTING_GLOW[32],
	CORPSE_SPRITE[64],
	Float:SPRITE_SCALE
};

new g_eCvars[CVARS];

enum GlowColors
{
	Float:REVIVE_COLOR,
	Float:PLANTING_COLOR
};

new Float:g_eGlowColors[GlowColors][3];

new const CORPSE_SPRITE_CLASSNAME[] = "rt_corpse_sprite";

new Float:g_fTime;

public plugin_precache()
{
	RegisterCvars();
	UploadConfigs();

	if(g_eCvars[CORPSE_SPRITE][0] != EOS)
		precache_model(g_eCvars[CORPSE_SPRITE]);
}

public plugin_init()
{
	register_plugin("Revive Teammates: Effects", VERSION, AUTHORS);

	register_dictionary("rt_library.txt");

	register_forward(FM_AddToFullPack, "AddToFullPack_Post", true);
}

public plugin_cfg()
{
	if(g_eCvars[REVIVE_GLOW][0] != EOS)
		g_eGlowColors[REVIVE_COLOR] = parseHEXColor(g_eCvars[REVIVE_GLOW]);
	
	if(g_eCvars[PLANTING_GLOW][0] != EOS)
		g_eGlowColors[PLANTING_COLOR] = parseHEXColor(g_eCvars[PLANTING_GLOW]);

	g_fTime = get_pcvar_float(get_cvar_pointer("rt_revive_time"));
}

public AddToFullPack_Post(es, e, ent, host, flags, player, pSet)
{
	if(g_eCvars[CORPSE_SPRITE][0] == EOS || player || !FClassnameIs(ent, CORPSE_SPRITE_CLASSNAME))
		return FMRES_IGNORED;

	if(TeamName:get_entvar(ent, var_team) != TeamName:get_member(host, m_iTeam))
		set_es(es, ES_Effects, EF_NODRAW);

	return FMRES_IGNORED;
}

public rt_revive_start(const iEnt, const id, const iActivator, const modes_struct:eMode)
{
	switch(eMode)
	{
		case MODE_REVIVE:
		{
			if(g_eCvars[SPECTATOR])
			{
				rg_internal_cmd(id, "specmode", "4");
				set_entvar(id, var_iuser2, iActivator);
				set_member(id, m_hObserverTarget, iActivator);
				set_member(id, m_flNextObserverInput, get_gametime() + 1.25);
			}

			if(g_eCvars[NOTIFY_DHUD])
			{
				DisplayDHUDMessage(iActivator, fmt("%L", iActivator, "RT_DHUD_REVIVE", id), eMode);
				DisplayDHUDMessage(id, fmt("%L %L", id, "RT_CHAT_TAG", id, "RT_DHUD_REVIVE2", iActivator), eMode);
			}
			
			if(g_eCvars[REVIVE_GLOW][0] != EOS)
				rg_set_rendering(iEnt, kRenderFxGlowShell, g_eGlowColors[REVIVE_COLOR], kRenderNormal, 30.0);
		}
		case MODE_PLANT:
		{
			if(g_eCvars[NOTIFY_DHUD])
				DisplayDHUDMessage(iActivator, fmt("%L", iActivator, "RT_DHUD_PLANTING", id), eMode);
			
			if(g_eCvars[PLANTING_GLOW][0] != EOS)
				rg_set_rendering(iEnt, kRenderFxGlowShell, g_eGlowColors[PLANTING_COLOR], kRenderNormal, 30.0);
		}
	}

	return PLUGIN_CONTINUE;
}

public rt_revive_cancelled(const iEnt, const id, const iActivator, const modes_struct:eMode)
{
	switch(eMode)
	{
		case MODE_REVIVE:
		{
			if(g_eCvars[REVIVE_GLOW][0] != EOS)
				rg_set_rendering(iEnt);
		}
		case MODE_PLANT:
		{
			if(g_eCvars[PLANTING_GLOW][0] != EOS)
				rg_set_rendering(iEnt);
		}
	}

	if(g_eCvars[NOTIFY_DHUD])
	{
		if(iActivator != NULLENT)
			ClearDHUDMessages(iActivator);

		if(id != NULLENT)
			ClearDHUDMessages(id);
	}
}

public rt_revive_end(const iEnt, const id, const iActivator, const modes_struct:eMode)
{
	switch(eMode)
	{
		case MODE_REVIVE:
		{
			static modes_struct:iMode;
			iMode = get_entvar(iEnt, var_iuser3);
			
			if(iMode != MODE_PLANT && g_eCvars[REVIVE_GLOW][0] != EOS)
				rg_set_rendering(iEnt);
		}
		case MODE_PLANT:
		{
			if(g_eCvars[PLANTING_GLOW][0] != EOS)
				rg_set_rendering(iEnt);
		}
	}

	if(g_eCvars[NOTIFY_DHUD])
	{
		ClearDHUDMessages(iActivator);
		ClearDHUDMessages(id);
	}
}

public rt_creating_corpse_end(const iEnt, const id, const origin[3])
{
	if(g_eCvars[CORPSE_SPRITE][0] != EOS)
	{
		new iEntSprite = rg_create_entity("info_target");

		if(is_nullent(iEntSprite))
			return;

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

		rg_set_rendering(iEntSprite, kRenderFxNone, Float:{255.0, 255.0, 255.0}, kRenderTransAlpha, 255.0);

		SetThink(iEntSprite, "Corpse_Sprite_Think");

		set_entvar(iEntSprite, var_nextthink, get_gametime() + 0.1);
	}
}

public Corpse_Sprite_Think(const iEnt)
{
	if(is_nullent(get_entvar(iEnt, var_iuser1)))
	{
		UTIL_RemoveCorpses(get_entvar(iEnt, var_owner), CORPSE_SPRITE_CLASSNAME);
		return;
	}

	set_entvar(iEnt, var_nextthink, get_gametime() + 0.1);
}

stock rg_set_rendering(const id, const fx = kRenderFxNone, const Float:fColor[3] = {0.0, 0.0, 0.0}, const render = kRenderNormal, const Float:fAmount = 0.0)
{
	set_entvar(id, var_renderfx, fx);
	set_entvar(id, var_rendercolor, fColor);
	set_entvar(id, var_rendermode, render);
	set_entvar(id, var_renderamt, fAmount);
}

stock Float:parseHEXColor(const value[])
{
	new Float:result[3];

	if(value[0] != '#' && strlen(value) != 7)
		return result;

	result[0] = parse16bit(value[1], value[2]);
	result[1] = parse16bit(value[3], value[4]);
	result[2] = parse16bit(value[5], value[6]);

	return result;
}

stock Float:parse16bit(ch1, ch2)
{
	return float(parseHex(ch1) * 16 + parseHex(ch2));
}

stock parseHex(const ch)
{
	switch(ch)
	{
		case '0'..'9': return (ch - '0');
		case 'a'..'f': return (10 + ch - 'a');
		case 'A'..'F': return (10 + ch - 'A');
	}

	return 0;
}

stock DisplayDHUDMessage(id, szMessage[], modes_struct:eMode)
{
	switch(eMode)
	{
		case MODE_REVIVE: set_dhudmessage(0, 255, 0, -1.0, 0.81, .holdtime = g_fTime);
		case MODE_PLANT: set_dhudmessage(255, 0, 0, -1.0, 0.81, .holdtime = g_fTime);
	}

	show_dhudmessage(id, szMessage);
}

stock ClearDHUDMessages(id, iClear = 8)
{
	for(new i; i < iClear; i++)
		show_dhudmessage(id, "");
}

public RegisterCvars()
{
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
		"Notification under Timer(DHUD)",
		true,
		0.0,
		true,
		1.0),
		g_eCvars[NOTIFY_DHUD]
	);
	bind_pcvar_string(create_cvar(
		"rt_revive_glow",
		"#5da130",
		FCVAR_NONE,
		"The color of the corpse being resurrected(HEX)"),
		g_eCvars[REVIVE_GLOW],
		charsmax(g_eCvars[REVIVE_GLOW])
	);
	bind_pcvar_string(create_cvar(
		"rt_planting_glow",
		"#9b2d30",
		FCVAR_NONE,
		"The color of the corpse being planted(HEX)"),
		g_eCvars[PLANTING_GLOW],
		charsmax(g_eCvars[PLANTING_GLOW])
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