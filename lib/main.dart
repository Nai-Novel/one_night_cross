import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:one_night_cross/http_helper.dart';
import 'package:url_launcher/url_launcher.dart' as UrlLauncher;
import 'game.dart';
import 'game_resource_screen.dart';
import 'script_runner.dart';
import 'text_processor.dart';
import 'com_cons.dart';
import 'storage_helper.dart';

void main() {
  //Let device allow app to set Orientation
  WidgetsFlutterBinding.ensureInitialized();
  //Initialize StorageHelper
  StorageHelper.init().whenComplete(() {
    HttpHelper.getCommonOnlineInfo();
    HttpHelper.getGameInfoJson().whenComplete(() {
      //Set game orientation then run App
      //TODO: Set native device orientation if need
      SystemChrome.setPreferredOrientations(GameConstant.GAME_ORIENTATION)
          .whenComplete(() => runApp(MaterialApp(
        home: SafeArea(child: InitWidget(),),)),
      );
    });
  });
}

//SplashText
class _SText{
  static const String LEFT_SIDE_TITLE = "LEFT_SIDE_TITLE";
  static const String GAME_TITLE_NOT_READY = "GAME_TITLE_NOT_READY";
  static const String GAME_TITLE_READY = "GAME_TITLE_READY";
  static const String GAME_START = "GAME_START";
  static const String GAME_CONTINUE = "GAME_CONTINUE";
  static const String GAME_GOTO_RESOURCE_SCREEN = "GAME_GOTO_RESOURCE_SCREEN";
  static const String GAME_GUIDE = "GAME_GUIDE";
  static const String GAME_BUG_REPORT = "GAME_BUG_REPORT";
  static const String GAME_SURVEY = "GAME_SURVEY";

  static const String RIGHT_SIDE_TITLE = "RIGHT_SIDE_TITLE";

  static const String COMMON_URL_NOT_FOUND = "COMMON_URL_NOT_FOUND";
  static const String COMMON_END_GAME_TITLE = "COMMON_END_GAME_TITLE";
  static const String COMMON_END_GAME_CONTENT = "COMMON_END_GAME_CONTENT";
  static const String COMMON_NOT_END_GAME_WARNING = "COMMON_NOT_END_GAME_WARNING";
  static const String COMMON_NEW_VERSION_READY = "COMMON_NEW_VERSION_READY";

  static String get(String txt) {
    String lang= UserConfig.get(UserConfig.MENU_LANGUAGE);
    if (lang == Language.VIETNAMESE) {
      switch(txt) {
        case LEFT_SIDE_TITLE: return "???ng d???ng";
        case GAME_TITLE_NOT_READY: return "D??? li???u game ch??a s???n s??ng";
        case GAME_TITLE_READY: return "GAME!!!";
        case GAME_START: return "B???t ?????u";
        case GAME_CONTINUE: return "Ti???p t???c";
        case GAME_GOTO_RESOURCE_SCREEN: return "T???i xu???ng d??? li???u";
        case GAME_GUIDE: return "Xem h?????ng d???n";
        case GAME_BUG_REPORT: return "B??o l???i";
        case GAME_SURVEY: return "Kh???o s??t";

        case RIGHT_SIDE_TITLE: return "C???ng ?????ng";
        case COMMON_URL_NOT_FOUND: return "Kh??ng t??m th???y ???????ng d???n";
        case COMMON_END_GAME_TITLE: return "Ho??n th??nh game";
        case COMMON_END_GAME_CONTENT: return "C???m ??n b???n ???? ch??i h???t to??n b??? game ONE NIGHT CROSS."
            " V???i ?? ?????nh nung n???u b???y l??u v??? vi???c ????a Visual Novel ?????n v???i c??c b???n ?????c gi??? ???????c d??? d??ng h??n,"
            " ch??ng m??nh r???t c???n s??? ???ng h??? t??? nh???ng ng?????i y??u th??ch th??? lo???i n??y."
            " M???t v??i d??ng nh???n x??t c???a c??c b???n l?? v?? c??ng qu?? gi?? v???i ch??ng m??nh."
            " B???m v??o n??t \"Kh???o s??t\" ??? b??n d?????i b???n nh??.";
        case COMMON_NOT_END_GAME_WARNING: return "B???n h??y ho??n th??nh 2 end c???a game tr?????c ???? nh??.";
        case COMMON_NEW_VERSION_READY: return "C?? b???n c???p nh???t m???i";
      }
    }
    else if (lang == Language.JAPANESE) {
      switch(txt) {
        case LEFT_SIDE_TITLE: return "????????????????????????";
        case GAME_TITLE_NOT_READY: return "???????????????????????????";
        case GAME_TITLE_READY: return "??????????????????";
        case GAME_START: return "????????????";
        case GAME_CONTINUE: return "?????????";
        case GAME_GOTO_RESOURCE_SCREEN: return "????????????????????????????????????";
        case GAME_GUIDE: return "???????????????";
        case GAME_BUG_REPORT: return "???????????????";
        case GAME_SURVEY: return "???????????????";

        case RIGHT_SIDE_TITLE: return "??????????????????";
        case COMMON_URL_NOT_FOUND: return "?????????????????????????????????";
        case COMMON_END_GAME_TITLE: return "??????????????????";
        case COMMON_END_GAME_CONTENT: return "ONE NIGHT CROSS?????????????????????????????????"
            "?????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????"
            "?????????????????????????????????????????????????????????????????????????????????????????????????????????????????? "
            "???????????????????????????????????????????????????????????????????????? "
            "????????????????????????????????????????????????????????????????????????????????????";
        case COMMON_NOT_END_GAME_WARNING: return "?????????????????????????????????????????????????????????????????????????????? ";
        case COMMON_NEW_VERSION_READY: return "??????????????????????????????????????????";
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
      GameResource.checkVersion().then((message) {
        if(null!= message){
          // set up the button
          Widget okButton = TextButton(
            child: Text("OK"),
            onPressed: () {
              Navigator.pop(context);
            },
          );

          // show the dialog
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(_SText.get(_SText.COMMON_NEW_VERSION_READY)),
                content: SingleChildScrollView(
                  child: Text(message.replaceAll(TextProcessor.FULL_TAG_LINE_BREAK, "\n")),
                ),
                actions: [
                  okButton,
                ],
              );
            },
          );
        }
      });
    });
  }

  void _checkIsFinishAllEnding(){
    if(SavesInfo.globalCheckVariable(ScriptCommandInfo(
        "check; exp=null != ed1 && null != ed2"))){
      // set up the button
      Widget okButton = TextButton(
        child: Text("OK"),
        onPressed: () {
          Navigator.pop(context);
        },
      );

      // show the dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(_SText.get(_SText.COMMON_END_GAME_TITLE)),
            content: Text(_SText.get(_SText.COMMON_END_GAME_CONTENT)),
            actions: [
              okButton,
            ],
          );
        },
      );
    }
  }

  final TextStyle _defaultTextStyle = TextStyle(
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

  Widget _getCommunityChild(String iconName, String txt, String queryJsonPath){
    String iconPath= AssetConstant.APP_IMAGE_COMMUNITY_DIR+ iconName;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          dynamic commonInfoJsonObj= HttpHelper.queryCommonInfo();
          if(null== commonInfoJsonObj){
            final snackBar = SnackBar(content: Text(_SText.get(_SText.COMMON_URL_NOT_FOUND)));
            ScaffoldMessenger.of(context).showSnackBar(snackBar);
            return;
          }
          UrlLauncher.launch(commonInfoJsonObj[queryJsonPath] as String);
        },
        child: Container(
          padding: const EdgeInsets.all(1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AspectRatio(
                  aspectRatio: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image(
                      image: AssetImage(iconPath),
                      fit: BoxFit.fitWidth,
                    ),
                  ),
              ),
              Text(txt, style: _defaultTextStyle.copyWith(fontSize: 14),),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        ToggleButtons(
          children: <Widget>[
            Icon(Icons.ac_unit),
          ],
          onPressed: (int index) {
            setState(() {
              UserConfig.saveBool(UserConfig.IS_ACTIVE_MAIN_LANGUAGE,
                  !UserConfig.getBool(UserConfig.IS_ACTIVE_MAIN_LANGUAGE));
            });
          },
          isSelected: <bool>[UserConfig.getBool(UserConfig.IS_ACTIVE_MAIN_LANGUAGE)],
        ),
        ToggleButtons(
          children: <Widget>[
            Icon(Icons.mail),
          ],
          onPressed: (int index) {
            setState(() {
              UserConfig.saveBool(UserConfig.IS_ACTIVE_SUB_LANGUAGE,
                  !UserConfig.getBool(UserConfig.IS_ACTIVE_SUB_LANGUAGE));
            });
          },
          isSelected: <bool>[UserConfig.getBool(UserConfig.IS_ACTIVE_SUB_LANGUAGE)],
        ),
      ],),
      Expanded(child: Container()),
    ],);
    ButtonStyle _normalBtnStyle= ElevatedButton.styleFrom(
      padding: EdgeInsets.all(5),
      primary: Colors.redAccent,
      textStyle: _defaultTextStyle,
    );
    /*
    return Scaffold(
      body: Row(children: [
        Expanded(flex: 2, child: Card(
          shadowColor: Colors.greenAccent,
          elevation: 7,
          color: Colors.white70,
          margin: const EdgeInsets.all(5),
          child: Stack(
            children: [
              DefaultTextStyle.merge(
                style: _defaultTextStyle,
                child: Container(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Text(_SText.get(_SText.LEFT_SIDE_TITLE))),
                      Container(
                        decoration: _headerBoxDecoration,
                        child: Container(
                          padding: EdgeInsets.all(3),
                          width: double.infinity,
                          child: Text("Ng??n ng????????????"),
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
                              UserConfig.saveBool(UserConfig.IS_ACTIVE_MAIN_LANGUAGE, false);
                              UserConfig.saveBool(UserConfig.IS_ACTIVE_SUB_LANGUAGE, true);
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
                              UserConfig.saveBool(UserConfig.IS_ACTIVE_MAIN_LANGUAGE, true);
                              UserConfig.saveBool(UserConfig.IS_ACTIVE_SUB_LANGUAGE, false);
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
                              ? _SText.get(_SText.GAME_TITLE_READY)
                              : _SText.get(_SText.GAME_TITLE_NOT_READY)),
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
                          style: _normalBtnStyle.copyWith(
                              backgroundColor: MaterialStateProperty.all(Colors.green)),
                          child: Text(_SText.get(_SText.GAME_GOTO_RESOURCE_SCREEN)),
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
                              _checkIsFinishAllEnding();
                            });
                          },
                          style: _normalBtnStyle,
                          child: Text(_SText.get(_SText.GAME_START)),
                        ),
                        if(_isGameResourceReady) SizedBox(width: 5,),
                        if(_isGameResourceReady) ElevatedButton(
                          onPressed: (){
                            if(!SavesInfo.haveCurrentData()){return;}
                            Navigator.push(context,
                              MaterialPageRoute(builder: (context) => MyApp(
                                command: StartAppCommand.LOAD_LAST_SAVE,
                              )),
                            ).whenComplete(() {
                              _checkResourceInternal();
                              _checkIsFinishAllEnding();
                            });
                          },
                          style: SavesInfo.haveCurrentData()
                              ? _normalBtnStyle
                              : _normalBtnStyle.copyWith(backgroundColor:
                                MaterialStateProperty.all(Colors.grey)),
                          child: Text(_SText.get(_SText.GAME_CONTINUE)),
                        ),
                      ],),
                      Row(children: [
                        if(_isGameResourceReady) SizedBox(width: 5,),
                        if(_isGameResourceReady) ElevatedButton(
                          onPressed: (){
                            Navigator.push(context,
                              MaterialPageRoute(builder: (context) => MyApp(
                                file: ScriptItem.GUIDE_SCRIPT_NAME,
                                command: StartAppCommand.RUN_SCRIPT,
                              )),
                            );
                          },
                          style: _normalBtnStyle.copyWith(
                              backgroundColor: MaterialStateProperty.all(Colors.blueAccent)),
                          child: Text(_SText.get(_SText.GAME_GUIDE)),
                        ),
                        SizedBox(width: 5,),
                        ElevatedButton(
                          onPressed: (){
                            dynamic gameInfoJsonObj= HttpHelper.queryGameInfo();
                            if(null== gameInfoJsonObj){
                              final snackBar = SnackBar(content: Text(_SText.get(_SText.COMMON_URL_NOT_FOUND)));
                              ScaffoldMessenger.of(context).showSnackBar(snackBar);
                              return;
                            }
                            UrlLauncher.launch(gameInfoJsonObj["bug_report_url"] as String);
                          },
                          style: _normalBtnStyle.copyWith(
                              backgroundColor: MaterialStateProperty.all(Color(0xFFBF360C))),
                          child: Text(_SText.get(_SText.GAME_BUG_REPORT)),
                        ),
                        SizedBox(width: 5,),
                        ElevatedButton(
                          onPressed: (){
                            SavesInfo fakeSave= SavesInfo.loadCurrentData();
                            if(!fakeSave.checkVariable(ScriptCommandInfo(
                                "check; exp=null != ed1 && null != ed2"))){
                              Widget okButton = TextButton(
                                child: Text("OK"),
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                              );

                              // show the dialog
                              showDialog(
                                context: context,
                                builder: (BuildContext inContext) {
                                  return AlertDialog(
                                    title: Text(_SText.get(_SText.COMMON_END_GAME_TITLE)),
                                    content: Text(_SText.get(_SText.COMMON_NOT_END_GAME_WARNING)),
                                    actions: [
                                      okButton,
                                    ],
                                  );
                                },
                              );
                              return;
                            }
                            dynamic gameInfoJsonObj= HttpHelper.queryGameInfo();
                            if(null== gameInfoJsonObj){
                              final snackBar = SnackBar(content: Text(_SText.get(_SText.COMMON_URL_NOT_FOUND)));
                              ScaffoldMessenger.of(context).showSnackBar(snackBar);
                              return;
                            }
                            UrlLauncher.launch(gameInfoJsonObj["survey_url"] as String);
                          },
                          style: _normalBtnStyle.copyWith(
                              backgroundColor: MaterialStateProperty.all(Colors.blueAccent)),
                          child: Text(_SText.get(_SText.GAME_SURVEY)),
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
        Expanded(child: Card(
          shadowColor: Colors.pinkAccent,
          elevation: 7,
          color: Colors.white70,
          margin: const EdgeInsets.all(5),
          child: DefaultTextStyle.merge(
            style: _defaultTextStyle,
            child: Container(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Text(_SText.get(_SText.RIGHT_SIDE_TITLE))),
                    Expanded(child: ListView(
                      children: [
                        Row(children: [
                          _getCommunityChild("website.png", "Website", "website_hoshi"),
                          _getCommunityChild("discord.png", "Discord", "discord_hoshi"),
                        ],),
                        Row(children: [
                          _getCommunityChild("facebook.png", "Fanpage", "hoshi_fb_fanpage"),
                          _getCommunityChild("group.png", "FB group", "visul_novel_group_fb"),
                        ],),
                      ],
                    )),
                  ],
                )
            ),
          ),
        )),
      ],),
    );
    */
  }

  @override
  void dispose() {
    Hive.close();
    super.dispose();
  }
}