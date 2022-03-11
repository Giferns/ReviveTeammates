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
*
*/
forward rt_revive_start(const id, const activator);

/**
* Think on revive :: PRE
*
* @param id         player id who can be revived
* @param activator  player id who can revive
* @param timer      time to revive id
*
* @note Can stoped by return PLUGIN_HANDLED
*
*/
forward rt_revive_loop_pre(const id, const activator, const timer);

/**
* Think on revive :: POST
*
* @param id         player id who can be revived
* @param activator  player id who can revive
* @param timer      time to revive id
* @param nextthink  Next think on used entity (default value 1.0)
*
*/
forward rt_revive_loop_post(const id, const activator, const Float: timer, Float: &nextthink);

/**
* Called after revive has been ending
*
* @param id         player id who can be revived
* @param activator  player id who can revive
* @param success    true if revive successeed, false otherwise
*
*/
forward rt_revive_end(const id, const activator, bool: success);