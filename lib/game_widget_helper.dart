import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'audio_helper.dart';
import 'com_cons.dart';
import 'game.dart';
import 'script_runner.dart';
import 'storage_helper.dart';
import 'text_processor.dart';

class WidgetHelper{
  static Widget getMenuButton(String txt, bool flag, Function() onPress) {
    return ElevatedButton(
      child: Text(txt),
      style: ElevatedButton.styleFrom(
        primary: Colors.white,
        onPrimary: flag ? Colors.orangeAccent : Colors.blueGrey,
      ),
      onPressed: onPress,
    );
  }

  static Widget getCommonWidgetForGameContainer(Widget childWidget,
      ValueNotifier<double> opacityNotifier,
      ValueNotifier<List<double>> rotateNotifier,
      ValueNotifier<List<double?>> positionNotifier,
      {double xOffset= 0, double yOffset= 0,}){
    return ValueListenableBuilder(
      valueListenable: positionNotifier,
      builder: (_, positionValue, __) => Positioned(
        left: (positionValue as List<double?>)[0],
        top: positionValue[1],
        right: positionValue[2],
        bottom: positionValue[3],
        width: positionValue[4],
        height: positionValue[5],
        child: ValueListenableBuilder(
          valueListenable: opacityNotifier,
          builder: (_, opacityValue, __) => Opacity(
            opacity: opacityValue as double,
            child: ValueListenableBuilder(
              valueListenable: rotateNotifier,
              builder: (_, rotateValue, __) => Transform(
                alignment: Alignment(xOffset, yOffset),
                transform: Matrix4.rotationZ(CommonFunc.getRotateValue((rotateValue as List<double>)[0])),
                child: Transform(
                  alignment: Alignment(0, 0),
                  transform: Matrix4.rotationY(CommonFunc.getRotateValue(rotateValue[1])),
                  //child: Transform(
                  //alignment: Alignment(0, 0),
                  //transform: Matrix4.rotationX(rotateValue[2]),
                  child: childWidget,
                  //),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TextBoxClipper extends CustomClipper<Path> {
  final double width;
  final double preHeight;
  final double height;
  final double position;
  TextBoxClipper({required this.width, required this.preHeight, required this.height, required this.position});
  Path getClip(Size size) {
    var path = Path();
    path.moveTo(0.0, 0.0);
    path.lineTo(width, 0.0);
    path.lineTo(width, preHeight);
    path.lineTo(position, preHeight);
    path.lineTo(position, height);
    path.lineTo(0.0, height);
    path.lineTo(0.0, 0.0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(TextBoxClipper oldClipper) {
    return position!= oldClipper.position;
  }
}

class GameSaveLoad extends StatefulWidget {
  GameSaveLoad({Key? key, required this.canSave, required this.onSave, required this.onLoad})
      : super(key: key);
  final bool canSave;
  final Function(int) onSave;
  final Function(int, int) onLoad;

  static const int MAX_PAGE_COUNT = 5;
  static const int MAX_SAVE_IN_ONE_PAGE = 10;
  static const double BUTTON_ASPECT_RATIO = 1;

  @override
  _GameSaveLoadState createState() => _GameSaveLoadState();
}

class _GameSaveLoadState extends State<GameSaveLoad> {
  late ScrollController _scrollController;

  @override
  void initState() {
    _scrollController= ScrollController(initialScrollOffset:
    UserConfig.getDouble(UserConfig.LAST_SAVE_LOAD_MENU_SCROLL_POSITION),
        keepScrollOffset: false)..addListener(() {
      UserConfig.saveDouble(UserConfig.LAST_SAVE_LOAD_MENU_SCROLL_POSITION, _scrollController.offset);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Column(
        children: [
          Expanded(
            flex: 1,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemExtent: 50,
              itemCount: GameSaveLoad.MAX_PAGE_COUNT,
              itemBuilder: (BuildContext context, int index) {
                return InkWell(
                  child: Container(
                    decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        color: UserConfig.getInt(UserConfig.LAST_SAVE_LOAD_MENU_PAGE) == index
                            ? Colors.lightBlueAccent
                            : Colors.black38),
                    child: Center(
                        child: TextProcessor.simpleRichText((index + 1).toString())),
                  ),
                  onTap: () {
                    UserConfig.save(UserConfig.LAST_SAVE_LOAD_MENU_PAGE, index.toString());
                    setState(() {});
                  },
                );
              },
            ),
          ),
          Expanded(
            flex: 7,
            child: ListView.builder(
              controller: _scrollController,
              itemExtent: 80,
              itemCount: GameSaveLoad.MAX_SAVE_IN_ONE_PAGE,
              itemBuilder: (BuildContext context, int index) {
                final int saveIndex = index +
                    (UserConfig.getInt(UserConfig.LAST_SAVE_LOAD_MENU_PAGE) * GameSaveLoad.MAX_SAVE_IN_ONE_PAGE);
                return FutureBuilder(
                  future: SavesInfo.loadLessData(GameSaveType.NORMAL, saveIndex),
                  builder: (context, snapshot){
                    if(snapshot.connectionState!= ConnectionState.done){
                      return Container();
                    }
                    SavesInfo saveInfo= snapshot.data as SavesInfo;
                    final Color rowBackColor = saveInfo.isEmpty()
                        ? Colors.black : Colors.greenAccent;
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            tileMode: TileMode.clamp,
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            stops: [
                              0,
                              1,
                            ],
                            colors: [
                              rowBackColor,
                              rowBackColor.withOpacity(0.3),
                            ]),
                      ),
                      child: Row(
                        children: [
                          Padding(
                              padding: const EdgeInsets.only(left: 3, right: 3),
                              child: Center(
                                child: TextProcessor.simpleRichText((saveIndex + 1).toString()),
                              )),
                          if (saveInfo.thumbPath.length > 0)
                            AspectRatio(
                              aspectRatio: GameConstant.GAME_ASPECT_RATIO,
                              child: Image.file(
                                File(SavesInfo.getSaveThumbPath(saveInfo.thumbPath)),
                                key: UniqueKey(),
                              ),
                            ),
                          Expanded(
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: Container(
                                  color: Colors.transparent,
                                  child: TextProcessor.simpleRichText(saveInfo.dateTime + "<br><setsize=14>" + saveInfo.text),
                                ),
                              )),
                          Column(
                            children: [
                              const Spacer(),
                              Expanded(
                                  flex: 3,
                                  child: Container(
                                    width: 1,
                                    color: Colors.white70,
                                  )),
                              const Spacer()
                            ],
                          ),
                          if (widget.canSave)
                            SizedBox(
                              width: 50,
                              child: InkWell(
                                  onTap: () {
                                    widget.onSave(saveInfo.slot);
                                  },
                                  child: const Center(
                                      child: Icon(Icons.file_download,
                                          color: Colors.white))),
                            )
                          else
                            SizedBox(
                                width: 50,
                                child: const Center(
                                    child: Icon(Icons.file_download,
                                        color: Colors.grey))),
                          Column(
                            children: [
                              const Spacer(),
                              Expanded(
                                  flex: 3,
                                  child: Container(
                                    width: 1,
                                    color: Colors.white70,
                                  )),
                              const Spacer()
                            ],
                          ),
                          if (!saveInfo.isEmpty())
                            SizedBox(
                              width: 50,
                              child: InkWell(
                                  onTap: () {
                                    widget.onLoad(saveInfo.type, saveInfo.slot);
                                  },
                                  child: const Center(
                                      child: Icon(Icons.file_upload,
                                          color: Colors.white))),
                            )
                          else SizedBox(
                              width: 50,
                              child: const Center(child: Icon(Icons.file_upload, color: Colors.grey))
                          ),
                          Column(
                            children: [
                              const Spacer(),
                              Expanded(
                                  flex: 3,
                                  child: Container(
                                    width: 1,
                                    color: Colors.white70,
                                  )
                              ),
                              const Spacer()
                            ],
                          ),
                          //if (!saveInfo.isEmpty()) SizedBox(
                          //  width: 50,
                          //  child: InkWell(
                          //    onTap: () {},
                          //    child: Center(
                          //      child: Icon(Icons.swap_vert,
                          //          color: Colors.white))
                          //  ),
                          //)
                          //else SizedBox(
                          //  width: 50,
                          //  child: Center(child: Icon(Icons.swap_vert, color: Colors.grey))
                          //),
                          Column(
                            children: [
                              const Spacer(),
                              Expanded(
                                  flex: 3,
                                  child: Container(
                                    width: 1,
                                    color: Colors.white70,
                                  )),
                              const Spacer()
                            ],
                          ),
                          if (!saveInfo.isEmpty()) SizedBox(
                            width: 50,
                            child: InkWell(
                                onTap: () {
                                  SavesInfo.deleteSaveData(
                                      saveInfo.type, saveInfo.slot)
                                      .whenComplete(() => setState(() {}));
                                },
                                child: const Center(
                                    child: Icon(Icons.delete_forever_outlined,
                                        color: Colors.white)
                                )
                            ),
                          )
                          else SizedBox(
                              width: 50,
                              child: const Center(
                                  child: Icon(Icons.delete_forever_outlined,
                                      color: Colors.grey))
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ChoiceHelper extends StatefulWidget {
  ChoiceHelper({Key? key, required this.onFreezeChoice, required this.onChoiceEnd}) : super(key: key);
  final Function(List<ScriptCommandInfo>) onChoiceEnd;
  final Function(ScriptCommandInfo) onFreezeChoice;
  final _ChoiceHelperState _state = _ChoiceHelperState();

  void addCommand(ScriptCommandInfo commandInfo) {
    _state._addCommand(commandInfo);
  }

  bool haveChoice(){
    return _state._listCommand.length> 0;
  }

  void clearChoice(){
    _state._clearChoice();
  }

  @override
  _ChoiceHelperState createState() {
    return _state;
  }
}

class _ChoiceHelperState extends State<ChoiceHelper> {
  List<ScriptCommandInfo> _listCommand = <ScriptCommandInfo>[];
  int _chosen = -1;
  bool _isDisplay= false;
  bool _userChosen= false;
  String _layout= "";
  late Widget _layoutWidget;

  void _addCommand(ScriptCommandInfo commandInfo) {
    _listCommand.add(commandInfo);
    if (commandInfo.containKey(ScriptCommand.CHOICE_LAYOUT)){
      _layout= commandInfo.valueOf(ScriptCommand.CHOICE_LAYOUT)!;
    }
    if (commandInfo.containKey(ScriptCommand.CHOICE_END)) {
      List<Widget> choiceList = <Widget>[];
      for (int i = 0; i < _listCommand.length; i++) {
        final index = i;
        final bool enable= (_chosen< 0 || _chosen== index)
            && !_listCommand[index].containKey(ScriptCommand.CHOICE_DISABLE_USER_CHOICE);
        String choiceLang= UserConfig.getBool(UserConfig.IS_ACTIVE_MAIN_LANGUAGE)
            ? UserConfig.get(UserConfig.GAME_MAIN_LANGUAGE)
            : UserConfig.get(UserConfig.GAME_SUB_LANGUAGE);
        choiceList.add(_getChoiceContainer(
            TextProcessor.simpleRichText(_listCommand[index].valueOf(choiceLang)!), index, enable
        ));
      }

      if(_layout.length> 0){
        if(_layout== "title"){
          _layoutWidget= Column(
            children: [
              const Spacer(),
              Expanded(
                flex: 1,
                child: Row(
                  children: [
                    const Spacer(flex: 6,),
                    Expanded(
                      flex: 8,
                      child: Center(
                        child: ListView(
                          children: choiceList,
                        ),
                      ),
                    ),
                    const Spacer(flex: 6,),
                  ],
                ),
              ),
            ],
          );
        }
      }else{
        _layoutWidget= Column(
          children: [
            const Spacer(),
            Expanded(
              flex: 7,
              child: Row(
                children: [
                  const Spacer(),
                  Expanded(
                    flex: 8,
                    child: Center(
                      child: ListView(
                        shrinkWrap: true,
                        children: choiceList,
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            const Spacer(flex: 2,),
          ],
        );
      }
      setState(() {
        _isDisplay= true;
      });
    }
  }

  Widget _getChoiceContainer(Widget child, int index, bool enable){
    if(_layout== "title"){
      return AnimatedOpacity(
        opacity: enable ? 1 : 0.5,
        duration: const Duration(milliseconds: 600),
        child: InkWell(
          child: Container(
            margin: EdgeInsets.only(bottom: 5),
            decoration: const BoxDecoration(gradient:
            const LinearGradient(tileMode: TileMode.mirror,
                begin: Alignment.center,
                end: Alignment.centerLeft,
                stops: [0, 1,],
                colors: [Colors.black, Colors.transparent,]
            )),
            child: Align(
              heightFactor: 1.2,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
          onTap: () {
            if(enable && !_userChosen){
              userChoose(index);
            }
          },
        ),
      );
    }
    return AnimatedOpacity(
      opacity: enable ? 1 : 0.5,
      duration: const Duration(milliseconds: 600),
      child: InkWell(
        child: Container(
          margin: EdgeInsets.only(bottom: 20),
          decoration: const BoxDecoration(gradient:
          const LinearGradient(tileMode: TileMode.mirror,
              begin: Alignment.center,
              end: Alignment.centerLeft,
              stops: [0, 1,],
              colors: [Colors.redAccent, Colors.transparent,]
          )),
          child: Align(
            heightFactor: 1.2,
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
        onTap: () {
          if(enable && !_userChosen){
            userChoose(index);
          }
        },
      ),
    );
  }

  void _clearChoice(){
    setState(() {
      _layout= "";
      _listCommand.clear();
      _chosen = -1;
      _isDisplay= false;
    });
  }

  void userChoose(int index) {
    if(_listCommand[index].containKey(ScriptCommand.CHOICE_FREEZE)){
      ScriptCommandInfo fakeCommand= ScriptCommandInfo(_listCommand[index].nextCommand);
      fakeCommand.isFake= true;
      widget.onFreezeChoice(fakeCommand);
      return;
    }
    for (int i = 0; i < _listCommand.length; i++){
      if(index!= i){
        _listCommand[i]= _listCommand[i].removeNextCommand();
      }
    }
    _userChosen= true;
    _chosen= index;
    setState(() {
      Future.delayed(Duration(milliseconds: 600)).whenComplete(() {
        setState(() {
          _isDisplay= false;
          Future.delayed(Duration(milliseconds: 600)).whenComplete(() {
            List<ScriptCommandInfo> listCopy= _listCommand.toList();
            _listCommand.clear();
            _chosen= -1;
            _userChosen= false;
            setState(() {
              widget.onChoiceEnd(listCopy);
              _layout= "";
            });
          });
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      child: _isDisplay ? Material(
        color: Colors.transparent,
        child: _listCommand.length == 0 ? Container() : _layoutWidget,
      ) : null,
    );
  }
}

class BackLog extends StatelessWidget {
  BackLog({Key? key, required this.backlogItems, required this.onJump}) : super(key: key);
  final List<BackLogItem> backlogItems;
  final ScrollController _scrollController= ScrollController();
  final Function(BackLogItem) onJump;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
    return Material(
      color: Colors.black,
      child: ListView.builder(
          padding: EdgeInsets.only(top: 20, bottom: 20),
          controller: _scrollController,
          itemCount: backlogItems.length,
          itemBuilder: (BuildContext context, int index){
            final BackLogItem backlogItem= backlogItems[index];
            final Color backgroundColor= backlogItem.saveType== GameSingleSaveType.CHOICE
                ? Colors.orange : Colors.transparent;

            return Container(
              decoration: BoxDecoration(
                color: backgroundColor,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 10,),
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: backlogItem.saveType== GameSingleSaveType.CHOICE ? null : InkWell(
                          onTap: (){
                            onJump(backlogItem);
                          },
                          child: const Center(child: Icon(Icons.settings_backup_restore_outlined, color: Colors.white,)),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: backlogItem.listVoiceCommand== null ? null : InkWell(
                          onTap: (){
                            AudioHelper.playBackLogVoice(backlogItem.listVoiceCommand!.toList());
                          },
                          child: const Center(child: Icon(Icons.keyboard_voice_outlined, color: Colors.white,)),
                        ),
                      ),
                      Expanded(
                        child: TextProcessor.simpleRichText(backlogItem.combineText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3,),
                  SizedBox(
                    height: 1,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 7,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.deepPurple,
                            ),
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
      ),
    );
  }
}

class ConfigWidget extends StatefulWidget {
  @override
  _ConfigWidgetState createState() => _ConfigWidgetState();
}

class _ConfigWidgetState extends State<ConfigWidget> {
  Widget _getCommonConfigCard(String configLabel, Widget childWidget){
    return Card(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(1))),
      color: const Color(0xFF383737),
      margin: const EdgeInsets.all(3),
      child: Container(
        padding: const EdgeInsets.all(5),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextProcessor.simpleRichText(configLabel),
            ),
            childWidget,
          ],
        ),
      ),
    );
  }

  Widget _getGeneralTabContent(){
    return ListView(
      children: [
        _getCommonConfigCard(
            GameText.CONFIG_TAB_GENERAL_MENU_LANGUAGE,
            Row(
              children: [
                Switch(
                    value: UserConfig.get(UserConfig.MENU_LANGUAGE)== Language.VIETNAMESE,
                    onChanged: (isEnable){
                      UserConfig.save(UserConfig.MENU_LANGUAGE, isEnable ? Language.VIETNAMESE : Language.JAPANESE);
                      GameText.loadMenuByLanguage(UserConfig.get(UserConfig.MENU_LANGUAGE));
                      setState(() {});
                    }
                ),
                ValueListenableBuilder(
                  valueListenable: UserConfig.getListener(UserConfig.MENU_LANGUAGE),
                  builder: (_, box, __) {
                    return UserConfig.get(UserConfig.MENU_LANGUAGE)== Language.VIETNAMESE
                        ? TextProcessor.simpleRichText("Tiếng Việt")
                        : TextProcessor.simpleRichText("日本語");
                  },
                )
              ],
            )
        ),
        _getCommonConfigCard(
            GameText.CONFIG_TAB_GENERAL_KEEP_AUTO_MODE,
            Row(
              children: [
                Switch(
                    value: UserConfig.getBool(UserConfig.IS_KEEP_AUTO_MODE),
                    onChanged: (isKeep){
                      UserConfig.saveBool(UserConfig.IS_KEEP_AUTO_MODE, isKeep);
                      setState(() {});
                    }
                ),
                ValueListenableBuilder(
                  valueListenable: UserConfig.getListener(UserConfig.IS_KEEP_AUTO_MODE),
                  builder: (_, box, __) {
                    return UserConfig.getBool(UserConfig.IS_KEEP_AUTO_MODE)
                        ? const Icon(Icons.check, color: Colors.green, size: 25)
                        : const Icon(Icons.close, color: Colors.grey, size: 25);
                  },
                )
              ],
            )
        ),
      ],
    );
  }

  Widget _getSoundTabContent(){
    return ListView(
      children: [
        _getCommonConfigCard(
            GameText.CONFIG_TAB_SOUND_VOLUME_MASTER,
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Slider(
                    divisions: 100,
                    value: UserConfig.getDouble(UserConfig.GAME_VOLUME_MASTER),
                    onChanged: (value){
                      UserConfig.saveDouble(UserConfig.GAME_VOLUME_MASTER, value);
                      setState(() {});
                    },
                    onChangeEnd: (value){
                      AudioHelper.reConfigBgmVolume();
                    },
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: ValueListenableBuilder(
                    valueListenable: UserConfig.getListener(UserConfig.GAME_VOLUME_MASTER),
                    builder: (_, box, __) {
                      return TextProcessor.simpleRichText(
                          (UserConfig.getDouble(UserConfig.GAME_VOLUME_MASTER)
                          *100).round().toString()+ "%");
                    },
                  ),
                ),
              ],
            )
        ),
        _getCommonConfigCard(
            GameText.CONFIG_TAB_SOUND_VOLUME_BG,
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Slider(
                    divisions: 100,
                    value: UserConfig.getDouble(UserConfig.GAME_VOLUME_BG),
                    onChanged: (value){
                      UserConfig.saveDouble(UserConfig.GAME_VOLUME_BG, value);
                      setState(() {});
                    },
                    onChangeEnd: (value){
                      AudioHelper.reConfigBgmVolume();
                    },
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: ValueListenableBuilder(
                    valueListenable: UserConfig.getListener(UserConfig.GAME_VOLUME_BG),
                    builder: (_, box, __) {
                      return TextProcessor.simpleRichText(
                          (UserConfig.getDouble(UserConfig.GAME_VOLUME_BG)
                              *100).round().toString()+ "%");
                    },
                  ),
                ),
              ],
            )
        ),
        _getCommonConfigCard(
            GameText.CONFIG_TAB_SOUND_VOLUME_SE,
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Slider(
                    divisions: 100,
                    value: UserConfig.getDouble(UserConfig.GAME_VOLUME_SE),
                    onChanged: (value){
                      UserConfig.saveDouble(UserConfig.GAME_VOLUME_SE, value);
                      setState(() {});
                    },
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: ValueListenableBuilder(
                    valueListenable: UserConfig.getListener(UserConfig.GAME_VOLUME_SE),
                    builder: (_, box, __) {
                      return TextProcessor.simpleRichText(
                          (UserConfig.getDouble(UserConfig.GAME_VOLUME_SE)
                              *100).round().toString()+ "%");
                    },
                  ),
                ),
              ],
            )
        ),
        _getCommonConfigCard(
            GameText.CONFIG_TAB_SOUND_VOLUME_VOICE,
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Slider(
                    divisions: 100,
                    value: UserConfig.getDouble(UserConfig.GAME_VOLUME_VOICE_COMMON),
                    onChanged: (value){
                      UserConfig.saveDouble(UserConfig.GAME_VOLUME_VOICE_COMMON, value);
                      setState(() {});
                    },
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: ValueListenableBuilder(
                    valueListenable: UserConfig.getListener(UserConfig.GAME_VOLUME_VOICE_COMMON),
                    builder: (_, box, __) {
                      return TextProcessor.simpleRichText(
                          (UserConfig.getDouble(UserConfig.GAME_VOLUME_VOICE_COMMON)
                              *100).round().toString()+ "%");
                    },
                  ),
                ),
              ],
            )
        ),
        _getCommonConfigCard(
            GameText.CONFIG_TAB_SOUND_VOICE_DONE_IS_WAIT,
            Row(
              children: [
                Switch(
                    value: UserConfig.getBool(UserConfig.IS_WAIT_VOICE_END_AUTO_MODE),
                    onChanged: (isWait){
                      UserConfig.saveBool(UserConfig.IS_WAIT_VOICE_END_AUTO_MODE, isWait);
                      setState(() {});
                    }
                ),
                ValueListenableBuilder(
                  valueListenable: UserConfig.getListener(UserConfig.IS_WAIT_VOICE_END_AUTO_MODE),
                  builder: (_, box, __) {
                    return UserConfig.getBool(UserConfig.IS_WAIT_VOICE_END_AUTO_MODE)
                        ? const Icon(Icons.check, color: Colors.green, size: 25)
                        : const Icon(Icons.close, color: Colors.grey, size: 25);
                  },
                )
              ],
            )
        ),
      ],
    );
  }

  Widget _getTextTabContent(){
    return ListView(
      children: [
        _getCommonConfigCard(
            GameText.CONFIG_TAB_TEXT_LANGUAGE,
            Row(
              children: [
                Checkbox(
                  value: UserConfig.getBool(UserConfig.IS_ACTIVE_MAIN_LANGUAGE),
                  onChanged: (value) {
                    UserConfig.saveBool(UserConfig.IS_ACTIVE_MAIN_LANGUAGE, value!);
                    setState(() {});
                  },
                ),
                TextProcessor.simpleRichText("日本語"),
                Checkbox(
                  value: UserConfig.getBool(UserConfig.IS_ACTIVE_SUB_LANGUAGE),
                  onChanged: (value) {
                    UserConfig.saveBool(UserConfig.IS_ACTIVE_SUB_LANGUAGE, value!);
                    setState(() {});
                  },
                ),
                TextProcessor.simpleRichText("Tiếng Việt"),
              ],
            )
        ),
        _getCommonConfigCard(
          GameText.CONFIG_TAB_TEXT_TEXTBOX_BG_OPACITY,
          Row(
            children: [
              Expanded(
                flex: 1,
                child: Slider(
                  divisions: 100,
                  value: UserConfig.getDouble(UserConfig.TEXT_BOX_BACKGROUND_OPACITY),
                  onChanged: (value){
                    UserConfig.saveDouble(UserConfig.TEXT_BOX_BACKGROUND_OPACITY, value);
                    setState(() {});
                  },
                ),
              ),
              Expanded(
                flex: 1,
                child: ValueListenableBuilder(
                  valueListenable: UserConfig.getListener(UserConfig.TEXT_BOX_BACKGROUND_OPACITY),
                  builder: (_, box, __) {
                    return TextProcessor.simpleRichText(
                        (UserConfig.getDouble(UserConfig.TEXT_BOX_BACKGROUND_OPACITY)
                            *100).round().toString()+ "%");
                  },
                ),
              ),
            ],
          )
        ),
        _getCommonConfigCard(
            GameText.CONFIG_TAB_TEXT_TEXT_SIZE,
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Slider(
                    divisions: 20,
                    min: 20,
                    max: 60,
                    value: UserConfig.getDouble(UserConfig.TEXT_SIZE)*2,
                    onChanged: (value){
                      UserConfig.saveDouble(UserConfig.TEXT_SIZE, value/2);
                      setState(() {});
                    },
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: ValueListenableBuilder(
                    valueListenable: UserConfig.getListener(UserConfig.TEXT_SIZE),
                    builder: (_, box, __) {
                      return TextProcessor.simpleRichText(
                          (UserConfig.getDouble(UserConfig.TEXT_SIZE))
                              .toStringAsFixed(1));
                    },
                  ),
                ),
              ],
            )
        ),
        _getCommonConfigCard(
            GameText.CONFIG_TAB_TEXT_TEXT_SPEED,
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Slider(
                    min: 0,
                    max: 300,
                    divisions: 60,
                    value: 300- UserConfig.getDouble(UserConfig.ONE_CHARACTER_DISPLAY_TIME),
                    onChanged: (value){
                      UserConfig.saveDouble(UserConfig.ONE_CHARACTER_DISPLAY_TIME, 300- value);
                      setState(() {});
                    },
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: ValueListenableBuilder(
                    valueListenable: UserConfig.getListener(UserConfig.ONE_CHARACTER_DISPLAY_TIME),
                    builder: (_, box, __) {
                      return TextProcessor.simpleRichText(
                          (300- UserConfig.getDouble(UserConfig.ONE_CHARACTER_DISPLAY_TIME))
                              .round().toString());
                    },
                  ),
                ),
              ],
            )
        ),
        _getCommonConfigCard(
            GameText.CONFIG_TAB_TEXT_AUTO_WAIT_TIME,
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Slider(
                    divisions: 50,
                    min: 0,
                    max: 5000,
                    value: UserConfig.getDouble(UserConfig.AUTO_END_WAIT_TIME),
                    onChanged: (value){
                      UserConfig.saveDouble(UserConfig.AUTO_END_WAIT_TIME, value);
                      setState(() {});
                    },
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: ValueListenableBuilder(
                    valueListenable: UserConfig.getListener(UserConfig.AUTO_END_WAIT_TIME),
                    builder: (_, box, __) {
                      return TextProcessor.simpleRichText(
                          (UserConfig.getDouble(UserConfig.AUTO_END_WAIT_TIME))
                              .round().toString()+ "ms");
                    },
                  ),
                ),
              ],
            )
        ),
      ],
    );
  }

  Widget _getCharacterTabContent(){
    return ListView(
      children: [
        _getCommonConfigCard(
            GameText.CONFIG_TAB_CHARACTER_LIP_SYNC,
            Row(
              children: [
                Switch(
                    value: UserConfig.getBool(UserConfig.ENABLE_LIP_SYNC),
                    onChanged: (isEnable){
                      UserConfig.saveBool(UserConfig.ENABLE_LIP_SYNC, isEnable);
                      setState(() {});
                    }
                ),
                ValueListenableBuilder(
                  valueListenable: UserConfig.getListener(UserConfig.ENABLE_LIP_SYNC),
                  builder: (_, box, __) {
                    return UserConfig.getBool(UserConfig.ENABLE_LIP_SYNC)
                        ? const Icon(Icons.emoji_emotions_outlined, color: Colors.green, size: 25)
                        : const Icon(Icons.masks, color: Colors.grey, size: 25);
                  },
                )
              ],
            )
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Column(
        children: [
          Expanded(
            flex: 1,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              itemBuilder: (BuildContext context, int index) {
                String tabName= GameText.CONFIG_TAB_GENERAL;
                if(index== 0){
                  tabName= GameText.CONFIG_TAB_GENERAL;
                }else if(index== 1){
                  tabName= GameText.CONFIG_TAB_SOUND;
                }else if(index== 2){
                  tabName= GameText.CONFIG_TAB_TEXT;
                }else if(index== 3){
                  tabName= GameText.CONFIG_TAB_CHARACTER;
                }
                return InkWell(
                  child: Container(
                    decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        color: UserConfig.getInt(UserConfig.LAST_CONFIG_TAB_INDEX) == index
                            ? Colors.lightBlueAccent
                            : Colors.black38),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10, right: 10),
                      child: Center(
                        child: RichText(
                          text: TextSpan(children: TextProcessor.buildSpanFromString(tabName))
                        ),
                      ),
                    ),
                  ),
                  onTap: () {
                    UserConfig.saveInt(UserConfig.LAST_CONFIG_TAB_INDEX, index);
                    setState(() {});
                  },
                );
              },
            ),
          ),
          Expanded(
            flex: 7,
            child: ValueListenableBuilder(
              valueListenable: UserConfig.getListener(UserConfig.LAST_CONFIG_TAB_INDEX),
              builder: (_, box, __) {
                final int index= UserConfig.getInt(UserConfig.LAST_CONFIG_TAB_INDEX);
                if(index== 0){
                  return _getGeneralTabContent();
                }
                if(index== 1){
                  return _getSoundTabContent();
                }
                if(index== 2){
                  return _getTextTabContent();
                }
                if(index== 3){
                  return _getCharacterTabContent();
                }
                return Container();
              }
            ),
          ),
        ],
      ),
    );
  }
}

class QuickMenu extends StatefulWidget {
  static const double PADDING= 40;
  QuickMenu({Key? key}) : super(key: key);

  final _QuickMenuState _state= _QuickMenuState();

  void show(){
    _state._show();
  }

  void update(Offset panPosition){
    _state._update(panPosition);
  }

  String hide(){
    return _state._hide();
  }

  @override
  _QuickMenuState createState() => _state;
}

class _QuickMenuState extends State<QuickMenu> {
  bool _isShow= false;
  String _activeLabel= "";
  late double _quickMenuHDelta, _quickMenuVDelta, _quickMenuSize;
  String? _panCommand;

  void _show(){
    setState(() {
      _isShow= true;
    });
    Size contextSize= context.size == null ?  Size(0,0) : context.size!;

    double widthHeightDelta= contextSize.width- contextSize.height;
    if(widthHeightDelta > 0){
      _quickMenuHDelta= QuickMenu.PADDING+ widthHeightDelta/2;
      _quickMenuVDelta= QuickMenu.PADDING;
      _quickMenuSize= contextSize.height- _quickMenuVDelta*2;
    }else{
      _quickMenuHDelta= QuickMenu.PADDING;
      _quickMenuVDelta= QuickMenu.PADDING- widthHeightDelta/2;
      _quickMenuSize= contextSize.width- _quickMenuHDelta*2;
    }
  }

  void _update(Offset panPosition){
    if(panPosition.dx< (_quickMenuSize/ 3)+ _quickMenuHDelta){
      if(panPosition.dy< (_quickMenuSize/ 3)+ _quickMenuVDelta){
        _panCommand=MyAppCmd.QUICK_LOAD;
        _switchLabel(GameText.MENU_QUICK_LOAD);
      }else if (panPosition.dy> (_quickMenuSize* 2/ 3)+ _quickMenuVDelta){
        _panCommand=MyAppCmd.QUICK_SAVE;
        _switchLabel(GameText.MENU_QUICK_SAVE);
      }else{
        _panCommand=MyAppCmd.HIDE_TEXT_BOX;
        _switchLabel(GameText.MENU_HIDE_TEXT_BOX);
      }
    }else if (panPosition.dx> (_quickMenuSize* 2/ 3)+ _quickMenuHDelta){
      if(panPosition.dy< (_quickMenuSize/ 3)+ _quickMenuVDelta){
        _panCommand=MyAppCmd.SWITCH_SKIP_READ;
        _switchLabel(GameText.MENU_TRIGGER_SKIP_READ);
      }else if (panPosition.dy> (_quickMenuSize* 2/ 3)+ _quickMenuVDelta){
        _panCommand=MyAppCmd.SWITCH_SKIP_ALL;
        _switchLabel(GameText.MENU_TRIGGER_SKIP_ALL);
      }else{
        _panCommand=MyAppCmd.SWITCH_AUTO_READ;
        _switchLabel(GameText.MENU_TRIGGER_AUTO);
      }
    }else{
      if(panPosition.dy< (_quickMenuSize/ 3)+ _quickMenuVDelta){
        _panCommand=MyAppCmd.OPEN_BACK_LOG;
        _switchLabel(GameText.MENU_BACK_LOG);
      }else if (panPosition.dy> (_quickMenuSize* 2/ 3)+ _quickMenuVDelta){
        _panCommand=MyAppCmd.OPEN_SAVE_LOAD;
        _switchLabel(GameText.MENU_SAVE_AND_LOAD);
      }else{
        _panCommand= null;
        _switchLabel(GameText.QUICK_MENU_CANCEL);
      }
    }
  }

  String _hide(){
    setState(() {
      _isShow= false;
    });
    final String panCommand= _panCommand== null ? "" : _panCommand!;
    _panCommand= null;
    return panCommand;
  }

  void _switchLabel(String label){
    setState(() {
      _activeLabel= label;
    });
  }

  Widget _getItemCard(final String label){
    return Card(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(50))),
      color: _activeLabel== label ? Colors.blueAccent : Color(0xFF383737),
      margin: const EdgeInsets.all(3),
      child: Center(
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: TextProcessor.buildSpanFromString(label),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _isShow ? Container(
        color: Colors.black38,
        child: Padding(
          padding: const EdgeInsets.all(QuickMenu.PADDING),
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _getItemCard(GameText.MENU_QUICK_LOAD),
                        ),
                        Expanded(
                          child: _getItemCard(GameText.MENU_BACK_LOG),
                        ),
                        Expanded(
                          child: _getItemCard(GameText.MENU_TRIGGER_SKIP_READ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _getItemCard(GameText.MENU_HIDE_TEXT_BOX),
                        ),
                        Expanded(
                          child: _getItemCard(GameText.QUICK_MENU_CANCEL),
                        ),
                        Expanded(
                          child: _getItemCard(GameText.MENU_TRIGGER_AUTO),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _getItemCard(GameText.MENU_QUICK_SAVE),
                        ),
                        Expanded(
                          child: _getItemCard(GameText.MENU_SAVE_AND_LOAD),
                        ),
                        Expanded(
                          child: _getItemCard(GameText.MENU_TRIGGER_SKIP_ALL),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ) : null,
    );
  }
}

class GameTextMenu extends StatefulWidget {
  static const int SPLIT_WIDGET_COUNT= 4;
  GameTextMenu({Key? key, required this.boundSize}) : super(key: key);
  final Size boundSize;

  void update(Offset panPosition){
    _state._update(panPosition);
  }

  int hide(){
    return _state._hide();
  }

  final _GameTextMenuState _state= _GameTextMenuState();
  @override
  _GameTextMenuState createState() => _state;
}

class _GameTextMenuState extends State<GameTextMenu> {
  late double _textMenuWidth= widget.boundSize.width;
  int _displayTextCommand= -1;

  void _update(Offset panPosition){
    if(panPosition.dx< (_textMenuWidth/ GameTextMenu.SPLIT_WIDGET_COUNT)){
      _switchIndex(1);
    }else if (panPosition.dx< (_textMenuWidth*2/ GameTextMenu.SPLIT_WIDGET_COUNT)){
      _switchIndex(2);
    }else if (panPosition.dx< (_textMenuWidth*3/ GameTextMenu.SPLIT_WIDGET_COUNT)){
      _switchIndex(3);
    }else{
      _switchIndex(4);
    }
  }

  int _hide(){
    final int command= _displayTextCommand;
    _displayTextCommand= -1;
    setState(() {

    });
    return command;
  }

  void _switchIndex(int index){
    setState(() {
      _displayTextCommand= index;
    });
  }

  Widget _getTextMenuCard(final String label, final int index){
    return Expanded(
      child: Card(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(50))),
        color: _displayTextCommand== index ? Colors.blueAccent : Color(0xFF383737),
        margin: const EdgeInsets.all(3),
        child: Center(
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: TextProcessor.buildSpanFromString(label),
            ),
          ),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Container(
        color: Colors.black38,
        child: Row(
          children: [
            _getTextMenuCard(GameText.TEXT_MENU_MAIN_LANGUAGE, 1),
            _getTextMenuCard(GameText.TEXT_MENU_SUB_LANGUAGE, 2),
            _getTextMenuCard(GameText.TEXT_MENU_HIRAGANA, 3),
            _getTextMenuCard(GameText.TEXT_MENU_PLAY_VOICE, 4),
          ],
        ),
      ),
    );
  }
}











