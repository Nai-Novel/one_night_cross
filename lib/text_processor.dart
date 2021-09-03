import 'dart:collection';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'com_cons.dart';
import 'script_runner.dart';
import 'storage_helper.dart';

class TextProcessor{
  static const String START_TAG_STRING = "<";
  static const String END_TAG_STRING = ">";
  static const String CLOSE_TAG_STRING = "/";
  static const String SEPARATE_TAG_STRING = "=";

  static const String STYLE_TAG_COLOR = "color";
  static const String STYLE_TAG_FONT = "font";
  static const String STYLE_TAG_SIZE_CHANGE = "size+";
  static const String STYLE_TAG_FIXED_SIZE = "size";
  static const String STYLE_TAG_ITALIC = "i";
  static const String STYLE_TAG_BOLD = "b";
  static const String STYLE_TAG_UNDERLINE = "u";
  static const String STYLE_TAG_STRIKE_THROUGH = "s";

  static const String FULL_TAG_LINE_BREAK = "<br>";
  static const String REPLACE_LINE_BREAK = "br";
  static const String REPLACE_SEMICOLON = ".,";
  static const String REPLACE_EQUAL = "-_";

  static const String CLICKABLE = "click";
  static const String CLICKABLE_ACTION_COPY_TO_CLIPBOARD = "copy";

  static RichText simpleRichText(String txt, [TextStyle? inputStyle]){
    return RichText(
      textAlign: TextAlign.start,
      text: TextSpan(
        children: TextProcessor.buildSpanFromString(txt, inputStyle),
      ),
    );
  }

  static String buildTag(String tag, String? value, [bool isClose= false]){
    String ret= START_TAG_STRING;
    ret+= isClose ? CLOSE_TAG_STRING : "";
    ret+= tag;
    if(!isClose && value!= null){
      ret+= SEPARATE_TAG_STRING+ value;
    }
    ret+= END_TAG_STRING;

    return ret;
  }

  static int computeClipDuration(double widthDelta, String? speed){
    double? speedPercent= (speed== null) ? 1 : double.tryParse(speed);
    if(speedPercent== null){speedPercent= 1;}
    int ret= UserConfig.getDouble(UserConfig.ONE_CHARACTER_DISPLAY_TIME) * speedPercent *
        (widthDelta< 0 ? 0 : widthDelta)~/ UserConfig.getDouble(UserConfig.TEXT_SIZE);
    return ret;
  }

  static Iterable<int> getListSubIndexTypeWriter(String text, String lastText) sync* {
    RuneIterator charArray= text.substring(lastText.length).runes.iterator;
    bool isInTag= false;

    while(charArray.moveNext()){
      if(charArray.currentAsString== START_TAG_STRING){isInTag= true;}
      if(!isInTag) {
        yield charArray.rawIndex+ lastText.length;
      }
      if(charArray.currentAsString== END_TAG_STRING){isInTag= false;}
    }
  }

  static List<TextSpan> buildSpanFromString(String text, [TextStyle? inputStyle]){
    TextStyle orgTextStyle;
    if(inputStyle== null){
      orgTextStyle = GameConstant.GAME_DEFAULT_TEXT_STYLE
          .copyWith(fontSize: UserConfig.getDouble(UserConfig.TEXT_SIZE),
                    fontFamily: UserConfig.get(UserConfig.TEXT_USER_FONT));
    }else{
      orgTextStyle= inputStyle;
    }
    TextStyle textStyle= orgTextStyle.copyWith();
    List<TextSpan> ret= <TextSpan>[];
    String tailText = text;
    int startTagIndex = tailText.indexOf(START_TAG_STRING);
    int endTagIndex = tailText.indexOf(END_TAG_STRING);
    String? tapActionString;

    do{
      if(startTagIndex>= 0){
        if(tapActionString== null){
          ret.add(TextSpan(
            text: tailText.substring(0, startTagIndex),
            style: textStyle,
          ));
        }else{
          TapGestureRecognizer? tapAction;
          TextStyle clickStyle= textStyle;
          String textInside= tailText.substring(0, startTagIndex);
          if(tapActionString== CLICKABLE_ACTION_COPY_TO_CLIPBOARD){
            tapAction= TapGestureRecognizer()..onTap= (){
              //TODO: Refactor to onCliCk(string command, string data)
              Clipboard.setData(ClipboardData(text: textInside));
            };
            clickStyle= textStyle.copyWith(
              color: Colors.lightBlue,
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.solid,
              decorationColor: Colors.lightBlue,
            );
          }
          ret.add(TextSpan(
            text: textInside,
            style: clickStyle,
            recognizer: tapAction,
          ));
        }
        String replacedText= "";
        List<String> changeStyleStringArray = tailText.substring(
            startTagIndex+ 1, endTagIndex).split(SEPARATE_TAG_STRING);
        if(changeStyleStringArray[0].startsWith(CLOSE_TAG_STRING)){
          String closeTagString = changeStyleStringArray[0].substring(CLOSE_TAG_STRING.length);
          if(closeTagString== STYLE_TAG_COLOR){
            textStyle = textStyle.copyWith(color: orgTextStyle.color);
          }else if(closeTagString== STYLE_TAG_FONT){
            textStyle = textStyle.copyWith(fontFamily: UserConfig.get(UserConfig.TEXT_USER_FONT));
          }else if(closeTagString== STYLE_TAG_SIZE_CHANGE){
            textStyle = textStyle.copyWith(fontSize: UserConfig.getDouble(UserConfig.TEXT_SIZE));
          }else if(closeTagString== STYLE_TAG_FIXED_SIZE){
            textStyle = textStyle.copyWith(fontSize: UserConfig.getDouble(UserConfig.TEXT_SIZE));
          }else if(closeTagString== STYLE_TAG_ITALIC){
            textStyle = textStyle.copyWith(fontStyle: orgTextStyle.fontStyle);
          }else if(closeTagString== STYLE_TAG_BOLD){
            textStyle = textStyle.copyWith(fontWeight: orgTextStyle.fontWeight);
          }else if(closeTagString== STYLE_TAG_UNDERLINE){
            textStyle = textStyle.copyWith(decoration: orgTextStyle.decoration);
          }else if(closeTagString== STYLE_TAG_STRIKE_THROUGH){
            textStyle = textStyle.copyWith(decoration: orgTextStyle.decoration);
          }else if(closeTagString== CLICKABLE){
            tapActionString = null;
          }
        }else{
          String openTagString = changeStyleStringArray[0];
          String tagValue;
          if(changeStyleStringArray.length> 1){
            tagValue= changeStyleStringArray[1];
            if(openTagString== STYLE_TAG_COLOR){
              textStyle = textStyle.copyWith(color: Color(int.tryParse("FF"+tagValue, radix: 16)!));
            }else if(openTagString== STYLE_TAG_FONT){
              textStyle = textStyle.copyWith(fontFamily: tagValue);
            }else if(openTagString== STYLE_TAG_SIZE_CHANGE){
              textStyle = textStyle.copyWith(fontSize: UserConfig.getDouble(UserConfig.TEXT_SIZE) + double.tryParse(tagValue)!);
            }else if(openTagString== STYLE_TAG_FIXED_SIZE){
              textStyle = textStyle.copyWith(fontSize: double.tryParse(tagValue));
            }else if(openTagString== CLICKABLE){
              tapActionString = tagValue;
            }
          }else{
            if(openTagString== STYLE_TAG_ITALIC){
              textStyle = textStyle.copyWith(fontStyle: FontStyle.italic);
            }else if(openTagString== STYLE_TAG_BOLD){
              textStyle = textStyle.copyWith(fontWeight: FontWeight.bold);
            }else if(openTagString== STYLE_TAG_UNDERLINE){
              textStyle = textStyle.copyWith(decoration: TextDecoration.underline);
            }else if(openTagString== STYLE_TAG_STRIKE_THROUGH){
              textStyle = textStyle.copyWith(decoration: TextDecoration.lineThrough);
            }else if(openTagString== REPLACE_LINE_BREAK){
              replacedText= "\n";
            }else if(openTagString== REPLACE_SEMICOLON){
              replacedText= ";";
            }else if(openTagString== REPLACE_EQUAL){
              replacedText= "=";
            }
          }

        }

        if((endTagIndex+ END_TAG_STRING.length)>= text.length){
          tailText= "";
          startTagIndex = -1;
          endTagIndex = -1;
        }else{
          tailText = replacedText + tailText.substring(endTagIndex+ END_TAG_STRING.length);
          startTagIndex = tailText.indexOf(START_TAG_STRING);
          endTagIndex = tailText.indexOf(END_TAG_STRING);
        }
      }else{
        ret.add(TextSpan(
            text: tailText,
            style: textStyle
        ));
        tailText= "";
      }
    }while(tailText.length> 0);

    return ret;
  }
}

class Language{
  static const String NONE = "__";
  static const String JAPANESE = "jp";
  static const String JP_KANJI_WITH_HIRAGANA = "kana";
  static const String VIETNAMESE = "vi";
  static const String ENGLISH = "en";
}

class GameText{
  static String GAME_RESOURCE_SCREEN_CURRENT_STATE_READY= "";
  static String GAME_RESOURCE_SCREEN_CURRENT_STATE_NOT_READY= "";

  static String SPLASH_CHOOSE_STORAGE_LABEL= "";
  static String SPLASH_STORAGE_LABEL_CHOSEN= "";
  static String SPLASH_CHOOSE_STORAGE_EXPLAIN= "";
  static String SPLASH_CHOOSE_STORAGE_INTERNAL_STORAGE= "";
  static String SPLASH_CHOOSE_STORAGE_EXTERNAL_STORAGE= "";
  static String SPLASH_GAME_RESOURCE= "";
  static String SPLASH_GAME_RESOURCE_READY= "";
  static String SPLASH_GAME_RESOURCE_NOT_READY= "";
  static String SPLASH_GAME_RESOURCE_DOWNLOADING= "";
  static String SPLASH_GAME_RESOURCE_EXTRACTING= "";
  static String SPLASH_GAME_RESOURCE_AUTO_DOWNLOAD= "";
  static String SPLASH_GAME_RESOURCE_MANUAL_DOWNLOAD= "";
  static String SPLASH_GAME_BUG_REPORT= "";
  static String SPLASH_GAME_USER_GUIDE= "";
  static String SPLASH_GAME_READY_START= "";
  static String SPLASH_GAME_READY_LOAD_LAST_SAVE= "";
  static String SPLASH_COMMUNITY= "";
  static String SPLASH_COMMUNITY_DISCORD= "Discord";
  static String SPLASH_COMMUNITY_FACEBOOK_GROUP= "Group";
  static String SPLASH_COMMUNITY_FACEBOOK_FANPAGE= "Fanpage";
  static String SPLASH_COMMUNITY_WEBSITE= "Website";
  static String SPLASH_HELP_US= "";
  static String SPLASH_HELP_US_SURVEY= "";
  static String SPLASH_HELP_US_DONATE= "";

  static String MENU_CLOSE_MENU= "";
  static String MENU_TRIGGER_AUTO= "";
  static String MENU_TRIGGER_SKIP_READ= "";
  static String MENU_TRIGGER_SKIP_ALL= "";
  static String MENU_SAVE_AND_LOAD= "";
  static String MENU_QUICK_SAVE= "";
  static String MENU_QUICK_LOAD= "";
  static String MENU_BACK_LOG= "";
  static String MENU_CONFIG= "";
  static String MENU_HIDE_TEXT_BOX= "";
  static String MENU_EXIT_TO_TITLE= "";
  static String MENU_QUIT= "";

  static String QUICK_MENU_CANCEL= "";

  static String TEXT_MENU_MAIN_LANGUAGE= "";
  static String TEXT_MENU_SUB_LANGUAGE= "";
  static String TEXT_MENU_HIRAGANA= "";
  static String TEXT_MENU_PLAY_VOICE= "";

  static String CONFIG_TAB_GENERAL= "";
  static String CONFIG_TAB_GENERAL_MENU_LANGUAGE= "Menu language";
  static String CONFIG_TAB_GENERAL_KEEP_AUTO_MODE= "";
  static String CONFIG_TAB_SOUND= "";
  static String CONFIG_TAB_SOUND_VOLUME_MASTER= "";
  static String CONFIG_TAB_SOUND_VOLUME_BG= "";
  static String CONFIG_TAB_SOUND_VOLUME_SE= "";
  static String CONFIG_TAB_SOUND_VOLUME_VOICE= "";
  static String CONFIG_TAB_SOUND_VOICE_DONE_IS_WAIT= "";
  static String CONFIG_TAB_TEXT= "";
  static String CONFIG_TAB_TEXT_TEXTBOX_BG_OPACITY= "";
  static String CONFIG_TAB_TEXT_TEXT_SIZE= "";
  static String CONFIG_TAB_TEXT_TEXT_SPEED= "";
  static String CONFIG_TAB_TEXT_AUTO_WAIT_TIME= "";
  static String CONFIG_TAB_TEXT_LANGUAGE= "Display language";
  static String CONFIG_TAB_TEXT_SAMPLE_DISPLAY= "";
  static String CONFIG_TAB_TEXT_SAMPLE_TEXT1= "";
  static String CONFIG_TAB_TEXT_SAMPLE_TEXT2= "";
  static String CONFIG_TAB_CHARACTER= "";
  static String CONFIG_TAB_CHARACTER_LIP_SYNC= "Lip sync";

  static String BACK_LOG_CHOICE= "";

  static String WARNING_GAME_STILL_RUNNING= "";

  static void loadByLanguage(String lang){
    if(lang== Language.VIETNAMESE){
      BACK_LOG_CHOICE = "Lựa chọn";

      WARNING_GAME_STILL_RUNNING = "Trò chơi vẫn đang trong quá trình chạy";
    }else if(lang== Language.ENGLISH){
      BACK_LOG_CHOICE = "Choice";

      WARNING_GAME_STILL_RUNNING = "Game is still running";
    }else if(lang== Language.JAPANESE){
      BACK_LOG_CHOICE = "選択";

      WARNING_GAME_STILL_RUNNING = "ゲームはまだ実行中です。";
    }

  }

  static void loadMenuByLanguage(String lang){
    if(lang== Language.VIETNAMESE){
      GAME_RESOURCE_SCREEN_CURRENT_STATE_READY = "Đã sẵn sàng!";
      GAME_RESOURCE_SCREEN_CURRENT_STATE_NOT_READY = "Chưa đầy đủ!";

      SPLASH_CHOOSE_STORAGE_LABEL = "Chọn vùng nhớ: ";
      SPLASH_STORAGE_LABEL_CHOSEN = "Vùng nhớ: ";
      SPLASH_CHOOSE_STORAGE_INTERNAL_STORAGE= "Bộ nhớ trong";
      SPLASH_CHOOSE_STORAGE_EXTERNAL_STORAGE= "Thẻ nhớ";
      SPLASH_CHOOSE_STORAGE_EXPLAIN = "Chọn lấy vùng nhớ sẽ lưu trữ dữ liệu game, dữ liệu nặng khoảng 800Mb nhưng sẽ cần tới 1Gb để thực hiện thêm cả thao tác giải nén.";
      SPLASH_GAME_RESOURCE_READY= "GAME!!!";
      SPLASH_GAME_RESOURCE_NOT_READY= "Dữ liệu game chưa sẵn sàng";
      SPLASH_GAME_RESOURCE= "Cài đặt dữ liệu game";
      SPLASH_GAME_RESOURCE_DOWNLOADING= "Đang tải xuống";
      SPLASH_GAME_RESOURCE_EXTRACTING= "Đang giải nén";
      SPLASH_GAME_RESOURCE_AUTO_DOWNLOAD= "Tự động";
      SPLASH_GAME_RESOURCE_MANUAL_DOWNLOAD= "Thủ công";
      SPLASH_GAME_BUG_REPORT= "Báo lỗi";
      SPLASH_GAME_USER_GUIDE= "Hướng dẫn";
      SPLASH_GAME_READY_START= "Bắt đầu";
      SPLASH_GAME_READY_LOAD_LAST_SAVE= "Đọc tiếp";
      SPLASH_COMMUNITY= "Cộng đồng";
      SPLASH_HELP_US= "Giúp chúng mình";
      SPLASH_HELP_US_SURVEY= "Khảo sát";
      SPLASH_HELP_US_DONATE= "Quyên góp";

      MENU_CLOSE_MENU = "Đóng";
      MENU_TRIGGER_AUTO = "Tự động đọc";
      MENU_TRIGGER_SKIP_READ = "Bỏ qua đã đọc";
      MENU_TRIGGER_SKIP_ALL = "Bỏ qua toàn bộ";
      MENU_SAVE_AND_LOAD = "Lưu / Tải";
      MENU_QUICK_SAVE = "Lưu nhanh";
      MENU_QUICK_LOAD = "Tải nhanh";
      MENU_BACK_LOG = "Lược sử";
      MENU_CONFIG = "Tuỳ chỉnh";
      MENU_HIDE_TEXT_BOX = "Ẩn khung thoại";
      MENU_EXIT_TO_TITLE = "Về tiêu đề";
      MENU_QUIT = "Thoát";

      QUICK_MENU_CANCEL = "Huỷ";

      TEXT_MENU_MAIN_LANGUAGE = "Ngôn ngữ chính";
      TEXT_MENU_SUB_LANGUAGE = "Ngôn ngữ phụ";
      TEXT_MENU_HIRAGANA = "Hiragana";
      TEXT_MENU_PLAY_VOICE = "Đọc lời thoại";

      CONFIG_TAB_GENERAL = "Cơ bản";
      CONFIG_TAB_GENERAL_KEEP_AUTO_MODE = "Vẫn tự động đọc khi chuyển thoại bằng tay";
      CONFIG_TAB_SOUND = "Âm thanh";
      CONFIG_TAB_SOUND_VOLUME_MASTER = "Âm lượng tổng";
      CONFIG_TAB_SOUND_VOLUME_BG = "Nhạc nền";
      CONFIG_TAB_SOUND_VOLUME_SE = "Tiếng động";
      CONFIG_TAB_SOUND_VOLUME_VOICE = "Giọng nói nhân vật";
      CONFIG_TAB_SOUND_VOICE_DONE_IS_WAIT = "Chờ giọng nhân vật kết thúc khi tự động đọc";
      CONFIG_TAB_TEXT = "Văn bản";
      CONFIG_TAB_TEXT_TEXTBOX_BG_OPACITY = "Độ mờ khung thoại";
      CONFIG_TAB_TEXT_TEXT_SIZE = "Cỡ chữ";
      CONFIG_TAB_TEXT_TEXT_SPEED = "Tốc độ văn bản";
      CONFIG_TAB_TEXT_AUTO_WAIT_TIME = "Thời gian chờ trong chế độ tự động đọc";
      CONFIG_TAB_TEXT_SAMPLE_DISPLAY = "Kiểu hiển thị của văn bản hiện hành";
      CONFIG_TAB_TEXT_SAMPLE_TEXT1 = "Tên nhân vật<br>Một đoạn văn bản rất dài dùng để cho bạn thấy với các tuỳ chỉnh hiện tại, văn bản được hiển thị như thế nào.";
      CONFIG_TAB_TEXT_SAMPLE_TEXT2 = "Vậy nên khi đọc bạn sẽ thấy vô cùng chán nản, mệt mỏi và cuối cùng là... hối tiếc vì đã đọc đống chữ hiển thị thử nghiệm vớ vẩn này.";
      CONFIG_TAB_CHARACTER = "Nhân vật";
    }
    else if(lang== Language.ENGLISH){
      GAME_RESOURCE_SCREEN_CURRENT_STATE_READY = "All ready!";
      GAME_RESOURCE_SCREEN_CURRENT_STATE_NOT_READY = "Incomplete!";

      SPLASH_CHOOSE_STORAGE_LABEL = "Choose storage: ";
      SPLASH_STORAGE_LABEL_CHOSEN = "Storage: ";
      SPLASH_CHOOSE_STORAGE_INTERNAL_STORAGE= "Internal storage";
      SPLASH_CHOOSE_STORAGE_EXTERNAL_STORAGE= "SD card";
      SPLASH_CHOOSE_STORAGE_EXPLAIN = "Select the storage will store the game data, data will take about 800Mb, but it will need 1.6Gb to perform additional decompression.";
      SPLASH_GAME_RESOURCE_READY= "GAME!!!";
      SPLASH_GAME_RESOURCE_NOT_READY= "Not ready";
      SPLASH_GAME_RESOURCE= "Install game resource";
      SPLASH_GAME_RESOURCE_DOWNLOADING= "Downloading";
      SPLASH_GAME_RESOURCE_EXTRACTING= "Decompressing";
      SPLASH_GAME_RESOURCE_AUTO_DOWNLOAD= "Auto";
      SPLASH_GAME_RESOURCE_MANUAL_DOWNLOAD= "Manual";
      SPLASH_GAME_BUG_REPORT= "Report";
      SPLASH_GAME_USER_GUIDE= "Guide";
      SPLASH_GAME_READY_START= "Start game";
      SPLASH_GAME_READY_LOAD_LAST_SAVE= "Continue";
      SPLASH_COMMUNITY= "Community";
      SPLASH_HELP_US= "Help us";
      SPLASH_HELP_US_SURVEY= "Survey";
      SPLASH_HELP_US_DONATE= "Donate";

      MENU_CLOSE_MENU = "Close";
      MENU_TRIGGER_AUTO = "Auto";
      MENU_TRIGGER_SKIP_READ = "Skip read";
      MENU_TRIGGER_SKIP_ALL = "Skip all";
      MENU_SAVE_AND_LOAD = "Save / load";
      MENU_QUICK_SAVE = "Quick save";
      MENU_QUICK_LOAD = "Quick load";
      MENU_BACK_LOG = "Back log";
      MENU_CONFIG = "Config";
      MENU_HIDE_TEXT_BOX = "Hide textbox";
      MENU_EXIT_TO_TITLE = "Back to title";
      MENU_QUIT = "Quit";

      QUICK_MENU_CANCEL = "Cancel";

      TEXT_MENU_MAIN_LANGUAGE = "Main language";
      TEXT_MENU_SUB_LANGUAGE = "Sub language";
      TEXT_MENU_HIRAGANA = "Hiragana";
      TEXT_MENU_PLAY_VOICE = "Play voice";

      CONFIG_TAB_GENERAL = "General";
      CONFIG_TAB_GENERAL_KEEP_AUTO_MODE = "Keep auto mode when manual read";
      CONFIG_TAB_SOUND = "Sound";
      CONFIG_TAB_SOUND_VOLUME_MASTER = "Master volume";
      CONFIG_TAB_SOUND_VOLUME_BG = "Background music";
      CONFIG_TAB_SOUND_VOLUME_SE = "Sound effect";
      CONFIG_TAB_SOUND_VOLUME_VOICE = "Voice";
      CONFIG_TAB_SOUND_VOICE_DONE_IS_WAIT = "Wait character voice complete on auto mode";
      CONFIG_TAB_TEXT = "Text";
      CONFIG_TAB_TEXT_TEXTBOX_BG_OPACITY = "Message background transparent";
      CONFIG_TAB_TEXT_TEXT_SIZE = "Message text size";
      CONFIG_TAB_TEXT_TEXT_SPEED = "Message speed";
      CONFIG_TAB_TEXT_AUTO_WAIT_TIME = "Auto mode wait time";
      CONFIG_TAB_TEXT_SAMPLE_DISPLAY = "Sample text";
      CONFIG_TAB_CHARACTER = "Character";
    }
    else if(lang== Language.JAPANESE){
      GAME_RESOURCE_SCREEN_CURRENT_STATE_READY = "準備完了";
      GAME_RESOURCE_SCREEN_CURRENT_STATE_NOT_READY = "未完成";

      SPLASH_CHOOSE_STORAGE_LABEL = "ストレージ選び：";
      SPLASH_STORAGE_LABEL_CHOSEN = "ストレージ：";
      SPLASH_CHOOSE_STORAGE_INTERNAL_STORAGE= "内部ストレージ";
      SPLASH_CHOOSE_STORAGE_EXTERNAL_STORAGE= "SDカード";
      SPLASH_CHOOSE_STORAGE_EXPLAIN= "ゲームデータは選んだストレージ保存されます。データの重量は約800Mbですが、追加の解凍を実行するには1.6Gbが必要です。";
      SPLASH_GAME_RESOURCE_READY= "準備完了";
      SPLASH_GAME_RESOURCE_NOT_READY= "見つけません";
      SPLASH_GAME_RESOURCE= "ゲームデータのインストール";
      SPLASH_GAME_RESOURCE_DOWNLOADING= "ダウンロード";
      SPLASH_GAME_RESOURCE_EXTRACTING= "解凍";
      SPLASH_GAME_RESOURCE_AUTO_DOWNLOAD= "自動的に";
      SPLASH_GAME_RESOURCE_MANUAL_DOWNLOAD= "自分でする";
      SPLASH_GAME_BUG_REPORT= "故障報告";
      SPLASH_GAME_USER_GUIDE= "マニュアル";
      SPLASH_GAME_READY_START= "はじめる";
      SPLASH_GAME_READY_LOAD_LAST_SAVE= "続ける";
      SPLASH_COMMUNITY= "コミュニティ";
      SPLASH_HELP_US= "応援する";
      SPLASH_HELP_US_SURVEY= "アンケート";
      SPLASH_HELP_US_DONATE= "寄付";

      MENU_CLOSE_MENU = "閉じる";
      MENU_TRIGGER_AUTO = "自動送り";
      MENU_TRIGGER_SKIP_READ = "早送り（既読）";
      MENU_TRIGGER_SKIP_ALL = "早送り（全て）";
      MENU_SAVE_AND_LOAD = "データ保存・読み";
      MENU_QUICK_SAVE = "クイックセーブ";
      MENU_QUICK_LOAD = "クイックロード";
      MENU_BACK_LOG = "文章履歴";
      MENU_CONFIG = "環境設定";
      MENU_HIDE_TEXT_BOX = "テキスト非表示";
      MENU_EXIT_TO_TITLE = "タイトルに戻る";
      MENU_QUIT = "終了";

      QUICK_MENU_CANCEL = "閉じる";

      TEXT_MENU_MAIN_LANGUAGE = "主な言語";
      TEXT_MENU_SUB_LANGUAGE = "サブ言語";
      TEXT_MENU_HIRAGANA = "ひらがな";
      TEXT_MENU_PLAY_VOICE = "声を再生";

      CONFIG_TAB_GENERAL = "基本";
      CONFIG_TAB_GENERAL_KEEP_AUTO_MODE = "手動で読むときは自動モードを維持する";
      CONFIG_TAB_SOUND = "音";
      CONFIG_TAB_SOUND_VOLUME_MASTER = "全体音量";
      CONFIG_TAB_SOUND_VOLUME_BG = "BGM音量";
      CONFIG_TAB_SOUND_VOLUME_SE = "効果音量";
      CONFIG_TAB_SOUND_VOLUME_VOICE = "声音量";
      CONFIG_TAB_SOUND_VOICE_DONE_IS_WAIT = "オートモードではキャラクターの声が終わるのを待つ";
      CONFIG_TAB_TEXT = "文字";
      CONFIG_TAB_TEXT_TEXTBOX_BG_OPACITY = "メッセージウインドウ透明度";
      CONFIG_TAB_TEXT_TEXT_SIZE = "テキスト大きさ";
      CONFIG_TAB_TEXT_TEXT_SPEED = "メッセージ表示速度";
      CONFIG_TAB_TEXT_AUTO_WAIT_TIME = "オートモード速度";
      CONFIG_TAB_TEXT_SAMPLE_DISPLAY = "表示のサンプル";
      CONFIG_TAB_TEXT_SAMPLE_TEXT1 = "キャラクター<br>現在の設定でテキストがどのように表示されるかを示すために使用される非常に長いテキスト。";
      CONFIG_TAB_TEXT_SAMPLE_TEXT2 = "ですから、あなたがそれを読むとき、つまらないと感じて、疲れて、そして最後に...このたわごとサンプル表示テキストを読んだことを後悔するでしょう。";
      CONFIG_TAB_CHARACTER = "キャラクター";
    }

  }
}

class CharacterOfText {
  static const String STRING_BETWEEN_CHAR_NAME_AND_TEXT= "</color><br>";
  late String _nameTagStyleStart;
  //String _nameTagStyleEnd;
  late String _multiLanguageDisplayName;

  CharacterOfText(String nameTagStyleStart, String multiLanguageDisplayName){
    _nameTagStyleStart= nameTagStyleStart;
    //_nameTagStyleEnd= nameTagStyleEnd;
    _multiLanguageDisplayName= multiLanguageDisplayName;
  }

  String getDisplayName(String language){
    ScriptCommandInfo languageCommand= ScriptCommandInfo(_multiLanguageDisplayName);
    return _nameTagStyleStart + (languageCommand.containKey(language)
        ? languageCommand.valueOf(language)! : languageCommand.valueOf(Language.NONE)!)+ STRING_BETWEEN_CHAR_NAME_AND_TEXT;
  }

  static SplayTreeMap<String, CharacterOfText>? _listCharacterBase;
  static CharacterOfText get(String baseName){
    if(_listCharacterBase== null){
      _listCharacterBase= SplayTreeMap<String, CharacterOfText>();
      _listCharacterBase!.putIfAbsent(CharacterBase.ROUGE, () => CharacterOfText("<color=bc836a>", ";jp=ルージュ;vi=Rouge"));
      _listCharacterBase!.putIfAbsent(CharacterBase.GRIS, () => CharacterOfText("<color=a8a1a8>", ";jp=グリーズ;vi=Gris"));
      _listCharacterBase!.putIfAbsent(CharacterBase.NOIR, () => CharacterOfText("<color=6c605f>", ";jp=ノワール;vi=Noir"));
    }
    if(_listCharacterBase!.containsKey(baseName)){
      return _listCharacterBase![baseName]!;
    }else{
      String noLanguageBaseName= ScriptCommandInfo.buildCommandParam(Language.NONE, baseName);
      if(baseName.startsWith(CharacterBase.PREFIX_MALE)){
        return CharacterOfText("<color=f5e6d3>", noLanguageBaseName);
      }
      if(baseName.startsWith(CharacterBase.PREFIX_FEMALE)){
        return CharacterOfText("<color=e9afa3>", noLanguageBaseName);
      }
      return CharacterOfText("", noLanguageBaseName);
    }
  }

  String get nameTagStyleStart => _nameTagStyleStart;
  String get multiLanguageDisplayName => _multiLanguageDisplayName;
}

class ErrorString{
  static const String INFINITE_LOOP_NEED_NAME = "[Game Error] Infinity loop need a name, to stop the loop by the defined name.";
  static const String EXECUTION_COUNT_IS_NEGATIVE = "[Game Error] Execution count became less than [continue execution count], it is mean that something wrong. Execution count= ";
  static const String NO_IMAGE_FOUND = "[Game Error] [animateImageCommand] No image found by this name:";
  static const String NO_CACHED_IMAGE_FOUND = "[Game Error] No cached image found by this name:";
}

















