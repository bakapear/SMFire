#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <topmenus>
#include <clientprefs>
#include <adminmenu>

#pragma newdecls required
#define COMMANDS_PER_PAGE	10

Menu g_ConfigMenu = null;
SMCParser config_parser;
int g_BanTarget[MAXPLAYERS+1];
int g_BanTargetUserId[MAXPLAYERS+1];
int g_BanTime[MAXPLAYERS+1];

bool g_IsWaitingForChatReason[MAXPLAYERS+1];
KeyValues g_hKvBanReasons;
char g_BanReasonsPath[PLATFORM_MAX_PATH];

public Plugin myinfo =  {
	name = "Basic", 
	author = "pear", 
	description = "", 
	version = "", 
	url = ""
}

/* Forwards */
Handle hOnAdminMenuReady = null;
Handle hOnAdminMenuCreated = null;

/* Menus */
TopMenu hAdminMenu;

/* Top menu objects */
TopMenuObject obj_playercmds = INVALID_TOPMENUOBJECT;
TopMenuObject obj_servercmds = INVALID_TOPMENUOBJECT;
TopMenuObject obj_votingcmds = INVALID_TOPMENUOBJECT;

#define NAME_LENGTH 64
#define CMD_LENGTH 255

#define ARRAY_STRING_LENGTH 32

enum GroupCommands
{
	ArrayList:groupListName,
	ArrayList:groupListCommand	
};

int g_groupList[GroupCommands];
int g_groupCount;

SMCParser g_configParser;

enum Places
{
	Place_Category,
	Place_Item,
	Place_ReplaceNum
};

char g_command[MAXPLAYERS+1][CMD_LENGTH];
int g_currentPlace[MAXPLAYERS+1][Places];

/**
 * What to put in the 'info' menu field (for PlayerList and Player_Team menus only)
 */
enum PlayerMethod
{		
	ClientId,				/** Client id number ( 1 - Maxplayers) */
	UserId,					/** Client userid */
	Name,					/** Client Name */
	SteamId,				/** Client Steamid */
	IpAddress,				/** Client's Ip Address */
	UserId2					/** Userid (not prefixed with #) */
};

enum ExecuteType
{
	Execute_Player,
	Execute_Server
}

enum SubMenu_Type
{
	SubMenu_Group,
	SubMenu_GroupPlayer,
	SubMenu_Player,
	SubMenu_MapCycle,
	SubMenu_List,
	SubMenu_OnOff	
}

enum Item
{
	String:Item_cmd[256],
	ExecuteType:Item_execute,
	ArrayList:Item_submenus
}

enum Submenu
{
	SubMenu_Type:Submenu_type,
	String:Submenu_title[32],
	PlayerMethod:Submenu_method,
	Submenu_listcount,
	DataPack:Submenu_listdata
}

public Action HelpCmd(int client, int args)
{
	char arg[64], CmdName[20];
	int PageNum = 1;
	bool DoSearch;

	GetCmdArg(0, CmdName, sizeof(CmdName));

	if (GetCmdArgs() >= 1)
	{
		GetCmdArg(1, arg, sizeof(arg));
		StringToIntEx(arg, PageNum);
		PageNum = (PageNum <= 0) ? 1 : PageNum;
	}

	DoSearch = (strcmp("sm_help", CmdName) == 0) ? false : true;

	if (GetCmdReplySource() == SM_REPLY_TO_CHAT)
	{
		ReplyToCommand(client, "[SM] %t", "See console for output");
	}

	char name[64];
	char Desc[255];
	char NoDesc[128];
	int Flags;
	Handle CmdIter = GetCommandIterator();

	FormatEx(NoDesc, sizeof(NoDesc), "%T", "No description available", client);

	if (DoSearch)
	{
		int i = 1;
		while (ReadCommandIterator(CmdIter, name, sizeof(name), Flags, Desc, sizeof(Desc)))
		{
			if ((StrContains(name, arg, false) != -1) && CheckCommandAccess(client, name, Flags))
			{
				PrintToConsole(client, "[%03d] %s - %s", i++, name, (Desc[0] == '\0') ? NoDesc : Desc);
			}
		}

		if (i == 1)
		{
			PrintToConsole(client, "%t", "No matching results found");
		}
	} else {
		PrintToConsole(client, "%t", "SM help commands");		

		/* Skip the first N commands if we need to */
		if (PageNum > 1)
		{
			int i;
			int EndCmd = (PageNum-1) * COMMANDS_PER_PAGE - 1;
			for (i=0; ReadCommandIterator(CmdIter, name, sizeof(name), Flags, Desc, sizeof(Desc)) && i<EndCmd; )
			{
				if (CheckCommandAccess(client, name, Flags))
				{
					i++;
				}
			}

			if (i == 0)
			{
				PrintToConsole(client, "%t", "No commands available");
				delete CmdIter;
				return Plugin_Handled;
			}
		}

		/* Start printing the commands to the client */
		int i;
		int StartCmd = (PageNum-1) * COMMANDS_PER_PAGE;
		for (i=0; ReadCommandIterator(CmdIter, name, sizeof(name), Flags, Desc, sizeof(Desc)) && i<COMMANDS_PER_PAGE; )
		{
			if (CheckCommandAccess(client, name, Flags))
			{
				i++;
				PrintToConsole(client, "[%03d] %s - %s", i+StartCmd, name, (Desc[0] == '\0') ? NoDesc : Desc);
			}
		}

		if (i == 0)
		{
			PrintToConsole(client, "%t", "No commands available");
		} else {
			PrintToConsole(client, "%t", "Entries n - m in page k", StartCmd+1, i+StartCmd, PageNum);
		}

		/* Test if there are more commands available */
		if (ReadCommandIterator(CmdIter, name, sizeof(name), Flags, Desc, sizeof(Desc)) && CheckCommandAccess(client, name, Flags))
		{
			PrintToConsole(client, "%t", "Type sm_help to see more", PageNum+1);
		}
	}

	delete CmdIter;

	return Plugin_Handled;
}

ArrayList g_DataArray;

void BuildDynamicMenu()
{
	int itemInput[Item];
	g_DataArray = new ArrayList(sizeof(itemInput));
	
	char executeBuffer[32];
	
	KeyValues kvMenu = new KeyValues("Commands");
	kvMenu.SetEscapeSequences(true); 
	
	char file[256];
	
	/* As a compatibility shim, we use the old file if it exists. */
	BuildPath(Path_SM, file, 255, "configs/dynamicmenu/menu.ini");
	if (FileExists(file))
	{
		LogError("Warning! configs/dynamicmenu/menu.ini is now configs/adminmenu_custom.txt.");
		LogError("Read the 1.0.2 release notes, as the dynamicmenu folder has been removed.");
	}
	else
	{
		BuildPath(Path_SM, file, 255, "configs/adminmenu_custom.txt");
	}
	
	FileToKeyValues(kvMenu, file);
	
	char name[NAME_LENGTH];
	char buffer[NAME_LENGTH];
		
	if (!kvMenu.GotoFirstSubKey())
		return;
	
	char admin[30];
	
	TopMenuObject categoryId;
	
	do
	{		
		kvMenu.GetSectionName(buffer, sizeof(buffer));

		kvMenu.GetString("admin", admin, sizeof(admin),"sm_admin");
				
		if ((categoryId = hAdminMenu.FindCategory(buffer)) == INVALID_TOPMENUOBJECT)
		{
			categoryId = hAdminMenu.AddCategory(buffer,
							DynamicMenuCategoryHandler,
							admin,
							ADMFLAG_GENERIC,
							name);

		}

		char category_name[NAME_LENGTH];
		strcopy(category_name, sizeof(category_name), buffer);
		
		if (!kvMenu.GotoFirstSubKey())
		{
			return;
		}
		
		do
		{		
			kvMenu.GetSectionName(buffer, sizeof(buffer));
			
			kvMenu.GetString("admin", admin, sizeof(admin),"");
			
			if (admin[0] == '\0')
			{
				//No 'admin' keyvalue was found
				//Use the first argument of the 'cmd' string instead
				
				char temp[64];
				kvMenu.GetString("cmd", temp, sizeof(temp),"");
				
				BreakString(temp, admin, sizeof(admin));
			}
			
			
			kvMenu.GetString("cmd", itemInput[Item_cmd], sizeof(itemInput[Item_cmd]));	
			kvMenu.GetString("execute", executeBuffer, sizeof(executeBuffer));
			
			if (StrEqual(executeBuffer, "server"))
			{
				itemInput[Item_execute] = Execute_Server;
			}
			else //assume player type execute
			{
				itemInput[Item_execute] = Execute_Player;
			}
  							
  			/* iterate all submenus and load data into itemInput[Item_submenus] (ArrayList) */
  			
  			int count = 1;
  			char countBuffer[10] = "1";
  			
  			char inputBuffer[48];
  			
  			while (kvMenu.JumpToKey(countBuffer))
  			{
	  			int submenuInput[Submenu];
	  			
	  			if (count == 1)
	  			{
		  			itemInput[Item_submenus] = new ArrayList(sizeof(submenuInput));	
	  			}
	  			
	  			kvMenu.GetString("type", inputBuffer, sizeof(inputBuffer));
	  			
	  			if (strncmp(inputBuffer,"group",5)==0)
				{	
					if (StrContains(inputBuffer, "player") != -1)
					{			
						submenuInput[Submenu_type] = SubMenu_GroupPlayer;
					}
					else
					{
						submenuInput[Submenu_type] = SubMenu_Group;
					}
				}			
				else if (StrEqual(inputBuffer,"mapcycle"))
				{
					submenuInput[Submenu_type] = SubMenu_MapCycle;
					
					kvMenu.GetString("path", inputBuffer, sizeof(inputBuffer),"mapcycle.txt");
					
					submenuInput[Submenu_listdata] = new DataPack();
					submenuInput[Submenu_listdata].WriteString(inputBuffer);
					submenuInput[Submenu_listdata].Reset();
				}
				else if (StrContains(inputBuffer, "player") != -1)
				{			
					submenuInput[Submenu_type] = SubMenu_Player;
				}
				else if (StrEqual(inputBuffer,"onoff"))
				{
					submenuInput[Submenu_type] = SubMenu_OnOff;
				}		
				else //assume 'list' type
				{
					submenuInput[Submenu_type] = SubMenu_List;
					
					submenuInput[Submenu_listdata] = new DataPack();
					
					char temp[6];
					char value[64];
					char text[64];
					char subadm[30];	//  same as "admin", cf. line 110
					int i=1;
					bool more = true;
					
					int listcount = 0;
								
					do
					{
						Format(temp,3,"%i",i);
						kvMenu.GetString(temp, value, sizeof(value), "");
						
						Format(temp,5,"%i.",i);
						kvMenu.GetString(temp, text, sizeof(text), value);
						
						Format(temp,5,"%i*",i);
						kvMenu.GetString(temp, subadm, sizeof(subadm),"");	
						
						if (value[0]=='\0')
						{
							more = false;
						}
						else
						{
							listcount++;
							submenuInput[Submenu_listdata].WriteString(value);
							submenuInput[Submenu_listdata].WriteString(text);
							submenuInput[Submenu_listdata].WriteString(subadm);
						}
						
						i++;
										
					} while (more);
					
					submenuInput[Submenu_listdata].Reset();
					submenuInput[Submenu_listcount] = listcount;
				}
				
				if ((submenuInput[Submenu_type] == SubMenu_Player) || (submenuInput[Submenu_type] == SubMenu_GroupPlayer))
				{
					kvMenu.GetString("method", inputBuffer, sizeof(inputBuffer));
					
					if (StrEqual(inputBuffer, "clientid"))
					{
						submenuInput[Submenu_method] = ClientId;
					}
					else if (StrEqual(inputBuffer, "steamid"))
					{
						submenuInput[Submenu_method] = SteamId;
					}
					else if (StrEqual(inputBuffer, "userid2"))
					{
						submenuInput[Submenu_method] = UserId2;
					}
					else if (StrEqual(inputBuffer, "userid"))
					{
						submenuInput[Submenu_method] = UserId;
					}
					else if (StrEqual(inputBuffer, "ip"))
					{
						submenuInput[Submenu_method] = IpAddress;
					}
					else
					{
						submenuInput[Submenu_method] = Name;
					}				
				}
				
				kvMenu.GetString("title", inputBuffer, sizeof(inputBuffer));
				strcopy(submenuInput[Submenu_title], sizeof(submenuInput[Submenu_title]), inputBuffer);
	  			
	  			count++;
	  			Format(countBuffer, sizeof(countBuffer), "%i", count);
	  			
	  			itemInput[Item_submenus].PushArray(submenuInput[0]);
	  		
	  			kvMenu.GoBack();	
  			}
  			
  			/* Save this entire item into the global items array and add it to the menu */
  			
  			int location = g_DataArray.PushArray(itemInput[0]);
			
			char locString[10];
			IntToString(location, locString, sizeof(locString));

			if (hAdminMenu.AddItem(buffer,
				DynamicMenuItemHandler,
  				categoryId,
  				admin,
  				ADMFLAG_GENERIC,
  				locString) == INVALID_TOPMENUOBJECT)
			{
				LogError("Duplicate command name \"%s\" in adminmenu_custom.txt category \"%s\"", buffer, category_name);
			}
		
		} while (kvMenu.GotoNextKey());
		
		kvMenu.GoBack();
		
	} while (kvMenu.GotoNextKey());
	
	delete kvMenu;
}

void ParseConfigs()
{
	ParseConfigs2();
	if (!g_configParser)
		g_configParser = new SMCParser();
	
        g_configParser.OnEnterSection = NewSection;
        g_configParser.OnKeyValue = KeyValue;
        g_configParser.OnLeaveSection = EndSection;
	
	delete g_groupList[groupListName];
	delete g_groupList[groupListCommand];
	
	g_groupList[groupListName] = new ArrayList(ARRAY_STRING_LENGTH);
	g_groupList[groupListCommand] = new ArrayList(ARRAY_STRING_LENGTH);
	
	char configPath[256];
	BuildPath(Path_SM, configPath, sizeof(configPath), "configs/dynamicmenu/adminmenu_grouping.txt");
	if (FileExists(configPath))
	{
		LogError("Warning! configs/dynamicmenu/adminmenu_grouping.txt is now configs/adminmenu_grouping.txt.");
		LogError("Read the 1.0.2 release notes, as the dynamicmenu folder has been removed.");
	}
	else
	{
		BuildPath(Path_SM, configPath, sizeof(configPath), "configs/adminmenu_grouping.txt");
	}
	
	if (!FileExists(configPath))
	{
		LogError("Unable to locate admin menu groups file: %s", configPath);
			
		return;		
	}
	
	int line;
	SMCError err = g_configParser.ParseFile(configPath, line);
	if (err != SMCError_Okay)
	{
		char error[256];
		SMC_GetErrorString(err, error, sizeof(error));
		LogError("Could not parse file (line %d, file \"%s\"):", line, configPath);
		LogError("Parser encountered error: %s", error);
	}
	
	return;
}

public SMCResult NewSection(SMCParser smc, const char[] name, bool opt_quotes)
{

}

public SMCResult KeyValue(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	g_ConfigMenu.AddItem(key, value);
}

public SMCResult EndSection(SMCParser smc)
{
	
}

public void DynamicMenuCategoryHandler(TopMenu topmenu, 
						TopMenuAction action,
						TopMenuObject object_id,
						int param,
						char[] buffer,
						int maxlength)
{
	if ((action == TopMenuAction_DisplayTitle) || (action == TopMenuAction_DisplayOption))
	{
		topmenu.GetObjName(object_id, buffer, maxlength);
	}
}

public void DynamicMenuItemHandler(TopMenu topmenu, 
					  TopMenuAction action,
					  TopMenuObject object_id,
					  int param,
					  char[] buffer,
					  int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		topmenu.GetObjName(object_id, buffer, maxlength);
	}
	else if (action == TopMenuAction_SelectOption)
	{	
		char locString[10];
		topmenu.GetInfoString(object_id, locString, sizeof(locString));
		
		int location = StringToInt(locString);
		
		int output[Item];
		g_DataArray.GetArray(location, output[0]);
		
		strcopy(g_command[param], sizeof(g_command[]), output[Item_cmd]);
					
		g_currentPlace[param][Place_Item] = location;
		g_currentPlace[param][Place_ReplaceNum] = 1;
		
		ParamCheck(param);
	}
}

public void ParamCheck(int client)
{
	char buffer[6];
	char buffer2[6];
	
	int outputItem[Item];
	int outputSubmenu[Submenu];
	
	g_DataArray.GetArray(g_currentPlace[client][Place_Item], outputItem[0]);
		
	if (g_currentPlace[client][Place_ReplaceNum] < 1)
	{
		g_currentPlace[client][Place_ReplaceNum] = 1;
	}
	
	Format(buffer, 5, "#%i", g_currentPlace[client][Place_ReplaceNum]);
	Format(buffer2, 5, "@%i", g_currentPlace[client][Place_ReplaceNum]);
	
	if (StrContains(g_command[client], buffer) != -1 || StrContains(g_command[client], buffer2) != -1)
	{
		outputItem[Item_submenus].GetArray(g_currentPlace[client][Place_ReplaceNum] - 1, outputSubmenu[0]);
		
		Menu itemMenu = new Menu(Menu_Selection);
		itemMenu.ExitBackButton = true;
			
		if ((outputSubmenu[Submenu_type] == SubMenu_Group) || (outputSubmenu[Submenu_type] == SubMenu_GroupPlayer))
		{	
			char nameBuffer[ARRAY_STRING_LENGTH];
			char commandBuffer[ARRAY_STRING_LENGTH];
		
			for (int i = 0; i<g_groupCount; i++)
			{			
				g_groupList[groupListName].GetString(i, nameBuffer, sizeof(nameBuffer));
				g_groupList[groupListCommand].GetString(i, commandBuffer, sizeof(commandBuffer));
				itemMenu.AddItem(commandBuffer, nameBuffer);
			}
		}
		
		if (outputSubmenu[Submenu_type] == SubMenu_MapCycle)
		{	
			char path[200];
			outputSubmenu[Submenu_listdata].ReadString(path, sizeof(path));
			outputSubmenu[Submenu_listdata].Reset();
		
			File file = OpenFile(path, "rt");
			char readData[128];
			
			if (file)
			{
				while (!file.EndOfFile() && file.ReadLine(readData, sizeof(readData)))
				{
					TrimString(readData);
					
					if (IsMapValid(readData))
					{
						itemMenu.AddItem(readData, readData);
					}
				}
			}
		}
		else if ((outputSubmenu[Submenu_type] == SubMenu_Player) || (outputSubmenu[Submenu_type] == SubMenu_GroupPlayer))
		{
			PlayerMethod playermethod = outputSubmenu[Submenu_method];
		
			char nameBuffer[MAX_NAME_LENGTH];
			char infoBuffer[32];
			char temp[4];
			
			//loop through players. Add name as text and name/userid/steamid as info
			for (int i=1; i<=MaxClients; i++)
			{
				if (IsClientInGame(i))
				{			
					GetClientName(i, nameBuffer, sizeof(nameBuffer));
					
					switch (playermethod)
					{
						case UserId:
						{
							int userid = GetClientUserId(i);
							Format(infoBuffer, sizeof(infoBuffer), "#%i", userid);
							itemMenu.AddItem(infoBuffer, nameBuffer);	
						}
						case UserId2:
						{
							int userid = GetClientUserId(i);
							Format(infoBuffer, sizeof(infoBuffer), "%i", userid);
							itemMenu.AddItem(infoBuffer, nameBuffer);							
						}
						case SteamId:
						{
							if (GetClientAuthId(i, AuthId_Steam2, infoBuffer, sizeof(infoBuffer)))
								itemMenu.AddItem(infoBuffer, nameBuffer);
						}	
						case IpAddress:
						{
							GetClientIP(i, infoBuffer, sizeof(infoBuffer));
							itemMenu.AddItem(infoBuffer, nameBuffer);							
						}
						case Name:
						{
							itemMenu.AddItem(nameBuffer, nameBuffer);
						}	
						default: //assume client id
						{
							Format(temp,3,"%i",i);
							itemMenu.AddItem(temp, nameBuffer);						
						}								
					}
				}
			}
		}
		else if (outputSubmenu[Submenu_type] == SubMenu_OnOff)
		{
			itemMenu.AddItem("1", "On");
			itemMenu.AddItem("0", "Off");
		}		
		else
		{
			char value[64];
			char text[64];
					
			char admin[NAME_LENGTH];
			
			for (int i=0; i<outputSubmenu[Submenu_listcount]; i++)
			{
				outputSubmenu[Submenu_listdata].ReadString(value, sizeof(value));
				outputSubmenu[Submenu_listdata].ReadString(text, sizeof(text));
				outputSubmenu[Submenu_listdata].ReadString(admin, sizeof(admin));
				
				if (CheckCommandAccess(client, admin, 0))
				{
					itemMenu.AddItem(value, text);
				}
			}
			
			outputSubmenu[Submenu_listdata].Reset();
		}
		
		itemMenu.SetTitle(outputSubmenu[Submenu_title]);
		
		itemMenu.Display(client, MENU_TIME_FOREVER);
	}
	else
	{	
		//nothing else need to be done. Run teh command.
		
		hAdminMenu.Display(client, TopMenuPosition_LastCategory);
		
		char unquotedCommand[CMD_LENGTH];
		UnQuoteString(g_command[client], unquotedCommand, sizeof(unquotedCommand), "#@");
		
		if (outputItem[Item_execute] == Execute_Player) // assume 'player' type execute option
		{
			FakeClientCommand(client, unquotedCommand);
		}
		else // assume 'server' type execute option
		{
			InsertServerCommand(unquotedCommand);
			ServerExecute();
		}

		g_command[client][0] = '\0';
		g_currentPlace[client][Place_ReplaceNum] = 1;
	}
}

public int Menu_Selection(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	
	if (action == MenuAction_Select)
	{
		char unquotedinfo[NAME_LENGTH];
 
		/* Get item info */
		bool found = menu.GetItem(param2, unquotedinfo, sizeof(unquotedinfo));
		
		if (!found)
		{
			return 0;
		}
		
		char info[NAME_LENGTH*2+1];
		QuoteString(unquotedinfo, info, sizeof(info), "#@");
		
		
		char buffer[6];
		char infobuffer[NAME_LENGTH+2];
		Format(infobuffer, sizeof(infobuffer), "\"%s\"", info);
		
		Format(buffer, 5, "#%i", g_currentPlace[param1][Place_ReplaceNum]);
		ReplaceString(g_command[param1], sizeof(g_command[]), buffer, infobuffer);
		//replace #num with the selected option (quoted)
		
		Format(buffer, 5, "@%i", g_currentPlace[param1][Place_ReplaceNum]);
		ReplaceString(g_command[param1], sizeof(g_command[]), buffer, info);
		//replace @num with the selected option (unquoted)
		
		// Increment the parameter counter.
		g_currentPlace[param1][Place_ReplaceNum]++;
		
		ParamCheck(param1);
	}
	
	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		//client exited we should go back to submenu i think
		hAdminMenu.Display(param1, TopMenuPosition_LastCategory);
	}

	return 0;
}

stock bool QuoteString(char[] input, char[] output, int maxlen, char[] quotechars)
{
	int count = 0;
	int len = strlen(input);
	
	for (int i=0; i<len; i++)
	{
		output[count] = input[i];
		count++;
		
		if (count >= maxlen)
		{
			/* Null terminate for safety */
			output[maxlen-1] = 0;
			return false;	
		}
		
		if (FindCharInString(quotechars, input[i]) != -1 || input[i] == '\\')
		{
			/* This char needs escaping */
			output[count] = '\\';
			count++;
			
			if (count >= maxlen)
			{
				/* Null terminate for safety */
				output[maxlen-1] = 0;
				return false;	
			}		
		}
	}
	
	output[count] = 0;
	
	return true;
}

stock bool UnQuoteString(char[] input, char[] output, int maxlen, char[] quotechars)
{
	int count = 1;
	int len = strlen(input);
	
	output[0] = input[0];
	
	for (int i=1; i<len; i++)
	{
		output[count] = input[i];
		count++;
		
		if (input[i+1] == '\\' && (input[i] == '\\' || FindCharInString(quotechars, input[i]) != -1))
		{
			/* valid quotechar followed by a backslash - Skip */
			i++; 
		}
		
		if (count >= maxlen)
		{
			/* Null terminate for safety */
			output[maxlen-1] = 0;
			return false;	
		}
	}
	
	output[count] = 0;
	
	return true;
}


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("GetAdminTopMenu", __GetAdminTopMenu);
	CreateNative("AddTargetsToMenu", __AddTargetsToMenu);
	CreateNative("AddTargetsToMenu2", __AddTargetsToMenu2);
	RegPluginLibrary("adminmenu");
	return APLRes_Success;
}

TopMenu hTopMenu;

Menu g_MapList;
StringMap g_ProtectedVars;

void PerformKick(int client, int target, const char[] reason)
{
	LogAction(client, target, "\"%L\" kicked \"%L\" (reason \"%s\")", client, target, reason);

	if (reason[0] == '\0')
	{
		KickClient(target, "%t", "Kicked by admin");
	}
	else
	{
		KickClient(target, "%s", reason);
	}
}

void DisplayKickMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Kick);
	
	char title[100];
	Format(title, sizeof(title), "%T:", "Kick player", client);
	menu.SetTitle(title);
	menu.ExitBackButton = true;
	
	AddTargetsToMenu(menu, client, false, false);
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public void AdminMenu_Kick(TopMenu topmenu, 
					  TopMenuAction action,
					  TopMenuObject object_id,
					  int param,
					  char[] buffer,
					  int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "Kick player", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		DisplayKickMenu(param);
	}
}

public int MenuHandler_Kick(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hTopMenu)
		{
			hTopMenu.Display(param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		char info[32];
		int userid, target;
		
		menu.GetItem(param2, info, sizeof(info));
		userid = StringToInt(info);

		if ((target = GetClientOfUserId(userid)) == 0)
		{
			PrintToChat(param1, "[SM] %t", "Player no longer available");
		}
		else if (!CanUserTarget(param1, target))
		{
			PrintToChat(param1, "[SM] %t", "Unable to target");
		}
		else
		{
			char name[MAX_NAME_LENGTH];
			GetClientName(target, name, sizeof(name));
			ShowActivity2(param1, "[SM] ", "%t", "Kicked target", "_s", name);
			PerformKick(param1, target, "");
		}
		
		/* Re-draw the menu if they're still valid */
		if (IsClientInGame(param1) && !IsClientInKickQueue(param1))
		{
			DisplayKickMenu(param1);
		}
	}
}

public Action Command_Kick(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_kick <#userid|name> [reason]");
		return Plugin_Handled;
	}

	char Arguments[256];
	GetCmdArgString(Arguments, sizeof(Arguments));

	char arg[65];
	int len = BreakString(Arguments, arg, sizeof(arg));
	
	if (len == -1)
	{
		/* Safely null terminate */
		len = 0;
		Arguments[0] = '\0';
	}

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			arg,
			client, 
			target_list, 
			MAXPLAYERS, 
			COMMAND_FILTER_CONNECTED,
			target_name,
			sizeof(target_name),
			tn_is_ml)) > 0)
	{
		char reason[64];
		Format(reason, sizeof(reason), Arguments[len]);

		if (tn_is_ml)
		{
			if (reason[0] == '\0')
			{
				ShowActivity2(client, "[SM] ", "%t", "Kicked target", target_name);
			}
			else
			{
				ShowActivity2(client, "[SM] ", "%t", "Kicked target reason", target_name, reason);
			}
		}
		else
		{
			if (reason[0] == '\0')
			{
				ShowActivity2(client, "[SM] ", "%t", "Kicked target", "_s", target_name);            
			}
			else
			{
				ShowActivity2(client, "[SM] ", "%t", "Kicked target reason", "_s", target_name, reason);
			}
		}
		
		int kick_self = 0;
		
		for (int i = 0; i < target_count; i++)
		{
			/* Kick everyone else first */
			if (target_list[i] == client)
			{
				kick_self = client;
			}
			else
			{
				PerformKick(client, target_list[i], reason);
			}
		}
		
		if (kick_self)
		{
			PerformKick(client, client, reason);
		}
	}
	else
	{
		ReplyToTargetError(client, target_count);
	}

	return Plugin_Handled;
}

void PerformReloadAdmins(int client)
{
	/* Dump it all! */
	DumpAdminCache(AdminCache_Groups, true);
	DumpAdminCache(AdminCache_Overrides, true);

	LogAction(client, -1, "\"%L\" refreshed the admin cache.", client);
	ReplyToCommand(client, "[SM] %t", "Admin cache refreshed");
}

public void AdminMenu_ReloadAdmins(TopMenu topmenu, 
							  TopMenuAction action,
							  TopMenuObject object_id,
							  int param,
							  char[] buffer,
							  int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "Reload admins", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		PerformReloadAdmins(param);
		RedisplayAdminMenu(topmenu, param);	
	}
}

public Action Command_ReloadAdmins(int client, int args)
{
	PerformReloadAdmins(client);

	return Plugin_Handled;
}

void PerformCancelVote(int client)
{
	if (!IsVoteInProgress())
	{
		ReplyToCommand(client, "[SM] %t", "Vote Not In Progress");
		return;
	}

	ShowActivity2(client, "[SM] ", "%t", "Cancelled Vote");
	
	CancelVote();
}
	
public void AdminMenu_CancelVote(TopMenu topmenu, 
							  TopMenuAction action,
							  TopMenuObject object_id,
							  int param,
							  char[] buffer,
							  int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "Cancel vote", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		PerformCancelVote(param);
		RedisplayAdminMenu(topmenu, param);	
	}
	else if (action == TopMenuAction_DrawOption)
	{
		buffer[0] = IsVoteInProgress() ? ITEMDRAW_DEFAULT : ITEMDRAW_IGNORE;
	}
}

public Action Command_CancelVote(int client, int args)
{
	PerformCancelVote(client);

	return Plugin_Handled;
}

void PerformWho(int client, int target, ReplySource reply, bool is_admin)
{
	char name[MAX_NAME_LENGTH];
	GetClientName(target, name, sizeof(name));
	
	bool show_name = false;
	char admin_name[MAX_NAME_LENGTH];
	AdminId id = GetUserAdmin(target);
	if (id != INVALID_ADMIN_ID && id.GetUsername(admin_name, sizeof(admin_name)))
	{
		show_name = true;
	}
	
	ReplySource old_reply = SetCmdReplySource(reply);
	
	if (id == INVALID_ADMIN_ID)
	{
		ReplyToCommand(client, "[SM] %t", "Player is not an admin", name);
	}
	else
	{
		if (!is_admin)
		{
			ReplyToCommand(client, "[SM] %t", "Player is an admin", name);
		}
		else
		{
			int flags = GetUserFlagBits(target);
			char flagstring[255];
			if (flags == 0)
			{
				strcopy(flagstring, sizeof(flagstring), "none");
			}
			else if (flags & ADMFLAG_ROOT)
			{
				strcopy(flagstring, sizeof(flagstring), "root");
			}
			else
			{
				FlagsToString(flagstring, sizeof(flagstring), flags);
			}
			
			if (show_name)
			{
				ReplyToCommand(client, "[SM] %t", "Admin logged in as", name, admin_name, flagstring);
			}
			else
			{
				ReplyToCommand(client, "[SM] %t", "Admin logged in anon", name, flagstring);
			}
		}
	}
	
	SetCmdReplySource(old_reply);
}

void DisplayWhoMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Who);
	
	char title[100];
	Format(title, sizeof(title), "%T:", "Identify player", client);
	menu.SetTitle(title);
	menu.ExitBackButton = true;
	
	AddTargetsToMenu2(menu, 0, COMMAND_FILTER_CONNECTED);
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public void AdminMenu_Who(TopMenu topmenu, 
					  TopMenuAction action,
					  TopMenuObject object_id,
					  int param,
					  char[] buffer,
					  int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "Identify player", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		DisplayWhoMenu(param);
	}
}

public int MenuHandler_Who(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hTopMenu)
		{
			hTopMenu.Display(param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		char info[32];
		int userid, target;
		
		menu.GetItem(param2, info, sizeof(info));
		userid = StringToInt(info);

		if ((target = GetClientOfUserId(userid)) == 0)
		{
			PrintToChat(param1, "[SM] %t", "Player no longer available");
		}
		else if (!CanUserTarget(param1, target))
		{
			PrintToChat(param1, "[SM] %t", "Unable to target");
		}
		else
		{
			PerformWho(param1, target, SM_REPLY_TO_CHAT, (GetUserFlagBits(param1) != 0 ? true : false));
		}
		
		/* Re-draw the menu if they're still valid */
		
		/* - Close the menu? redisplay? jump back up to the category?
		if (IsClientInGame(param1) && !IsClientInKickQueue(param1))
		{
			DisplayWhoMenu(param1);
		}
		*/
	}
}
public Action Command_Who(int client, int args)
{
	bool is_admin = false;
	
	if (!client || (client && GetUserFlagBits(client) != 0))
	{
		is_admin = true;
	}
	
	if (args < 1)
	{
		/* Display header */
		char t_access[16], t_name[16], t_username[16];
		Format(t_access, sizeof(t_access), "%T", "Admin access", client);
		Format(t_name, sizeof(t_name), "%T", "Name", client);
		Format(t_username, sizeof(t_username), "%T", "Username", client);

		if (is_admin)
		{
			PrintToConsole(client, "    %-24.23s %-18.17s %s", t_name, t_username, t_access);
		}
		else
		{
			PrintToConsole(client, "    %-24.23s %s", t_name, t_access);
		}

		/* List all players */
		char flagstring[255];

		for (int i=1; i<=MaxClients; i++)
		{
			if (!IsClientInGame(i))
			{
				continue;
			}
			int flags = GetUserFlagBits(i);
			AdminId id = GetUserAdmin(i);
			if (flags == 0)
			{
				strcopy(flagstring, sizeof(flagstring), "none");
			}
			else if (flags & ADMFLAG_ROOT)
			{
				strcopy(flagstring, sizeof(flagstring), "root");
			}
			else
			{
				FlagsToString(flagstring, sizeof(flagstring), flags);
			}
			char name[MAX_NAME_LENGTH];
			char username[MAX_NAME_LENGTH];
			
			GetClientName(i, name, sizeof(name));
			
			if (id != INVALID_ADMIN_ID)
			{
				id.GetUsername(username, sizeof(username));
			}
			
			if (is_admin)
			{
				PrintToConsole(client, "%2d. %-24.23s %-18.17s %s", i, name, username, flagstring);
			}
			else
			{
				if (flags == 0)
				{
					PrintToConsole(client, "%2d. %-24.23s %t", i, name, "No");
				}
				else
				{
					PrintToConsole(client, "%2d. %-24.23s %t", i, name, "Yes");
				}
			}
		}

		if (GetCmdReplySource() == SM_REPLY_TO_CHAT)
		{
			ReplyToCommand(client, "[SM] %t", "See console for output");
		}

		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	int target = FindTarget(client, arg, false, false);
	if (target == -1)
	{
		return Plugin_Handled;
	}
	
	PerformWho(client, target, GetCmdReplySource(), is_admin);

	return Plugin_Handled;
}

public int MenuHandler_ChangeMap(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hTopMenu)
		{
			hTopMenu.Display(param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		char map[PLATFORM_MAX_PATH];
		
		menu.GetItem(param2, map, sizeof(map));
	
		ShowActivity2(param1, "[SM] ", "%t", "Changing map", map);

		LogAction(param1, -1, "\"%L\" changed map to \"%s\"", param1, map);

		DataPack dp;
		CreateDataTimer(3.0, Timer_ChangeMap, dp);
		dp.WriteString(map);
	}
	else if (action == MenuAction_Display)
	{
		char title[128];
		Format(title, sizeof(title), "%T", "Please select a map", param1);

		Panel panel = view_as<Panel>(param2);
		panel.SetTitle(title);
	}
}

public void AdminMenu_Map(TopMenu topmenu, 
							  TopMenuAction action,
							  TopMenuObject object_id,
							  int param,
							  char[] buffer,
							  int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "Choose Map", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		g_MapList.Display(param, MENU_TIME_FOREVER);
	}
}

public Action Command_Map(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_map <map>");
		return Plugin_Handled;
	}

	char map[PLATFORM_MAX_PATH];
	char displayName[PLATFORM_MAX_PATH];
	GetCmdArg(1, map, sizeof(map));

	if (FindMap(map, displayName, sizeof(displayName)) == FindMap_NotFound)
	{
		ReplyToCommand(client, "[SM] %t", "Map was not found", map);
		return Plugin_Handled;
	}

	GetMapDisplayName(displayName, displayName, sizeof(displayName));

	ShowActivity2(client, "[SM] ", "%t", "Changing map", displayName);
	LogAction(client, -1, "\"%L\" changed map to \"%s\"", client, map);

	DataPack dp;
	CreateDataTimer(3.0, Timer_ChangeMap, dp);
	dp.WriteString(map);

	return Plugin_Handled;
}

public Action Timer_ChangeMap(Handle timer, DataPack dp)
{
	char map[PLATFORM_MAX_PATH];

	dp.Reset();
	dp.ReadString(map, sizeof(map));

	ForceChangeLevel(map, "sm_map Command");

	return Plugin_Stop;
}

Handle g_map_array = null;
int g_map_serial = -1;

int LoadMapList(Menu menu)
{
	Handle map_array;
	
	if ((map_array = ReadMapList(g_map_array,
			g_map_serial,
			"sm_map menu",
			MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_NO_DEFAULT|MAPLIST_FLAG_MAPSFOLDER))
		!= null)
	{
		g_map_array = map_array;
	}
	
	if (g_map_array == null)
	{
		return 0;
	}
	
	menu.RemoveAllItems();
	
	char map_name[PLATFORM_MAX_PATH];
	int map_count = GetArraySize(g_map_array);
	
	for (int i = 0; i < map_count; i++)
	{
		GetArrayString(g_map_array, i, map_name, sizeof(map_name));
		menu.AddItem(map_name, map_name);
	}
	
	return map_count;
}

void PerformExec(int client, char[] path)
{
	if (!FileExists(path))
	{
		ReplyToCommand(client, "[SM] %t", "Config not found", path[4]);
		return;
	}

	ShowActivity2(client, "[SM] ", "%t", "Executed config", path[4]);

	LogAction(client, -1, "\"%L\" executed config (file \"%s\")", client, path[4]);

	ServerCommand("exec \"%s\"", path[4]);
}

public void AdminMenu_ExecCFG(TopMenu topmenu, 
					  TopMenuAction action,
					  TopMenuObject object_id,
					  int param,
					  char[] buffer,
					  int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "Exec CFG", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		g_ConfigMenu.Display(param, MENU_TIME_FOREVER);
	}
}

public int MenuHandler_ExecCFG(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hTopMenu)
		{
			hTopMenu.Display(param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		char path[256];
		
		menu.GetItem(param2, path, sizeof(path));
	
		PerformExec(param1, path);
	}
	else if (action == MenuAction_Display)
	{
		char title[128];
		Format(title, sizeof(title), "%T", "Choose Config", param1);

		Panel panel = view_as<Panel>(param2);
		panel.SetTitle(title);
	}
}

public Action Command_ExecCfg(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_execcfg <filename>");
		return Plugin_Handled;
	}

	char path[64] = "cfg/";
	GetCmdArg(1, path[4], sizeof(path)-4);

	PerformExec(client, path);

	return Plugin_Handled;
}

void ParseConfigs2()
{
	if (!config_parser)
		config_parser = new SMCParser();
	
	config_parser.OnEnterSection = NewSection;
	config_parser.OnLeaveSection = EndSection;
	config_parser.OnKeyValue = KeyValue;
	
	if (g_ConfigMenu != null)
	{
		delete g_ConfigMenu;
	}
	
	g_ConfigMenu = new Menu(MenuHandler_ExecCFG, MenuAction_Display);
	g_ConfigMenu.SetTitle("%T", "Choose Config", LANG_SERVER);
	g_ConfigMenu.ExitBackButton = true;
	
	char configPath[256];
	BuildPath(Path_SM, configPath, sizeof(configPath), "configs/adminmenu_cfgs.txt");
	
	if (!FileExists(configPath))
	{
		LogError("Unable to locate exec config file, no maps loaded.");
			
		return;		
	}
	
	int line;
	SMCError err = config_parser.ParseFile(configPath, line);
	if (err != SMCError_Okay)
	{
		char error[256];
		SMC_GetErrorString(err, error, sizeof(error));
		LogError("Could not parse file (line %d, file \"%s\"):", line, configPath);
		LogError("Parser encountered error: %s", error);
	}
	
	return;
}


public void OnPluginStart()
{
	BuildPath(Path_SM, g_BanReasonsPath, sizeof(g_BanReasonsPath), "configs/banreasons.txt");

	LoadBanReasons();
	LoadTranslations("common.phrases");
	LoadTranslations("basebans.phrases");
	LoadTranslations("core.phrases");
	LoadTranslations("adminmenu.phrases");
	LoadTranslations("adminhelp.phrases");
	LoadTranslations("clientprefs.phrases");
	LoadTranslations("plugin.basecommands");
	hOnAdminMenuCreated = CreateGlobalForward("OnAdminMenuCreated", ET_Ignore, Param_Cell);
	hOnAdminMenuReady = CreateGlobalForward("OnAdminMenuReady", ET_Ignore, Param_Cell);

	RegConsoleCmd("sm_help", HelpCmd, "Displays SourceMod commands and descriptions");
	//RegConsoleCmd("sm_searchcmd", HelpCmd, "Searches SourceMod commands");
	RegAdminCmd("sm_admin", Command_DisplayMenu, ADMFLAG_GENERIC, "Displays the admin menu");
	//RegConsoleCmd("sm_cookies", Command_Cookie, "sm_cookies <name> [value]");
	//RegConsoleCmd("sm_settings", Command_Settings);	
	RegAdminCmd("sm_kick", Command_Kick, ADMFLAG_KICK, "sm_kick <#userid|name> [reason]");
	RegAdminCmd("sm_map", Command_Map, ADMFLAG_CHANGEMAP, "sm_map <map>");
	RegAdminCmd("sm_rcon", Command_Rcon, ADMFLAG_RCON, "sm_rcon <args>");
	RegAdminCmd("sm_cvar", Command_Cvar, ADMFLAG_CONVARS, "sm_cvar <cvar> [value]");
	//RegAdminCmd("sm_resetcvar", Command_ResetCvar, ADMFLAG_CONVARS, "sm_resetcvar <cvar>");
	RegAdminCmd("sm_exec", Command_ExecCfg, ADMFLAG_CONFIG, "sm_exec <filename>");
	RegAdminCmd("sm_who", Command_Who, ADMFLAG_GENERIC, "sm_who [#userid|name]");
	//RegAdminCmd("sm_reloadadmins", Command_ReloadAdmins, ADMFLAG_BAN, "sm_reloadadmins");
	//RegAdminCmd("sm_cancelvote", Command_CancelVote, ADMFLAG_VOTE, "sm_cancelvote");
	//RegConsoleCmd("sm_revote", Command_ReVote);
	RegAdminCmd("sm_ban", Command_Ban, ADMFLAG_BAN, "sm_ban <#userid|name> <minutes|0> [reason]");
	RegAdminCmd("sm_unban", Command_Unban, ADMFLAG_UNBAN, "sm_unban <steamid|ip>");
	//RegAdminCmd("sm_addban", Command_AddBan, ADMFLAG_RCON, "sm_addban <time> <steamid> [reason]");
	//RegAdminCmd("sm_banip", Command_BanIp, ADMFLAG_BAN, "sm_banip <ip|#userid|name> <time> [reason]");
	//RegConsoleCmd("sm_abortban", Command_AbortBan, "sm_abortban");
	
	/* Account for late loading */
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
	{
		OnAdminMenuReady(topmenu);
	}
	
	g_MapList = new Menu(MenuHandler_ChangeMap, MenuAction_Display);
	g_MapList.SetTitle("%T", "Please select a map", LANG_SERVER);
	g_MapList.ExitBackButton = true;
	
	char mapListPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, mapListPath, sizeof(mapListPath), "configs/adminmenu_maplist.ini");
	SetMapListCompatBind("sm_map menu", mapListPath);
	
	g_ProtectedVars = new StringMap();
	ProtectVar("rcon_password");
	ProtectVar("sm_show_activity");
	ProtectVar("sm_immunity_mode");
}

public void OnConfigsExecuted()
{
	char path[PLATFORM_MAX_PATH];
	char error[256];
	
	BuildPath(Path_SM, path, sizeof(path), "configs/adminmenu_sorting.txt");
	
	if (!hAdminMenu.LoadConfig(path, error, sizeof(error)))
	{
		LogError("Could not load admin menu config (file \"%s\": %s)", path, error);
		return;
	}
	
	LoadMapList(g_MapList);
}

public void OnMapStart()
{
	LoadBanReasons();
	ParseConfigs();
}

public void OnAllPluginsLoaded()
{
	hAdminMenu = new TopMenu(DefaultCategoryHandler);
	
	obj_playercmds = hAdminMenu.AddCategory("PlayerCommands", DefaultCategoryHandler);
	obj_servercmds = hAdminMenu.AddCategory("ServerCommands", DefaultCategoryHandler);
	obj_votingcmds = hAdminMenu.AddCategory("VotingCommands", DefaultCategoryHandler);
		
	BuildDynamicMenu();
	
	Call_StartForward(hOnAdminMenuCreated);
	Call_PushCell(hAdminMenu);
	Call_Finish();
	
	Call_StartForward(hOnAdminMenuReady);
	Call_PushCell(hAdminMenu);
	Call_Finish();
}

public void DefaultCategoryHandler(TopMenu topmenu, 
						TopMenuAction action,
						TopMenuObject object_id,
						int param,
						char[] buffer,
						int maxlength)
{
	if (action == TopMenuAction_DisplayTitle)
	{
		if (object_id == INVALID_TOPMENUOBJECT)
		{
			Format(buffer, maxlength, "%T:", "Admin Menu", param);
		}
		else if (object_id == obj_playercmds)
		{
			Format(buffer, maxlength, "%T:", "Player Commands", param);
		}
		else if (object_id == obj_servercmds)
		{
			Format(buffer, maxlength, "%T:", "Server Commands", param);
		}
		else if (object_id == obj_votingcmds)
		{
			Format(buffer, maxlength, "%T:", "Voting Commands", param);
		}
	}
	else if (action == TopMenuAction_DisplayOption)
	{
		if (object_id == obj_playercmds)
		{
			Format(buffer, maxlength, "%T", "Player Commands", param);
		}
		else if (object_id == obj_servercmds)
		{
			Format(buffer, maxlength, "%T", "Server Commands", param);
		}
		else if (object_id == obj_votingcmds)
		{
			Format(buffer, maxlength, "%T", "Voting Commands", param);
		}
	}
}

public int __GetAdminTopMenu(Handle plugin, int numParams)
{
	return view_as<int>(hAdminMenu);
}

public int __AddTargetsToMenu(Handle plugin, int numParams)
{
	bool alive_only = false;
	
	if (numParams >= 4)
	{
		alive_only = GetNativeCell(4);
	}
	
	return UTIL_AddTargetsToMenu(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3), alive_only);
}

public int __AddTargetsToMenu2(Handle plugin, int numParams)
{
	return UTIL_AddTargetsToMenu2(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3));
}

public Action Command_DisplayMenu(int client, int args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "[SM] %t", "Command is in-game only");
		return Plugin_Handled;
	}
	
	hAdminMenu.Display(client, TopMenuPosition_Start);
	return Plugin_Handled;
}

stock int UTIL_AddTargetsToMenu2(Menu menu, int source_client, int flags)
{
	char user_id[12];
	char name[MAX_NAME_LENGTH];
	char display[MAX_NAME_LENGTH+12];
	
	int num_clients;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i) || IsClientInKickQueue(i))
		{
			continue;
		}
		
		if (((flags & COMMAND_FILTER_NO_BOTS) == COMMAND_FILTER_NO_BOTS)
			&& IsFakeClient(i))
		{
			continue;
		}
		
		if (((flags & COMMAND_FILTER_CONNECTED) != COMMAND_FILTER_CONNECTED)
			&& !IsClientInGame(i))
		{
			continue;
		}
		
		if (((flags & COMMAND_FILTER_ALIVE) == COMMAND_FILTER_ALIVE) 
			&& !IsPlayerAlive(i))
		{
			continue;
		}
		
		if (((flags & COMMAND_FILTER_DEAD) == COMMAND_FILTER_DEAD)
			&& IsPlayerAlive(i))
		{
			continue;
		}
		
		if ((source_client && ((flags & COMMAND_FILTER_NO_IMMUNITY) != COMMAND_FILTER_NO_IMMUNITY))
			&& !CanUserTarget(source_client, i))
		{
			continue;
		}
		
		IntToString(GetClientUserId(i), user_id, sizeof(user_id));
		GetClientName(i, name, sizeof(name));
		Format(display, sizeof(display), "%s (%s)", name, user_id);
		menu.AddItem(user_id, display);
		num_clients++;
	}
	
	return num_clients;
}

stock int UTIL_AddTargetsToMenu(Menu menu, int source_client, bool in_game_only, bool alive_only)
{
	int flags = 0;
	
	if (!in_game_only)
	{
		flags |= COMMAND_FILTER_CONNECTED;
	}
	
	if (alive_only)
	{
		flags |= COMMAND_FILTER_ALIVE;
	}
	
	return UTIL_AddTargetsToMenu2(menu, source_client, flags);
}

/** Various parsing globals */
bool g_LoggedFileName = false;       /* Whether or not the file name has been logged */
int g_ErrorCount = 0;                /* Current error count */
int g_IgnoreLevel = 0;               /* Nested ignored section count, so users can screw up files safely */
int g_CurrentLine = 0;               /* Current line we're on */
char g_Filename[PLATFORM_MAX_PATH];  /* Used for error messages */

enum OverrideState
{
	OverrideState_None,
	OverrideState_Levels,
	OverrideState_Overrides,
}

static SMCParser g_hOldOverrideParser;
static SMCParser g_hNewOverrideParser;
static OverrideState g_OverrideState = OverrideState_None;

public SMCResult ReadOldOverrides_NewSection(SMCParser smc, const char[] name, bool opt_quotes)
{
	if (g_IgnoreLevel)
	{
		g_IgnoreLevel++;
		return SMCParse_Continue;
	}
	
	if (g_OverrideState == OverrideState_None)
	{
		if (StrEqual(name, "Levels"))
		{
			g_OverrideState = OverrideState_Levels;
		} else {
			g_IgnoreLevel++;
		}
	} else if (g_OverrideState == OverrideState_Levels) {
		if (StrEqual(name, "Overrides"))
		{
			g_OverrideState = OverrideState_Overrides;
		} else {
			g_IgnoreLevel++;
		}
	} else {
		g_IgnoreLevel++;
	}
	
	return SMCParse_Continue;
}

public SMCResult ReadNewOverrides_NewSection(SMCParser smc, const char[] name, bool opt_quotes)
{
	if (g_IgnoreLevel)
	{
		g_IgnoreLevel++;
		return SMCParse_Continue;
	}
	
	if (g_OverrideState == OverrideState_None)
	{
		if (StrEqual(name, "Overrides"))
		{
			g_OverrideState = OverrideState_Overrides;
		} else {
			g_IgnoreLevel++;
		}
	} else {
		g_IgnoreLevel++;
	}
	
	return SMCParse_Continue;
}

public SMCResult ReadOverrides_KeyValue(SMCParser smc, 
										const char[] key, 
										const char[] value,
										bool key_quotes, 
										bool value_quotes)
{
	if (g_OverrideState != OverrideState_Overrides || g_IgnoreLevel)
	{
		return SMCParse_Continue;
	}
	
	int flags = ReadFlagString(value);
	
	if (key[0] == '@')
	{
		AddCommandOverride(key[1], Override_CommandGroup, flags);
	} else {
		AddCommandOverride(key, Override_Command, flags);
	}
	
	return SMCParse_Continue;
}

public SMCResult ReadOldOverrides_EndSection(SMCParser smc)
{
	/* If we're ignoring, skip out */
	if (g_IgnoreLevel)
	{
		g_IgnoreLevel--;
		return SMCParse_Continue;
	}
	
	if (g_OverrideState == OverrideState_Levels)
	{
		g_OverrideState = OverrideState_None;
	} else if (g_OverrideState == OverrideState_Overrides) {
		/* We're totally done parsing */
		g_OverrideState = OverrideState_Levels;
		return SMCParse_Halt;
	}
	
	return SMCParse_Continue;
}

public SMCResult ReadNewOverrides_EndSection(SMCParser smc)
{
	/* If we're ignoring, skip out */
	if (g_IgnoreLevel)
	{
		g_IgnoreLevel--;
		return SMCParse_Continue;
	}
	
	if (g_OverrideState == OverrideState_Overrides)
	{
		g_OverrideState = OverrideState_None;
	}
	
	return SMCParse_Continue;
}

public SMCResult ReadOverrides_CurrentLine(SMCParser smc, const char[] line, int lineno)
{
	g_CurrentLine = lineno;
	
	return SMCParse_Continue;
}

static void InitializeOverrideParsers()
{
	if (!g_hOldOverrideParser)
	{
		g_hOldOverrideParser = new SMCParser();
		g_hOldOverrideParser.OnEnterSection = ReadOldOverrides_NewSection;
		g_hOldOverrideParser.OnKeyValue = ReadOverrides_KeyValue;
		g_hOldOverrideParser.OnLeaveSection = ReadOldOverrides_EndSection;
		g_hOldOverrideParser.OnRawLine = ReadOverrides_CurrentLine;
	}
	if (!g_hNewOverrideParser)
	{
		g_hNewOverrideParser = new SMCParser();
		g_hNewOverrideParser.OnEnterSection = ReadNewOverrides_NewSection;
		g_hNewOverrideParser.OnKeyValue = ReadOverrides_KeyValue;
		g_hNewOverrideParser.OnLeaveSection = ReadNewOverrides_EndSection;
		g_hNewOverrideParser.OnRawLine = ReadOverrides_CurrentLine;
	}
}

void InternalReadOverrides(SMCParser parser, const char[] file)
{
	BuildPath(Path_SM, g_Filename, sizeof(g_Filename), file);
	
	/* Set states */
	InitGlobalStates();
	g_OverrideState = OverrideState_None;
		
	SMCError err = parser.ParseFile(g_Filename);
	if (err != SMCError_Okay)
	{
		char buffer[64];
		if (parser.GetErrorString(err, buffer, sizeof(buffer)))
		{
			ParseError("%s", buffer);
		} else {
			ParseError("Fatal parse error");
		}
	}
}

void ReadOverrides()
{
	InitializeOverrideParsers();
	InternalReadOverrides(g_hOldOverrideParser, "configs/admin_levels.cfg");
	InternalReadOverrides(g_hNewOverrideParser, "configs/admin_overrides.cfg");
}

enum GroupState
{
	GroupState_None,
	GroupState_Groups,
	GroupState_InGroup,
	GroupState_Overrides,
}

enum GroupPass
{
	GroupPass_Invalid,
	GroupPass_First,
	GroupPass_Second,
}

static SMCParser g_hGroupParser;
static GroupId g_CurGrp = INVALID_GROUP_ID;
static GroupState g_GroupState = GroupState_None;
static GroupPass g_GroupPass = GroupPass_Invalid;
static bool g_NeedReparse = false;

public SMCResult ReadGroups_NewSection(SMCParser smc, const char[] name, bool opt_quotes)
{
	if (g_IgnoreLevel)
	{
		g_IgnoreLevel++;
		return SMCParse_Continue;
	}
	
	if (g_GroupState == GroupState_None)
	{
		if (StrEqual(name, "Groups"))
		{
			g_GroupState = GroupState_Groups;
		} else {
			g_IgnoreLevel++;
		}
	} else if (g_GroupState == GroupState_Groups) {
		if ((g_CurGrp = CreateAdmGroup(name)) == INVALID_GROUP_ID)
		{
			g_CurGrp = FindAdmGroup(name);
		}
		g_GroupState = GroupState_InGroup;
	} else if (g_GroupState == GroupState_InGroup) {
		if (StrEqual(name, "Overrides"))
		{
			g_GroupState = GroupState_Overrides;
		} else {
			g_IgnoreLevel++;
		}
	} else {
		g_IgnoreLevel++;
	}
	
	return SMCParse_Continue;
}

public SMCResult ReadGroups_KeyValue(SMCParser smc, 
										const char[] key, 
										const char[] value, 
										bool key_quotes, 
										bool value_quotes)
{
	if (g_CurGrp == INVALID_GROUP_ID || g_IgnoreLevel)
	{
		return SMCParse_Continue;
	}
	
	AdminFlag flag;
	
	if (g_GroupPass == GroupPass_First)
	{
		if (g_GroupState == GroupState_InGroup)
		{
			if (StrEqual(key, "flags"))
			{
				int len = strlen(value);
				for (int i=0; i<len; i++)
				{
					if (!FindFlagByChar(value[i], flag))
					{
						continue;
					}
					g_CurGrp.SetFlag(flag, true);
				}
			} else if (StrEqual(key, "immunity")) {
				g_NeedReparse = true;
			}
		} else if (g_GroupState == GroupState_Overrides) {
			OverrideRule rule = Command_Deny;
			
			if (StrEqual(value, "allow", false))
			{
				rule = Command_Allow;
			}
			
			if (key[0] == '@')
			{
				g_CurGrp.AddCommandOverride(key[1], Override_CommandGroup, rule);
			} else {
				g_CurGrp.AddCommandOverride(key, Override_Command, rule);
			}
		}
	} else if (g_GroupPass == GroupPass_Second
			   && g_GroupState == GroupState_InGroup) {
		/* Check for immunity again, core should handle double inserts */
		if (StrEqual(key, "immunity"))
		{
			/* If it's a value we know about, use it */
			if (StrEqual(value, "*"))
			{
				g_CurGrp.ImmunityLevel = 2;
			} else if (StrEqual(value, "$")) {
				g_CurGrp.ImmunityLevel = 1;
			} else {
				int level;
				if (StringToIntEx(value, level))
				{
					g_CurGrp.ImmunityLevel = level;
				} else {
					GroupId id;
					if (value[0] == '@')
					{
						id = FindAdmGroup(value[1]);
					} else {
						id = FindAdmGroup(value);
					}
					if (id != INVALID_GROUP_ID)
					{
						g_CurGrp.AddGroupImmunity(id);
					} else {
						ParseError("Unable to find group: \"%s\"", value);
					}
				}
			}
		}
	}
	
	return SMCParse_Continue;
}

public SMCResult ReadGroups_EndSection(SMCParser smc)
{
	/* If we're ignoring, skip out */
	if (g_IgnoreLevel)
	{
		g_IgnoreLevel--;
		return SMCParse_Continue;
	}
	
	if (g_GroupState == GroupState_Overrides)
	{
		g_GroupState = GroupState_InGroup;
	} else if (g_GroupState == GroupState_InGroup) {
		g_GroupState = GroupState_Groups;
		g_CurGrp = INVALID_GROUP_ID;
	} else if (g_GroupState == GroupState_Groups) {
		g_GroupState = GroupState_None;
	}
	
	return SMCParse_Continue;
}

public SMCResult ReadGroups_CurrentLine(SMCParser smc, const char[] line, int lineno)
{
	g_CurrentLine = lineno;
	
	return SMCParse_Continue;
}

static void InitializeGroupParser()
{
	if (!g_hGroupParser)
	{
		g_hGroupParser = new SMCParser();
		g_hGroupParser.OnEnterSection = ReadGroups_NewSection;
		g_hGroupParser.OnKeyValue = ReadGroups_KeyValue;
		g_hGroupParser.OnLeaveSection = ReadGroups_EndSection;
		g_hGroupParser.OnRawLine = ReadGroups_CurrentLine;
	}
}

static void InternalReadGroups(const char[] path, GroupPass pass)
{
	/* Set states */
	InitGlobalStates();
	g_GroupState = GroupState_None;
	g_CurGrp = INVALID_GROUP_ID;
	g_GroupPass = pass;
	g_NeedReparse = false;
		
	SMCError err = g_hGroupParser.ParseFile(path);
	if (err != SMCError_Okay)
	{
		char buffer[64];
		if (g_hGroupParser.GetErrorString(err, buffer, sizeof(buffer)))
		{
			ParseError("%s", buffer);
		} else {
			ParseError("Fatal parse error");
		}
	}
}

void ReadGroups()
{
	InitializeGroupParser();
	
	BuildPath(Path_SM, g_Filename, sizeof(g_Filename), "configs/admin_groups.cfg");
	
	InternalReadGroups(g_Filename, GroupPass_First);
	if (g_NeedReparse)
	{
		InternalReadGroups(g_Filename, GroupPass_Second);
	}
}

enum UserState
{
	UserState_None,
	UserState_Admins,
	UserState_InAdmin,
}

static SMCParser g_hUserParser;
static UserState g_UserState = UserState_None;
static char g_CurAuth[64];
static char g_CurIdent[64];
static char g_CurName[64];
static char g_CurPass[64];
static ArrayList g_GroupArray;
static int g_CurFlags;
static int g_CurImmunity;

public SMCResult ReadUsers_NewSection(SMCParser smc, const char[] name, bool opt_quotes)
{
	if (g_IgnoreLevel)
	{
		g_IgnoreLevel++;
		return SMCParse_Continue;
	}
	
	if (g_UserState == UserState_None)
	{
		if (StrEqual(name, "Admins"))
		{
			g_UserState = UserState_Admins;
		}
		else
		{
			g_IgnoreLevel++;
		}
	}
	else if (g_UserState == UserState_Admins)
	{
		g_UserState = UserState_InAdmin;
		strcopy(g_CurName, sizeof(g_CurName), name);
		g_CurAuth[0] = '\0';
		g_CurIdent[0] = '\0';
		g_CurPass[0] = '\0';
		g_GroupArray.Clear();
		g_CurFlags = 0;
		g_CurImmunity = 0;
	}
	else
	{
		g_IgnoreLevel++;
	}
	
	return SMCParse_Continue;
}

public SMCResult ReadUsers_KeyValue(SMCParser smc, 
									const char[] key, 
									const char[] value, 
									bool key_quotes, 
									bool value_quotes)
{
	if (g_UserState != UserState_InAdmin || g_IgnoreLevel)
	{
		return SMCParse_Continue;
	}
	
	if (StrEqual(key, "auth"))
	{
		strcopy(g_CurAuth, sizeof(g_CurAuth), value);
	}
	else if (StrEqual(key, "identity"))
	{
		strcopy(g_CurIdent, sizeof(g_CurIdent), value);
	}
	else if (StrEqual(key, "password")) 
	{
		strcopy(g_CurPass, sizeof(g_CurPass), value);
	} 
	else if (StrEqual(key, "group")) 
	{
		GroupId id = FindAdmGroup(value);
		if (id == INVALID_GROUP_ID)
		{
			ParseError("Unknown group \"%s\"", value);
		}

		g_GroupArray.Push(id);
	} 
	else if (StrEqual(key, "flags")) 
	{
		int len = strlen(value);
		AdminFlag flag;
		
		for (int i = 0; i < len; i++)
		{
			if (!FindFlagByChar(value[i], flag))
			{
				ParseError("Invalid flag detected: %c", value[i]);
			}
			else
			{
				g_CurFlags |= FlagToBit(flag);
			}
		}
	} 
	else if (StrEqual(key, "immunity")) 
	{
		g_CurImmunity = StringToInt(value);
	}
	
	return SMCParse_Continue;
}

public SMCResult ReadUsers_EndSection(SMCParser smc)
{
	if (g_IgnoreLevel)
	{
		g_IgnoreLevel--;
		return SMCParse_Continue;
	}
	
	if (g_UserState == UserState_InAdmin)
	{
		/* Dump this user to memory */
		if (g_CurIdent[0] != '\0' && g_CurAuth[0] != '\0')
		{
			AdminFlag flags[26];
			AdminId id;
			int i, num_groups, num_flags;
			
			if ((id = FindAdminByIdentity(g_CurAuth, g_CurIdent)) == INVALID_ADMIN_ID)
			{
				id = CreateAdmin(g_CurName);
				if (!id.BindIdentity(g_CurAuth, g_CurIdent))
				{
					RemoveAdmin(id);
					ParseError("Failed to bind auth \"%s\" to identity \"%s\"", g_CurAuth, g_CurIdent);
					return SMCParse_Continue;
				}
			}
			
			num_groups = g_GroupArray.Length;
			for (i = 0; i < num_groups; i++)
			{
				id.InheritGroup(g_GroupArray.Get(i));
			}
			
			id.SetPassword(g_CurPass);
			if (id.ImmunityLevel < g_CurImmunity)
			{
				id.ImmunityLevel = g_CurImmunity;
			}
			
			num_flags = FlagBitsToArray(g_CurFlags, flags, sizeof(flags));
			for (i = 0; i < num_flags; i++)
			{
				id.SetFlag(flags[i], true);
			}
		}
		else
		{
			ParseError("Failed to create admin: did you forget either the auth or identity properties?");
		}
		
		g_UserState = UserState_Admins;
	}
	else if (g_UserState == UserState_Admins)
	{
		g_UserState = UserState_None;
	}
	
	return SMCParse_Continue;
}

public SMCResult ReadUsers_CurrentLine(SMCParser smc, const char[] line, int lineno)
{
	g_CurrentLine = lineno;
	
	return SMCParse_Continue;
}

static void InitializeUserParser()
{
	if (!g_hUserParser)
	{
		g_hUserParser = new SMCParser();
		g_hUserParser.OnEnterSection = ReadUsers_NewSection;
		g_hUserParser.OnKeyValue = ReadUsers_KeyValue;
		g_hUserParser.OnLeaveSection = ReadUsers_EndSection;
		g_hUserParser.OnRawLine = ReadUsers_CurrentLine;
		
		g_GroupArray = new ArrayList();
	}
}

void ReadUsers()
{
	InitializeUserParser();
	
	BuildPath(Path_SM, g_Filename, sizeof(g_Filename), "configs/admins.cfg");

	/* Set states */
	InitGlobalStates();
	g_UserState = UserState_None;
		
	SMCError err = g_hUserParser.ParseFile(g_Filename);
	if (err != SMCError_Okay)
	{
		char buffer[64];
		if (g_hUserParser.GetErrorString(err, buffer, sizeof(buffer)))
		{
			ParseError("%s", buffer);
		}
		else
		{
			ParseError("Fatal parse error");
		}
	}
}

public void ReadSimpleUsers()
{
	BuildPath(Path_SM, g_Filename, sizeof(g_Filename), "configs/admins_simple.ini");
	
	File file = OpenFile(g_Filename, "rt");
	if (!file)
	{
		ParseError("Could not open file!");
		return;
	}
	
	while (!file.EndOfFile())
	{
		char line[255];
		if (!file.ReadLine(line, sizeof(line)))
			break;
		
		/* Trim comments */
		int len = strlen(line);
		bool ignoring = false;
		for (int i=0; i<len; i++)
		{
			if (ignoring)
			{
				if (line[i] == '"')
					ignoring = false;
			} else {
				if (line[i] == '"')
				{
					ignoring = true;
				} else if (line[i] == ';') {
					line[i] = '\0';
					break;
				} else if (line[i] == '/'
							&& i != len - 1
							&& line[i+1] == '/')
				{
					line[i] = '\0';
					break;
				}
			}
		}
		
		TrimString(line);
		
		if ((line[0] == '/' && line[1] == '/')
			|| (line[0] == ';' || line[0] == '\0'))
		{
			continue;
		}
	
		ReadAdminLine(line);
	}
	
	file.Close();
}

void DecodeAuthMethod(const char[] auth, char method[32], int &offset)
{
	if ((StrContains(auth, "STEAM_") == 0) || (strncmp("0:", auth, 2) == 0) || (strncmp("1:", auth, 2) == 0))
	{
		// Steam2 Id
		strcopy(method, sizeof(method), AUTHMETHOD_STEAM);
		offset = 0;
	}
	else if (!strncmp(auth, "[U:", 3) && auth[strlen(auth) - 1] == ']')
	{
		// Steam3 Id
		strcopy(method, sizeof(method), AUTHMETHOD_STEAM);
		offset = 0;
	}
	else
	{
		if (auth[0] == '!')
		{
			strcopy(method, sizeof(method), AUTHMETHOD_IP);
			offset = 1;
		}
		else
		{
			strcopy(method, sizeof(method), AUTHMETHOD_NAME);
			offset = 0;
		}
	}
}

void ReadAdminLine(const char[] line)
{
	bool is_bound;
	AdminId admin;
	char auth[64];
	char auth_method[32];
	int idx, cur_idx, auth_offset;
	
	if ((cur_idx = BreakString(line, auth, sizeof(auth))) == -1)
	{
		/* This line is bad... we need at least two parameters */
		return;
	}
	
	idx = cur_idx;
	
	/* Check if we can bind beforehand */
	DecodeAuthMethod(auth, auth_method, auth_offset);
	if ((admin = FindAdminByIdentity(auth_method, auth[auth_offset])) == INVALID_ADMIN_ID)
	{
		/* There is no binding, create the admin */
		admin = CreateAdmin();
	}
	else
	{
		is_bound = true;
	}
	
	/* Read flags */
	char flags[64];	
	cur_idx = BreakString(line[idx], flags, sizeof(flags));
	idx += cur_idx;

	/* Read immunity level, if any */
	int level, flag_idx;

	if ((flag_idx = StringToIntEx(flags, level)) > 0)
	{
		admin.ImmunityLevel = level;
		if (flags[flag_idx] == ':')
		{
			flag_idx++;
		}
	}

	if (flags[flag_idx] == '@')
	{
		GroupId gid = FindAdmGroup(flags[flag_idx + 1]);
		if (gid == INVALID_GROUP_ID)
		{
			ParseError("Invalid group detected: %s", flags[flag_idx + 1]);
			return;
		}
		admin.InheritGroup(gid);
	}
	else
	{
		int len = strlen(flags[flag_idx]);
		bool is_default = false;
		for (int i=0; i<len; i++)
		{
			if (!level && flags[flag_idx + i] == '$')
			{
				admin.ImmunityLevel = 1;
			} else {
				AdminFlag flag;
				
				if (!FindFlagByChar(flags[flag_idx + i], flag))
				{
					ParseError("Invalid flag detected: %c", flags[flag_idx + i]);
					continue;
				}
				admin.SetFlag(flag, true);
			}
		}
		
		if (is_default)
		{
			GroupId gid = FindAdmGroup("Default");
			if (gid != INVALID_GROUP_ID)
			{
				admin.InheritGroup(gid);
			}
		}
	}
	
	/* Lastly, is there a password? */
	if (cur_idx != -1)
	{
		char password[64];
		BreakString(line[idx], password, sizeof(password));
		admin.SetPassword(password);
	}
	
	/* Now, bind the identity to something */
	if (!is_bound)
	{
		if (!admin.BindIdentity(auth_method, auth[auth_offset]))
		{
			/* We should never reach here */
			RemoveAdmin(admin);
			ParseError("Failed to bind identity %s (method %s)", auth[auth_offset], auth_method);			
		}
	}
}


public void OnRebuildAdminCache(AdminCachePart part)
{
	if (part == AdminCache_Overrides)
	{
		ReadOverrides();
	} else if (part == AdminCache_Groups) {
		ReadGroups();
	} else if (part == AdminCache_Admins) {
		ReadUsers();
		ReadSimpleUsers();
	}
}

void ParseError(const char[] format, any ...)
{
	char buffer[512];
	
	if (!g_LoggedFileName)
	{
		LogError("Error(s) detected parsing %s", g_Filename);
		g_LoggedFileName = true;
	}
	
	VFormat(buffer, sizeof(buffer), format, 2);
	
	LogError(" (line %d) %s", g_CurrentLine, buffer);
	
	g_ErrorCount++;
}

void InitGlobalStates()
{
	g_ErrorCount = 0;
	g_IgnoreLevel = 0;
	g_CurrentLine = 0;
	g_LoggedFileName = false;
}


public Action Command_Cookie(int client, int args)
{
	if (args == 0)
	{
		ReplyToCommand(client, "[SM] Usage: sm_cookies <name> [value]");
		ReplyToCommand(client, "[SM] %t", "Printing Cookie List");
		
		/* Show list of cookies */
		Handle iter = GetCookieIterator();
		
		char name[30];
		name[0] = '\0';
		char description[255];
		description[0] = '\0';
		
		PrintToConsole(client, "%t:", "Cookie List");
		
		CookieAccess access;
		
		while (ReadCookieIterator(iter, 
								name, 
								sizeof(name),
								access, 
								description, 
								sizeof(description)) != false)
		{
			if (access < CookieAccess_Private)
			{
				PrintToConsole(client, "%s - %s", name, description);
			}
		}
		
		delete iter;		
		return Plugin_Handled;
	}
	
	if (client == 0)
	{
		PrintToServer("%T", "No Console", LANG_SERVER);
		return Plugin_Handled;	
	}
	
	char name[30];
	name[0] = '\0';
	GetCmdArg(1, name, sizeof(name));
	
	Handle cookie = FindClientCookie(name);
	
	if (cookie == null)
	{
		ReplyToCommand(client, "[SM] %t", "Cookie not Found", name);
		return Plugin_Handled;
	}
	
	CookieAccess access = GetCookieAccess(cookie);
	
	if (access == CookieAccess_Private)
	{
		ReplyToCommand(client, "[SM] %t", "Cookie not Found", name);
		delete cookie;
		return Plugin_Handled;
	}
	
	char value[100];
	value[0] = '\0';
	
	if (args == 1)
	{
		GetClientCookie(client, cookie, value, sizeof(value));
		ReplyToCommand(client, "[SM] %t", "Cookie Value", name, value);
		
		delete cookie;
		return Plugin_Handled;
	}
	
	if (access == CookieAccess_Protected)
	{
		ReplyToCommand(client, "[SM] %t", "Protected Cookie", name);
		delete cookie;
		return Plugin_Handled;
	}
	
	/* Set the new value of the cookie */
	
	GetCmdArg(2, value, sizeof(value));
	
	SetClientCookie(client, cookie, value);
	delete cookie;
	ReplyToCommand(client, "[SM] %t", "Cookie Changed Value", name, value);
	
	return Plugin_Handled;
}

public Action Command_Settings(int client, int args)
{
	if (client == 0)
	{
		PrintToServer("%T", "No Console", LANG_SERVER);
		return Plugin_Handled;	
	}
	
	ShowCookieMenu(client);
	
	return Plugin_Handled;
}

void ProtectVar(const char[] cvar)
{
	g_ProtectedVars.SetValue(cvar, 1);
}

bool IsVarProtected(const char[] cvar)
{
	int dummy_value;
	return g_ProtectedVars.GetValue(cvar, dummy_value);
}

bool IsClientAllowedToChangeCvar(int client, const char[] cvarname)
{
	ConVar hndl = FindConVar(cvarname);

	bool allowed = false;
	int client_flags = client == 0 ? ADMFLAG_ROOT : GetUserFlagBits(client);
	
	if (client_flags & ADMFLAG_ROOT)
	{
		allowed = true;
	}
	else
	{
		if (hndl.Flags & FCVAR_PROTECTED)
		{
			allowed = ((client_flags & ADMFLAG_PASSWORD) == ADMFLAG_PASSWORD);
		}
		else if (StrEqual(cvarname, "sv_cheats"))
		{
			allowed = ((client_flags & ADMFLAG_CHEATS) == ADMFLAG_CHEATS);
		}
		else if (!IsVarProtected(cvarname))
		{
			allowed = true;
		}
	}

	return allowed;
}

public void OnAdminMenuReady(Handle aTopMenu)
{
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

	/* Block us from being called twice */
	if (topmenu == hTopMenu)
	{
		return;
	}
	
	/* Save the Handle */
	hTopMenu = topmenu;
	
	/* Build the "Player Commands" category */
	TopMenuObject player_commands = hTopMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);
	
	if (player_commands != INVALID_TOPMENUOBJECT)
	{
		hTopMenu.AddItem("sm_kick", AdminMenu_Kick, player_commands, "sm_kick", ADMFLAG_KICK);
		hTopMenu.AddItem("sm_who", AdminMenu_Who, player_commands, "sm_who", ADMFLAG_GENERIC);
		hTopMenu.AddItem("sm_ban", AdminMenu_Ban, player_commands, "sm_ban", ADMFLAG_BAN);
	}

	TopMenuObject server_commands = hTopMenu.FindCategory(ADMINMENU_SERVERCOMMANDS);

	if (server_commands != INVALID_TOPMENUOBJECT)
	{
		hTopMenu.AddItem("sm_reloadadmins", AdminMenu_ReloadAdmins, server_commands, "sm_reloadadmins", ADMFLAG_BAN);
		hTopMenu.AddItem("sm_map", AdminMenu_Map, server_commands, "sm_map", ADMFLAG_CHANGEMAP);
		hTopMenu.AddItem("sm_execcfg", AdminMenu_ExecCFG, server_commands, "sm_execcfg", ADMFLAG_CONFIG);		
	}

	TopMenuObject voting_commands = hTopMenu.FindCategory(ADMINMENU_VOTINGCOMMANDS);

	if (voting_commands != INVALID_TOPMENUOBJECT)
	{
		hTopMenu.AddItem("sm_cancelvote", AdminMenu_CancelVote, voting_commands, "sm_cancelvote", ADMFLAG_VOTE);
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (strcmp(name, "adminmenu") == 0)
	{
		hTopMenu = null;
	}
}

#define FLAG_STRINGS		14
char g_FlagNames[FLAG_STRINGS][20] =
{
	"res",
	"admin",
	"kick",
	"ban",
	"unban",
	"slay",
	"map",
	"cvars",
	"cfg",
	"chat",
	"vote",
	"pass",
	"rcon",
	"cheat"
};

int CustomFlagsToString(char[] buffer, int maxlength, int flags)
{
	char joins[6][6];
	int total;
	
	for (int i=view_as<int>(Admin_Custom1); i<=view_as<int>(Admin_Custom6); i++)
	{
		if (flags & (1<<i))
		{
			IntToString(i - view_as<int>(Admin_Custom1) + 1, joins[total++], 6);
		}
	}
	
	ImplodeStrings(joins, total, ",", buffer, maxlength);
	
	return total;
}

void FlagsToString(char[] buffer, int maxlength, int flags)
{
	char joins[FLAG_STRINGS+1][32];
	int total;

	for (int i=0; i<FLAG_STRINGS; i++)
	{
		if (flags & (1<<i))
		{
			strcopy(joins[total++], 32, g_FlagNames[i]);
		}
	}
	
	char custom_flags[32];
	if (CustomFlagsToString(custom_flags, sizeof(custom_flags), flags))
	{
		Format(joins[total++], 32, "custom(%s)", custom_flags);
	}

	ImplodeStrings(joins, total, ", ", buffer, maxlength);
}

public Action Command_Cvar(int client, int args)
{
	if (args < 1)
	{
		if (client == 0)
		{
			ReplyToCommand(client, "[SM] Usage: sm_cvar <cvar|protect> [value]");
		}
		else
		{
			ReplyToCommand(client, "[SM] Usage: sm_cvar <cvar> [value]");
		}
		return Plugin_Handled;
	}

	char cvarname[64];
	GetCmdArg(1, cvarname, sizeof(cvarname));
	
	if (client == 0 && StrEqual(cvarname, "protect"))
	{
		if (args < 2)
		{
			ReplyToCommand(client, "[SM] Usage: sm_cvar <protect> <cvar>");
			return Plugin_Handled;
		}
		GetCmdArg(2, cvarname, sizeof(cvarname));
		ProtectVar(cvarname);
		ReplyToCommand(client, "[SM] %t", "Cvar is now protected", cvarname);
		return Plugin_Handled;
	}

	ConVar hndl = FindConVar(cvarname);
	if (hndl == null)
	{
		ReplyToCommand(client, "[SM] %t", "Unable to find cvar", cvarname);
		return Plugin_Handled;
	}

	if (!IsClientAllowedToChangeCvar(client, cvarname))
	{
		ReplyToCommand(client, "[SM] %t", "No access to cvar");
		return Plugin_Handled;
	}

	char value[255];
	if (args < 2)
	{
		hndl.GetString(value, sizeof(value));

		ReplyToCommand(client, "[SM] %t", "Value of cvar", cvarname, value);
		return Plugin_Handled;
	}

	GetCmdArg(2, value, sizeof(value));
	
	// The server passes the values of these directly into ServerCommand, following exec. Sanitize.
	if (StrEqual(cvarname, "servercfgfile", false) || StrEqual(cvarname, "lservercfgfile", false))
	{
		int pos = StrContains(value, ";", true);
		if (pos != -1)
		{
			value[pos] = '\0';
		}
	}

	if ((hndl.Flags & FCVAR_PROTECTED) != FCVAR_PROTECTED)
	{
		ShowActivity2(client, "[SM] ", "%t", "Cvar changed", cvarname, value);
	}
	else
	{
		ReplyToCommand(client, "[SM] %t", "Cvar changed", cvarname, value);
	}

	LogAction(client, -1, "\"%L\" changed cvar (cvar \"%s\") (value \"%s\")", client, cvarname, value);

	hndl.SetString(value, true);

	return Plugin_Handled;
}

public Action Command_ResetCvar(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_resetcvar <cvar>");

		return Plugin_Handled;
	}

	char cvarname[64];
	GetCmdArg(1, cvarname, sizeof(cvarname));
	
	ConVar hndl = FindConVar(cvarname);
	if (hndl == null)
	{
		ReplyToCommand(client, "[SM] %t", "Unable to find cvar", cvarname);
		return Plugin_Handled;
	}
	
	if (!IsClientAllowedToChangeCvar(client, cvarname))
	{
		ReplyToCommand(client, "[SM] %t", "No access to cvar");
		return Plugin_Handled;
	}

	hndl.RestoreDefault();

	char value[255];
	hndl.GetString(value, sizeof(value));

	if ((hndl.Flags & FCVAR_PROTECTED) != FCVAR_PROTECTED)
	{
		ShowActivity2(client, "[SM] ", "%t", "Cvar changed", cvarname, value);
	}
	else
	{
		ReplyToCommand(client, "[SM] %t", "Cvar changed", cvarname, value);
	}

	LogAction(client, -1, "\"%L\" reset cvar (cvar \"%s\") (value \"%s\")", client, cvarname, value);

	return Plugin_Handled;
}

public Action Command_Rcon(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_rcon <args>");
		return Plugin_Handled;
	}

	char argstring[255];
	GetCmdArgString(argstring, sizeof(argstring));

	LogAction(client, -1, "\"%L\" console command (cmdline \"%s\")", client, argstring);

	if (client == 0) // They will already see the response in the console.
	{
		ServerCommand("%s", argstring);
	} else {
		char responseBuffer[4096];
		ServerCommandEx(responseBuffer, sizeof(responseBuffer), "%s", argstring);
		ReplyToCommand(client, responseBuffer);
	}

	return Plugin_Handled;
}

public Action Command_ReVote(int client, int args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "[SM] %t", "Command is in-game only");
		return Plugin_Handled;
	}
	
	if (!IsVoteInProgress())
	{
		ReplyToCommand(client, "[SM] %t", "Vote Not In Progress");
		return Plugin_Handled;
	}
	
	if (!IsClientInVotePool(client))
	{
		ReplyToCommand(client, "[SM] %t", "Cannot participate in vote");
		return Plugin_Handled;
	}
	
	if (!RedrawClientVoteMenu(client))
	{
		ReplyToCommand(client, "[SM] %t", "Cannot change vote");
	}
	
	return Plugin_Handled;
}

void PrepareBan(int client, int target, int time, const char[] reason)
{
	int originalTarget = GetClientOfUserId(g_BanTargetUserId[client]);

	if (originalTarget != target)
	{
		if (client == 0)
		{
			PrintToServer("[SM] %t", "Player no longer available");
		}
		else
		{
			PrintToChat(client, "[SM] %t", "Player no longer available");
		}

		return;
	}

	char name[MAX_NAME_LENGTH];
	GetClientName(target, name, sizeof(name));

	if (!time)
	{
		if (reason[0] == '\0')
		{
			ShowActivity(client, "%t", "Permabanned player", name);
		} else {
			ShowActivity(client, "%t", "Permabanned player reason", name, reason);
		}
	} else {
		if (reason[0] == '\0')
		{
			ShowActivity(client, "%t", "Banned player", name, time);
		} else {
			ShowActivity(client, "%t", "Banned player reason", name, time, reason);
		}
	}

	LogAction(client, target, "\"%L\" banned \"%L\" (minutes \"%d\") (reason \"%s\")", client, target, time, reason);

	if (reason[0] == '\0')
	{
		BanClient(target, time, BANFLAG_AUTO, "Banned", "Banned", "sm_ban", client);
	}
	else
	{
		BanClient(target, time, BANFLAG_AUTO, reason, reason, "sm_ban", client);
	}
}

void DisplayBanTargetMenu(int client)
{
	Menu menu = new Menu(MenuHandler_BanPlayerList);

	char title[100];
	Format(title, sizeof(title), "%T:", "Ban player", client);
	menu.SetTitle(title);
	menu.ExitBackButton = true;

	AddTargetsToMenu2(menu, client, COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED);

	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplayBanTimeMenu(int client)
{
	Menu menu = new Menu(MenuHandler_BanTimeList);

	char title[100];
	Format(title, sizeof(title), "%T: %N", "Ban player", client, g_BanTarget[client]);
	menu.SetTitle(title);
	menu.ExitBackButton = true;

	menu.AddItem("0", "Permanent");
	menu.AddItem("10", "10 Minutes");
	menu.AddItem("30", "30 Minutes");
	menu.AddItem("60", "1 Hour");
	menu.AddItem("240", "4 Hours");
	menu.AddItem("1440", "1 Day");
	menu.AddItem("10080", "1 Week");

	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplayBanReasonMenu(int client)
{
	Menu menu = new Menu(MenuHandler_BanReasonList);

	char title[100];
	Format(title, sizeof(title), "%T: %N", "Ban reason", client, g_BanTarget[client]);
	menu.SetTitle(title);
	menu.ExitBackButton = true;
	
	//Add custom chat reason entry first
	menu.AddItem("", "Custom reason (type in chat)");
	
	//Loading configurable entries from the kv-file
	char reasonName[100];
	char reasonFull[255];
	
	//Iterate through the kv-file
	g_hKvBanReasons.GotoFirstSubKey(false);
	do
	{
		g_hKvBanReasons.GetSectionName(reasonName, sizeof(reasonName));
		g_hKvBanReasons.GetString(NULL_STRING, reasonFull, sizeof(reasonFull));
		
		//Add entry
		menu.AddItem(reasonFull, reasonName);
		
	} while (g_hKvBanReasons.GotoNextKey(false));
	
	//Reset kvHandle
	g_hKvBanReasons.Rewind();

	menu.Display(client, MENU_TIME_FOREVER);
}

public void AdminMenu_Ban(TopMenu topmenu,
							  TopMenuAction action,
							  TopMenuObject object_id,
							  int param,
							  char[] buffer,
							  int maxlength)
{
	//Reset chat reason first
	g_IsWaitingForChatReason[param] = false;
	
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "Ban player", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		DisplayBanTargetMenu(param);
	}
}

public int MenuHandler_BanReasonList(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hTopMenu)
		{
			hTopMenu.Display(param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		if(param2 == 0)
		{
			//Chat reason
			g_IsWaitingForChatReason[param1] = true;
			PrintToChat(param1, "[SM] %t", "Custom ban reason explanation", "sm_abortban");
		}
		else
		{
			char info[64];
			
			menu.GetItem(param2, info, sizeof(info));
			
			PrepareBan(param1, g_BanTarget[param1], g_BanTime[param1], info);
		}
	}
}

public int MenuHandler_BanPlayerList(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hTopMenu)
		{
			hTopMenu.Display(param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		char info[32], name[32];
		int userid, target;

		menu.GetItem(param2, info, sizeof(info), _, name, sizeof(name));
		userid = StringToInt(info);

		if ((target = GetClientOfUserId(userid)) == 0)
		{
			PrintToChat(param1, "[SM] %t", "Player no longer available");
		}
		else if (!CanUserTarget(param1, target))
		{
			PrintToChat(param1, "[SM] %t", "Unable to target");
		}
		else
		{
			g_BanTarget[param1] = target;
			g_BanTargetUserId[param1] = userid;
			DisplayBanTimeMenu(param1);
		}
	}
}

public int MenuHandler_BanTimeList(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hTopMenu)
		{
			hTopMenu.Display(param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		char info[32];

		menu.GetItem(param2, info, sizeof(info));
		g_BanTime[param1] = StringToInt(info);

		DisplayBanReasonMenu(param1);
	}
}

public Action Command_Ban(int client, int args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_ban <#userid|name> <minutes|0> [reason]");
		return Plugin_Handled;
	}

	int len, next_len;
	char Arguments[256];
	GetCmdArgString(Arguments, sizeof(Arguments));

	char arg[65];
	len = BreakString(Arguments, arg, sizeof(arg));

	int target = FindTarget(client, arg, true);
	if (target == -1)
	{
		return Plugin_Handled;
	}

	char s_time[12];
	if ((next_len = BreakString(Arguments[len], s_time, sizeof(s_time))) != -1)
	{
		len += next_len;
	}
	else
	{
		len = 0;
		Arguments[0] = '\0';
	}

	int time = StringToInt(s_time);

	g_BanTargetUserId[client] = GetClientUserId(target);

	PrepareBan(client, target, time, Arguments[len]);

	return Plugin_Handled;
}


public void OnClientDisconnect(int client)
{
	g_IsWaitingForChatReason[client] = false;
}

void LoadBanReasons()
{
	delete g_hKvBanReasons;

	g_hKvBanReasons = new KeyValues("banreasons");

	if (g_hKvBanReasons.ImportFromFile(g_BanReasonsPath))
	{
		char sectionName[255];
		if (!g_hKvBanReasons.GetSectionName(sectionName, sizeof(sectionName)))
		{
			SetFailState("Error in %s: File corrupt or in the wrong format", g_BanReasonsPath);
			return;
		}

		if (strcmp(sectionName, "banreasons") != 0)
		{
			SetFailState("Error in %s: Couldn't find 'banreasons'", g_BanReasonsPath);
			return;
		}
		
		//Reset kvHandle
		g_hKvBanReasons.Rewind();
	} else {
		SetFailState("Error in %s: File not found, corrupt or in the wrong format", g_BanReasonsPath);
		return;
	}
}

public Action Command_BanIp(int client, int args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_banip <ip|#userid|name> <time> [reason]");
		return Plugin_Handled;
	}

	int len, next_len;
	char Arguments[256];
	char arg[50], time[20];
	
	GetCmdArgString(Arguments, sizeof(Arguments));
	len = BreakString(Arguments, arg, sizeof(arg));
	
	if ((next_len = BreakString(Arguments[len], time, sizeof(time))) != -1)
	{
		len += next_len;
	}
	else
	{
		len = 0;
		Arguments[0] = '\0';
	}

	if (StrEqual(arg, "0"))
	{
		ReplyToCommand(client, "[SM] %t", "Cannot ban that IP");
		return Plugin_Handled;
	}
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[1];
	bool tn_is_ml;
	int found_client = -1;
	
	if (ProcessTargetString(
			arg,
			client, 
			target_list, 
			1, 
			COMMAND_FILTER_CONNECTED|COMMAND_FILTER_NO_MULTI,
			target_name,
			sizeof(target_name),
			tn_is_ml) > 0)
	{
		found_client = target_list[0];
	}
	
	bool has_rcon;
	
	if (client == 0 || (client == 1 && !IsDedicatedServer()))
	{
		has_rcon = true;
	}
	else
	{
		AdminId id = GetUserAdmin(client);
		has_rcon = (id == INVALID_ADMIN_ID) ? false : GetAdminFlag(id, Admin_RCON);
	}
	
	int hit_client = -1;
	if (found_client != -1
		&& !IsFakeClient(found_client)
		&& (has_rcon || CanUserTarget(client, found_client)))
	{
		GetClientIP(found_client, arg, sizeof(arg));
		hit_client = found_client;
	}
	
	if (hit_client == -1 && !has_rcon)
	{
		ReplyToCommand(client, "[SM] %t", "No Access");
		return Plugin_Handled;
	}

	int minutes = StringToInt(time);

	LogAction(client, 
			  hit_client, 
			  "\"%L\" added ban (minutes \"%d\") (ip \"%s\") (reason \"%s\")", 
			  client, 
			  minutes, 
			  arg, 
			  Arguments[len]);
				
	ReplyToCommand(client, "[SM] %t", "Ban added");
	
	BanIdentity(arg, 
				minutes, 
				BANFLAG_IP, 
				Arguments[len], 
				"sm_banip", 
				client);
				
	if (hit_client != -1)
	{
		KickClient(hit_client, "Banned: %s", Arguments[len]);
	}

	return Plugin_Handled;
}

public Action Command_AddBan(int client, int args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_addban <time> <steamid> [reason]");
		return Plugin_Handled;
	}

	char arg_string[256];
	char time[50];
	char authid[50];

	GetCmdArgString(arg_string, sizeof(arg_string));

	int len, total_len;

	/* Get time */
	if ((len = BreakString(arg_string, time, sizeof(time))) == -1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_addban <time> <steamid> [reason]");
		return Plugin_Handled;
	}	
	total_len += len;

	/* Get steamid */
	if ((len = BreakString(arg_string[total_len], authid, sizeof(authid))) != -1)
	{
		total_len += len;
	}
	else
	{
		total_len = 0;
		arg_string[0] = '\0';
	}

	/* Verify steamid */
	bool idValid = false;
	if (!strncmp(authid, "STEAM_", 6) && authid[7] == ':')
		idValid = true;
	else if (!strncmp(authid, "[U:", 3))
		idValid = true;
	
	if (!idValid)
	{
		ReplyToCommand(client, "[SM] %t", "Invalid SteamID specified");
		return Plugin_Handled;
	}

	int minutes = StringToInt(time);

	LogAction(client, 
			  -1, 
			  "\"%L\" added ban (minutes \"%d\") (id \"%s\") (reason \"%s\")", 
			  client, 
			  minutes, 
			  authid, 
			  arg_string[total_len]);
	BanIdentity(authid, 
				minutes, 
				BANFLAG_AUTHID, 
				arg_string[total_len], 
				"sm_addban", 
				client);

	ReplyToCommand(client, "[SM] %t", "Ban added");

	return Plugin_Handled;
}

public Action Command_Unban(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_unban <steamid|ip>");
		return Plugin_Handled;
	}

	char arg[50];
	GetCmdArgString(arg, sizeof(arg));

	ReplaceString(arg, sizeof(arg), "\"", "");	

	int ban_flags;
	if (IsCharNumeric(arg[0]))
	{
		ban_flags |= BANFLAG_IP;
	}
	else
	{
		ban_flags |= BANFLAG_AUTHID;
	}

	LogAction(client, -1, "\"%L\" removed ban (filter \"%s\")", client, arg);
	RemoveBan(arg, ban_flags, "sm_unban", client);

	ReplyToCommand(client, "[SM] %t", "Removed bans matching", arg);

	return Plugin_Handled;
}

public Action Command_AbortBan(int client, int args)
{
	if(!CheckCommandAccess(client, "sm_ban", ADMFLAG_BAN))
	{
		ReplyToCommand(client, "[SM] %t", "No Access");
		return Plugin_Handled;
	}
	if(g_IsWaitingForChatReason[client])
	{
		g_IsWaitingForChatReason[client] = false;
		ReplyToCommand(client, "[SM] %t", "AbortBan applied successfully");
	}
	else
	{
		ReplyToCommand(client, "[SM] %t", "AbortBan not waiting for custom reason");
	}
	
	return Plugin_Handled;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if(g_IsWaitingForChatReason[client])
	{
		g_IsWaitingForChatReason[client] = false;
		PrepareBan(client, g_BanTarget[client], g_BanTime[client], sArgs);
		return Plugin_Stop;
	}

	return Plugin_Continue;
}
