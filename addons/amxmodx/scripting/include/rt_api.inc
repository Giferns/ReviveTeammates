//////////////////////////
// Revive Teammates API //
//////////////////////////

#if defined _rt_api_included
  #endinput
#endif
#define _rt_api_included

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>

#define VERSION "1.0.0"
#define AUTHORS "ufame & Albertio"

enum modes_struct
{
	MODE_NONE = 0,
	MODE_REVIVE,
	MODE_PLANT
};

new const DEAD_BODY_CLASSNAME[] = "rt_corpse_empty";

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

/**
* Called before a corpse is created
*
* @param iEnt  corpse entity index
* @param id    id of the player whose corpse
*
*/
forward rt_creating_corpse_start(const iEnt, const id);

/**
* Called after the creation of the corpse is completed
*
* @param iEnt    corpse entity index
* @param id      id of the player whose corpse
* @param origin  coordinates of the corpse
*
*/
forward rt_creating_corpse_end(const iEnt, const id, const origin[3]);

/*
* Removal of corpses
*/
stock UTIL_RemoveCorpses(const id = 0, const szClassName[] = DEAD_BODY_CLASSNAME)
{
	static iEnt, iActivator;
	iEnt = NULLENT;

	while((iEnt = rg_find_ent_by_class(iEnt, szClassName)) > 0)
	{
		if(!is_nullent(iEnt))
		{
			if(id && get_entvar(iEnt, var_owner) != id)
				continue;

			iActivator = get_entvar(iEnt, var_iuser1);
			
			set_entvar(iEnt, var_flags, FL_KILLME);
			set_entvar(iEnt, var_nextthink, -1.0);

			return iActivator;
		}
	}

	return 0;
}

/*
* Reset entity think
*/
stock UTIL_ResetEntityThink(const eForward, const iEnt, const id, const activator, const modes_struct:mode)
{
	if(iEnt != NULLENT)
	{
		set_entvar(iEnt, var_nextthink, 0.0);
		set_entvar(iEnt, var_iuser1, 0);
	}

	ExecuteForward(eForward, _, iEnt, UTIL_IsUserConnected(id), UTIL_IsUserConnected(activator), mode);
}

/*
* Checking whether the player is connected
*/
stock UTIL_IsUserConnected(const id)
{
	return (is_user_connected(id) ? id : NULLENT);
}

/*
* Loads plugin configs
*/
stock UploadConfigs()
{
	new szPath[MAX_RESOURCE_PATH_LENGTH], szPlFileName[32];
	
	get_localinfo("amxx_configsdir", szPath, charsmax(szPath));
	get_plugin(-1, szPlFileName, charsmax(szPlFileName));

	copyc(szPlFileName, charsmax(szPlFileName), szPlFileName, '.');
	formatex(szPath, charsmax(szPath), "%s/rt_configs/%s.cfg", szPath, szPlFileName);

	server_cmd("exec %s", szPath);
	server_exec();
}