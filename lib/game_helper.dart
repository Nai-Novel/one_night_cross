part of 'game.dart';

class LifecycleEventHandler extends WidgetsBindingObserver {
  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        if(Platform.isAndroid || Platform.isIOS){
          AudioHelper.resumeAllAudio();
        }
        break;
      case AppLifecycleState.inactive:
        if(Platform.isAndroid || Platform.isIOS){
          AudioHelper.pauseAllAudio();
        }
        break;
      case AppLifecycleState.paused:
        break;
      case AppLifecycleState.detached:
        break;
    }
  }
}

class MyAppCmd{
  static const String USER_RUN_SCRIPT= "USER_RUN_SCRIPT";
  static const String SWITCH_AUTO_READ= "SWITCH_AUTO_READ";
  static const String SWITCH_SKIP_READ= "SWITCH_SKIP_READ";
  static const String SWITCH_SKIP_ALL= "SWITCH_SKIP_ALL";
  static const String OPEN_MENU= "OPEN_MENU";
  static const String OPEN_MENU_CONFIG= "OPEN_CONFIG";
  static const String OPEN_BACK_LOG= "OPEN_BACK_LOG";
  static const String OPEN_SAVE_LOAD= "OPEN_SAVE_LOAD";
  static const String QUICK_SAVE= "QUICK_SAVE";
  static const String QUICK_LOAD= "QUICK_LOAD";
  static const String QUIT_GAME= "QUIT_GAME";
  static const String BACK_TO_TITLE= "BACK_TO_TITLE";
  static const String HIDE_TEXT_BOX= "HIDE_TEXT_BOX";
  static const String POP_UP= "POP_UP";
}

void _doAppCommand(String? command, {bool? switchOn, String popUpText = ""}){
  if(command== null){return;}
  command= command.toUpperCase();
  switch(command){
    case MyAppCmd.BACK_TO_TITLE:
      if(_scriptRunner.isProcessingCommand() || _scriptRunner.isOnTitle()){
        _doAppCommand(MyAppCmd.POP_UP,
            popUpText: GameText.get(GameText.WARNING_GAME_STILL_RUNNING));
      }else{
        AudioHelper.disposeAllAudio().whenComplete(() {
          _scriptRunner.setScript(ScriptItem(ScriptItem.TITLE_SCRIPT_NAME, null), true);
        });
      }
      break;
    case MyAppCmd.POP_UP:
      (_overlayContainerKey.currentState as _OverlayContainerState)
          .popUp(popUpText);
      break;
    case MyAppCmd.OPEN_MENU:
      (_gameMenuKey.currentState as _MenuContainerState).displayMenu();
      break;
    case MyAppCmd.QUICK_SAVE:
      _scriptRunner.userSave(GameSaveType.QUICK);
      break;
    case MyAppCmd.QUICK_LOAD:
      _scriptRunner.loadSaveData(GameSaveType.QUICK);
      break;
    case MyAppCmd.OPEN_MENU_CONFIG:
      (_gameMenuKey.currentState as _MenuContainerState).displayMenu(GameText.MENU_CONFIG);
      break;
    case MyAppCmd.HIDE_TEXT_BOX:
      (_textContainerKey.currentState as _TextContainerState).hideTextBox(true);
      break;
    case MyAppCmd.OPEN_SAVE_LOAD:
      (_gameMenuKey.currentState as _MenuContainerState).displayMenu(GameText.MENU_SAVE_AND_LOAD);
      break;
    case MyAppCmd.OPEN_BACK_LOG:
      (_gameMenuKey.currentState as _MenuContainerState).displayMenu(GameText.MENU_BACK_LOG);
      break;
    case MyAppCmd.USER_RUN_SCRIPT:
      _scriptRunner.userRunScript();
      break;
    case MyAppCmd.SWITCH_AUTO_READ:
      if(switchOn== null){
        _scriptRunner.switchRunFlag(ScriptRunFlag.AUTO);
        return;
      }
      if(switchOn && !_scriptRunner.haveRunFlag(ScriptRunFlag.AUTO)){
        _scriptRunner.switchRunFlag(ScriptRunFlag.AUTO);
        return;
      }
      if(!switchOn && _scriptRunner.haveRunFlag(ScriptRunFlag.AUTO)){
        _scriptRunner.switchRunFlag(ScriptRunFlag.AUTO);
        return;
      }
      break;
    case MyAppCmd.SWITCH_SKIP_ALL:
      if(switchOn== null){
        _scriptRunner.switchRunFlag(ScriptRunFlag.SKIP_ALL);
        return;
      }
      if(switchOn && !_scriptRunner.haveRunFlag(ScriptRunFlag.SKIP_ALL)){
        _scriptRunner.switchRunFlag(ScriptRunFlag.SKIP_ALL);
        return;
      }
      if(!switchOn && _scriptRunner.haveRunFlag(ScriptRunFlag.SKIP_ALL)){
        _scriptRunner.switchRunFlag(ScriptRunFlag.SKIP_ALL);
        return;
      }
      break;
    case MyAppCmd.SWITCH_SKIP_READ:
      if(switchOn== null){
        _scriptRunner.switchRunFlag(ScriptRunFlag.SKIP_READ);
        return;
      }
      if(switchOn && !_scriptRunner.haveRunFlag(ScriptRunFlag.SKIP_READ)){
        _scriptRunner.switchRunFlag(ScriptRunFlag.SKIP_READ);
        return;
      }
      if(!switchOn && _scriptRunner.haveRunFlag(ScriptRunFlag.SKIP_READ)){
        _scriptRunner.switchRunFlag(ScriptRunFlag.SKIP_READ);
        return;
      }
      break;
  }
}