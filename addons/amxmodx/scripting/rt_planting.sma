#include <amxmodx>
#include <hamsandwich>
#include <reapi>
#include <rt_api>

enum CVARS
{
	Float:DAMAGE,
	Float:RADIUS,
	MAX_PLANTING
};

new g_eCvars[CVARS];

new g_szModels[3];

enum _:PlayerData
{
	PLANTING_COUNT
};

new g_ePlayerData[MAX_PLAYERS + 1][PlayerData];

public plugin_precache()
{
	g_szModels[0] = precache_model("sprites/zerogxplode.spr");
	g_szModels[1] = precache_model("sprites/eexplo.spr");
	g_szModels[2] = precache_model("sprites/fexplo.spr");

	RegisterCvars();
	UploadConfigs();
}

public plugin_init()
{
	register_plugin("Revive Teammates: Planting", VERSION, AUTHORS);

	register_dictionary("rt_library.txt");

	RegisterHookChain(RG_CSGameRules_CleanUpMap, "CSGameRules_CleanUpMap_Post", .post = 1);
}

public CSGameRules_CleanUpMap_Post()
{
	arrayset(g_ePlayerData[0][_:0], 0, sizeof(g_ePlayerData) * sizeof(g_ePlayerData[]));
}

public client_disconnected(id)
{
	g_ePlayerData[id][PLANTING_COUNT] = 0;
}

public rt_revive_start(const iEnt, const id, const iActivator, const modes_struct:eMode)
{
	static modes_struct:iMode;
	iMode = get_entvar(iEnt, var_iuser3);
	
	if(eMode == MODE_PLANT)
	{
		if(g_ePlayerData[iActivator][PLANTING_COUNT] >= g_eCvars[MAX_PLANTING])
		{
			UTIL_NotifyClient(iActivator, print_team_red, "RT_PLANTING_COUNT");
			return PLUGIN_HANDLED;
		}

		if(iMode == MODE_PLANT)
		{
			UTIL_NotifyClient(iActivator, print_team_red, "RT_IS_PLANTED", id);
			return PLUGIN_HANDLED;
		}
	}

	return PLUGIN_CONTINUE;
}

public rt_revive_end(const iEnt, const id, const iActivator, const modes_struct:eMode)
{
	switch(eMode)
	{
		case MODE_REVIVE:
		{
			static modes_struct:iMode;
			iMode = get_entvar(iEnt, var_iuser3);

			if(iMode == MODE_PLANT)
			{
				static Float:vOrigin[3];
				get_entvar(iActivator, var_origin, vOrigin);
				UTIL_MakeExplosionEffects(vOrigin);
				
				static iPlanter;
				iPlanter = get_entvar(iEnt, var_iuser4);
				
				for(new iVictim = 1, Float:fReduceDamage, Float:vecEnd[3]; iVictim <= MaxClients; iVictim++)
				{
					if(!is_user_alive(iVictim) || TeamName:get_member(iVictim, m_iTeam) != TeamName:get_member(id, m_iTeam))
						continue;
					
					get_entvar(iVictim, var_origin, vecEnd);

					if((fReduceDamage = (g_eCvars[DAMAGE] - vector_distance(vOrigin, vecEnd) * (g_eCvars[DAMAGE] / g_eCvars[RADIUS]))) < 1.0)
						continue;
					
					set_member(iVictim, m_LastHitGroup, HITGROUP_GENERIC);

					ExecuteHamB(Ham_TakeDamage, iVictim, iEnt, iPlanter, fReduceDamage, DMG_GRENADE | DMG_ALWAYSGIB);
				}

				UTIL_RemoveCorpses(id, DEAD_BODY_CLASSNAME);
			}
		}
		case MODE_PLANT:
		{
			UTIL_NotifyClient(iActivator, print_team_blue, "RT_PLANTING", id);
			
			g_ePlayerData[iActivator][PLANTING_COUNT]++;

			set_entvar(iEnt, var_iuser1, 0);
			set_entvar(iEnt, var_iuser3, eMode);
			set_entvar(iEnt, var_iuser4, iActivator);
		}
	}
}

stock UTIL_MakeExplosionEffects(const Float:vecOrigin[3])
{
	message_begin_f(MSG_PAS, SVC_TEMPENTITY, vecOrigin);
	write_byte(TE_EXPLOSION);
	write_coord_f(vecOrigin[0]);
	write_coord_f(vecOrigin[1]);
	write_coord_f(vecOrigin[2] + 20.0);
	write_short(g_szModels[2]);
	write_byte(25);
	write_byte(30);
	write_byte(TE_EXPLFLAG_NONE);
	message_end();
	
	message_begin_f(MSG_PAS, SVC_TEMPENTITY, vecOrigin);
	write_byte(TE_EXPLOSION);
	write_coord_f(vecOrigin[0] + random_float(-64.0, 64.0));
	write_coord_f(vecOrigin[1] + random_float(-64.0, 64.0));
	write_coord_f(vecOrigin[2] + random_float(30.0, 35.0));
	write_short(g_szModels[1]);
	write_byte(30);
	write_byte(30);
	write_byte(TE_EXPLFLAG_NONE);
	message_end();

	for(new i; i < 3; i++)
	{
		message_begin_f(MSG_PAS, SVC_TEMPENTITY, vecOrigin);
		write_byte(TE_SPRITE);
		write_coord_f(vecOrigin[0] + random_float(-256.0, 256.0));
		write_coord_f(vecOrigin[1] + random_float(-256.0, 256.0));
		write_coord_f(vecOrigin[2] + random_float(-10.0, 10.0));
		write_short(g_szModels[i]);
		write_byte(30);
		write_byte(150);
		message_end();
	}
}

public RegisterCvars()
{
	bind_pcvar_float(create_cvar(
		"rt_explosion_damage",
		"255.0",
		FCVAR_NONE,
		"Explosion damage",
		true,
		1.0),
		g_eCvars[DAMAGE]
	);
	bind_pcvar_float(create_cvar(
		"rt_explosion_radius",
		"200.0",
		FCVAR_NONE,
		"Explosion radius",
		true,
		1.0),
		g_eCvars[RADIUS]
	);
	bind_pcvar_num(create_cvar(
		"rt_max_planting",
		"3",
		FCVAR_NONE,
		"Maximum number of planting corpses per round",
		true,
		1.0),
		g_eCvars[MAX_PLANTING]
	);
}