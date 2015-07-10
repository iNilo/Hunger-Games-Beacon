#include <sourcemod>
#include <sdktools>
#include <autoexecconfig>
#include <csgocolors>

#pragma semicolon 1
 
#define SOUND_BLIP "buttons/blip1.wav"
#define PLUGIN_VERSION "1.1"
 
new g_BeamSprite = -1;
new g_HaloSprite = -1;

new g_beaconrepeat = 1;

new Handle:g_hPluginEnabled = INVALID_HANDLE;
new bool:g_bPluginEnabled;

new Handle:g_hMinimumBeacon = INVALID_HANDLE;
new g_bMinimumBeacon;

new Handle:g_hPluginColor = INVALID_HANDLE;
new bool:g_bPluginColor;

new Handle:g_hBeaconRadius = INVALID_HANDLE;
new Float:g_fBeaconRadius;

new Handle:g_hBeaconWidth = INVALID_HANDLE;
new Float:g_fBeaconWidth;

new Handle:g_hBeaconTimelimit = INVALID_HANDLE;
new Float:g_fBeaconTimelimit;

new i_RedColor[4] = {255, 75, 75, 255};

new g_iClientValidation[MAXPLAYERS + 1] = {1, ...};

public Plugin:myinfo =
{
    name = "Hunger Games Beacon",
    author = "Headline",
    description = "Beacons players designed for Hunger Games",
    version = PLUGIN_VERSION
};

public OnPluginStart()
{
	AutoExecConfig_SetFile("sm_beacon");
	AutoExecConfig_SetCreateFile(true);

	AutoExecConfig_CreateConVar("beacon_version", PLUGIN_VERSION, "Headline's Beacon Plugin: Version", FCVAR_PLUGIN|FCVAR_NOTIFY);

	g_hPluginEnabled = AutoExecConfig_CreateConVar("sm_beacon_enabled", "1", "Enables and disables the beacon plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	HookConVarChange(g_hPluginEnabled, OnCVarChange);
	g_bPluginEnabled = GetConVarBool(g_hPluginEnabled);
	
	g_hMinimumBeacon = AutoExecConfig_CreateConVar("sm_players_for_beacon", "2", "Sets the ammount of players for when the beacon should start", FCVAR_NOTIFY, true, 0.0, true, 32.0);
	HookConVarChange(g_hMinimumBeacon, OnCVarChange);
	g_bMinimumBeacon = GetConVarInt(g_hMinimumBeacon);
	
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
		g_bMinimumBeacon = GetConVarInt(g_hMinimumBeacon);
	}
}

public OnMapStart()
{
    PrecacheSound(SOUND_BLIP, true);
    g_BeamSprite = PrecacheModel("materials/sprites/bomb_planted_ring.vmt");
    g_HaloSprite = PrecacheModel("materials/sprites/halo.vtf");
    g_beaconrepeat = 1;
}

public OnClientConnected(client)
{
	g_iClientValidation[client] = 0;
}

public OnClientDisconnected(client)
{
	g_iClientValidation[client] = 0;
	if(GetPlayerCount() == 2)
	{
		g_beaconrepeat++;
		for (new i = 1; i <= MaxClients; i++)
		{	
			if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) >= 2)
			{
				g_iClientValidation[i] = g_beaconrepeat;
				CreateTimer(0.1, beacon_all, GetClientUserId(i), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!g_bPluginEnabled)
	{
		return Plugin_Continue;
	}
	if(GetPlayerCount() == g_bMinimumBeacon)
	{
		g_beaconrepeat++;
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) >= 2)
			{
				g_iClientValidation[i] = g_beaconrepeat;
				CreateTimer(1.0, beacon_all, GetClientUserId(i), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
	return Plugin_Continue;
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!g_bPluginEnabled)
	{
		return Plugin_Continue;
	}
	g_beaconrepeat++;
	if (!g_fBeaconTimelimit)
	{
		return Plugin_Continue;
	}
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) >= 2)
		{
			g_iClientValidation[i] = g_beaconrepeat;
			CreateTimer(g_fBeaconTimelimit, beacon_all_timelimit, GetClientUserId(i), TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	return Plugin_Continue;
}

public Action:beacon_all_timelimit(Handle:timer, any:userid)
{
	CreateTimer(1.0, beacon_all, userid, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!g_bPluginEnabled)
	{
		return Plugin_Continue;
	}
	g_beaconrepeat++;
	return Plugin_Continue;
}

public Action:Command_StopBeacon(client, args)
{
	if (!g_bPluginEnabled)
	{
		ReplyToCommand(0, "Hunger Games Beacon is Disabled");
		return Plugin_Handled;
	}
	if (!g_bPluginColor)
	{
		PrintToChatAll("[SM] %N toggled beacon OFF", client);
	}
	else
	{
		CPrintToChatAll("[SM] {PINK}%N {GREEN}toggled beacon {PINK}OFF", client);
	}
	g_beaconrepeat++;
	return Plugin_Handled;
}

public Action:Command_BeaconAll(client, args)
 {
	if (!g_bPluginEnabled)
	{
		ReplyToCommand(0, "Hunger Games Beacon is Disabled");
		return Plugin_Handled;
	}
	if (!g_bPluginColor)
	{
		PrintToChatAll("[SM] %N toggled beacon ON", client);
	}
	else
	{
		CPrintToChatAll("[SM] {PINK}%N {GREEN}toggled beacon {PINK}ON", client);
	}
	g_beaconrepeat++;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) >= 2)
		{
			g_iClientValidation[i] = g_beaconrepeat;
			CreateTimer(1.0, beacon_all, GetClientUserId(i), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	return Plugin_Handled;
}

public Action:beacon_all(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if(g_iClientValidation[client] != g_beaconrepeat)
	{
		return Plugin_Stop;
	}
	if(IsClientInGame(client) && IsPlayerAlive(client) && (0 < client <= MaxClients))
	{
		new Float:vec[3];
		GetClientAbsOrigin(client, vec);
		vec[2] += 10;
		TE_SetupBeamRingPoint(vec, 10.0, g_fBeaconRadius, g_BeamSprite, g_HaloSprite, 0, 10, 0.6, g_fBeaconWidth, 0.5, i_RedColor, 5, 0);

		TE_SendToAll();

		GetClientEyePosition(client, vec);
		EmitAmbientSound(SOUND_BLIP, vec, client, SNDLEVEL_RAIDSIREN);
		return Plugin_Continue;
	}
	return Plugin_Stop;
}

GetPlayerCount()
{
	new players;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) >= 2)
		{
			players++;
		}
	}
	return players;
}

/********** CHANGELOG: ***********************
***** 1.0 - Initial Release ******************
***** 1.1 - Added CVAR sm_players_for_beacon *
*********** CHANGELOG: ***********************/