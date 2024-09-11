#include <amxmodx>
#include <reapi>
#include <hamsandwich>
#include <fakemeta>
#include <rt_api>

public stock const PLUGIN[] = "Revive Teammates: Model";
public stock const CFG_FILE[] = "addons/amxmodx/configs/rt_configs/rt_revive_model.cfg";

enum CVARS {
	MODEL_V[96],
};

new g_eCvars[CVARS];

public plugin_precache() {
	CreateCvars();

	server_cmd("exec %s", CFG_FILE);
	server_exec();

	if(g_eCvars[MODEL_V][0]) {
		precache_model(g_eCvars[MODEL_V]);
		UTIL_PrecacheSoundsFromModel(g_eCvars[MODEL_V]);
	}
}

public plugin_init() {
	register_plugin(PLUGIN, VERSION, "mx?!");

	if(g_eCvars[MODEL_V][0]) {
		RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "CBasePlayerWeapon_DefaultDeploy_Post", true);
	}
}

public plugin_cfg() {
	if(!g_eCvars[MODEL_V][0]) {
		return;
	}

	new pCvar = get_cvar_pointer("rt_force_fwd_mode"); // from rt_core.sma

	if(!pCvar) {
		return;
	}

	if(!get_pcvar_num(pCvar)) {
		set_pcvar_num(pCvar, 1);
		log_amx("Forcing 'rt_force_fwd_mode' cvar value to ^"1^" !");
	}
}

public rt_revive_start_post(const iEnt, const iPlayer, const iActivator, const Modes:eMode) {
	if(!g_eCvars[MODEL_V][0] || eMode != MODE_REVIVE) {
		return;
	}

	set_entvar(iActivator, var_viewmodel, g_eCvars[MODEL_V]);

	set_entvar(iActivator, var_weaponmodel, "");
	set_member(iActivator, m_szAnimExtention, "knife");

	const ANIM_DRAW = 3;
	SetWeaponAnim(iActivator, ANIM_DRAW);

	set_member(iActivator, m_flNextAttack, 9999.0);

	new pWeapon = get_member(iActivator, m_pActiveItem);
	if(pWeapon > 0) {
		set_member(pWeapon, m_Weapon_flTimeWeaponIdle, 9999.0);
		//set_member(pWeapon, m_Weapon_flNextPrimaryAttack, 9999.0);
		//set_member(pWeapon, m_Weapon_flNextSecondaryAttack, 9999.0);
	}
}

public rt_revive_loop_post(const iEnt, const iPlayer, const iActivator, const Float:fTimer, Modes:eMode) {
	const Float:fAnimTime = 0.6; // 23 frames / 30 fps = 0.766, но нам не нужна полная анимация, обрезаем 0.166
	const ANIM_USE = 1;

	new Float:fGameTime = get_gametime();
	new Float:fEndTime = fGameTime + fTimer;

	if(g_eCvars[MODEL_V][0] && eMode == MODE_REVIVE && fGameTime > (fEndTime - fAnimTime) && get_entvar(iActivator, var_weaponanim) != ANIM_USE) {
		SetWeaponAnim(iActivator, ANIM_USE);
	}
}

public rt_revive_cancelled(const iEnt, const iPlayer, const iActivator, const Modes:eMode) {
	if(eMode == MODE_REVIVE && iActivator != RT_NULLENT) {
		TryResetReviveModel(iActivator);
	}
}

public rt_revive_end(const iEnt, const iPlayer, const iActivator, const Modes:eMode) {
	if(eMode == MODE_REVIVE/* && iActivator != RT_NULLENT*/) {
		TryResetReviveModel(iActivator);
	}
}

TryResetReviveModel(pPlayer) {
	if(!g_eCvars[MODEL_V][0] || !IsRiviveModelActive(pPlayer)) {
		return;
	}

	new pWeapon = get_member(pPlayer, m_pActiveItem);

	if(!is_nullent(pWeapon)) {
		ExecuteHamB(Ham_Item_Deploy, pWeapon);
	}
}

bool:IsRiviveModelActive(pPlayer) {
/*
	if(!g_eCvars[MODEL_V][0]) {
		return false;
	}
*/

	static szModel[96]
	get_entvar(pPlayer, var_viewmodel, szModel, charsmax(szModel));

	return bool:equal(szModel, g_eCvars[MODEL_V]);
}

public CBasePlayerWeapon_DefaultDeploy_Post(pWeapon, szViewModel[], szWeaponModel[], iAnim, szAnimExt[], skiplocal) {
	if(!is_entity(pWeapon)) {
		return;
	}

	new pPlayer = get_member(pWeapon, m_pPlayer);

	if(rt_get_user_mode(pPlayer) == MODE_REVIVE) {
		rt_reset_use(pPlayer);
	}
}

CreateCvars() {
	bind_pcvar_string(create_cvar(
		"rt_revive_model_v",
		"",
		FCVAR_NONE,
		"1st persion view model for revive process"),
		g_eCvars[MODEL_V],
		charsmax(g_eCvars[MODEL_V])
	);
}

SetWeaponAnim(pPlayer, iAnimNum) {
	set_entvar(pPlayer, var_weaponanim, iAnimNum);

	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, .player = pPlayer);
	write_byte(iAnimNum); // sequence number
	write_byte(0); // weaponmodel bodygroup.
	message_end();
}

// Автопрекеш звуков из модели: https://dev-cs.ru/resources/914/field?field=source
stock UTIL_PrecacheSoundsFromModel(const szModelPath[])
{
    new iFile;

    if((iFile = fopen(szModelPath, "rt")))
    {
        new szSoundPath[64];

        new iNumSeq, iSeqIndex;
        new iEvent, iNumEvents, iEventIndex;

        fseek(iFile, 164, SEEK_SET);
        fread(iFile, iNumSeq, BLOCK_INT);
        fread(iFile, iSeqIndex, BLOCK_INT);

        for(new k, i = 0; i < iNumSeq; i++)
        {
            fseek(iFile, iSeqIndex + 48 + 176 * i, SEEK_SET);
            fread(iFile, iNumEvents, BLOCK_INT);
            fread(iFile, iEventIndex, BLOCK_INT);
            fseek(iFile, iEventIndex + 176 * i, SEEK_SET);

            for(k = 0; k < iNumEvents; k++)
            {
                fseek(iFile, iEventIndex + 4 + 76 * k, SEEK_SET);
                fread(iFile, iEvent, BLOCK_INT);
                fseek(iFile, 4, SEEK_CUR);

                if(iEvent != 5004)
                    continue;

                fread_blocks(iFile, szSoundPath, 64, BLOCK_CHAR);

                if(strlen(szSoundPath))
                {
                    strtolower(szSoundPath);
                    engfunc(EngFunc_PrecacheSound, szSoundPath);
                }
            }
        }
    }

    fclose(iFile);
}