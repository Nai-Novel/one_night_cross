import 'dart:collection';
import 'dart:io';
import 'package:flutter/scheduler.dart';
import 'audio_helper.dart';
import 'storage_helper.dart';
import 'text_processor.dart';
import 'dart:ui' as ui;

import 'com_cons.dart';

class ScriptRunner {
  //List all script was run. Use for label goback, create backlog, save data
  List<ScriptItem>? _scriptList;
  ScriptItem? _currentScript;
  int _executionCount= 0;
  int _continueExecutionCount= 0;
  int _runFlag = ScriptRunFlag.STOP;
  late Function(ScriptCommandInfo) _commandPreparedCallBack;
  Function(int, int)? _flagSwitchedCallBack;
  List<String> Function()? _didReadySaveCallBack;
  HashMap<String, List<String>> _listInfiniteCommand = HashMap<String, List<String>>();
  bool _isNeedToPause= false;
  int _isReadyToSave= -1;
  SavesInfo? _currentSave;

  bool isProcessingCommand(){
    return _executionCount> _continueExecutionCount;
  }

  ScriptRunner(Function(ScriptCommandInfo) callBack) {
    _commandPreparedCallBack = callBack;
    _currentSave= SavesInfo.loadCurrentData();
  }

  void dispose(){
    _continueExecutionCount = 0;
    _infinityExecutionCount = 0;
    _runFlag = ScriptRunFlag.STOP;
    _isNeedToPause = false;
    _infinityExecutionLine= -1;
    _insideInfinityLoopCount= 0;
    _insideInfinityStartLoopLine= -1;
    _scriptList= null;
    _flagSwitchedCallBack= null;
    _didReadySaveCallBack= null;
    _listInfiniteCommand.clear();
    _currentSave= null;
    _currentScript= null;
  }

  bool isOnTitle(){
    return _currentScript!= null
      && (_currentScript!.name== ScriptItem.TITLE_SCRIPT_NAME
            || _currentScript!.name== ScriptItem.SPLASH_SCRIPT_NAME);
  }

  //Return 1 instead of 0 is to trigger listener of animation to run
  int parseAnimationTime(String? timeString){
    if(timeString== null || timeString.length== 0
        || haveRunFlag(ScriptRunFlag.SKIP_MAX)
        || haveRunFlag(ScriptRunFlag.SKIP_READ)){
      return 1;
    }
    int? ret= int.tryParse(timeString);
    return ret== null ? 1 : ret;
  }

  void setOnReadySaveCallBack(List<String> Function() callBack){
    _didReadySaveCallBack = callBack;
  }

  void setSwitchFlagCallBack(Function(int, int) callBack){
    _flagSwitchedCallBack = callBack;
  }

  bool isNoSkipFlag(){
    return _runFlag< ScriptRunFlag.SKIP_READ;
  }

  void saveVariable(ScriptCommandInfo commandInfo){
    _currentSave!.saveVariable(commandInfo);
  }

  ScriptCommandInfo checkVariable(ScriptCommandInfo commandInfo){
    return _currentSave!.checkVariable(commandInfo) ? commandInfo : commandInfo.removeNextCommand();
  }

  String getLocalParameter(String param){
    return _currentSave!.getLocalParameter(param);
  }

  void clearRunFlag(){
    final int oldFlag= _runFlag;
    _runFlag &= 0x00000000;
    timeDilation= 1;
    _flagSwitchedCallBack!(oldFlag, _runFlag);
  }

  void switchRunFlag(int flag){
    final int oldFlag= _runFlag;
    if(flag== ScriptRunFlag.TO_NEXT){
      if(haveRunFlag(ScriptRunFlag.TO_NEXT)){
        _runFlag -= ScriptRunFlag.TO_NEXT;
      }else{
        _runFlag |= ScriptRunFlag.TO_NEXT;
      }
    }else if(flag== ScriptRunFlag.AUTO){
      if(haveRunFlag(ScriptRunFlag.AUTO)){
        _runFlag -= ScriptRunFlag.AUTO;
      }else{
        _runFlag |= ScriptRunFlag.AUTO;
        if(_executionCount== _continueExecutionCount
            && !AudioHelper.isVoicePlaying()){
          _runScript();
        }
      }
    }else if(flag== ScriptRunFlag.SKIP_READ){
      if(haveRunFlag(ScriptRunFlag.SKIP_READ)){
        _runFlag -= ScriptRunFlag.SKIP_READ;
      }else{
        _runFlag |= ScriptRunFlag.SKIP_READ;
        if(_executionCount== _continueExecutionCount){ // && _currentScript.line< lastSaveLine
          _runScript();
        }
      }
    }else if(flag== ScriptRunFlag.SKIP_ALL){
      if(haveRunFlag(ScriptRunFlag.SKIP_ALL)){
        _runFlag -= ScriptRunFlag.SKIP_ALL;
      }else{
        _runFlag |= ScriptRunFlag.SKIP_ALL;
        if(_executionCount== _continueExecutionCount){
          _runScript();
        }
      }
    }else if(flag== ScriptRunFlag.SKIP_MAX){
      if(haveRunFlag(ScriptRunFlag.SKIP_MAX)){
        _runFlag -= ScriptRunFlag.SKIP_MAX;
      }else{
        _runFlag |= ScriptRunFlag.SKIP_MAX;
        if(_executionCount== _continueExecutionCount){
          if(_currentScript!.line< _currentSave!.currentScriptLine){
            _runScript();
          }
        }
      }
    }
    if(haveRunFlag(ScriptRunFlag.SKIP_ALL)
        || haveRunFlag(ScriptRunFlag.SKIP_READ)
        || haveRunFlag(ScriptRunFlag.TO_NEXT)
    ){
      timeDilation= 0.1;
    }else if(haveRunFlag(ScriptRunFlag.SKIP_MAX)){
      timeDilation= 0.001;
    }else{
      timeDilation= 1;
    }
    if(_flagSwitchedCallBack!= null){
      _flagSwitchedCallBack!(oldFlag, _runFlag);
    }
  }

  bool haveRunFlag(int flag){
    return _runFlag & flag == flag;
  }

  bool wasRead(){
    if(_currentScript== null){return false;}
    return AlreadyReadHelper.wasRead(_currentScript!.name, _currentScript!.line);
  }

  void setScript(ScriptItem _scriptItem, [bool isRenew= false]) {
    if(isRenew && _currentSave!= null){
      _currentSave!.refresh();
      _scriptList = <ScriptItem>[];
    }
    if (_scriptList == null) {
      _scriptList = <ScriptItem>[];
    }
    if(_currentScript!= null && !_currentScript!.isFake){
      _scriptList!.add(_currentScript!.copy(isWake: false));
    }

    _currentScript = _scriptItem;
    if(_scriptItem.isFake){
      _runScript();
    }else{
      _currentScript!.wake();
      _isReadyToSave= GameSingleSaveType.SCRIPT_CHANGE;
      _makeSave();
      _runScript();
    }
  }

  void goBackOnce(){
    _currentSave!.goBackOnce();
    loadCurrentSave();
  }

  void goBackFromBackLog(BackLogItem backLogItem){
    _currentSave!.goBackFromBackLog(backLogItem);
    loadCurrentSave();
  }

  void _resetCache(){
    _continueExecutionCount = 0;
    _infinityExecutionCount = 0;
    _executionCount = _continueExecutionCount;
    _runFlag = ScriptRunFlag.STOP;
    _isNeedToPause = false;
    _isReadyToSave = SavesInfo.STEP_FOR_TEMP_SAVE;
    _listInfiniteCommand = HashMap<String, List<String>>();
    _infinityExecutionLine= -1;
    _insideInfinityLoopCount= 0;
    _insideInfinityStartLoopLine= -1;
  }

  void loadSaveData(int type, [int slot= -1]){
    if(!SavesInfo.haveData(type, slot)){return;}
    _resetCache();
    if(_currentSave== null){
      SavesInfo.loadData(type, slot).then((result) {
        _currentSave= result;
        loadCurrentSave();
      });
    }else{
      _currentSave!.delete().whenComplete(() {
        SavesInfo.loadData(type, slot).then((result) {
          _currentSave= result;
          loadCurrentSave();
        });
      });
    }
  }

  void loadCurrentSave(){
    _resetCache();
    AudioHelper.disposeAllAudio().whenComplete(() {
      _scriptList= ScriptItem.parseFromSave(_currentSave!.saveArray[_currentSave!.saveArray.length- 1].scriptsStack);
      List<String> toLoadScriptLine= <String>[];
      toLoadScriptLine.add(ScriptCommand.CHOICE_HEADER
          + ScriptCommandInfo.buildCommandParam(ScriptCommand.COMMON_ACTION, ScriptCommand.CHOICE_ACTION_CLEAR));
      toLoadScriptLine.add(ScriptCommand.LAYER_HEADER
          + ScriptCommandInfo.buildCommandParam(ScriptCommand.COMMON_ACTION, ScriptCommand.LAYER_ACTION_CLEAR));
      toLoadScriptLine.add(ScriptCommand.LAYER_HEADER
          + ScriptCommandInfo.buildCommandParam(ScriptCommand.COMMON_NAME, ContainerKeyName.FILTER)
          + ScriptCommandInfo.buildCommandParam(ScriptCommand.COMMON_ACTION, ScriptCommand.ANIMATION_ACTION_NAME)
          + ScriptCommandInfo.buildCommandParam(ScriptCommand.ANIMATION_TYPE, ScriptCommand.ANIMATION_TYPE_FILTER)
          + ScriptCommandInfo.buildCommandParam(ScriptCommand.ANIMATION_TYPE_FILTER_COLOR, ""));

      toLoadScriptLine.add("");

      toLoadScriptLine.addAll(_currentSave!.saveArray[_currentSave!.saveArray.length- 1].saveScriptContent);

      toLoadScriptLine.add("");
      toLoadScriptLine.add(ScriptCommand.LABEL_HEADER
          + ScriptCommandInfo.buildCommandParam(ScriptCommand.COMMON_ACTION,
              ScriptCommand.LABEL_ACTION_GO_BACK));
      toLoadScriptLine.add(ScriptCommand.TEXT_HEADER);
      toLoadScriptLine.add("");
      _currentScript = ScriptItem.fake(toLoadScriptLine);

      if(!haveRunFlag(ScriptRunFlag.SKIP_MAX)){
        switchRunFlag(ScriptRunFlag.SKIP_MAX);
      }
    });
  }

  List<BackLogItem> buildBackLog(){
    List<BackLogItem> ret= <BackLogItem>[];
    if(_currentSave== null || _currentScript== null){return ret;}
    int backStep= 0;
    List<String> linesToBuild= <String>[];
    ScriptItem? scriptItem;
    late ScriptItem lastScriptItem;
    bool isFirst= true;

    while(_currentSave!.saveArray.length- backStep> 0 && ret.length< SavesInfo.MAX_BACK_LOG_LINE){
      if(isFirst){//First time
        SingleSaveInfo singleSaveInfo= _currentSave!.saveArray[_currentSave!.saveArray.length- 1];
        lastScriptItem= ScriptItem.parseFromSave(singleSaveInfo.scriptsStack).last;
        for(int i= lastScriptItem.line; i< _currentScript!.line; i++){
          linesToBuild.add(_currentScript!._scriptLines[i]);
        }
        ret.addAll(_buildBackLogBlock(backStep, linesToBuild));
        linesToBuild.clear();
        isFirst= false;
      }else{
        ScriptItem tempScriptItem= ScriptItem.parseFromSave(
            _currentSave!.saveArray[_currentSave!.saveArray.length- 1- backStep].scriptsStack).last;
        if(scriptItem!= null && tempScriptItem.name== scriptItem.name){
          scriptItem.changeTo(tempScriptItem.startLine, tempScriptItem.line);
        }else{
          scriptItem= tempScriptItem..wake();
        }
        if(scriptItem== lastScriptItem){
          for(int i= scriptItem.line; i< lastScriptItem.line; i++){
            linesToBuild.add(scriptItem.scriptLines[i]);
          }
        }else{
          linesToBuild.add(scriptItem.scriptLines[scriptItem.line]);
        }
        ret.insertAll(0, _buildBackLogBlock(backStep, linesToBuild));
        lastScriptItem= scriptItem.copy(isWake: false);
        linesToBuild.clear();
      }
      backStep++;
    }
    //for(BackLogItem buildLine in ret){
    //  print(buildLine.toString());
    //}
    return ret;
  }
  List<BackLogItem> _buildBackLogBlock(int backStep, List<String> aPartOfScriptContent){
    List<BackLogItem> ret= <BackLogItem>[];
    BackLogItem anItem= BackLogItem(backStep);
    bool endOneBlock= false;
    int lastSoundLine= -1;

    for(int i= 0; i<= aPartOfScriptContent.length; i++){
      if(i== aPartOfScriptContent.length){
        if(!anItem.isEmpty()){
          ret.add(anItem..setDeltaLine(i- 1));
        }
        break;
      }
      if((aPartOfScriptContent[i].length== 0) && endOneBlock){
        if(!anItem.isEmpty()){
          ret.add(anItem..setDeltaLine(i));
        }
        anItem= BackLogItem(backStep);
        endOneBlock= false;
        lastSoundLine= -1;
        continue;
      }
      ScriptCommandInfo commandInfo = ScriptCommandInfo(aPartOfScriptContent[i]);
      if(commandInfo.header== ScriptCommand.TEXT_HEADER && !commandInfo.containKey(ScriptCommand.COMMON_ACTION)){
        if(commandInfo.containKey(ScriptCommand.TEXT_CHARACTER_NAME)){
          anItem.setCharName(commandInfo.valueOf(ScriptCommand.TEXT_CHARACTER_NAME)!);
        }
        if(commandInfo.containKey(UserConfig.get(UserConfig.GAME_MAIN_LANGUAGE))){
          anItem.addText(commandInfo.valueOf(UserConfig.get(UserConfig.GAME_MAIN_LANGUAGE))!);
        }
        if(commandInfo.containKey(UserConfig.get(UserConfig.GAME_SUB_LANGUAGE))){
          anItem.addSubText(commandInfo.valueOf(UserConfig.get(UserConfig.GAME_SUB_LANGUAGE)));
        }
        if(!commandInfo.containKey(ScriptCommand.TEXT_IS_CONCAT)){
          endOneBlock= true;
        }
        continue;
      }
      if(commandInfo.header== ScriptCommand.SOUND_HEADER
          && commandInfo.valueOf(ScriptCommand.SOUND_TYPE)== ScriptCommand.SOUND_TYPE_VOICE){
        if(lastSoundLine< 0){
          anItem.addVoice(commandInfo.valueOf(ScriptCommand.SOUND_PATH)!);
        }else{
          if(i- lastSoundLine== 1){
            anItem.addSyncVoice(commandInfo.valueOf(ScriptCommand.SOUND_PATH)!);
          }else{
            anItem.addVoice(commandInfo.valueOf(ScriptCommand.SOUND_PATH)!);
          }
        }
        lastSoundLine= i;
        continue;
      }
      if(ScriptCommand.CHOICE_HEADER== commandInfo.header
          && commandInfo.containKey(ScriptCommand.CHOICE_END)){
        anItem.setType(GameSingleSaveType.CHOICE);
        anItem.addText(GameText.BACK_LOG_CHOICE);
        endOneBlock= true;
        continue;
      }
    }
    return ret;
  }

  void userRunScript(){
    if(haveRunFlag(ScriptRunFlag.SKIP_READ)){
      switchRunFlag(ScriptRunFlag.SKIP_READ);
      return;
    }else if(haveRunFlag(ScriptRunFlag.SKIP_ALL)){
      switchRunFlag(ScriptRunFlag.SKIP_ALL);
      return;
    }else if(haveRunFlag(ScriptRunFlag.SKIP_MAX)){
      return;
    }else if(haveRunFlag(ScriptRunFlag.TO_NEXT)){
      return;
    }else if(haveRunFlag(ScriptRunFlag.AUTO)){
      if(AudioHelper.isVoicePlaying()){
        AudioHelper.stopVoice();
      }
      if(!UserConfig.getBool(UserConfig.IS_KEEP_AUTO_MODE)){
        switchRunFlag(ScriptRunFlag.AUTO);
      }
    }
    if(_executionCount> _continueExecutionCount){
      switchRunFlag(ScriptRunFlag.TO_NEXT);
    }else{
      _runScript();
    }
  }

  Future<void> userSave(int saveType, [String text= "", int slot= -1, ui.Image? thumbImage]) async {
    if(!isAllowSave()){return;}
    await _currentSave!.userSave(saveType, slot, text, thumbImage, _currentScript!.loopCount> 0 ? _currentScript!.startLoopLine- 1 : _currentScript!.line);
  }

  bool isAllowSave(){
    return _currentScript!= null && !_currentScript!.isFake;
  }

  void triggerSave(int singleSaveType){
    _isReadyToSave= singleSaveType;
  }
  void _makeSave([String note=""]){
    if(_didReadySaveCallBack== null
        || _currentSave== null
        || _currentScript== null
        || _scriptList== null
        || _currentScript!.isFake
        || (_isReadyToSave!= GameSingleSaveType.SCRIPT_CHANGE && _currentScript!.line<= _currentSave!.currentScriptLine)
    ){return;}
    String scriptStack= "";
    for(ScriptItem scriptItem in _scriptList!){
      scriptStack+= scriptItem.getSaveString()
          + ScriptCommandInfo.LINE_COMMAND_SEPARATOR;
    }
    scriptStack+= _currentScript!.getSaveString();

    List<String> gotScriptContent= _didReadySaveCallBack!();
    if(gotScriptContent.length== 0){return;}

    List<String> saveScriptContent= <String>[];
    saveScriptContent.addAll(gotScriptContent);
    for(var oneListCommand in _listInfiniteCommand.entries){
      for(String oneCommand in oneListCommand.value){
        saveScriptContent.add(oneCommand);
      }
    }

    _currentSave!.put(SingleSaveInfo.all(_isReadyToSave, note, scriptStack, saveScriptContent),
        _currentScript!.loopCount> 0 ? _currentScript!.startLoopLine- 1 : _currentScript!.line);
    _isReadyToSave= SavesInfo.STEP_FOR_TEMP_SAVE;
  }

  int _handleSingleCommand(ScriptCommandInfo commandInfo){
    if (commandInfo.header== ScriptCommand.TEXT_HEADER){
      if(!commandInfo.containKey(ScriptCommand.TEXT_DO_NOT_STOP)
          && !commandInfo.containKey(ScriptCommand.COMMON_ACTION)){
        _isNeedToPause= true;
        if(!commandInfo.containKey(ScriptCommand.TEXT_IS_CONCAT)
            && commandInfo.containKey(UserConfig.get(UserConfig.GAME_MAIN_LANGUAGE))
            && _currentScript!.loopCount<= 0){
          _isReadyToSave++;
        }
      }
    } else if (commandInfo.header== ScriptCommand.IMAGE_HEADER){
      if(commandInfo.containKey(ScriptCommand.VIDEO_HEADER)
          && !commandInfo.containKey(ScriptCommand.ANIMATION_TYPE_VIDEO_START_FRAME)
          && !commandInfo.containKey(ScriptCommand.ANIMATION_TYPE_VIDEO_END_FRAME)){
        //pause if video just play, it is not for animation
        _isNeedToPause= true;
      }

    } else if (ScriptCommand.CHOICE_HEADER== commandInfo.header
        && commandInfo.containKey(ScriptCommand.CHOICE_END)){
      _isNeedToPause= true;
    }
    if(commandInfo.containKey(ScriptCommand.COMMON_COMMAND_CONTINUE)){
      _continueExecutionCount++;
      _isNeedToPause= false;
    }
    return 1;
  }

  void _runScript() async {
    if(_executionCount> _continueExecutionCount || _currentScript== null){
      return;
    }
    if(_isReadyToSave>= 0){
      _makeSave();
    }
    _isNeedToPause= false;
    String? infiniteLoopName;
    List<ScriptCommandInfo> scriptBlock = <ScriptCommandInfo>[];

    //Read all line in script, add to a block of commands until empty line
    //then process them async
    for (int i = _currentScript!.line; i < _currentScript!.scriptLines.length; i++) {
      _currentScript!.line = i;
      AlreadyReadHelper.read(_currentScript!.name, i);
      String currentLineInCurrentScript = _currentScript!.scriptLines[i].trim();
      print("qqqq10: $currentLineInCurrentScript");
      if (currentLineInCurrentScript.length > 0) {
        if (currentLineInCurrentScript.trimLeft().startsWith(ScriptCommand.COMMON_COMMEND)) {
          continue;
        }
        ScriptCommandInfo commandInfo = ScriptCommandInfo(currentLineInCurrentScript);

        if(infiniteLoopName!= null){
          _listInfiniteCommand[infiniteLoopName]!.add(currentLineInCurrentScript);
          if (commandInfo.header== ScriptCommand.LOOP_END
              && commandInfo.valueOf(ScriptCommand.COMMON_NAME)== infiniteLoopName){
            _currentScript!.loopCount= 0;
            _runInfinityLoop(infiniteLoopName);
            infiniteLoopName= null;
          }
          continue;
        }
        if (commandInfo.header== ScriptCommand.LOOP_START) {
          if(commandInfo.containKey(ScriptCommand.LOOP_TIME)){
            _currentScript!.loopCount = int.tryParse(commandInfo.valueOf(ScriptCommand.LOOP_TIME)!)!- 1;
          }else {
            _currentScript!.loopCount = -1; //Infinity loop
          }
          if(_currentScript!.loopCount< 0){
            if(!commandInfo.containKey(ScriptCommand.COMMON_NAME)){
              throw(ErrorString.INFINITE_LOOP_NEED_NAME);
            }
            infiniteLoopName= commandInfo.valueOf(ScriptCommand.COMMON_NAME)!;
            List<String> newInfinityList= <String>[];
            newInfinityList.add(currentLineInCurrentScript);
            _listInfiniteCommand.putIfAbsent(infiniteLoopName, () => newInfinityList);
            _infinityExecutionLine = 0;
          }else{
            _currentScript!.startLoopLine= i + 1;
          }
          continue;
        }
        if (commandInfo.header== ScriptCommand.LOOP_END){
          if (_currentScript!.loopCount < 0) {

          }else if(_currentScript!.loopCount > 0){
            _currentScript!.loopCount--;
            _currentScript!.line= _currentScript!.startLoopLine;
          }else{
            _currentScript!.startLoopLine= -1;
            _currentScript!.line = i + 1;
          }
          break;
        }
        if (commandInfo.header== ScriptCommand.LOOP_STOP){
          if(!commandInfo.containKey(ScriptCommand.COMMON_NAME)){
            throw(ErrorString.INFINITE_LOOP_NEED_NAME);
          }
          _listInfiniteCommand.remove(commandInfo.valueOf(ScriptCommand.COMMON_NAME));
          continue;
        }
        int handleSingleCommandResult= _handleSingleCommand(commandInfo);
        if(handleSingleCommandResult== -1){
          return;
        }else if(handleSingleCommandResult== 0){
          continue;
        }else if(handleSingleCommandResult== 1){
          scriptBlock.add(commandInfo);
        }
      } else {
        if (_currentScript!.loopCount >= 0) {
          _currentScript!.line = i + 1;
          break;
        }
      }
    }

    if(scriptBlock.length== 0){
      if(_currentScript!.line< _currentScript!.scriptLines.length- 1){
        _runScript();
      }else{
        return;
      }
    }else{
      _executionCount+= scriptBlock.length;
      for (ScriptCommandInfo commandInfo in scriptBlock) {
        _commandPreparedCallBack(commandInfo);
      }
    }
  }

  int _infinityExecutionLine= -1;
  int _infinityExecutionCount= 0;
  int _insideInfinityLoopCount= 0;
  int _insideInfinityStartLoopLine= -1;
  void _runInfinityLoop(String loopName){
    List<String>? listCommand= _listInfiniteCommand[loopName];
    List<String> scriptBlock= <String>[];
    if(listCommand!= null && _infinityExecutionLine>= 0){
      for (int i = _infinityExecutionLine; i < listCommand.length; i++) {
        String currentLine = listCommand[i].trim();
        ScriptCommandInfo commandInfo= ScriptCommandInfo(currentLine, loopName);

        if (currentLine.length > 0){
          if (commandInfo.header== ScriptCommand.LOOP_START){
            if(commandInfo.containKey(ScriptCommand.LOOP_TIME)){
              _insideInfinityLoopCount = int.parse(commandInfo.valueOf(ScriptCommand.LOOP_TIME)!)- 1;
              _insideInfinityStartLoopLine= i+ 1;
            }
            continue;
          }
          if (commandInfo.header== ScriptCommand.LOOP_END){
            if(_insideInfinityLoopCount> 0){
              _infinityExecutionLine= _insideInfinityStartLoopLine;
              _insideInfinityLoopCount--;
            }else{
              if(_insideInfinityStartLoopLine>= 0){
                _insideInfinityStartLoopLine= -1;
                _infinityExecutionLine= i+1;
              }else{
                _infinityExecutionLine = 0;
              }
            }
            break;
          }

          scriptBlock.add(currentLine);
        }else{
          _infinityExecutionLine= i + 1;
          break;
        }
      }

      if(scriptBlock.length== 0){
        _runInfinityLoop(loopName);
      }else{
        _infinityExecutionCount+= scriptBlock.length;
        for (String scriptLine in scriptBlock) {
          _commandPreparedCallBack(ScriptCommandInfo(scriptLine, loopName));
        }
      }
    }else{
      _infinityExecutionLine= -1;
    }
  }

  void completeCommand(ScriptCommandInfo commandInfo, isCountForExecution) async {
    //When user quit game but command is still being processed
    if(_currentSave== null || _currentScript== null || _scriptList== null){return;}
    if (commandInfo.containKey(ScriptCommand.COMMON_WAIT)) {
      //Delay after process
      if(timeDilation>= 1){
        await Future.delayed(Duration(
            milliseconds: (commandInfo.valueIntOf(ScriptCommand.COMMON_WAIT)! * timeDilation).toInt()));
      }
    }

    if(commandInfo.buildNextCommand()){
      int handleSingleCommandResult= _handleSingleCommand(commandInfo);
      if(handleSingleCommandResult== -1){
        if(isCountForExecution && commandInfo.isCompleted()) {
          _executionCount--;
        }
        return;
      }else if(handleSingleCommandResult== 0){

      }else if(handleSingleCommandResult== 1){
        commandInfo.increaseCountdownComplete();
        _commandPreparedCallBack(commandInfo);
      }
    }else{
      if(!commandInfo.isCompleted()){
        commandInfo._countdownToComplete--;
        return;
      }
      if(commandInfo.infinityExecutionName!= null){
        _infinityExecutionCount--;
        if(_infinityExecutionCount< 0){
          throw("_infinityExecutionCount< 0");
        }
        if(_infinityExecutionCount== 0){
          _runInfinityLoop(commandInfo.infinityExecutionName!);
        }
        return;
      }
      if(isCountForExecution) {
        _executionCount--;
      }
      if(commandInfo.containKey(ScriptCommand.COMMON_COMMAND_CONTINUE)){
        _continueExecutionCount--;
      }

      if (commandInfo.header== ScriptCommand.LABEL_HEADER
          && commandInfo.containKey(ScriptCommand.COMMON_ACTION)) {
        String? labelAction= commandInfo.valueOf(ScriptCommand.COMMON_ACTION);
        if (ScriptCommand.LABEL_ACTION_JUMP== labelAction) {
          String? newScriptName= commandInfo.valueOf(ScriptCommand.LABEL_ACTION_JUMP_TO_FILE);
          setScript(ScriptItem(newScriptName== null ? _currentScript!.name : newScriptName,
              commandInfo.valueOf(ScriptCommand.LABEL_NAME)), commandInfo.containKey(ScriptCommand.LABEL_ACTION_JUMP_CLEAR_SAVE));
        }
        if (ScriptCommand.LABEL_ACTION_GO_BACK== labelAction) {
          bool lastScriptIsFake= _currentScript!.isFake;
          while(_currentScript== _scriptList!.last && _currentScript!.line== _scriptList!.last.line){
            _scriptList!.removeLast();
          }
          _currentScript= _scriptList!.removeLast()..wake();
          if(!lastScriptIsFake){
            _isReadyToSave= GameSingleSaveType.SCRIPT_CHANGE;
            _makeSave();
          }
        }
        _isNeedToPause= false;
      }

      if(_executionCount< _continueExecutionCount){
        throw(ErrorString.EXECUTION_COUNT_IS_NEGATIVE + _executionCount.toString());
      }else if(_executionCount== _continueExecutionCount){
        if(haveRunFlag(ScriptRunFlag.TO_NEXT)){
          switchRunFlag(ScriptRunFlag.TO_NEXT);
        }
        if(haveRunFlag(ScriptRunFlag.SKIP_ALL)){
          _runScript();
          return;
        }
        if(haveRunFlag(ScriptRunFlag.SKIP_MAX)){
          //if(_currentScript!.isFake || _currentScript!.line< _currentSave!.currentScriptLine){
          //  _runScript();
          //}else{
          //  switchRunFlag(ScriptRunFlag.SKIP_MAX);
          //}
          switchRunFlag(ScriptRunFlag.SKIP_MAX);
          _runScript();
          return;
        }
        if(haveRunFlag(ScriptRunFlag.AUTO)){
          if(_isNeedToPause){
            if(AudioHelper.isVoicePlaying()){
              if(UserConfig.getBool(UserConfig.IS_WAIT_VOICE_END_AUTO_MODE)){
                return;
              }else{
                if(UserConfig.getDouble(UserConfig.AUTO_END_WAIT_TIME)> 0){
                  final autoLine= _currentScript!.line;
                  Future.delayed(Duration(
                      milliseconds: (UserConfig.getDouble(UserConfig.AUTO_END_WAIT_TIME) * timeDilation).toInt())).whenComplete(() {
                    if(_currentScript!= null && autoLine== _currentScript!.line){_runScript();}
                  });
                  return;
                }
              }
            }else {
              if(UserConfig.getDouble(UserConfig.AUTO_END_WAIT_TIME)> 0){
                final autoLine= _currentScript!.line;
                Future.delayed(Duration(
                    milliseconds: (UserConfig.getDouble(UserConfig.AUTO_END_WAIT_TIME) * timeDilation).toInt())).whenComplete(() {
                  if(_currentScript!= null && autoLine== _currentScript!.line){_runScript();}
                });
                return;
              }
            }
          }
          _runScript();
          return;
        }
        if(haveRunFlag(ScriptRunFlag.SKIP_READ)){
          if(wasRead() || !_isNeedToPause){
            _runScript();
          }
          return;
        }
        if(_isNeedToPause){
        } else {
          _runScript();
          return;
        }
      }
    }
  }

}

class BackLogItem{
  static const String SYNC_VOICE_SEPARATOR= ";";

  late int _saveType;
  late int _saveBackStep;
  late int _deltaLine;
  String? _characterName;
  CharacterOfText? _characterOfText;
  late String _mainText;
  String _subText= "";
  List<String>? _listVoiceCommand;

  BackLogItem(int saveBackStep){
    _saveType= GameSingleSaveType.TEMP;
    _saveBackStep= saveBackStep;
    _mainText= "";
  }

  bool isEmpty(){
    return _mainText.length==0 && _subText.length== 0;
  }

  void setType(int saveType){
    _saveType= saveType;
  }

  void setCharName(String name){
    _characterName= name;
    if(_characterName!.length> 0){
      _characterOfText= CharacterOfText.get(_characterName!);
    }
  }

  void setDeltaLine(int delta){
    _deltaLine= delta;
  }

  void addText(String toAppendText){
    if (_mainText.length== 0 && _characterOfText!= null){
      _mainText+= _characterOfText!.getDisplayName(
          UserConfig.get(UserConfig.GAME_MAIN_LANGUAGE));
    }
    _mainText+= toAppendText;
  }

  void addSubText(String? toAppendText){
    if(toAppendText== null){return;}
    if (_subText.length== 0 && _characterOfText!= null){
      _subText = _subText + _characterOfText!.getDisplayName(
          UserConfig.get(UserConfig.GAME_SUB_LANGUAGE));
    }
    _subText= _subText + toAppendText;
  }

  void addSyncVoice(String voicePath){
    _listVoiceCommand!.last+= SYNC_VOICE_SEPARATOR+ voicePath;
  }

  void addVoice(String voicePath){
    if(_listVoiceCommand== null){
      _listVoiceCommand= <String>[];
    }
    _listVoiceCommand!.add(voicePath);
  }

  @override
  String toString() {
    return 'BackLogItem{_saveBackStep: $_saveBackStep, _deltaLine: $_deltaLine, _characterName: $_characterName, _text: $_mainText, _listVoiceCommand: $_listVoiceCommand}';
  }

  List<String>? get listVoiceCommand => _listVoiceCommand;
  String get combineText {
    String ret= "";
    if(UserConfig.getBool(UserConfig.IS_ACTIVE_MAIN_LANGUAGE)){
      if(UserConfig.getBool(UserConfig.IS_ACTIVE_SUB_LANGUAGE)){
        String lineBreak= TextProcessor.START_TAG_STRING
            + TextProcessor.REPLACE_LINE_BREAK
            + TextProcessor.END_TAG_STRING;
        ret+= _mainText + lineBreak + _subText;
      }else{
        ret= _mainText;
      }
    }else{
      ret= _subText;
    }
    return ret;
  }
  int get deltaLine => _deltaLine;
  int get saveBackStep => _saveBackStep;
  int get saveType => _saveType;
}

class ScriptCommand {
  static const String COMMON_COMMEND = "//";
  static const String COMMON_NAME = "name";
  static const String COMMON_ACTION = "action";
  static const String COMMON_DELAY = "delay";
  static const String COMMON_WAIT = "wait";
  static const String COMMON_COMMAND_CONTINUE = "continue";

  static const String APP_COMMAND_HEADER = "cmd";

  static const String CHOICE_HEADER = "choice";
  static const String CHOICE_LAYOUT = "layout";
  static const String CHOICE_ACTION_CLEAR = "clear";
  static const String CHOICE_DISABLE_USER_CHOICE = "disable";
  static const String CHOICE_FREEZE = "freeze";
  static const String CHOICE_END = "end";

  static const String SET_HEADER = "set";
  static const String SET_VARIABLE_NAME = "var";
  static const String SET_VALUE = "value";

  static const String CHECK_HEADER = "check";
  static const String CHECK_EXPRESSION = "exp";

  static const String SAVE_HEADER = "save";
  static const String SAVE_STRING = "note";

  static const String TO_SAVE_SCRIPT_HEADER = "savescript";
  static const String TO_SAVE_SCRIPT_NAME = "name";
  static const String TO_SAVE_SCRIPT_START_LINE = "startline";
  static const String TO_SAVE_SCRIPT_CURRENT_LINE = "currentline";
  static const String TO_SAVE_SCRIPT_LOOP_COUNT = "loopcount";
  static const String TO_SAVE_SCRIPT_LOOP_START_LINE = "loopstartline";

  static const String LABEL_HEADER = "label";
  static const String LABEL_NAME = "name";
  static const String LABEL_ACTION_CREATE = "new";
  static const String LABEL_ACTION_JUMP = "jump";
  static const String LABEL_ACTION_JUMP_CLEAR_SAVE = "clear save";
  static const String LABEL_ACTION_JUMP_TO_FILE = "file";
  static const String LABEL_ACTION_GO_BACK = "go back";

  static const String WAIT_HEADER = "wait";
  static const String WAIT_SE = "se";
  static const String WAIT_VOICE = "voice";
  static const String WAIT_TIME = "time";

  static const String LOOP_START = "loop";
  static const String LOOP_TIME = "time";
  static const String LOOP_END = "endloop";
  static const String LOOP_STOP = "stoploop";

  static const String SOUND_HEADER = "sound";
  static const String SOUND_PATH = "path";
  static const String SOUND_TYPE = "type";
  static const String SOUND_TYPE_VOICE = "voice";
  static const String SOUND_TYPE_VOICE_STACK = "stack";
  static const String SOUND_TYPE_BG = "back";
  static const String SOUND_TYPE_BG_FADE_OUT_TIME = "fadeout";
  static const String SOUND_TYPE_BG_FADE_IN_TIME = "fadein";
  static const String SOUND_TYPE_SOUND_EFFECT = "se";

  static const String IMAGE_HEADER = "img";
  static const String IMAGE_ACTION_CREATE = "new";
  static const String IMAGE_ACTION_MOD = "mod";
  static const String IMAGE_ACTION_REMOVE = "remove";
  static const String IMAGE_ACTION_DELETE_CACHE = "del cache";
  static const String IMAGE_ACTION_SWAP = "swap";
  static const String IMAGE_ACTION_SWAP_NAME1 = "name1";
  static const String IMAGE_ACTION_SWAP_NAME2 = "name2";
  static const String IMAGE_INDEX_FIRST = "first";
  static const String IMAGE_INDEX_BELOW = "below";
  static const String IMAGE_INDEX_ABOVE = "above";
  static const String IMAGE_LAYER = "layer";
  static const String IMAGE_PATH = "path";
  static const String IMAGE_ALPHA = "alpha";
  static const String IMAGE_NEW_NAME = "newname";
  static const String IMAGE_MASK_TARGET = "target";
  static const String IMAGE_POSITION_TOP = "top";
  static const String IMAGE_POSITION_BOTTOM = "bottom";
  static const String IMAGE_POSITION_LEFT = "left";
  static const String IMAGE_POSITION_RIGHT = "right";
  static const String IMAGE_SIZE_WIDTH = "width";
  static const String IMAGE_SIZE_HEIGHT = "height";
  static const String IMAGE_ROTATE_Z = "rotate";
  static const String IMAGE_ROTATE_Y = "yrotate";
  static const String IMAGE_ROTATE_X = "xrotate";
  static const String IMAGE_X_OFFSET = "xoffset";
  static const String IMAGE_Y_OFFSET = "yoffset";
  static const String IMAGE_COLOR = "color";
  static const String IMAGE_COLOR_BLEND_MODE = "blend";
  static const String IMAGE_TYPE = "type";
  static const String IMAGE_TYPE_NONE = "none";
  static const String IMAGE_TYPE_BACKGROUND = "back";
  static const String IMAGE_TYPE_MULTIPLE_LANGUAGE = "lang";
  static const String IMAGE_TYPE_SPRITE = "char";
  static const String IMAGE_TYPE_SPRITE_BODY = "body";
  static const String IMAGE_TYPE_SPRITE_EMOTION = "emo";
  static const String IMAGE_TYPE_SPRITE_LIP = "lip";
  static const String IMAGE_TYPE_SPRITE_HAIR = "hair";
  static const String IMAGE_TYPE_CACHE = "cache";
  static const String IMAGE_TYPE_VIDEO = "video";
  static const String IMAGE_TYPE_EFFECT = "eff";
  static const String IMAGE_TYPE_SEQUENCE = "seq";

  static const String LAYER_HEADER = "layer";
  static const String LAYER_ACTION_CLEAR = "clear";
  static const String LAYER_ACTION_CAPTURE = "capture";
  static const String LAYER_ACTION_CAPTURE_IMAGE_NAME = "cache name";

  static const String ANIMATION_ACTION_NAME = "animate";
  static const String ANIMATION_TIME = "time";
  static const String ANIMATION_TYPE = "type";
  static const String ANIMATION_TYPE_FADE = "fade";
  static const String ANIMATION_TYPE_SIZE = "size";
  static const String ANIMATION_TYPE_POSITION = "move";
  static const String ANIMATION_TYPE_VIDEO = "video";
  static const String ANIMATION_TYPE_VIDEO_ACTION = "do";
  static const String ANIMATION_TYPE_VIDEO_ACTION_STOP = "stop";
  static const String ANIMATION_TYPE_VIDEO_START_FRAME = "begin";
  static const String ANIMATION_TYPE_VIDEO_END_FRAME = "end";
  static const String ANIMATION_CUBIC = "cubic";
  static const String ANIMATION_CURVE = "curve";
  static const String ANIMATION_TYPE_ROTATE = "rotate";
  static const String ANIMATION_TYPE_FILTER = "filter";
  static const String ANIMATION_TYPE_FILTER_COLOR = "color";
  static const String ANIMATION_TYPE_FILTER_BLEND_MODE = "blend";
  static const String ANIMATION_TYPE_GRADIENT = "gradient";
  static const String ANIMATION_TYPE_GRADIENT_SHADER = "shader";
  static const String ANIMATION_TYPE_GRADIENT_PARAMETER = "param";
  static const String ANIMATION_TYPE_SHOW_MASK = "mask show";
  static const String ANIMATION_TYPE_HIDE_MASK = "mask hide";
  static const String ANIMATION_TYPE_MASK_IMAGE_PATH = "path";
  static const String ANIMATION_TYPE_BLUR = "blur";
  static const String ANIMATION_TYPE_BLUR_SIGMA_X = "sigmax";
  static const String ANIMATION_TYPE_BLUR_SIGMA_Y = "sigmay";

  static const String VIDEO_HEADER = "video";
  static const String VIDEO_LAYER = "layer";
  static const String VIDEO_PATH = "path";
  static const String VIDEO_ACTION_CREATE = "new";
  static const String VIDEO_ACTION_PLAY = "play";
  static const String VIDEO_ACTION_REMOVE = "remove";

  static const String TEXT_HEADER = "txt";
  static const String TEXT_JP_KANA = "kana";
  static const String TEXT_CHARACTER_NAME = "name";
  static const String TEXT_CHARACTER_AVATAR = "ava";
  static const String TEXT_CHARACTER_AVATAR_EMOTION = "emo";
  static const String TEXT_BACKGROUND_IMAGE = "back";
  static const String TEXT_IS_CONCAT = "concat";
  static const String TEXT_DO_NOT_STOP = "next";
  static const String TEXT_OPACITY = "alpha";
  static const String TEXT_MODE = "mode";
  static const String TEXT_MODE_ADV = "avd";
  static const String TEXT_MODE_NOVEL = "novel";
  static const String TEXT_MODE_CHAT = "chat";
  static const String TEXT_MODE_BUBBLE = "bubble";
}

class ScriptRunFlag {
  static const int STOP = 0;
  static const int TO_NEXT = 1;
  static const int AUTO = 2;
  static const int SKIP_READ = 4;
  static const int SKIP_ALL = 8;
  static const int SKIP_MAX = 16;
}

class ScriptItem{
  static const String ENCODING = "utf-8";
  static const String FILE_EXTENSION = ".txt";
  static const String FAKE_SCRIPT_NAME_PREFIX= "_";
  static const String SPLASH_SCRIPT_NAME= FAKE_SCRIPT_NAME_PREFIX+ "splash";
  static const String TITLE_SCRIPT_NAME= FAKE_SCRIPT_NAME_PREFIX+ "title";
  static const String MAIN_SCRIPT_NAME= "main_menu_test";

  late String _name;
  int line= 0;
  int _startLine= 0;
  List<String> _scriptLines= <String>[];
  HashMap<String, int>? _scriptLabelList;
  bool _isFake= false;
  int loopCount= 0;
  int startLoopLine= -1;

  String getSaveString(){
    return ScriptCommand.TO_SAVE_SCRIPT_HEADER
    + ScriptCommandInfo.buildCommandParam(ScriptCommand.TO_SAVE_SCRIPT_NAME, _name)
    + ScriptCommandInfo.buildCommandParam(ScriptCommand.TO_SAVE_SCRIPT_START_LINE, _startLine.toString())
    + ScriptCommandInfo.buildCommandParam(ScriptCommand.TO_SAVE_SCRIPT_CURRENT_LINE, line.toString())
    + ScriptCommandInfo.buildCommandParam(ScriptCommand.TO_SAVE_SCRIPT_LOOP_COUNT, loopCount.toString())
    + ScriptCommandInfo.buildCommandParam(ScriptCommand.TO_SAVE_SCRIPT_LOOP_START_LINE, startLoopLine.toString());
  }

  static List<ScriptItem> parseFromSave(String scriptsStack){
    List<ScriptItem> ret= <ScriptItem>[];
    ScriptCommandInfo scriptCommandInfo = ScriptCommandInfo(scriptsStack);
    do{
      if(scriptCommandInfo.header== ScriptCommand.TO_SAVE_SCRIPT_HEADER){
        ret.add(ScriptItem.base(scriptCommandInfo.valueOf(ScriptCommand.TO_SAVE_SCRIPT_NAME)!,
            scriptCommandInfo.valueIntOf(ScriptCommand.TO_SAVE_SCRIPT_START_LINE)!,
            scriptCommandInfo.valueIntOf(ScriptCommand.TO_SAVE_SCRIPT_CURRENT_LINE)!,
          scriptCommandInfo.valueIntOf(ScriptCommand.TO_SAVE_SCRIPT_LOOP_COUNT)!,
          scriptCommandInfo.valueIntOf(ScriptCommand.TO_SAVE_SCRIPT_LOOP_START_LINE)!,));
      }
    }while(scriptCommandInfo.buildNextCommand());

    return ret;
  }

  static List<String> loadScriptContent(String name) {
    File scriptFile= File(CommonFunc.buildPath(
        [UserConfig.get(UserConfig.GAME_ASSETS_FOLDER),
          AssetConstant.SCRIPT_DIR,
          name+ ScriptItem.FILE_EXTENSION]));
    if(scriptFile.existsSync()){
      return scriptFile.readAsLinesSync();
    }
    return <String>[];
  }

  void idle(){
    _scriptLines.clear();
  }

  void wake(){
    if(_scriptLines.length== 0){
      _scriptLines = loadScriptContent(_name);
    }
    if(_scriptLabelList== null){
      _scriptLabelList = HashMap<String, int>();
      for (int i = 0; i < _scriptLines.length; i++) {
        if (_scriptLines[i].trimLeft().startsWith(ScriptCommand.LABEL_HEADER)) {
          ScriptCommandInfo scriptCommandInfo = ScriptCommandInfo(_scriptLines[i]);
          String? action= scriptCommandInfo.valueOf(ScriptCommand.COMMON_ACTION);
          if (null== action || action== ScriptCommand.LABEL_ACTION_CREATE) {
            _scriptLabelList!.putIfAbsent(
                scriptCommandInfo.valueOf(ScriptCommand.COMMON_NAME)!, () => i);
          }
        }
      }
    }
  }

  void changeTo(int startLine, int _line){
    _startLine= startLine;
    line= _line;
  }

  ScriptItem copy({int? startLine, int? currentLine, bool isWake= true, int? lLoopCount, int? lStartLoopLine}){
    ScriptItem ret= ScriptItem.base(_name,
        startLine== null ? _startLine : startLine, currentLine== null ? line : currentLine,
        lLoopCount== null ? loopCount : lLoopCount, lStartLoopLine== null ? startLoopLine : lStartLoopLine);
    ret._isFake= _isFake;
    if(isWake){
      if(_scriptLines.length== 0){
        ret.wake();
      }else{
        ret._scriptLines= _scriptLines;
        ret._scriptLabelList= _scriptLabelList;
      }
    }

    return ret;
  }

  ScriptItem.base(String name, int startLine, int currentLine, int _loopCount, int _startLoopLine){
    _name = name;
    _startLine = startLine;
    line = currentLine;
    loopCount = _loopCount;
    startLoopLine = _startLoopLine;
  }

  ScriptItem.fake(List<String> scriptLines, [startLine= 0, currentLine= 0]){
    _name= FAKE_SCRIPT_NAME_PREFIX;
    _scriptLines = scriptLines;
    _startLine = startLine;
    line = currentLine;
    _isFake= true;
  }

  ScriptItem(String name, String? labelName) {
    _name = name;
    if(_name.startsWith(FAKE_SCRIPT_NAME_PREFIX)){
      _isFake= true;
    }
    wake();
    //Get label list in script file
    if (labelName != null) {
      for (var scriptLabelListEntry in _scriptLabelList!.entries) {
        if (scriptLabelListEntry.key == labelName) {
          _startLine = line = scriptLabelListEntry.value;
          break;
        }
      }
    } else {
      _startLine = line = 0;
    }
  }


  @override
  bool operator ==(Object other) {
    if(other is ScriptItem){
      ScriptItem toCompare= other;
      return _name== toCompare.name && _startLine== toCompare.startLine;
    }
    return false;
  }

  String get name => _name;
  int get startLine => _startLine;
  List<String> get scriptLines => _scriptLines;
  bool get isFake => _isFake;

  @override
  int get hashCode => super.hashCode;

  @override
  String toString() {
    return 'ScriptItem{_name: $_name, line: $line, _startLine: $_startLine, _isFake: $_isFake, loopCount: $loopCount, startLoopLine: $startLoopLine}';
  }
}

class ScriptCommandInfo {
  static const String LINE_COMMAND_SEPARATOR = " -> ";
  static const String PARAM_COMMAND_SEPARATOR = ";";
  static const String PARAM_VALUE_COMMAND_SEPARATOR = "=";
  static const String PARAM_IN_VALUE_COMMAND_SEPARATOR = ",";

  late String _command;
  String? _nextCommand;
  late String _header;
  late HashMap<String, String> _listCommandParam;
  String? _infinityExecutionName;
  int _countdownToComplete= 1;

  void increaseCountdownComplete(){
    _countdownToComplete++;
  }

  bool isCompleted(){
    return _countdownToComplete== 0;
  }

  void complete(){_countdownToComplete--;}

  ScriptCommandInfo(String commandLine,[String? infinityExecutionName]) {
    buildCommandInfo(commandLine);
    _infinityExecutionName= infinityExecutionName;
  }

  String get nextCommand {
    return _nextCommand == null ? "" : _nextCommand!;
  }

  void buildCommandInfo(String commandLine){
    int commandLineSeparatorIndex = commandLine.indexOf(LINE_COMMAND_SEPARATOR);
    if(commandLineSeparatorIndex> 0){
      _command = commandLine.substring(0, commandLineSeparatorIndex);
      _nextCommand = commandLine.substring(
          commandLineSeparatorIndex + LINE_COMMAND_SEPARATOR.length);
    }else{
      _command = commandLine;
      _nextCommand = null;
    }

    _listCommandParam = HashMap<String, String>();
    List<String> paramArray = _command.split(PARAM_COMMAND_SEPARATOR);
    _header = paramArray[0].trim();
    for (int i = 1; i < paramArray.length; i++) {
      int separatorIndex= paramArray[i].indexOf(PARAM_VALUE_COMMAND_SEPARATOR);
      String paramKey= separatorIndex< 0 ? paramArray[i] : paramArray[i].substring(0, separatorIndex);
      String paramValue= separatorIndex< 0 ? "" : paramArray[i].substring(separatorIndex+ 1);
      if(_header== ScriptCommand.TEXT_HEADER){
        _listCommandParam.putIfAbsent(
            paramKey.trim().toLowerCase(), () => paramValue);
      }else{
        _listCommandParam.putIfAbsent(
            paramKey.trim().toLowerCase(), () => paramValue.trim());
      }
    }
  }

  bool buildNextCommand(){ //If this command has next, build command in tail
    if(_nextCommand== null){
      return false;
    }
    buildCommandInfo(_nextCommand!);
    return true;
  }

  bool containKey(String key) {
    return _listCommandParam.containsKey(key);
  }

  String? valueOf(String key) {
    if (!containKey(key)) {
      return null;
    }
    return _listCommandParam[key];
  }

  int? valueIntOf(String key){
    if (!containKey(key)) {
      return null;
    }
    return int.tryParse(_listCommandParam[key]!);
  }

  double? valueDoubleOf(String key){
    if (!containKey(key)) {
      return null;
    }
    return double.tryParse(_listCommandParam[key]!);
  }

  String get header => _header;
  String? get infinityExecutionName => _infinityExecutionName;

  @override
  String toString() {
    if(_nextCommand== null){
      return _command;
    }
    return _command + LINE_COMMAND_SEPARATOR + _nextCommand!;
  }

  ScriptCommandInfo removeNextCommand(){
    _nextCommand= null;
    return this;
  }

  static String buildCommandParam(String paramName, String? paramValue){
    String ret= PARAM_COMMAND_SEPARATOR + paramName;
    if(paramValue!= null){
      ret+= PARAM_VALUE_COMMAND_SEPARATOR + paramValue;
    }
    return ret;
  }
  static String buildIntCommandParam(String paramName, int? paramValue){
    return buildCommandParam(paramName, paramValue== null ? "" : paramValue.toString());
  }
  static String buildDoubleCommandParam(String paramName, double? paramValue){
    return buildCommandParam(paramName, paramValue== null ? "" : paramValue.toString());
  }
}
