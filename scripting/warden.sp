#include <basecomm>
#include <cstrike>
#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <warden>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION   "4.4.0"
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
int iLaserEndGlow, iLaserBeam = 0;
float fWardenLastAimPos[3] = {0.0, 0.0, 0.0};
int iWardenLaserLastRunTick = 0;

ConVar conVarBetterNotifications, 
    conVarMuteTime,
    conVarNoblockDefault,
    conVarBhopDefault,
    conVarSplitPlayersRadius;
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
    CreateTimer(0.5, DisplayCurrentWarden, _, TIMER_REPEAT);
    
    // Laser.
    iLaserEndGlow = PrecacheModel("materials/sprites/redglow1.vmt", true);
    iLaserBeam = PrecacheModel("materials/sprites/laserbeam.vmt", true);
    
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
    
    // Initialize config.
    AutoExecConfig(true);
    
    // May not touch this line.
    CreateConVar("sm_warden_version", PLUGIN_VERSION, "The version of the SourceMod plugin JailBreak Warden.", FCVAR_SPONLY|FCVAR_DONTRECORD|FCVAR_REPLICATED|FCVAR_NOTIFY);
}

// ---
// Commands.
// ---

// sm_c / sm_w.
public Action BecomeWarden(int iClient, int iArgs) {
    if (warden_exist()) {
        // The warden already exist so there is no point setting a new one
        if (warden_iswarden(iClient)) {
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
    if (!warden_iswarden(iClient)) {
        CPrintToChat(iClient, TRANSLATION_PREFIX, "warden_notwarden");
        return Plugin_Handled;
    }
    
    // Open for a new warden.
    warden_remove(-1);
    
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
    if (!(warden_iswarden(iClient) || CheckCommandAccess(iClient, "sm_hc", ADMFLAG_GENERIC))) {
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
    
    if (bWardenMenuOpened) {
        WardenMenu_Refresh(iClient);
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
    if (!(warden_iswarden(iClient) || CheckCommandAccess(iClient, "sm_hc", ADMFLAG_GENERIC))) {
        CPrintToChat(iClient, TRANSLATION_PREFIX, "warden_notwarden");
        return Plugin_Handled;
    }

    // If the timer is active then force it to trigger.
    if (IsValidHandle(hMuteTimer)) {
        TriggerTimer(hMuteTimer, true);
    } else {
        MuteTerrorists(conVarMuteTime.FloatValue);
    }
    
    if (bWardenMenuOpened) {
        WardenMenu_Refresh(iClient);
    }
    
    return Plugin_Handled;
}

public void TempMuteTimer(Handle timer) {
    UnmuteTerrorists();
    // Doing this to update the menu.
    hMuteTimer = null;
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
    if (!(warden_iswarden(iClient) || CheckCommandAccess(iClient, "sm_hc", ADMFLAG_GENERIC))) {
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
    if (!(warden_iswarden(iClient) || CheckCommandAccess(iClient, "sm_hc", ADMFLAG_GENERIC))) {
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
    if (!(warden_iswarden(iClient) || CheckCommandAccess(iClient, "sm_hc", ADMFLAG_GENERIC))) {
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
    if (warden_exist()) {
        warden_remove(-1);
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
    if (warden_exist()) {
        warden_remove(iClient);
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
        SetHudTextParams(1.5, -1.7, 0.5, 173, 216, 230, 255);
    } else {
        SetHudTextParams(1.5, -1.7, 0.5, 255, 0, 0, 255);
    }
    
    for (int i = 1; i <= MaxClients; i++) {
        if (IsValidClient(i)) {
            char szBuffer[256];

            if (IsValidClient(Warden)) {
                FormatEx(szBuffer, sizeof(szBuffer), "%T  ", "warden_exist", i, Warden);
            } else {
                FormatEx(szBuffer, sizeof(szBuffer), "%T  ", "warden_missing", i);
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
    if (!warden_iswarden(iClient))
        return;
    
    iWardenLaserLastRunTick += 1;
    
    if (iWardenLaserLastRunTick > 4)
        iWardenLaserLastRunTick = 0;
    
    if (!iWardenLaserLastRunTick)
        DrawLaser(iClient, fAngles, (iButtons & IN_USE));
}

void DrawLaser(int iClient, const float fAngles[3], bool bDraw) {
    float fOrigin[3], fEnd[3];
    GetClientEyePosition(iClient, fOrigin);
    TR_TraceRayFilter(fOrigin, fAngles, MASK_SHOT, RayType_Infinite, TraceFilter_Callback, iClient);
    if (TR_DidHit()) {
        TR_GetEndPosition(fEnd);
        if (fWardenLastAimPos[0] != 0.0 && fWardenLastAimPos[1] != 0.0 && fWardenLastAimPos[2] != 0.0) {
            if (bDraw) {
                // Glowing snake-like laser.
                TE_SetupBeamPoints(fWardenLastAimPos, fEnd, iLaserBeam, 0, 0, 0, 25.0, 2.0, 2.0, 10, 0.0, {173, 216, 230, 255}, 0);
                TE_SendToAll();
                // Straight laser coming out of warden's head.
                TE_SetupBeamPoints(fOrigin, fEnd, iLaserBeam, 0, 0, 0, 0.1, 0.1, 0.1, 10, 0.0, {173, 216, 230, 255}, 0);
                TE_SendToAll();
                // Glowing sprite, shows what warden is currently looking at.
                TE_SetupGlowSprite(fEnd, iLaserEndGlow, 0.1, 1.0, 200);
                TE_SendToAll(0.0);
            }
        }
        fWardenLastAimPos = fEnd;
    }
}

bool TraceFilter_Callback(int iEntity, int iMask) { 
    return (iEntity > MaxClients || !iEntity);
}

// ---
// Event hooks.
// ---

public void Event_RoundStart(Handle event, const char[] name, bool bDontBroadcast) {
    // Let's remove the current warden if he exists.
    warden_remove(-1);

    // Laser.
    iLaserEndGlow = PrecacheModel("materials/sprites/redglow1.vmt", false);
    iLaserBeam = PrecacheModel("materials/sprites/laserbeam.vmt", false);
    
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
}

public void Event_PlayerDeath(Handle event, const char[] name, bool bDontBroadcast) {
    // Get the dead client's id.
    int iClient = GetClientOfUserId(GetEventInt(event, "userid"));

    // Aww damn, he is the warden.
    if (warden_iswarden(iClient)) {
        CPrintToChatAll(TRANSLATION_PREFIX, "warden_dead", Warden);
        if (conVarBetterNotifications.BoolValue) {
            PrintCenterTextAll("%t", "warden_dead", Warden);
        }
        warden_remove(-1);
        
        // Make last remaining CT a Warden.
        if (GetTeamAliveCount(CS_TEAM_CT) == 1) {
            SetTheWarden(GetFirstAlivePlayerOnTeam(CS_TEAM_CT), true);
        }
    }
}

public Action Event_PlayerSpawn(Handle event, const char[] name, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
    if (IsValidClient(iClient)) {
        PlayerApplyNoblock(iClient, false);
    }
    return Plugin_Continue;
}

public void OnClientDisconnect_Post(int iClient) {
    // The warden disconnected, action!
    if (warden_iswarden(iClient)) {
        CPrintToChatAll(TRANSLATION_PREFIX, "warden_disconnected");
        if (conVarBetterNotifications.BoolValue) {
            PrintCenterTextAll("%t", "warden_disconnected");
        }
        warden_remove(-1);
        
        // Make last remaining CT a Warden.
        if (GetTeamAliveCount(CS_TEAM_CT) == 1) {
            SetTheWarden(GetFirstAlivePlayerOnTeam(CS_TEAM_CT), true);
        }
    }
}

// Warden chat hook.
public Action WardenSay(int iClient, int iArgs) {
    // Check so the player typing is a warden and also checking so the client isn't the console!
    if (warden_iswarden(iClient)) {
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

void WardenMenu_Refresh(int iClient) {
    if (!IsValidHandle(hWardenMenu) || !warden_iswarden(iClient)) {
        return;
    }
    
    hWardenMenu.RemoveAllItems();
    char szBuffer[128];
    
    FormatEx(szBuffer, sizeof(szBuffer), "%T", "warden_menu_title", iClient);
    hWardenMenu.SetTitle(szBuffer);
    
    FormatEx(szBuffer, sizeof(szBuffer), "%T", "warden_menu_noblock", iClient, 
            bNoblock ? "warden_enabled" : "warden_disabled");
    hWardenMenu.AddItem("warden_menu_noblock", szBuffer);
    
    FormatEx(szBuffer, sizeof(szBuffer), "%T", "warden_menu_friendlyfire", iClient, 
            conVarMpFriendlyFire.BoolValue ? "warden_enabled" : "warden_disabled");
    hWardenMenu.AddItem("warden_menu_friendlyfire", szBuffer);
    
    FormatEx(szBuffer, sizeof(szBuffer), "%T", "warden_menu_bhop", iClient, 
            conVarSvAutoBunnyHopping.BoolValue ? "warden_enabled" : "warden_disabled");
    hWardenMenu.AddItem("warden_menu_bhop", szBuffer);
    
    FormatEx(szBuffer, sizeof(szBuffer), "%T", "warden_menu_mute", iClient, conVarMuteTime.FloatValue, 
            IsValidHandle(hMuteTimer) ? "warden_enabled" : "warden_disabled");
    hWardenMenu.AddItem("warden_menu_mute", szBuffer);
    
    FormatEx(szBuffer, sizeof(szBuffer), "%T", "warden_menu_splitplayers", iClient);
    hWardenMenu.AddItem("warden_menu_splitplayers", szBuffer);
    
    FormatEx(szBuffer, sizeof(szBuffer), "%T", "warden_menu_retire", iClient);
    hWardenMenu.AddItem("warden_menu_retire", szBuffer);
    
    hWardenMenu.Display(iClient, MENU_TIME_FOREVER);
}

void WardenMenu_Handler(Menu hMenu, MenuAction action, int iClient, int iItem) {
    if (!IsValidHandle(hMenu) || !warden_iswarden(iClient)) {
        return;
    }
    
    switch (action) {
        case MenuAction_Display: {
            bWardenMenuOpened = true;
        }
        case MenuAction_Select: {
            char szItem[128];
            hMenu.GetItem(iItem, szItem, sizeof(szItem));
            
            if (StrEqual("warden_menu_noblock", szItem)) {
                ToggleNoblock(iClient, 0);
            }
            
            if (StrEqual("warden_menu_friendlyfire", szItem)) {
                FriendlyFire(iClient, 0);
            }
            
            if (StrEqual("warden_menu_bhop", szItem)) {
                AutoBunnyHopping(iClient, 0);
            }
            
            if (StrEqual("warden_menu_mute", szItem)) {
                TempMute(iClient, 0);
            }
            
            if (StrEqual("warden_menu_splitplayers", szItem)) {
                SplitPlayers(iClient, 0);
            }
            
            if (StrEqual("warden_menu_retire", szItem)) {
                ExitWarden(iClient, 0);
            }
            
            hWardenMenu.Cancel();
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

void SetTheWarden(int iClient, bool bNotify) {
    if (bNotify) {
        CPrintToChatAll(TRANSLATION_PREFIX, "warden_new", iClient);
        
        if (conVarBetterNotifications.BoolValue) {
            PrintCenterTextAll("%t", "warden_new", iClient);
        }
    }
    
    Warden = iClient;
    SetClientListeningFlags(iClient, VOICE_NORMAL);
    WardenMenu_Refresh(iClient);
    fWardenLastAimPos = {0.0, 0.0, 0.0};
    
    Forward_OnWardenCreation(iClient);
}

void RemoveTheWarden(int iAdmin) {
    if (IsValidClient(iAdmin)) {
        CPrintToChatAll(TRANSLATION_PREFIX, "warden_removed", iAdmin, Warden);
        if (conVarBetterNotifications.BoolValue) {
            PrintCenterTextAll("%t", "warden_removed", iAdmin, Warden);
        }
    }
    Forward_OnWardenRemoved(Warden);
    hWardenMenu.Cancel();
    Warden = -1;
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
    return IsValidClient(Warden) && IsPlayerAlive(Warden);
}

public int Native_IsWarden(Handle hPlugin, int iParams) {
    int iClient = GetNativeCell(1);
    
    if (!IsValidClient(iClient))
        ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", iClient);
    
    return IsPlayerAlive(iClient) && iClient == Warden;
}

public void Native_SetWarden(Handle hPlugin, int iParams) {
    int iClient = GetNativeCell(1);
    
    if (!IsValidClient(iClient)) {
        ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", iClient);
        return;
    }
    
    if (!warden_exist()) {
        SetTheWarden(iClient, true);
    }
}

public void Native_RemoveWarden(Handle hPlugin, int iParams) {
    if (!warden_exist())
        ThrowNativeError(SP_ERROR_NOT_FOUND, "Tried to remove non-existant Warden");
    RemoveTheWarden(GetNativeCell(1));
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