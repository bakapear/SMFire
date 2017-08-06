#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <tf2_stocks>

float fHeadScale[MAXPLAYERS + 1];
float fTorsoScale[MAXPLAYERS + 1];
float fHandScale[MAXPLAYERS + 1];
bool bThirdperson[MAXPLAYERS + 1];

public Plugin myinfo =  {
	name = "SM_Fire", 
	author = "pear", 
	description = "", 
	version = "1.0", 
	url = ""
};

public void OnPluginStart() {
	LoadTranslations("common.phrases");
	RegAdminCmd("sm_fire", sm_fire, ADMFLAG_BAN, "[SM] Usage: sm_fire <target> <action> <value>");
	HookEvent("player_spawn", event_playerspawn, EventHookMode_Post);
	for (int i = 1; i <= MaxClients; i++) {
		fHeadScale[i] = 1.0;
		fTorsoScale[i] = 1.0;
		fHandScale[i] = 1.0;
		bThirdperson[i] = false;
	}
}

public void OnGameFrame() {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsPlayerAlive(i)) {
			if (fHeadScale[i] != 1.0) {
				SetEntPropFloat(i, Prop_Send, "m_flHeadScale", fHeadScale[i]);
			}
			if (fTorsoScale[i] != 1.0) {
				SetEntPropFloat(i, Prop_Send, "m_flTorsoScale", fTorsoScale[i]);
			}
			if (fHandScale[i] != 1.0) {
				SetEntPropFloat(i, Prop_Send, "m_flHandScale", fHandScale[i]);
			}
		}
	}
}

public Action event_playerspawn(Handle event, char[] name, bool dontbroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (bThirdperson[client] == true) {
		CreateTimer(0.1, spawn_thirdperson, client);
	}
}

public Action spawn_thirdperson(Handle timer, any client) {
	SetVariantInt(1);
	AcceptEntityInput(client, "SetForcedTauntCam");
}

public Action sm_fire(int client, int args) {
	if (client == 0) { return Plugin_Handled; }
	if (args < 2) {
		ReplyToCommand(client, "[SM] Usage: sm_fire <target> <action> <value>");
		return Plugin_Handled;
	}
	char arg1[256]; GetCmdArg(1, arg1, sizeof(arg1));
	char arg2[256]; GetCmdArg(2, arg2, sizeof(arg2));
	char arg3[256]; GetCmdArgString(arg3, sizeof(arg3));
	int len1 = strlen(arg1); int len2 = strlen(arg2);
	int len3 = len1 + len2;
	strcopy(arg3, sizeof(arg3), arg3[len3 + 2]);
	ent_fire(client, arg1, arg2, arg3);
	return Plugin_Handled;
}

void ent_fire(int client, char[] target, char[] action, char[] value) {
	int num;
	if (StrEqual(target, "!picker", false)) {
		int itarget = GetClientAimTarget(client, false);
		ent_action(client, itarget, action, value, false);
	}
	else if (StrEqual(target, "!self", false)) {
		int itarget = client;
		ent_action(client, itarget, action, value, false);
	}
	else if (StrEqual(target, "!all", false)) {
		if (StrEqual(action, "data", false)) {
			for (int e = 1; e <= GetMaxEntities(); e++) {
				if (IsValidEntity(e)) {
					if (e != -1) {
						int itarget = e;
						ent_action(client, itarget, action, value, true);
						num++;
					}
				}
			}
		}
		else {
			for (int i = 1; i <= MaxClients; i++) {
				if (IsClientInGame(i)) {
					int itarget = i;
					ent_action(client, itarget, action, value, true);
				}
			}
		}
	}
	else if (StrEqual(target, "!blue", false)) {
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i)) {
				int team = GetClientTeam(i);
				if (team == 3) {
					int itarget = i;
					ent_action(client, itarget, action, value, true);
					num++;
				}
			}
		}
	}
	else if (StrEqual(target, "!red", false)) {
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i)) {
				int team = GetClientTeam(i);
				if (team == 2) {
					int itarget = i;
					ent_action(client, itarget, action, value, true);
					num++;
				}
			}
		}
	}
	else if (StrEqual(target, "!bots", false)) {
		for (int i = 1; i <= MaxClients; i++) {
			if (IsFakeClient(i)) {
				int itarget = i;
				ent_action(client, itarget, action, value, true);
				num++;
			}
		}
	}
	else if (StrContains(target, "@", false) == 0) {
		strcopy(target, 64, target[1]);
		int itarget = FindTarget(client, target, false, false);
		if (itarget != -1) {
			ent_action(client, itarget, action, value, false);
		}
	}
	else if (StrContains(target, "*", false) == 0) {
		strcopy(target, 64, target[1]);
		int itarget = StringToInt(target);
		ent_action(client, itarget, action, value, false);
	}
	else if (StrContains(target, "#", false) == 0) {
		strcopy(target, 64, target[1]);
		for (int e = 1; e <= GetMaxEntities(); e++) {
			if (IsValidEntity(e)) {
				char tname[64]; GetEntPropString(e, Prop_Data, "m_iName", tname, sizeof(tname));
				if (StrEqual(target, tname)) {
					if (e != -1) {
						int itarget = e;
						ent_action(client, itarget, action, value, true);
						num++;
					}
				}
			}
		}
	}
	else {
		for (int e = 1; e <= GetMaxEntities(); e++) {
			if (IsValidEntity(e)) {
				char ename[64]; GetEntityClassname(e, ename, sizeof(ename));
				if (StrEqual(target, ename)) {
					if (e != -1) {
						int itarget = e;
						ent_action(client, itarget, action, value, true);
						num++;
					}
				}
			}
		}
	}
	
	if (StrEqual(action, "data", false) && num >= 1) {
		PrintToChat(client, "[SM] %i entities printed to console!", num);
	}
}

void ent_action(int client, int itarget, char[] action, char[] value, bool multiple) {
	if (itarget <= 0 || !IsValidEntity(itarget)) {
		PrintToChat(client, "[SM] Invalid target!");
	}
	else if (StrEqual(action, "data", false)) {
		char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
		char tname[64]; GetEntPropString(itarget, Prop_Data, "m_iName", tname, sizeof(tname));
		char model[512]; GetEntPropString(itarget, Prop_Data, "m_ModelName", model, sizeof(model));
		char parent[256]; GetEntPropString(itarget, Prop_Data, "m_iParent", parent, sizeof(parent));
		float entang[3]; GetEntPropVector(itarget, Prop_Data, "m_angRotation", entang);
		float entorg[3]; GetEntPropVector(itarget, Prop_Data, "m_vecOrigin", entorg);
		float entvec[3]; GetEntPropVector(itarget, Prop_Data, "m_vecVelocity", entvec);
		if (StrEqual(tname, "")) { strcopy(tname, sizeof(tname), "N/A"); }
		if (StrEqual(model, "")) { strcopy(model, sizeof(model), "N/A"); }
		if (StrEqual(parent, "")) { strcopy(parent, sizeof(parent), "N/A"); }
		if (multiple == false) {
			ReplyToCommand(client, "\x03%i > Classname: %s - Name: %s", itarget, ename, tname);
			if (StrEqual(value, "full", false)) {
				ReplyToCommand(client, "Model: %s", model);
				ReplyToCommand(client, "Parent: %s", model);
				ReplyToCommand(client, "Origin: %.0f %.0f %.0f", entorg[0], entorg[1], entorg[2]);
				ReplyToCommand(client, "Angles: %.0f %.0f %.0f", entang[0], entang[1], entang[2]);
				ReplyToCommand(client, "Velocity: %.0f %.0f %.0f", entvec[0], entvec[1], entvec[2]);
			}
		}
		else {
			PrintToConsole(client, "%i > Classname: %s - Name: %s", itarget, ename, tname);
		}
	}
	else if (StrEqual(action, "removeslot", false)) {
		char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
		if (StrEqual(ename, "player")) {
			int ivalue = StringToInt(value);
			TF2_RemoveWeaponSlot(itarget, ivalue);
		}
		else {
			PrintToChat(client, "[SM] Target must be a player!");
		}
	}
	else if (StrEqual(action, "stun", false)) {
		char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
		if (StrEqual(ename, "player")) {
			float fvalue = StringToFloat(value);
			TF2_StunPlayer(itarget, fvalue, 0.0, TF_STUNFLAGS_BIGBONK, 0);
		}
		else {
			PrintToChat(client, "[SM] Target must be a player!");
		}
	}
	else if (StrEqual(action, "setname", false)) {
		char newvalue[128]; Format(newvalue, sizeof(newvalue), "targetname %s", value);
		SetVariantString(newvalue);
		AcceptEntityInput(itarget, "addoutput");
	}
	else if (StrEqual(action, "kill", false)) {
		char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
		if (StrEqual(ename, "player")) {
			ForcePlayerSuicide(itarget);
		}
		else {
			RemoveEdict(itarget);
		}
	}
	else if (StrEqual(action, "addorg", false)) {
		float entorg[3]; GetEntPropVector(itarget, Prop_Data, "m_vecOrigin", entorg);
		char num[32][6]; ExplodeString(value, " ", num, 6, sizeof(num));
		entorg[0] += StringToFloat(num[0]);
		entorg[1] += StringToFloat(num[1]);
		entorg[2] += StringToFloat(num[2]);
		TeleportEntity(itarget, entorg, NULL_VECTOR, NULL_VECTOR);
	}
	else if (StrEqual(action, "addang", false)) {
		float entang[3]; GetEntPropVector(itarget, Prop_Data, "m_angRotation", entang);
		char num[32][6]; ExplodeString(value, " ", num, 6, sizeof(num));
		entang[0] += StringToFloat(num[0]);
		entang[1] += StringToFloat(num[1]);
		entang[2] += StringToFloat(num[2]);
		TeleportEntity(itarget, NULL_VECTOR, entang, NULL_VECTOR);
	}
	else if (StrEqual(action, "setorg", false)) {
		float entorg[3]; char num[32][6];
		ExplodeString(value, " ", num, 6, sizeof(num));
		entorg[0] = StringToFloat(num[0]);
		entorg[1] = StringToFloat(num[1]);
		entorg[2] = StringToFloat(num[2]);
		TeleportEntity(itarget, entorg, NULL_VECTOR, NULL_VECTOR);
	}
	else if (StrEqual(action, "setang", false)) {
		float entang[3]; char num[32][6];
		ExplodeString(value, " ", num, 6, sizeof(num));
		entang[0] = StringToFloat(num[0]);
		entang[1] = StringToFloat(num[1]);
		entang[2] = StringToFloat(num[2]);
		TeleportEntity(itarget, NULL_VECTOR, entang, NULL_VECTOR);
	}
	else if (StrEqual(action, "copy", false)) {
		if (multiple == false) {
			char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
			if (StrEqual(ename, "prop_dynamic") || StrEqual(ename, "prop_physics") || StrEqual(ename, "prop_static")) {
				char model[512]; GetEntPropString(itarget, Prop_Data, "m_ModelName", model, sizeof(model));
				char tname[64]; GetEntPropString(itarget, Prop_Data, "m_iName", tname, sizeof(tname));
				float entang[3]; GetEntPropVector(itarget, Prop_Data, "m_angRotation", entang);
				float entorg[3]; GetEntPropVector(itarget, Prop_Data, "m_vecOrigin", entorg);
				int ent = CreateEntityByName("prop_dynamic");
				if (ent != -1) {
					DispatchKeyValue(ent, "targetname", tname);
					DispatchKeyValue(ent, "model", model);
					DispatchKeyValue(ent, "solid", "6");
					DispatchKeyValue(ent, "physdamagescale", "0.0");
				}
				DispatchSpawn(ent);
				ActivateEntity(ent);
				char num[32][12]; ExplodeString(value, " ", num, 12, sizeof(num));
				entorg[0] += StringToFloat(num[0]);
				entorg[1] += StringToFloat(num[1]);
				entorg[2] += StringToFloat(num[2]);
				entang[0] += StringToFloat(num[3]);
				entang[1] += StringToFloat(num[4]);
				entang[2] += StringToFloat(num[5]);
				TeleportEntity(ent, entorg, entang, NULL_VECTOR);
			}
			else {
				PrintToChat(client, "[SM] Target must be a prop!");
			}
		}
		else {
			PrintToChat(client, "[SM] Only one target allowed!");
		}
	}
	else if (StrEqual(action, "class", false)) {
		char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
		if (StrEqual(ename, "player")) {
			TFClassType class;
			if (StrEqual(value, "scout", false)) { class = TFClass_Scout; }
			else if (StrEqual(value, "soldier", false)) { class = TFClass_Soldier; }
			else if (StrEqual(value, "pyro", false)) { class = TFClass_Pyro; }
			else if (StrEqual(value, "demoman", false)) { class = TFClass_DemoMan; }
			else if (StrEqual(value, "heavy", false)) { class = TFClass_Heavy; }
			else if (StrEqual(value, "engineer", false)) { class = TFClass_Engineer; }
			else if (StrEqual(value, "medic", false)) { class = TFClass_Medic; }
			else if (StrEqual(value, "sniper", false)) { class = TFClass_Sniper; }
			else if (StrEqual(value, "spy", false)) { class = TFClass_Spy; }
			else { class = TF2_GetPlayerClass(itarget); }
			TF2_SetPlayerClass(itarget, class);
			SetEntityHealth(itarget, 25);
			TF2_RegeneratePlayer(itarget);
			int weapon = GetPlayerWeaponSlot(itarget, TFWeaponSlot_Primary);
			if (IsValidEntity(weapon)) {
				SetEntPropEnt(itarget, Prop_Send, "m_hActiveWeapon", weapon);
			}
		}
		else {
			PrintToChat(client, "[SM] Target must be a player!");
		}
	}
	else if (StrEqual(action, "setheadscale", false)) {
		char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
		if (StrEqual(ename, "player")) {
			fHeadScale[client] = StringToFloat(value);
			SetEntPropFloat(itarget, Prop_Send, "m_flHeadScale", fHeadScale[itarget]);
		}
		else {
			PrintToChat(client, "[SM] Target must be a player!");
		}
	}
	else if (StrEqual(action, "settorsoscale", false)) {
		char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
		if (StrEqual(ename, "player")) {
			fTorsoScale[client] = StringToFloat(value);
			SetEntPropFloat(itarget, Prop_Send, "m_flTorsoScale", fTorsoScale[itarget]);
		}
		else {
			PrintToChat(client, "[SM] Target must be a player!");
		}
	}
	else if (StrEqual(action, "sethandscale", false)) {
		char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
		if (StrEqual(ename, "player")) {
			fHandScale[client] = StringToFloat(value);
			SetEntPropFloat(itarget, Prop_Send, "m_flHandScale", fHandScale[itarget]);
		}
		else {
			PrintToChat(client, "[SM] Target must be a player!");
		}
	}
	else if (StrEqual(action, "resetscale", false)) {
		char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
		if (StrEqual(ename, "player")) {
			fHeadScale[itarget] = 1.0;
			fTorsoScale[itarget] = 1.0;
			fHandScale[itarget] = 1.0;
			SetVariantString("1.0");
			AcceptEntityInput(itarget, "setmodelscale");
		}
		else {
			PrintToChat(client, "[SM] Target must be a player!");
		}
	}
	else if (StrEqual(action, "fp", false) || StrEqual(action, "firstperson", false)) {
		char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
		if (StrEqual(ename, "player")) {
			SetVariantInt(0);
			AcceptEntityInput(itarget, "SetForcedTauntCam");
			bThirdperson[itarget] = false;
		}
		else {
			PrintToChat(client, "[SM] Target must be a player!");
		}
	}
	else if (StrEqual(action, "tp", false) || StrEqual(action, "thirdperson", false)) {
		char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
		if (StrEqual(ename, "player")) {
			SetVariantInt(1);
			AcceptEntityInput(itarget, "SetForcedTauntCam");
			bThirdperson[itarget] = true;
		}
		else {
			PrintToChat(client, "[SM] Target must be a player!");
		}
	}
	else if (StrEqual(action, "teleport", false)) {
		char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
		if (StrEqual(ename, "player")) {
			if (StrContains(value, "@", false) == 0) {
				strcopy(value, 64, value[1]);
				int newtarget = FindTarget(client, value, false, false);
				if (newtarget != -1) {
					float playerorg[3]; GetClientEyePosition(newtarget, playerorg);
					TeleportEntity(itarget, playerorg, NULL_VECTOR, NULL_VECTOR);
				}
			}
			else {
				PrintToChat(client, "[SM] Target invalid!");
			}
			
		}
	}
	else {
		SetVariantString(value);
		AcceptEntityInput(itarget, action);
		if (StrEqual(action, "setcustommodel", false)) {
			SetEntProp(itarget, Prop_Send, "m_bCustomModelRotates", 1);
			SetEntProp(itarget, Prop_Send, "m_bUseClassAnimations", TF2_GetPlayerClass(itarget));
		}
	}
} 