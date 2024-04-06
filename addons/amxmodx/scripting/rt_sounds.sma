#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <rt_api>

public stock const PLUGIN[] = "Revive Teammates: Sounds";
public stock const CFG_FILE[] = "addons/amxmodx/configs/rt_configs/rt_sounds.cfg";
public stock const INI_FILE[] = "addons/amxmodx/configs/rt_configs/rt_sounds.ini";

#define MAX_SOUNDS_PER_SECTION 10
#define MAX_SOUND_LENGTH 64

enum CVARS {
	Float:SOUND_RADIUS,
	NEARBY_PLAYERS
};

new g_eCvars[CVARS];

enum sections_struct {
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

public plugin_precache() {
	register_plugin(PLUGIN, VERSION, AUTHORS);
	
	if(!file_exists(INI_FILE)) {
		set_fail_state("[RT Sounds] File ^"%s^" not found", INI_FILE);
		return;
	}
	
	new INIParser:iParser = INI_CreateParser();
	INI_SetReaders(iParser, "ReadKeyValue", "ReadNewSection");
	INI_ParseFile(iParser, INI_FILE);
	INI_DestroyParser(iParser);

	CreateCvars();

	server_cmd("exec %s", CFG_FILE);
	server_exec();
}

public rt_revive_start(const iEnt, const id, const iActivator, const Modes:eMode) {
	switch(eMode) {
		case MODE_REVIVE: { UTIL_PlaybackSound(iEnt, id, iActivator, SECTION_REVIVE_START); }
		case MODE_PLANT: { UTIL_PlaybackSound(iEnt, id, iActivator, SECTION_PLANT_START); }
	}
}

public rt_revive_loop_post(const iEnt, const id, const iActivator, const Float:timer, Modes:eMode) {
	switch(eMode) {
		case MODE_REVIVE: { UTIL_PlaybackSound(iEnt, id, iActivator, SECTION_REVIVE_LOOP); }
		case MODE_PLANT: { UTIL_PlaybackSound(iEnt, id, iActivator, SECTION_PLANT_LOOP); }
	}
}

public rt_revive_end(const iEnt, const id, const iActivator, const Modes:eMode) {
	switch(eMode) {
		case MODE_REVIVE: {
			new Modes:iMode = Modes:get_entvar(iEnt, var_iuser3);
			
			if(iMode != MODE_PLANT)
				UTIL_PlaybackSound(iEnt, id, iActivator, SECTION_REVIVE_END);
		}
		case MODE_PLANT: { UTIL_PlaybackSound(iEnt, id, iActivator, SECTION_PLANT_END); }
	}
}

public bool:ReadNewSection(INIParser:iParser, const szSection[], bool:bInvalidTokens, bool:bCloseBracket) {
	if(!bCloseBracket) {
		log_error(AMX_ERR_NATIVE, "Closing bracket was not detected! Current section name '%s'.", szSection);
		return false;
	}

	if(equal(szSection, "revive_start")) {
		g_eCurrentSection = SECTION_REVIVE_START;
		return true;
	} else if(equal(szSection, "revive_loop")) {
		g_eCurrentSection = SECTION_REVIVE_LOOP;
		return true;
	} else if(equal(szSection, "revive_end")) {
		g_eCurrentSection = SECTION_REVIVE_END;
		return true;
	} else if(equal(szSection, "plant_start")) {
		g_eCurrentSection = SECTION_PLANT_START;
		return true;
	} else if(equal(szSection, "plant_loop")) {
		g_eCurrentSection = SECTION_PLANT_LOOP;
		return true;
	} else if(equal(szSection, "plant_end")) {
		g_eCurrentSection = SECTION_PLANT_END;
		return true;
	}
	
	return false;
}

public bool:ReadKeyValue(INIParser:iParser, const szKey[], const szValue[]) {
	if(szKey[0] == EOS)
		return false;
	
	new szSound[MAX_SOUND_LENGTH];
	copy(szSound, charsmax(szSound), szKey);
	trim(szSound);
	copy(g_szSounds[g_eCurrentSection][g_iSounds[g_eCurrentSection]++], charsmax(g_szSounds[][]), szSound);
	
	precache_sound(szSound);
	
	return true;
}

stock UTIL_PlaybackSound(const iEnt, const id, const iActivator, const sections_struct:iSoundSection) {
	if(g_iSounds[iSoundSection]) {
		if(g_eCvars[NEARBY_PLAYERS] == 2 || (g_eCvars[NEARBY_PLAYERS] && (iSoundSection == SECTION_REVIVE_END || iSoundSection == SECTION_PLANT_END)))
			UTIL_PlaybackSoundNearbyPlayers(iEnt, g_szSounds[iSoundSection][random(g_iSounds[iSoundSection])]);
		else if(!g_eCvars[NEARBY_PLAYERS]) {
			rg_send_audio(iActivator, g_szSounds[iSoundSection][random(g_iSounds[iSoundSection])]);
			rg_send_audio(id, g_szSounds[iSoundSection][random(g_iSounds[iSoundSection])]);
		}
	}
}

stock UTIL_PlaybackSoundNearbyPlayers(const id, const szSound[]) {
	new iEnt = RT_NULLENT;

	new Float:vOrigin[3];
	get_entvar(id, var_vuser4, vOrigin);
	
	while((iEnt = engfunc(EngFunc_FindEntityInSphere, iEnt, vOrigin, g_eCvars[SOUND_RADIUS])) > 0)
		if(ExecuteHam(Ham_IsPlayer, iEnt))
			rg_send_audio(iEnt, szSound);
}

public CreateCvars() {
	bind_pcvar_float(create_cvar(
		"rt_sound_radius",
		"250.0",
		FCVAR_NONE,
		"The radius in which to count the nearest players",
		true,
		1.0),
		g_eCvars[SOUND_RADIUS]
	);
	bind_pcvar_num(create_cvar(
		"rt_nearby_players",
		"0",
		FCVAR_NONE,
		"Play the resurrection/landing sound for nearby players. 0 - off, 1 - only ending sounds, 2 - all sounds",
		true,
		0.0,
		true,
		2.0),
		g_eCvars[NEARBY_PLAYERS]
	);
}