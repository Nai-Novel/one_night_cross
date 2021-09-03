import 'dart:async';
import 'dart:convert' as Convert;

import 'package:dio/dio.dart';

class HttpHelper{
  static const String GAME_INFO_URL= "https://anotepad.com/notes/qd28b844";
  static const String GAME_INFO_START= "[ONE_NIGHT_CROSS_START]";
  static const String GAME_INFO_END= "[ONE_NIGHT_CROSS_END]";
  static String _gameInfoJson= "";

  static Future<String> getGameInfoJson(){
    Completer<String> completer= Completer<String>();
    if(_gameInfoJson.length> 0){
      completer.complete(_gameInfoJson);
    }else{
      Dio().get(GAME_INFO_URL).then((respond) {
        if(respond.statusCode!= 200){
          completer.complete(_gameInfoJson);
          return;
        }
        String encodedJsonStr= respond.data.toString();
        int startIndex= encodedJsonStr.indexOf(GAME_INFO_START);
        int endIndex= encodedJsonStr.indexOf(GAME_INFO_END);
        if(startIndex>= 0 && endIndex>= 0){
          encodedJsonStr= encodedJsonStr.substring(
              startIndex+ GAME_INFO_START.length, endIndex);
          _gameInfoJson= Convert.utf8.decode(Convert.base64Decode(encodedJsonStr));
        }
        completer.complete(_gameInfoJson);
      });
    }
    return completer.future;
  }
}