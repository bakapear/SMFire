#pragma semicolon 1
#pragma newdecls required
#pragma dynamic 131072

#include <sourcemod>
#include <tf2_stocks>

#define MAX_BUTTONS 25
#define IN_SPEED	(1 << 17)
#define PROPSAVE_DIR "data/smfire"

int lastbuttons[MAXPLAYERS + 1];
int iCounter;
int iCopy[MAXPLAYERS + 1];
int iEntity[MAXPLAYERS + 1];
float fHeadScale[MAXPLAYERS + 1];
float fTorsoScale[MAXPLAYERS + 1];
float fHandScale[MAXPLAYERS + 1];
bool bThirdperson[MAXPLAYERS + 1];
int iVoicePitch[MAXPLAYERS + 1];
bool bShift[MAXPLAYERS + 1];
int iShiftMode[MAXPLAYERS + 1];
int iShift[MAXPLAYERS + 1];
int iWeapon[MAXPLAYERS + 1];
int iMove[MAXPLAYERS + 1];
int iMoveTarget[MAXPLAYERS + 1];
bool bMove[MAXPLAYERS + 1];

public Plugin myinfo =  {
	name = "SM_Fire", 
	author = "pear", 
	description = "entity debugging", 
	version = "1.5.4", 
	url = ""
};

public void OnPluginStart() {
	LoadTranslations("common.phrases");
	RegAdminCmd("sm_fire", sm_fire, ADMFLAG_BAN, "[SM] Usage: sm_fire <target> <action> <value>");
	HookEvent("player_spawn", event_playerspawn, EventHookMode_Post);
	AddNormalSoundHook(hook_sound);
	for (int i = 1; i <= MaxClients; i++) {
		fHeadScale[i] = 1.0;
		fTorsoScale[i] = 1.0;
		fHandScale[i] = 1.0;
		bThirdperson[i] = false;
		iVoicePitch[i] = 100;
	}
}

public void OnPluginEnd() {
	for (int e = 1; e <= GetMaxEntities(); e++) {
		if (IsValidEntity(e)) {
			char tname[128]; GetEntPropString(e, Prop_Data, "m_iName", tname, sizeof(tname));
			if (StrContains(tname, "enttemp") == 0) {
				if (e != -1) {
					RemoveEdict(e);
				}
			}
		}
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

public void OnClientDisconnect_Post(int client) {
	lastbuttons[client] = 0;
	if (bMove[client]) {
		DeleteTempEnts(client);
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
	if (entity == data) {
		return false;
	}
	else {
		return true;
	}
}

public bool filter_multiple(int entity, int mask, any data) {
	if (entity == data || entity == iShift[data]) {
		return false;
	}
	else {
		return true;
	}
}

public Action hook_sound(int clients[64], int &numclients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags) {
	if (channel == SNDCHAN_VOICE && entity >= 1 && entity <= MaxClients) {
		if (iVoicePitch[entity] != 100) {
			pitch = iVoicePitch[entity];
			flags |= SND_CHANGEPITCH;
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float velocity[3], float angles[3], int &weapon) {
	for (int i = 0; i < MAX_BUTTONS; i++) {
		int button = (1 << i);
		if ((buttons & button)) {
			if (!(lastbuttons[client] & button)) {
				OnButtonPress(client, button);
			}
		}
	}
	lastbuttons[client] = buttons;
	if (bMove[client] == true) {
		int aim = GetAimEntity(client);
		if (aim > 0) {
			char tname[128]; GetEntPropString(aim, Prop_Data, "m_iName", tname, sizeof(tname));
			char auth[256]; GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));
			char buffer[128]; FormatEx(buffer, sizeof(buffer), "enttemp_%s", auth);
			if (StrContains(tname, buffer) == 0) {
				if (iMoveTarget[client] != aim) {
					if (IsValidEntity(iMoveTarget[client])) {
						SetEntityRenderColor(iMoveTarget[client], 255, 255, 255, 0);
					}
					iMoveTarget[client] = aim;
					SetEntityRenderColor(iMoveTarget[client], 255, 255, 255, 128);
				}
			}
		}
	}
	if (bShift[client] == true && iShift[client] != 0 && IsValidEntity(iShift[client])) {
		if (IsPlayerAlive(client)) {
			float playerang[3]; GetClientEyeAngles(client, playerang);
			float playerorg[3]; GetClientEyePosition(client, playerorg);
			float entorg[3]; GetEntPropVector(iShift[client], Prop_Data, "m_vecOrigin", entorg);
			float entang[3]; GetEntPropVector(iShift[client], Prop_Data, "m_angRotation", entang);
			Handle trace = TR_TraceRayFilterEx(playerorg, playerang, MASK_SHOT, RayType_Infinite, filter_multiple, client);
			float endpos[3]; TR_GetEndPosition(endpos, trace);
			if (iShiftMode[client] != 0) {
				entang[1] = playerang[1] + iShiftMode[client];
			}
			TeleportEntity(iShift[client], endpos, entang, NULL_VECTOR);
			CloseHandle(trace);
		}
		else {
			bShift[client] = false;
			iShift[client] = 0;
			iShiftMode[client] = 0;
			ReplyToCommand(client, "[SM] Stopped shifting.");
		}
	}
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
				if (IsClientInGame(i) && IsClientConnected(i)) {
					int itarget = i;
					ent_action(client, itarget, action, value, true);
				}
			}
		}
	}
	else if (StrEqual(target, "!blue", false)) {
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i) && IsClientConnected(i)) {
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
			if (IsClientInGame(i) && IsClientConnected(i)) {
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
			if (IsFakeClient(i) && IsClientInGame(i) && IsClientConnected(i)) {
				int itarget = i;
				ent_action(client, itarget, action, value, true);
				num++;
			}
		}
	}
	else if (StrEqual(target, "!aim", false)) {
		float playerang[3]; GetClientEyeAngles(client, playerang);
		float playerorg[3]; GetClientEyePosition(client, playerorg);
		Handle trace = TR_TraceRayFilterEx(playerorg, playerang, MASK_SHOT, RayType_Infinite, filter_player, client);
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
		ReplyToCommand(client, "[SM] %i entities printed to console!", num);
	}
	iCounter = 0;
}

void ent_action(int client, int itarget, char[] action, char[] value, bool multiple) {
	iCounter++;
	if (itarget <= 0 || !IsValidEntity(itarget)) {
		if (iCounter == 1)
			ReplyToCommand(client, "[SM] Invalid target!");
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
					ReplyToCommand(client, "[SM] removeslot <value>");
			}
			else {
				int ivalue = StringToInt(value);
				TF2_RemoveWeaponSlot(itarget, ivalue);
			}
		}
		else {
			if (iCounter == 1)
				ReplyToCommand(client, "[SM] Target must be a player!");
		}
	}
	else if (StrEqual(action, "stun", false)) {
		char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
		if (StrEqual(ename, "player")) {
			if (StrEqual(value, "")) {
				if (iCounter == 1)
					ReplyToCommand(client, "[SM] stun <value>");
			}
			else {
				float fvalue = StringToFloat(value);
				TF2_StunPlayer(itarget, fvalue, 0.0, TF_STUNFLAGS_BIGBONK, 0);
			}
		}
		else {
			if (iCounter == 1)
				ReplyToCommand(client, "[SM] Target must be a player!");
		}
	}
	else if (StrEqual(action, "setname", false)) {
		if (StrEqual(value, "")) {
			if (iCounter == 1)
				ReplyToCommand(client, "[SM] setname <name>");
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
				ReplyToCommand(client, "[SM] addorg <x> <y> <z>");
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
				ReplyToCommand(client, "[SM] addang <pitch> <yaw> <roll>");
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
				ReplyToCommand(client, "[SM] setorg <x> <y> <z>");
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
				ReplyToCommand(client, "[SM] setang <pitch> <yaw> <roll>");
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
						ReplyToCommand(client, "[SM] copy <x> <y> <z> <pitch> <yaw> <roll>");
				}
				else {
					char model[512]; GetEntPropString(itarget, Prop_Data, "m_ModelName", model, sizeof(model));
					char tname[128]; GetEntPropString(itarget, Prop_Data, "m_iName", tname, sizeof(tname));
					float entang[3]; GetEntPropVector(itarget, Prop_Data, "m_angRotation", entang);
					float entorg[3]; GetEntPropVector(itarget, Prop_Data, "m_vecOrigin", entorg);
					int ent = CreateEntityByName("prop_dynamic");
					DispatchKeyValue(ent, "targetname", tname);
					DispatchKeyValue(ent, "model", model);
					DispatchKeyValue(ent, "solid", "6");
					DispatchKeyValue(ent, "physdamagescale", "0.0");
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
					int red, green, blue, alpha;
					GetEntityRenderColor(itarget, red, green, blue, alpha);
					SetEntityRenderColor(ent, red, green, blue, alpha);
					SetEntityRenderMode(ent, GetEntityRenderMode(itarget));
					SetEntityRenderFx(ent, GetEntityRenderFx(itarget));
				}
			}
			else {
				if (iCounter == 1)
					ReplyToCommand(client, "[SM] Target must be a prop!");
			}
		}
		else {
			if (iCounter == 1)
				ReplyToCommand(client, "[SM] Only one target allowed!");
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
				ReplyToCommand(client, "[SM] Target must be a player!");
		}
	}
	else if (StrEqual(action, "setheadscale", false)) {
		char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
		if (StrEqual(ename, "player")) {
			if (StrEqual(value, "")) {
				if (iCounter == 1)
					ReplyToCommand(client, "[SM] setheadscale <value>");
			}
			else {
				fHeadScale[itarget] = StringToFloat(value);
				SetEntPropFloat(itarget, Prop_Send, "m_flHeadScale", fHeadScale[itarget]);
			}
		}
		else {
			if (iCounter == 1)
				ReplyToCommand(client, "[SM] Target must be a player!");
		}
	}
	else if (StrEqual(action, "settorsoscale", false)) {
		char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
		if (StrEqual(ename, "player")) {
			if (StrEqual(value, "")) {
				if (iCounter == 1)
					ReplyToCommand(client, "[SM] settorsoscale <value>");
			}
			else {
				fTorsoScale[itarget] = StringToFloat(value);
				SetEntPropFloat(itarget, Prop_Send, "m_flTorsoScale", fTorsoScale[itarget]);
			}
		}
		else {
			if (iCounter == 1)
				ReplyToCommand(client, "[SM] Target must be a player!");
		}
	}
	else if (StrEqual(action, "sethandscale", false)) {
		char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
		if (StrEqual(ename, "player")) {
			if (StrEqual(value, "")) {
				if (iCounter == 1)
					ReplyToCommand(client, "[SM] sethandscale <value>");
			}
			else {
				fHandScale[itarget] = StringToFloat(value);
				SetEntPropFloat(itarget, Prop_Send, "m_flHandScale", fHandScale[itarget]);
			}
		}
		else {
			if (iCounter == 1)
				ReplyToCommand(client, "[SM] Target must be a player!");
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
			SetEntPropFloat(itarget, Prop_Send, "m_flHeadScale", 1.0);
			SetEntPropFloat(itarget, Prop_Send, "m_flTorsoScale", 1.0);
			SetEntPropFloat(itarget, Prop_Send, "m_flHandScale", 1.0);
		}
		else {
			if (iCounter == 1)
				ReplyToCommand(client, "[SM] Target must be a player!");
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
				ReplyToCommand(client, "[SM] Target must be a player!");
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
				ReplyToCommand(client, "[SM] Target must be a player!");
		}
	}
	else if (StrEqual(action, "teleport", false)) {
		if (StrEqual(value, "!picker", false)) {
			int newtarget = GetClientAimTarget(client, false);
			float entorg[3]; GetEntPropVector(newtarget, Prop_Data, "m_vecAbsOrigin", entorg);
			TeleportEntity(itarget, entorg, NULL_VECTOR, NULL_VECTOR);
		}
		else if (StrEqual(value, "!self", false)) {
			int newtarget = client;
			float entorg[3]; GetEntPropVector(newtarget, Prop_Data, "m_vecAbsOrigin", entorg);
			TeleportEntity(itarget, entorg, NULL_VECTOR, NULL_VECTOR);
		}
		else if (StrContains(value, "@", false) == 0) {
			char tvalue[256];
			strcopy(tvalue, 64, value[1]);
			int newtarget = FindTarget(client, tvalue, false, false);
			if (newtarget != -1) {
				float entorg[3]; GetEntPropVector(newtarget, Prop_Data, "m_vecAbsOrigin", entorg);
				TeleportEntity(itarget, entorg, NULL_VECTOR, NULL_VECTOR);
			}
		}
		else if (StrContains(value, "*", false) == 0) {
			char tvalue[256];
			strcopy(tvalue, 64, value[1]);
			int newtarget = StringToInt(tvalue);
			float entorg[3]; GetEntPropVector(newtarget, Prop_Data, "m_vecAbsOrigin", entorg);
			TeleportEntity(itarget, entorg, NULL_VECTOR, NULL_VECTOR);
		}
		else if (StrEqual(value, "")) {
			if (iCounter == 1)
				ReplyToCommand(client, "[SM] teleport <target>");
		}
		else {
			if (iCounter == 1)
				ReplyToCommand(client, "[SM] Target invalid!");
		}
	}
	else if (StrEqual(action, "addcond", false)) {
		char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
		if (StrEqual(ename, "player")) {
			if (StrEqual(value, "")) {
				if (iCounter == 1)
					ReplyToCommand(client, "[SM] addcond <condition>");
			}
			else {
				int condition = StringToInt(value);
				TF2_AddCondition(itarget, view_as<TFCond>(condition));
			}
			
		}
		else {
			if (iCounter == 1)
				ReplyToCommand(client, "[SM] Target must be a player!");
		}
	}
	else if (StrEqual(action, "removecond", false)) {
		char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
		if (StrEqual(ename, "player")) {
			if (StrEqual(value, "")) {
				if (iCounter == 1)
					ReplyToCommand(client, "[SM] removecond <condition>");
			}
			else {
				int condition = StringToInt(value);
				TF2_RemoveCondition(itarget, view_as<TFCond>(condition));
			}
		}
		else {
			if (iCounter == 1)
				ReplyToCommand(client, "[SM] Target must be a player!");
		}
	}
	else if (StrEqual(action, "pitch", false)) {
		char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
		if (StrEqual(ename, "player")) {
			if (StrEqual(value, "")) {
				iVoicePitch[itarget] = 100;
				if (iCounter == 1)
					ReplyToCommand(client, "[SM] your pitch has been reset");
			}
			else {
				iVoicePitch[itarget] = StringToInt(value);
			}
			
		}
		else {
			if (iCounter == 1)
				ReplyToCommand(client, "[SM] Target must be a player!");
		}
	}
	else if (StrEqual(action, "color", false)) {
		char num[32][6]; ExplodeString(value, "+", num, 6, sizeof(num));
		int red = StringToInt(num[0]);
		int green = StringToInt(num[1]);
		int blue = StringToInt(num[2]);
		int alpha = StringToInt(num[3]);
		if (StrEqual(num[0], "")) { red = 255; }
		if (StrEqual(num[1], "")) { green = 255; }
		if (StrEqual(num[2], "")) { blue = 255; }
		if (StrEqual(num[3], "")) { alpha = 255; }
		SetEntityRenderColor(itarget, red, green, blue, alpha);
		SetEntityRenderMode(itarget, RENDER_TRANSALPHAADD);
	}
	else if (StrEqual(action, "setclip", false)) {
		char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
		if (StrEqual(ename, "player")) {
			if (StrEqual(value, "")) {
				if (iCounter == 1)
					ReplyToCommand(client, "[SM] setclip <value>");
			}
			else {
				int weapon = GetEntPropEnt(itarget, Prop_Data, "m_hActiveWeapon");
				SetEntProp(weapon, Prop_Data, "m_iClip1", StringToInt(value));
			}
		}
		else {
			if (iCounter == 1)
				ReplyToCommand(client, "[SM] Target must be a player!");
		}
	}
	else if (StrEqual(action, "noclip", false)) {
		char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
		if (StrEqual(ename, "player")) {
			if (StrEqual(value, "")) {
				MoveType movetype = GetEntityMoveType(itarget);
				if (movetype != MOVETYPE_NOCLIP) {
					SetEntityMoveType(itarget, MOVETYPE_NOCLIP);
				}
				else {
					SetEntityMoveType(itarget, MOVETYPE_WALK);
				}
			}
			else {
				if (StrEqual(value, "on")) {
					SetEntityMoveType(itarget, MOVETYPE_NOCLIP);
				}
				else if (StrEqual(value, "off")) {
					SetEntityMoveType(itarget, MOVETYPE_WALK);
				}
				else {
					if (iCounter == 1)
						ReplyToCommand(client, "[SM] noclip <on/off>");
				}
			}
		}
		else {
			if (iCounter == 1)
				ReplyToCommand(client, "[SM] Target must be a player!");
		}
	}
	else if (StrEqual(action, "saveprops", false)) {
		if (multiple == false) {
			char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
			if (StrEqual(ename, "player")) {
				if (StrEqual(value, "")) {
					ReplyToCommand(client, "[SM] saveprops <filename>");
				}
				else {
					CreateFile(client, itarget, value);
				}
			}
			else {
				ReplyToCommand(client, "[SM] Target must be a player!");
			}
		}
		else {
			ReplyToCommand(client, "[SM] Only one target allowed!");
		}
	}
	else if (StrEqual(action, "loadprops", false)) {
		if (multiple == false) {
			char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
			if (StrEqual(ename, "player")) {
				if (StrEqual(value, "")) {
					ReplyToCommand(client, "[SM] loadprops <filename>");
				}
				else {
					ReadFromFile(client, itarget, value);
				}
			}
			else {
				ReplyToCommand(client, "[SM] Target must be a player!");
			}
		}
		else {
			ReplyToCommand(client, "[SM] Only one target allowed!");
		}
	}
	else if (StrEqual(action, "deletefile", false)) {
		if (multiple == false) {
			if (StrEqual(value, "")) {
				ReplyToCommand(client, "[SM] deletefile <filename>");
			}
			else {
				char buffer[256]; FormatEx(buffer, sizeof(buffer), "%s/%s.cfg", PROPSAVE_DIR, value);
				char filepath[256]; BuildPath(Path_SM, filepath, sizeof(filepath), buffer);
				if (FileExists(filepath)) {
					DeleteFile(filepath);
					ReplyToCommand(client, "[SM] Deleted %s!", buffer);
				}
				else {
					ReplyToCommand(client, "[SM] File %s doesn't exist!", buffer);
				}
			}
		}
	}
	else if (StrContains(action, "m_", false) == 0) {
		if (multiple == false) {
			PropFieldType type;
			int info = FindDataMapInfo(itarget, action, type);
			if (info != -1) {
				if (StrEqual(value, "")) {
					if (type == PropField_Integer) {
						int data = GetEntProp(itarget, Prop_Data, action);
						ReplyToCommand(client, "\x03%i", data);
					}
					else if (type == PropField_Float) {
						float data = GetEntPropFloat(itarget, Prop_Data, action);
						ReplyToCommand(client, "\x03%.2f", data);
					}
					else if (type == PropField_String || type == PropField_String_T) {
						char buffer[256];
						GetEntPropString(itarget, Prop_Data, action, buffer, sizeof(buffer));
						ReplyToCommand(client, "\x03%s", buffer);
					}
					else if (type == PropField_Vector) {
						float vector[3];
						GetEntPropVector(itarget, Prop_Data, action, vector);
						ReplyToCommand(client, "\x03%.0f %.0f %.0f", vector[0], vector[1], vector[2]);
					}
					else if (type == PropField_Entity) {
						int data = GetEntPropEnt(itarget, Prop_Data, action);
						ReplyToCommand(client, "\x03%i", data);
					}
					else {
						ReplyToCommand(client, "[SM] Type not supported!");
					}
				}
				else {
					if (type == PropField_Integer) {
						SetEntProp(itarget, Prop_Data, action, StringToInt(value));
						ReplyToCommand(client, "[SM] Set %s to %s", action, value);
					}
					else if (type == PropField_Float) {
						SetEntPropFloat(itarget, Prop_Data, action, StringToFloat(value));
						ReplyToCommand(client, "[SM] Set %s to %s", action, value);
					}
					else if (type == PropField_String || type == PropField_String_T) {
						SetEntPropString(itarget, Prop_Data, action, value);
						ReplyToCommand(client, "[SM] Set %s to %s", action, value);
					}
					else if (type == PropField_Vector) {
						float vector[3]; char num[64][6];
						ExplodeString(value, " ", num, 3, sizeof(num), false);
						vector[0] = StringToFloat(num[0]);
						vector[1] = StringToFloat(num[1]);
						vector[2] = StringToFloat(num[2]);
						SetEntPropVector(itarget, Prop_Data, action, vector);
						ReplyToCommand(client, "[SM] Set %s to %.0f %.0f %.0f", action, vector[0], vector[1], vector[2]);
					}
					else if (type == PropField_Entity) {
						if (IsValidEntity(StringToInt(value))) {
							SetEntPropEnt(itarget, Prop_Data, action, StringToInt(value));
							ReplyToCommand(client, "[SM] Set %s to %s", action, value);
						}
						else {
							ReplyToCommand(client, "[SM] Invalid entity!", action, value);
						}
						
					}
					else {
						ReplyToCommand(client, "[SM] Type not supported!");
					}
				}
			}
			else {
				ReplyToCommand(client, "[SM] %s not a datamap for target!", action);
			}
		}
		else {
			if (iCounter == 1)
				ReplyToCommand(client, "[SM] Only one target allowed!");
		}
	}
	else if (StrContains(action, "tf_weapon", false) == 0) {
		char ename[256]; GetEntityClassname(itarget, ename, sizeof(ename));
		if (StrEqual(ename, "player")) {
			if (StrEqual(value, "")) {
				if (iCounter == 1)
					ReplyToCommand(client, "[SM] tf_weapon_* <index>");
			}
			else {
				if (iWeapon[itarget] != 0) {
					if (IsValidEdict(iWeapon[itarget])) {
						RemoveEdict(iWeapon[itarget]);
					}
					iWeapon[itarget] = 0;
				}
				int ent = CreateEntityByName(action);
				if (ent != -1 && IsValidEntity(ent)) {
					SetEntProp(ent, Prop_Send, "m_bDisguiseWeapon", 1);
					SetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex", StringToInt(value));
					SetEntProp(ent, Prop_Send, "m_iEntityQuality", 6);
					SetEntProp(ent, Prop_Send, "m_iEntityLevel", 10);
					SetEntPropEnt(ent, Prop_Send, "m_hOwner", itarget);
					SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", itarget);
					SetEntPropEnt(ent, Prop_Send, "moveparent", itarget);
					SetEntProp(ent, Prop_Send, "m_bInitialized", 1);
					DispatchSpawn(ent);
					EquipPlayerWeapon(itarget, ent);
					SetEntPropEnt(itarget, Prop_Data, "m_hActiveWeapon", ent);
					iWeapon[itarget] = ent;
				}
				else {
					if (iCounter == 1)
						ReplyToCommand(client, "[SM] Invalid weapon!");
				}
			}
		}
		else {
			if (iCounter == 1)
				ReplyToCommand(client, "[SM] Target must be a player!");
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
		ReplyToCommand(client, "StartPos: %.0f %.0f %.0f", startpos[0], startpos[1], startpos[2]);
		ReplyToCommand(client, "StartAng: %.0f %.0f %.0f", startang[0], startang[1], startang[2]);
		ReplyToCommand(client, "EndPos: %.0f %.0f %.0f", endpos[0], endpos[1], endpos[2]);
		ReplyToCommand(client, "Hit: %i", entity);
	}
	else if (StrEqual(action, "prop", false)) {
		if (StrEqual(value, "")) {
			ReplyToCommand(client, "[SM] prop <modelpath>");
		}
		else {
			char auth[256]; GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));
			char targetname[256]; FormatEx(targetname, sizeof(targetname), "entprop_%s", auth);
			PrecacheModel(value);
			int prop = CreateEntityByName("prop_dynamic");
			DispatchKeyValue(prop, "physdamagescale", "0.0");
			DispatchKeyValue(prop, "Solid", "6");
			DispatchKeyValue(prop, "model", value);
			DispatchKeyValue(prop, "targetname", targetname);
			DispatchSpawn(prop);
			ActivateEntity(prop);
			float propang[3];
			propang[1] = 180 + startang[1];
			TeleportEntity(prop, endpos, propang, NULL_VECTOR);
			SetEntityRenderMode(prop, RENDER_TRANSALPHAADD);
		}
	}
	else if (StrEqual(action, "create", false)) {
		if (StrEqual(value, "")) {
			ReplyToCommand(client, "[SM] create <entity>");
		}
		else {
			if (StrEqual(value, "0") || StrEqual(value, "-1")) {
				ReplyToCommand(client, "[SM] Cannot create that entity!");
			}
			else if (iEntity[client] == 0) {
				iEntity[client] = CreateEntityByName(value);
				if (IsValidEntity(iEntity[client])) {
					ReplyToCommand(client, "[SM] Entity %i > %s created.", iEntity[client], value);
				}
				else {
					ReplyToCommand(client, "[SM] Invalid entity!");
					iEntity[client] = 0;
				}
			}
			else {
				ReplyToCommand(client, "[SM] Please delete or spawn your previous entity first. (%i)", iEntity[client]);
			}
		}
	}
	else if (StrEqual(action, "delete", false)) {
		if (iEntity[client] != 0) {
			char ename[128]; GetEntityClassname(iEntity[client], ename, sizeof(ename));
			ReplyToCommand(client, "[SM] Entity %i > %s deleted", iEntity[client], ename);
			RemoveEdict(iEntity[client]);
			iEntity[client] = 0;
		}
		else {
			ReplyToCommand(client, "[SM] No entity created yet.", iEntity[client]);
		}
	}
	else if (StrEqual(action, "value", false)) {
		if (StrEqual(value, "")) {
			ReplyToCommand(client, "[SM] value <key> <value>");
		}
		else {
			if (iEntity[client] != 0) {
				char ename[128]; GetEntityClassname(iEntity[client], ename, sizeof(ename));
				char part[256][6]; ExplodeString(value, " ", part, 2, sizeof(part), true);
				if (StrEqual(part[0], "model", false) || StrEqual(part[0], "parent", false)) {
					PrecacheModel(part[1]);
				}
				DispatchKeyValue(iEntity[client], part[0], part[1]);
				ReplyToCommand(client, "[SM] Key:\"%s\" Value:\"%s\"", part[0], part[1]);
				ReplyToCommand(client, "added to entity %i > %s", iEntity[client], ename);
			}
			else {
				ReplyToCommand(client, "[SM] No entity created yet.", iEntity[client]);
			}
		}
	}
	else if (StrEqual(action, "spawn", false)) {
		if (iEntity[client] != 0) {
			char ename[128]; GetEntityClassname(iEntity[client], ename, sizeof(ename));
			ReplyToCommand(client, "[SM] Entity %i > %s spawned.", iEntity[client], ename);
			DispatchSpawn(iEntity[client]);
			ActivateEntity(iEntity[client]);
			float propang[3];
			propang[1] = 180 + startang[1];
			TeleportEntity(iEntity[client], endpos, propang, NULL_VECTOR);
			iEntity[client] = 0;
		}
		else {
			ReplyToCommand(client, "[SM] No entity created yet.", iEntity[client]);
		}
	}
	else if (StrEqual(action, "copy", false)) {
		char ename[256]; GetEntityClassname(entity, ename, sizeof(ename));
		if (StrEqual(ename, "prop_dynamic")) {
			iCopy[client] = entity;
			ReplyToCommand(client, "[SM] %i > %s copied.", iCopy[client], ename);
		}
		else {
			ReplyToCommand(client, "[SM] Target must be a prop!");
		}
	}
	else if (StrEqual(action, "paste", false)) {
		if (iCopy[client] != 0) {
			char model[512]; GetEntPropString(iCopy[client], Prop_Data, "m_ModelName", model, sizeof(model));
			char tname[128]; GetEntPropString(iCopy[client], Prop_Data, "m_iName", tname, sizeof(tname));
			float entang[3]; GetEntPropVector(iCopy[client], Prop_Data, "m_angRotation", entang);
			float entorg[3]; GetEntPropVector(iCopy[client], Prop_Data, "m_vecOrigin", entorg);
			PrecacheModel(model);
			int prop = CreateEntityByName("prop_dynamic");
			DispatchKeyValue(prop, "targetname", tname);
			DispatchKeyValue(prop, "physdamagescale", "0.0");
			DispatchKeyValue(prop, "solid", "6");
			DispatchKeyValue(prop, "model", model);
			DispatchSpawn(prop);
			ActivateEntity(prop);
			TeleportEntity(prop, endpos, entang, NULL_VECTOR);
			int red, green, blue, alpha;
			GetEntityRenderColor(iCopy[client], red, green, blue, alpha);
			SetEntityRenderColor(prop, red, green, blue, alpha);
			SetEntityRenderMode(prop, GetEntityRenderMode(iCopy[client]));
			SetEntityRenderFx(prop, GetEntityRenderFx(iCopy[client]));
		}
		else {
			ReplyToCommand(client, "[SM] No entity copied yet!");
		}
	}
	else if (StrEqual(action, "shift", false)) {
		if (bShift[client] == false) {
			if (IsValidEntity(entity) && entity > 0) {
				bShift[client] = true;
				iShift[client] = entity;
				iShiftMode[client] = StringToInt(value);
				ReplyToCommand(client, "[SM] Started shifting %i", iShift[client]);
			}
			else {
				ReplyToCommand(client, "[SM] Invalid entity!");
			}
		}
		else {
			bShift[client] = false;
			iShift[client] = 0;
			iShiftMode[client] = 0;
			ReplyToCommand(client, "[SM] Stopped shifting.");
		}
	}
	else if (StrEqual(action, "move", false)) {
		if (bMove[client] == false) {
			iMove[client] = GetAimEntity(client);
			if (iMove[client] > 0) {
				CreateTempEnts(client, iMove[client]);
				bMove[client] = true;
			}
			else {
				ReplyToCommand(client, "[SM] Invalid entity!");
			}
		}
		else {
			DeleteTempEnts(client);
			bMove[client] = false;
		}
	}
}

int GetAimEntity(int client) {
	float org[3]; GetClientEyePosition(client, org);
	float ang[3]; GetClientEyeAngles(client, ang);
	Handle trace = TR_TraceRayFilterEx(org, ang, MASK_SHOT, RayType_Infinite, filter_player, client);
	int ent = TR_GetEntityIndex(trace);
	CloseHandle(trace);
	return ent;
}

int CreatePropRelative(int entity, float offset[3], char[] name) {
	float org[3]; GetEntPropVector(entity, Prop_Data, "m_vecOrigin", org);
	float ang[3]; GetEntPropVector(entity, Prop_Data, "m_angRotation", ang);
	char model[256]; GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));
	PrecacheModel(model);
	org[0] += offset[0];
	org[1] += offset[1];
	org[2] += offset[2];
	int prop = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(prop, "model", model);
	DispatchKeyValue(prop, "targetname", name);
	DispatchKeyValue(prop, "solid", "4");
	DispatchSpawn(prop);
	TeleportEntity(prop, org, ang, NULL_VECTOR);
	SetEntityRenderColor(prop, 255, 255, 255, 0);
	SetEntityRenderMode(prop, RENDER_TRANSALPHAADD);
	return prop;
}

void CreateTempEnts(int client, int entity) {
	float vector1[3]; GetEntPropVector(entity, Prop_Data, "m_vecMins", vector1);
	float vector2[3]; GetEntPropVector(entity, Prop_Data, "m_vecMaxs", vector2);
	float vector3[3];
	
	if (vector1[0] < 0) { vector1[0] /= (-1); }
	if (vector1[1] < 0) { vector1[1] /= (-1); }
	if (vector1[2] < 0) { vector1[2] /= (-1); }
	
	char auth[256]; GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));
	char buffer[128]; FormatEx(buffer, sizeof(buffer), "enttemp_%i", auth);
	vector3[0] = vector1[0] + vector2[0];
	CreatePropRelative(entity, vector3, buffer);
	vector3[0] = (vector1[0] + vector2[0]) / (-1);
	CreatePropRelative(entity, vector3, buffer);
	vector3[0] = 0.0;
	vector3[1] = vector1[1] + vector2[1];
	CreatePropRelative(entity, vector3, buffer);
	vector3[1] = (vector1[1] + vector2[1]) / (-1);
	CreatePropRelative(entity, vector3, buffer);
	vector3[1] = 0.0;
	vector3[2] = vector1[2] + vector2[2];
	CreatePropRelative(entity, vector3, buffer);
	vector3[2] = (vector1[2] + vector2[2]) / (-1);
	CreatePropRelative(entity, vector3, buffer);
}

void DeleteTempEnts(int client) {
	for (int e = 1; e <= GetMaxEntities(); e++) {
		if (IsValidEntity(e)) {
			char tname[128]; GetEntPropString(e, Prop_Data, "m_iName", tname, sizeof(tname));
			char auth[256]; GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));
			char buffer[128]; FormatEx(buffer, sizeof(buffer), "enttemp_%s", auth);
			if (StrContains(tname, buffer) == 0) {
				if (e != -1) {
					RemoveEdict(e);
				}
			}
		}
	}
}

void OnButtonPress(int client, int button) {
	if (button == IN_SPEED && bMove[client] == true) {
		if (iMoveTarget[client] > 0 && IsValidEntity(iMoveTarget[client])) {
			float org[3]; GetEntPropVector(iMoveTarget[client], Prop_Data, "m_vecOrigin", org);
			TeleportEntity(iMove[client], org, NULL_VECTOR, NULL_VECTOR);
			DeleteTempEnts(client);
			CreateTempEnts(client, iMove[client]);
		}
	}
}

void CreateFile(int client, int target, char[] filename) {
	char dir[256]; BuildPath(Path_SM, dir, sizeof(dir), PROPSAVE_DIR);
	if (!DirExists(dir)) {
		CreateDirectory(dir, 0);
	}
	char auth[256]; GetClientAuthId(target, AuthId_SteamID64, auth, sizeof(auth));
	char buffer[256]; FormatEx(buffer, sizeof(buffer), "%s/%s_%s.cfg", PROPSAVE_DIR, filename, auth);
	char filepath[256]; BuildPath(Path_SM, filepath, sizeof(filepath), buffer);
	WriteToFile(client, target, filepath, buffer);
}

void WriteToFile(int client, int target, char[] path, char[] filename) {
	int check;
	for (int e = 1; e <= GetMaxEntities(); e++) {
		if (IsValidEntity(e)) {
			char cname[128]; GetEntityClassname(e, cname, sizeof(cname));
			char tname[128]; GetEntPropString(e, Prop_Data, "m_iName", tname, sizeof(tname));
			char auth[256]; GetClientAuthId(target, AuthId_SteamID64, auth, sizeof(auth));
			char buffer[128]; FormatEx(buffer, sizeof(buffer), "entprop_%s", auth);
			if (StrContains(tname, buffer) == 0) {
				if (e != -1 && StrEqual(cname, "prop_dynamic")) {
					check++;
				}
			}
		}
	}
	int num;
	if (check > 0) {
		Handle filehandle = OpenFile(path, "w");
		for (int e = 1; e <= GetMaxEntities(); e++) {
			if (IsValidEntity(e)) {
				char cname[128]; GetEntityClassname(e, cname, sizeof(cname));
				char tname[128]; GetEntPropString(e, Prop_Data, "m_iName", tname, sizeof(tname));
				char auth[256]; GetClientAuthId(target, AuthId_SteamID64, auth, sizeof(auth));
				char buffer[128]; FormatEx(buffer, sizeof(buffer), "entprop_%s", auth);
				if (StrContains(tname, buffer) == 0) {
					if (e != -1 && StrEqual(cname, "prop_dynamic")) {
						char model[512]; GetEntPropString(e, Prop_Data, "m_ModelName", model, sizeof(model));
						int parent = GetEntPropEnt(e, Prop_Data, "m_hParent");
						int solid = GetEntProp(e, Prop_Data, "m_nSolidType");
						float scale = GetEntPropFloat(e, Prop_Data, "m_flModelScale");
						float entorg[3]; GetEntPropVector(e, Prop_Data, "m_vecOrigin", entorg);
						float entang[3]; GetEntPropVector(e, Prop_Data, "m_angRotation", entang);
						int red, green, blue, alpha;
						GetEntityRenderColor(e, red, green, blue, alpha);
						char mapname[256]; GetCurrentMap(mapname, sizeof(mapname));
						char string[512];
						Format(string, sizeof(string), "%s|%s|%i|%i|%f|%f|%f|%f|%f|%f|%f|%i|%i|%i|%i", 
							mapname, model, parent, solid, scale, entorg[0], entorg[1], entorg[2], entang[0], entang[1], entang[2], red, green, blue, alpha);
						WriteFileLine(filehandle, "%s", string);
						num++;
					}
				}
			}
		}
		ReplyToCommand(client, "[SM] %i props saved into %s", num, filename);
		CloseHandle(filehandle);
	}
	else {
		ReplyToCommand(client, "[SM] No props available for saving.");
	}
}

void ReadFromFile(int client, int target, char[] filename) {
	char auth[256]; GetClientAuthId(target, AuthId_SteamID64, auth, sizeof(auth));
	char buffer[256]; FormatEx(buffer, sizeof(buffer), "%s/%s_%s.cfg", PROPSAVE_DIR, filename, auth);
	char filepath[256]; BuildPath(Path_SM, filepath, sizeof(filepath), buffer);
	if (!FileExists(filepath)) {
		ReplyToCommand(client, "[SM] File %s doesn't exist!", buffer);
	}
	else {
		Handle filehandle = OpenFile(filepath, "r");
		char line[512];
		int num;
		char realmap[256];
		while (!IsEndOfFile(filehandle) && ReadFileLine(filehandle, line, sizeof(line))) {
			char part[512][128];
			ExplodeString(line, "|", part, 15, sizeof(part));
			char mapname[256]; GetCurrentMap(mapname, sizeof(mapname));
			if (StrEqual(part[0], mapname)) {
				RecoverProp(target, part[1], StringToInt(part[2]), part[3], part[4], StringToFloat(part[5]), StringToFloat(part[6]), StringToFloat(part[7]), StringToFloat(part[8]), StringToFloat(part[9]), StringToFloat(part[10]), StringToInt(part[11]), StringToInt(part[12]), StringToInt(part[13]), StringToInt(part[14]));
			}
			else {
				strcopy(realmap, sizeof(realmap), part[0]);
			}
			num++;
		}
		if (num == 0) {
			ReplyToCommand(client, "[SM] File %s is empty", buffer);
		}
		else if (!StrEqual(realmap, "")) {
			ReplyToCommand(client, "[SM] Wrong map! These were saved in %s.", realmap);
		}
		else {
			ReplyToCommand(client, "[SM] Spawned %i saved props from %s", num, buffer);
		}
		CloseHandle(filehandle);
	}
}

void RecoverProp(int client, char[] model, int parent, char[] solid, char[] scale, float entorg0, float entorg1, float entorg2, float entang0, float entang1, float entang2, int red, int green, int blue, int alpha) {
	char auth[256]; GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));
	char buffer[128]; FormatEx(buffer, sizeof(buffer), "entprop_%s", auth);
	PrecacheModel(model);
	int prop = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(prop, "model", model);
	DispatchKeyValue(prop, "targetname", buffer);
	DispatchKeyValue(prop, "solid", solid);
	DispatchKeyValue(prop, "modelscale", scale);
	DispatchSpawn(prop);
	SetEntPropEnt(prop, Prop_Data, "m_hParent", parent);
	float entorg[3]; entorg[0] = entorg0; entorg[1] = entorg1; entorg[2] = entorg2;
	float entang[3]; entang[0] = entang0; entang[1] = entang1; entang[2] = entang2;
	TeleportEntity(prop, entorg, entang, NULL_VECTOR);
	SetEntityRenderColor(prop, red, green, blue, alpha);
	SetEntityRenderMode(prop, RENDER_TRANSALPHAADD);
} 