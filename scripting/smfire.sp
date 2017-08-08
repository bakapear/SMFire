#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <tf2_stocks>

int iCounter;
int iEntity[MAXPLAYERS + 1] = 0;
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

public bool filter_player(int entity, int mask, any data) {
	return entity > GetMaxClients() || !entity;
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
	else if (StrEqual(target, "!aim", false)) {
		float playerang[3]; GetClientEyeAngles(client, playerang);
		float playerorg[3]; GetClientEyePosition(client, playerorg);
		Handle trace = TR_TraceRayFilterEx(playerorg, playerang, MASK_SHOT, RayType_Infinite, filter_player);
		if (TR_DidHit(trace)) {
			float endpos[3]; TR_GetEndPosition(endpos, trace);
			int entity = TR_GetEntityIndex(trace);
			ent_trace(client, playerorg, playerang, endpos, entity, action, value);
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
				char tname[128]; GetEntPropString(e, Prop_Data, "m_iName", tname, sizeof(tname));
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
				char ename[128]; GetEntityClassname(e, ename, sizeof(ename));
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
	iCounter = 0;
}

void ent_action(int client, int itarget, char[] action, char[] value, bool multiple) {
	iCounter++;
	if (itarget <= 0 || !IsValidEntity(itarget)) {
		if (iCounter == 1)
			PrintToChat(client, "[SM] Invalid target!");
	}
	else if (StrEqual(action, "data", false)) {
		char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
		char tname[128]; GetEntPropString(itarget, Prop_Data, "m_iName", tname, sizeof(tname));
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
			if (StrEqual(value, "")) {
				if (iCounter == 1)
					PrintToChat(client, "[SM] removeslot <value>");
			}
			else {
				int ivalue = StringToInt(value);
				TF2_RemoveWeaponSlot(itarget, ivalue);
			}
		}
		else {
			if (iCounter == 1)
				PrintToChat(client, "[SM] Target must be a player!");
		}
	}
	else if (StrEqual(action, "stun", false)) {
		char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
		if (StrEqual(ename, "player")) {
			if (StrEqual(value, "")) {
				if (iCounter == 1)
					PrintToChat(client, "[SM] stun <value>");
			}
			else {
				float fvalue = StringToFloat(value);
				TF2_StunPlayer(itarget, fvalue, 0.0, TF_STUNFLAGS_BIGBONK, 0);
			}
		}
		else {
			if (iCounter == 1)
				PrintToChat(client, "[SM] Target must be a player!");
		}
	}
	else if (StrEqual(action, "setname", false)) {
		if (StrEqual(value, "")) {
			if (iCounter == 1)
				PrintToChat(client, "[SM] setname <name>");
		}
		else {
			char newvalue[128]; Format(newvalue, sizeof(newvalue), "targetname %s", value);
			SetVariantString(newvalue);
			AcceptEntityInput(itarget, "addoutput");
		}
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
		if (StrEqual(value, "")) {
			if (iCounter == 1)
				PrintToChat(client, "[SM] addorg <x> <y> <z>");
		}
		else {
			float entorg[3]; GetEntPropVector(itarget, Prop_Data, "m_vecOrigin", entorg);
			char num[32][6]; ExplodeString(value, " ", num, 6, sizeof(num));
			entorg[0] += StringToFloat(num[0]);
			entorg[1] += StringToFloat(num[1]);
			entorg[2] += StringToFloat(num[2]);
			TeleportEntity(itarget, entorg, NULL_VECTOR, NULL_VECTOR);
		}
	}
	else if (StrEqual(action, "addang", false)) {
		if (StrEqual(value, "")) {
			if (iCounter == 1)
				PrintToChat(client, "[SM] addang <pitch> <yaw> <roll>");
		}
		else {
			float entang[3]; GetEntPropVector(itarget, Prop_Data, "m_angRotation", entang);
			char num[32][6]; ExplodeString(value, " ", num, 6, sizeof(num));
			entang[0] += StringToFloat(num[0]);
			entang[1] += StringToFloat(num[1]);
			entang[2] += StringToFloat(num[2]);
			TeleportEntity(itarget, NULL_VECTOR, entang, NULL_VECTOR);
		}
	}
	else if (StrEqual(action, "setorg", false)) {
		if (StrEqual(value, "")) {
			if (iCounter == 1)
				PrintToChat(client, "[SM] setorg <x> <y> <z>");
		}
		else {
			float entorg[3]; char num[32][6];
			ExplodeString(value, " ", num, 6, sizeof(num));
			entorg[0] = StringToFloat(num[0]);
			entorg[1] = StringToFloat(num[1]);
			entorg[2] = StringToFloat(num[2]);
			TeleportEntity(itarget, entorg, NULL_VECTOR, NULL_VECTOR);
		}
	}
	else if (StrEqual(action, "setang", false)) {
		if (StrEqual(value, "")) {
			if (iCounter == 1)
				PrintToChat(client, "[SM] setang <pitch> <yaw> <roll>");
		}
		else {
			float entang[3]; char num[32][6];
			ExplodeString(value, " ", num, 6, sizeof(num));
			entang[0] = StringToFloat(num[0]);
			entang[1] = StringToFloat(num[1]);
			entang[2] = StringToFloat(num[2]);
			TeleportEntity(itarget, NULL_VECTOR, entang, NULL_VECTOR);
		}
	}
	else if (StrEqual(action, "copy", false)) {
		if (multiple == false) {
			char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
			if (StrEqual(ename, "prop_dynamic") || StrEqual(ename, "prop_physics") || StrEqual(ename, "prop_static")) {
				if (StrEqual(value, "")) {
					if (iCounter == 1)
						PrintToChat(client, "[SM] copy <x> <y> <z> <pitch> <yaw> <roll>");
				}
				else {
					char model[512]; GetEntPropString(itarget, Prop_Data, "m_ModelName", model, sizeof(model));
					char tname[128]; GetEntPropString(itarget, Prop_Data, "m_iName", tname, sizeof(tname));
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
			}
			else {
				if (iCounter == 1)
					PrintToChat(client, "[SM] Target must be a prop!");
			}
		}
		else {
			if (iCounter == 1)
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
			if (iCounter == 1)
				PrintToChat(client, "[SM] Target must be a player!");
		}
	}
	else if (StrEqual(action, "setheadscale", false)) {
		char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
		if (StrEqual(ename, "player")) {
			if (StrEqual(value, "")) {
				if (iCounter == 1)
					PrintToChat(client, "[SM] setheadscale <value>");
			}
			else {
				fHeadScale[client] = StringToFloat(value);
				SetEntPropFloat(itarget, Prop_Send, "m_flHeadScale", fHeadScale[itarget]);
			}
		}
		else {
			if (iCounter == 1)
				PrintToChat(client, "[SM] Target must be a player!");
		}
	}
	else if (StrEqual(action, "settorsoscale", false)) {
		char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
		if (StrEqual(ename, "player")) {
			if (StrEqual(value, "")) {
				if (iCounter == 1)
					PrintToChat(client, "[SM] settorsoscale <value>");
			}
			else {
				fTorsoScale[client] = StringToFloat(value);
				SetEntPropFloat(itarget, Prop_Send, "m_flTorsoScale", fTorsoScale[itarget]);
			}
		}
		else {
			if (iCounter == 1)
				PrintToChat(client, "[SM] Target must be a player!");
		}
	}
	else if (StrEqual(action, "sethandscale", false)) {
		char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
		if (StrEqual(ename, "player")) {
			if (StrEqual(value, "")) {
				if (iCounter == 1)
					PrintToChat(client, "[SM] sethandscale <value>");
			}
			else {
				fHandScale[client] = StringToFloat(value);
				SetEntPropFloat(itarget, Prop_Send, "m_flHandScale", fHandScale[itarget]);
			}
		}
		else {
			if (iCounter == 1)
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
			if (iCounter == 1)
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
			if (iCounter == 1)
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
			if (iCounter == 1)
				PrintToChat(client, "[SM] Target must be a player!");
		}
	}
	else if (StrEqual(action, "teleport", false)) {
		char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
		if (StrEqual(ename, "player")) {
			if (StrEqual(value, "!picker", false)) {
				int newtarget = GetClientAimTarget(client, false);
				float playerorg[3]; GetClientEyePosition(newtarget, playerorg);
				TeleportEntity(itarget, playerorg, NULL_VECTOR, NULL_VECTOR);
			}
			else if (StrEqual(value, "!self", false)) {
				int newtarget = client;
				float playerorg[3]; GetClientEyePosition(newtarget, playerorg);
				TeleportEntity(itarget, playerorg, NULL_VECTOR, NULL_VECTOR);
			}
			else if (StrContains(value, "@", false) == 0) {
				strcopy(value, 64, value[1]);
				int newtarget = FindTarget(client, value, false, false);
				if (newtarget != -1) {
					float playerorg[3]; GetClientEyePosition(newtarget, playerorg);
					TeleportEntity(itarget, playerorg, NULL_VECTOR, NULL_VECTOR);
				}
			}
			else if (StrContains(value, "*", false) == 0) {
				strcopy(value, 64, value[1]);
				int newtarget = StringToInt(value);
				float playerorg[3]; GetClientEyePosition(newtarget, playerorg);
				TeleportEntity(itarget, playerorg, NULL_VECTOR, NULL_VECTOR);
			}
			else if (StrEqual(value, "")) {
				if (iCounter == 1)
					PrintToChat(client, "[SM] teleport <target>");
			}
			else {
				if (iCounter == 1)
					PrintToChat(client, "[SM] Target invalid!");
			}
			
		}
		else {
			if (iCounter == 1)
				PrintToChat(client, "[SM] Target must be a player!");
		}
	}
	else if (StrEqual(action, "addcond", false)) {
		char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
		if (StrEqual(ename, "player")) {
			if (StrEqual(value, "")) {
				if (iCounter == 1)
					PrintToChat(client, "[SM] addcond <condition>");
			}
			else {
				int condition = StringToInt(value);
				TF2_AddCondition(itarget, view_as<TFCond>(condition));
			}
			
		}
		else {
			if (iCounter == 1)
				PrintToChat(client, "[SM] Target must be a player!");
		}
	}
	else if (StrEqual(action, "removecond", false)) {
		char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
		if (StrEqual(ename, "player")) {
			if (StrEqual(value, "")) {
				if (iCounter == 1)
					PrintToChat(client, "[SM] removecond <condition>");
			}
			else {
				int condition = StringToInt(value);
				TF2_RemoveCondition(itarget, view_as<TFCond>(condition));
			}
			
		}
		else {
			if (iCounter == 1)
				PrintToChat(client, "[SM] Target must be a player!");
		}
	}
	else if (StrContains(action, "m_", false) == 0) {
		if (multiple == false) {
			char part[32][6]; ExplodeString(value, " ", part, 2, sizeof(part), true);
			PropFieldType type;
			int info = FindDataMapInfo(client, action, type);
			if (info != -1) {
				if (StrEqual(part[0], "set")) {
					if (StrEqual(part[1], "")) {
						PrintToChat(client, "[SM] m_* get/set <value>");
					}
					else if (type == PropField_Integer) {
						SetEntProp(itarget, Prop_Data, action, StringToInt(part[1]));
						PrintToChat(client, "[SM] Set %s to %s", action, part[1]);
					}
					else if (type == PropField_Float) {
						SetEntPropFloat(itarget, Prop_Data, action, StringToFloat(part[1]));
						PrintToChat(client, "[SM] Set %s to %s", action, part[1]);
					}
					else if (type == PropField_String) {
						SetEntPropString(itarget, Prop_Data, action, part[1]);
						PrintToChat(client, "[SM] Set %s to %s", action, part[1]);
					}
					else if (type == PropField_Vector) {
						float vector[3]; char num[64][6];
						ExplodeString(part[1], " ", num, 3, sizeof(num), false);
						vector[0] = StringToFloat(num[0]);
						vector[1] = StringToFloat(num[1]);
						vector[2] = StringToFloat(num[2]);
						SetEntPropVector(itarget, Prop_Data, action, vector);
						PrintToChat(client, "[SM] Set %s to %.0f %.0f %.0f", action, vector[0], vector[1], vector[2]);
					}
					else if (type == PropField_Entity) {
						SetEntPropEnt(itarget, Prop_Data, action, StringToInt(part[1]));
						PrintToChat(client, "[SM] Set %s to %s", action, part[1]);
					}
				}
				else if (StrEqual(part[0], "get")) {
					if (type == PropField_Integer) {
						int data = GetEntProp(itarget, Prop_Data, action);
						PrintToChat(client, "\x03%i", data);
					}
					else if (type == PropField_Float) {
						float data = GetEntPropFloat(itarget, Prop_Data, action);
						PrintToChat(client, "\x03%.0f", data);
					}
					else if (type == PropField_String) {
						char buffer[256];
						GetEntPropString(itarget, Prop_Data, action, buffer, sizeof(buffer));
						PrintToChat(client, "\x03%s", buffer);
					}
					else if (type == PropField_Vector) {
						float vector[3];
						GetEntPropVector(itarget, Prop_Data, action, vector);
						PrintToChat(client, "\x03%.0f %.0f %.0f", vector[0], vector[1], vector[2]);
					}
					else if (type == PropField_Entity) {
						int data = GetEntPropEnt(itarget, Prop_Data, action);
						PrintToChat(client, "\x03%i", data);
					}
				}
				else {
					PrintToChat(client, "[SM] m_* get/set <value>");
				}
			}
			else {
				PrintToChat(client, "[SM] %s not found!", action);
			}
		}
		else {
			if (iCounter == 1)
				PrintToChat(client, "[SM] Only one target allowed!");
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

void ent_trace(int client, float startpos[3], float startang[3], float endpos[3], int entity, char[] action, char[] value) {
	if (StrEqual(action, "data", false)) {
		PrintToChat(client, "StartPos: %.0f %.0f %.0f", startpos[0], startpos[1], startpos[2]);
		PrintToChat(client, "StartAng: %.0f %.0f %.0f", startang[0], startang[1], startang[2]);
		PrintToChat(client, "EndPos: %.0f %.0f %.0f", endpos[0], endpos[1], endpos[2]);
		PrintToChat(client, "Hit: %i", entity);
	}
	else if (StrEqual(action, "prop", false)) {
		if (StrEqual(value, "")) {
			PrintToChat(client, "[SM] prop <modelpath>");
		}
		else {
			PrecacheModel(value);
			int prop = CreateEntityByName("prop_dynamic");
			DispatchKeyValue(prop, "physdamagescale", "0.0");
			DispatchKeyValue(prop, "Solid", "6");
			DispatchKeyValue(prop, "model", value);
			DispatchSpawn(prop);
			float propang[3];
			propang[1] = 180 + startang[1];
			TeleportEntity(prop, endpos, propang, NULL_VECTOR);
		}
	}
	else if (StrEqual(action, "create", false)) {
		if (StrEqual(value, "")) {
			PrintToChat(client, "[SM] create <entity>");
		}
		else {
			if (StrEqual(value, "0") || StrEqual(value, "-1")) {
				PrintToChat(client, "[SM] Cannot create that entity!");
			}
			else if (iEntity[client] == 0) {
				iEntity[client] = CreateEntityByName(value);
				if (IsValidEntity(iEntity[client])) {
					PrintToChat(client, "[SM] Entity %i > %s created.", iEntity[client], value);
				}
				else {
					PrintToChat(client, "[SM] Invalid entity!");
					iEntity[client] = 0;
				}
			}
			else {
				PrintToChat(client, "[SM] Please delete or spawn your previous entity first. (%i)", iEntity[client]);
			}
		}
	}
	else if (StrEqual(action, "delete", false)) {
		if (iEntity[client] != 0) {
			char ename[128]; GetEntityClassname(iEntity[client], ename, sizeof(ename));
			PrintToChat(client, "[SM] Entity %i > %s deleted", iEntity[client], ename);
			RemoveEdict(iEntity[client]);
			iEntity[client] = 0;
		}
		else {
			PrintToChat(client, "[SM] No entity created yet.", iEntity[client]);
		}
	}
	else if (StrEqual(action, "value", false)) {
		if (StrEqual(value, "")) {
			PrintToChat(client, "[SM] value <key> <value>");
		}
		else {
			if (iEntity[client] != 0) {
				char ename[128]; GetEntityClassname(iEntity[client], ename, sizeof(ename));
				char part[32][6]; ExplodeString(value, " ", part, 2, sizeof(part), true);
				DispatchKeyValue(iEntity[client], part[0], part[1]);
				PrintToChat(client, "[SM] Key:\"%s\" Value:\"%s\"", part[0], part[1]);
				PrintToChat(client, "added to entity %i > %s", iEntity[client], ename);
			}
			else {
				PrintToChat(client, "[SM] No entity created yet.", iEntity[client]);
			}
		}
	}
	else if (StrEqual(action, "spawn", false)) {
		if (iEntity[client] != 0) {
			char ename[128]; GetEntityClassname(iEntity[client], ename, sizeof(ename));
			PrintToChat(client, "[SM] Entity %i > %s spawned.", iEntity[client], ename);
			DispatchSpawn(iEntity[client]);
			float propang[3];
			propang[1] = 180 + startang[1];
			TeleportEntity(iEntity[client], endpos, propang, NULL_VECTOR);
			iEntity[client] = 0;
		}
		else {
			PrintToChat(client, "[SM] No entity created yet.", iEntity[client]);
		}
	}
	
} 