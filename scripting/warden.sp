#include <basecomm>
#include <sourcemod>
#include <sdktools>
#include <sourcecolors>
#tryinclude <warden>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION   "4.2.0"
#define TRANSLATION_PREFIX "[Warden] \x07FFFFFF%t"

#define COLLISION_GROUP_DEBRIS_TRIGGER 2
#define COLLISION_GROUP_PLAYER 5

int Warden = -1;
bool bNoblock = true;
ConVar conVarMpFriendlyFire;
Handle hMuteTimer = null;

ConVar g_cVar_mnotes = null, g_cVar_muteTime = null, g_cVar_noblockDefault = null;
Handle g_hFrwd_OnWardenCreation = null, g_hFrwd_OnWardenRemoved = null;

public Plugin myinfo = {
    name = "Jailbreak Warden",
    author = "ecca & notfoundname",
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
    
    RegConsoleCmd("sm_wmute", TempMute);
    RegConsoleCmd("sm_wm", TempMute);
    
    conVarMpFriendlyFire = FindConVar("mp_friendlyfire");
    RegConsoleCmd("sm_wfriendlyfire", FriendlyFire);
    RegConsoleCmd("sm_wff", FriendlyFire);
    
    
    // Laserbeam
    // RegConsoleCmd("sm_lcolor", Command_Lcolor, "Change laser color");
    // RegConsoleCmd("sm_lclear", Command_Lclear, "Clear all lasers")
    
    // Register our admin commands.
    RegAdminCmd("sm_hirewarden", HireWarden, ADMFLAG_GENERIC, "sm_hirewarden <#userid|name>");
    RegAdminCmd("sm_hc", HireWarden, ADMFLAG_GENERIC, "sm_hc <#userid|name>");
    RegAdminCmd("sm_hw", HireWarden, ADMFLAG_GENERIC, "sm_hw <#userid|name>");
    RegAdminCmd("sm_removewarden", RemoveWarden, ADMFLAG_GENERIC, "sm_removewarden");
    RegAdminCmd("sm_rc", RemoveWarden, ADMFLAG_GENERIC, "sm_rc");
    RegAdminCmd("sm_rw", RemoveWarden, ADMFLAG_GENERIC, "sm_rw");
    
    // Display current warden on top of the screen.
    CreateTimer(1.0, DisplayCurrentWarden, _, TIMER_REPEAT);
    
    // Hooking the events.
    HookEvent("round_start", Event_RoundStart); // For the round start
    HookEvent("player_death", Event_PlayerDeath); // To check when our warden dies :)
    
    // For our warden to look some extra cool.
    AddCommandListener(HookPlayerChat, "say");
    
    // May not touch this line.
    CreateConVar("sm_warden_version", PLUGIN_VERSION,  "The version of the SourceMod plugin JailBreak Warden, by ecca & notfoundname.", FCVAR_SPONLY|FCVAR_DONTRECORD|FCVAR_REPLICATED|FCVAR_NOTIFY);
    
    g_cVar_mnotes = CreateConVar("sm_warden_better_notifications", "1", "0 - disabled, 1 - Will display center text.", FCVAR_NONE, true, 0.0, true, 1.0);
    g_cVar_muteTime = CreateConVar("sm_warden_mute_time", "20", "For how long warden can mute players.", FCVAR_NONE, true, 5.0, true, 60.0);
    g_cVar_noblockDefault = CreateConVar("sm_warden_noblock_default", "1", "0 - start with player collisions, 1 - start with no collisions.", FCVAR_NONE, true, 0.0, true, 1.0);
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
    g_hFrwd_OnWardenCreation = CreateGlobalForward("warden_OnWardenCreation", ET_Ignore, Param_Cell);
    g_hFrwd_OnWardenRemoved = CreateGlobalForward("warden_OnWardenRemoved", ET_Ignore, Param_Cell);
}

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErr_Max) {
    RegPluginLibrary("warden");
    
    CreateForwards();
    CreateNatives();
    
    return APLRes_Success;
}

// ---
// Commands.
// ---

// sm_c / sm_w.
public Action BecomeWarden(int iClient, int iArgs) {
    if (Warden != -1) {
        // The warden already exist so there is no point setting a new one
        if (iClient == Warden) {
            WardenMenu_Create();
            //Menu_Test1();
        } else {
            CPrintToChat(iClient, TRANSLATION_PREFIX, "warden_exist", Warden);
        }
        return Plugin_Handled;
    }
    
    if (GetClientTeam(iClient) != 3) {
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
    WardenMenu_Create();
    //Menu_Test1();
    
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
    
    // Let's remove the awesome color.
    SetEntityRenderColor(iClient, 255, 255, 255, 255);
    
    CPrintToChatAll(TRANSLATION_PREFIX, "warden_retire", iClient);
    if (GetConVarBool(g_cVar_mnotes)) {
        PrintCenterTextAll("%t", "warden_retire", iClient);
    }
    
    return Plugin_Handled;
}

// sm_noblock / sm_nb.
public Action ToggleNoblock(int iClient, int iArgs) {
    // Make sure executor is the Warden.
    if (iClient != Warden) {
        CPrintToChat(iClient, TRANSLATION_PREFIX, "warden_notwarden");
        return Plugin_Handled;
    }   
    
    // Toggle the value and apply it.
    bNoblock = !bNoblock;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientConnected(i) && IsClientInGame(i)) {
            PlayerApplyNoblock(i, true);
        }
    }
    
    return Plugin_Handled;
}

public void PlayerApplyNoblock(int iClient, bool bCommand) {
    if (IsClientConnected(iClient) && IsClientInGame(iClient)) {
        if (bNoblock) {
            SetEntityCollisionGroup(iClient, COLLISION_GROUP_DEBRIS_TRIGGER);
            if (bCommand) {
                CPrintToChat(iClient, TRANSLATION_PREFIX, "warden_noblock_enabled");
            }
        } else {
            SetEntityCollisionGroup(iClient, COLLISION_GROUP_PLAYER);
            if (bCommand) {
                CPrintToChat(iClient, TRANSLATION_PREFIX, "warden_noblock_disabled");
            }
        }
    }
}

// sm_wmute / sm_wm.
public Action TempMute(int iClient, int iArgs) {
    // Make sure executor is the Warden.
    if (iClient == Warden) {
        // If the timer is active then force it to trigger.
        if (IsValidHandle(hMuteTimer)) {
            TriggerTimer(hMuteTimer, true);
        } else {
            MuteTerrorists(GetConVarFloat(g_cVar_muteTime));
        }
    } else {
        CPrintToChat(iClient, TRANSLATION_PREFIX, "warden_notwarden");
    }
    
    return Plugin_Handled;
}

public void TempMuteTimer(Handle timer) {
    UnmuteTerrorists();
	if (Warden != -1) {
		WardenMenu_Create();
	}
}

public void MuteTerrorists(float iDuration) {
    hMuteTimer = CreateTimer(iDuration, TempMuteTimer);
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientConnected(i) && IsClientInGame(i)) {
            CPrintToChat(i, TRANSLATION_PREFIX, "warden_mute_enabled", iDuration);
            if (GetClientTeam(i) == 2 && !BaseComm_IsClientMuted(i)) {
                SetClientListeningFlags(i, VOICE_MUTED);
            }
        }
    }
}

public void UnmuteTerrorists() {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientConnected(i) && IsClientInGame(i)) {
            CPrintToChat(i, TRANSLATION_PREFIX, "warden_mute_disabled", GetConVarInt(g_cVar_muteTime));
            if (GetClientTeam(i) == 2 && !BaseComm_IsClientMuted(i)) {
                SetClientListeningFlags(i, VOICE_NORMAL);
            }
        }
    }
}

// sm_wmute / sm_wm.
public Action FriendlyFire(int iClient, int iArgs) {
    // Make sure executor is the Warden.
    if (iClient == Warden) {
        conVarMpFriendlyFire.SetBool(!GetConVarBool(conVarMpFriendlyFire), true, false);
        CPrintToChatAll(TRANSLATION_PREFIX,
                GetConVarBool(conVarMpFriendlyFire) ? "warden_friendlyfire_enabled" : "warden_friendlyfire_disabled");
    } else {
        CPrintToChat(iClient, TRANSLATION_PREFIX, "warden_notwarden");
    }
    
    return Plugin_Handled;
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
    
    if (iTarget == -1) {
        CPrintToChat(iClient, TRANSLATION_PREFIX, "No matching client");
        return Plugin_Handled;
    }
    
    if (GetClientTeam(iTarget) != 3) {
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
    if (GetConVarBool(g_cVar_mnotes)) {
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

public Action DisplayCurrentWarden(Handle timer) {
    Handle hudHandle = CreateHudSynchronizer();
    SetHudTextParams(1.5, -1.7, 1.0, 255, 255, 255, 255);
    
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientConnected(i) && IsClientInGame(i)) {
            char buf[256];
            if (Warden != -1) {
                Format(buf, sizeof(buf), "%t  ", "warden_exist", Warden);
            } else {
                Format(buf, sizeof(buf), "%t  ", "warden_missing");
            }
            ShowSyncHudText(i, hudHandle, buf);
        }
    }
    
    CloseHandle(hudHandle);
    return Plugin_Continue;
}

// ---
// Event hooks.
// ---

public Action Event_RoundStart(Handle event, const char[] name, bool bDontBroadcast) {
    // Let's remove the current warden if he exists.
    Warden = -1;
    
    bNoblock = GetConVarBool(g_cVar_noblockDefault);
    for (int i = 1; i <= MaxClients; i++) {
        PlayerApplyNoblock(i, false);
    }
    
    // If the timer is active then kill it (don't trigger it).
    if (IsValidHandle(hMuteTimer)) {
        KillTimer(hMuteTimer, true);
    }
    
    return Plugin_Continue;
}

public Action Event_PlayerDeath(Handle event, const char[] name, bool bDontBroadcast) {
    // Get the dead client's id.
    int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
    
    // Aww damn, he is the warden.
    if (iClient == Warden) {
        CPrintToChatAll(TRANSLATION_PREFIX, "warden_dead", Warden);
        if (GetConVarBool(g_cVar_mnotes)) {
            PrintCenterTextAll("%t", "warden_dead", Warden);
        }
        RemoveTheWarden(iClient, false);
    }
    
    return Plugin_Continue;
}

public void OnClientDisconnect(int iClient) {
    // The warden disconnected, action!
    if (iClient == Warden) {
        CPrintToChatAll(TRANSLATION_PREFIX, "warden_disconnected");
        if (GetConVarBool(g_cVar_mnotes)) {
            PrintCenterTextAll("%t", "warden_disconnected");
        }
        RemoveTheWarden(iClient, false);
    }
}

public Action HookPlayerChat(int iClient, const char[] command, int argc) {
    // Check so the player typing is a warden and also checking so the client isn't the console!
    // notfoundname: I don't know why is there a check for a client being the console. I'll keep it anyway.
    if (Warden == iClient && iClient != 0) {
        char szText[256];
        GetCmdArg(1, szText, sizeof(szText));
        
        if (szText[0] == '/' || szText[0] == '@' || IsChatTrigger()) {
            // Prevent unwanted text to be displayed.
            return Plugin_Handled;
        }
        
        if (IsClientConnected(iClient) && IsPlayerAlive(iClient) && GetClientTeam(iClient) == 3) {
            // Typing warden is alive and his team is Counter-Terrorist.
            CPrintToChatAll("[Warden] \x0799CCFF%N\x07FFFFFF: %s", iClient, szText);
            return Plugin_Handled;
        }
    }
    
    return Plugin_Continue;
}

// ---
// Menus.
// ---

public void WardenMenu_Create() {
    Menu mWardenMenu = new Menu(WardenMenu_Handler);
    char szBuffer[128];
    
    Format(szBuffer, sizeof(szBuffer), "%T", "warden_menu_title", Warden);
    mWardenMenu.SetTitle(szBuffer);
    
    Format(szBuffer, sizeof(szBuffer), "%T", "warden_menu_noblock", Warden, 
            bNoblock ? "warden_enabled" : "warden_disabled");
    mWardenMenu.AddItem("warden_menu_noblock", szBuffer);
    
    Format(szBuffer, sizeof(szBuffer), "%T", "warden_menu_friendlyfire", Warden, 
            GetConVarBool(conVarMpFriendlyFire) ? "warden_enabled" : "warden_disabled");
    mWardenMenu.AddItem("warden_menu_friendlyfire", szBuffer);
    
    Format(szBuffer, sizeof(szBuffer), "%T", "warden_menu_mute", Warden, GetConVarFloat(g_cVar_muteTime), 
            IsValidHandle(hMuteTimer) ? "warden_enabled" : "warden_disabled");
    mWardenMenu.AddItem("warden_menu_mute", szBuffer);
    
    Format(szBuffer, sizeof(szBuffer), "%T", "warden_menu_retire", Warden);
    mWardenMenu.AddItem("warden_menu_retire", szBuffer);
    
    mWardenMenu.Display(Warden, MENU_TIME_FOREVER);
}

public int WardenMenu_Handler(Menu mWardenMenu, MenuAction action, int iClient, int iItem) {
    switch (action) {
        case MenuAction_Select: {
            if (Warden == -1 || iClient != Warden || !IsPlayerAlive(iClient)) {
                return 0;
            }
            
            char szItem[128];
            mWardenMenu.GetItem(iItem, szItem, sizeof(szItem));
            
            if (strcmp("warden_menu_noblock", szItem, false) == 0) {
                ToggleNoblock(iClient, 0);
            }
            
            if (strcmp("warden_menu_friendlyfire", szItem, false) == 0) {
                FriendlyFire(iClient, 0);
            }
            
            if (strcmp("warden_menu_mute", szItem, false) == 0) {
                TempMute(iClient, 0);
            }
            
            if (strcmp("warden_menu_retire", szItem, false) == 0) {
                ExitWarden(iClient, 0);
                return 0;
            }
            
            WardenMenu_Create();
        }
        case MenuAction_Cancel, MenuAction_End: {
            delete mWardenMenu;
        }
    }
    return 0;
}

// ---
// Warden setting.
// ---

public void SetTheWarden(int iClient, bool bNotify) {
    if (bNotify) {
        CPrintToChatAll(TRANSLATION_PREFIX, "warden_new", iClient);
        
        if (GetConVarBool(g_cVar_mnotes)) {
            PrintCenterTextAll("%t", "warden_new", iClient);
        }
    }
    
    Warden = iClient;
    SetEntityRenderColor(iClient, 0, 0, 255, 255);
    SetClientListeningFlags(iClient, VOICE_NORMAL);
    
    Forward_OnWardenCreation(iClient);
}

public void RemoveTheWarden(int iClient, bool bNotify) {
    if (bNotify) {
        CPrintToChatAll(TRANSLATION_PREFIX, "warden_removed", iClient, Warden);
        if (GetConVarBool(g_cVar_mnotes)) {
            PrintCenterTextAll("%t", "warden_removed", iClient, Warden);
        }
    }
    
    SetEntityRenderColor(Warden, 255, 255, 255, 255);
    Warden = -1;
    
    Forward_OnWardenRemoved(iClient);
    
    if (GetAlivePlayersCountOnTeam(3) == 1) {
        SetTheWarden(GetFirstAlivePlayerOnTeam(3), !bNotify);
    }
}

// ---
// Etc. functions.
// ---

public int GetFirstAlivePlayerOnTeam(int iTeam) {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == iTeam) {
            return i;
        }
    }
    return -1;
}

public int GetAlivePlayersCountOnTeam(int iTeam) {
    int iNumber = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == iTeam) {
            iNumber++;
        }
    }
    return iNumber;
}

// ---
// API, too.
// ---

public int Native_ExistWarden(Handle hPlugin, int iParams) {
    return Warden != -1;
}

public int Native_IsWarden(Handle hPlugin, int iParams) {
    int iClient = GetNativeCell(1);
    
    if (!IsClientConnected(iClient) || !IsClientInGame(iClient))
        ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", iClient);
    
    return iClient == Warden;
}

public int Native_SetWarden(Handle hPlugin, int iParams) {
    int iClient = GetNativeCell(1);
    
    if (!IsClientConnected(iClient) || IsClientInGame(iClient))
        ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", iClient);
    
    if (Warden == -1) {
        SetTheWarden(iClient, true);
    }
}

public int Native_RemoveWarden(Handle hPlugin, int iParams) {
    int iClient = GetNativeCell(1);
    
    if (!IsClientConnected(iClient) || IsClientInGame(iClient))
        ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", iClient);
    
    if (iClient == Warden) {
        RemoveTheWarden(iClient, true);
    }
}

public void Forward_OnWardenCreation(int iClient) {
    Call_StartForward(g_hFrwd_OnWardenCreation);
    Call_PushCell(iClient);
    Call_Finish();
}

public void Forward_OnWardenRemoved(int iClient) {
    Call_StartForward(g_hFrwd_OnWardenRemoved);
    Call_PushCell(iClient);
    Call_Finish();
}