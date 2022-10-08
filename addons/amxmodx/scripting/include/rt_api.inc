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
#include <xs>

#define VERSION "0.4.0"
#define AUTHORS "ufame & Albertio"

enum modes_struct
{
	MODE_NONE = 0,
	MODE_REVIVE,
	MODE_PLANT
};

new const DEAD_BODY_CLASSNAME[] = "rt_corpse_empty";

/**
* Called before activator starting the revive (on press USE - `E`)
*
* @param id         player id who can be revived
* @param activator  player id who can revive
* @param mode       MODE_REVIVE - started the resurrection, MODE_PLANT - started planting
*
*/
forward rt_revive_start(const id, const activator, const modes_struct:mode);

/**
* Think on revive :: PRE
*
* @param id         player id who can be revived
* @param activator  player id who can revive
* @param timer      time to revive id
* @param mode       MODE_REVIVE - the player was resurrected, MODE_PLANT - the player was mined
*
* @note Can stoped by return PLUGIN_HANDLED
*
* @note timer can be 0.0
*
*/
forward rt_revive_loop_pre(const id, const activator, const Float:timer, modes_struct:mode);

/**
* Think on revive :: POST
*
* @param id         player id who can be revived
* @param activator  player id who can revive
* @param timer      time to revive id
* @param mode       MODE_REVIVE - the player was resurrected, MODE_PLANT - the player was mined
*
* @note timer can't(!!!) be 0.0
*
*/
forward rt_revive_loop_post(const id, const activator, const Float:timer, modes_struct:mode);

/**
* Called after revive has been ending
*
* @param id         player id who can be revived
* @param activator  player id who can revive
* @param mode       MODE_REVIVE - the player was resurrected, MODE_PLANT - the player was mined
*
*/
forward rt_revive_end(const id, const activator, const modes_struct:mode);

/**
* Called when the player has stopped resurrecting
*
* @param id         player id who can be revived
* @param activator  player id who can revive
* @param mode       MODE_REVIVE - stopped the resurrection, MODE_PLANT - stopped planting
*
*/
forward rt_revive_cancelled(const id, const activator, const modes_struct:mode);

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
		
		SetThink(iEnt, NULL_STRING);

		RequestFrame("DeleteEntity", iEnt);
	}
}

public DeleteEntity(iEnt)
{
	engfunc(EngFunc_RemoveEntity, iEnt);
}

/*
* Get Entity by Player id
*/
stock UTIL_GetEntityById(const id)
{
	if(!is_user_connected(id))
	{
		return NULLENT;
	}

	new iEnt = NULLENT;

	while((iEnt = rg_find_ent_by_class(iEnt, DEAD_BODY_CLASSNAME)) > 0)
	{
		if(get_entvar(iEnt, var_owner) == id)
		{
			return iEnt;
		}
	}

	return NULLENT;
}

/*
* Loads plugin configs
*/
stock UTIL_UploadConfigs()
{
	new path[MAX_RESOURCE_PATH_LENGTH], pl_fname1[32], pl_fname2[32];
	
	get_localinfo("amxx_configsdir", path, charsmax(path));
	get_plugin(-1, pl_fname1, charsmax(pl_fname1));

	copyc(pl_fname2, charsmax(pl_fname2), pl_fname1, '.');
	formatex(path, charsmax(path), "%s/rt_configs/%s.cfg", path, pl_fname2);

	server_cmd("exec %s", path);
	server_exec();
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
 
		if(is_in_viewcone(activator, vBoneOrigin) && get_distance_f(vPlOrigin, vBoneOrigin) <= 64.0)
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

	ExecuteForward(eForward, _, id, activator, mode);
}