#include <sourcemod>
#include <sdktools>
#include <autoexecconfig>
#include <csgocolors>

#pragma semicolon 1

#define SOUND_BLIP "buttons/blip1.wav"
#define PLUGIN_VERSION "1.3"
 
new g_BeamSprite = -1;
new g_HaloSprite = -1;
new g_iBeaconValidation = 1;
new g_bBeaconOn = false;

new Handle:g_hPluginEnabled = INVALID_HANDLE;
new bool:g_bPluginEnabled;

new Handle:g_hTagEnabled = INVALID_HANDLE;
new bool:g_bTagEnabled;

new Handle:g_hMinimumBeacon = INVALID_HANDLE;
new g_iMinimumBeacon;

new Handle:g_hPluginColor = INVALID_HANDLE;
new bool:g_bPluginColor;

new Handle:g_hBeaconRadius = INVALID_HANDLE;
new Float:g_fBeaconRadius;

new Handle:g_hBeaconWidth = INVALID_HANDLE;
new Float:g_fBeaconWidth;

new Handle:g_hBeaconTimelimit = INVALID_HANDLE;
new Float:g_fBeaconTimelimit;

new Handle:g_hWarnPlayers = INVALID_HANDLE;
new bool:g_bWarnPlayers;

new ga_iRedColor[4] = {255, 75, 75, 255};

public Plugin:myinfo =
{
    name = "Hunger Games Beacon",
    author = "Headline",
    description = "Beacons players designed for Hunger Games",
    version = PLUGIN_VERSION
};

public OnConfigsExecuted()
{
	if (g_bTagEnabled)
	{
		new Handle:hTags = FindConVar("sv_tags");
		decl String:sTags[128];
		GetConVarString(hTags, sTags, sizeof(sTags));
		StrCat(sTags, sizeof(sTags), ", Headline");
		ServerCommand("sv_tags %s", sTags);
	}
}

public OnPluginStart()
{
	AutoExecConfig_SetFile("sm_beacon");
	AutoExecConfig_SetCreateFile(true);

	AutoExecConfig_CreateConVar("beacon_version", "1.3", "Headline's Beacon Plugin: Version", FCVAR_PLUGIN|FCVAR_NOTIFY);

	g_hPluginEnabled = AutoExecConfig_CreateConVar("sm_beacon_enabled", "1", "Enables and disables the beacon plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	HookConVarChange(g_hPluginEnabled, OnCVarChange);
	g_bPluginEnabled = GetConVarBool(g_hPluginEnabled);
	
	g_hTagEnabled = AutoExecConfig_CreateConVar("sm_tag_enabled", "1", "Allow \"Headline\" to be added to the server tags?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	HookConVarChange(g_hTagEnabled, OnCVarChange);
	g_bTagEnabled = GetConVarBool(g_hTagEnabled);

	g_hMinimumBeacon = AutoExecConfig_CreateConVar("sm_players_for_beacon", "2", "Sets the ammount of players for when the beacon should start", FCVAR_NOTIFY, true, 0.0, true, 32.0);
	HookConVarChange(g_hMinimumBeacon, OnCVarChange);
	g_iMinimumBeacon = GetConVarInt(g_hMinimumBeacon);

	g_hPluginColor = AutoExecConfig_CreateConVar("sm_beacon_color", "1", "Enables and disables the beacon plugin's chat colors", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	HookConVarChange(g_hPluginColor, OnCVarChange);
	g_bPluginColor = GetConVarBool(g_hPluginColor);

	g_hBeaconRadius = AutoExecConfig_CreateConVar("sm_beacon_radius", "750", "Sets the radius for the beacon's rings.", FCVAR_NOTIFY, true, 50.0, true, 1500.0);
	HookConVarChange(g_hBeaconRadius, OnCVarChange);
	g_fBeaconRadius = GetConVarFloat(g_hBeaconRadius);

	g_hBeaconWidth = AutoExecConfig_CreateConVar("sm_beacon_width", "10", "Sets the thickness for the beacon's rings.", FCVAR_NOTIFY, true, 10.0, true, 30.0);
	HookConVarChange(g_hBeaconWidth, OnCVarChange);
	g_fBeaconWidth = GetConVarFloat(g_hBeaconWidth);

	g_hBeaconTimelimit = AutoExecConfig_CreateConVar("sm_beacon_timelimit", "0", "Sets the amount of time (in seconds) until the beacon gets manually turned on (set to 0 to disable)", FCVAR_NOTIFY, true, 0.0, true, 600.0);
	HookConVarChange(g_hBeaconTimelimit, OnCVarChange);
	g_fBeaconTimelimit = GetConVarFloat(g_hBeaconTimelimit);

	g_hWarnPlayers = AutoExecConfig_CreateConVar("sm_warn_players", "0", "If it is = 1, players will be warned to not delay the round when beacons start", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	HookConVarChange(g_hWarnPlayers, OnCVarChange);
	g_bWarnPlayers = GetConVarBool(g_hWarnPlayers);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("round_start", Event_RoundStart);
	
	RegAdminCmd("sm_beaconall", Command_BeaconAll, ADMFLAG_GENERIC, "Toggles beacon on all players");
	RegAdminCmd("sm_stopbeacon", Command_StopBeacon, ADMFLAG_GENERIC, "Toggles beacon on all players");
}

public OnCVarChange(Handle:hCVar, const String:sOldValue[], const String:sNewValue[])
{
	if(hCVar == g_hPluginEnabled)
	{
		g_bPluginEnabled = GetConVarBool(g_hPluginEnabled);
	}
	if(hCVar == g_hPluginColor)
	{
		g_bPluginColor = GetConVarBool(g_hPluginColor);
	}
	if(hCVar == g_hBeaconRadius)
	{
		g_fBeaconRadius = GetConVarFloat(g_hBeaconRadius);
	}
	if(hCVar == g_hBeaconTimelimit)
	{
		g_fBeaconTimelimit = GetConVarFloat(g_hBeaconTimelimit);
	}
	if(hCVar == g_hMinimumBeacon)
	{
		g_iMinimumBeacon = GetConVarInt(g_hMinimumBeacon);
	}
	if(hCVar == g_hWarnPlayers)
	{
		g_bWarnPlayers = GetConVarBool(g_hWarnPlayers);
	}
	if(hCVar == g_hTagEnabled)
	{
		g_bTagEnabled = GetConVarBool(g_hTagEnabled);
	}
}

public OnMapStart()
{
    PrecacheSound(SOUND_BLIP, true);
    g_BeamSprite = PrecacheModel("materials/sprites/bomb_planted_ring.vmt");
    g_HaloSprite = PrecacheModel("materials/sprites/halo.vtf");
    g_iBeaconValidation = 1;
}

public OnClientDisconnected(client)
{
	if (!g_bPluginEnabled)
	{
		return;
	}
	
	if(GetPlayerCount() == g_iMinimumBeacon)
	{
		g_iBeaconValidation++;
		CreateTimer(1.0, BeaconAll_Callback, g_iBeaconValidation, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:Event_PlayerDeath(Handle:hEvent, const String:sName[], bool:bDontBroadcast)
{
	if (!g_bPluginEnabled)
	{
		return Plugin_Continue;
	}
	
	if(GetPlayerCount() == g_iMinimumBeacon)
	{
		if (g_bWarnPlayers)
		{
			if (!g_bPluginColor)
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

public Action:Event_RoundStart(Handle:hEvent, const String:sName[], bool:bDontBroadcast)
{
	if (!g_bPluginEnabled)
	{
		return Plugin_Continue;
	}
	g_iBeaconValidation++;
	if (!g_fBeaconTimelimit)
	{
		return Plugin_Continue;
	}
	g_bBeaconOn = false;
	CreateTimer(g_fBeaconTimelimit, beacon_all_timelimit, g_iBeaconValidation, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

public Action:beacon_all_timelimit(Handle:hTimer, any:iValidation)
{
	if(g_iBeaconValidation == iValidation)
	{
		g_iBeaconValidation++;
		CreateTimer(1.0, BeaconAll_Callback, g_iBeaconValidation, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:Event_RoundEnd(Handle:hEvent, const String:sName[], bool:bDontBroadcast)
{
	if (!g_bPluginEnabled)
	{
		return Plugin_Continue;
	}
	g_bBeaconOn = false;
	g_iBeaconValidation++;
	return Plugin_Continue;
}

public Action:Command_StopBeacon(client, iArgs)
{
	if (iArgs != 0)
	{
		PrintToConsole(client, "[SM] Usage : sm_stopbeacon");
	}
	if (!g_bPluginEnabled)
	{
		ReplyToCommand(client, "Hunger Games Beacon is Disabled");
		return Plugin_Handled;
	}
	g_iBeaconValidation++;
	g_bBeaconOn = false;
	if (!g_bPluginColor)
	{
		PrintToChatAll("[SM] %N toggled beacon OFF", client);
	}
	else
	{
		CPrintToChatAll("[SM] {PINK}%N {NORMAL}toggled beacon {PINK}OFF", client);
	}
	return Plugin_Handled;
}

public Action:Command_BeaconAll(client, iArgs)
 {
	if (iArgs != 0)
	{
		PrintToConsole(client, "[SM] Usage : beaconall");
	}
	if (!g_bPluginEnabled)
	{
		ReplyToCommand(client, "Hunger Games Beacon is Disabled");
		return Plugin_Handled;
	}
	if (!g_bPluginColor)
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
		if (!g_bPluginColor)
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

public Action:BeaconAll_Callback(Handle:hTimer, any:iValidation)
{
	if(iValidation != g_iBeaconValidation)
	{
		return Plugin_Stop;
	}
	for(new i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) >= 2)
		{
			new Float:a_fOrigin[3];
			GetClientAbsOrigin(i, a_fOrigin);
			a_fOrigin[2] += 10;
			TE_SetupBeamRingPoint(a_fOrigin, 10.0, g_fBeaconRadius, g_BeamSprite, g_HaloSprite, 0, 10, 0.6, g_fBeaconWidth, 0.5, ga_iRedColor, 5, 0);

			TE_SendToAll();

			GetClientEyePosition(i, a_fOrigin);
			EmitAmbientSound(SOUND_BLIP, a_fOrigin, i, SNDLEVEL_RAIDSIREN);
		}
	}
	return Plugin_Continue;
}

bool IsValidClient(iClient)
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

GetPlayerCount()
{
	new iPlayers;
	for (new i = 1; i <= MaxClients; i++)
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
*/