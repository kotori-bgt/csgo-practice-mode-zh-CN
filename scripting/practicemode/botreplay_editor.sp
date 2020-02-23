stock void GiveReplayEditorMenu(int client, int pos = 0) {
  if (StrEqual(g_ReplayId[client], "")) {
    IntToString(GetNextReplayId(), g_ReplayId[client], REPLAY_NAME_LENGTH);
    SetReplayName(g_ReplayId[client], DEFAULT_REPLAY_NAME);
  }

  // Reset role specific data.
  g_CurrentEditingRole[client] = -1;

  Menu menu = new Menu(ReplayMenuHandler);
  char replayName[REPLAY_NAME_LENGTH];
  GetReplayName(g_ReplayId[client], replayName, REPLAY_NAME_LENGTH);
  menu.SetTitle("重放编辑器: %s (ID %s)", replayName, g_ReplayId[client]);

  /* Page 1 */
  for (int i = 0; i < MAX_REPLAY_CLIENTS; i++) {
    bool recordedLastRole = true;
    if (i > 0) {
      recordedLastRole = HasRoleRecorded(g_ReplayId[client], i - 1);
    }
    int style = EnabledIf(recordedLastRole);
    if (HasRoleRecorded(g_ReplayId[client], i)) {
      char roleName[REPLAY_NAME_LENGTH];
      if (GetRoleName(g_ReplayId[client], i, roleName, sizeof(roleName))) {
        AddMenuIntStyle(menu, i, style, "更改玩家 %d 角色 (%s)", i + 1, roleName);
      } else {
        AddMenuIntStyle(menu, i, style, "更改玩家 %d 角色", i + 1);
      }
    } else {
      AddMenuIntStyle(menu, i, style, "添加玩家 %d 角色", i + 1);
    }
  }

  menu.AddItem("replay", "播放重放内容");

  /* Page 2 */
  menu.AddItem("recordall", "一次性录制所有角色玩家");
  menu.AddItem("stop", "停止当前重放");
  menu.AddItem("name", "命名此重放");
  menu.AddItem("copy", "复制此重放至新重放");
  menu.AddItem("delete", "完全删除此重放");

  char display[128];
  Format(display, sizeof(display), "显示重叠式循环计时器: %s",
         g_ReplayPlayRoundTimer[client] ? "yes" : "no");
  menu.AddItem("round_timer", display);

  menu.ExitButton = true;
  menu.ExitBackButton = true;
  menu.DisplayAt(client, pos, MENU_TIME_FOREVER);
}

public int ReplayMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(param2, buffer, sizeof(buffer));

    ServerCommand("sm_botmimic_snapshotinterval 64");

    if (StrEqual(buffer, "replay")) {
      bool already_playing = false;
      for (int i = 1; i <= MaxClients; i++) {
        if (IsValidClient(i) && BotMimic_IsPlayerMimicing(i)) {
          already_playing = true;
          break;
        }
      }
      if (already_playing) {
        PM_Message(client, "等待当前重放首先完成。");
      } else {
        char replayName[REPLAY_NAME_LENGTH];
        GetReplayName(g_ReplayId[client], replayName, sizeof(replayName));
        PM_MessageToAll("开始重放: %s", replayName);
        RunReplay(g_ReplayId[client]);
      }

      GiveReplayEditorMenu(client, GetMenuSelectionPosition());

    } else if (StrEqual(buffer, "stop")) {
      CancelAllReplays();
      if (BotMimic_IsPlayerRecording(client)) {
        BotMimic_StopRecording(client, false /* save */);
        PM_Message(client, "停止录制。");
      }
      GiveReplayEditorMenu(client, GetMenuSelectionPosition());

    } else if (StrEqual(buffer, "delete")) {
      char replayName[REPLAY_NAME_LENGTH];
      GetReplayName(g_ReplayId[client], replayName, REPLAY_NAME_LENGTH);
      GiveDeleteConfirmationMenu(client);

    } else if (StrEqual(buffer, "round_timer")) {
      g_ReplayPlayRoundTimer[client] = !g_ReplayPlayRoundTimer[client];
      GiveReplayEditorMenu(client, GetMenuSelectionPosition());

    } else if (StrEqual(buffer, "copy")) {
      char replayName[REPLAY_NAME_LENGTH];
      GetReplayName(g_ReplayId[client], replayName, REPLAY_NAME_LENGTH);
      PM_Message(client, "已复制重放: %s", replayName);

      char oldReplayId[REPLAY_ID_LENGTH];
      strcopy(oldReplayId, sizeof(oldReplayId), g_ReplayId[client]);
      IntToString(GetNextReplayId(), g_ReplayId[client], REPLAY_NAME_LENGTH);
      CopyReplay(oldReplayId, g_ReplayId[client]);

      char newName[REPLAY_NAME_LENGTH];
      Format(newName, sizeof(newName), "%s的复制版本", replayName);
      SetReplayName(g_ReplayId[client], newName);

      GiveReplayEditorMenu(client, GetMenuSelectionPosition());

    } else if (StrContains(buffer, "name") == 0) {
      PM_Message(client, "使用 .namereplay <名称> 以命名重放。");
      GiveReplayEditorMenu(client, GetMenuSelectionPosition());

    } else if (StrEqual(buffer, "recordall")) {
      int count = 0;
      for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i) && !BotMimic_IsPlayerRecording(i)) {
          count++;
        }
      }
      if (count == 0) {
        PM_Message(client, "在T / CT上没有玩家时，无法录制完整的重放。");
        return 0;
      }
      if (count > MAX_REPLAY_CLIENTS) {
        PM_Message(
            client,
            "无法记录％d个玩家的完整重播。 仅支持％d。 其他玩家应进入观察者那里。",
            count, MAX_REPLAY_CLIENTS);
        return 0;
      }

      if (BotMimic_IsPlayerRecording(client)) {
        PM_Message(client, "您应当首先完成您的录制。");
        GiveReplayEditorMenu(client, GetMenuSelectionPosition());
        return 0;
      }

      if (IsReplayPlaying()) {
        PM_Message(client, "您应当首先完成您的录制。");
        GiveReplayEditorMenu(client, GetMenuSelectionPosition());
        return 0;
      }

      int role = 0;
      for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i) && !BotMimic_IsPlayerRecording(i) && GetClientTeam(i)) {
          g_CurrentEditingRole[i] = role;
          g_ReplayId[i] = g_ReplayId[client];
          StartRecording(i, role, false);
          role++;
        }
      }
      g_RecordingFullReplay = true;
      g_RecordingFullReplayClient = client;
      PM_MessageToAll("开始录制 %d-玩家 重放。", count);
      PM_MessageToAll(
          "当任何玩家按下其检视武器按钮（默认：F键）时，录制将停止。");

    } else {
      // Handling for recording players [0, 4]
      for (int i = 0; i < MAX_REPLAY_CLIENTS; i++) {
        char idxString[16];
        IntToString(i, idxString, sizeof(idxString));
        if (StrEqual(buffer, idxString)) {
          GiveReplayRoleMenu(client, i);
          break;
        }
      }
    }

  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    int client = param1;
    GiveMainReplaysMenu(client);

  } else if (action == MenuAction_End) {
    delete menu;
  }

  return 0;
}

void FinishRecording(int client, bool printOnFail) {
  if (g_RecordingFullReplay) {
    for (int i = 0; i <= MaxClients; i++) {
      if (IsPlayer(i) && BotMimic_IsPlayerRecording(i)) {
        BotMimic_StopRecording(i, true /* save */);
      }
    }

  } else {
    if (BotMimic_IsPlayerRecording(client)) {
      BotMimic_StopRecording(client, true /* save */);
    } else if (printOnFail) {
      PM_Message(client, "您现在不在录制回放。");
    }
  }
}

public Action Command_FinishRecording(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }
  FinishRecording(client, true);
  return Plugin_Handled;
}

public Action Command_LookAtWeapon(int client, const char[] command, int argc) {
  if (g_InPracticeMode && g_InBotReplayMode &&
      GetSetting(client, UserSetting_StopsRecordingInspectKey)) {
    // TODO: also hook the noclip command as a way to finish recording.
    FinishRecording(client, false);
  }
  return Plugin_Continue;
}

public Action Command_Cancel(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  int numReplaying = 0;
  for (int i = 0; i < MAX_REPLAY_CLIENTS; i++) {
    int bot = g_ReplayBotClients[i];
    if (IsValidClient(bot) && BotMimic_IsPlayerMimicing(bot)) {
      numReplaying++;
    }
  }

  if (g_RecordingFullReplay) {
    for (int i = 1; i <= MaxClients; i++) {
      if (IsPlayer(i) && BotMimic_IsPlayerRecording(i)) {
        BotMimic_StopRecording(client, false /* save */);
      }
    }

  } else if (BotMimic_IsPlayerRecording(client)) {
    BotMimic_StopRecording(client, false /* save */);

  } else if (numReplaying > 0) {
    CancelAllReplays();
    PM_MessageToAll("取消所有回放。");
  }

  return Plugin_Handled;
}

stock void GiveReplayRoleMenu(int client, int role, int pos = 0) {
  Menu menu = new Menu(ReplayRoleMenuHandler);
  g_CurrentEditingRole[client] = role;

  char replayName[REPLAY_NAME_LENGTH];
  GetReplayName(g_ReplayId[client], replayName, sizeof(replayName));

  char roleName[REPLAY_NAME_LENGTH];
  GetRoleName(g_ReplayId[client], role, roleName, sizeof(roleName));

  if (StrEqual(roleName, "")) {
    menu.SetTitle("%s: 角色 %d", replayName, role + 1, roleName);
  } else {
    menu.SetTitle("%s: 角色 %d (%s)", replayName, role + 1, roleName);
  }

  menu.ExitButton = true;
  menu.ExitBackButton = true;

  bool recorded = HasRoleRecorded(g_ReplayId[client], role);
  if (recorded) {
    menu.AddItem("record", "重录角色");
  } else {
    menu.AddItem("record", "录制角色");
  }

  menu.AddItem("spawn", "传送至重生点", EnabledIf(recorded));
  menu.AddItem("play", "播放此重放", EnabledIf(recorded));
  menu.AddItem("name", "命名这个角色", EnabledIf(recorded));
  menu.AddItem("nades", "检视投掷物组合", EnabledIf(recorded));
  menu.AddItem("delete", "删除录制", EnabledIf(recorded));

  menu.DisplayAt(client, MENU_TIME_FOREVER, pos);
}

public int ReplayRoleMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    int role = g_CurrentEditingRole[client];
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(param2, buffer, sizeof(buffer));

    if (StrEqual(buffer, "record")) {
      if (BotMimic_IsPlayerRecording(client)) {
        PM_Message(client, "您应当首先完成您的录制。");
        GiveReplayRoleMenu(client, role, GetMenuSelectionPosition());
        return 0;
      }
      if (IsReplayPlaying()) {
        PM_Message(client, "您应当首先完成您的重放。");
        GiveReplayRoleMenu(client, role, GetMenuSelectionPosition());
        return 0;
      }
      StartRecording(client, role);
      RunReplay(g_ReplayId[client], role);

    } else if (StrEqual(buffer, "spawn")) {
      GotoReplayStart(client, g_ReplayId[client], role);
      GiveReplayRoleMenu(client, role, GetMenuSelectionPosition());

    } else if (StrEqual(buffer, "play")) {
      if (IsReplayPlaying()) {
        PM_Message(client, "您应当首先完成您的重放。");
        GiveMainReplaysMenu(client);
        return 0;
      }

      int bot = g_ReplayBotClients[role];
      if (IsValidClient(bot) && HasRoleRecorded(g_ReplayId[client], role)) {
        ReplayRole(g_ReplayId[client], bot, role);
      }
      GiveReplayRoleMenu(client, role, GetMenuSelectionPosition());

    } else if (StrEqual(buffer, "name")) {
      PM_Message(client, "使用 .namerole <名称> 以命名此角色。");
      GiveReplayRoleMenu(client, role, GetMenuSelectionPosition());

    } else if (StrEqual(buffer, "nades")) {
      if (g_NadeReplayData[client].Length == 0) {
        PM_Message(client, "此角色没有保存任何投掷物。");
        GiveReplayRoleMenu(client, role, GetMenuSelectionPosition());
      } else {
        GiveReplayRoleNadesMenu(client);
      }

    } else if (StrEqual(buffer, "delete")) {
      DeleteReplayRole(g_ReplayId[client], role);
      PM_Message(client, "删除角色 %d.", role + 1);
      GiveReplayEditorMenu(client);
    }

  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    int client = param1;
    GiveReplayEditorMenu(client);

  } else if (action == MenuAction_End) {
    delete menu;
  }

  return 0;
}

stock void GiveReplayRoleNadesMenu(int client, int pos = 0) {
  Menu menu = new Menu(ReplayRoleNadesMenuHandler);
  menu.SetTitle("角色 %d 的投掷物", g_CurrentEditingRole[client] + 1);
  menu.ExitButton = true;
  menu.ExitBackButton = true;

  GetRoleNades(g_ReplayId[client], g_CurrentEditingRole[client], client);
  for (int i = 0; i < g_NadeReplayData[client].Length; i++) {
    GrenadeType type;
    float delay;
    float personOrigin[3];
    float personAngles[3];
    float grenadeOrigin[3];
    float grenadeVelocity[3];
    GetReplayNade(client, i, type, delay, personOrigin, personAngles, grenadeOrigin,
                  grenadeVelocity);

    char displayString[128];
    GrenadeTypeString(type, displayString, sizeof(displayString));
    AddMenuInt(menu, i, displayString);
  }

  menu.DisplayAt(client, MENU_TIME_FOREVER, pos);
}

public int ReplayRoleNadesMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    int nadeIndex = GetMenuInt(menu, param2);

    GrenadeType type;
    float delay;
    float personOrigin[3];
    float personAngles[3];
    float grenadeOrigin[3];
    float grenadeVelocity[3];
    GetReplayNade(client, nadeIndex, type, delay, personOrigin, personAngles, grenadeOrigin,
                  grenadeVelocity);

    TeleportEntity(client, personOrigin, personAngles, NULL_VECTOR);

    // TODO: de-dupliate with TeleportToSavedGrenadePosition.
    if (type != GrenadeType_None && GetSetting(client, UserSetting_SwitchToNadeOnSelect)) {
      char weaponName[64];
      GetGrenadeWeapon(type, weaponName, sizeof(weaponName));
      FakeClientCommand(client, "use %s", weaponName);
      GiveReplayRoleNadesMenu(client, GetMenuSelectionPosition());
    }

  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    int client = param1;
    GiveReplayRoleMenu(client, g_CurrentEditingRole[client]);

  } else if (action == MenuAction_End) {
    delete menu;
  }

  return 0;
}

public void GiveDeleteConfirmationMenu(int client) {
  char replayName[REPLAY_NAME_LENGTH];
  GetReplayName(g_ReplayId[client], replayName, sizeof(replayName));

  Menu menu = new Menu(DeletionMenuHandler);
  menu.SetTitle("确定删除: %s", replayName);
  menu.ExitButton = false;
  menu.ExitBackButton = false;
  menu.Pagination = MENU_NO_PAGINATION;

  // Add rows of padding to move selection out of "danger zone"
  for (int i = 0; i < 7; i++) {
    menu.AddItem("", "", ITEMDRAW_NOTEXT);
  }

  // Add actual choices
  menu.AddItem("no", "不，请保留它。");
  menu.AddItem("yes", "是的，删除它。");
  menu.Display(client, MENU_TIME_FOREVER);
}

public int DeletionMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(param2, buffer, sizeof(buffer));

    if (StrEqual(buffer, "yes")) {
      char replayName[REPLAY_NAME_LENGTH];
      GetReplayName(g_ReplayId[client], replayName, sizeof(replayName));
      DeleteReplay(g_ReplayId[client]);
      PM_MessageToAll("已删除重放: %s", replayName);
      GiveMainReplaysMenu(client);
    } else {
      GiveReplayEditorMenu(client);
    }

  } else if (action == MenuAction_End) {
    delete menu;
  }

  return 0;
}

stock void StartRecording(int client, int role, bool printCommands = true) {
  if (role < 0 || role >= MAX_REPLAY_CLIENTS) {
    return;
  }

  g_NadeReplayData[client].Clear();
  g_CurrentEditingRole[client] = role;
  g_CurrentRecordingStartTime[client] = GetGameTime();

  char recordName[128];
  Format(recordName, sizeof(recordName), "玩家 %d 角色", role + 1);
  char roleString[32];
  Format(roleString, sizeof(roleString), "role%d", role);
  BotMimic_StartRecording(client, recordName, "practicemode", roleString);

  if (g_ReplayPlayRoundTimer[client]) {
    // Effectively a .countdown command, but already started (g_RunningLiveTimeCommand=true).
    float timer_duration = float(GetRoundTimeSeconds());
    g_RunningTimeCommand[client] = true;
    g_RunningLiveTimeCommand[client] = true;
    g_TimerType[client] = TimerType_Countdown_Movement;
    g_TimerDuration[client] = timer_duration;
    StartClientTimer(client);
  }

  if (printCommands) {
    PM_Message(client, "已开始录制玩家 %d 角色.", role + 1);

    if (GetSetting(client, UserSetting_StopsRecordingInspectKey)) {
      PM_Message(client,
                 "输入 .finish、您的武器检视按键（默认F键）或.noclip 以停止录制。");
    } else {
      PM_Message(client, "输入 .finish、您的武器检视按键（默认F键）或.noclip 以停止录制。");
    }
  }
}

public Action BotMimic_OnStopRecording(int client, char[] name, char[] category, char[] subdir,
                                char[] path, bool& save) {
  if (g_ReplayPlayRoundTimer[client]) {
    StopClientTimer(client);
  }

  if (g_CurrentEditingRole[client] >= 0) {
    if (!save) {
      // We only handle the not-saving case here because BotMimic_OnRecordSaved below
      // is handling the saving case.
      PM_Message(client, "已取消录制玩家角色 %d", g_CurrentEditingRole[client] + 1);
      GiveReplayMenuInContext(client);
    }
  }

  return Plugin_Continue;
}

public void BotMimic_OnRecordSaved(int client, char[] name, char[] category, char[] subdir, char[] file) {
  if (g_CurrentEditingRole[client] >= 0) {
    SetRoleFile(g_ReplayId[client], g_CurrentEditingRole[client], file);
    SetRoleNades(g_ReplayId[client], g_CurrentEditingRole[client], client);
    SetRoleTeam(g_ReplayId[client], g_CurrentEditingRole[client], GetClientTeam(client));

    if (!g_RecordingFullReplay) {
      PM_Message(client, "已结束录制玩家角色 %d", g_CurrentEditingRole[client] + 1);
      GiveReplayMenuInContext(client);
    } else {
      if (g_RecordingFullReplayClient == client) {
        g_CurrentEditingRole[client] = -1;
        PM_MessageToAll("已结束录制该重放。");
        RequestFrame(ResetFullReplayRecording, GetClientSerial(client));
      }
    }

    MaybeWriteNewReplayData();
  }
}

public void ResetFullReplayRecording(int serial) {
  g_RecordingFullReplay = false;
  g_RecordingFullReplayClient = -1;
  int client = GetClientFromSerial(serial);
  if (IsPlayer(client)) {
    GiveReplayMenuInContext(client);
  }
}
