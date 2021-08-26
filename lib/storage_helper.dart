import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'package:expressions/expressions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/services.dart';
import 'com_cons.dart';
import 'script_runner.dart';
import 'text_processor.dart';
import 'package:path_provider/path_provider.dart' as PathProvider;
import 'package:path/path.dart' as Path;
import 'dart:ui' as ui;

part 'storage_helper.g.dart';

class StorageHelper{
  static const String APP_SAVE_DIR = "save";
  static const String SAVE_FILE_EXTENSION = ".txt";

  static late final String GAME_SAVE_THUMB_DIR;
  static const String GAME_IMAGE_CACHE_EXTENSION = ".png";

  static late final List<Directory> APP_DIRECTORY_ON_DEVICE;
  static late final String APP_SAVE_DIR_FULL_PATH;

  static Future<void> init() async {
    List<Directory>? externalStorageDirectories = await PathProvider.getExternalStorageDirectories();
    if(externalStorageDirectories== null){
      throw("ExternalStorageDirectories was null!");
    }
    APP_DIRECTORY_ON_DEVICE= externalStorageDirectories;
    APP_SAVE_DIR_FULL_PATH= CommonFunc.buildPath([APP_DIRECTORY_ON_DEVICE[0].path, APP_SAVE_DIR]);
    Hive.init(APP_SAVE_DIR_FULL_PATH);
    Hive.registerAdapter(SavesInfoAdapter());
    Hive.registerAdapter(SingleSaveInfoAdapter());

    GAME_SAVE_THUMB_DIR = CommonFunc.buildPath([APP_DIRECTORY_ON_DEVICE[0].path, "save_thumb/"]);
    if(!Directory(GAME_SAVE_THUMB_DIR).existsSync()){
      Directory(GAME_SAVE_THUMB_DIR).create(recursive: true);
    }

    await Hive.openBox<String>(UserConfig.TABLE_USER_CONFIG);
    UserConfig._init();
    await Hive.openBox<String>(GlobalVariable.TABLE_NAME);
    if(UserConfig.get(UserConfig.GAME_ASSETS_FOLDER).length== 0 && APP_DIRECTORY_ON_DEVICE.length== 1){
      UserConfig.save(UserConfig.GAME_ASSETS_FOLDER, APP_DIRECTORY_ON_DEVICE[0].path);
    }
    GameText.loadByLanguage(UserConfig.getBool(UserConfig.IS_ACTIVE_MAIN_LANGUAGE)
        ? UserConfig.get(UserConfig.GAME_MAIN_LANGUAGE) : UserConfig.get(UserConfig.GAME_SUB_LANGUAGE));
    GameText.loadMenuByLanguage(UserConfig.get(UserConfig.MENU_LANGUAGE));
    await Hive.openBox<SavesInfo>(SavesInfo.TABLE_SAVE_TEMP);
    AlreadyReadHelper.init();

    await AssetConstant.initAssetsPath();
  }
}

class GlobalVariable{
  static const String TABLE_NAME = "global_variable";

  static void save(String propertyName, String? value){
    if(null== value){
      Hive.box<String>(TABLE_NAME).delete(propertyName).whenComplete(() {
        Hive.box<String>(TABLE_NAME).compact();
      });
    }else{
      Hive.box<String>(TABLE_NAME).put(propertyName, value).whenComplete(() {
        Hive.box<String>(TABLE_NAME).compact();
      });
    }
  }

  static String? get(String propertyName){
    return Hive.box<String>(TABLE_NAME).get(propertyName);
  }

  static Map<dynamic, String> allDataToMap(){
    return Hive.box<String>(TABLE_NAME).toMap();
  }
}

class UserConfig{
  static const String TABLE_USER_CONFIG = "user_config";

  static const String GAME_ASSETS_FOLDER = "GAME_ASSETS_FOLDER";
  static const String MENU_ALIGNMENT = "MENU_ALIGNMENT";
  static const String TEXT_BOX_BACKGROUND_OPACITY = "TEXT_BOX_BACKGROUND_OPACITY";
  static const String GAME_VOLUME_MASTER = "GAME_VOLUME_MASTER";
  static const String GAME_VOLUME_BG = "GAME_VOLUME_BG";
  static const String GAME_VOLUME_SE = "GAME_VOLUME_SE";
  static const String GAME_VOLUME_VOICE_COMMON = "GAME_VOLUME_VOICE_COMMON";
  static const String MENU_LANGUAGE = "MENU_LANGUAGE";
  static const String IS_ACTIVE_MAIN_LANGUAGE = "IS_ACTIVE_JP_LANGUAGE";
  static const String IS_ACTIVE_SUB_LANGUAGE = "IS_ACTIVE_SUB_LANGUAGE";
  static const String GAME_MAIN_LANGUAGE = "GAME_MAIN_LANGUAGE";
  static const String GAME_SUB_LANGUAGE = "GAME_SUB_LANGUAGE";
  static const String ONE_CHARACTER_DISPLAY_TIME = "ONE_CHARACTER_DISPLAY_TIME";
  static const String TEXT_SIZE = "TEXT_SIZE";
  static const String TEXT_USER_FONT = "TEXT_USER_FONT";
  static const String AUTO_END_WAIT_TIME = "AUTO_END_WAIT_TIME";
  static const String LAST_SAVE_LOAD_MENU_PAGE = "LAST_SAVE_LOAD_MENU_PAGE";
  static const String LAST_SAVE_LOAD_MENU_SCROLL_POSITION = "LAST_SAVE_LOAD_MENU_SCROLL_POSITION";
  static const String LAST_CONFIG_TAB_INDEX = "LAST_CONFIG_TAB_INDEX";
  static const String IS_WAIT_VOICE_END_AUTO_MODE = "IS_WAIT_VOICE_END_AUTO_MODE";
  static const String IS_KEEP_AUTO_MODE = "IS_KEEP_AUTO_MODE";
  static const String ENABLE_LIP_SYNC = "ENABLE_LIP_SYNC";

  static void _init() async {
    Box<String> userConfigBox= Hive.box<String>(TABLE_USER_CONFIG);
    if(userConfigBox.isNotEmpty){return;}
    await userConfigBox.put(GAME_ASSETS_FOLDER, "");
    await userConfigBox.put(MENU_ALIGNMENT, Alignment.topLeft.toString());
    await userConfigBox.put(TEXT_BOX_BACKGROUND_OPACITY, (1).toString());
    await userConfigBox.put(GAME_VOLUME_MASTER, (1).toString());
    await userConfigBox.put(GAME_VOLUME_BG, (0.4).toString());
    await userConfigBox.put(GAME_VOLUME_SE, (1).toString());
    await userConfigBox.put(GAME_VOLUME_VOICE_COMMON, (1).toString());
    await userConfigBox.put(MENU_LANGUAGE, Language.VIETNAMESE);
    await userConfigBox.put(IS_ACTIVE_MAIN_LANGUAGE, (0).toString());
    await userConfigBox.put(IS_ACTIVE_SUB_LANGUAGE, (1).toString());
    await userConfigBox.put(GAME_MAIN_LANGUAGE, Language.JAPANESE);
    await userConfigBox.put(GAME_SUB_LANGUAGE, Language.VIETNAMESE);
    await userConfigBox.put(ONE_CHARACTER_DISPLAY_TIME, (45).toString());
    await userConfigBox.put(TEXT_SIZE, (20).toString());
    await userConfigBox.put(TEXT_USER_FONT, "");
    await userConfigBox.put(AUTO_END_WAIT_TIME, (1500).toString());
    await userConfigBox.put(LAST_SAVE_LOAD_MENU_PAGE, (0).toString());
    await userConfigBox.put(LAST_SAVE_LOAD_MENU_SCROLL_POSITION, (0).toString());
    await userConfigBox.put(LAST_CONFIG_TAB_INDEX, (0).toString());
    await userConfigBox.put(IS_WAIT_VOICE_END_AUTO_MODE, (1).toString());
    await userConfigBox.put(ENABLE_LIP_SYNC, (1).toString());
    await userConfigBox.put(IS_KEEP_AUTO_MODE, (0).toString());
  }

  static Map<dynamic, String> allDataToMap(){
    return Hive.box<String>(TABLE_USER_CONFIG).toMap();
  }

  static void save(String propertyName, String value){
    Hive.box<String>(TABLE_USER_CONFIG).put(propertyName, value).whenComplete(() {
      Hive.box<String>(TABLE_USER_CONFIG).compact();
    });
  }

  static String get(String propertyName){
    String? ret= Hive.box<String>(TABLE_USER_CONFIG).get(propertyName);
    return ret== null ? "" : ret;
  }

  static Alignment getAlign(String propertyName){
    return CommonFunc.parseAlign(get(propertyName));
  }

  static void saveDouble(String propertyName, double? value){
    Hive.box<String>(TABLE_USER_CONFIG).put(propertyName, value== null ? "" : value.toString()).whenComplete(() {
      Hive.box<String>(TABLE_USER_CONFIG).compact();
    });
  }
  static double getDouble(String propertyName){
    String value= get(propertyName);
    return value.length== 0 ? 0 : double.tryParse(value)!;
  }

  static void saveInt(String propertyName, int? value){
    Hive.box<String>(TABLE_USER_CONFIG).put(propertyName, value== null ? "" : value.toString()).whenComplete(() {
      Hive.box<String>(TABLE_USER_CONFIG).compact();
    });
  }
  static int getInt(String propertyName){
    String value= get(propertyName);
    return value.length== 0 ? 0 : int.tryParse(value)!;
  }

  static void saveBool(String propertyName, bool? value){
    Hive.box<String>(TABLE_USER_CONFIG).put(propertyName, value== null || !value ? "0" : "1").whenComplete(() {
      Hive.box<String>(TABLE_USER_CONFIG).compact();
    });
  }
  static bool getBool(String propertyName){
    return get(propertyName)== "1";
  }

  static ValueListenable getListener(String key){
    return Hive.box<String>(TABLE_USER_CONFIG).listenable(keys: <String>[]..add(key));
  }
}

class GameSingleSaveType {
  static const int TEMP = 0;
  static const int SCRIPT_CHANGE = 1;
  static const int CHOICE = 2;
  static const int SAVE_POINT = 3;
}

@HiveType(typeId : 1)
class SingleSaveInfo {
  static const String TEXT_SPEED_PERCENT = "_text_speed";
  static const String TEXT_ANIMATION_STYLE = "_text_animation_style";
  static const String TEXT_ANIMATION_STYLE_TYPE_WRITER = "type_writer";
  static const String GAME_TEXT_MODE = "_text_mode";
  static const String GAME_TEXT_MODE_NOVEL = "novel";

  @HiveField(0)
  int _type = GameSingleSaveType.TEMP;

  @HiveField(1)
  String _note= "";

  //@HiveField(2)
  //String _text;

  @HiveField(3)
  String _scriptsStack= "";

  @HiveField(4)
  Map<String, String> _parametersSave= Map<String, String>();

  @HiveField(5)
  late List<String> _saveScriptContent;

  SingleSaveInfo();

  SingleSaveInfo.all(int type, String note, String scriptsStack, List<String> saveContentLines){
    _type= type;
    _note= note;
    _scriptsStack= scriptsStack;
    _saveScriptContent= saveContentLines;
  }

  void setParameterSave(Map<String, String> currentParameterSave) {
    _parametersSave.addAll(currentParameterSave);
  }

  String get scriptsStack => _scriptsStack;
  Map<String, String> get parametersSave => _parametersSave;
  int get type => _type;
  String get note => _note;
  List<String> get saveScriptContent => _saveScriptContent;

  @override
  String toString() {
    return 'SingleSaveInfo{_type: $_type, _note: $_note, _scriptsStack: $_scriptsStack, _parametersSave: $_parametersSave}';
  }
}

class GameSaveType {
  static const int CURRENT = 1;
  static const int NORMAL = 2;
  static const int QUICK = 3;
}

@HiveType(typeId : 2)
class SavesInfo extends HiveObject{
  static const String TABLE_SAVE = "save;";
  static const String TABLE_SAVE_TEMP = "save_temp";
  static const int THUMBNAIL_WIDTH= 160;
  static const int MAX_TEMP_SAVE= 20;
  static const int MAX_BACK_LOG_LINE= 30;
  static const int STEP_FOR_TEMP_SAVE = -2;

  static String getKey(int type, [int slot= -1]){
    return "$type,$slot";
  }

  @HiveField(0)
  int _type = GameSaveType.CURRENT;

  @HiveField(1)
  int _slot= -1;

  @HiveField(2)
  int _currentScriptLine= -1;

  @HiveField(3)
  String _thumbPath = "";

  @HiveField(4)
  String _text = "";

  @HiveField(5)
  String _note = "";

  @HiveField(6)
  String _dateTime = "";

  @HiveField(7)
  List<SingleSaveInfo> _singleSaveArray= <SingleSaveInfo>[];

  int _tempSaveCount= 0;
  Map<String, String> _currentParameterSave= Map<String, String>();

  SavesInfo();

  SavesInfo.fromType(int type, int slot) {
    _type= type;
    _slot= slot;
    refresh();
    if(_type== GameSaveType.CURRENT){
      Hive.box<SavesInfo>(TABLE_SAVE_TEMP).put(getKey(_type, -1), this);
    }
  }

  bool goBackOnce(){
    if(_singleSaveArray.length== 0){return false;}
    SingleSaveInfo toRemove= _singleSaveArray.elementAt(_singleSaveArray.length- 1);
    List<ScriptItem> scriptItems= ScriptItem.parseFromSave(toRemove.scriptsStack);
    if(_singleSaveArray.length== 1){ //&& scriptItems.length== 1
      if(scriptItems.elementAt(scriptItems.length- 1).line>= _currentScriptLine){
        return false;
      }else{
        _currentScriptLine= scriptItems.elementAt(scriptItems.length- 1).line;
        save();
        return true;
      }
    }
    if(scriptItems.elementAt(scriptItems.length- 1).line>= _currentScriptLine){
      _singleSaveArray.remove(toRemove);
      _reloadTempData();
    }
    _currentScriptLine= scriptItems.elementAt(scriptItems.length- 1).line;
    save();

    return true;
  }

  void goBackFromBackLog(BackLogItem backLogItem){
    for(int i= 0; i< backLogItem.saveBackStep; i++){
      _singleSaveArray.removeLast();
    }
    _reloadTempData();
    _currentScriptLine= ScriptItem.parseFromSave(
        _singleSaveArray.last._scriptsStack).last.line + backLogItem.deltaLine;
    save();
  }

  static bool haveData(int type, [int slot= -1]){
    return File(getSaveFullPath(type, slot)).existsSync();
  }

  static String getSaveFullPath(int type, int slot){
    return CommonFunc.buildPath([StorageHelper.APP_SAVE_DIR_FULL_PATH,
      SavesInfo.TABLE_SAVE+ getKey(type, slot)+ ".hive"]);
  }

  static haveCurrentData(){
    Box<SavesInfo> box= Hive.box<SavesInfo>(TABLE_SAVE_TEMP);
    return box.isNotEmpty && box.get(getKey(GameSaveType.CURRENT, -1))!.saveArray.length> 0;
  }

  static Future<SavesInfo> loadData(int type, [int slot= -1]) async {
    await Hive.box<SavesInfo>(SavesInfo.TABLE_SAVE_TEMP).clear();
    LazyBox<SavesInfo> saveBox= await Hive.openLazyBox<SavesInfo>(SavesInfo.TABLE_SAVE+ getKey(type, slot));
    SavesInfo loaded= (await saveBox.get(getKey(type, slot)))!;
    await Hive.box<SavesInfo>(TABLE_SAVE_TEMP).put(getKey(GameSaveType.CURRENT, -1),
        loaded.copyWith(type: GameSaveType.CURRENT, slot: -1));
    saveBox.close();
    return loadCurrentData();
  }

  static SavesInfo loadCurrentData(){
    SavesInfo? ret= Hive.box<SavesInfo>(TABLE_SAVE_TEMP).get(getKey(GameSaveType.CURRENT, -1));
    if(ret== null){
      ret= SavesInfo.fromType(GameSaveType.CURRENT, -1);
    }
    ret._reloadTempData();
    return ret;
  }

  void _reloadTempData(){
    _tempSaveCount= 0;
    for(int i= _singleSaveArray.length- 1; i>= 0; i--){
      if(_singleSaveArray[i].type== GameSingleSaveType.TEMP){
        _tempSaveCount++;
      }else{
        break;
      }
    }

    _currentParameterSave.clear();
    if(_singleSaveArray.length> 0){
      _currentParameterSave.addAll(_singleSaveArray.last.parametersSave);
    }
  }

  static Future<SavesInfo> loadLessData(int type, [int slot= -1]) async {
    if(!haveData(type, slot)){return SavesInfo.fromType(type, slot);}
    LazyBox<SavesInfo> saveBox= await Hive.openLazyBox<SavesInfo>(SavesInfo.TABLE_SAVE+ getKey(type, slot));
    SavesInfo? ret= await saveBox.get(getKey(type, slot));
    ret= ret== null ? SavesInfo.fromType(type, slot) : ret.lesser();
    saveBox.close();
    return ret;
  }

  static Future<void> deleteSaveData(int type, [int slot= -1]){
    Completer<void> completer = new Completer<void>();
    Hive.openLazyBox<SavesInfo>(SavesInfo.TABLE_SAVE+ getKey(type, slot)).then((saveBox) {
      saveBox.get(getKey(type, slot)).then((toDel) {
        if(toDel!= null && toDel.thumbPath.length> 0){
          File(getSaveThumbPath(toDel.thumbPath)).delete();
        }
        saveBox.deleteFromDisk().whenComplete(() {
          completer.complete(null);
        });
      });
    });
    return completer.future;
  }

  SavesInfo lesser(){
    return copyWith(listSingleSave: <SingleSaveInfo>[]);
  }

  bool isEmpty(){
    return _currentScriptLine< 0;
  }

  void refresh(){
    _thumbPath= "";
    _singleSaveArray= <SingleSaveInfo>[];
    _currentParameterSave.clear();
    _currentScriptLine= -1;
    _tempSaveCount= 0;
    _text= "";
    _note= "";
    _dateTime= "";
  }

  String getLocalParameter(String param){
    String? ret= _currentParameterSave[param];
    return ret== null ? "" : ret;
  }

  Map<String, dynamic> initExpressionContext(){
    int Function(String?) length= (toGetLengthStr){
      return null== toGetLengthStr ? -1 : toGetLengthStr.length;
    };
    bool Function(String?, String?) contains= (heyStack, needle){
      if(null== heyStack || null== needle){
        return false;
      }
      return heyStack.contains(needle);
    };
    Map<String, dynamic> context = {};
    context.putIfAbsent("undefined", () => null);
    context.putIfAbsent("contains", () => contains);
    context.putIfAbsent("length", () => length);
    Function(dynamic, String) parseVariableValue= (key,value) {
      double? tryParseNumber= double.tryParse(value);
      //Treat as string if fail on trying parse to number
      if(null!= tryParseNumber){
        context.putIfAbsent(key, () => tryParseNumber);
      }else{
        context.putIfAbsent(key, () => value);
      }
    };
    _currentParameterSave.forEach(parseVariableValue);
    GlobalVariable.allDataToMap().forEach(parseVariableValue);
    return context;
  }
  void saveVariable(ScriptCommandInfo commandInfo) {
    String varName= commandInfo.valueOf(ScriptCommand.SET_VARIABLE_NAME)!;
    if(varName.length== 0){return;}
    String? expressionString= commandInfo.valueOf(ScriptCommand.SET_VALUE);
    Map<String, dynamic> context= initExpressionContext();
    final evaluator = const ExpressionEvaluator();

    if(varName.startsWith("_")){
      //Local variable
      if(null== expressionString){
        _currentParameterSave.remove(varName);
      }else{
        var value = evaluator.eval(Expression.parse(expressionString), context);
        _currentParameterSave.putIfAbsent(varName, () => value.toString());
      }
      return;
    }else if(RegExp("^[A-Z]+?[A-Z_]+").hasMatch(varName)){
      //Config variable
      if(null!= expressionString){
        var value = evaluator.eval(Expression.parse(expressionString), context);
        UserConfig.save(varName, value.toString());
      }
    }else{
      //Global variable
      if(null== expressionString){
        GlobalVariable.save(varName, null);
      }else{
        var value = evaluator.eval(Expression.parse(expressionString), context);
        GlobalVariable.save(varName, value.toString());
      }
    }
  }

  bool checkVariable(ScriptCommandInfo commandInfo) {
    String expressionString= commandInfo.valueOf(ScriptCommand.CHECK_EXPRESSION)!;
    Map<String, dynamic> context= initExpressionContext();
    final evaluator = const ExpressionEvaluator();

    bool result= evaluator.eval(Expression.parse(expressionString), context) as bool;
    return result;
  }

  void put(SingleSaveInfo singleSaveInfo, int lastScriptLine) {
    singleSaveInfo.setParameterSave(_currentParameterSave);
    _singleSaveArray.add(singleSaveInfo);
    _currentScriptLine= lastScriptLine;
    if(singleSaveInfo.type== GameSingleSaveType.TEMP){
      _tempSaveCount++;
      if(_tempSaveCount> MAX_TEMP_SAVE){
        _tempSaveCount--;
        _singleSaveArray.removeAt(_singleSaveArray.length -1 -MAX_TEMP_SAVE);
      }
    }else{
      _tempSaveCount= 0;
    }
    //save();
  }

  static String getSaveThumbPath(String thumbName){
    return "${StorageHelper.GAME_SAVE_THUMB_DIR}$thumbName${StorageHelper.GAME_IMAGE_CACHE_EXTENSION}";
  }

  Future<void> userSave(int saveType, int slot, String text, ui.Image? thumbImage, int currentScriptLine) async {
    DateTime now = DateTime.now();
    String dateTimeString= "${now.year}/${now.month}/${now.day} ${now.hour}:${now.minute}:${now.second}";
    _dateTime= dateTimeString;
    if(saveType== GameSaveType.CURRENT){
      _currentScriptLine= currentScriptLine;
      save().whenComplete(() {
        Hive.box<SavesInfo>(SavesInfo.TABLE_SAVE_TEMP).compact();
      });
    }else{
      String thumbName= "";
      if(thumbImage!= null){
        thumbName= getKey(saveType, slot);
        File toCache= File(getSaveThumbPath(thumbName));
        ByteData? img= await thumbImage.toByteData(format: ui.ImageByteFormat.png);
        if(img!= null){
          toCache.writeAsBytesSync(img.buffer.asInt8List(), flush: true);
        }
      }
      LazyBox<SavesInfo> saveBox= await Hive.openLazyBox<SavesInfo>(SavesInfo.TABLE_SAVE+ getKey(saveType, slot));
      SavesInfo? toUpdate= await saveBox.get(getKey(saveType, slot));
      if(toUpdate== null){
        toUpdate= SavesInfo.fromType(saveType, slot);
        await saveBox.put(getKey(saveType, slot), toUpdate);
      }
      toUpdate._text= text;
      toUpdate._thumbPath= thumbName;
      toUpdate._currentScriptLine= currentScriptLine;
      toUpdate._dateTime= dateTimeString;
      toUpdate._singleSaveArray= _singleSaveArray.toList();
      await toUpdate.save();
      await saveBox.close();
    }
  }

  static Future<void> alterUserNote(int saveType, int slot, String note) async {
    LazyBox<SavesInfo> saveBox= await Hive.openLazyBox<SavesInfo>(
        SavesInfo.TABLE_SAVE+ getKey(saveType, slot));
    SavesInfo? toAlter= await saveBox.get(getKey(saveType, slot));
    if(toAlter!= null){
      toAlter._note= note;
      await toAlter.save();
      await saveBox.close();
    }
  }

  SavesInfo.all(int type, int slot, int currentScriptLine, String thumbPath,
      String text, String note, String dateTime, List<SingleSaveInfo> singleSaveArray) {
    _slot= slot;
    _type= type;
    _text= text;
    _note= note;
    _dateTime= dateTime;
    _currentScriptLine= currentScriptLine;
    _thumbPath= thumbPath;
    _singleSaveArray= singleSaveArray.toList();
  }

  SavesInfo copyWith({int? type, int? slot, int? currentLine, String? thumbPath,
    String? text, String? note, String? dateTime, List<SingleSaveInfo>? listSingleSave}){
    if(type== null){
      type= _type;
    }
    if(slot== null){
      slot= _slot;
    }
    if(currentLine== null){
      currentLine= _currentScriptLine;
    }
    if(thumbPath== null){
      thumbPath= _thumbPath;
    }
    if(text== null){
      text= _text;
    }
    if(note== null){
      note= _note;
    }
    if(dateTime== null){
      dateTime= _dateTime;
    }
    if(listSingleSave== null){
      listSingleSave= _singleSaveArray.toList();
    }
    SavesInfo ret= SavesInfo.all(type, slot, currentLine, thumbPath, text, note, dateTime, listSingleSave);
    return ret;
  }

  int get slot => _slot;
  int get type => _type;
  String get note => _note;
  String get text => _text;
  int get currentScriptLine => _currentScriptLine;
  String get thumbPath => _thumbPath;
  String get dateTime => _dateTime;
  List<SingleSaveInfo> get saveArray => _singleSaveArray;

  @override
  String toString() {
    String ret= "[Start SavesInfo]\ntype:$_type\nslot:$_slot\ncurrentScriptLine:$_currentScriptLine\nsingleSaveArray lenght:${_singleSaveArray.length}\n";

    for(SingleSaveInfo singleSaveInfo in _singleSaveArray){
      ret+= singleSaveInfo.toString() + "\n";
    }
    ret+= "[End SavesInfo]";
    return ret;
  }
}

class AlreadyReadHelper{
  static const String ALREADY_READ_TABLE_NAME = "already_read";

  static void init() async {
    Box<Uint8List> box= await Hive.openBox<Uint8List>(ALREADY_READ_TABLE_NAME);
    if(box.isEmpty){
      Directory scriptDir= Directory(CommonFunc.buildPath(
          [UserConfig.get(UserConfig.GAME_ASSETS_FOLDER),
            AssetConstant.SCRIPT_DIR]));
      if(scriptDir.existsSync()){
        scriptDir.list().listen((data) {
          if(data is File){
            box.put(Path.basenameWithoutExtension(data.path), Uint8List(File(data.path).readAsLinesSync().length* 2));
          }
        });
      }
    }
  }

  static void compact(){
    Box<Uint8List> box= Hive.box<Uint8List>(ALREADY_READ_TABLE_NAME);
    for(String key in box.keys){
      Uint8List data= box.get(key)!;
      box.put(key, data);
    }
    box.compact();
  }

  static void read(String fileName, int line){
    if(fileName.length== 0 || fileName== ScriptItem.FAKE_SCRIPT_NAME_PREFIX){return;}
    Box<Uint8List> box= Hive.box<Uint8List>(ALREADY_READ_TABLE_NAME);
    if(!box.containsKey(fileName)){
      String filePath= CommonFunc.buildPath(
          [UserConfig.get(UserConfig.GAME_ASSETS_FOLDER),
            AssetConstant.SCRIPT_DIR,
            fileName+ ScriptItem.FILE_EXTENSION]);
      box.put(fileName, Uint8List(File(filePath).readAsLinesSync().length* 2));
    }
    int index= (line/ 8).truncate();
    int insideIndex= line % 8;
    Uint8List data= box.get(fileName)!;
    int toAdd= 1<< insideIndex;
    data[index]|= toAdd;
  }

  static bool wasRead(String? fileName, int line){
    if(fileName== null || !Hive.box<Uint8List>(ALREADY_READ_TABLE_NAME).containsKey(fileName)){return false;}
    int index= (line/ 8).truncate();
    int insideIndex= line % 8;
    int toCheck= 1<< insideIndex;
    return Hive.box<Uint8List>(ALREADY_READ_TABLE_NAME).get(fileName)![index] & toCheck == toCheck;
  }
}

class AssetConstant {
  //static const String ROOT_DIR = "assets/.nomedia/";
  static const String GAME_ROOT_DIR = "assets/.nomedia/game/";
  static const String SCRIPT_DIR = GAME_ROOT_DIR + "scripts/";
  static const String SPECTRUM_DIR = GAME_ROOT_DIR + "spectrum/";
  static const String IMAGE_DIR = GAME_ROOT_DIR + "image/";
  static const String BACKGROUND_DIR = IMAGE_DIR + "bg/";
  static const String MULTIPLE_LANGUAGE_DIR = IMAGE_DIR + "lang/";
  static const String EFFECT_DIR = IMAGE_DIR + "eff/";
  static const String IMAGE_SEQUENCE_DIR = IMAGE_DIR + "sequence/";
  static const String CHARACTER_DIR = IMAGE_DIR + "char/";
  static const String AVATAR_DIR = IMAGE_DIR + "ava/";
  static const String IMAGE_CUSTOM_DIR = IMAGE_DIR + "custom/";
  static const String OTHER_IMAGE_DIR = IMAGE_DIR + "other/";
  static const String VIDEO_DIR = GAME_ROOT_DIR + "movies/";
  static const String GIF_DIR = GAME_ROOT_DIR + "gif/";
  static const String SOUND_DIR = GAME_ROOT_DIR + "sound/";
  static const String SOUND_VOICE_DIR = SOUND_DIR + "voice/";
  static const String SOUND_BGM_BGS_DIR = SOUND_DIR + "bg/";
  static const String SOUND_SOUND_EFFECT_DIR = SOUND_DIR + "se/";
  static const String TEXT_BACKGROUND_IMAGE_FILE = "textbox_bg";
  static const String RESOURCE_DOWNLOAD_DIR = "resource_download";

  static const String APP_ROOT_DIR = "assets/app/";
  static const String APP_IMAGE_DIR = APP_ROOT_DIR + "image/";
  static const String APP_GIF_DIR = APP_IMAGE_DIR + "gif/";
  static const String APP_TEXT_BOX_ARROW_UP_GIF = APP_GIF_DIR + "game_text_box_arrow_up_animate.gif";
  static const String APP_TEXT_BOX_ARROW_UP = APP_IMAGE_DIR + "game_text_box_arrow_up.png";
  static const String APP_TEXT_DIR = APP_ROOT_DIR + "text/";

  static const String CHECK_HASH_FILE_PATH = IMAGE_DIR+ "hoshi";

  static SplayTreeMap<String, String>? _magicPath;

  static Future<void> initAssetsPath(){
    Completer<void> completer = new Completer<void>();
    if(_magicPath!= null && _magicPath!.length> 0){
      completer.complete();
    }else{
      _magicPath = SplayTreeMap<String, String>();
      rootBundle.loadString(APP_TEXT_DIR+ "magic_path.txt").then((fileString) {
        for(String aLine in fileString.split("\r\n")){
          if(aLine.length== 0){continue;}
          int separatorIndex= aLine.indexOf("|=|");
          if(separatorIndex< 0){continue;}
          _magicPath!.putIfAbsent(aLine.substring(0, separatorIndex), () => aLine.substring(separatorIndex+ 3));
        }
        completer.complete(null);
      });
    }
    return completer.future;
  }

  static String getTruePath(String abstractPath) {
    if (!_magicPath!.containsKey(abstractPath)) {
      return "${UserConfig.get(UserConfig.GAME_ASSETS_FOLDER)}/$abstractPath";
    }
    return "${UserConfig.get(UserConfig.GAME_ASSETS_FOLDER)}/${_magicPath![abstractPath]}";
  }

  static bool containPath(String assetPath){
    return _magicPath!.containsKey(assetPath);
  }
}