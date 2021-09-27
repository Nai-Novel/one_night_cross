import 'dart:async';
import 'dart:convert' as Convert;
import 'dart:convert' as JSON;

import 'package:dio/dio.dart';
import 'storage_helper.dart';

class HttpHelper{
  static const String GAME_INFO_URL= "https://raw.githubusercontent.com/" +
      "namlhse02285/OnlineAppInfoManager/master/GameInfo/OneNightCross.cs";
  static const String GAME_INFO_START= "[ONE_NIGHT_CROSS_START]";
  static const String GAME_INFO_END= "[ONE_NIGHT_CROSS_END]";

  static Future<String> getGameInfoJson(){
    Completer<String> completer= Completer<String>();
    Dio().get(GAME_INFO_URL).then((respond) {
      if(respond.statusCode!= 200){
        String _gameInfoJson= UserConfig.get(UserConfig.GAME_INFO_JSON);
        completer.complete(Convert.utf8.decode(Convert.base64Decode(_gameInfoJson)));
        return;
      }
      String encodedJsonStr= respond.data.toString();
      int startIndex= encodedJsonStr.indexOf(GAME_INFO_START);
      int endIndex= encodedJsonStr.indexOf(GAME_INFO_END);
      String _gameInfoJson= "";
      if(startIndex>= 0 && endIndex>= 0){
        encodedJsonStr= encodedJsonStr.substring(
            startIndex+ GAME_INFO_START.length, endIndex);
        UserConfig.save(UserConfig.GAME_INFO_JSON, encodedJsonStr);
        _gameInfoJson= Convert.utf8.decode(Convert.base64Decode(encodedJsonStr));
      }
      completer.complete(_gameInfoJson);
    }).catchError((_){
      String _gameInfoJson= UserConfig.get(UserConfig.GAME_INFO_JSON);
      completer.complete(Convert.utf8.decode(Convert.base64Decode(_gameInfoJson)));
    });
    return completer.future;
  }

  static dynamic queryGameInfo(){
    String gameInfoJson= UserConfig.get(UserConfig.GAME_INFO_JSON);
    if(gameInfoJson.length== 0){return null;}
    String gameInfo= Convert.utf8.decode(Convert.base64Decode(gameInfoJson));
    return JSON.jsonDecode(gameInfo);
  }

  static const String COMMON_INFO_URL =
    "https://raw.githubusercontent.com/namlhse02285/" +
    "OnlineAppInfoManager/master/Common/OnlineCommonUrl.cs";
  static const String COMMON_INFO_START = "[COMMON_INFO_START]";
  static const String COMMON_INFO_END = "[COMMON_INFO_END]";

  static Future<String> getCommonOnlineInfo(){
    Completer<String> completer= Completer<String>();
    Dio().get(COMMON_INFO_URL).then((respond) {
      if(respond.statusCode!= 200){
        String _gameInfoJson= UserConfig.get(UserConfig.COMMON_ONLINE_INFO_JSON);
        completer.complete(Convert.utf8.decode(Convert.base64Decode(_gameInfoJson)));
        return;
      }
      String encodedJsonStr= respond.data.toString();
      int startIndex= encodedJsonStr.indexOf(COMMON_INFO_START);
      int endIndex= encodedJsonStr.indexOf(COMMON_INFO_END);
      String _gameInfoJson= "";
      if(startIndex>= 0 && endIndex>= 0){
        encodedJsonStr= encodedJsonStr.substring(
            startIndex+ COMMON_INFO_START.length, endIndex);
        UserConfig.save(UserConfig.COMMON_ONLINE_INFO_JSON, encodedJsonStr);
        _gameInfoJson= Convert.utf8.decode(Convert.base64Decode(encodedJsonStr));
      }
      completer.complete(_gameInfoJson);
    }).catchError((_){
      String _gameInfoJson= UserConfig.get(UserConfig.COMMON_ONLINE_INFO_JSON);
      completer.complete(Convert.utf8.decode(Convert.base64Decode(_gameInfoJson)));
    });
    return completer.future;
  }

  static dynamic queryCommonInfo(){
    String commonInfoJson= UserConfig.get(UserConfig.COMMON_ONLINE_INFO_JSON);
    if(commonInfoJson.length== 0){return null;}
    String commonInfo= Convert.utf8.decode(Convert.base64Decode(commonInfoJson));
    return JSON.jsonDecode(commonInfo);
  }
}