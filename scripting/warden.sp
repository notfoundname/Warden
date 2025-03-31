#include <sourcemod>
#include <sdktools>
#include <sourcecolors>
#tryinclude <warden>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION   "4.1.0"
#define TRANSLATION_PREFIX "[Warden] \x07FFFFFF%t"

int Warden = -1;

bool noblockEnabled = true;

Handle muteTimer = null;

Handle g_cVar_mnotes = null;
Handle g_cVar_muteTime = null;
Handle g_cVar_noblockDefault = null;

Handle g_hFrwd_OnWardenCreation = null;
Handle g_hFrwd_OnWardenRemoved = null;

public Plugin myinfo = {
    name = "Jailbreak Warden",
    author = "ecca & notfoundname",
    description = "Updated Jailbreak Warden Plugin",
    version = PLUGIN_VERSION,
    url = "ffac.eu & babrcraft.ru"
};

public void OnPluginStart() {
    // Initialize our phrases
    LoadTranslations("warden.phrases");
    
    // Register our public commands
    RegConsoleCmd("sm_w", BecomeWarden);
    RegConsoleCmd("sm_warden", BecomeWarden);
    RegConsoleCmd("sm_uw", ExitWarden);
    RegConsoleCmd("sm_unwarden", ExitWarden);
    RegConsoleCmd("sm_c", BecomeWarden);
    RegConsoleCmd("sm_commander", BecomeWarden);
    RegConsoleCmd("sm_uc", ExitWarden);
    RegConsoleCmd("sm_uncommander", ExitWarden);
    
    // Warden private commands
    RegConsoleCmd("sm_noblock", ToggleNoblock);
    RegConsoleCmd("sm_nb", ToggleNoblock);
    RegConsoleCmd("sm_wmute", TempMute);
    RegConsoleCmd("sm_wm", TempMute);
    
    // Laserbeam
    // RegConsoleCmd("sm_lcolor", Command_Lcolor, "Change laser color");
    // RegConsoleCmd("sm_lclear", Command_Lclear, "Clear all lasers")
    
    // Register our admin commands
    RegAdminCmd("sm_rw", RemoveWarden, ADMFLAG_GENERIC);
    RegAdminCmd("sm_rc", RemoveWarden, ADMFLAG_GENERIC);
    
    // Display current warden on top of the screen
    CreateTimer(1.0, DisplayCurrentWarden, _, TIMER_REPEAT);
    
    // Hooking the events
    HookEvent("round_start", Event_RoundStart); // For the round start
    HookEvent("player_death", Event_PlayerDeath); // To check when our warden dies :)
    
    // For our warden to look some extra cool
    AddCommandListener(HookPlayerChat, "say");
    
    // May not touch this line
    CreateConVar("sm_warden_version", PLUGIN_VERSION,  "The version of the SourceMod plugin JailBreak Warden, by ecca & notfoundname", FCVAR_SPONLY|FCVAR_DONTRECORD|FCVAR_REPLICATED|FCVAR_NOTIFY);
    
    g_cVar_mnotes = CreateConVar("sm_warden_better_notifications", "1", "0 - disabled, 1 - Will use center text", FCVAR_NONE, true, 0.0, true, 1.0);
    g_cVar_muteTime = CreateConVar("sm_warden_mute_time", "20", "For how long warden can mute players?", FCVAR_NONE, true, 5.0, true, 60.0);
    g_cVar_noblockDefault = CreateConVar("sm_warden_noblock_default", "1", "0 - start with player collisions, 1 - start with no collisions", FCVAR_NONE, true, 0.0, true, 1.0);
}

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

public Action BecomeWarden(int iClient, int iArgs) {
    if (Warden == -1) { // There is no warden , so lets proceed
        if (GetClientTeam(iClient) == 3) { // The requested player is on the Counter-Terrorist side
            if (IsPlayerAlive(iClient)) { // A dead warden would be worthless >_<
                SetTheWarden(iClient);
            } else { // Grr he is not alive -.-
                CPrintToChat(iClient, TRANSLATION_PREFIX, "warden_playerdead");
            }
        } else { // Would be weird if an terrorist would run the prison wouldn't it :p
            CPrintToChat(iClient, TRANSLATION_PREFIX, "warden_ctsonly");
        }
    } else { // The warden already exist so there is no point setting a new one
        CPrintToChat(iClient, TRANSLATION_PREFIX, "warden_exist", Warden);
    }
}

public Action ExitWarden(int iClient, int iArgs) {
    if (iClient == Warden) { // The iClient is actually the current warden so lets proceed
        CPrintToChatAll(TRANSLATION_PREFIX, "warden_retire", iClient);
        if (GetConVarBool(g_cVar_mnotes)) {
            PrintCenterTextAll("%t", "warden_retire", iClient);
        }
        Warden = -1; // Open for a new warden
        SetEntityRenderColor(iClient, 255, 255, 255, 255); // Lets remove the awesome color
    } else { // Fake dude!
        CPrintToChat(iClient, TRANSLATION_PREFIX, "warden_notwarden");
    }
}

public Action DisplayCurrentWarden(Handle timer) {
    Handle hudHandle = CreateHudSynchronizer();
    
    SetHudTextParams(1.5, -1.7, 1.0, 255, 255, 255, 255);
    
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            char buf[256];
            if (Warden != -1) {
                Format(buf, sizeof(buf), "%t   ", "warden_exist", Warden);
            } else {
                Format(buf, sizeof(buf), "%t   ", "warden_missing");
            }
            ShowSyncHudText(i, hudHandle, buf);
        }
    }
    
    CloseHandle(hudHandle);
    return Plugin_Continue;
}

public Action ToggleNoblock(int iClient, int iArgs) {
    if (iClient == Warden) { // Make sure executor is the Warden
        noblockEnabled = !noblockEnabled;
        for (int i = 1; i <= MaxClients; i++) {
            PlayerApplyNoblock(i, true);
        }
    } else {
        CPrintToChat(iClient, TRANSLATION_PREFIX, "warden_notwarden");
    }
    
    return Plugin_Handled;
}

public void PlayerApplyNoblock(int iClient, bool command) {
    if (noblockEnabled) {
        SetEntityCollisionGroup(iClient, 2); // COLLISION_GROUP_DEBRIS_TRIGGER
        if (command) {
            CPrintToChat(iClient, TRANSLATION_PREFIX, "warden_noblock_enabled");
        }
    } else {
        SetEntityCollisionGroup(iClient, 5); // COLLISION_GROUP_PLAYER
        if (command) {
            CPrintToChat(iClient, TRANSLATION_PREFIX, "warden_noblock_disabled");
        }
    }
}

public Action TempMute(int iClient, int iArgs) {
    if (iClient == Warden) { // Make sure executor is the Warden
        if (muteTimer != null) { // If the timer is active then force it to trigger
            TriggerTimer(muteTimer, false);
            return Plugin_Handled;
        }
        muteTimer = CreateTimer(GetConVarFloat(g_cVar_muteTime), TempMuteTimer);
        for (int i = 1; i <= MaxClients; i++) {
            CPrintToChat(i, TRANSLATION_PREFIX, "warden_mute", GetConVarInt(g_cVar_muteTime));
            if (GetClientTeam(i) == 2) { // Mute all Terrorists
                SetClientListeningFlags(i, VOICE_MUTED);
            }
        }
    } else {
        CPrintToChat(iClient, TRANSLATION_PREFIX, "warden_notwarden");
    }
    
    return Plugin_Handled;
}

public Action TempMuteTimer(Handle timer) {
    for (int i = 1; i <= MaxClients; i++) {
        CPrintToChat(i, TRANSLATION_PREFIX, "warden_mute_ended", GetConVarInt(g_cVar_muteTime));
        if (GetClientTeam(i) == 2) { // Unmute all Terrorists
            SetClientListeningFlags(i, VOICE_NORMAL);
        }
    }
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast) {
    Warden = -1; // Lets remove the current warden if he exist
    
    noblockEnabled = GetConVarBool(g_cVar_noblockDefault);
    for (int i = 1; i <= MaxClients; i++) {
        PlayerApplyNoblock(i, false);
    }
    
    if (muteTimer != null) { // If the timer is active then kill it (don't trigger it)
        KillTimer(muteTimer, false);
    }
    
    return Plugin_Continue;
}

public Action Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast) {
    int iClient = GetClientOfUserId(GetEventInt(event, "userid")); // Get the dead clients id
    
    if (iClient == Warden) { // Aww damn , he is the warden
        CPrintToChatAll(TRANSLATION_PREFIX, "warden_dead", Warden);
        if (GetConVarBool(g_cVar_mnotes)) {
            PrintCenterTextAll("%t", "warden_dead", Warden);
        }
        SetEntityRenderColor(iClient, 255, 255, 255, 255); // Lets give him the standard color back
        Warden = -1; // Lets open for a new warden
    }
    
    return Plugin_Continue;
}

public void OnClientDisconnect(int iClient) {
    if (iClient == Warden) { // The warden disconnected, action!
        CPrintToChatAll(TRANSLATION_PREFIX, "warden_disconnected");
        if (GetConVarBool(g_cVar_mnotes)) {
            PrintCenterTextAll("%t", "warden_disconnected");
        }
        Warden = -1; // Lets open for a new warden
    }
}

public Action RemoveWarden(int iClient, int iArgs) {
    if (Warden != -1) { // Is there an warden at the moment ?
        RemoveTheWarden(iClient);
    } else {
        CPrintToChatAll(TRANSLATION_PREFIX, "warden_noexist");
    }

    return Plugin_Handled; // Prevent sourcemod from typing "unknown command" in console
}


public Action HookPlayerChat(int iClient, const char[] command, int argc) {
    if (Warden == iClient && iClient != 0) { // Check so the player typing is warden and also checking so the client isn't console!
        char szText[256];
        GetCmdArg(1, szText, sizeof(szText));
        
        if (szText[0] == '/' || szText[0] == '@' || IsChatTrigger()) { // Prevent unwanted text to be displayed.
            return Plugin_Handled;
        }
        
        if (IsClientInGame(iClient) && IsPlayerAlive(iClient) && GetClientTeam(iClient) == 3) { // Typing warden is alive and his team is Counter-Terrorist
            CPrintToChatAll("[Warden] \x0799CCFF%N\x07FFFFFF: %s", iClient, szText);
            return Plugin_Handled;
        }
    }
    
    return Plugin_Continue;
}


public void SetTheWarden(int iClient) {
    CPrintToChatAll(TRANSLATION_PREFIX, "warden_new", iClient);
    
    if (GetConVarBool(g_cVar_mnotes)) {
        PrintCenterTextAll("%t", "warden_new", iClient);
    }
    
    Warden = iClient;
    SetEntityRenderColor(iClient, 0, 0, 255, 255);
    SetClientListeningFlags(iClient, VOICE_NORMAL);
    
    Forward_OnWardenCreation(iClient);
}

public void RemoveTheWarden(int iClient) {
    CPrintToChatAll(TRANSLATION_PREFIX, "warden_removed", iClient, Warden);
    if (GetConVarBool(g_cVar_mnotes)) {
        PrintCenterTextAll("%t", "warden_removed", iClient, Warden);
    }
    
    SetEntityRenderColor(Warden, 255, 255, 255, 255);
    Warden = -1;
    
    Forward_OnWardenRemoved(iClient);
}

public int Native_ExistWarden(Handle hPlugin, int iParams) {
    return Warden != -1;
}

public int Native_IsWarden(Handle hPlugin, int iParams) {
    int iClient = GetNativeCell(1);
    
    if (!IsClientInGame(iClient) && !IsClientConnected(iClient))
        ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", iClient);
    
    return iClient == Warden;
}

public int Native_SetWarden(Handle hPlugin, int iParams) {
    int iClient = GetNativeCell(1);
    
    if (!IsClientInGame(iClient) && !IsClientConnected(iClient))
        ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", iClient);
    
    if (Warden == -1) {
        SetTheWarden(iClient);
    }
}

public int Native_RemoveWarden(Handle hPlugin, int iParams) {
    int iClient = GetNativeCell(1);
    
    if (!IsClientInGame(iClient) && !IsClientConnected(iClient))
        ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", iClient);
    
    if (iClient == Warden) {
        RemoveTheWarden(iClient);
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