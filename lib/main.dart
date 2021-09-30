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
    HttpHelper.getGameInfoJson();
    HttpHelper.getCommonOnlineInfo();
    //Set game orientation then run App
    //TODO: Set native device orientation if need
    SystemChrome.setPreferredOrientations(GameConstant.GAME_ORIENTATION)
        .whenComplete(() => runApp(MaterialApp(
      home: SafeArea(child: InitWidget(),),)),
    );
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

  static String get(String txt) {
    String lang= UserConfig.get(UserConfig.MENU_LANGUAGE);
    if (lang == Language.VIETNAMESE) {
      switch(txt) {
        case LEFT_SIDE_TITLE: return "Ứng dụng";
        case GAME_TITLE_NOT_READY: return "Dữ liệu game chưa sẵn sàng";
        case GAME_TITLE_READY: return "GAME!!!";
        case GAME_START: return "Bắt đầu";
        case GAME_CONTINUE: return "Tiếp tục";
        case GAME_GOTO_RESOURCE_SCREEN: return "Tải xuống dữ liệu";
        case GAME_GUIDE: return "Xem hướng dẫn";
        case GAME_BUG_REPORT: return "Báo lỗi";
        case GAME_SURVEY: return "Khảo sát";

        case RIGHT_SIDE_TITLE: return "Cộng đồng";
        case COMMON_URL_NOT_FOUND: return "Không tìm thấy đường dẫn";
        case COMMON_END_GAME_TITLE: return "Hoàn thành game";
        case COMMON_END_GAME_CONTENT: return "Cảm ơn bạn đã chơi hết toàn bộ game ONE NIGHT CROSS. Với ý định nung nấu bấy lâu về việc đưa Visual Novel đến với các bạn độc giả được dễ dàng hơn, chúng mình rất cần sự ủng hộ từ những người yêu thích thể loại này. Một vài dòng nhận xét của các bạn là vô cùng quý giá với chúng mình. Bấm vào nút \"Khảo sát\" ở bên dưới bạn nhé.";
      }
    }
    else if (lang == Language.JAPANESE) {
      switch(txt) {
        case LEFT_SIDE_TITLE: return "アプリケーション";
        case GAME_TITLE_NOT_READY: return "ゲームデータ未完成";
        case GAME_TITLE_READY: return "ゲーム！！！";
        case GAME_START: return "スタート";
        case GAME_CONTINUE: return "つづき";
        case GAME_GOTO_RESOURCE_SCREEN: return "ゲームデータダウンロード";
        case GAME_GUIDE: return "説明を見る";
        case GAME_BUG_REPORT: return "エラー報告";
        case GAME_SURVEY: return "アンケート";

        case RIGHT_SIDE_TITLE: return "コミュニティ";
        case COMMON_URL_NOT_FOUND: return "リンクが見つかりません";
        case COMMON_END_GAME_TITLE: return "ゲームクリア";
        case COMMON_END_GAME_CONTENT: return "ONE NIGHT CROSSをプレイしていただき、どうもありがとうございます。ビジュアルノベルをより簡単に読者に届けるという熱烈な意図を持って、私たちにとってこのジャンルに興味のある人々からのサポートが本当に必要です。 あなたのコメントの数行は私たちにとって非常に貴重です。 下の「アンケート」ボタンをクリックして頂いたら嬉しいです。";
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

  void _checkIsFinishAllEnding(){
    SavesInfo fakeSave= SavesInfo.loadCurrentData();
    if(fakeSave.checkVariable(ScriptCommandInfo(
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
    ButtonStyle _normalBtnStyle= ElevatedButton.styleFrom(
      padding: EdgeInsets.all(5),
      primary: Colors.redAccent,
      textStyle: _defaultTextStyle,
    );
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
                        SizedBox(width: 5,),
                        ElevatedButton(
                          onPressed: (){

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
  }

  @override
  void dispose() {
    Hive.close();
    super.dispose();
  }
}