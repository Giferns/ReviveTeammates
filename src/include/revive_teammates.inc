//
// Revive teammates API
//

#if defined _revive_teammates_included
  #endinput
#endif
#define _revive_teammates_included

/**
* Called before activator starting the revive (on press USE - `E`)
*
* @param id         player id who can be revived
* @param activator  player id who can revive
*
* @note Can stoped by return PLUGIN_HANDLED
*/
forward rt_revive_start(const id, const activator);

/**
* Think on revive
*
* @param id         player id who can be revived
* @param activator  player id who can revive
* @param timer      time to revive id
*
* @note Can stoped by return PLUGIN_HANDLED
*/
forward rt_revive_loop(const id, const activator, const timer);

/**
* Called after revive has been ending
*
* @param id         player id who can be revived
* @param activator  player id who can revive
*/
forward rt_revive_end(const id, const activator);