import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart' as Hash;
import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'script_runner.dart';

/*
* Edit all from this file com_cons.dart
* Edit all from this storage_helper.dart
* Edit pubspec.yaml for assets path, font define, app file/folder define
* Edit script_runner.dart if you want to change command
* Edit image_helper.dart - write your own shader mask, color filter matrix
* and in getCommonWidgetForGameContainer() function, remove unused transform to
* save performance
* Edit android/app/src/main/AndroidManifest.xml
* <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
* Edit assets/app/fonts/ to add font, don't forget to edit pubspec.yaml
* Edit text_processor.dart to define menu text, character name for each language
* */

extension MoreStringExtension on String {
  double? getDelta(){
    String str = this;
    if(!str.startsWith("+")){return null;}
    return double.tryParse(str.substring(1));
  }

  BlendMode toBlendMode(){
    String blendName = this.toLowerCase();
    switch(blendName){
      case "srcatop": return BlendMode.srcATop;
      case "modulate": return BlendMode.modulate;
      case "srcover": return BlendMode.srcOver;
      case "dstover": return BlendMode.dstOver;
      case "srcin": return BlendMode.srcIn;
      case "dstin": return BlendMode.dstIn;
      case "srcout": return BlendMode.srcOut;
      case "dstout": return BlendMode.dstOut;
      case "dstatop": return BlendMode.dstATop;
      case "hue": return BlendMode.hue;
      case "xor": return BlendMode.xor;
      case "plus": return BlendMode.plus;
      case "screen": return BlendMode.screen;
      case "overlay": return BlendMode.overlay;
      case "darken": return BlendMode.darken;
      case "lighten": return BlendMode.lighten;
      case "colordodge": return BlendMode.colorDodge;
      case "colorburn": return BlendMode.colorBurn;
      case "hardlight": return BlendMode.hardLight;
      case "softlight": return BlendMode.softLight;
      case "difference": return BlendMode.difference;
      case "exclusion": return BlendMode.exclusion;
      case "multiply": return BlendMode.multiply;
      case "saturation": return BlendMode.saturation;
      case "color": return BlendMode.color;
      case "luminosity": return BlendMode.luminosity;
    }
    return BlendMode.srcATop;
  }
  
  List<double> toColorMatrix(){
    String str= this;
    if(str.length== 0){
      return [
        1, 0, 0, 0, 0,
        0, 1, 0, 0, 0,
        0, 0, 1, 0, 0,
        0, 0, 0, 1, 0,
      ];
    }
    if(!str.contains(ScriptCommandInfo.PARAM_IN_VALUE_COMMAND_SEPARATOR)){
      return [int.parse("0x${str.length== 6 ? "FF"+ str : str}").toDouble()];
    }
    List<double> inputList= str.split(ScriptCommandInfo.PARAM_IN_VALUE_COMMAND_SEPARATOR)
        .map((e) => double.parse(e.trim())).toList();
    if(inputList.length== 4){
      return [
        (inputList[0]), 0, 0, 0, 0,
        0, (inputList[1]), 0, 0, 0,
        0, 0, (inputList[2]), 0, 0,
        0, 0, 0, (inputList[3]), 0,
      ];
    }else if(inputList.length== 5){
      return [
        (inputList[0]), 0, 0, 0, (inputList[4]),
        0, (inputList[1]), 0, 0, (inputList[4]),
        0, 0, (inputList[2]), 0, (inputList[4]),
        0, 0, 0, (inputList[3]), 0,
      ];
    }else{
      return inputList;
    }
  }
}

extension ColorToStringExtension on Color {
  String toText() {
    Color myColor = this;
    return myColor.toString().substring(8, 16);
  }
}

extension DoubleToColorExtension on double {
  List<double> toColorDoubleList() {
    return <double>[]..add(Color(this.toInt()).value.toDouble());
  }
}

extension BlendModeToTextExtension on BlendMode {
  String toText() {
    BlendMode myBlend = this;
    return myBlend.toString().substring(10).toLowerCase();
  }
}

enum StartAppCommand {
  LOAD_LAST_SAVE,
  RUN_SCRIPT,
}

class GameConstant {
  static const double GAME_ASPECT_RATIO = 16 / 9;
  static const double GAME_TEXT_BOX_AVATAR_ASPECT_RATIO = 0.7;
  static const double GAME_TEXT_BOX_RIGHT_ASPECT_RATIO = 0.8;
  static const int GAME_SPRITE_SIZE_BASE = 1956;
  static const int GAME_CG_SIZE_BASE = 1280;
  static const int GAME_VIDEO_SIZE_BASE = 1280;
  static late double gameSpriteSizeRatio;
  static late double gameCgSizeRatio;
  static late double gameVideoSizeRatio;
  static const int LIP_SYNC_FREQUENCY = 70;
  static const int GAME_SPRITE_ANIMATE_TIME = 400;
  static const int GAME_TEXTBOX_ELEMENT_ANIMATE_TIME = 200;
  static const int GAME_TEXT_BOX_SCROLL_TIME = 300;
  static const int GAME_MENU_SWITCH_TIME = 400;
  static const int GAME_BGM_FADE_OUT_TIME = 1000;
  static const int GAME_BGM_FADE_IN_TIME = 500;
  static const String LIP_SYNC_SPECTRUM_SEPARATOR = ",";

  static const Alignment GAME_SCENE_ALIGNMENT = Alignment.topCenter;

  static const TextStyle SPLASH_DEFAULT_TEXT_STYLE = TextStyle(
    fontFamily: "Linotte",
    fontSize: 23,
    decoration: TextDecoration.none,
    decorationStyle: TextDecorationStyle.solid,
    decorationColor: Colors.white,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    shadows: [
      Shadow( // bottomLeft
          offset: Offset(-1, -1),
          color: Colors.black
      ),
      Shadow( // bottomRight
          offset: Offset(1, -1),
          color: Colors.black
      ),
      Shadow( // topRight
          offset: Offset(1, 1),
          color: Colors.black
      ),
      Shadow( // topLeft
          offset: Offset(-1, 1),
          color: Colors.black
      ),
    ],
  );

  static const TextStyle SPLASH_COMMUNITY_TEXT_STYLE = TextStyle(
    fontFamily: "Linotte",
    fontSize: 18,
    decoration: TextDecoration.none,
    decorationStyle: TextDecorationStyle.solid,
    decorationColor: Colors.white,
    fontWeight: FontWeight.normal,
    color: Colors.white,
    shadows: [
      Shadow( // bottomLeft
          offset: Offset(-0.5, -0.5),
          color: Colors.black
      ),
      Shadow( // bottomRight
          offset: Offset(0.5, -0.5),
          color: Colors.black
      ),
      Shadow( // topRight
          offset: Offset(0.5, 0.5),
          color: Colors.black
      ),
      Shadow( // topLeft
          offset: Offset(-0.5, 0.5),
          color: Colors.black
      ),
    ],
  );

  static const TextStyle SPLASH_SIMPLE_TEXT_STYLE = TextStyle(
    fontFamily: "Linotte",
    fontSize: 18,
    decoration: TextDecoration.none,
    decorationStyle: TextDecorationStyle.solid,
    decorationColor: Colors.white,
    fontWeight: FontWeight.normal,
    color: Colors.black,
  );

  static const TextStyle GAME_DEFAULT_TEXT_STYLE = TextStyle(
    color: Color(0xFFCAB804),
    height: 1.25,
    shadows: [
      Shadow(
        blurRadius: 5.0,
        color: Colors.black,
        offset: Offset(3.0, 3.0),
      ),
      Shadow( // bottomLeft
          offset: Offset(-0.5, -0.5),
          color: Colors.black
      ),
      Shadow( // bottomRight
          offset: Offset(0.5, -0.5),
          color: Colors.black
      ),
      Shadow( // topRight
          offset: Offset(0.5, 0.5),
          color: Colors.black
      ),
      Shadow( // topLeft
          offset: Offset(-0.5, 0.5),
          color: Colors.black
      ),
    ],
  );

  static const TextStyle GAME_DEFAULT_NAME_TAG_STYLE = TextStyle(
    color: Colors.white,
    shadows: [
      Shadow(
        blurRadius: 10.0,
        color: Colors.black,
        offset: Offset(3.0, 3.0),
      ),
      Shadow(
        blurRadius: 10.0,
        color: Colors.black,
        offset: Offset(-3.0, 3.0),
      ),
      Shadow(
        blurRadius: 10.0,
        color: Colors.black,
        offset: Offset(3.0, -3.0),
      ),
      Shadow(
        blurRadius: 10.0,
        color: Colors.black,
        offset: Offset(-3.0, -3.0),
      ),
      Shadow( // bottomLeft
          offset: Offset(-0.5, -0.5),
          color: Colors.black
      ),
      Shadow( // bottomRight
          offset: Offset(0.5, -0.5),
          color: Colors.black
      ),
      Shadow( // topRight
          offset: Offset(0.5, 0.5),
          color: Colors.black
      ),
      Shadow( // topLeft
          offset: Offset(-0.5, 0.5),
          color: Colors.black
      ),
    ],
  );

  static const List<DeviceOrientation> GAME_ORIENTATION = [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight
  ];

  static void preInit(){

  }

  static void postInit(double gameContainerWidth){
    gameSpriteSizeRatio = gameContainerWidth/ GAME_SPRITE_SIZE_BASE;
    gameCgSizeRatio = gameContainerWidth/ GAME_CG_SIZE_BASE;
    gameVideoSizeRatio = gameContainerWidth/ GAME_VIDEO_SIZE_BASE;
  }
}

class CommonFunc {
  static Alignment parseAlign(String? align){
    if(align== null || align.length== 0){return Alignment.center;}
    if(align== Alignment.topLeft.toString()) {return Alignment.topLeft;}
    if(align== Alignment.topCenter.toString()) {return Alignment.topCenter;}
    if(align== Alignment.topRight.toString()) {return Alignment.topRight;}
    if(align== Alignment.centerLeft.toString()) {return Alignment.centerLeft;}
    if(align== Alignment.centerRight.toString()) {return Alignment.centerRight;}
    if(align== Alignment.center.toString()) {return Alignment.center;}
    if(align== Alignment.bottomLeft.toString()) {return Alignment.bottomLeft;}
    if(align== Alignment.bottomCenter.toString()) {return Alignment.bottomCenter;}
    if(align== Alignment.bottomRight.toString()) {return Alignment.bottomRight;}
    if(!align.contains(",")){return Alignment.center;}
    List<String> alignStr= align.split(",");
    return Alignment(double.parse(alignStr[0]), double.parse(alignStr[1]));
  }

  static String buildPath(List<String> params){
    String? ret;
    bool lastParamEndWithSeparator= false;
    for(String aParam in params){
      if(ret== null){
        ret= aParam;
      }else{
        if(!lastParamEndWithSeparator){
          ret += Platform.pathSeparator;
        }
        ret += aParam;
      }
      lastParamEndWithSeparator= aParam.endsWith(Platform.pathSeparator);
    }

    return ret!;
  }

  static Size getImageSizeInPath(String imagePath){
    double width = 0, height = 0;
    String imageName = imagePath.substring(
        imagePath.lastIndexOf(Platform.pathSeparator)+ 1);
    imageName = imageName.substring(0, imageName.lastIndexOf("."));
    if(imageName.contains(";")){
      List<String> nameSplit = imageName.split(";");
      for(String aParam in nameSplit){
        if(aParam.trim().startsWith("w=")){
          width = double.parse(aParam.substring("w=".length).trim());
        }
        if(aParam.trim().startsWith("h=")){
          height = double.parse(aParam.substring("h=".length).trim());
        }
      }
    }

    return Size(width, height);
  }

  static int getDurationInPath(String imagePath){
    String imageName = imagePath.substring(
        imagePath.lastIndexOf(Platform.pathSeparator)+ 1);
    imageName = imageName.substring(0, imageName.lastIndexOf("."));
    if(imageName.contains(";")){
      List<String> nameSplit = imageName.split(";");
      for(String aParam in nameSplit){
        if(aParam.trim().startsWith("t=")){
          return int.parse(aParam.substring("t=".length).trim());
        }
      }
    }

    return 0;
  }

  static double getRotateValue(double rotateAngle){
    return rotateAngle  * Math.pi / 180;
  }
  static double getAngleValue(double rotate){
    return rotate  / Math.pi * 180;
  }

  static Future<bool> checkMd5File(String filePath, String toCheck1, String toCheck2) {
    Completer<bool> completer = new Completer<bool>();
    var file = File(filePath);
    if (file.existsSync()) {
      try {
        Hash.md5.bind(file.openRead()).first.then((value) {
          completer.complete(value.toString().toLowerCase()== (toCheck1+ toCheck2));
        });
      } catch (exception) {
        completer.complete(false);
      }
    } else {
      completer.complete(false);
    }
    return completer.future;
  }

  static Future<String> getMd5Hash(String filePath){
    Completer<String> completer = new Completer<String>();
    var file = File(filePath);
    if (file.existsSync()) {
      try {
        Hash.md5.bind(file.openRead()).first.then((value) {
          completer.complete(value.toString().toUpperCase());
        });
      } catch (exception) {
        completer.complete("");
      }
    } else {
      completer.complete("");
    }
    return completer.future;
  }
}

enum LAYER_TYPE{
  SIMPLE,
  EFFECT,
}

class ContainerKeyName {
  static const String CONTAINER_KEY_NAME_PREFIX = "";
  static const String GAME_CONTAINER =
      "game_container"; //Contain SCENE + TEXT_BOUND

  //Contain ALL layer below
  static const String SCENE = "scene";
  static const String BACK_FILTER = "backfilter";
  static const String BACKGROUND = "back";
  static const String BACK_ENVIRONMENT = "backenv";
  static const String SPRITE = "char";
  static const String FRONT_ENVIRONMENT = "env";
  static const String FILTER = "filter";
  static const String SCENE_OVERLAY = "over";

  //Contain TEXT_BOUND + TEXT_DISPLAY
  static const String TEXT_BOUND = "textbox";
  static const String TEXT_BACK = "textback";
  //Contain  TEXT_DISPLAY_BOX + TEXT_DISPLAY_AVATAR
  static const String TEXT_DISPLAY = "textdisplay";
  static const String TEXT_DISPLAY_BOX = "textbox";
  static const String TEXT_DISPLAY_AVATAR = "avatar";

  static const String GAME_MENU = "game_menu";

  //static const String CONFIG_MENU = "config_menu";

  static const String ALL_OVERLAY = "game_overlay";
}

class CharacterBase{
  static const String PREFIX_MALE= "+";
  static const String PREFIX_FEMALE= "-";

  static const String ROUGE= "ルージュ";
  static const String GRIS= "グリーズ";
  static const String NOIR= "ノワール";
}