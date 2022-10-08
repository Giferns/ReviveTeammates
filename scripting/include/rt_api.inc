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

#define VERSION "0.3.0"
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
* Get position of the bones of the corpse
*/
stock UTIL_GetPositionBonesCorpse(const iEnt, Float:vOrigin[6][3])
{
	static const iBonesCorpse[] = {0, 8, 17, 31, 43, 49};
	new Float:vBoneOrigin[6][3];
	
	for(new i; i < sizeof(iBonesCorpse); i++)
	{
		engfunc(EngFunc_GetBonePosition, iEnt, iBonesCorpse[i], vBoneOrigin[i]);
	}

	vOrigin = vBoneOrigin;
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