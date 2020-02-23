public Action Command_LastGrenade(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  int index = g_GrenadeHistoryPositions[client].Length - 1;
  if (index >= 0) {
    TeleportToGrenadeHistoryPosition(client, index);
    PM_Message(client, "传送至投掷物历史位置 %d", index + 1);
  }

  return Plugin_Handled;
}

public Action Command_NextGrenade(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0) {
    return Plugin_Handled;
  }

  int nextId = FindNextGrenadeId(client, nadeId);
  if (nextId != -1) {
    char auth[AUTH_LENGTH];
    GetClientAuthId(client, AUTH_METHOD, auth, sizeof(auth));

    char idBuffer[GRENADE_ID_LENGTH];
    IntToString(nextId, idBuffer, sizeof(idBuffer));
    TeleportToSavedGrenadePosition(client, idBuffer);
  }

  return Plugin_Handled;
}

public Action Command_GrenadeBack(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  char argString[64];
  if (args >= 1 && GetCmdArg(1, argString, sizeof(argString))) {
    int index = StringToInt(argString) - 1;
    if (index >= 0 && index < g_GrenadeHistoryPositions[client].Length) {
      g_GrenadeHistoryIndex[client] = index;
      TeleportToGrenadeHistoryPosition(client, g_GrenadeHistoryIndex[client]);
      PM_Message(client, "传送至投掷物历史位置 %d",
                 g_GrenadeHistoryIndex[client] + 1);
    } else {
      PM_Message(client, "您的投掷物历史只有 1 到 %d.",
                 g_GrenadeHistoryPositions[client].Length);
    }
    return Plugin_Handled;
  }

  if (g_GrenadeHistoryPositions[client].Length > 0) {
    g_GrenadeHistoryIndex[client]--;
    if (g_GrenadeHistoryIndex[client] < 0)
      g_GrenadeHistoryIndex[client] = 0;

    TeleportToGrenadeHistoryPosition(client, g_GrenadeHistoryIndex[client]);
    PM_Message(client, "传送至投掷物历史位置 %d",
               g_GrenadeHistoryIndex[client] + 1);
  }

  return Plugin_Handled;
}

public Action Command_SavePos(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  AddGrenadeToHistory(client);
  PM_Message(client, "位置已保存。使用 .back 返回位置");
  return Plugin_Handled;
}

public Action Command_GrenadeForward(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (g_GrenadeHistoryPositions[client].Length > 0) {
    int max = g_GrenadeHistoryPositions[client].Length;
    g_GrenadeHistoryIndex[client]++;
    if (g_GrenadeHistoryIndex[client] >= max)
      g_GrenadeHistoryIndex[client] = max - 1;
    TeleportToGrenadeHistoryPosition(client, g_GrenadeHistoryIndex[client]);
    PM_Message(client, "传送至投掷物历史位置 %d",
               g_GrenadeHistoryIndex[client] + 1);
  }

  return Plugin_Handled;
}

public Action Command_ClearNades(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  ClearArray(g_GrenadeHistoryPositions[client]);
  ClearArray(g_GrenadeHistoryAngles[client]);
  PM_Message(client, "投掷物历史已清除。");

  return Plugin_Handled;
}

public Action Command_GotoNade(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  char arg[GRENADE_ID_LENGTH];
  if (args >= 1 && GetCmdArg(1, arg, sizeof(arg))) {
    char id[GRENADE_ID_LENGTH];
    if (!FindGrenade(arg, id) || !TeleportToSavedGrenadePosition(client, arg)) {
      PM_Message(client, "投掷物 ID %s 未找到", arg);
      return Plugin_Handled;
    }
  } else {
    PM_Message(client, "用法: .goto <投掷物ID>");
  }

  return Plugin_Handled;
}

public Action Command_Grenades(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  char arg[MAX_NAME_LENGTH];
  if (args >= 1 && GetCmdArgString(arg, sizeof(arg))) {
    ArrayList ids = new ArrayList(GRENADE_ID_LENGTH);
    char data[256];
    GrenadeMenuType type = FindGrenades(arg, ids, data, sizeof(data));
    if (type != GrenadeMenuType_Invalid) {
      GiveGrenadeMenu(client, type, 0, data, ids);
    } else {
      PM_Message(client, "无相符投掷物。");
    }
    delete ids;

  } else {
    bool categoriesOnly = (g_SharedAllNadesCvar.IntValue != 0);
    if (categoriesOnly) {
      GiveGrenadeMenu(client, GrenadeMenuType_Categories);
    } else {
      GiveGrenadeMenu(client, GrenadeMenuType_PlayersAndCategories);
    }
  }

  return Plugin_Handled;
}

public Action Command_Find(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  char arg[MAX_NAME_LENGTH];
  if (args >= 1 && GetCmdArgString(arg, sizeof(arg))) {
    GiveGrenadeMenu(client, GrenadeMenuType_MatchingName, 0, arg, null,
                    GrenadeMenuType_MatchingName);
  } else {
    PM_Message(client, "用法: .find <关键词>");
  }

  return Plugin_Handled;
}

public Action Command_GrenadeDescription(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "此投掷物不属于您。");
    return Plugin_Handled;
  }

  char description[GRENADE_DESCRIPTION_LENGTH];
  GetCmdArgString(description, sizeof(description));

  UpdateGrenadeDescription(nadeId, description);
  PM_Message(client, "已添加投掷物描述。");
  return Plugin_Handled;
}

public Action Command_RenameGrenade(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "此投掷物不属于您。");
    return Plugin_Handled;
  }

  char name[GRENADE_NAME_LENGTH];
  GetCmdArgString(name, sizeof(name));

  UpdateGrenadeName(nadeId, name);
  PM_Message(client, "已更新投掷物描述。");
  return Plugin_Handled;
}

public Action Command_DeleteGrenade(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  // get the grenade id first
  char grenadeIdStr[32];
  if (args < 1 || !GetCmdArg(1, grenadeIdStr, sizeof(grenadeIdStr))) {
    // if this fails, use the last grenade position
    IntToString(g_CurrentSavedGrenadeId[client], grenadeIdStr, sizeof(grenadeIdStr));
  }

  if (!CanEditGrenade(client, StringToInt(grenadeIdStr))) {
    PM_Message(client, "此投掷物不属于您。");
    return Plugin_Handled;
  }

  DeleteGrenadeFromKv(grenadeIdStr);
  PM_Message(client, "已删除投掷物 ID为 %s 的投掷物。", grenadeIdStr);
  return Plugin_Handled;
}

public Action Command_SaveGrenade(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  char name[GRENADE_NAME_LENGTH];
  GetCmdArgString(name, sizeof(name));
  TrimString(name);

  if (StrEqual(name, "")) {
    PM_Message(client, "用法: .save <名称>");
    return Plugin_Handled;
  }

  char auth[AUTH_LENGTH];
  GetClientAuthId(client, AUTH_METHOD, auth, sizeof(auth));
  char grenadeId[GRENADE_ID_LENGTH];
  if (FindGrenadeByName(auth, name, grenadeId)) {
    PM_Message(client, "您已经使用了那个名字。");
    return Plugin_Handled;
  }

  int max_saved_grenades = g_MaxGrenadesSavedCvar.IntValue;
  if (max_saved_grenades > 0 && CountGrenadesForPlayer(auth) >= max_saved_grenades) {
    PM_Message(client, "您已经达到的您所能保存的最大投掷物数量 (%d)。",
               max_saved_grenades);
    return Plugin_Handled;
  }

  if (GetEntityMoveType(client) == MOVETYPE_NOCLIP) {
    PM_Message(client, "在穿墙模式（Noclip）下无法保存投掷物。");
    return Plugin_Handled;
  }

  float origin[3];
  float angles[3];
  GetClientAbsOrigin(client, origin);
  GetClientEyeAngles(client, angles);

  GrenadeType grenadeType = g_LastGrenadeType[client];
  float grenadeOrigin[3];
  float grenadeVelocity[3];
  grenadeOrigin = g_LastGrenadeOrigin[client];
  grenadeVelocity = g_LastGrenadeVelocity[client];

  if (grenadeType != GrenadeType_None && GetVectorDistance(origin, grenadeOrigin) >= 500.0) {
    PM_Message(
        client,
        "{LIGHT_RED}警告: {NORMAL}您保存的投掷物组合与您投掷的最后一枚投掷物组合相距很远。 如果 .throw 不起作用，请手动将投掷物在组合内扔出，然后键入.update进行修复。");
  }

  Action ret = Plugin_Continue;
  Call_StartForward(g_OnGrenadeSaved);
  Call_PushCell(client);
  Call_PushArray(origin, sizeof(origin));
  Call_PushArray(angles, sizeof(angles));
  Call_PushString(name);
  Call_Finish(ret);

  if (ret < Plugin_Handled) {
    int nadeId =
        SaveGrenadeToKv(client, origin, angles, grenadeOrigin, grenadeVelocity, grenadeType, name);
    g_CurrentSavedGrenadeId[client] = nadeId;
    PM_Message(
        client,
        "保存投掷物位置 (ID %d)。 输入 .desc <描述> 为此投掷物添加描述 输入 .delete 以删除此位置。",
        nadeId);

    if (g_CSUtilsLoaded) {
      if (IsGrenade(g_LastGrenadeType[client])) {
        char grenadeName[64];
        GrenadeTypeString(g_LastGrenadeType[client], grenadeName, sizeof(grenadeName));
        PM_Message(
            client,
            "已保存 %s 投掷。 使用 .clearthrow 或 .savethrow 以改变投掷物参数。",
            grenadeName);
      } else {
        PM_Message(client,
                   "没有投掷物参数被保存。 使用 .savethrow 以保存。");
      }
    }
  }

  g_LastGrenadeType[client] = GrenadeType_None;
  return Plugin_Handled;
}

public Action Command_MoveGrenade(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "此投掷物不属于您。");
    return Plugin_Handled;
  }

  if (GetEntityMoveType(client) == MOVETYPE_NOCLIP) {
    PM_Message(client, "在穿墙模式（Noclip）下无法保存投掷物。");
    return Plugin_Handled;
  }

  float origin[3];
  float angles[3];
  GetClientAbsOrigin(client, origin);
  GetClientEyeAngles(client, angles);
  SetClientGrenadeVectors(nadeId, origin, angles);
  PM_Message(client, "已更新投掷物位置。");
  return Plugin_Handled;
}

public Action Command_SaveThrow(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (!g_CSUtilsLoaded) {
    PM_Message(client, "您需要安装csutils插件以使用此命令。");
    return Plugin_Handled;
  }

  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "此投掷物不属于您。");
    return Plugin_Handled;
  }

  SetClientGrenadeParameters(nadeId, g_LastGrenadeType[client], g_LastGrenadeOrigin[client],
                             g_LastGrenadeVelocity[client]);
  PM_Message(client, "已更新投掷物参数。");
  g_LastGrenadeType[client] = GrenadeType_None;
  return Plugin_Handled;
}

public Action Command_UpdateGrenade(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "此投掷物不属于您。");
    return Plugin_Handled;
  }

  if (GetEntityMoveType(client) == MOVETYPE_NOCLIP) {
    PM_Message(client, "在穿墙模式（Noclip）下无法保存投掷物。");
    return Plugin_Handled;
  }

  float origin[3];
  float angles[3];
  GetClientAbsOrigin(client, origin);
  GetClientEyeAngles(client, angles);
  SetClientGrenadeVectors(nadeId, origin, angles);
  bool updatedParameters = false;
  if (g_CSUtilsLoaded && IsGrenade(g_LastGrenadeType[client])) {
    updatedParameters = true;
    SetClientGrenadeParameters(nadeId, g_LastGrenadeType[client], g_LastGrenadeOrigin[client],
                               g_LastGrenadeVelocity[client]);
  }

  if (updatedParameters) {
    PM_Message(client, "已更新投掷物位置与参数。");
  } else {
    PM_Message(client, "已更新投掷物位置。");
  }

  g_LastGrenadeType[client] = GrenadeType_None;
  return Plugin_Handled;
}

public Action Command_SetDelay(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (!g_CSUtilsLoaded) {
    PM_Message(client, "您需要安装csutils插件以使用此命令。");
    return Plugin_Handled;
  }

  if (args < 1) {
    PM_Message(client, "用法: .delay <持续时间>");
    return Plugin_Handled;
  }

  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "此投掷物不属于您。");
    return Plugin_Handled;
  }

  char arg[64];
  GetCmdArgString(arg, sizeof(arg));
  float delay = StringToFloat(arg);
  SetClientGrenadeFloat(nadeId, "delay", delay);
  PM_Message(client, "已保存延迟为 %.1f 秒 ID为 %d 的投掷物。", delay, nadeId);
  return Plugin_Handled;
}

public Action Command_ClearThrow(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (!g_CSUtilsLoaded) {
    PM_Message(client, "您需要安装csutils插件以使用此命令。");
    return Plugin_Handled;
  }

  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "此投掷物不属于您。");
    return Plugin_Handled;
  }

  SetClientGrenadeParameters(nadeId, g_LastGrenadeType[client], g_LastGrenadeOrigin[client],
                             g_LastGrenadeVelocity[client]);
  PM_Message(client, "已清除投掷物参数。");
  return Plugin_Handled;
}

static void ClientThrowGrenade(int client, const char[] id, float delay = 0.0) {
  if (!ThrowGrenade(client, id, delay)) {
    PM_Message(
        client,
        "投掷物 %s 的参数未找到。 尝试使用 \".goto %s\" 并扔出投掷物，再使用 \".update\" 后再重试。",
        id, id);
  }
}

public Action Command_Throw(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (!g_CSUtilsLoaded) {
    PM_Message(client, "您需要安装csutils插件以使用此命令。");
    return Plugin_Handled;
  }

  char argString[256];
  GetCmdArgString(argString, sizeof(argString));
  if (args >= 1) {
    char data[128];
    ArrayList ids = new ArrayList(GRENADE_CATEGORY_LENGTH);

    GrenadeMenuType filterType;
    if (StrEqual(argString, "current", false)) {
      filterType = FindGrenades(g_ClientLastMenuData[client], ids, data, sizeof(data));
    } else {
      filterType = FindGrenades(argString, ids, data, sizeof(data));
    }

    // Print what's about to be thrown.
    if (filterType == GrenadeMenuType_OneCategory) {
      PM_Message(client, "投掷分类： %s", data);

    } else {
      char idString[256];
      for (int i = 0; i < ids.Length; i++) {
        char id[GRENADE_ID_LENGTH];
        ids.GetString(i, id, sizeof(id));
        StrCat(idString, sizeof(idString), id);
        if (i + 1 != ids.Length) {
          StrCat(idString, sizeof(idString), ", ");
        }
      }
      if (ids.Length == 1) {
        PM_Message(client, "正在投掷的ID 为 %s", idString);
      } else if (ids.Length > 1) {
        PM_Message(client, "正在投掷的ID 为 %s", idString);
      }
    }

    // Actually do the throwing.
    for (int i = 0; i < ids.Length; i++) {
      char id[GRENADE_ID_LENGTH];
      ids.GetString(i, id, sizeof(id));
      float delay = 0.0;
      // Only support delays when throwing a category.
      if (filterType == GrenadeMenuType_OneCategory) {
        delay = GetClientGrenadeFloat(StringToInt(id), "delay");
      }
      ClientThrowGrenade(client, id, delay);
    }
    if (ids.Length == 0) {
      PM_Message(client, "无投掷物相符 %s", argString);
    }
    delete ids;

  } else {
    // No arg, throw last nade.
    if (IsGrenade(g_LastGrenadeType[client])) {
      PM_Message(client, "重扔出你最后一次投出的投掷物。");
      CSU_ThrowGrenade(client, g_LastGrenadeType[client], g_LastGrenadeOrigin[client],
                       g_LastGrenadeVelocity[client]);
    } else {
      PM_Message(client, "无法重扔，您尚未投掷。");
    }
  }

  return Plugin_Handled;
}

public Action Command_TestFlash(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  g_TestingFlash[client] = true;
  PM_Message(
      client,
      "已保存位置。您可以扔出闪光，接着您会被传送回此以检验闪光效果。");
  PM_Message(client, "当你完成测试时请使用 {GREEN}.stop {NORMAL}");
  GetClientAbsOrigin(client, g_TestingFlashOrigins[client]);
  GetClientEyeAngles(client, g_TestingFlashAngles[client]);
  return Plugin_Handled;
}

public Action Command_StopFlash(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  g_TestingFlash[client] = false;
  PM_Message(client, "已禁用闪光测试。");
  return Plugin_Handled;
}

public Action Command_Categories(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }
  GiveGrenadeMenu(client, GrenadeMenuType_Categories);
  return Plugin_Handled;
}

public Action Command_AddCategory(int client, int args) {
  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0 || !g_InPracticeMode || args < 1) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "此投掷物不属于您。");
    return Plugin_Handled;
  }

  char category[GRENADE_CATEGORY_LENGTH];
  GetCmdArgString(category, sizeof(category));
  AddGrenadeCategory(nadeId, category);

  PM_Message(client, "已添加投掷物分类。");
  return Plugin_Handled;
}

public Action Command_AddCategories(int client, int args) {
  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0 || !g_InPracticeMode || args < 1) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "此投掷物不属于您。");
    return Plugin_Handled;
  }

  char category[GRENADE_CATEGORY_LENGTH];
  for (int i = 1; i <= args; i++) {
    GetCmdArg(i, category, sizeof(category));
    AddGrenadeCategory(nadeId, category);
  }

  PM_Message(client, "已添加投掷物分类。");
  return Plugin_Handled;
}

public Action Command_RemoveCategory(int client, int args) {
  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0 || !g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "此投掷物不属于您。");
    return Plugin_Handled;
  }

  char category[GRENADE_CATEGORY_LENGTH];
  GetCmdArgString(category, sizeof(category));

  if (StrEqual(category, "")) {
    PM_Message(client, "您需要给出一个分类名称！");
    return Plugin_Handled;
  }

  if (RemoveGrenadeCategory(nadeId, category)) {
    PM_Message(client, "已移除投掷物分类。");
  } else {
    PM_Message(client, "分类未找到。");
  }

  return Plugin_Handled;
}

public Action Command_DeleteCategory(int client, int args) {
  char category[GRENADE_CATEGORY_LENGTH];
  GetCmdArgString(category, sizeof(category));

  if (StrEqual(category, "")) {
    PM_Message(client, "您需要给出一个分类名称！");
    return Plugin_Handled;
  }

  if (DeleteGrenadeCategory(client, category) > 0) {
    PM_Message(client, "已移除投掷物分类。");
  } else {
    PM_Message(client, "分类未找到。");
  }
  return Plugin_Handled;
}

public Action Command_ClearGrenadeCategories(int client, int args) {
  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0 || !g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "此投掷物不属于您。");
    return Plugin_Handled;
  }

  SetClientGrenadeData(nadeId, "categories", "");
  PM_Message(client, "已为 ID %d 清除投掷物分类。", nadeId);

  return Plugin_Handled;
}

public Action Command_TranslateGrenades(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (args != 3) {
    ReplyToCommand(client, "用法: sm_translategrenades <dx> <dy> <dz>");
    return Plugin_Handled;
  }

  char buffer[32];
  GetCmdArg(1, buffer, sizeof(buffer));
  float dx = StringToFloat(buffer);

  GetCmdArg(2, buffer, sizeof(buffer));
  float dy = StringToFloat(buffer);

  GetCmdArg(3, buffer, sizeof(buffer));
  float dz = StringToFloat(buffer);

  TranslateGrenades(dx, dy, dz);

  return Plugin_Handled;
}

public Action Command_FixGrenades(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  CorrectGrenadeIds();
  g_UpdatedGrenadeKv = true;
  ReplyToCommand(client, "已修复投掷物数据。");
  return Plugin_Handled;
}
