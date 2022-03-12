#include <amxmodx>
#include <revive_teammates>

public stock const PluginName[]     = "Revive teammates: Nextthink";
public stock const PluginVersion[]  = "0.0.1";
public stock const PluginAuthor[]   = "m4ts";
public stock const PluginURL[]      = "https://github.com/ma4ts";

//TODO: move to cvar this
const MAX_ACTIVATORS            = 5;
const Float: REMOVE_THINK       = 0.2;

new g_iCurrentActivators[MAX_PLAYERS + 1];
new g_pActivators[MAX_PLAYERS + 1][MAX_ACTIVATORS];
new bool: g_bNextthinkCanBeUpped[MAX_PLAYERS + 1];

public rt_revive_start(const id, const activator)   {
    if (g_iCurrentActivators[id] >= MAX_ACTIVATORS)
        return PLUGIN_HANDLED;

    for (new i; i <= g_iCurrentActivators[id]; i++) {
        if (activator == g_pActivators[id][i])
            return PLUGIN_CONTINUE;
    }

    g_pActivators[id][g_iCurrentActivators[id]++] = activator;

    return PLUGIN_CONTINUE;
}

public rt_revive_loop_post(const id, const activator, const Float: timer, &Float: nextthink)    {
    if (g_bNextthinkCanBeUpped[id]) {
        g_bNextthinkCanBeUpped[id] = false;

        nextthink += REMOVE_THINK;
    }
    else if (g_iCurrentActivators[id] > 1)
        nextthink -= (float(g_iCurrentActivators[id]) * REMOVE_THINK);
}

public rt_revive_end(const id, const activator, bool: success)  {
    if (success)
        return;

    for (new i; i <= g_iCurrentActivators[id]; i++) {
        if (activator == g_pActivators[id][g_iCurrentActivators[id]])   {
            g_pActivators[id][g_iCurrentActivators[id]] = 0;
            g_iCurrentActivators[id]--;
            g_bNextthinkCanBeUpped[id] = true;
        }
    }
}

public plugin_init()    {
	register_plugin(PluginName, PluginVersion, PluginAuthor);
}