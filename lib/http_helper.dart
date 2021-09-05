import 'dart:async';
import 'dart:convert' as Convert;
import 'package:hive/hive.dart';

import 'package:dio/dio.dart';
import 'package:one_night_cross/storage_helper.dart';

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
}