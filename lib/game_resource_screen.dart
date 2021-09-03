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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: GameResourceProgress(),);
  }
}

//GameResourceText
class GRText{
  static const String STATE_HEADER = "STATE_HEADER";
  static const String STATE_READY = "STATE_READY";
  static const String STATE_NOT_READY = "STATE_NOT_READY";

  static const String STORAGE_HEADER = "STORAGE_HEADER";
  static const String STORAGE_NEED_CHOOSE = "STORAGE_NEED_CHOOSE";
  static const String STORAGE_CHOSEN = "STORAGE_CHOSEN";
  static const String STORAGE_INSIDE = "STORAGE_INSIDE";
  static const String STORAGE_OUTSIDE = "STORAGE_OUTSIDE";

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
        case STORAGE_NEED_CHOOSE: return "Chưa chọn";
        case STORAGE_INSIDE: return "Bộ nhớ trong";
        case STORAGE_OUTSIDE: return "Bộ nhớ ngoài";

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
        case STORAGE_NEED_CHOOSE: return "選んでください";
        case STORAGE_INSIDE: return "内部メモリ";
        case STORAGE_OUTSIDE: return "外部メモリ";

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
  const GameResourceProgress({Key? key}) : super(key: key);

  @override
  _GameResourceProgressState createState() => _GameResourceProgressState();
}

class _GameResourceProgressState extends State<GameResourceProgress> {
  String _storageState= GRText.STORAGE_NEED_CHOOSE;
  ValueNotifier<String> _progressNotifier= ValueNotifier<String>(
      GRText.get(GRText.DOWNLOAD_COMMAND_WAITING));
  List<GRDownloadInfo>? _listDownloadInfo;

  _checkState([bool refresh= true]){
    if(UserConfig.get(UserConfig.GAME_ASSETS_FOLDER).length> 0){
      _storageState= GRText.STORAGE_CHOSEN;
    }else{
      _storageState= GRText.STORAGE_NEED_CHOOSE;
    }
    if(refresh){
      setState(() {});
    }
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
    _checkState(false);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: ValueListenableBuilder(
          valueListenable: _progressNotifier,
          builder: (context, value, child) {
            String progress= value as String;
            String readyText= GRText.get(GRText.STATE_HEADER)
                + GRText.get(GRText.STATE_READY);
            //TODO: change color for state
            if(progress!= readyText){
              return Text(GRText.get(GRText.STATE_HEADER)
                  + GRText.get(GRText.STATE_NOT_READY));
            }
            return Text(readyText);
          },),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Container(
              child: Column(
                children: [
                  Text(GRText.get(GRText.STORAGE_HEADER)
                  + (_storageState== GRText.STORAGE_NEED_CHOOSE
                      ? GRText.get(GRText.STORAGE_NEED_CHOOSE)
                      : GRText.decideStorageText())),
                  Text(UserConfig.get(UserConfig.GAME_ASSETS_FOLDER)),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Container(
              child: Column(
                children: [
                  Text("Download"),
                  ValueListenableBuilder(valueListenable: _progressNotifier,
                    builder: (context, value, child) {
                      String progressStr= value as String;
                      if(GRText.get(GRText.DOWNLOAD_ONE_FILE_DONE)== progressStr){
                        _listDownloadInfo!.removeAt(0);
                        if(_listDownloadInfo!.length> 0){
                          _listDownloadInfo![0].download(_progressNotifier);
                        }else{
                          WidgetsBinding.instance!.addPostFrameCallback((_) {
                            WidgetsFlutterBinding.ensureInitialized();
                            _progressNotifier.value= GRText.get(
                                GRText.DOWNLOAD_ALL_DONE);
                            _listDownloadInfo= null;
                          });
                        }
                      }
                      if(GRText.get(GRText.DOWNLOAD_ALL_DONE)== progressStr){
                        _decodeResource().whenComplete(() {
                          _progressNotifier.value=
                              GRText.get(GRText.STATE_HEADER)
                                  + GRText.get(GRText.STATE_READY);
                        });
                      }
                      return Text(progressStr);
                  },),
                  ElevatedButton(
                      onPressed: () {
                        if(null!= _listDownloadInfo){return;}
                        _progressNotifier.value= GRText.get(
                            GRText.DOWNLOAD_DATA_REQUESTING);
                        GRDownloadInfo.getDownloadAssetsList().then((downloadList) {
                          if(downloadList.isEmpty){
                            _progressNotifier.value= GRText.get(
                                GRText.DOWNLOAD_DATA_REQUEST_FAILED);
                          }else{
                            _listDownloadInfo= downloadList;
                            _listDownloadInfo![0].download(_progressNotifier);
                          }
                        });
                      },
                      child: Text("Start download")
                  ),
                ],
              ),
            ),
          ),
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

  //ValueNotifier<String> _progressNotifier= ValueNotifier<String>(
  //    GRText.get(GRText.DOWNLOAD_PREPARING));
  //ValueNotifier<String> getNotifier(){return _progressNotifier;}

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
    String filePath= CommonFunc.buildPath(
        [UserConfig.get(UserConfig.GAME_ASSETS_FOLDER), _fileName]);
    Dio().download(_url, filePath+ ".downloading", onReceiveProgress: (count, total) {
      progressNotifier.value= GRText.get(GRText.DOWNLOAD_PROCESSING)
          + (count* 100/ total).toStringAsFixed(1) + "%";
    },).then((response) {
      if(response.statusCode== 200){
        print("qqqq2: $_fileSize - $_hashMd5");
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
            progressNotifier.value= "${GRText.get(GRText.DOWNLOAD_EXTRACTING)}"
                "${progress.toStringAsFixed(1)}%";
            if(progress>= 100){
              zipFile.delete().whenComplete(() {
                progressNotifier.value= GRText.get(GRText.DOWNLOAD_ONE_FILE_DONE);
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