import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'game.dart';
import 'game_resource_screen.dart';
import 'script_runner.dart';
import 'text_processor.dart';
import 'com_cons.dart';
import 'storage_helper.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart' as UrlLauncher;
import 'package:path/path.dart' as Path;

void main() {
  //Let device allow app to set Orientation
  WidgetsFlutterBinding.ensureInitialized();
  //Initialize StorageHelper
  StorageHelper.init().whenComplete(() {
    //Set game orientation then run MyApp
    //TODO: Set native device orientation if need
    SystemChrome.setPreferredOrientations(GameConstant.GAME_ORIENTATION)
        .whenComplete(() => runApp(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Linotte'),
          home: SafeArea(child: InitWidget(),),
        )),
    );
  });
}

//SplashText
class _SPText{
  static const String LEFT_SIDE_TITLE = "LEFT_SIDE_TITLE";
  static const String OPEN_GAME_TITLE_NOT_READY = "OPEN_GAME_TITLE_NOT_READY";
  static const String OPEN_GAME_TITLE_READY = "OPEN_GAME_TITLE_READY";
  static const String OPEN_GAME_START = "OPEN_GAME_START";
  static const String OPEN_GAME_CONTINUE = "OPEN_GAME_CONTINUE";
  static const String OPEN_GAME_GOTO_RESOURCE_SCREEN = "OPEN_GAME_GOTO_RESOURCE_SCREEN";

  static String get(String txt) {
    String lang= UserConfig.get(UserConfig.MENU_LANGUAGE);
    if (lang == Language.VIETNAMESE) {
      switch(txt) {
        case LEFT_SIDE_TITLE: return "Ứng dụng";
        case OPEN_GAME_TITLE_NOT_READY: return "Dữ liệu game chưa sẵn sàng";
        case OPEN_GAME_TITLE_READY: return "GAME!!!";
        case OPEN_GAME_START: return "Bắt đầu";
        case OPEN_GAME_CONTINUE: return "Tiếp tục";
        case OPEN_GAME_GOTO_RESOURCE_SCREEN: return "Tải xuống dữ liệu";
      }
    }
    else if (lang == Language.JAPANESE) {
      switch(txt) {
        case LEFT_SIDE_TITLE: return "アプリケーション";
        case OPEN_GAME_TITLE_NOT_READY: return "ゲームデータ未完成";
        case OPEN_GAME_TITLE_READY: return "ゲーム！！！";
        case OPEN_GAME_START: return "スタート";
        case OPEN_GAME_CONTINUE: return "つづき";
        case OPEN_GAME_GOTO_RESOURCE_SCREEN: return "ゲームデータダウンロード";
      }
    }
    return "";
  }
}

class InitWidget extends StatefulWidget {
  @override
  _InitWidgetState createState() => _InitWidgetState();
}
class _InitWidgetState extends State<InitWidget> {
  bool _isGameResourceReady= false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(LifecycleEventHandler());
    _checkResourceInternal();
  }

  void _checkResourceInternal(){
    GameResource.checkResource().then((result) {
      setState(() {
        _isGameResourceReady= result;
      });
    });
  }

  final Widget _normalStar= Image.asset("assets/app/image/stage_splash/star.png",
    height: GameConstant.SPLASH_DEFAULT_TEXT_STYLE.fontSize,);
  final Widget _transparentStar= Image.asset("assets/app/image/stage_splash/star.png",
    color: Colors.transparent, height: GameConstant.SPLASH_DEFAULT_TEXT_STYLE.fontSize,);
  final BoxDecoration _greenBtnDecoration= const BoxDecoration(
    image: const DecorationImage(
      image: const AssetImage('assets/app/image/stage_splash/btn_bg_green.png'),
      fit: BoxFit.fill,
    ),
  );
  final BoxDecoration _greyBtnDecoration= const BoxDecoration(
    image: const DecorationImage(
      image: const AssetImage('assets/app/image/stage_splash/btn_bg_grey.png'),
      fit: BoxFit.fill,
    ),
  );
  final BoxDecoration _headerBoxDecoration= BoxDecoration(
    gradient: LinearGradient(
      colors: [const Color(0xFF00CCFF), const Color(0xFF3366FF),],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,),
  );
  final BoxDecoration _headerBoxDecorationGrey= BoxDecoration(
    gradient: LinearGradient(
      colors: [const Color(0xFFD2D1D3), const Color(0xFF918997),],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,),
  );
  final ButtonStyle _openGameBtnStyle= TextButton.styleFrom(
    padding: EdgeInsets.all(3),
    primary: Colors.white,
    textStyle: GameConstant.SPLASH_DEFAULT_TEXT_STYLE,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(children: [
        Expanded(flex: 2, child: Card(
          shadowColor: Colors.greenAccent,
          elevation: 7,
          color: Colors.white70,
          margin: const EdgeInsets.all(8),
          child: Stack(
            children: [
              DefaultTextStyle.merge(
                style: GameConstant.SPLASH_DEFAULT_TEXT_STYLE,
                child: Container(
                  padding: EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Text(_SPText.get(_SPText.LEFT_SIDE_TITLE))),
                      Container(
                        decoration: _headerBoxDecoration,
                        child: Container(
                          padding: EdgeInsets.all(3),
                          width: double.infinity,
                          child: Text("Ngôn ngữ／言語"),
                        ),
                      ),
                      Row(children: [
                        Expanded(child: Container(
                          padding: const EdgeInsets.all(5.0),
                          height: 60,
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: UserConfig.get(
                                UserConfig.MENU_LANGUAGE)== Language.VIETNAMESE
                                ? Border.all(color: Colors.lightBlueAccent) : null,
                          ),
                          child: GestureDetector(
                            onTap: () {
                              UserConfig.save(UserConfig.MENU_LANGUAGE, Language.VIETNAMESE);
                              setState(() {});
                            },
                            child: Image(
                              image: AssetImage('assets/app/image/stage_splash/flag_vietnam.png'),
                            ),
                          ),
                        )),
                        Expanded(child: Container(
                          padding: const EdgeInsets.all(5.0),
                          height: 60,
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: UserConfig.get(
                                UserConfig.MENU_LANGUAGE)== Language.JAPANESE
                                ? Border.all(color: Colors.lightBlueAccent) : null,
                          ),
                          child: GestureDetector(
                            onTap: () {
                              UserConfig.save(UserConfig.MENU_LANGUAGE, Language.JAPANESE);
                              setState(() {});
                            },
                            child: Image(
                              image: AssetImage('assets/app/image/stage_splash/flag_japan.png'),
                            ),
                          ),
                        )),
                      ],),
                      Container(
                        decoration: _isGameResourceReady
                            ? _headerBoxDecoration : _headerBoxDecorationGrey,
                        child: Container(
                          padding: EdgeInsets.all(3),
                          width: double.infinity,
                          child: Text(_isGameResourceReady
                              ? _SPText.get(_SPText.OPEN_GAME_TITLE_READY)
                              : _SPText.get(_SPText.OPEN_GAME_TITLE_NOT_READY)),
                        ),
                      ),
                      Row(children: [
                        if(!_isGameResourceReady) SizedBox(width: 5,),
                        if(!_isGameResourceReady) ElevatedButton(
                          onPressed: (){
                            Navigator.push(context,
                              MaterialPageRoute(builder: (context) => GameResourceProgress()),
                            ).whenComplete(() {
                              _checkResourceInternal();
                            });
                          },
                          style: _openGameBtnStyle,
                          child: Text(_SPText.get(_SPText.OPEN_GAME_GOTO_RESOURCE_SCREEN)),
                        ),
                        if(_isGameResourceReady) SizedBox(width: 5,),
                        if(_isGameResourceReady) ElevatedButton(
                          onPressed: (){
                            Navigator.push(context,
                              MaterialPageRoute(builder: (context) => MyApp(
                                file: ScriptItem.SPLASH_SCRIPT_NAME,
                                command: StartAppCommand.RUN_SCRIPT,
                              )),
                            ).whenComplete(() {
                              _checkResourceInternal();
                            });
                          },
                          style: _openGameBtnStyle,
                          child: Text(_SPText.get(_SPText.OPEN_GAME_START)),
                        ),
                        if(_isGameResourceReady) SizedBox(width: 5,),
                        if(_isGameResourceReady) ElevatedButton(
                          onPressed: SavesInfo.haveCurrentData() ? (){
                            Navigator.push(context,
                              MaterialPageRoute(builder: (context) => MyApp(
                                command: StartAppCommand.LOAD_LAST_SAVE,
                              )),
                            ).whenComplete(() {
                              _checkResourceInternal();
                            });
                          } : null,
                          style: _openGameBtnStyle,
                          child: Text(_SPText.get(_SPText.OPEN_GAME_CONTINUE)),
                        ),
                      ],),
                    ],
                  ),
                ),
              ),
              //Container(color: Colors.black54,),
            ],
          ),
        )),
        Expanded(child: Container()),
      ],),
    );
  }

  @override
  void dispose() {
    Hive.close();
    super.dispose();
  }
}