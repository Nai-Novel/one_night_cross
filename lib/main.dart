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
import 'package:flutter_archive/flutter_archive.dart';
import 'package:url_launcher/url_launcher.dart' as UrlLauncher;

void main() {
  //Let device allow app to set Orientation
  WidgetsFlutterBinding.ensureInitialized();
  //Initialize StorageHelper
  StorageHelper.init().whenComplete(() {
    //Set game orientation then run MyApp
    //TODO: Set native device orientation if need
    SystemChrome.setPreferredOrientations(GameConstant.GAME_ORIENTATION)
        .whenComplete(() => runApp(
        MaterialApp(//theme: ThemeData(fontFamily: 'Raleway'),
          home: InitWidget(),//backgroundColor: Colors.black,
        )),
    );
  });
}

class InitWidget extends StatefulWidget {
  @override
  _InitWidgetState createState() => _InitWidgetState();
}
class _InitWidgetState extends State<InitWidget> {
  List<String> _storagePathList = <String>[];
  ValueNotifier<String> _progressString= ValueNotifier<String>(GameText.SPLASH_GAME_RESOURCE_NOT_READY);
  ValueNotifier<bool> _hashCheckResult= ValueNotifier<bool>(false);
  ValueNotifier<List<String>> _displayGuide= ValueNotifier<List<String>>(<String>[]);
  List<String>? _listDownloadCommand;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(LifecycleEventHandler());
    for (Directory oneAppDir in StorageHelper.APP_DIRECTORY_ON_DEVICE) {
      _storagePathList.add(oneAppDir.path);
    }
    checkFileHash();
  }
  void autoUpdateFile(){
    HttpProcessor.getUpdateFileListCommand().then((result) {
      if(!Directory(UserConfig.get(UserConfig.GAME_ASSETS_FOLDER)).existsSync()){
        return;
      }
      for(String aCommand in result){
        ScriptCommandInfo commandInfo= ScriptCommandInfo(aCommand);
        String dirPath= CommonFunc.buildPath(
            [UserConfig.get(UserConfig.GAME_ASSETS_FOLDER),
              commandInfo.valueOf("path")!]);
        if(!Directory(dirPath).existsSync()){
          continue;
        }

        String filePath= CommonFunc.buildPath(
            [UserConfig.get(UserConfig.GAME_ASSETS_FOLDER),
              commandInfo.valueOf("path")!,
              commandInfo.valueOf("name")!.replaceAll("{.,}", ";")]);
        CommonFunc.checkMd5File(filePath,
            commandInfo.valueOf("md5")!.substring(0, 16),
            commandInfo.valueOf("md5")!.substring(16)).then((result) {
          if(!result){
            Dio().download(commandInfo.valueOf("url")!, filePath+ ".downloading").then((response) {
              if(response.statusCode== HttpProcessor.STATUS_CODE_OK){
                File oldFile= File(filePath);
                oldFile.exists().then((isExist) {
                  if(isExist){
                    File(filePath).delete().whenComplete(() {
                      File(filePath+ ".downloading").rename(filePath);
                    });
                  }else{
                    File(filePath+ ".downloading").rename(filePath);
                  }
                });

              }
            });
          }
        });
      }
    });
  }
  void checkFileHash() {
    _hashCheckResult.value= true;
    //if(UserConfig.get(UserConfig.GAME_ASSETS_FOLDER).length> 0){
    //  String filePath= AssetConstant.getTruePath(AssetConstant.CHECK_HASH_FILE_PATH);
    //  CommonFunc.checkMd5File(filePath, "A60226EB91F11F4F", "1DFE28C090CA0F11").then((result) {
    //    _hashCheckResult.value= result;
    //    if(result){
    //      _progressString.value= GameText.SPLASH_GAME_RESOURCE_READY;
    //      autoUpdateFile();
    //    }else{
    //      _progressString.value= GameText.SPLASH_GAME_RESOURCE_NOT_READY;
    //    }
    //  });
    //}else{
    //  _hashCheckResult.value= false;
    //  _progressString.value= GameText.SPLASH_GAME_RESOURCE_NOT_READY;
    //}
  }
  void startDownloadResource(){
    if(_listDownloadCommand!.length> 0){
      ScriptCommandInfo commandInfo= ScriptCommandInfo(_listDownloadCommand!.removeAt(0));
      final String rarFilePath= CommonFunc.buildPath(
          [UserConfig.get(UserConfig.GAME_ASSETS_FOLDER),
            AssetConstant.RESOURCE_DOWNLOAD_DIR,
            commandInfo.valueOf("name")!]);
      Dio().download(commandInfo.valueOf("url")!, rarFilePath, onReceiveProgress: (rec, total){
        _progressString.value= "${GameText.SPLASH_GAME_RESOURCE_DOWNLOADING}:"
            " ${(rec/ 1000000).toStringAsFixed(1)}Mb / ${_listDownloadCommand!.length+ 1} files";
      }).then((response) {
        if(response.statusCode== HttpProcessor.STATUS_CODE_OK){
          decompress(rarFilePath);
        }
      });
    }else{
      _listDownloadCommand= null;
      checkFileHash();
    }
  }

  void decompress(String filePath) {
    final File zipFile = File(filePath);
    final Directory destinationDir = Directory(UserConfig.get(UserConfig.GAME_ASSETS_FOLDER));
    try {
      ZipFile.extractToDirectory(
          zipFile: zipFile,
          destinationDir: destinationDir,
          onExtracting: (zipEntry, progress) {
            _progressString.value= "${GameText.SPLASH_GAME_RESOURCE_EXTRACTING}:"
                " ${progress.toStringAsFixed(1)}% / ${_listDownloadCommand!.length+ 1} files.";
            if(progress>= 100){
              zipFile.delete().whenComplete(() {
                startDownloadResource();
              });
            }
            return ZipFileOperation.includeItem;
          }
      );
    } catch (e) {
      print(e);
    }
  }

  final Widget _normalStar= Image.asset("assets/app/image/stage_splash/star.png", height: GameConstant.SPLASH_DEFAULT_TEXT_STYLE.fontSize,);
  final Widget _transparentStar= Image.asset("assets/app/image/stage_splash/star.png", color: Colors.transparent, height: GameConstant.SPLASH_DEFAULT_TEXT_STYLE.fontSize,);
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
  late EdgeInsets _btnPaddingSize;
  final SizedBox _rowSpacing= const SizedBox(width: 0, height: 5,);
  final SizedBox _btnSpacing= const SizedBox(width: 12, height: 0,);
  final Container _horizontalLine= Container(
    color: Colors.black,
    child: Container(
      padding: const EdgeInsets.all(1),
      color: Colors.white,
    ),
  );
  final double _btnHeight= GameConstant.SPLASH_DEFAULT_TEXT_STYLE.fontSize!* 1.7;
  @override
  Widget build(BuildContext context) {
    _btnPaddingSize= EdgeInsets.only(left: 10, right: 10,
        top: GameConstant.SPLASH_DEFAULT_TEXT_STYLE.fontSize!*
            (UserConfig.get(UserConfig.MENU_LANGUAGE) == Language.JAPANESE ? 0 : 0.35));
    return Stack(
      children: [
        Positioned(
          left: 0, top: 0, right: 0, bottom: 0,
          child: Image.asset("assets/app/image/stage_splash/background.png"),
        ),
        Align(
          alignment: Alignment.center,
          child: AspectRatio(
            aspectRatio: 16/9,
            child: Column(
              children: [
                const Spacer(),
                Expanded(flex: 7, child: Row(
                  children: [
                    const Spacer(),
                    Expanded(flex: 10, child: Row(
                      children: [
                        Expanded(flex: 7, child: Column(//Main
                          children: [
                            Row(
                              children: [
                                _normalStar,
                                if(UserConfig.get(UserConfig.GAME_ASSETS_FOLDER).length== 0)
                                  Text(GameText.SPLASH_CHOOSE_STORAGE_LABEL,
                                    style: GameConstant.SPLASH_DEFAULT_TEXT_STYLE.copyWith(decoration: TextDecoration.underline),),
                                if(UserConfig.get(UserConfig.GAME_ASSETS_FOLDER)== _storagePathList[0])
                                  Text(GameText.SPLASH_STORAGE_LABEL_CHOSEN+ GameText.SPLASH_CHOOSE_STORAGE_INTERNAL_STORAGE,
                                    style: GameConstant.SPLASH_DEFAULT_TEXT_STYLE.copyWith(decoration: TextDecoration.underline, color: Colors.greenAccent),),
                                if(_storagePathList.length> 1 && UserConfig.get(UserConfig.GAME_ASSETS_FOLDER)== _storagePathList[1])
                                  Text(GameText.SPLASH_STORAGE_LABEL_CHOSEN+ GameText.SPLASH_CHOOSE_STORAGE_EXTERNAL_STORAGE,
                                    style: GameConstant.SPLASH_DEFAULT_TEXT_STYLE.copyWith(decoration: TextDecoration.underline, color: Colors.greenAccent),),
                                if(_storagePathList.length> 2 && UserConfig.get(UserConfig.GAME_ASSETS_FOLDER)== _storagePathList[2])
                                  Text(GameText.SPLASH_STORAGE_LABEL_CHOSEN+ "USB",
                                    style: GameConstant.SPLASH_DEFAULT_TEXT_STYLE.copyWith(decoration: TextDecoration.underline, color: Colors.greenAccent),),
                                if(UserConfig.get(UserConfig.GAME_ASSETS_FOLDER).length> 0) GestureDetector(
                                  child: const Text('  [+]', style: GameConstant.SPLASH_DEFAULT_TEXT_STYLE),
                                  onTap: (){
                                    UserConfig.save(UserConfig.GAME_ASSETS_FOLDER, "");
                                    checkFileHash();
                                    setState(() {});
                                  },
                                ),
                                GestureDetector(
                                  child: const Text('  [?]', style: GameConstant.SPLASH_DEFAULT_TEXT_STYLE),
                                  onTap: (){
                                    showDialog(
                                      context: context,
                                      builder: (cText){
                                        return GestureDetector(
                                          child: Image.asset("assets/app/image/stage_splash/pop_up_notify_storage.png"),
                                          onTap: (){
                                            Navigator.pop(cText);
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                            _rowSpacing,
                            if(UserConfig.get(UserConfig.GAME_ASSETS_FOLDER).length== 0) Row(
                              children: [
                                _transparentStar,
                                GestureDetector(
                                  onTap: (){
                                    UserConfig.save(UserConfig.GAME_ASSETS_FOLDER, _storagePathList[0]);
                                    checkFileHash();
                                    setState(() {});
                                  },
                                  child: Container(
                                    height: _btnHeight,
                                    decoration: _greenBtnDecoration,
                                    child: Padding(
                                      padding: _btnPaddingSize,
                                      child: Text(GameText.SPLASH_CHOOSE_STORAGE_INTERNAL_STORAGE, style: GameConstant.SPLASH_DEFAULT_TEXT_STYLE),
                                    ),
                                  ),
                                ),
                                _btnSpacing,
                                if(_storagePathList.length> 1) GestureDetector(
                                  onTap: (){
                                    UserConfig.save(UserConfig.GAME_ASSETS_FOLDER, _storagePathList[1]);
                                    checkFileHash();
                                    setState(() {});
                                  },
                                  child: Container(
                                    height: _btnHeight,
                                    decoration: _greenBtnDecoration,
                                    child: Padding(
                                      padding: _btnPaddingSize,
                                      child: Text(GameText.SPLASH_CHOOSE_STORAGE_EXTERNAL_STORAGE, style: GameConstant.SPLASH_DEFAULT_TEXT_STYLE),
                                    ),
                                  ),
                                ),
                                _btnSpacing,
                                if(_storagePathList.length> 2) GestureDetector(
                                  onTap: (){
                                    UserConfig.save(UserConfig.GAME_ASSETS_FOLDER, _storagePathList[2]);
                                    checkFileHash();
                                    setState(() {});
                                  },
                                  child: Container(
                                    height: _btnHeight,
                                    decoration: _greenBtnDecoration,
                                    child: Padding(
                                      padding: _btnPaddingSize,
                                      child: const Text(' USB ', style: GameConstant.SPLASH_DEFAULT_TEXT_STYLE),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            _rowSpacing,
                            Row(
                              children: [
                                _normalStar,
                                Text(GameText.SPLASH_GAME_RESOURCE, style: GameConstant.SPLASH_DEFAULT_TEXT_STYLE.copyWith(decoration: TextDecoration.underline),),
                                GestureDetector(
                                  child: const Text('  [?]', style: GameConstant.SPLASH_DEFAULT_TEXT_STYLE),
                                  onTap: (){
                                    showDialog(
                                      context: context,
                                      builder: (cText){
                                        return GestureDetector(
                                          child: Image.asset("assets/app/image/stage_splash/pop_up_notify_auto_download.png"),
                                          onTap: (){
                                            Navigator.pop(cText);
                                          },
                                        );
                                      },
                                    ).whenComplete(() {
                                      showDialog(
                                        context: context,
                                        builder: (cText){
                                          return GestureDetector(
                                            child: Stack(children: [
                                              Positioned(
                                                child: Image.asset("assets/app/image/stage_splash/pop_up_notify_manual_download.png", fit: BoxFit.fill,),
                                                top: 0, bottom: 0, left: 0, right: 0,
                                              ),
                                              Column(children: [
                                                const Spacer(flex: 840,),
                                                Expanded(
                                                  flex: 600,
                                                  child: Row(children: [
                                                    const Spacer(flex: 410,),
                                                    Expanded(
                                                      flex: 1740,
                                                      child: Align(
                                                        alignment: Alignment.topLeft,
                                                        child: Text(UserConfig.get(UserConfig.GAME_ASSETS_FOLDER),
                                                          style: GameConstant.SPLASH_SIMPLE_TEXT_STYLE,),
                                                      ),
                                                    ),
                                                    const Spacer(flex: 410,),
                                                  ],),
                                                ),
                                              ],),
                                            ],),
                                            onTap: (){
                                              Navigator.pop(cText);
                                            },
                                          );
                                        },
                                      );
                                    });
                                  },
                                ),
                              ],
                            ),
                            _rowSpacing,
                            if(UserConfig.get(UserConfig.GAME_ASSETS_FOLDER).length> 0) Row(
                              children: [
                                _transparentStar,
                                GestureDetector(
                                  onTap: (){
                                    if(_listDownloadCommand!= null){return;}
                                    HttpProcessor.getResourceCommand().then((result) {
                                      String dirPath= CommonFunc.buildPath(
                                          [UserConfig.get(UserConfig.GAME_ASSETS_FOLDER),
                                            AssetConstant.RESOURCE_DOWNLOAD_DIR]);
                                      Directory zipDir= Directory(dirPath);
                                      if(!zipDir.existsSync()){
                                        zipDir.createSync(recursive: true);
                                      }

                                      for(String aCommand in result){
                                        ScriptCommandInfo commandInfo= ScriptCommandInfo(aCommand);
                                        String filePath= CommonFunc.buildPath(
                                            [UserConfig.get(UserConfig.GAME_ASSETS_FOLDER),
                                              AssetConstant.RESOURCE_DOWNLOAD_DIR,
                                              commandInfo.valueOf("name")!]);
                                        if(File(filePath).existsSync()){
                                          File(filePath).deleteSync();
                                        }
                                      }

                                      _listDownloadCommand= <String>[];
                                      for(String aCommand in result){
                                        _listDownloadCommand!.add(aCommand);
                                      }
                                      setState(() {});
                                      startDownloadResource();
                                    });
                                  },
                                  child: Container(
                                    height: _btnHeight,
                                    decoration: _listDownloadCommand== null ? _greenBtnDecoration : _greyBtnDecoration,
                                    child: Padding(
                                      padding: _btnPaddingSize,
                                      child: Text(GameText.SPLASH_GAME_RESOURCE_AUTO_DOWNLOAD, style: GameConstant.SPLASH_DEFAULT_TEXT_STYLE),
                                    ),
                                  ),
                                ),
                                _btnSpacing,
                                GestureDetector(
                                  onTap: (){
                                    //HttpProcessor.openLinkByName("resource_link_manual");
                                    Navigator.push(context,
                                      MaterialPageRoute(builder: (context) => GameResource()),
                                    );
                                  },
                                  child: Container(
                                    height: _btnHeight,
                                    decoration: _greenBtnDecoration,
                                    child: Padding(
                                      padding: _btnPaddingSize,
                                      child: Text(GameText.SPLASH_GAME_RESOURCE_MANUAL_DOWNLOAD, style: GameConstant.SPLASH_DEFAULT_TEXT_STYLE),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            _rowSpacing,
                            Row(
                              children: [
                                _normalStar,
                                ValueListenableBuilder(
                                  valueListenable: _progressString,
                                  builder: (context, progress, childWidget){
                                    return Text(progress as String, style: GameConstant.SPLASH_DEFAULT_TEXT_STYLE.copyWith(decoration: TextDecoration.underline),);
                                  },
                                ),
                              ],
                            ),
                            _rowSpacing,
                            ValueListenableBuilder(
                              valueListenable: _hashCheckResult,
                              builder: (context, checkResult, childWidget){
                                return Row(
                                  children: [
                                    _transparentStar,
                                    GestureDetector(
                                      onTap: checkResult as bool ? (){
                                        Navigator.push(context,
                                          MaterialPageRoute(builder: (context) => MyApp(
                                            file: ScriptItem.SPLASH_SCRIPT_NAME,
                                            command: StartAppCommand.RUN_SCRIPT,
                                          )),
                                        ).whenComplete(() {
                                          setState(() {});
                                        });
                                      } : null,
                                      child: Container(
                                        height: _btnHeight,
                                        decoration: BoxDecoration(
                                          image: DecorationImage(
                                            image: AssetImage(checkResult
                                                ? 'assets/app/image/stage_splash/btn_bg_orange.png'
                                                : 'assets/app/image/stage_splash/btn_bg_grey.png'),
                                            fit: BoxFit.fill,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: _btnPaddingSize,
                                          child: Text(GameText.SPLASH_GAME_READY_START, style: GameConstant.SPLASH_DEFAULT_TEXT_STYLE),
                                        ),
                                      ),
                                    ),
                                    _btnSpacing,
                                    GestureDetector(
                                      onTap: checkResult && SavesInfo.haveCurrentData() ? (){
                                        Navigator.push(context,
                                          MaterialPageRoute(builder: (context) => MyApp(
                                            command: StartAppCommand.LOAD_LAST_SAVE,
                                          )),
                                        ).whenComplete(() {
                                          setState(() {});
                                        });
                                      } : null,
                                      child: Container(
                                        height: _btnHeight,
                                        decoration: BoxDecoration(
                                          image: DecorationImage(
                                            image: AssetImage(checkResult && SavesInfo.haveCurrentData()
                                                ? 'assets/app/image/stage_splash/btn_bg_orange.png'
                                                : 'assets/app/image/stage_splash/btn_bg_grey.png'),
                                            fit: BoxFit.fill,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: _btnPaddingSize,
                                          child: Text(GameText.SPLASH_GAME_READY_LOAD_LAST_SAVE, style: GameConstant.SPLASH_DEFAULT_TEXT_STYLE),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            _rowSpacing,
                            Row(
                              children: [
                                _transparentStar,
                                GestureDetector(
                                  onTap: (){
                                    _displayGuide.value.add("assets/app/image/guide/guide1.png");
                                    _displayGuide.value.add("assets/app/image/guide/guide2.png");
                                    _displayGuide.value.add("assets/app/image/guide/guide3.png");
                                    _displayGuide.value.add("assets/app/image/guide/guide4.png");
                                    _displayGuide.value.add("assets/app/image/guide/guide5.png");
                                    _displayGuide.notifyListeners();
                                  },
                                  child: Container(
                                    height: _btnHeight,
                                    decoration: const BoxDecoration(
                                      image: const DecorationImage(
                                        image: const AssetImage('assets/app/image/stage_splash/btn_bg_red.png'),
                                        fit: BoxFit.fill,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: _btnPaddingSize,
                                      child: Text(GameText.SPLASH_GAME_USER_GUIDE, style: GameConstant.SPLASH_DEFAULT_TEXT_STYLE),
                                    ),
                                  ),
                                ),
                                _btnSpacing,
                                GestureDetector(
                                  onTap: (){
                                    HttpProcessor.openLinkByName("report");
                                  },
                                  child: Container(
                                    height: _btnHeight,
                                    decoration: const BoxDecoration(
                                      image: const DecorationImage(
                                        image: const AssetImage('assets/app/image/stage_splash/btn_bg_red.png'),
                                        fit: BoxFit.fill,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: _btnPaddingSize,
                                      child: Text(GameText.SPLASH_GAME_BUG_REPORT, style: GameConstant.SPLASH_DEFAULT_TEXT_STYLE),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),),
                        Expanded(flex: 3, child: Column(
                          children: [
                            Text(GameText.SPLASH_COMMUNITY, style: GameConstant.SPLASH_DEFAULT_TEXT_STYLE),
                            _horizontalLine,
                            _rowSpacing,
                            Row(
                              children: [
                                const Spacer(),
                                Expanded(flex: 4, child: GestureDetector(
                                  child: Image.asset("assets/app/image/community/facebook.png"),
                                  onTap: (){
                                    HttpProcessor.openLinkByName("facebook_fanpage");
                                  },
                                )),
                                const Spacer(),
                                Expanded(flex: 4, child: GestureDetector(
                                  child: Image.asset("assets/app/image/community/website.png"),
                                  onTap: (){
                                    HttpProcessor.openLinkByName("website");
                                  },
                                )),
                                const Spacer(),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(child: Center(
                                  child: Text(GameText.SPLASH_COMMUNITY_FACEBOOK_FANPAGE, style: GameConstant.SPLASH_COMMUNITY_TEXT_STYLE),
                                )),
                                Expanded(child: Center(
                                  child: Text(GameText.SPLASH_COMMUNITY_WEBSITE, style: GameConstant.SPLASH_COMMUNITY_TEXT_STYLE),
                                )),
                              ],
                            ),
                            Row(
                              children: [
                                const Spacer(),
                                Expanded(flex: 4, child: GestureDetector(
                                  child: Image.asset("assets/app/image/community/group.png"),
                                  onTap: (){
                                    HttpProcessor.openLinkByName("facebook_group");
                                  },
                                )),
                                const Spacer(),
                                Expanded(flex: 4, child: GestureDetector(
                                  child: Image.asset("assets/app/image/community/discord.png"),
                                  onTap: (){
                                    HttpProcessor.openLinkByName("discord");
                                  },
                                )),
                                const Spacer(),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(child: Center(
                                  child: Text(GameText.SPLASH_COMMUNITY_FACEBOOK_GROUP, style: GameConstant.SPLASH_COMMUNITY_TEXT_STYLE),
                                )),
                                Expanded(child: Center(
                                  child: Text(GameText.SPLASH_COMMUNITY_DISCORD, style: GameConstant.SPLASH_COMMUNITY_TEXT_STYLE),
                                )),
                              ],
                            ),
                            _btnSpacing,
                            Align(
                              alignment: Alignment.topCenter,
                              child: GestureDetector(
                                onTap: (){
                                  HttpProcessor.openLinkByName("survey");
                                },
                                child: Container(
                                  height: _btnHeight,
                                  decoration: const BoxDecoration(
                                    image: const DecorationImage(
                                      image: const AssetImage('assets/app/image/stage_splash/btn_bg_blue.png'),
                                      fit: BoxFit.fill,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: _btnPaddingSize,
                                    child: Text(GameText.SPLASH_HELP_US_SURVEY, style: GameConstant.SPLASH_DEFAULT_TEXT_STYLE),
                                  ),
                                ),
                              ),
                            ),
                            _btnSpacing,
                            Align(
                              alignment: Alignment.topCenter,
                              child: GestureDetector(
                                onTap: (){
                                  HttpProcessor.openLinkByName("donate");
                                },
                                child: Container(
                                  height: _btnHeight,
                                  decoration: const BoxDecoration(
                                    image: const DecorationImage(
                                      image: const AssetImage('assets/app/image/stage_splash/btn_bg_blue.png'),
                                      fit: BoxFit.fill,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: _btnPaddingSize,
                                    child: Text(GameText.SPLASH_HELP_US_DONATE, style: GameConstant.SPLASH_DEFAULT_TEXT_STYLE),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),),
                      ],
                    ),),
                    const Spacer(),
                  ],
                ),),
              ],
            ),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: _displayGuide,
          builder: (context, guideList, childWidget){
            if((guideList as List<String>).length> 0){
              return Container(
                color: Colors.black45,
                child: GestureDetector(
                  onTap: (){
                    _displayGuide.value.removeAt(0);
                    _displayGuide.notifyListeners();
                  },
                  child: Image.asset(guideList.first),
                ),
              );
            }
            return Container();
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    Hive.close();
    super.dispose();
  }
}

class HttpProcessor{
  static const int STATUS_CODE_OK= 200;

  static String getFileContentFromRespond(String htmlRespond){
    String contentNeeded= htmlRespond.substring(htmlRespond.indexOf(">"));
    contentNeeded= contentNeeded.substring(1, contentNeeded.indexOf("<"));
    return contentNeeded;
  }

  static Future<List<String>> getResourceCommand(){
    Completer<List<String>> completer = new Completer<List<String>>();
    List<String> ret= <String>[];
    bool start= false;

    Dio().get("https://notepad.pw/raw/cozau3jn1").then((response) {
      if(response.statusCode!= STATUS_CODE_OK){return;}
      List<String> commandList= getFileContentFromRespond(response.data.toString()).split("\n");

      for(String aCommand in commandList){
        if(aCommand.startsWith("//") || aCommand.length== 0){
          if(aCommand.startsWith("//hoshi_higu1_resource_start")){
            start= true;
          }
          if(aCommand.startsWith("//hoshi_higu1_resource_end")){
            start= false;
          }
          continue;
        }
        if(!start){continue;}
        final ScriptCommandInfo commandInfo= ScriptCommandInfo(aCommand);
        if(commandInfo.header== "file"){
          ret.add(aCommand);
        }
      }
      completer.complete(ret);
    });

    return completer.future;
  }

  static Future<List<String>> getUpdateFileListCommand(){
    Completer<List<String>> completer = new Completer<List<String>>();
    List<String> ret= <String>[];
    bool start= false;

    Dio().get("https://notepad.pw/raw/2z50ny3zc").then((response) {
      if(response.statusCode!= STATUS_CODE_OK){return;}
      List<String> commandList= getFileContentFromRespond(response.data.toString()).split("\n");

      for(String aCommand in commandList){
        if(aCommand.startsWith("//") || aCommand.length== 0){
          if(aCommand.startsWith("//hoshi_higu1_update_file_start")){
            start= true;
          }
          if(aCommand.startsWith("//hoshi_higu1_update_file_end")){
            start= false;
          }
          continue;
        }
        if(!start){continue;}
        final ScriptCommandInfo commandInfo= ScriptCommandInfo(aCommand);
        if(commandInfo.header== "file"){
          ret.add(aCommand);
        }
      }
      completer.complete(ret);
    });

    return completer.future;
  }

  static void openLinkByName(final String name){
    Dio().get("https://notepad.pw/raw/gfzu226zy").then((response) {
      if(response.statusCode!= STATUS_CODE_OK){return;}
      bool start= false;
      List<String> commandList= getFileContentFromRespond(response.data.toString()).split("\n");

      for(String aCommand in commandList){
        if(aCommand.startsWith("//") || aCommand.length== 0){
          if(aCommand.startsWith("//hoshi_all_link_start")){
            start= true;
          }
          if(aCommand.startsWith("//hoshi_all_link_end")){
            start= false;
          }
          continue;
        }
        if(!start){continue;}
        final ScriptCommandInfo commandInfo= ScriptCommandInfo(aCommand);
        if(commandInfo.header== "link" && commandInfo.valueOf("name")== name){
          String url= commandInfo.valueOf("url")!;
          UrlLauncher.canLaunch(url).then((canLaunch) {
            if(canLaunch){
              UrlLauncher.launch(url);
            }
          });
        }
      }
    });
  }
}