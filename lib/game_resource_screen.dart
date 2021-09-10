import 'dart:async';
import 'dart:convert' as JSON;
import 'dart:io';
import 'dart:convert' as Convert;
import 'package:path/path.dart' as Path;

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_archive/flutter_archive.dart';

import 'com_cons.dart';
import 'http_helper.dart';
import 'storage_helper.dart';
import 'text_processor.dart';

class GameResource extends StatelessWidget {
  const GameResource({Key? key}) : super(key: key);

  static Future<bool> checkResource(){
    Completer<bool> completer = new Completer<bool>();
    String gameInfoJsonStr= Convert.utf8.decode(Convert.base64Decode(
        UserConfig.get(UserConfig.GAME_INFO_JSON)
    ));
    if(gameInfoJsonStr.length== 0){
      completer.complete(false);
      return completer.future;
    }
    List<dynamic> checkInfoListObject= JSON.jsonDecode(gameInfoJsonStr)
    ['resource_info']['credit_check_file'] as List<dynamic>;
    int validFileCount= 0;
    int checkedFileCount= 0;
    for(dynamic toCheckObj in checkInfoListObject){
      String filePath= AssetConstant.getTruePath(
          AssetConstant.ROOT_DIR+ toCheckObj['path']);
      String md5Str= toCheckObj['hash_md5'];
      CommonFunc.checkMd5File(filePath,
          md5Str.substring(0, 16),
          md5Str.substring(16)).then((result) {
        checkedFileCount++;
        if(result){validFileCount++;}
        if(checkedFileCount>= checkInfoListObject.length){
          completer.complete(validFileCount== checkedFileCount);
        }
      });
    }
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return GameResourceProgress();
  }
}

//GameResourceText
class _GRText{
  static const String STATE_HEADER = "STATE_HEADER";
  static const String STATE_READY = "STATE_READY";
  static const String STATE_NOT_READY = "STATE_NOT_READY";

  static const String STORAGE_HEADER = "STORAGE_HEADER";
  static const String STORAGE_NEED_CHOOSE = "STORAGE_NEED_CHOOSE";
  static const String STORAGE_PLEASE_CHOOSE = "STORAGE_PLEASE_CHOOSE";
  static const String STORAGE_CHOSEN = "STORAGE_CHOSEN";
  static const String STORAGE_INSIDE = "STORAGE_INSIDE";
  static const String STORAGE_OUTSIDE = "STORAGE_OUTSIDE";

  static const String DOWNLOAD_HEADER = "DOWNLOAD_HEADER";
  static const String DOWNLOAD_COMMAND_START = "DOWNLOAD_COMMAND_START";
  static const String DOWNLOAD_COMMAND_WAITING = "DOWNLOAD_PREPARING";
  static const String DOWNLOAD_DATA_REQUEST_FAILED = "DOWNLOAD_DATA_REQUEST_FAILED";
  static const String DOWNLOAD_DATA_REQUESTING = "DOWNLOAD_DATA_REQUESTING";
  static const String DOWNLOAD_PROCESSING = "DOWNLOAD_PROCESSING";
  static const String DOWNLOAD_EXTRACTING = "DOWNLOAD_EXTRACTING";
  static const String DOWNLOAD_ONE_FILE_DONE = "DOWNLOAD_ONE_FILE_DONE";
  static const String DOWNLOAD_ALL_DONE = "DOWNLOAD_ALL_DONE";

  static String decideStorageText(){
    return UserConfig.get(UserConfig.GAME_ASSETS_FOLDER).contains("/0/")
        ? get(STORAGE_INSIDE)
        : get(STORAGE_OUTSIDE);
  }

  static String get(String txt) {
    String lang= UserConfig.get(UserConfig.MENU_LANGUAGE);
    if (lang == Language.VIETNAMESE) {
      switch(txt) {
        case STATE_HEADER: return "Dữ liệu game: ";
        case STATE_READY: return "Sẵn sàng!";
        case STATE_NOT_READY: return "Chưa đầy đủ!";

        case STORAGE_HEADER: return "Vùng nhớ: ";
        case STORAGE_NEED_CHOOSE: return "Chưa chọn(Bấm để chọn)";
        case STORAGE_PLEASE_CHOOSE: return "Hãy lựa chọn vùng nhớ";
        case STORAGE_INSIDE: return "Bộ nhớ trong";
        case STORAGE_OUTSIDE: return "Bộ nhớ ngoài";

        case DOWNLOAD_HEADER: return "Tải xuống: ";
        case DOWNLOAD_COMMAND_START: return "Bắt đầu tải";
        case DOWNLOAD_COMMAND_WAITING: return "Đang chờ lệnh...";
        case DOWNLOAD_DATA_REQUEST_FAILED: return "Không tìm thấy dữ liệu tải xuống!";
        case DOWNLOAD_DATA_REQUESTING: return "Đang kết nối...";
        case DOWNLOAD_PROCESSING: return "Đang tải xuống: ";
        case DOWNLOAD_EXTRACTING: return "Giải nén: ";
        case DOWNLOAD_ONE_FILE_DONE: return "Đang tìm tệp kế tiếp...";
        case DOWNLOAD_ALL_DONE: return "Hoàn tất tải xuống. Đang xử lý dữ liệu...";
      }
    }
    else if (lang == Language.JAPANESE) {
      switch(txt) {
        case STATE_HEADER: return "ゲームデータ：";
        case STATE_READY: return "準備完了";
        case STATE_NOT_READY: return "未完成";

        case STORAGE_HEADER: return "ストレージ：";
        case STORAGE_NEED_CHOOSE: return "選んでください（クリック）";
        case STORAGE_PLEASE_CHOOSE: return "ストレージを選んでください";
        case STORAGE_INSIDE: return "内部メモリ";
        case STORAGE_OUTSIDE: return "外部メモリ";

        case DOWNLOAD_HEADER: return "ダウンロード";
        case DOWNLOAD_COMMAND_START: return "実行";
        case DOWNLOAD_COMMAND_WAITING: return "命令待機…";
        case DOWNLOAD_DATA_REQUEST_FAILED: return "ダウンロードリソース見つけません";
        case DOWNLOAD_DATA_REQUESTING: return "ネット接続中…";
        case DOWNLOAD_PROCESSING: return "ダウンロード中：";
        case DOWNLOAD_EXTRACTING: return "解凍中：";
        case DOWNLOAD_ONE_FILE_DONE: return "次のファイル待機…";
        case DOWNLOAD_ALL_DONE: return "ダウンロード完了、データ処理中…";
      }
    }
    return "";
  }
}

class GameResourceProgress extends StatefulWidget {
  static const Color PROGRESS_NOT_COMPLETE= Colors.orangeAccent;
  static const Color PROGRESS_COMPLETE= Colors.greenAccent;
  GameResourceProgress({Key? key}) : super(key: key);
  final _GameResourceProgressState _state= _GameResourceProgressState();

  @override
  _GameResourceProgressState createState() => _state;
}

class _GameResourceProgressState extends State<GameResourceProgress> {
  String _storageState= _GRText.STORAGE_NEED_CHOOSE;
  bool _resourceReady= false;
  ValueNotifier<String> _progressNotifier= ValueNotifier<String>(
      _GRText.get(_GRText.DOWNLOAD_COMMAND_WAITING));
  List<GRDownloadInfo>? _listDownloadInfo;

  bool _checkResourceInternal([bool refresh= true]){
    bool ret= false;
    if(UserConfig.get(UserConfig.GAME_ASSETS_FOLDER).length> 0){
      _storageState= _GRText.STORAGE_CHOSEN;
      ret= true;
    }else{
      _storageState= _GRText.STORAGE_NEED_CHOOSE;
    }
    GameResource.checkResource().then((value) {
      _resourceReady= value;
      setState(() {});
    });
    return ret;
  }

  Future<void> _decodeResource(){
    Completer<void> completer= Completer<void>();
    String gameResourceDir = AssetConstant.getTruePath(AssetConstant.ROOT_DIR);
    Directory(gameResourceDir).list(recursive: false).forEach((file) {
      String fileName= Path.basename(file.path);
      fileName= Convert.utf8.decode(Convert.base64Decode(fileName));
      String newFileNameStr= fileName.replaceAll("(=)", Platform.pathSeparator);
      String newFilePath= gameResourceDir+ newFileNameStr;
      if(!Directory(Path.dirname(newFilePath)).existsSync()){
        Directory(Path.dirname(newFilePath)).createSync(recursive: true);
      }
      File(file.path).copySync(newFilePath);
      File(file.path).deleteSync();
    }).whenComplete(() => completer.complete(null));
    return completer.future;
  }

  @override
  void initState() {
    _checkResourceInternal(false);
    super.initState();
  }

  @override
  Widget build(BuildContext rootContext) {
    BoxDecoration boxDecoration= BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Colors.black),
      borderRadius: BorderRadius.circular(3),
      gradient: LinearGradient(
        colors: [
          Color(0x889C37EB),
          Colors.white,
        ],
        stops: [0.1, 1],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.5),
          spreadRadius: 5,
          blurRadius: 7,
          offset: Offset(0, 3), // changes position of shadow
        ),
      ],
    );
    String readyText= _GRText.get(_GRText.STATE_HEADER)
        + _GRText.get(_GRText.STATE_READY);
    return Scaffold(
      appBar: AppBar(title: ValueListenableBuilder(
          valueListenable: _progressNotifier,
          builder: (context, value, child) {
            String progress= value as String;
            if(progress!= readyText){
              return Text(_GRText.get(_GRText.STATE_HEADER)
                  + _GRText.get(_GRText.STATE_NOT_READY));
            }
            return Text(readyText);
          },),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(rootContext),
        ),
        backgroundColor: !_resourceReady ? Colors.grey : null,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                showDialog(context: rootContext, builder: (inContext) {
                  List<Widget> listRadio= <Widget>[];
                  for(int i= 0; i< StorageHelper.APP_DIRECTORY_ON_DEVICE.length; i++){
                    final String dirPath= StorageHelper.APP_DIRECTORY_ON_DEVICE[i].path;
                    listRadio.add(RadioListTile<String>(
                      title: RichText(
                        textAlign: TextAlign.start,
                        text: TextSpan(
                          children: TextProcessor.buildSpanFromString(
                              "<color=000000>"+(i== 0
                                ? _GRText.get(_GRText.STORAGE_INSIDE)
                                : _GRText.get(_GRText.STORAGE_OUTSIDE))
                                  + "<br><size-=5>$dirPath</size>",
                              GameConstant.SPLASH_SIMPLE_TEXT_STYLE),
                        ),
                      ),
                      value: dirPath,
                      groupValue: UserConfig.get(UserConfig.GAME_ASSETS_FOLDER),
                      onChanged: (String? value) {
                        UserConfig.save(UserConfig.GAME_ASSETS_FOLDER, value!);
                        Navigator.pop(inContext);
                      },
                    ));
                  }
                  listRadio.add(ElevatedButton(
                    child: Text("OK"),
                    style: ElevatedButton.styleFrom(
                      primary: Colors.greenAccent,
                      onPrimary: Colors.black,
                    ),
                    onPressed: () {
                      Navigator.pop(inContext);
                    },
                  ));
                  return AlertDialog(
                    title: Text(_GRText.get(_GRText.STORAGE_PLEASE_CHOOSE)),
                    contentPadding: const EdgeInsets.fromLTRB(0, 10.0, 0, 0),
                    scrollable: true,
                    content: Column(
                      children: listRadio,
                    ),
                  );
                },).whenComplete(() {
                  _checkResourceInternal();
                });
              },
              child: Container(
                margin: EdgeInsets.all(8),
                padding: const EdgeInsets.all(8),
                decoration: boxDecoration,
                child: Container(
                  child: Column(
                    children: [
                      Text(_GRText.get(_GRText.STORAGE_HEADER),
                      style: GameConstant.SPLASH_SIMPLE_TEXT_STYLE,),
                      Text((_storageState== _GRText.STORAGE_NEED_CHOOSE
                          ? _GRText.get(_GRText.STORAGE_NEED_CHOOSE)
                          : _GRText.decideStorageText()) + ": "
                          + UserConfig.get(UserConfig.GAME_ASSETS_FOLDER)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              margin: EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: boxDecoration,
              child: Column(
                children: [
                  Text(_GRText.get(_GRText.DOWNLOAD_HEADER),
                    style: GameConstant.SPLASH_SIMPLE_TEXT_STYLE,),
                  ValueListenableBuilder(valueListenable: _progressNotifier,
                    builder: (context, value, child) {
                      String progressStr= value as String;
                      if(_GRText.get(_GRText.DOWNLOAD_ONE_FILE_DONE)== progressStr){
                        _listDownloadInfo!.removeAt(0);
                        if(_listDownloadInfo!.length> 0){
                          _listDownloadInfo![0].download(_progressNotifier);
                        }else{
                          WidgetsBinding.instance!.addPostFrameCallback((_) {
                            WidgetsFlutterBinding.ensureInitialized();
                            _progressNotifier.value= _GRText.get(
                                _GRText.DOWNLOAD_ALL_DONE);
                            _listDownloadInfo= null;
                          });
                        }
                      }
                      if(_GRText.get(_GRText.DOWNLOAD_ALL_DONE)== progressStr){
                        _decodeResource().whenComplete(() {
                          _progressNotifier.value=
                              _GRText.get(_GRText.STATE_HEADER)
                                  + _GRText.get(_GRText.STATE_READY);
                          _checkResourceInternal();
                        });
                      }
                      return Text(progressStr);
                  },),
                  ElevatedButton(
                      onPressed: () {
                        if(null!= _listDownloadInfo){return;}
                        if(UserConfig.get(UserConfig.GAME_ASSETS_FOLDER).length== 0){
                          ScaffoldMessenger.of(rootContext).showSnackBar(SnackBar(
                            content: Text(_GRText.get(_GRText.STORAGE_PLEASE_CHOOSE)),
                          ));
                          return;
                        }
                        _progressNotifier.value= _GRText.get(
                            _GRText.DOWNLOAD_DATA_REQUESTING);
                        GRDownloadInfo.getDownloadAssetsList().then((downloadList) {
                          if(downloadList.isEmpty){
                            _progressNotifier.value= _GRText.get(
                                _GRText.DOWNLOAD_DATA_REQUEST_FAILED);
                          }else{
                            _listDownloadInfo= downloadList;
                            _listDownloadInfo![0].download(_progressNotifier);
                          }
                        });
                      },
                      child: Text(_GRText.get(_GRText.DOWNLOAD_COMMAND_START))
                  ),
                ],
              ),
            ),
          ),
          Flexible(child: Container(),),
        ],
      ),
    );
  }
}

//GameResourceDownloadInfo
class GRDownloadInfo{
  String _fileName= "";
  String _url= "";
  String _hashMd5= "";
  int _fileSize= 0;

  static Future<List<GRDownloadInfo>> getDownloadAssetsList(){
    Completer<List<GRDownloadInfo>> completer= Completer<List<GRDownloadInfo>>();
    HttpHelper.getGameInfoJson().then((gameInfoJson) {
      if(gameInfoJson.length== 0){
        completer.complete(<GRDownloadInfo>[]);
      }
      List<dynamic> listJson = JSON.jsonDecode(gameInfoJson)
      ['resource_info']['download_links'] as List<dynamic>;
      List<GRDownloadInfo> ret= listJson.map((jsonString) =>
          GRDownloadInfo.fromJson(jsonString)).toList();
      completer.complete(ret);
    });
    return completer.future;
  }

  GRDownloadInfo(String fileName, String url, String hashMd5, int fileSize){
    _fileName= fileName;
    _url= url;
    _hashMd5= hashMd5;
    _fileSize= fileSize;
  }

  factory GRDownloadInfo.fromJson(dynamic json) {
    return GRDownloadInfo(
        json['file_name'] as String,
        json['url'] as String,
        json['hash_md5'] as String,
        json['file_size'] as int
    );
  }

  Future<bool> download(ValueNotifier progressNotifier){
    Completer<bool> completer= Completer<bool>();
    String filePath= Path.join(
        UserConfig.get(UserConfig.GAME_ASSETS_FOLDER), _fileName);
    if(File(filePath+ ".downloading").existsSync()){
      File(filePath+ ".downloading").deleteSync();
    }
    Dio().download(_url, filePath+ ".downloading",
      onReceiveProgress: (count, total) {
      progressNotifier.value= _GRText.get(_GRText.DOWNLOAD_PROCESSING)
          + (count* 100/ total).toStringAsFixed(1) + "%";
    },).then((response) {
      if(response.statusCode== 200){
        File oldFile= File(filePath);
        oldFile.exists().then((isExist) {
          if(isExist){
            File(filePath).deleteSync();
          }
          File(filePath+ ".downloading").rename(filePath);
          decompress(filePath, progressNotifier);
          completer.complete(true);
        });
      }else{
        completer.complete(false);
      }
    });
    return completer.future;
  }

  void decompress(String filePath, ValueNotifier progressNotifier) {
    final File zipFile = File(filePath);
    final Directory destinationDir = Directory(
        UserConfig.get(UserConfig.GAME_ASSETS_FOLDER));
    try {
      ZipFile.extractToDirectory(
          zipFile: zipFile,
          destinationDir: destinationDir,
          onExtracting: (zipEntry, progress) {
            progressNotifier.value= "${_GRText.get(_GRText.DOWNLOAD_EXTRACTING)}"
                "${progress.toStringAsFixed(1)}%";
            if(progress>= 100){
              zipFile.delete().whenComplete(() {
                progressNotifier.value= _GRText.get(_GRText.DOWNLOAD_ONE_FILE_DONE);
              });
            }
            return ZipFileOperation.includeItem;
          }
      );
    } catch (e) {
      print(e);
    }
  }
}