////////////////////////////////////
////////					////////
////	Revive Teammates API	////
////////					////////
////////////////////////////////////

#if defined _rt_api_included
	#endinput
#endif
#define _rt_api_included

public stock const VERSION[] = "1.2.0";
public stock const AUTHORS[] = "DEV-CS.RU Community";

#define RT_NULLENT -1

enum Modes {
	MODE_NONE = 0,
	MODE_REVIVE,
	MODE_PLANT
};

new const DEAD_BODY_CLASSNAME[] = "rt_corpse_empty";

/**
* Called after the activator starts resurrection/planting (on press USE - `E`)
*
* @param iEnt           Corpse entity index
* @param id             Player id who can be ressurected
* @param iActivator     Player id who ressurect
* @param eMode          MODE_REVIVE - started the resurrection, MODE_PLANT - started planting
*
* @noreturn
*/
forward rt_revive_start(const iEnt, const id, const iActivator, const Modes:eMode);

/**
* PreThink on resurrection/planting
*
* @note                 Timer can be 0.0
*
* @param iEnt           Corpse entity index
* @param id             Player id who can be ressurected
* @param iActivator     Player id who ressurect
* @param timer          Resurrection time
* @param eMode          MODE_REVIVE - the player continues to be resurrected, MODE_PLANT - the player continues to be planted
*
* @return               PLUGIN_CONTINUE to continue resurrection/planting
*                       PLUGIN_HANDLED to stop resurrection/planting
*/
forward rt_revive_loop_pre(const iEnt, const id, const iActivator, const Float:timer, Modes:eMode);

/**
* PostThink on resurrection/planting
*
* @note                 Timer can't be 0.0
*
* @param iEnt           Corpse entity index
* @param id             Player id who can be ressurected
* @param iActivator     Player id who ressurect
* @param timer          Resurrection time
* @param eMode          MODE_REVIVE - the player continues to be resurrected, MODE_PLANT - the player continues to be planted
*
* @return               PLUGIN_CONTINUE to continue resurrection/planting
*                       PLUGIN_HANDLED to stop resurrection/planting
*/
forward rt_revive_loop_post(const iEnt, const id, const iActivator, const Float:timer, Modes:eMode);

/**
* Called after the resurrection/planting is ending
*
* @param iEnt           Corpse entity index
* @param id             Player id who can be ressurected
* @param iActivator     Player id who ressurect
* @param eMode          MODE_REVIVE - the player was resurrected, MODE_PLANT - the player was planted
*
* @noreturn
*/
forward rt_revive_end(const iEnt, const id, const iActivator, const Modes:eMode);

/**
* Called when the player has stopped resurrecting/planting
*
* @param iEnt           Corpse entity index
* @param id             Player id who can be ressurected or RT_NULLENT
* @param iActivator     Player id who ressurect or RT_NULLENT
* @param eMode          MODE_REVIVE - stopped the resurrection, MODE_PLANT - stopped planting
*
* @noreturn
*/
forward rt_revive_cancelled(const iEnt, const id, const iActivator, const Modes:eMode);

/**
* Called before a corpse is created
*
* @param iEnt           Corpse entity index
* @param id             Player id whose corpse
*
* @return               PLUGIN_CONTINUE to continue the created of a corpse
*                       PLUGIN_HANDLED to stop the created of a corpse
*/
forward rt_creating_corpse_start(const iEnt, const id);

/**
* Called after the creation of the corpse is completed
*
* @param iEnt           Corpse entity index
* @param id             Player id whose corpse
* @param vOrigin        Coordinates of the corpse
*
* @noreturn
*/
forward rt_creating_corpse_end(const iEnt, const id, const vOrigin[3]);

/**
* Removal of corpses
*
* @param id             Player id whose corpse or 0 for all corpses
* @param szClassName    Entity classname
*
* @return               Player id who is resurrecting or 0
*/
stock UTIL_RemoveCorpses(const id = 0, const szClassName[] = DEAD_BODY_CLASSNAME) {
	new iEnt = RT_NULLENT;
	new iActivator, iOwner;

	while((iEnt = rg_find_ent_by_class(iEnt, szClassName)) > 0) {
		if(!is_nullent(iEnt)) {
			if(id && (iOwner = get_entvar(iEnt, var_owner)) != id)
				continue;

			if(id && iOwner == id)
				iActivator = get_entvar(iEnt, var_iuser1);

			set_entvar(iEnt, var_flags, FL_KILLME);
			set_entvar(iEnt, var_nextthink, 0.0);

			if(iActivator)
				break;
		}
	}

	return iActivator;
}

/**
* Reset entity think
*
* @param eForward       Forward type
* @param iEnt           Corpse entity index
* @param id             Player id whose corpse
* @param iActivator     Player id who ressurect
* @param eMode          MODE_REVIVE - stopped the resurrection, MODE_PLANT - stopped planting
*
* @noreturn
*/
stock UTIL_ResetEntityThink(const eForward, const iEnt, const id, const iActivator, const Modes:eMode) {
	if(!is_nullent(iEnt)) {
		set_entvar(iEnt, var_nextthink, get_gametime() + 1.0);
		set_entvar(iEnt, var_iuser1, 0);
	}

	new iPlayerEnt = is_user_connected(id) ? id : RT_NULLENT;
	new iActivatorEnt = is_user_connected(iActivator) ? iActivator : RT_NULLENT;

	ExecuteForward(eForward, _, iEnt, iPlayerEnt, iActivatorEnt, eMode);
}

/**
* Notifying players in chat
*
* @param id             Player id or 0 to display to all clients
* @param iSender        Player id used as the message sender or color type
* @param szFmtRules     Formatting rules
*
* @noreturn
*/
stock UTIL_NotifyClient(const id, const iSender, const szFmtRules[], any:...) {
	new szMessage[192];
	SetGlobalTransTarget(id);
	vformat(szMessage, charsmax(szMessage), szFmtRules, 4);
	client_print_color(id, iSender, szMessage);
}