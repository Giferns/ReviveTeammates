#include <amxmodx>
#include <rt_api>

enum CVARS
{
	SPECTATOR,
	NOTIFY_DHUD,
	REVIVE_GLOW[32],
	PLANTING_GLOW[32]
};

new g_eCvars[CVARS];

enum GlowColors
{
	Float:REVIVE_COLOR,
	Float:PLANTING_COLOR
};

new Float:g_eGlowColors[GlowColors][3];

new Float:g_fTime;

public plugin_init()
{
	register_plugin("Revive Teammates: Effects", VERSION, AUTHORS);

	register_dictionary("rt_library.txt");
	
	RegisterCvars();
}

public plugin_cfg()
{
	UTIL_UploadConfigs();

	if(g_eCvars[REVIVE_GLOW][0] != EOS)
	{
		g_eGlowColors[REVIVE_COLOR] = parseHEXColor(g_eCvars[REVIVE_GLOW]);
	}
	
	if(g_eCvars[PLANTING_GLOW][0] != EOS)
	{
		g_eGlowColors[PLANTING_COLOR] = parseHEXColor(g_eCvars[PLANTING_GLOW]);
	}

	g_fTime = get_pcvar_float(get_cvar_pointer("rt_revive_time"));
}

public rt_revive_start(const iEnt, const id, const activator, const modes_struct:mode)
{
	switch(mode)
	{
		case MODE_REVIVE:
		{
			if(g_eCvars[SPECTATOR])
			{
				rg_internal_cmd(id, "specmode", "4");
				set_entvar(id, var_iuser2, activator);
				set_member(id, m_hObserverTarget, activator);
				set_member(id, m_flNextObserverInput, get_gametime() + 1.6);
			}

			if(g_eCvars[NOTIFY_DHUD])
			{
				DisplayDHUDMessage(activator, fmt("%L", activator, "RT_DHUD_REVIVE", id), mode);
				DisplayDHUDMessage(id, fmt("%L %L", id, "RT_CHAT_TAG", id, "RT_DHUD_REVIVE2", activator), mode);
			}
			
			if(g_eCvars[REVIVE_GLOW][0] != EOS)
			{
				rg_set_rendering(iEnt, kRenderFxGlowShell, g_eGlowColors[REVIVE_COLOR], kRenderNormal, 30.0);
			}
		}
		case MODE_PLANT:
		{
			if(g_eCvars[NOTIFY_DHUD])
			{
				DisplayDHUDMessage(activator, fmt("%L", activator, "RT_DHUD_PLANTING", id), mode);
			}
			
			if(g_eCvars[PLANTING_GLOW][0] != EOS)
			{
				rg_set_rendering(iEnt, kRenderFxGlowShell, g_eGlowColors[PLANTING_COLOR], kRenderNormal, 30.0);
			}
		}
	}
}

public rt_revive_cancelled(const iEnt, const id, const activator, const modes_struct:mode)
{
	switch(mode)
	{
		case MODE_REVIVE:
		{
			if(g_eCvars[REVIVE_GLOW][0] != EOS)
			{
				rg_set_rendering(iEnt);
			}
		}
		case MODE_PLANT:
		{
			if(g_eCvars[PLANTING_GLOW][0] != EOS)
			{
				rg_set_rendering(iEnt);
			}
		}
	}

	if(g_eCvars[NOTIFY_DHUD])
	{
		ClearDHUDMessages(activator);
		ClearDHUDMessages(id);
	}
}

public rt_revive_end(const iEnt, const id, const activator, const modes_struct:mode)
{
	switch(mode)
	{
		case MODE_REVIVE:
		{
			new modes_struct:iMode = get_entvar(iEnt, var_iuser3);
			
			if(iMode != MODE_PLANT && g_eCvars[REVIVE_GLOW][0] != EOS)
			{
				rg_set_rendering(iEnt);
			}
		}
		case MODE_PLANT:
		{
			if(g_eCvars[PLANTING_GLOW][0] != EOS)
			{
				rg_set_rendering(iEnt);
			}
		}
	}

	if(g_eCvars[NOTIFY_DHUD])
	{
		ClearDHUDMessages(activator);
		ClearDHUDMessages(id);
	}
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
	{
		return result;
	}

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
		case '0'..'9':
		{
			return (ch - '0');
		}
		case 'a'..'f':
		{
			return (10 + ch - 'a');
		}
		case 'A'..'F':
		{
			return (10 + ch - 'A');
		}
	}

	return 0;
}

stock DisplayDHUDMessage(id, szMessage[], modes_struct:mode)
{
	switch(mode)
	{
		case MODE_REVIVE:
		{
			set_dhudmessage(0, 255, 0, -1.0, 0.81, .holdtime = g_fTime);
		}
		case MODE_PLANT:
		{
			set_dhudmessage(255, 0, 0, -1.0, 0.81, .holdtime = g_fTime);
		}
	}

	show_dhudmessage(id, szMessage);
}

stock ClearDHUDMessages(id, iClear = 8)
{
	for(new i; i < iClear; i++)
	{
		show_dhudmessage(id, "");
	}
}

public RegisterCvars()
{
	bind_pcvar_num(create_cvar(
		"rt_spectator",
		"1",
		FCVAR_NONE,
		"Automatically observe the resurrecting player",
		true,
		0.0),
		g_eCvars[SPECTATOR]
	);
	bind_pcvar_num(create_cvar(
		"rt_notify_dhud",
		"1",
		FCVAR_NONE,
		"Notification under Timer(DHUD)",
		true,
		0.0),
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
}