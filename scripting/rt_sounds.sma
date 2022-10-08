#include <amxmodx>
#include <rt_api>

#define MAX_SOUNDS_PER_SECTION 10
#define MAX_SOUND_LENGTH 64

enum sections_struct
{
	SECTION_REVIVE_START,
	SECTION_REVIVE_LOOP,
	SECTION_REVIVE_END,
	SECTION_PLANT_START,
	SECTION_PLANT_LOOP,
	SECTION_PLANT_END
};

new sections_struct:g_eCurrentSection;

new g_iSounds[sections_struct];
new g_szSounds[sections_struct][MAX_SOUNDS_PER_SECTION][MAX_SOUND_LENGTH];

public plugin_precache()
{
	register_plugin("Revive Teammates: Sounds", VERSION, AUTHORS);
	
	new szFile[64];
	get_localinfo("amxx_configsdir", szFile, charsmax(szFile));
	add(szFile, charsmax(szFile), "/rt_configs/rt_sounds.ini");
	
	if(!file_exists(szFile))
	{
		set_fail_state("[RT Sounds] File ^"%s^" not found", szFile);
		return;
	}
	
	new INIParser:iParser = INI_CreateParser();
	INI_SetReaders(iParser, "ReadValues", "ReadNewSection");
	INI_ParseFile(iParser, szFile);
	INI_DestroyParser(iParser);
}

public rt_revive_start(const id, const activator, const modes_struct:mode)
{
	new modes_struct:iMode = get_entvar(id, var_iuser3);

	if(iMode != MODE_PLANT)
	{
		switch(mode)
		{
			case MODE_REVIVE:
			{
				if(g_iSounds[SECTION_REVIVE_START])
				{
					rg_send_audio(activator, g_szSounds[SECTION_REVIVE_START][random(g_iSounds[SECTION_REVIVE_START])]);
				}
			}
			case MODE_PLANT:
			{
				if(g_iSounds[SECTION_PLANT_START])
				{
					rg_send_audio(activator, g_szSounds[SECTION_PLANT_START][random(g_iSounds[SECTION_PLANT_START])]);
				}
			}
		}
	}
}

public rt_revive_loop_post(const id, const activator, const Float:timer, modes_struct:mode)
{
	switch(mode)
	{
		case MODE_REVIVE:
		{
			if(g_iSounds[SECTION_REVIVE_LOOP])
			{
				rg_send_audio(activator, g_szSounds[SECTION_REVIVE_LOOP][random(g_iSounds[SECTION_REVIVE_LOOP])]);
			}
		}
		case MODE_PLANT:
		{
			if(g_iSounds[SECTION_PLANT_LOOP])
			{
				rg_send_audio(activator, g_szSounds[SECTION_PLANT_LOOP][random(g_iSounds[SECTION_PLANT_LOOP])]);
			}
		}
	}
}

public rt_revive_end(const id, const activator, const modes_struct:mode)
{
	switch(mode)
	{
		case MODE_REVIVE:
		{
			if(g_iSounds[SECTION_REVIVE_END])
			{
				rg_send_audio(activator, g_szSounds[SECTION_REVIVE_END][random(g_iSounds[SECTION_REVIVE_END])]);
			}
			}
		case MODE_PLANT:
		{
			if(g_iSounds[SECTION_PLANT_END])
			{
				rg_send_audio(activator, g_szSounds[SECTION_PLANT_END][random(g_iSounds[SECTION_PLANT_END])]);
			}
		}
	}
}

public ReadNewSection(INIParser:iParser, const szSection[], bool:invalid_tokens, bool:close_bracket)
{
	if(!close_bracket)
	{
		log_error(AMX_ERR_NATIVE, "Closing bracket was not detected! Current section name '%s'.", szSection);
		return false;
	}

	if(equal(szSection, "revive_start"))
	{
		g_eCurrentSection = SECTION_REVIVE_START;
		return true;
	}
	else if(equal(szSection, "revive_loop"))
	{
		g_eCurrentSection = SECTION_REVIVE_LOOP;
		return true;
	}
	else if(equal(szSection, "revive_end"))
	{
		g_eCurrentSection = SECTION_REVIVE_END;
		return true;
	}
	else if(equal(szSection, "plant_start"))
	{
		g_eCurrentSection = SECTION_PLANT_START;
		return true;
	}
	else if(equal(szSection, "plant_loop"))
	{
		g_eCurrentSection = SECTION_PLANT_LOOP;
		return true;
	}
	else if(equal(szSection, "plant_end"))
	{
		g_eCurrentSection = SECTION_PLANT_END;
		return true;
	}
	
	return false;
}

public ReadValues(INIParser:iParser, const szKey[], const szValue[])
{
	new szSound[MAX_SOUND_LENGTH];

	copy(szSound, charsmax(szSound), szKey);
	trim(szSound);

	copy(g_szSounds[g_eCurrentSection][g_iSounds[g_eCurrentSection]++], charsmax(g_szSounds[][]), szSound);
	
	precache_sound(szSound);
	
	return true;
}