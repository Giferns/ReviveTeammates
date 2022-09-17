//////////////////////////
// Revive Teammates API //
//////////////////////////

#if defined _revive_teammates_included
  #endinput
#endif
#define _revive_teammates_included

#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>

#define VERSION "0.0.1"
#define AUTHORS "ufame & Albertio"

enum modes_struct
{
	MODE_NONE = 0,
	MODE_REVIVE,
	MODE_PLANT
};

new const RT_TASK_INDEX = 19691;
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
* @param nextthink  Next think on used entity (default value 1.0)
*
* @note Can stoped by return PLUGIN_HANDLED
*
* @note timer can be 0.0
*
*/
forward rt_revive_loop_pre(const id, const activator, const Float:timer, Float:nextthink);

/**
* Think on revive :: POST
*
* @param id         player id who can be revived
* @param activator  player id who can revive
* @param timer      time to revive id
* @param nextthink  Next think on used entity (default value 1.0)
*
* @note timer can't(!!!) be 0.0
*
*/
forward rt_revive_loop_post(const id, const activator, const Float:timer, Float:nextthink);

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
stock UTIL_RemoveAllEnts(iPlayer = 0)
{
	new iEntity = NULLENT;

	while((iEntity = rg_find_ent_by_class(iEntity, DEAD_BODY_CLASSNAME)) > 0)
	{
		if(iPlayer && get_entvar(iEntity, var_owner) != iPlayer)
		{
			continue;
		}
		
		SetThink(iEntity, "");

		set_task(0.1, "DeleteEntity", RT_TASK_INDEX + iEntity);
	}
}

public DeleteEntity(iEnt)
{
	engfunc(EngFunc_RemoveEntity, iEnt - RT_TASK_INDEX);
}

/*
* Get Entity by Player id
*/
stock UTIL_GetEntityById(id)
{
	if(!is_user_connected(id))
	{
		return NULLENT;
	}

	new iEntity = NULLENT;

	while((iEntity = rg_find_ent_by_class(iEntity, DEAD_BODY_CLASSNAME)) > 0)
	{
		if(get_entvar(iEntity, var_owner) == id)
		{
			return iEntity;
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