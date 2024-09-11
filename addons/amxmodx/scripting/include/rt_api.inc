////////////////////////////////////
////////					////////
////	Revive Teammates API	////
////////					////////
////////////////////////////////////

#if defined _rt_api_included
	#endinput
#endif
#define _rt_api_included

public stock const VERSION[] = "2.3.14";
public stock const AUTHORS[] = "DEV-CS.RU Community";

/**
 * Invalid entity index
 */
#define RT_NULLENT -1

/**
 * The maximum buffer size required to store a chat message
 */
#define MAX_MESSAGE_LENGTH 192

/**
 * The maximum buffer size required to store a map's name
 */
#if !defined MAX_MAPNAME_LENGTH
	#define MAX_MAPNAME_LENGTH 64
#endif

/**
 * The maximum buffer size required to store a Hud/DHud colors
 */
#define MAX_COLORS_LENGTH 16

/**
 * The maximum buffer size required to store a Hud/DHud coordinates
 */
#define MAX_COORDS_LENGTH 16

/**
 * Types of resurrection
 */
enum Modes {
	MODE_NONE = 0,
	MODE_REVIVE,
	MODE_PLANT
};

/**
 * The classname of the corpse entity
 */
new const DEAD_BODY_CLASSNAME[] = "rt_corpse_empty";

/**
 * [PRE] Called after the activator starts resurrection/planting (on press USE - `E`)
 *
 * @param iEnt           Corpse entity index
 * @param iPlayer        Player id who can be ressurected
 * @param iActivator     Player id who ressurect
 * @param eMode          MODE_REVIVE - started the resurrection, MODE_PLANT - started planting
 *
 * @return               PLUGIN_CONTINUE to start resurrection/planting
 *                       PLUGIN_HANDLED to stop resurrection/planting
 */
forward rt_revive_start(const iEnt, const iPlayer, const iActivator, const Modes:eMode);

/**
 * [POST] Called after the activator starts resurrection/planting (on press USE - `E`)
 *
 * @note 			This forward will not be called if something was blocked attempt in rt_revive_start()
 *
 * @param iEnt           Corpse entity index
 * @param iPlayer        Player id who can be ressurected
 * @param iActivator     Player id who ressurect
 * @param eMode          MODE_REVIVE - started the resurrection, MODE_PLANT - started planting
 *
 * @noreturn
 */
forward rt_revive_start_post(const iEnt, const iPlayer, const iActivator, const Modes:eMode);

/**
 * PreThink on resurrection/planting
 *
 * @note                 Timer can be 0.0
 *
 * @param iEnt           Corpse entity index
 * @param iPlayer        Player id who can be ressurected
 * @param iActivator     Player id who ressurect
 * @param fTimer         Resurrection time
 * @param eMode          MODE_REVIVE - the player continues to be resurrected, MODE_PLANT - the player continues to be planted
 *
 * @return               PLUGIN_CONTINUE to continue resurrection/planting
 *                       PLUGIN_HANDLED to stop resurrection/planting
 */
forward rt_revive_loop_pre(const iEnt, const iPlayer, const iActivator, const Float:fTimer, Modes:eMode);

/**
 * PostThink on resurrection/planting
 *
 * @note                 Timer can't be 0.0
 *
 * @param iEnt           Corpse entity index
 * @param iPlayer        Player id who can be ressurected
 * @param iActivator     Player id who ressurect
 * @param fTimer         Resurrection time
 * @param eMode          MODE_REVIVE - the player continues to be resurrected, MODE_PLANT - the player continues to be planted
 *
 * @noreturn
 */
forward rt_revive_loop_post(const iEnt, const iPlayer, const iActivator, const Float:fTimer, Modes:eMode);

/**
 * Called after the resurrection/planting is ending
 *
 * @param iEnt           Corpse entity index
 * @param iPlayer        Player id who can be ressurected
 * @param iActivator     Player id who ressurect
 * @param eMode          MODE_REVIVE - the player was resurrected, MODE_PLANT - the player was planted
 *
 * @noreturn
 */
forward rt_revive_end(const iEnt, const iPlayer, const iActivator, const Modes:eMode);

/**
 * Called when the player has stopped resurrecting/planting
 *
 * @param iEnt           Corpse entity index
 * @param iPlayer        Player id who can be ressurected or RT_NULLENT
 * @param iActivator     Player id who ressurect or RT_NULLENT
 * @param eMode          MODE_REVIVE - stopped the resurrection, MODE_PLANT - stopped planting
 *
 * @noreturn
 */
forward rt_revive_cancelled(const iEnt, const iPlayer, const iActivator, const Modes:eMode);

/**
 * Called before a corpse is created
 *
 * @param iEnt           Corpse entity index
 * @param iPlayer        Player id whose corpse
 *
 * @return               PLUGIN_CONTINUE to continue the created of a corpse
 *                       PLUGIN_HANDLED to stop the created of a corpse
 */
forward rt_creating_corpse_start(const iEnt, const iPlayer);

/**
 * Called after the creation of the corpse is completed
 *
 * @param iEnt           Corpse entity index
 * @param iPlayer        Player id whose corpse
 * @param fVecOrigin     Coordinates of the corpse
 *
 * @noreturn
 */
forward rt_creating_corpse_end(const iEnt, const iPlayer, const Float:fVecOrigin[3]);

/**
 * Returns current user mode
 *
 * @note		In rt_revive_cancelled() and rt_revive_end() always return MODE_NONE
 *
 * @param iPlayer        Client index
 *
 * @return               see 'Modes' enum
 */
native Modes:rt_get_user_mode(iPlayer);

/**
 * Will interrupt the current process
 *
 * @param iPlayer        Client index
 *
 * @return               true if success, false otherwise
 */
native bool:rt_reset_use(iPlayer);

/**
 * Removal of corpses
 *
 * @param iPlayer        Player id whose corpse or 0 for all corpses
 * @param szClassName    Entity classname
 *
 * @return               Player id who is resurrecting or 0
 */
stock RemoveCorpses(const iPlayer = 0, const szClassName[] = DEAD_BODY_CLASSNAME) {
	new iEnt = RT_NULLENT;
	new iActivator, iOwner;

	while((iEnt = rg_find_ent_by_class(iEnt, szClassName)) > 0) {
		if(!is_nullent(iEnt)) {
			if(iPlayer && (iOwner = get_entvar(iEnt, var_owner)) != iPlayer)
				continue;

			if(iPlayer && iOwner == iPlayer)
				iActivator = get_entvar(iEnt, var_iuser1);

			set_entvar(iEnt, var_flags, FL_KILLME);
			set_entvar(iEnt, var_nextthink, 0.0);
			set_entvar(iEnt, var_iuser1, 0);

			if(iActivator)
				break;
		}
	}

	return iActivator;
}

/**
 * Notifying players in chat
 *
 * @param iPlayer        Player id or 0 to display to all clients
 * @param iSender        Player id used as the message sender or color type
 * @param szFmtRules     Formatting rules
 *
 * @noreturn
 */
stock NotifyClient(const iPlayer, const iSender, any:...) {
	new szMessage[MAX_MESSAGE_LENGTH];
	SetGlobalTransTarget(iPlayer);
	vformat(szMessage, charsmax(szMessage), "%l", 3);
	client_print_color(iPlayer, iSender, "%l %s", "RT_CHAT_TAG", szMessage);
}
