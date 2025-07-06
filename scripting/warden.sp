#include <basecomm>
#include <cstrike>
#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <warden>

#undef REQUIRE_EXTENSIONS
#include <sourcescramble>
#define REQUIRE_EXTENSIONS

#undef REQUIRE_PLUGINS
#include <hosties>
#define REQUIRE_PLUGINS

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION   "4.3.0"
#define TRANSLATION_PREFIX "{lightblue}[Warden] {white}%t"

// notfoundname: I tried searching for enum struct but it does not seem to exist.
#define COLLISION_GROUP_DEBRIS_TRIGGER 2
#define COLLISION_GROUP_PLAYER 5

int Warden = -1;

bool bNoblock = true;
ConVar conVarMpFriendlyFire;
ConVar conVarSvAutoBunnyHopping;
Handle hMuteTimer = null;
Menu hWardenMenu = null;
bool bWardenMenuOpened = false;
int iLaserEndGlow = 0;

#undef REQUIRE_EXTENSIONS
Handle g_hRagdoll;
int g_iRagdolls[64];
MemoryBlock memory;
#define REQUIRE_EXTENSIONS

ConVar conVarBetterNotifications, 
    conVarMuteTime,
    conVarNoblockDefault,
    conVarBhopDefault,
    conVarSplitPlayersRadius,
    conVarEnhanceRagdolls;
Handle forwardOnWardenCreation, forwardOnWardenRemoved;

public Plugin myinfo = {
    name = "Jailbreak Warden",
    author = "ecca, notfoundname, ByDexter",
    description = "Updated Jailbreak Warden Plugin",
    version = PLUGIN_VERSION,
    url = "https://github.com/notfoundname/Warden/"
};

public void OnPluginStart() {
    // Initialize our phrases.
    LoadTranslations("common.phrases");
    LoadTranslations("warden.phrases");
    
    // Register our public commands.
    RegConsoleCmd("sm_c", BecomeWarden);
    RegConsoleCmd("sm_commander", BecomeWarden);
    RegConsoleCmd("sm_w", BecomeWarden);
    RegConsoleCmd("sm_warden", BecomeWarden);
    
    RegConsoleCmd("sm_uc", ExitWarden);
    RegConsoleCmd("sm_uncommander", ExitWarden);
    RegConsoleCmd("sm_uw", ExitWarden);
    RegConsoleCmd("sm_unwarden", ExitWarden);
    
    // Register Warden-only commands.
    RegConsoleCmd("sm_wnoblock", ToggleNoblock);
    RegConsoleCmd("sm_wnb", ToggleNoblock);
    ConVar conVarHostiesNoBlock = FindConVar("sm_hosties_noblock_enable");
    if (conVarHostiesNoBlock != null) {
        conVarHostiesNoBlock.BoolValue = false;
    }
    
    RegConsoleCmd("sm_wmute", TempMute);
    RegConsoleCmd("sm_wm", TempMute);
    
    conVarMpFriendlyFire = FindConVar("mp_friendlyfire");
    RegConsoleCmd("sm_wfriendlyfire", FriendlyFire);
    RegConsoleCmd("sm_wff", FriendlyFire);
    
    conVarSvAutoBunnyHopping = FindConVar("sv_autobunnyhopping");
    RegConsoleCmd("sm_wbhop", AutoBunnyHopping);
    RegConsoleCmd("sm_wbh", AutoBunnyHopping);
    
    RegConsoleCmd("sm_wsplitplayers", SplitPlayers);
    RegConsoleCmd("sm_wsp", SplitPlayers);

    // For our warden to look some extra cool.
    RegConsoleCmd("say", WardenSay);
    
    // Create menus.
    hWardenMenu = new Menu(WardenMenu_Handler, MenuAction_Display|MenuAction_Select|MenuAction_Cancel|MenuAction_End);
    
    // Register our admin commands.
    RegAdminCmd("sm_hc", HireWarden, ADMFLAG_GENERIC, "sm_hc <#userid|name>");
    RegAdminCmd("sm_hirecommander", HireWarden, ADMFLAG_GENERIC, "sm_hirecommander <#userid|name>");
    RegAdminCmd("sm_hirewarden", HireWarden, ADMFLAG_GENERIC, "sm_hirewarden <#userid|name>");
    RegAdminCmd("sm_hw", HireWarden, ADMFLAG_GENERIC, "sm_hw <#userid|name>");
    RegAdminCmd("sm_rc", RemoveWarden, ADMFLAG_GENERIC, "sm_rc");
    RegAdminCmd("sm_removecommander", RemoveWarden, ADMFLAG_GENERIC, "sm_removecommander");
    RegAdminCmd("sm_removewarden", RemoveWarden, ADMFLAG_GENERIC, "sm_removewarden");
    RegAdminCmd("sm_rw", RemoveWarden, ADMFLAG_GENERIC, "sm_rw");
    
    // Display current warden on top of the screen.
    CreateTimer(1.0, DisplayCurrentWarden, _, TIMER_REPEAT);
    
    // Laser.
    iLaserEndGlow = PrecacheModel("materials/sprites/glow01.vmt", true);
    
    // Precache sounds.
    PrecacheSound("vo/npc/female01/runforyourlife01.wav", true);
    PrecacheSound("physics/metal/chain_impact_soft2.wav", true);
    PrecacheSound("physics/metal/chain_impact_hard1.wav", true);
    PrecacheSound("buttons/weapon_cant_buy.wav", true);
    
    // Hooking the events.
    HookEvent("round_start", Event_RoundStart); // For the round start
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre); // To check when our warden dies :)
    HookEvent("player_spawn", Event_PlayerSpawn);
    
    // Console variables.
    conVarBetterNotifications = CreateConVar("sm_warden_better_notifications", "1", "0 - disabled, 1 - Will display center text.", FCVAR_NONE, true, 0.0, true, 1.0);
    conVarMuteTime = CreateConVar("sm_warden_mute_time", "20", "For how long warden can mute players.", FCVAR_NONE, true, 5.0, true, 60.0);
    conVarNoblockDefault = CreateConVar("sm_warden_noblock_default", "1", "0 - start with player collisions, 1 - start with no collisions.", FCVAR_NONE, true, 0.0, true, 1.0);
    conVarBhopDefault = CreateConVar("sm_warden_bhop_default", "0", "0 - start with no bhop, 1 - start with bhop.", FCVAR_NONE, true, 0.0, true, 1.0);
    conVarSplitPlayersRadius = CreateConVar("sm_warden_splitplayers_radius", "512", "Radius of searching for splitting players into two teams. 0 to not care.", FCVAR_NONE, true, 0.0, true, 4096.0);
    conVarEnhanceRagdolls = CreateConVar("sm_warden_enhance_ragdolls", "1", "1 - Force ragdolls to be server-side and keep player's info, like colour and gravity. Requires SourceScramble.", FCVAR_NONE, true, 0.0, true, 1.0);

    // Initialize config.
    AutoExecConfig(true);
    
    // May not touch this line.
    CreateConVar("sm_warden_version", PLUGIN_VERSION, "The version of the SourceMod plugin JailBreak Warden.", FCVAR_SPONLY|FCVAR_DONTRECORD|FCVAR_REPLICATED|FCVAR_NOTIFY);
}

public void OnAllPluginsLoaded() {
    #undef REQUIRE_EXTENSIONS
    if (conVarEnhanceRagdolls.BoolValue) {
        memory = new MemoryBlock(0x4C);
    
        Handle hData = LoadGameConfigFile("warden.game");

        StartPrepSDKCall(SDKCall_Static);
        PrepSDKCall_SetFromConf(hData, SDKConf_Signature, "CreateServerRagdoll");
        PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
        PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
        PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
        PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
        PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
        PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
        g_hRagdoll = EndPrepSDKCall();        

        delete hData;
    }
    #define REQUIRE_EXTENSIONS
}

// ---
// Commands.
// ---

// sm_c / sm_w.
public Action BecomeWarden(int iClient, int iArgs) {
    if (Warden != -1) {
        // The warden already exist so there is no point setting a new one
        if (iClient == Warden) {
            WardenMenu_Refresh(iClient);
        } else {
            CPrintToChat(iClient, TRANSLATION_PREFIX, "warden_exist", Warden);
        }
        return Plugin_Handled;
    }
    
    if (GetClientTeam(iClient) != CS_TEAM_CT) {
        // Would be weird if an terrorist would run the prison wouldn't it :p
        CPrintToChat(iClient, TRANSLATION_PREFIX, "warden_ctsonly");
        return Plugin_Handled;
    }
    
    if (!IsPlayerAlive(iClient)) {
        // Grr he is not alive -.-
        CPrintToChat(iClient, TRANSLATION_PREFIX, "warden_playerdead");
        return Plugin_Handled;
    }
    
    SetTheWarden(iClient, true);
    
    return Plugin_Handled;
}

// sm_uc / sm_uw.
public Action ExitWarden(int iClient, int iArgs) {
    // Make sure executor is the Warden.
    if (iClient != Warden) {
        CPrintToChat(iClient, TRANSLATION_PREFIX, "warden_notwarden");
        return Plugin_Handled;
    }
    
    // Open for a new warden.
    Warden = -1;
    
    // API.
    Forward_OnWardenRemoved(iClient);
    
    CPrintToChatAll(TRANSLATION_PREFIX, "warden_retire", iClient);
    if (conVarBetterNotifications.BoolValue) {
        PrintCenterTextAll("%t", "warden_retire", iClient);
    }
    
    return Plugin_Handled;
}

// sm_noblock / sm_nb.
public Action ToggleNoblock(int iClient, int iArgs) {
    // Make sure executor is the Warden or an admin.
    if (!(iClient == Warden || GetAdminFlag(GetUserAdmin(iClient), ADMFLAG_GENERIC, Access_Real))) {
        CPrintToChat(iClient, TRANSLATION_PREFIX, "warden_notwarden");
        return Plugin_Handled;
    }
    
    // Toggle the value and apply it.
    bNoblock = !bNoblock;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsValidClient(i)) {
            PlayerApplyNoblock(i, true);
            ClientCommand(i, bNoblock ? "play physics/metal/chain_impact_soft2.wav" : "play buttons/weapon_cant_buy.wav");
        }
    }
    
    return Plugin_Handled;
}

public void PlayerApplyNoblock(int iClient, bool bCommand) {
    if (!IsValidClient(iClient)) {
        return;
    }
    
    SetEntityCollisionGroup(iClient, bNoblock ? COLLISION_GROUP_DEBRIS_TRIGGER : COLLISION_GROUP_PLAYER);
    if (bCommand) {
        CPrintToChat(iClient, TRANSLATION_PREFIX, bNoblock ? "warden_noblock_enabled" : "warden_noblock_disabled");
    }
}

// sm_wmute / sm_wm.
public Action TempMute(int iClient, int iArgs) {
    // Make sure executor is the Warden or an admin.
    if (!(iClient == Warden || GetAdminFlag(GetUserAdmin(iClient), ADMFLAG_GENERIC, Access_Real))) {
        CPrintToChat(iClient, TRANSLATION_PREFIX, "warden_notwarden");
        return Plugin_Handled;
    }

    // If the timer is active then force it to trigger.
    if (IsValidHandle(hMuteTimer)) {
        TriggerTimer(hMuteTimer, true);
    } else {
        MuteTerrorists(conVarMuteTime.FloatValue);
    }
    return Plugin_Handled;
}

public void TempMuteTimer(Handle timer) {
    UnmuteTerrorists();
    // Doing this to update the menu.
    hMuteTimer = null;
    if (bWardenMenuOpened) {
        WardenMenu_Refresh(Warden);
    }
}

public void MuteTerrorists(float iDuration) {
    hMuteTimer = CreateTimer(iDuration, TempMuteTimer);
    for (int i = 1; i <= MaxClients; i++) {
        if (IsValidClient(i)) {
            CPrintToChat(i, TRANSLATION_PREFIX, "warden_mute_enabled", iDuration);
            if (GetClientTeam(i) == CS_TEAM_T && !BaseComm_IsClientMuted(i)) {
                SetClientListeningFlags(i, VOICE_MUTED);
            }
        }
    }
}

public void UnmuteTerrorists() {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsValidClient(i)) {
            CPrintToChat(i, TRANSLATION_PREFIX, "warden_mute_disabled", conVarMuteTime.FloatValue);
            if (GetClientTeam(i) == CS_TEAM_T && !BaseComm_IsClientMuted(i)) {
                SetClientListeningFlags(i, VOICE_NORMAL);
            }
        }
    }
}

// sm_wmute / sm_wm.
public Action FriendlyFire(int iClient, int iArgs) {
    // Make sure executor is the Warden or an admin.
    if (!(iClient == Warden || GetAdminFlag(GetUserAdmin(iClient), ADMFLAG_GENERIC, Access_Real))) {
        CPrintToChat(iClient, TRANSLATION_PREFIX, "warden_notwarden");
        return Plugin_Handled;
    }
    
    conVarMpFriendlyFire.SetBool(!conVarMpFriendlyFire.BoolValue, true, false);
    CPrintToChatAll(TRANSLATION_PREFIX,
            conVarMpFriendlyFire.BoolValue ? "warden_friendlyfire_enabled" : "warden_friendlyfire_disabled");
    for (int i = 1; i <= MaxClients; i++) {
        if (IsValidClient(i)) {
            ClientCommand(i, conVarMpFriendlyFire.BoolValue ? "play vo/npc/female01/runforyourlife01.wav" : "play buttons/weapon_cant_buy.wav");
        }
    }
    

    return Plugin_Handled;
}

// sm_wbhop / sm_wbh.
public Action AutoBunnyHopping(int iClient, int iArgs) {
    // Make sure executor is the Warden or an admin.
    if (!(iClient == Warden || GetAdminFlag(GetUserAdmin(iClient), ADMFLAG_GENERIC, Access_Real))) {
        CPrintToChat(iClient, TRANSLATION_PREFIX, "warden_notwarden");
        return Plugin_Handled;
    }

    conVarSvAutoBunnyHopping.SetBool(!conVarSvAutoBunnyHopping.BoolValue, true, false);
        CPrintToChatAll(TRANSLATION_PREFIX,
                conVarSvAutoBunnyHopping.BoolValue ? "warden_bhop_enabled" : "warden_bhop_disabled");
    
    return Plugin_Handled;
}

// sm_wsp / sm_wsplitplayers
public Action SplitPlayers(int iClient, int iArgs) {
    // Make sure executor is the Warden or an admin.
    if (!(iClient == Warden || GetAdminFlag(GetUserAdmin(iClient), ADMFLAG_GENERIC, Access_Real))) {
        CPrintToChat(iClient, TRANSLATION_PREFIX, "warden_notwarden");
        return Plugin_Handled;
    }

    bool bRed = true;
    int playerCount = 0;
    if (conVarSplitPlayersRadius.FloatValue <= 0.0) {
        for (int i = 1; i <= MaxClients; i++) {
            // If our client is valid then put him into a team.
            if (IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) == CS_TEAM_T) {
                SetEntityRenderColor(i, bRed ? 255 : 0, 0, bRed ? 0 : 255, 255);
                CPrintToChat(i, TRANSLATION_PREFIX, "warden_team_chosen", 
                        bRed ? "warden_team_red" : "warden_team_blue");
                bRed = !bRed;
                playerCount++;
            }
        }
    } else {
        ArrayList entities = new ArrayList();
        float fOrigin[3];
        GetClientEyePosition(iClient, fOrigin);
    
        TR_EnumerateEntitiesSphere(fOrigin, conVarSplitPlayersRadius.FloatValue, PARTITION_NON_STATIC_EDICTS, AddEntities, entities);
        
        for (int i = 0; i < entities.Length; i++) {
            int iEntity = entities.Get(i);
        
            // If our client is valid then put him into a team.
            if (IsValidClient(iEntity) && IsPlayerAlive(iEntity) && GetClientTeam(iEntity) == CS_TEAM_T) {
                SetEntityRenderColor(iEntity, bRed ? 255 : 0, 0, bRed ? 0 : 255, 255);
                CPrintToChat(iEntity, TRANSLATION_PREFIX, "warden_team_chosen", 
                        bRed ? "warden_team_red" : "warden_team_blue");
                bRed = !bRed;
                playerCount++;
            }
        }
    }
    if (playerCount != 0) {
        CPrintToChat(iClient, TRANSLATION_PREFIX, "warden_team_split");
    } else {
        CPrintToChat(iClient, TRANSLATION_PREFIX, "No matching client");
    }
    
    return Plugin_Handled;
}

bool AddEntities(int iEntity, ArrayList entities) {
    entities.Push(iEntity);
    return true;
}

// sm_hirewarden <#userid|name>.
public Action HireWarden(int iClient, int iArgs) {
    if (iArgs < 1) {
        CPrintToChat(iClient, TRANSLATION_PREFIX, "No matching client");
        return Plugin_Handled;
    }
    
    char szName[128];
    GetCmdArgString(szName, sizeof(szName));
    
    int iTarget = FindTarget(iClient, szName, false, false);
    
    if (!IsValidClient(iTarget)) {
        CPrintToChat(iClient, TRANSLATION_PREFIX, "No matching client");
        return Plugin_Handled;
    }
    
    if (GetClientTeam(iTarget) != CS_TEAM_CT) {
        CPrintToChat(iClient, TRANSLATION_PREFIX, "warden_ctsonly");
        return Plugin_Handled;
    }
    
    if (!IsPlayerAlive(iTarget)) {
        CPrintToChat(iClient, TRANSLATION_PREFIX, "warden_playerdead");
        return Plugin_Handled;
    }
    
    // Is there a warden at the moment?
    if (Warden != -1) {
        RemoveTheWarden(iClient, false);
    }
    
    // Make our valid target the warden.
    SetTheWarden(iTarget, false);
    
    CPrintToChatAll(TRANSLATION_PREFIX, "warden_hired", iClient, Warden);
    if (conVarBetterNotifications.BoolValue) {
        PrintCenterTextAll("%t", "warden_hired", iClient, Warden);
    }
    
    // Prevent sourcemod from typing "unknown command" in console.
    return Plugin_Handled;
}

// sm_removewarden
public Action RemoveWarden(int iClient, int iArgs) {
    // Is there a warden at the moment?
    if (Warden != -1) {
        RemoveTheWarden(iClient, true);
    } else {
        CPrintToChatAll(TRANSLATION_PREFIX, "warden_noexist");
    }
    
    // Prevent sourcemod from typing "unknown command" in console.
    return Plugin_Handled;
}

// ---
// Display current warden on top right corner of the screen.
// ---

Action DisplayCurrentWarden(Handle hTimer) {
    Handle hHudMessage = CreateHudSynchronizer();
    
    if (IsValidClient(Warden)) {
        SetHudTextParams(1.5, -1.7, 1.0, 173, 216, 230, 255);
    } else {
        SetHudTextParams(1.5, -1.7, 1.0, 255, 0, 0, 255);
    }

    for (int i = 1; i <= MaxClients; i++) {
        if (IsValidClient(i)) {
            char szBuffer[256];

            if (IsValidClient(Warden)) {
                Format(szBuffer, sizeof(szBuffer), "%T  ", "warden_exist", i, Warden);
            } else {
                Format(szBuffer, sizeof(szBuffer), "%T  ", "warden_missing", i);
            }
            
            ShowSyncHudText(i, hHudMessage, szBuffer);
        }
    }
    
    CloseHandle(hHudMessage);
    return Plugin_Continue;
}

// ---
// Laser.
// ---

public void OnPlayerRunCmdPre(int iClient, int iButtons, int iImpulse, const float fVel[3], const float fAngles[3]) {
    if (iClient == Warden) {
        if (IsValidClient(iClient) && IsPlayerAlive(iClient)) {
            if (iButtons & IN_USE) {
                float fOrigin[3], fEnd[3];
                GetClientEyePosition(iClient, fOrigin);
                TR_TraceRayFilter(fOrigin, fAngles, MASK_SHOT, RayType_Infinite, TraceFilter_Callback, iClient);
                if (TR_DidHit()) {
                    TR_GetEndPosition(fEnd);

                    // Glowing end.
                    TE_SetupGlowSprite(fEnd, iLaserEndGlow, 0.001, 1.0, 255);

                    TE_SendToAll();
                }
            }
        }
    }
}

bool TraceFilter_Callback(int iEntity, int iMask) { 
    return (iEntity > MaxClients || !iEntity);
}

// ---
// Event hooks.
// ---

public Action Event_RoundStart(Handle event, const char[] name, bool bDontBroadcast) {
    // Let's remove the current warden if he exists.
    Warden = -1;

    // Laser.
    iLaserEndGlow = PrecacheModel("materials/sprites/glow01.vmt", false);
    
    bNoblock = conVarNoblockDefault.BoolValue;
    
    // If the timer is active then kill it (don't trigger it).
    if (IsValidHandle(hMuteTimer)) {
        KillTimer(hMuteTimer, true);
    }
    
    conVarMpFriendlyFire.SetBool(false, true, false);
    conVarSvAutoBunnyHopping.SetBool(conVarBhopDefault.BoolValue, true, false);
    
    // Make last remaining CT a Warden.
    if (GetTeamAliveCount(CS_TEAM_CT) == 1) {
        SetTheWarden(GetFirstAlivePlayerOnTeam(CS_TEAM_CT), true);
    }
    
    return Plugin_Continue;
}

public Action Event_PlayerDeath(Handle event, const char[] name, bool bDontBroadcast) {
    // Get the dead client's id.
    int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
    
    if (!IsValidClient(iClient)) {
        return Plugin_Continue;
    }

    // Aww damn, he is the warden.
    if (iClient == Warden) {
        CPrintToChatAll(TRANSLATION_PREFIX, "warden_dead", Warden);
        if (conVarBetterNotifications.BoolValue) {
            PrintCenterTextAll("%t", "warden_dead", Warden);
        }
        RemoveTheWarden(iClient, false);
        
        // Make last remaining CT a Warden.
        if (GetTeamAliveCount(CS_TEAM_CT) == 1) {
            SetTheWarden(GetFirstAlivePlayerOnTeam(CS_TEAM_CT), true);
        }
    }

    #undef REQUIRE_EXTENSIONS
    if (conVarEnhanceRagdolls.BoolValue) {
        int iRagdoll = SDKCall(g_hRagdoll, iClient, GetEntProp(iClient, Prop_Send, "m_nForceBone"), memory.Address, 3, true);
        SetEntPropEnt(iRagdoll, Prop_Send, "m_hOwnerEntity", iClient);

        g_iRagdolls[GetIndex()] = EntIndexToEntRef(iRagdoll);

        int iColor[4];
        float fGravity = GetEntityGravity(iClient);
        GetEntityRenderColor(iClient, iColor[0], iColor[1], iColor[2], iColor[3]);

        SetEntProp(iRagdoll, Prop_Data, "m_nRenderMode", 1);
        SetEntProp(iRagdoll, Prop_Data, "m_clrRender", iColor);
        SetEntPropFloat(iRagdoll, Prop_Data, "m_flGravity", fGravity);
    }
    #define REQUIRE_EXTENSIONS
    
    return Plugin_Continue;
}

int GetIndex (int iClient = -1) {
    int iEntity;
    
    if (iClient != -1) {
        for (int i = 0; i < 64; i++) {
            if ((iEntity = EntRefToEntIndex(g_iRagdolls[i])) <= 0 || !IsValidEntity(iEntity))
                continue;
                
            if (iClient == GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity")) {
                g_iRagdolls[i] = 0;
                return iEntity;
            }
        }
        
        return -1;
    }
    
    for (int i = 0; i < 64; i++) {
        if ((iEntity = EntRefToEntIndex(g_iRagdolls[i])) > 0 && IsValidEntity(iEntity))
            continue;

        return i;
    }
    
    return -1;
}

public Action Event_PlayerSpawn(Handle event, const char[] name, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
    if (IsValidClient(iClient)) {
        PlayerApplyNoblock(iClient, false);
    }
}

public void OnClientDisconnect_Post(int iClient) {
    // The warden disconnected, action!
    if (iClient == Warden) {
        CPrintToChatAll(TRANSLATION_PREFIX, "warden_disconnected");
        if (conVarBetterNotifications.BoolValue) {
            PrintCenterTextAll("%t", "warden_disconnected");
        }
        RemoveTheWarden(iClient, false);
        
        // Make last remaining CT a Warden.
        if (GetTeamAliveCount(CS_TEAM_CT) == 1) {
            SetTheWarden(GetFirstAlivePlayerOnTeam(CS_TEAM_CT), true);
        }
    }
}

// Warden chat hook.
public Action WardenSay(int iClient, int iArgs) {
    // Check so the player typing is a warden and also checking so the client isn't the console!
    if (Warden == iClient && IsValidClient(iClient)) {
        char szMessage[256];
        GetCmdArgString(szMessage, sizeof(szMessage));
        StripQuotes(szMessage);
        if (szMessage[0] == '/' || szMessage[0] == '@' || IsChatTrigger()) {
            // Prevent unwanted text to be displayed.
            return Plugin_Handled;
        }
        CPrintToChatAll("%t", "warden_chat", iClient, szMessage);
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}

// ---
// Menus.
// ---

public void WardenMenu_Refresh(int iClient) {
    if (!IsValidHandle(hWardenMenu) || iClient == -1) {
        return;
    }
    
    hWardenMenu.RemoveAllItems();
    char szBuffer[128];
    
    Format(szBuffer, sizeof(szBuffer), "%T", "warden_menu_title", iClient);
    hWardenMenu.SetTitle(szBuffer);
    
    Format(szBuffer, sizeof(szBuffer), "%T", "warden_menu_noblock", iClient, 
            bNoblock ? "warden_enabled" : "warden_disabled");
    hWardenMenu.AddItem("warden_menu_noblock", szBuffer);
    
    Format(szBuffer, sizeof(szBuffer), "%T", "warden_menu_friendlyfire", iClient, 
            conVarMpFriendlyFire.BoolValue ? "warden_enabled" : "warden_disabled");
    hWardenMenu.AddItem("warden_menu_friendlyfire", szBuffer);
    
    Format(szBuffer, sizeof(szBuffer), "%T", "warden_menu_bhop", iClient, 
            conVarSvAutoBunnyHopping.BoolValue ? "warden_enabled" : "warden_disabled");
    hWardenMenu.AddItem("warden_menu_bhop", szBuffer);
    
    Format(szBuffer, sizeof(szBuffer), "%T", "warden_menu_mute", iClient, conVarMuteTime.FloatValue, 
            IsValidHandle(hMuteTimer) ? "warden_enabled" : "warden_disabled");
    hWardenMenu.AddItem("warden_menu_mute", szBuffer);
    
    Format(szBuffer, sizeof(szBuffer), "%T", "warden_menu_splitplayers", iClient);
    hWardenMenu.AddItem("warden_menu_splitplayers", szBuffer);
    
    Format(szBuffer, sizeof(szBuffer), "%T", "warden_menu_retire", iClient);
    hWardenMenu.AddItem("warden_menu_retire", szBuffer);
    
    hWardenMenu.Display(iClient, MENU_TIME_FOREVER);
}

public void WardenMenu_Handler(Menu hMenu, MenuAction action, int iClient, int iItem) {
    if (!IsValidHandle(hMenu) || Warden == -1 || iClient != Warden || !IsPlayerAlive(iClient)) {
        return;
    }
    switch (action) {
        case MenuAction_Display: {
            bWardenMenuOpened = true;
        }
        case MenuAction_Select: {
            char szItem[128];
            hMenu.GetItem(iItem, szItem, sizeof(szItem));
            
            if (strcmp("warden_menu_noblock", szItem, false) == 0) {
                ToggleNoblock(iClient, 0);
            }
            
            if (strcmp("warden_menu_friendlyfire", szItem, false) == 0) {
                FriendlyFire(iClient, 0);
            }
            
            if (strcmp("warden_menu_bhop", szItem, false) == 0) {
                AutoBunnyHopping(iClient, 0);
            }
            
            if (strcmp("warden_menu_mute", szItem, false) == 0) {
                TempMute(iClient, 0);
            }
            
            if (strcmp("warden_menu_splitplayers", szItem, false) == 0) {
                SplitPlayers(iClient, 0);
            }
            
            if (strcmp("warden_menu_retire", szItem, false) == 0) {
                ExitWarden(iClient, 0);
            }
            
            WardenMenu_Refresh(iClient);
        }
        case MenuAction_Cancel, MenuAction_End: {
            bWardenMenuOpened = false;
        }
    }
}

// ---
// Warden setting.
// ---

public void SetTheWarden(int iClient, bool bNotify) {
    if (bNotify) {
        CPrintToChatAll(TRANSLATION_PREFIX, "warden_new", iClient);
        
        if (conVarBetterNotifications.BoolValue) {
            PrintCenterTextAll("%t", "warden_new", iClient);
        }
    }
    
    Warden = iClient;
    SetClientListeningFlags(iClient, VOICE_NORMAL);
    WardenMenu_Refresh(iClient);
    
    Forward_OnWardenCreation(iClient);
}

public void RemoveTheWarden(int iClient, bool bNotify) {
    if (bNotify) {
        CPrintToChatAll(TRANSLATION_PREFIX, "warden_removed", iClient, Warden);
        if (conVarBetterNotifications.BoolValue) {
            PrintCenterTextAll("%t", "warden_removed", iClient, Warden);
        }
    }
    
    Warden = -1;
    hWardenMenu.Cancel();
    
    Forward_OnWardenRemoved(iClient);
}

// ---
// API.
// ---

void CreateNatives() {
    CreateNative("warden_exist", Native_ExistWarden);
    CreateNative("warden_iswarden", Native_IsWarden);
    CreateNative("warden_set", Native_SetWarden);
    CreateNative("warden_remove", Native_RemoveWarden);
}

void CreateForwards() {
    forwardOnWardenCreation = CreateGlobalForward("warden_OnWardenCreation", ET_Ignore, Param_Cell);
    forwardOnWardenRemoved = CreateGlobalForward("warden_OnWardenRemoved", ET_Ignore, Param_Cell);
}

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErr_Max) {
    RegPluginLibrary("warden");
    
    CreateForwards();
    CreateNatives();
    
    return APLRes_Success;
}

public int Native_ExistWarden(Handle hPlugin, int iParams) {
    return Warden != -1;
}

public int Native_IsWarden(Handle hPlugin, int iParams) {
    int iClient = GetNativeCell(1);
    
    if (!IsClientInGame(iClient))
        ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", iClient);
    
    return iClient == Warden;
}

public void Native_SetWarden(Handle hPlugin, int iParams) {
    int iClient = GetNativeCell(1);
    
    if (!IsClientInGame(iClient)) {
        ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", iClient);
        return;
    }
    
    if (Warden == -1) {
        SetTheWarden(iClient, true);
    }
}

public void Native_RemoveWarden(Handle hPlugin, int iParams) {
    int iClient = GetNativeCell(1);
    
    if (!IsClientInGame(iClient))
        ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", iClient);
    
    if (iClient == Warden) {
        RemoveTheWarden(iClient, true);
    }
}

public void Forward_OnWardenCreation(int iClient) {
    Call_StartForward(forwardOnWardenCreation);
    Call_PushCell(iClient);
    Call_Finish();
}

public void Forward_OnWardenRemoved(int iClient) {
    Call_StartForward(forwardOnWardenRemoved);
    Call_PushCell(iClient);
    Call_Finish();
}