#include <sourcemod>
#include <sdktools>
#include <autoexecconfig>
#include <csgocolors>

#pragma semicolon 1

#pragma newdecls required

#define SOUND_BLIP "buttons/blip1.wav"
#define PLUGIN_VERSION "1.4.1"
 
int g_BeamSprite = -1;
int g_HaloSprite = -1;
int g_iBeaconValidation = 1;
bool g_bBeaconOn = false;

ConVar gc_bPluginEnabled;

ConVar gc_bTagEnabled;

ConVar gc_iMinimumBeacon;

ConVar gc_bPluginColor;

ConVar gc_fBeaconRadius;

ConVar gc_fBeaconWidth;

ConVar gc_fBeaconTimelimit;

ConVar gc_bWarnPlayers;

int ga_iRedColor[4] = {255, 75, 75, 255};

public Plugin myinfo =
{
    name = "Hunger Games Beacon",
    author = "Headline",
    description = "Beacons players designed for Hunger Games",
    version = PLUGIN_VERSION,
	url = "http://michaelwflaherty.com"
};

public void OnConfigsExecuted()
{
    if (gc_bTagEnabled.BoolValue)
    {
        ConVar hTags = FindConVar("sv_tags");
        char sTags[128];
        hTags.GetString(sTags, sizeof(sTags));
        StrCat(sTags, sizeof(sTags), ", Headline");
        hTags.SetString(sTags);
    }
}

public void OnPluginStart()
{
    AutoExecConfig_SetFile("sm_beacon");
    AutoExecConfig_SetCreateFile(true);

    AutoExecConfig_CreateConVar("beacon_version", PLUGIN_VERSION, "Headline's Beacon Plugin: Version", FCVAR_PLUGIN|FCVAR_NOTIFY);
	
    gc_bPluginEnabled = AutoExecConfig_CreateConVar("sm_beacon_enabled", "1", "Enables and disables the beacon plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    
    gc_bTagEnabled = AutoExecConfig_CreateConVar("sm_tag_enabled", "1", "Allow \"Headline\" to be added to the server tags?", FCVAR_NOTIFY, true, 0.0, true, 1.0);

    gc_iMinimumBeacon = AutoExecConfig_CreateConVar("sm_players_for_beacon", "2", "Sets the ammount of players for when the beacon should start", FCVAR_NOTIFY, true, 0.0, true, 32.0);

    gc_bPluginColor = AutoExecConfig_CreateConVar("sm_beacon_color", "1", "Enables and disables the beacon plugin's chat colors", FCVAR_NOTIFY, true, 0.0, true, 1.0);

    gc_fBeaconRadius = AutoExecConfig_CreateConVar("sm_beacon_radius", "750", "Sets the radius for the beacon's rings.", FCVAR_NOTIFY, true, 50.0, true, 1500.0);

    gc_fBeaconWidth = AutoExecConfig_CreateConVar("sm_beacon_width", "10", "Sets the thickness for the beacon's rings.", FCVAR_NOTIFY, true, 10.0, true, 30.0);

    gc_fBeaconTimelimit = AutoExecConfig_CreateConVar("sm_beacon_timelimit", "0", "Sets the amount of time (in seconds) until the beacon gets manually turned on (set to 0 to disable)", FCVAR_NOTIFY, true, 0.0, true, 600.0);

    gc_bWarnPlayers = AutoExecConfig_CreateConVar("sm_warn_players", "0", "If it is = 1, players will be warned to not delay the round when beacons start", FCVAR_NOTIFY, true, 0.0, true, 1.0);

    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();

    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("round_end", Event_RoundEnd);
    HookEvent("round_start", Event_RoundStart);
    
    RegAdminCmd("sm_beaconall", Command_BeaconAll, ADMFLAG_GENERIC, "Toggles beacon on all players");
    RegAdminCmd("sm_stopbeacon", Command_StopBeacon, ADMFLAG_GENERIC, "Toggles beacon on all players");
}

public void OnMapStart()
{
    PrecacheSound(SOUND_BLIP, true);
    g_BeamSprite = PrecacheModel("materials/sprites/bomb_planted_ring.vmt");
    g_HaloSprite = PrecacheModel("materials/sprites/halo.vtf");
    g_iBeaconValidation = 1;
}

public void OnClientDisconnected(int client)
{
    if (!gc_bPluginEnabled.BoolValue)
    {
        return;
    }
    
    if(GetPlayerCount() == gc_iMinimumBeacon.IntValue)
    {
        g_iBeaconValidation++;
        CreateTimer(1.0, BeaconAll_Callback, g_iBeaconValidation, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action Event_PlayerDeath(Handle hEvent, const char[] sName, bool bDontBroadcast)
{
    if (!gc_bPluginEnabled.BoolValue)
    {
        return Plugin_Continue;
    }
    if(GetPlayerCount() <= gc_iMinimumBeacon.IntValue)
    {
        if (gc_bWarnPlayers.BoolValue)
        {
            if (!gc_bPluginColor.BoolValue)
            {
                PrintToChatAll("Reminder! Teaming while the beacons are on is prohibited!!!");
            }
            else
            {
                CPrintToChatAll("Reminder! Teaming while the beacons are on is {PINK}prohibited!!!");
            }
        }
        g_iBeaconValidation++;
        CreateTimer(1.0, BeaconAll_Callback, g_iBeaconValidation, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    }
    return Plugin_Continue;
}

public Action Event_RoundStart(Handle hEvent, const char[] sName, bool bDontBroadcast)
{
    if (!gc_bPluginEnabled.BoolValue)
    {
        return Plugin_Continue;
    }
    g_iBeaconValidation++;
    if (gc_fBeaconTimelimit.FloatValue <= 0.0)
    {
        return Plugin_Continue;
    }
    g_bBeaconOn = false;
    CreateTimer(gc_fBeaconTimelimit.FloatValue, beacon_all_timelimit, g_iBeaconValidation, TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Continue;
}

public Action beacon_all_timelimit(Handle hTimer, any iValidation)
{
    if(g_iBeaconValidation == iValidation)
    {
        g_iBeaconValidation++;
        CreateTimer(1.0, BeaconAll_Callback, g_iBeaconValidation, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action Event_RoundEnd(Handle hEvent, const char[] sName, bool bDontBroadcast)
{
    if (!gc_bPluginEnabled.BoolValue)
    {
        return Plugin_Continue;
    }
    g_bBeaconOn = false;
    g_iBeaconValidation++;
    return Plugin_Continue;
}

public Action Command_StopBeacon(int client, int iArgs)
{
    if (iArgs != 0)
    {
        PrintToConsole(client, "[SM] Usage : sm_stopbeacon");
    }
    if (!gc_bPluginEnabled.BoolValue)
    {
        ReplyToCommand(client, "Hunger Games Beacon is Disabled");
        return Plugin_Handled;
    }
    g_iBeaconValidation++;
    g_bBeaconOn = false;
    if (!gc_bPluginColor.BoolValue)
    {
        PrintToChatAll("[SM] %N toggled beacon OFF", client);
    }
    else
    {
        CPrintToChatAll("[SM] {PINK}%N {NORMAL}toggled beacon {PINK}OFF", client);
    }
    return Plugin_Handled;
}

public Action Command_BeaconAll(int client, int iArgs)
 {
    if (iArgs != 0)
    {
        PrintToConsole(client, "[SM] Usage : beaconall");
    }
    if (!gc_bPluginEnabled.BoolValue)
    {
        ReplyToCommand(client, "Hunger Games Beacon is Disabled");
        return Plugin_Handled;
    }
    if (!gc_bPluginColor.BoolValue)
    {
        PrintToChatAll("[SM] %N toggled beacon ON", client);
    }
    else
    {
        CPrintToChatAll("[SM] {PINK}%N {NORMAL}toggled beacon {PINK}ON", client);
    }
    if (g_bBeaconOn)
    {
        g_iBeaconValidation++;
        if (!gc_bPluginColor.BoolValue)
        {
            PrintToChatAll("[SM] %N toggled beacon OFF", client);
        }
        else
        {
            CPrintToChatAll("[SM] {PINK}%N {NORMAL}toggled beacon {PINK}OFF", client);
        }
    }
    g_bBeaconOn = true;
    g_iBeaconValidation++;
    CreateTimer(1.0, BeaconAll_Callback, g_iBeaconValidation, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Handled;
}

public Action BeaconAll_Callback(Handle hTimer, any iValidation)
{
    if(iValidation != g_iBeaconValidation)
    {
        return Plugin_Stop;
    }
    for(int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) >= 2)
        {
            float a_fOrigin[3];
            GetClientAbsOrigin(i, a_fOrigin);
            a_fOrigin[2] += 10;
            TE_SetupBeamRingPoint(a_fOrigin, 10.0, gc_fBeaconRadius.FloatValue, g_BeamSprite, g_HaloSprite, 0, 10, 0.6, gc_fBeaconWidth.FloatValue, 0.5, ga_iRedColor, 5, 0);

            TE_SendToAll();

            GetClientEyePosition(i, a_fOrigin);
            EmitAmbientSound(SOUND_BLIP, a_fOrigin, i, SNDLEVEL_RAIDSIREN);
        }
    }
    return Plugin_Continue;
}

bool IsValidClient(int iClient)
{
    if(iClient < 1 || iClient > MaxClients || !IsClientConnected(iClient) || IsClientInKickQueue(iClient) || IsClientSourceTV(iClient))
    {
        return false;
    }
    else
    {
        return IsClientInGame(iClient);
    }
}

stock int GetPlayerCount()
{
    int iPlayers;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) >= 2)
        {
            iPlayers++;
        }
    }
    return iPlayers;
}

/*	Changelog
	1.0 - Initial Release
	1.1 - Added CVAR sm_players_for_beacon
	1.2 - ThatOneGuy helped fix the issue where sm_beaconall would cause the beacons to happen twice.
	1.3 - Created a warning for when beacons come on and a CVAR to go with it. Also added a sv_tags with my name in it so I can see servers using this!
	1.4 - Updated plugin to 1.7 transitional syntax & Added AutoExecConfigCaching & Made my Tagging system OFF by default xD
	1.4.1 - Removed Caching because it is not necessary, added my URL, and then applied ddhoward's suggestions
*/