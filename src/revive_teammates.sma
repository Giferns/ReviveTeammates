#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>

#pragma semicolon 1

public stock const PluginName[] = "Revive teammates: Core";
public stock const PluginVersion[] = "2.0.0";
public stock const PluginAuthor[] = "m4ts";
public stock const PluginURL[] = "https://github.com/ufame";

new const DEAD_BODY_CLASSNAME[] = "deathbody";
new const DEAD_BODY_CLASSNAME_EMPTY[] = "deathbody_empty";

const Float: DEFAULT_TIME_NEXTTHINK = 1.0;
const Float: DEFAULT_TIME_ANTIFLOOD = 1.0;
const Float: DEFAULT_TIME_RESCUE = 10.0;

new Float: g_flLastUse[MAX_PLAYERS + 1];

public plugin_init() {
    #if AMXX_VERSION_NUM < 200
        register_plugin(PluginName, PluginVersion, PluginAuthor, PluginURL);
    #endif

    RegisterHam(Ham_ObjectCaps, "info_target", "HamHook_ObjectCaps_Pre", .Post = 0);
    RegisterHookChain(RG_CSGameRules_CleanUpMap, "CSGameRules_CleanUpMap_Post", .post = 1);

    register_message(get_user_msgid("ClCorpse"), "MessageHook_ClCorpse");
}

public HamHook_ObjectCaps_Pre(const iEntity) {
    if (!FClassnameIs(iEntity, DEAD_BODY_CLASSNAME))
        return HAM_IGNORED;

    SetHamReturnInteger(FCAP_ONOFF_USE);

    return HAM_OVERRIDE;
}

public CSGameRules_CleanUpMap_Post() {
    UTIL_RemoveAllEnts();
}

public EntityHook_Use(const iEnt, const iActivator, const iCaller, const USE_TYPE: eUseType, Float: flValue) {
    if (is_nullent(iEnt))
        return;

    if (get_member_game(m_bRoundTerminating))
        return;

    if (iActivator != iCaller)
        return;

    if (!ExecuteHam(Ham_IsPlayer, iActivator))
        return;

    new Float: flTimer = DEFAULT_TIME_RESCUE;
    new iPlayer = get_entvar(iEnt, var_owner);

    if (get_member(iActivator, m_iTeam) != get_member(iPlayer, m_iTeam))
        return;

    new Float: flGameTime = get_gametime();

    if ((g_flLastUse[iActivator] + DEFAULT_TIME_ANTIFLOOD) > flGameTime)
        return;

    new Array: aResurrectionists = get_entvar(iEnt, var_iuser1);

    if (!aResurrectionists)
        aResurrectionists = ArrayCreate();

    if (!ArraySize(aResurrectionists))
        set_entvar(iEnt, var_fuser1, flTimer);

    ArrayPushCell(aResurrectionists, iActivator);
    set_entvar(iEnt, var_iuser1, aResurrectionists);

    g_flLastUse[iActivator] = flGameTime;
}

public EntityHook_Think(const iEnt) {
    if (is_nullent(iEnt))
        return;

    new iPlayer = get_entvar(iEnt, var_owner);
    new Array: aResurrectionists = get_entvar(iEnt, var_iuser1);

    if (!is_user_connected(iPlayer) || is_user_alive(iPlayer) || get_member(iPlayer, m_iTeam) == TEAM_SPECTATOR)
    {
        SetUse(iEnt, "");
        SetThink(iEnt, "");

        UTIL_RemoveAllEnts(iPlayer);

        return;
    }

    new Float: flNextThink = DEFAULT_TIME_NEXTTHINK;
    new iListSize = ArraySize(aResurrectionists);

    if (!aResurrectionists || !iListSize)
    {
        set_entvar(iEnt, var_nextthink, get_gametime() + flNextThink);

        return;
    }

    new Float: flTimeUntil = get_entvar(iEnt, var_fuser1);

    for (new i, iResurrectionist; i < iListSize; i++)
    {
        iResurrectionist = ArrayGetCell(aResurrectionists, i);

        if (!(get_entvar(iResurrectionist, var_button) & IN_USE))
        {
            ArrayDeleteItem(aResurrectionists, i);

            continue;
        }

        if (--flTimeUntil <= 0.0)
        {
            rg_round_respawn(iPlayer);

            new Float: flOrigin[3];
            get_entvar(iEnt, var_origin, flOrigin);

            flOrigin[2] += 30.0;
            engfunc(EngFunc_SetOrigin, iPlayer, flOrigin);

            SetUse(iEnt, "");
            SetThink(iEnt, "");
            UTIL_RemoveAllEnts(iPlayer);

            return;
        }
    }

    set_entvar(iEnt, var_fuser1, flTimeUntil);
    set_entvar(iEnt, var_nextthink, get_gametime() + flNextThink);
}

public MessageHook_ClCorpse() {
    new iEntity = rg_create_entity("info_target");

    if (is_nullent(iEntity))
        return PLUGIN_CONTINUE;

    enum
    {
        arg_model = 1,

        arg_coord_x,
        arg_coord_y,
        arg_coord_z,

        arg_angle_x,
        arg_angle_y,
        arg_angle_z,

        arg_delay,
        arg_sequence,
        arg_class_id,
        arg_team_id,

        arg_player_id
    };

    #pragma unused arg_delay, arg_team_id

    enum coords_struct
    {
        Float: coord_x,
        Float: coord_y,
        Float: coord_z
    };

    enum entity_struct
    {
        entity_coords[coords_struct],
        entity_angles[coords_struct]
    };

    new flEntityData[entity_struct];

    //https://github.com/s1lentq/ReGameDLL_CS/blob/c002edd5b18a8408e299bc6cccfec2c7de56ba3d/regamedll/dlls/player.cpp#L8721
    flEntityData[entity_coords][coord_x] = float(get_msg_arg_int(arg_coord_x) / 128);
    flEntityData[entity_coords][coord_y] = float(get_msg_arg_int(arg_coord_y) / 128);
    flEntityData[entity_coords][coord_z] = float(get_msg_arg_int(arg_coord_z) / 128);

    flEntityData[entity_angles][coord_x] = get_msg_arg_float(arg_angle_x);
    flEntityData[entity_angles][coord_y] = get_msg_arg_float(arg_angle_y);
    flEntityData[entity_angles][coord_z] = get_msg_arg_float(arg_angle_z);

    new szTemp[MAX_RESOURCE_PATH_LENGTH], szModel[MAX_RESOURCE_PATH_LENGTH];

    get_msg_arg_string(arg_model, szTemp, charsmax(szTemp));
    formatex(szModel, charsmax(szModel), "models/player/%s/%s.mdl", szTemp, szTemp);

    new iPlayer = get_msg_arg_int(arg_player_id);

    if (!is_user_connected(iPlayer))
        return PLUGIN_CONTINUE;

    engfunc(EngFunc_SetModel, iEntity, szModel);
    engfunc(EngFunc_SetOrigin, iEntity, flEntityData[entity_coords]);

    set_entvar(iEntity, var_classname, DEAD_BODY_CLASSNAME_EMPTY);
    set_entvar(iEntity, var_angles, flEntityData[entity_angles]);
    set_entvar(iEntity, var_body, get_msg_arg_int(arg_class_id));
    set_entvar(iEntity, var_skin, get_entvar(iPlayer, var_skin));
    set_entvar(iEntity, var_sequence, get_msg_arg_int(arg_sequence));
    set_entvar(iEntity, var_owner, iPlayer);

    new iUsabillityEntity = rg_create_entity("info_target");

    if (is_nullent(iUsabillityEntity))
        return PLUGIN_CONTINUE;

    set_entvar(iUsabillityEntity, var_classname, DEAD_BODY_CLASSNAME);
    set_entvar(iUsabillityEntity, var_framerate, 1.0);
    set_entvar(iUsabillityEntity, var_owner, iPlayer);

    set_entvar(iEntity, var_nextthink, get_gametime() + 0.01);

    SetUse(iEntity, "EntityHook_Use");
    SetThink(iEntity, "EntityHook_Think");

    return PLUGIN_HANDLED;
}

stock UTIL_RemoveAllEnts(iPlayer = 0) {
    new iEntity = NULLENT;
    new Array: aResurrectionists;

    while ((iEntity = rg_find_ent_by_class(iEntity, DEAD_BODY_CLASSNAME)) > 0)
    {
        if (iPlayer && get_entvar(iEntity, var_owner) != iPlayer)
            continue;

        aResurrectionists = get_entvar(iEntity, var_iuser1);

        if (aResurrectionists)
            ArrayDestroy(aResurrectionists);
        
        engfunc(EngFunc_RemoveEntity, iEntity);
    }

    while ((iEntity = rg_find_ent_by_class(iEntity, DEAD_BODY_CLASSNAME_EMPTY)) > 0)
    {
        if (iPlayer && get_entvar(iEntity, var_owner) != iPlayer)
            continue;

        engfunc(EngFunc_RemoveEntity, iEntity);
    }
}
