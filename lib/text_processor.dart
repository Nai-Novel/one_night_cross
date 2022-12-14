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
  static const String STYLE_TAG_SIZE_PLUS = "size+";
  static const String STYLE_TAG_SIZE_MINUS = "size-";
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
              textStyle = textStyle.copyWith(color: Color(int.tryParse(
                  tagValue.length== 6 ? "FF"+tagValue : tagValue, radix: 16)!));
            }else if(openTagString== STYLE_TAG_FONT){
              textStyle = textStyle.copyWith(fontFamily: tagValue);
            }else if(openTagString== STYLE_TAG_SIZE_PLUS){
              textStyle = textStyle.copyWith(fontSize: UserConfig.getDouble(UserConfig.TEXT_SIZE) + double.tryParse(tagValue)!);
            }else if(openTagString== STYLE_TAG_SIZE_MINUS){
              textStyle = textStyle.copyWith(fontSize: UserConfig.getDouble(UserConfig.TEXT_SIZE) - double.tryParse(tagValue)!);
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
  static const String MENU_CLOSE_MENU= "MENU_CLOSE_MENU";
  static const String MENU_TRIGGER_AUTO= "MENU_TRIGGER_AUTO";
  static const String MENU_TRIGGER_SKIP_READ= "MENU_TRIGGER_SKIP_READ";
  static const String MENU_TRIGGER_SKIP_ALL= "MENU_TRIGGER_SKIP_ALL";
  static const String MENU_SAVE_AND_LOAD= "MENU_SAVE_AND_LOAD";
  static const String MENU_QUICK_SAVE= "MENU_QUICK_SAVE";
  static const String MENU_QUICK_LOAD= "MENU_QUICK_LOAD";
  static const String MENU_BACK_LOG= "MENU_BACK_LOG";
  static const String MENU_CONFIG= "MENU_CONFIG";
  static const String MENU_HIDE_TEXT_BOX= "MENU_HIDE_TEXT_BOX";
  static const String MENU_EXIT_TO_TITLE= "MENU_EXIT_TO_TITLE";
  static const String MENU_QUIT= "MENU_QUIT";

  static const String QUICK_MENU_CANCEL= "QUICK_MENU_CANCEL";

  static const String TEXT_MENU_MAIN_LANGUAGE= "TEXT_MENU_MAIN_LANGUAGE";
  static const String TEXT_MENU_SUB_LANGUAGE= "TEXT_MENU_SUB_LANGUAGE";
  static const String TEXT_MENU_HIRAGANA= "TEXT_MENU_HIRAGANA";
  static const String TEXT_MENU_PLAY_VOICE= "TEXT_MENU_PLAY_VOICE";

  static const String CONFIG_TAB_GENERAL= "CONFIG_TAB_GENERAL";
  static const String CONFIG_TAB_GENERAL_MENU_LANGUAGE= "CONFIG_TAB_GENERAL_MENU_LANGUAGE";
  static const String CONFIG_TAB_GENERAL_KEEP_AUTO_MODE= "CONFIG_TAB_GENERAL_KEEP_AUTO_MODE";
  static const String CONFIG_TAB_SOUND= "CONFIG_TAB_SOUND";
  static const String CONFIG_TAB_SOUND_VOLUME_MASTER= "CONFIG_TAB_SOUND_VOLUME_MASTER";
  static const String CONFIG_TAB_SOUND_VOLUME_BG= "CONFIG_TAB_SOUND_VOLUME_BG";
  static const String CONFIG_TAB_SOUND_VOLUME_SE= "CONFIG_TAB_SOUND_VOLUME_SE";
  static const String CONFIG_TAB_SOUND_VOLUME_VOICE= "CONFIG_TAB_SOUND_VOLUME_VOICE";
  static const String CONFIG_TAB_SOUND_VOICE_DONE_IS_WAIT= "CONFIG_TAB_SOUND_VOICE_DONE_IS_WAIT";
  static const String CONFIG_TAB_TEXT= "CONFIG_TAB_TEXT";
  static const String CONFIG_TAB_TEXT_TEXTBOX_BG_OPACITY= "CONFIG_TAB_TEXT_TEXTBOX_BG_OPACITY";
  static const String CONFIG_TAB_TEXT_TEXT_SIZE= "CONFIG_TAB_TEXT_TEXT_SIZE";
  static const String CONFIG_TAB_TEXT_TEXT_SPEED= "CONFIG_TAB_TEXT_TEXT_SPEED";
  static const String CONFIG_TAB_TEXT_AUTO_WAIT_TIME= "CONFIG_TAB_TEXT_AUTO_WAIT_TIME";
  static const String CONFIG_TAB_TEXT_LANGUAGE= "Display language";
  static const String CONFIG_TAB_TEXT_SAMPLE_DISPLAY= "CONFIG_TAB_TEXT_SAMPLE_DISPLAY";
  static const String CONFIG_TAB_TEXT_SAMPLE_TEXT1= "CONFIG_TAB_TEXT_SAMPLE_TEXT1";
  static const String CONFIG_TAB_TEXT_SAMPLE_TEXT2= "CONFIG_TAB_TEXT_SAMPLE_TEXT2";
  static const String CONFIG_TAB_CHARACTER= "CONFIG_TAB_CHARACTER";
  static const String CONFIG_TAB_CHARACTER_LIP_SYNC= "CONFIG_TAB_CHARACTER_LIP_SYNC";

  static const String BACK_LOG_CHOICE= "BACK_LOG_CHOICE";

  static const String WARNING_GAME_STILL_RUNNING= "WARNING_GAME_STILL_RUNNING";

  static String get(String txt) {
    String lang= UserConfig.get(UserConfig.MENU_LANGUAGE);
    switch(txt){
      case CONFIG_TAB_CHARACTER_LIP_SYNC: return "Lip sync";
      case CONFIG_TAB_GENERAL_MENU_LANGUAGE: return "Menu language";
    }
    if (lang == Language.VIETNAMESE) {
      switch(txt) {
        case BACK_LOG_CHOICE: return "L???a ch???n";
        case WARNING_GAME_STILL_RUNNING: return "Tr?? ch??i v???n ??ang trong qu?? tr??nh ch???y!";

        case MENU_CLOSE_MENU: return "????ng";
        case MENU_TRIGGER_AUTO: return "T??? ?????ng ?????c";
        case MENU_TRIGGER_SKIP_READ: return "B??? qua ???? ?????c";
        case MENU_TRIGGER_SKIP_ALL: return "B??? qua to??n b???";
        case MENU_SAVE_AND_LOAD: return "L??u / T???i";
        case MENU_QUICK_SAVE: return "L??u nhanh";
        case MENU_QUICK_LOAD: return "T???i nhanh";
        case MENU_BACK_LOG: return "L?????c s???";
        case MENU_CONFIG: return "Tu??? ch???nh";
        case MENU_HIDE_TEXT_BOX: return "???n khung tho???i";
        case MENU_EXIT_TO_TITLE: return "V??? ti??u ?????";
        case MENU_QUIT: return "Tho??t";

        case QUICK_MENU_CANCEL: return "Hu???";

        case TEXT_MENU_MAIN_LANGUAGE: return "Ng??n ng??? ch??nh";
        case TEXT_MENU_SUB_LANGUAGE: return "Ng??n ng??? ph???";
        case TEXT_MENU_HIRAGANA: return "Hiragana";
        case TEXT_MENU_PLAY_VOICE: return "?????c l???i tho???i";

        case CONFIG_TAB_GENERAL: return "C?? b???n";
        case CONFIG_TAB_GENERAL_KEEP_AUTO_MODE: return "V???n t??? ?????ng ?????c khi chuy???n tho???i b???ng tay";
        case CONFIG_TAB_SOUND: return "??m thanh";
        case CONFIG_TAB_SOUND_VOLUME_MASTER: return "??m l?????ng t???ng";
        case CONFIG_TAB_SOUND_VOLUME_BG: return "Nh???c n???n";
        case CONFIG_TAB_SOUND_VOLUME_SE: return "Ti???ng ?????ng";
        case CONFIG_TAB_SOUND_VOLUME_VOICE: return "Gi???ng n??i nh??n v???t";
        case CONFIG_TAB_SOUND_VOICE_DONE_IS_WAIT: return "Ch??? gi???ng nh??n v???t k???t th??c khi t??? ?????ng ?????c";
        case CONFIG_TAB_TEXT: return "V??n b???n";
        case CONFIG_TAB_TEXT_TEXTBOX_BG_OPACITY: return "????? m??? khung tho???i";
        case CONFIG_TAB_TEXT_TEXT_SIZE: return "C??? ch???";
        case CONFIG_TAB_TEXT_TEXT_SPEED: return "T???c ????? v??n b???n";
        case CONFIG_TAB_TEXT_AUTO_WAIT_TIME: return "Th???i gian ch??? trong ch??? ????? t??? ?????ng ?????c";
        case CONFIG_TAB_TEXT_SAMPLE_DISPLAY: return "Ki???u hi???n th??? c???a v??n b???n hi???n h??nh";
        case CONFIG_TAB_TEXT_SAMPLE_TEXT1: return "T??n nh??n v???t<br>M???t ??o???n v??n b???n r???t d??i d??ng ????? cho b???n th???y v???i c??c tu??? ch???nh hi???n t???i, v??n b???n ???????c hi???n th??? nh?? th??? n??o.";
        case CONFIG_TAB_TEXT_SAMPLE_TEXT2: return "V???y n??n khi ?????c b???n s??? th???y v?? c??ng ch??n n???n, m???t m???i v?? cu???i c??ng l??... h???i ti???c v?? ???? ?????c ?????ng ch??? hi???n th??? th??? nghi???m v??? v???n n??y.";
        case CONFIG_TAB_CHARACTER: return "Nh??n v???t";
      }
    }
    else if (lang == Language.JAPANESE) {
      switch(txt) {
        case BACK_LOG_CHOICE: return "??????";
        case WARNING_GAME_STILL_RUNNING: return "????????????????????????????????????";

        case MENU_CLOSE_MENU: return "?????????";
        case MENU_TRIGGER_AUTO: return "????????????";
        case MENU_TRIGGER_SKIP_READ: return "?????????????????????";
        case MENU_TRIGGER_SKIP_ALL: return "?????????????????????";
        case MENU_SAVE_AND_LOAD: return "????????????????????????";
        case MENU_QUICK_SAVE: return "?????????????????????";
        case MENU_QUICK_LOAD: return "?????????????????????";
        case MENU_BACK_LOG: return "????????????";
        case MENU_CONFIG: return "????????????";
        case MENU_HIDE_TEXT_BOX: return "?????????????????????";
        case MENU_EXIT_TO_TITLE: return "?????????????????????";
        case MENU_QUIT: return "??????";

        case QUICK_MENU_CANCEL: return "?????????";

        case TEXT_MENU_MAIN_LANGUAGE: return "????????????";
        case TEXT_MENU_SUB_LANGUAGE: return "????????????";
        case TEXT_MENU_HIRAGANA: return "????????????";
        case TEXT_MENU_PLAY_VOICE: return "????????????";

        case CONFIG_TAB_GENERAL: return "??????";
        case CONFIG_TAB_GENERAL_KEEP_AUTO_MODE: return "??????????????????????????????????????????????????????";
        case CONFIG_TAB_SOUND: return "???";
        case CONFIG_TAB_SOUND_VOLUME_MASTER: return "????????????";
        case CONFIG_TAB_SOUND_VOLUME_BG: return "BGM??????";
        case CONFIG_TAB_SOUND_VOLUME_SE: return "????????????";
        case CONFIG_TAB_SOUND_VOLUME_VOICE: return "?????????";
        case CONFIG_TAB_SOUND_VOICE_DONE_IS_WAIT: return "????????????????????????????????????????????????????????????????????????";
        case CONFIG_TAB_TEXT: return "??????";
        case CONFIG_TAB_TEXT_TEXTBOX_BG_OPACITY: return "???????????????????????????????????????";
        case CONFIG_TAB_TEXT_TEXT_SIZE: return "?????????????????????";
        case CONFIG_TAB_TEXT_TEXT_SPEED: return "???????????????????????????";
        case CONFIG_TAB_TEXT_AUTO_WAIT_TIME: return "????????????????????????";
        case CONFIG_TAB_TEXT_SAMPLE_DISPLAY: return "?????????????????????";
        case CONFIG_TAB_TEXT_SAMPLE_TEXT1: return "??????????????????<br>?????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????";
        case CONFIG_TAB_TEXT_SAMPLE_TEXT2: return "???????????????????????????????????????????????????????????????????????????????????????????????????????????????...????????????????????????????????????????????????????????????????????????????????????????????????";
        case CONFIG_TAB_CHARACTER: return "??????????????????";
      }
    }
    else if (lang == Language.ENGLISH) {
      switch(txt) {
        case BACK_LOG_CHOICE: return "Choice";
        case WARNING_GAME_STILL_RUNNING: return "Game is still running!";

        case MENU_CLOSE_MENU: return "Close";
        case MENU_TRIGGER_AUTO: return "Auto";
        case MENU_TRIGGER_SKIP_READ: return "Skip read";
        case MENU_TRIGGER_SKIP_ALL: return "Skip all";
        case MENU_SAVE_AND_LOAD: return "Save / load";
        case MENU_QUICK_SAVE: return "Quick save";
        case MENU_QUICK_LOAD: return "Quick load";
        case MENU_BACK_LOG: return "Back log";
        case MENU_CONFIG: return "Config";
        case MENU_HIDE_TEXT_BOX: return "Hide textbox";
        case MENU_EXIT_TO_TITLE: return "Back to title";
        case MENU_QUIT: return "Quit";

        case QUICK_MENU_CANCEL: return "Cancel";

        case TEXT_MENU_MAIN_LANGUAGE: return "Main language";
        case TEXT_MENU_SUB_LANGUAGE: return "Sub language";
        case TEXT_MENU_HIRAGANA: return "Hiragana";
        case TEXT_MENU_PLAY_VOICE: return "Play voice";

        case CONFIG_TAB_GENERAL: return "General";
        case CONFIG_TAB_GENERAL_KEEP_AUTO_MODE: return "Keep auto mode when manual read";
        case CONFIG_TAB_SOUND: return "Sound";
        case CONFIG_TAB_SOUND_VOLUME_MASTER: return "Master volume";
        case CONFIG_TAB_SOUND_VOLUME_BG: return "Background music";
        case CONFIG_TAB_SOUND_VOLUME_SE: return "Sound effect";
        case CONFIG_TAB_SOUND_VOLUME_VOICE: return "Voice";
        case CONFIG_TAB_SOUND_VOICE_DONE_IS_WAIT: return "Wait character voice complete on auto mode";
        case CONFIG_TAB_TEXT: return "Text";
        case CONFIG_TAB_TEXT_TEXTBOX_BG_OPACITY: return "Message background transparent";
        case CONFIG_TAB_TEXT_TEXT_SIZE: return "Message text size";
        case CONFIG_TAB_TEXT_TEXT_SPEED: return "Message speed";
        case CONFIG_TAB_TEXT_AUTO_WAIT_TIME: return "Auto mode wait time";
        case CONFIG_TAB_TEXT_SAMPLE_DISPLAY: return "Sample text";
        case CONFIG_TAB_CHARACTER: return "Character";
      }
    }
    return txt;
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
      _listCharacterBase!.putIfAbsent(CharacterBase.ROUGE, () => CharacterOfText("<color=bc836a>", ";jp=????????????;vi=Rouge"));
      _listCharacterBase!.putIfAbsent(CharacterBase.GRIS, () => CharacterOfText("<color=a8a1a8>", ";jp=????????????;vi=Gris"));
      _listCharacterBase!.putIfAbsent(CharacterBase.NOIR, () => CharacterOfText("<color=6c605f>", ";jp=????????????;vi=Noir"));
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

















