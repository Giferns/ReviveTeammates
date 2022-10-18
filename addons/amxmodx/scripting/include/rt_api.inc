//////////////////////////
// Revive Teammates API //
//////////////////////////

#if defined _rt_api_included
  #endinput
#endif
#define _rt_api_included

#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>

#define VERSION "0.7.0"
#define AUTHORS "ufame & Albertio"

enum modes_struct
{
	MODE_NONE = 0,
	MODE_REVIVE,
	MODE_PLANT
};

new const DEAD_BODY_CLASSNAME[] = "rt_corpse_empty";

const Float:MAX_PLAYER_USE_RADIUS = 64.0;

/**
* Called after the activator starts resurrection/planting (on press USE - `E`)
*
* @param iEnt       corpse entity index
* @param id         player id who can be revived
* @param activator  player id who can revive
* @param mode       MODE_REVIVE - started the resurrection, MODE_PLANT - started planting
*
*/
forward rt_revive_start(const iEnt, const id, const activator, const modes_struct:mode);

/**
* PreThink on resurrection/planting
*
* @param iEnt       corpse entity index
* @param id         player id who can be revived
* @param activator  player id who can revive
* @param timer      time to revive id
* @param mode       MODE_REVIVE - the player continues to be resurrected, MODE_PLANT - the player continues to be planted
*
* @note Can stoped by return PLUGIN_HANDLED
*
* @note timer can be 0.0
*
*/
forward rt_revive_loop_pre(const iEnt, const id, const activator, const Float:timer, modes_struct:mode);

/**
* PostThink on resurrection/planting
*
* @param iEnt       corpse entity index
* @param id         player id who can be revived
* @param activator  player id who can revive
* @param timer      time to revive id
* @param mode       MODE_REVIVE - the player continues to be resurrected, MODE_PLANT - the player continues to be planted
*
* @note timer can't(!!!) be 0.0
*
*/
forward rt_revive_loop_post(const iEnt, const id, const activator, const Float:timer, modes_struct:mode);

/**
* Called after the resurrection/planting is ending
*
* @param iEnt       corpse entity index
* @param id         player id who can be revived
* @param activator  player id who can revive
* @param mode       MODE_REVIVE - the player was resurrected, MODE_PLANT - the player was planted
*
*/
forward rt_revive_end(const iEnt, const id, const activator, const modes_struct:mode);

/**
* Called when the player has stopped resurrecting/planting
*
* @param iEnt       corpse entity index
* @param id         player id who can be revived
* @param activator  player id who can revive
* @param mode       MODE_REVIVE - stopped the resurrection, MODE_PLANT - stopped planting
*
*/
forward rt_revive_cancelled(const iEnt, const id, const activator, const modes_struct:mode);

/*
* Removal of corpses
*/
stock UTIL_RemoveCorpses(const id = 0)
{
	new iEnt = NULLENT;

	while((iEnt = rg_find_ent_by_class(iEnt, DEAD_BODY_CLASSNAME)) > 0)
	{
		if(id && get_entvar(iEnt, var_owner) != id)
		{
			continue;
		}
		
		set_entvar(iEnt, var_flags, FL_KILLME);
		set_entvar(iEnt, var_nextthink, -1.0);
	}
}

/*
* Get the nearest bone of the corpses
*/
stock UTIL_GetNearestBoneCorpse(const iEnt, const activator)
{
	new Float:vPlOrigin[3], Float:vBoneOrigin[3];
	get_entvar(activator, var_origin, vPlOrigin);
	
	for(new iBone = 1; iBone <= 54; iBone++)
	{
		engfunc(EngFunc_GetBonePosition, iEnt, iBone, vBoneOrigin);
 
		if(vector_distance(vPlOrigin, vBoneOrigin) < MAX_PLAYER_USE_RADIUS)
		{
			return iBone;
		}
	}
 
	return 0;
}

/*
* Reset entity think
*/
stock UTIL_ResetEntityThink(const eForward, const iEnt, const id, const activator, const modes_struct:mode)
{
	set_entvar(iEnt, var_iuser1, 0);
	set_entvar(iEnt, var_nextthink, 0.0);

	ExecuteForward(eForward, _, iEnt, id, activator, mode);
}

/*
* Loads plugin configs
*/
stock UTIL_UploadConfigs()
{
	new path[MAX_RESOURCE_PATH_LENGTH], pl_fname[32];
	
	get_localinfo("amxx_configsdir", path, charsmax(path));
	get_plugin(-1, pl_fname, charsmax(pl_fname));

	copyc(pl_fname, charsmax(pl_fname), pl_fname, '.');
	formatex(path, charsmax(path), "%s/rt_configs/%s.cfg", path, pl_fname);

	server_cmd("exec %s", path);
	server_exec();
}