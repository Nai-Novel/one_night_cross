import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as Path;
import 'audio_helper.dart';
import 'game_widget_helper.dart';
import 'image_helper.dart';
import 'script_runner.dart';
import 'com_cons.dart';
import 'package:video_player/video_player.dart';
import 'dart:ui' as ui;

import 'storage_helper.dart';
import 'text_processor.dart';
part 'game_helper.dart';

final GlobalKey _gameContainerKey = GlobalKey();
final GlobalKey _sceneContainerKey = GlobalKey();
final GlobalKey _textContainerKey = GlobalKey();
final GlobalKey _overlayContainerKey = GlobalKey();
final GlobalKey _gameMenuKey = GlobalKey();
Size _sceneSize= Size(0,0);
late ScriptRunner _scriptRunner;
HashMap<String, ui.Image> _imageCache= HashMap<String, ui.Image>();

void _completeScriptCommand(ScriptCommandInfo commandInfo, [bool isCountForExecution= true]){
  commandInfo.complete();
  _scriptRunner.completeCommand(commandInfo, isCountForExecution);
}

class MyApp extends StatelessWidget {
  MyApp({Key? key, this.file, this.command}) : super(key: key);
  final String? file;
  final StartAppCommand? command;

  final GameContainer _gameContainer= GameContainer(
    key: _gameContainerKey,
    layerName: ContainerKeyName.GAME_CONTAINER,
  );
  final MenuContainer _menuContainer = MenuContainer(key: _gameMenuKey);
  final OverlayContainer _overlayContainer = OverlayContainer(key: _overlayContainerKey,);

  void _processCommand(ScriptCommandInfo commandInfo) {
    if (commandInfo.header== ScriptCommand.SET_HEADER) {
      _scriptRunner.saveVariable(commandInfo);

      _completeScriptCommand(commandInfo);
      return;
    }
    if (commandInfo.header== ScriptCommand.CHECK_HEADER) {
      ScriptCommandInfo toComplete= _scriptRunner.checkVariable(commandInfo);

      _completeScriptCommand(toComplete);
      return;
    }
    if (commandInfo.header == ScriptCommand.LABEL_HEADER){
      _completeScriptCommand(commandInfo);
      return;
    }
    _gameContainer._state._processCommand(commandInfo);
  }

  @override
  Widget build(BuildContext context) {
    GameConstant.preInit();
    WidgetsFlutterBinding.ensureInitialized();
    WidgetsBinding.instance!.addObserver(LifecycleEventHandler());
    _scriptRunner = ScriptRunner(_processCommand);
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      _sceneSize= _sceneContainerKey.currentContext!.size!;
      _scriptRunner.setOnReadySaveCallBack(() {
        return _gameContainer._state.collectSave();
      });
      if(command== StartAppCommand.LOAD_LAST_SAVE){
        _scriptRunner.loadCurrentSave();
      }else if(command== StartAppCommand.RUN_SCRIPT){
        _scriptRunner.setScript(ScriptItem(file!, null), true);
      }
    });

    SystemChrome.setEnabledSystemUIOverlays([]);
    return Stack(
      fit: StackFit.expand,
      children: [
        _gameContainer,
        _menuContainer,
        _overlayContainer,
      ],
    );
  }
}

class GameContainer extends StatefulWidget {
  GameContainer({Key? key, required this.layerName}) : super(key: key);
  final _GameContainerState _state = _GameContainerState();
  final String layerName;

  @override
  _GameContainerState createState() {
    return _state;
  }
}

class _GameContainerState extends State<GameContainer>
    with TickerProviderStateMixin{
  final SceneContainer _sceneContainer = SceneContainer(
    layerName: ContainerKeyName.GAME_CONTAINER,
  );
  final TextContainer _textContainer = TextContainer(
    key: _textContainerKey,
    layerName: ContainerKeyName.TEXT_BOUND,
  );
  List<String> collectSave(){
    List<String> ret= <String>[];
    if(_imageCache.length> 0){return ret;}
    ret.addAll(_textContainer.getSaveString());
    ret.addAll(AudioHelper.getSaveString());
    ret.addAll(_sceneContainer.getSaveString());
    return ret;
  }

  @override
  void dispose() {
    _scriptRunner.userSave(GameSaveType.CURRENT, "").whenComplete(() {
      _scriptRunner.dispose();
    });
    AudioHelper.disposeAllAudio();
    AlreadyReadHelper.compact();
    timeDilation= 1;
    super.dispose();
  }

  void _processCommand(ScriptCommandInfo commandInfo,[bool checkDelay= true]) {
    if(commandInfo.containKey(ScriptCommand.COMMON_COMMAND_CONTINUE)){
      _completeScriptCommand(commandInfo);
    }
    if (commandInfo.containKey(ScriptCommand.COMMON_DELAY) && checkDelay) {
      //Delay before process
      AnimationController _animationController= AnimationController(vsync: this);
      _animationController.duration= Duration(
          milliseconds: commandInfo.valueIntOf(ScriptCommand.COMMON_DELAY)!);
      _animationController.forward().whenCompleteOrCancel(() {
        _animationController.dispose();
        _processCommand(commandInfo, false);
      });
      return;
    }
    if(commandInfo.header== ScriptCommand.WAIT_HEADER){
      AnimationController _animationController= AnimationController(vsync: this);
      _animationController.duration= Duration(milliseconds: 1000);
      if(commandInfo.containKey(ScriptCommand.WAIT_TIME)){
        _animationController.duration= Duration(
            milliseconds: commandInfo.valueIntOf(ScriptCommand.WAIT_TIME)!);
      }
      if(commandInfo.containKey(ScriptCommand.WAIT_VOICE)){
        String voicePath = AssetConstant.getTruePath(
            AssetConstant.SOUND_VOICE_DIR
                + commandInfo.valueOf(ScriptCommand.WAIT_VOICE)!);
        _animationController.duration= Duration(
            milliseconds: CommonFunc.getDurationInPath(voicePath));
      }
      if(commandInfo.containKey(ScriptCommand.WAIT_SE)){
        String sePath = AssetConstant.getTruePath(
            AssetConstant.SOUND_SOUND_EFFECT_DIR
                + commandInfo.valueOf(ScriptCommand.WAIT_SE)!);
        _animationController.duration= Duration(
            milliseconds: CommonFunc.getDurationInPath(sePath));
      }
      _animationController.forward().whenCompleteOrCancel(() {
        _animationController.dispose();
        _completeScriptCommand(commandInfo);
      });
      return;
    }
    if (commandInfo.header == ScriptCommand.APP_COMMAND_HEADER) {
      String cmd= commandInfo.valueOf(ScriptCommand.COMMON_NAME)!;
      if(cmd== MyAppCmd.QUIT_GAME){
        _scriptRunner.userSave(GameSaveType.CURRENT, "").whenComplete(() {
          AudioHelper.disposeAllAudio().whenComplete(() {
            Navigator.pop(context);
          });
        });
      }else{
        _doAppCommand(cmd);
        _completeScriptCommand(commandInfo);
      }
      return;
    }
    if (commandInfo.header == ScriptCommand.TEXT_HEADER) {
      _textContainer._state.processTextCommand(commandInfo);
      return;
    }
    if (commandInfo.header == ScriptCommand.IMAGE_HEADER){
      _sceneContainer._state.processImageCommand(commandInfo);
      return;
    }
    if (commandInfo.header == ScriptCommand.VIDEO_HEADER){
      _sceneContainer._state.processVideoCommand(commandInfo);
      return;
    }
    if (commandInfo.header == ScriptCommand.LAYER_HEADER){
      _sceneContainer._state.processLayerCommand(commandInfo);
      return;
    }
    if (commandInfo.header == ScriptCommand.CHOICE_HEADER){
      _textContainer._state.processChoiceCommand(commandInfo);
      return;
    }
    if (commandInfo.header == ScriptCommand.SOUND_HEADER) {
      //if (UserConfig.getBool(UserConfig.ENABLE_LIP_SYNC)
      //    && _scriptRunner.isNoSkipFlag()
      //    && commandInfo.valueOf(ScriptCommand.SOUND_TYPE) == ScriptCommand.SOUND_TYPE_VOICE) {
      //  _sceneContainer._state.lipSyncCommand(commandInfo);
      //}
      bool isSkipping= _scriptRunner.haveRunFlag(ScriptRunFlag.SKIP_READ)
          || _scriptRunner.haveRunFlag(ScriptRunFlag.SKIP_ALL)
          || _scriptRunner.haveRunFlag(ScriptRunFlag.SKIP_MAX);
      if(commandInfo.valueOf(ScriptCommand.SOUND_TYPE)== ScriptCommand.SOUND_TYPE_BG){
        String? fadeTime= commandInfo.valueOf(ScriptCommand.SOUND_TYPE_BG_FADE_IN_TIME);
        if(fadeTime== null){
          fadeTime= commandInfo.valueOf(ScriptCommand.SOUND_TYPE_BG_FADE_OUT_TIME);
        }
        String? name= commandInfo.valueOf(ScriptCommand.COMMON_NAME);
        if (name== null || name.length== 0){
          _fadeBgm("", fadeTime, isFadeIn: false, onComplete: (){
            AudioHelper.disposeAllAudio().whenComplete(() {
              _completeScriptCommand(commandInfo);
            });
          });
        }else if (AudioHelper.isThisBgPlaying(commandInfo)){
          _fadeBgm(name, fadeTime, isFadeIn: false, onComplete: (){
            AudioHelper.playCommand(commandInfo, (isCountForExecution) {
              _completeScriptCommand(commandInfo, isCountForExecution);
            }, isSkipping);
          });
        }else{
          AudioHelper.playCommand(commandInfo, (isCountForExecution) {
            _completeScriptCommand(commandInfo, isCountForExecution);
          }, isSkipping);
          _fadeBgm(name, fadeTime);
        }
      }else{
        AudioHelper.playCommand(commandInfo, (isCountForExecution) {
          _completeScriptCommand(commandInfo, isCountForExecution);
        }, isSkipping);
      }

      return;
    }
    //No command found
    //_completeScriptCommand(commandInfo);
  }


  void _fadeBgm(String name, String? time, {bool isFadeIn= true, Function()? onComplete}){
    int fadeTime;
    if(time== null){
      fadeTime= isFadeIn ? GameConstant.GAME_BGM_FADE_IN_TIME : GameConstant.GAME_BGM_FADE_OUT_TIME;
    }else{
      fadeTime = _scriptRunner.parseAnimationTime(time);
    }
    AnimationController _animationController= AnimationController(vsync: this);
    _animationController.duration= Duration(milliseconds: fadeTime);
    Animation<double> _fadeInAudioAnim = Tween<double>(
        begin: isFadeIn ? 0 : 1, end: isFadeIn ? 1 : 0).animate(_animationController);
    Function() listener; listener= () {
      AudioHelper.setVolume(name, _fadeInAudioAnim.value);
    };
    _fadeInAudioAnim.addListener(listener);
    _animationController.forward(from: 0).whenCompleteOrCancel(() {
      _fadeInAudioAnim.removeListener(listener);
      if(onComplete!= null){
        onComplete();
      }
      _animationController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: GameConstant.GAME_SCENE_ALIGNMENT,
          child: AspectRatio(
            aspectRatio: GameConstant.GAME_ASPECT_RATIO,
            child: _sceneContainer,
          ),
        ),
        _textContainer,
      ],
    );
  }
}

class SceneContainer extends StatefulWidget {
  SceneContainer({Key? key, required this.layerName}) : super(key: key);
  final _SceneContainerState _state = _SceneContainerState();
  final String layerName;
  List<String> getSaveString(){
    return _state._buildSaveString();
  }

  @override
  _SceneContainerState createState() {
    return _state;
  }
}

class _SceneContainerState extends State<SceneContainer>
    with SingleTickerProviderStateMixin{
  List<Widget> _layerList = <Widget>[];

  List<String> _buildSaveString(){
    List<String> _saveString = <String>[];
    for(Widget layerContainer in _layerList){
      _saveString.addAll((layerContainer as LayerContainer).getSaveString());
    }
    return _saveString;
  }

  Future<ui.Image> capture() async {
    RenderRepaintBoundary _renderRepaintBoundary =
    _sceneContainerKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image ret = await _renderRepaintBoundary.toImage(pixelRatio: 2);
    return ret;
  }

  void processImageCommand(ScriptCommandInfo commandInfo) {
    //Init width size of Scene to let sprite(that not auto fit) fit in
    //MediaQuery.of(context).size.width return full width! So use this
    _sceneSize= _sceneContainerKey.currentContext!.size!;
    GameConstant.postInit(_sceneSize.width);//_gameContainerKey.currentContext.size.width

    String action= commandInfo.valueOf(ScriptCommand.COMMON_ACTION)== null
        ? ScriptCommand.IMAGE_ACTION_CREATE
        : commandInfo.valueOf(ScriptCommand.COMMON_ACTION)!;
    String imageName= commandInfo.valueOf(ScriptCommand.COMMON_NAME)== null
        ? ""
        : commandInfo.valueOf(ScriptCommand.COMMON_NAME)!;

    if(action== ScriptCommand.IMAGE_ACTION_CREATE){
      if (commandInfo.containKey(ScriptCommand.IMAGE_LAYER)) {
        String layer= commandInfo.valueOf(ScriptCommand.IMAGE_LAYER)!;
        for (Widget aLayerContainer in _layerList) {
          if ((aLayerContainer as LayerContainer).layerName == layer) {
            aLayerContainer._state.processCreateCommand(commandInfo);
            break;
          }
        }
        return;
      }else{
        if (commandInfo.containKey(ScriptCommand.IMAGE_TYPE)) {
          //If IMAGE_LAYER is not specified,
          //let the default layer by IMAGE_TYPE handle the command
          switch (commandInfo.valueOf(ScriptCommand.IMAGE_TYPE)) {
            case ScriptCommand.IMAGE_TYPE_SPRITE:
              for(Widget layerContainer in _layerList){
                if((layerContainer as LayerContainer).layerName== ContainerKeyName.SPRITE){
                  layerContainer._state.processCreateCommand(commandInfo);
                  break;
                }
              }
              break;
            case ScriptCommand.IMAGE_TYPE_MULTIPLE_LANGUAGE:
              for(Widget layerContainer in _layerList){
                if((layerContainer as LayerContainer).layerName== ContainerKeyName.SCENE_OVERLAY){
                  layerContainer._state.processCreateCommand(commandInfo);
                  break;
                }
              }
              break;
            case ScriptCommand.IMAGE_TYPE_EFFECT:
            case ScriptCommand.IMAGE_TYPE_SEQUENCE:
              for(Widget layerContainer in _layerList){
                if((layerContainer as LayerContainer).layerName== ContainerKeyName.FRONT_ENVIRONMENT){
                  layerContainer._state.processCreateCommand(commandInfo);
                  break;
                }
              }
              break;
            default:
              for(Widget layerContainer in _layerList){
                if((layerContainer as LayerContainer).layerName== ContainerKeyName.BACKGROUND){
                  layerContainer._state.processCreateCommand(commandInfo);
                  break;
                }
              }
              break;
          }
          return;
        }
      }
    }

    if(action== ScriptCommand.IMAGE_ACTION_REMOVE){
      for (Widget layerContainer in _layerList) {
        if ((layerContainer as LayerContainer)._state.containImageName(imageName)) {
          if(layerContainer._state.processRemoveCommand(commandInfo)){
            return;
          }
        }
      }
      //Nothing was removed
      _completeScriptCommand(commandInfo);
      return;
    }

    if(action== ScriptCommand.IMAGE_ACTION_MOD){
      for (Widget layerContainer in _layerList) {
        if ((layerContainer as LayerContainer)._state.containImageName(imageName)) {
          if(layerContainer._state.processEditCommand(commandInfo)){
            return;
          }
        }
      }
      //Nothing was edited
      _completeScriptCommand(commandInfo);
      return;
    }

    if(action== ScriptCommand.IMAGE_ACTION_SWAP){
      for (Widget layerContainer in _layerList) {
        if((layerContainer as LayerContainer)._state.processSwapCommand(commandInfo)){
          return;
        }
      }
      //Nothing was swapped
      _completeScriptCommand(commandInfo);
      return;
    }

    if(action== ScriptCommand.ANIMATION_ACTION_NAME){
      if(imageName.length> 0){
        for (Widget layerContainer in _layerList) {
          if ((layerContainer as LayerContainer)._state.containImageName(imageName)) {
            layerContainer._state.animateImageCommand(commandInfo);
            return;
          }
        }
      }
    }

    if(action== ScriptCommand.IMAGE_ACTION_DELETE_CACHE){
      if(imageName.length== 0){
        _completeScriptCommand(commandInfo);
        _imageCache.clear();
      }else{
        _imageCache.remove(imageName);
        _completeScriptCommand(commandInfo);
      }
      return;
    }
  }

  void lipSyncCommand(ScriptCommandInfo commandInfo){
    for (Widget layerContainer in _layerList) {
      (layerContainer as LayerContainer)._state.lipSyncCommand(commandInfo);
    }
  }

  void processVideoCommand(ScriptCommandInfo commandInfo){
    String? layerName= commandInfo.valueOf(ScriptCommand.VIDEO_LAYER);
    if(layerName== null || layerName.length== 0){
      layerName= ContainerKeyName.SCENE_OVERLAY;
    }
    for(Widget layerContainer in _layerList){
      if((layerContainer as LayerContainer).layerName== layerName){
        layerContainer._state.processVideoCommand(commandInfo);
        break;
      }
    }
  }

  void processLayerCommand(ScriptCommandInfo commandInfo) {
    String? layerName= commandInfo.valueOf(ScriptCommand.COMMON_NAME);
    String? layerAction= commandInfo.valueOf(ScriptCommand.COMMON_ACTION);
    if(null== layerAction){return;}
    if(layerName== null || layerName.length== 0){
      //Capture scene when layer name not specify
      if(layerAction== ScriptCommand.LAYER_ACTION_CAPTURE){
        capture().then((value) {
          _imageCache.update(commandInfo.valueOf(ScriptCommand.LAYER_ACTION_CAPTURE_IMAGE_NAME)!,
                  (oldValue) => value, ifAbsent: () => value);
          _completeScriptCommand(commandInfo);
        });
        return;
      }
      for(int i= 0; i< _layerList.length- 1; i++){
        (_layerList[i] as LayerContainer)._state.processLayerCommand(commandInfo, false);
      }
      (_layerList.last as LayerContainer)._state.processLayerCommand(commandInfo, true);
    }else {
      for (Widget layerContainer in _layerList) {
        if((layerContainer as LayerContainer).layerName== layerName){
          layerContainer._state.processLayerCommand(commandInfo, true);
          break;
        }
      }
    }
  }

  @override
  void initState() {
    //_layerList.add(LayerContainer(
    //  key: UniqueKey(),
    //  layerType: LAYER_TYPE.EFFECT,
    //  layerName: ContainerKeyName.BACK_FILTER,
    //));
    _layerList.add(LayerContainer(
      key: UniqueKey(),
      layerName: ContainerKeyName.BACKGROUND,
    ));
    //_layerList.add(LayerContainer(
    //  key: UniqueKey(),
    //  layerName: ContainerKeyName.BACK_ENVIRONMENT,
    //));
    _layerList.add(LayerContainer(
      key: UniqueKey(),
      layerName: ContainerKeyName.SPRITE,
    ));
    _layerList.add(LayerContainer(
      key: UniqueKey(),
      layerName: ContainerKeyName.FRONT_ENVIRONMENT,
    ));
    _layerList.add(LayerContainer(
      key: UniqueKey(),
      layerType: LAYER_TYPE.EFFECT,
      layerName: ContainerKeyName.FILTER,
    ));
    _layerList.add(LayerContainer(
      key: UniqueKey(),
      layerName: ContainerKeyName.SCENE_OVERLAY,
    ));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _sceneContainerKey,
      child: Stack(
        children: _layerList,
      ),
    );
  }
}

class LayerContainer extends StatefulWidget {
  LayerContainer({Key? key, required this.layerName, this.layerType= LAYER_TYPE.SIMPLE}) : super(key: key);
  final String layerName;
  final LAYER_TYPE layerType;
  final _LayerContainerState _state = _LayerContainerState();
  List<String> getSaveString(){
    return _state._buildSaveString();
  }

  @override
  _LayerContainerState createState() {
    return _state;
  }
}

class _LayerContainerState extends State<LayerContainer> with TickerProviderStateMixin {
  List<Widget> _layerChilds = <Widget>[];

  final ValueNotifier<dynamic> _shaderNotifier = ValueNotifier<Gradient>(ImageHelper.getGradientByName());
  final ValueNotifier<List<double>> _colorFilterNotifier = ValueNotifier<List<double>>(<double>[]);
  BlendMode _colorFilterBlendMode = BlendMode.srcATop;
  String _maskPath = "";
  ui.Image? _maskImage;
  String _shaderName = "";
  String _shaderParams = "";

  @override
  void dispose() {
    _shaderNotifier.dispose();
    _colorFilterNotifier.dispose();
    super.dispose();
  }

  Future<ui.Image> capture() async {
    RenderRepaintBoundary _renderRepaintBoundary = context.findRenderObject() as RenderRepaintBoundary;
    ui.Image ret = await _renderRepaintBoundary.toImage(pixelRatio: 2);
    return ret;
  }

  List<String> _buildSaveString(){
    List<String> _saveString = <String>[];

    String commandToSave;
    if(_colorFilterNotifier.value.length> 0){
      commandToSave= ScriptCommand.LAYER_HEADER;
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.COMMON_NAME, widget.layerName);
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.COMMON_ACTION, ScriptCommand.ANIMATION_ACTION_NAME);
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.ANIMATION_TYPE, ScriptCommand.ANIMATION_TYPE_FILTER);
      if(_colorFilterNotifier.value.length== 1){
        Color saveColor= Color(_colorFilterNotifier.value[0].toInt());
        if(ImageHelper.DEFAULT_COLOR!= saveColor.value.toDouble()){
          commandToSave+= ScriptCommandInfo.buildCommandParam(
              ScriptCommand.ANIMATION_TYPE_FILTER_COLOR,
              saveColor.toText());
        }
      }else if(_colorFilterNotifier.value.length> 0){
        String saveMatrix= _colorFilterNotifier.value
            .join(ScriptCommandInfo.PARAM_IN_VALUE_COMMAND_SEPARATOR);
        if(ImageHelper.DEFAULT_MATRIX_STR!= saveMatrix){
          commandToSave+= ScriptCommandInfo.buildCommandParam(
              ScriptCommand.ANIMATION_TYPE_FILTER_COLOR, saveMatrix);
        }
      }
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.IMAGE_COLOR_BLEND_MODE, _colorFilterBlendMode.toText());
      _saveString.add(commandToSave);
    }

    if(_shaderName.length > 0){
      commandToSave= ScriptCommand.LAYER_HEADER;
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.COMMON_NAME, widget.layerName);
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.COMMON_ACTION, ScriptCommand.ANIMATION_ACTION_NAME);
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.ANIMATION_TYPE, ScriptCommand.ANIMATION_TYPE_GRADIENT);
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.ANIMATION_TYPE_GRADIENT_SHADER, _shaderName);
      if(_shaderParams.length > 0){
        commandToSave+= ScriptCommandInfo.buildCommandParam(
            ScriptCommand.ANIMATION_TYPE_GRADIENT_PARAMETER, _shaderParams);
      }
      _saveString.add(commandToSave);
    }

    for(Widget imageContainer in _layerChilds){
      _saveString.addAll((imageContainer as ImageContainer).getSaveString());
    }
    return _saveString;
  }

  void processVideoCommand(ScriptCommandInfo commandInfo){
    String name= commandInfo.valueOf(ScriptCommand.COMMON_NAME)!;
    for (Widget anImageContainer in _layerChilds) {
      if ((anImageContainer as ImageContainer)._state.containerName == name) {
        anImageContainer._state.processVideoCommand(commandInfo);
        String? action= commandInfo.valueOf(ScriptCommand.COMMON_ACTION);
        if(action!= null && action== ScriptCommand.VIDEO_ACTION_REMOVE){
          _layerChilds.remove(anImageContainer);
          _completeScriptCommand(commandInfo);
        }
        return;
      }
    }
  }

  void processLayerCommand(ScriptCommandInfo commandInfo, bool completeCommandWhenDone){
    String? action= commandInfo.valueOf(ScriptCommand.COMMON_ACTION);
    if(action== null || action.length== 0){
      return;
    }
    if(action== ScriptCommand.LAYER_ACTION_CAPTURE){
      processCaptureCommand(commandInfo, completeCommandWhenDone);
      return;
    }
    if(action== ScriptCommand.LAYER_ACTION_CLEAR){
      processClearCommand(commandInfo, completeCommandWhenDone);
      return;
    }
    if(action== ScriptCommand.ANIMATION_ACTION_NAME){
      processAnimateCommand(commandInfo);
      return;
    }
  }

  void processCaptureCommand(ScriptCommandInfo commandInfo, bool completeCommandWhenDone){
    capture().then((value) {
      _imageCache.update(commandInfo.valueOf(ScriptCommand.LAYER_ACTION_CAPTURE_IMAGE_NAME)!,
              (oldValue) => value, ifAbsent: () => value);
      if(completeCommandWhenDone){
        _completeScriptCommand(commandInfo);
      }
      //StorageHelper.cacheImage(commandInfo.valueOf(SCRIPT_COMMAND.COMMON_NAME), value);
    });
  }

  void lipSyncCommand(ScriptCommandInfo commandInfo){
    for(Widget imageContainer in _layerChilds){
      if((imageContainer as ImageContainer)._state._imageType== ScriptCommand.IMAGE_TYPE_SPRITE){
        imageContainer._state.lipSyncCommand(commandInfo);
      }
    }
  }

  bool processRemoveCommand(ScriptCommandInfo commandInfo){
    int? toRemove;
    for(int i= 0; i< _layerChilds.length; i++){
      if ((_layerChilds[i] as ImageContainer)._state.containerName ==
          commandInfo.valueOf(ScriptCommand.COMMON_NAME)) {
        toRemove= i;
        break;
      }
    }
    if(toRemove!= null){
      _layerChilds.removeAt(toRemove);
      setState(() {
        WidgetsBinding.instance!.addPostFrameCallback((_) {
          WidgetsFlutterBinding.ensureInitialized();
          _completeScriptCommand(commandInfo);
        });
      });
      return true;
    }
    return false;
  }

  void processAnimateCommand(ScriptCommandInfo commandInfo) {
    String animationType= commandInfo.valueOf(ScriptCommand.ANIMATION_TYPE)!;
    int _timeInMillis = _scriptRunner.parseAnimationTime(commandInfo.valueOf(ScriptCommand.ANIMATION_TIME));
    AnimationController _animationController = AnimationController(
        duration: Duration(milliseconds: _timeInMillis), vsync: this);
    Curve curve= ImageHelper.getCurveFromParam(
        commandInfo.valueOf(ScriptCommand.ANIMATION_CURVE),
        commandInfo.valueOf(ScriptCommand.ANIMATION_CUBIC));
    final Animation<double> curveTransition = CurvedAnimation(parent: _animationController, curve: curve);
    Animation<dynamic> animation;
    Function() listener;
    //Size sceneSize= _sceneSize;

    if (animationType == ScriptCommand.ANIMATION_TYPE_FILTER) {
      List<double> oldFilter= _colorFilterNotifier.value;
      List<double> newFilter= commandInfo.valueOf(ScriptCommand.ANIMATION_TYPE_FILTER_COLOR)!.toColorMatrix();
      if(oldFilter.length!= newFilter.length){
        oldFilter= newFilter.length== 1
            ? (<double>[]..add(ImageHelper.DEFAULT_COLOR))
            : "".toColorMatrix();
      }
      if(commandInfo.containKey(ScriptCommand.ANIMATION_TYPE_FILTER_BLEND_MODE)){
        _colorFilterBlendMode= commandInfo.valueOf(ScriptCommand.ANIMATION_TYPE_FILTER_BLEND_MODE)!.toBlendMode();
      }

      if(newFilter.length== 1){
        animation = ColorTween(begin: Color(oldFilter[0].toInt())
            , end: Color(newFilter[0].toInt())).animate(curveTransition);
      }else{
        animation = ListNNDoubleTween(oldFilter, newFilter).animate(curveTransition);
      }

      listener= () {
        if(newFilter.length== 1){
          _colorFilterNotifier.value= <double>[]..add(animation.value.value.toDouble());
        }else{
          _colorFilterNotifier.value= animation.value;
        }
      };

      animation.addListener(listener);
      setState(() {});
      _animationController.forward(from: 0).whenCompleteOrCancel(() {
        animation.removeListener(listener);
        _completeScriptCommand(commandInfo);
      });
      return;
    }

    else if (animationType == ScriptCommand.ANIMATION_TYPE_GRADIENT){
      String? shaderParam= commandInfo.valueOf(ScriptCommand.ANIMATION_TYPE_GRADIENT_PARAMETER);
      _shaderParams= shaderParam== null ? "" : shaderParam;
      List<double> param= _shaderParams.length== 0
          ? <double>[] : _shaderParams.split(
          ScriptCommandInfo.PARAM_IN_VALUE_COMMAND_SEPARATOR).map((s) => double.tryParse(s)!).toList();
      _shaderName= commandInfo.valueOf(ScriptCommand.ANIMATION_TYPE_GRADIENT_SHADER)!;
      animation = Tween<double>(begin: 0, end: 1).animate(_animationController);
      listener= () {
        _shaderNotifier.value = ImageHelper.getGradientByName(
          _shaderName,
          animation.value,
          param,
        );
      }; animation.addListener(listener);

      setState(() {});
      _animationController.forward(from: 0).whenCompleteOrCancel(() {
        animation.removeListener(listener);
        _completeScriptCommand(commandInfo);
      });
      return;
    }

    else if (animationType == ScriptCommand.ANIMATION_TYPE_SHOW_MASK){
      _shaderParams= "";
      _maskPath= commandInfo.valueOf(ScriptCommand.ANIMATION_TYPE_MASK_IMAGE_PATH)!;
      animation = Tween<double>(begin: 0, end: 1).animate(_animationController);
      ImageHelper.getFileUiImage(AssetConstant.getTruePath(AssetConstant.EFFECT_DIR+ _maskPath),
          _sceneSize.width.toInt(), _sceneSize.height.toInt()).then((value) {
        _maskImage= value;
        _shaderNotifier.value= ImageShader(_maskImage!, TileMode.clamp, TileMode.clamp, Matrix4.identity().storage);
        _shaderName= "";
        _shaderParams= "";
        setState(() {
          _completeScriptCommand(commandInfo);
        });

      });
      return;
    }

    _completeScriptCommand(commandInfo);
  }

  void animateImageCommand(ScriptCommandInfo commandInfo){
    for (Widget anImageContainer in _layerChilds) {
      if ((anImageContainer as ImageContainer)._state.containerName ==
          commandInfo.valueOf(ScriptCommand.COMMON_NAME)) {
        anImageContainer._state.animateImageCommand(commandInfo);
        return;
      }
    }
  }

  bool processSwapCommand(ScriptCommandInfo commandInfo){
    if(commandInfo.containKey(ScriptCommand.IMAGE_ACTION_SWAP_NAME1)){
      String name1= commandInfo.valueOf(ScriptCommand.IMAGE_ACTION_SWAP_NAME1)!;
      String name2= commandInfo.valueOf(ScriptCommand.IMAGE_ACTION_SWAP_NAME2)!;
      int? image1Index;
      for(int i= 0; i< _layerChilds.length; i++){
        if((_layerChilds[i] as ImageContainer)._state.containerName== name1){
          image1Index= i;
          (_layerChilds[i] as ImageContainer)._state.containerName= name2 + name1;
          break;
        }
      }
      if(image1Index== null){return false;}
      for(int i= 0; i< _layerChilds.length; i++){
        if((_layerChilds[i] as ImageContainer)._state.containerName== name2){
          (_layerChilds[i] as ImageContainer)._state.containerName= name1;
          break;
        }
      }
      (_layerChilds[image1Index] as ImageContainer)._state.containerName= name2;
      _completeScriptCommand(commandInfo);
      return true;
    }

    return false;
  }

  bool processEditCommand(ScriptCommandInfo commandInfo){
    if(!containImageName(commandInfo.valueOf(ScriptCommand.COMMON_NAME)!)){
      return false;
    }
    int indexToProcess= -1;

    for(int i= 0; i< _layerChilds.length; i++) {
      String tempImageName= (_layerChilds[i] as ImageContainer)._state.containerName;
      if (tempImageName== commandInfo.valueOf(ScriptCommand.COMMON_NAME)){
        indexToProcess= i;
        break;
      }
    }
    if(indexToProcess< 0){return false;}

    if (commandInfo.containKey(ScriptCommand.IMAGE_NEW_NAME)) {
      (_layerChilds[indexToProcess] as ImageContainer)._state.containerName =
          commandInfo.valueOf(ScriptCommand.IMAGE_NEW_NAME)!;
      _completeScriptCommand(commandInfo);
      return true;
    }
    if(commandInfo.containKey(ScriptCommand.IMAGE_INDEX_BELOW)){
      String pointingImageName= commandInfo.valueOf(ScriptCommand.IMAGE_INDEX_BELOW)!;
      ImageContainer toProcess= _layerChilds.removeAt(indexToProcess) as ImageContainer;
      int indexBelow= -1;

      for(int i= 0; i< _layerChilds.length; i++){
        if((_layerChilds[i] as ImageContainer)._state.containerName== pointingImageName){
          indexBelow= i;
          break;
        }
      }
      if(indexBelow>= 0){
        _layerChilds.insert(indexBelow, toProcess);
      }else{
        _layerChilds.insert(indexToProcess, toProcess);
      }
      setState(() {
        WidgetsBinding.instance!.addPostFrameCallback((_) {
          WidgetsFlutterBinding.ensureInitialized();
          _completeScriptCommand(commandInfo);
        });
      });
      return indexBelow>= 0;
    }
    if(commandInfo.containKey(ScriptCommand.IMAGE_INDEX_ABOVE)){
      String pointingImageName= commandInfo.valueOf(ScriptCommand.IMAGE_INDEX_ABOVE)!;
      ImageContainer toProcess= _layerChilds.removeAt(indexToProcess) as ImageContainer;
      int indexAbove= -1;

      for(int i= 0; i< _layerChilds.length; i++){
        if((_layerChilds[i] as ImageContainer)._state.containerName== pointingImageName){
          indexAbove= i;
          break;
        }
      }
      if(indexAbove>= 0){
        if(indexAbove< _layerChilds.length- 1){
          _layerChilds.insert(indexAbove+ 1, toProcess);
        }else{
          _layerChilds.add(toProcess);
        }
      }else{
        _layerChilds.insert(indexToProcess, toProcess);
      }
      setState(() {
        WidgetsBinding.instance!.addPostFrameCallback((_) {
          WidgetsFlutterBinding.ensureInitialized();
          _completeScriptCommand(commandInfo);
        });
      });
      return indexAbove>= 0;
    }
    if(commandInfo.containKey(ScriptCommand.IMAGE_TYPE_SPRITE_BODY)
        || commandInfo.containKey(ScriptCommand.IMAGE_TYPE_SPRITE_EMOTION)
        || commandInfo.containKey(ScriptCommand.IMAGE_TYPE_SPRITE_LIP)
        || commandInfo.containKey(ScriptCommand.IMAGE_TYPE_SPRITE_HAIR)
    ){
      (_layerChilds[indexToProcess] as ImageContainer)._state
          .processEditSprite(commandInfo);
      return true;
    }
    if(commandInfo.containKey(ScriptCommand.IMAGE_PATH)){
      (_layerChilds[indexToProcess] as ImageContainer)._state
          .processEditPath(commandInfo);
      return true;
    }

    return false;
  }

  void processCreateCommand(ScriptCommandInfo commandInfo) {
    ImageContainer newImageContainer = ImageContainer(
      createCommand: commandInfo,
      key: UniqueKey(),
      initName: commandInfo.valueOf(ScriptCommand.COMMON_NAME)!,
      layerName: widget.layerName,
    );
    bool isImageAdded= false;
    if(commandInfo.containKey(ScriptCommand.IMAGE_INDEX_BELOW)){
      String pointingImageName= commandInfo.valueOf(ScriptCommand.IMAGE_INDEX_BELOW)!;
      for(int i= 0; i< _layerChilds.length; i++){
        if((_layerChilds[i] as ImageContainer)._state.containerName== pointingImageName){
          _layerChilds.insert(i, newImageContainer);
          isImageAdded= true;
          break;
        }
      }
    }else if(commandInfo.containKey(ScriptCommand.IMAGE_INDEX_ABOVE)){
      String pointingImageName= commandInfo.valueOf(ScriptCommand.IMAGE_INDEX_ABOVE)!;
      for(int i= 0; i< _layerChilds.length; i++){
        if((_layerChilds[i] as ImageContainer)._state.containerName== pointingImageName){
          if(i< _layerChilds.length- 1){
            _layerChilds.insert(i+1, newImageContainer);
            isImageAdded= true;
          }
          break;
        }
      }
    }else if(commandInfo.containKey(ScriptCommand.IMAGE_INDEX_FIRST)){
      _layerChilds.insert(0, newImageContainer);
      isImageAdded= true;
    }
    if(!isImageAdded){
      _layerChilds.add(newImageContainer);
    }
    setState(() {});
  }

  void processClearCommand(ScriptCommandInfo commandInfo, bool completeCommandWhenDone) {
    _layerChilds.clear();
    setState(() {
      if(completeCommandWhenDone){
        WidgetsBinding.instance!.addPostFrameCallback((_) {
          WidgetsFlutterBinding.ensureInitialized();
          _completeScriptCommand(commandInfo);
        });
      }
    });
  }

  bool containImageName(String name) {
    for (Widget anImageContainer in _layerChilds) {
      if ((anImageContainer as ImageContainer)._state.containerName == name) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if(widget.layerType== LAYER_TYPE.EFFECT){
      return RepaintBoundary(
        child: ValueListenableBuilder(
          valueListenable: _colorFilterNotifier,
          builder: (_, value, __) {
            List<double> colorMatrix= value as List<double>;
            if(colorMatrix.length== 0){
              colorMatrix.add(ImageHelper.DEFAULT_COLOR);
            }
            if(colorMatrix.length== 1){
              return ColorFiltered(
                colorFilter: ColorFilter.mode(
                    Color(colorMatrix[0].toInt()), _colorFilterBlendMode),
                child: ValueListenableBuilder(
                valueListenable: _shaderNotifier,
                builder: (_, shaderValue, __) {
                  return ShaderMask(blendMode: BlendMode.dstIn,
                    shaderCallback: (bounds) {
                      if(shaderValue is ImageShader){
                        return shaderValue;
                      }
                      return (shaderValue as Gradient).createShader(bounds);
                    },
                    child: Stack(
                      children: _layerChilds,
                    ),
                  );
                },
              ),);
            }
            return ColorFiltered(
              colorFilter: ColorFilter.matrix(colorMatrix),
              child: ValueListenableBuilder(
              valueListenable: _shaderNotifier,
              builder: (_, shaderValue, __) {
                return ShaderMask(blendMode: BlendMode.dstIn,
                  shaderCallback: (bounds) {
                    if(shaderValue is ImageShader){
                      return shaderValue;
                    }
                    return (shaderValue as Gradient).createShader(bounds);
                  },
                  child: Stack(
                    children: _layerChilds,
                  ),
                );
              },
            ),);
          },
        ),
      );
    }
    return RepaintBoundary(
      child: Stack(
        children: _layerChilds,
      ),
    );
  }
}

class ImageContainer extends StatefulWidget {
  ImageContainer({Key? key, required this.initName, required this.layerName, required this.createCommand}) : super(key: key);
  final ScriptCommandInfo createCommand;
  final String initName;
  final String layerName;
  final _ImageContainerState _state = _ImageContainerState();
  List<String> getSaveString(){
    return _state._buildSaveString();
  }

  @override
  _ImageContainerState createState() {
    return _state;
  }
}

class _ImageContainerState extends State<ImageContainer>
    with TickerProviderStateMixin {
  //Init to fix bug that "containerName" not initialized when compare(search img name)
  String containerName="";
  Widget _imageBound = SizedBox();
  Widget _imageInside = SizedBox();
  ValueNotifier<double> _opacityNotifier = ValueNotifier<double>(0);
  ValueNotifier<List<double>> _rotateNotifier = ValueNotifier<List<double>>([0,0,0]);
  //Left, top, right, bottom, width, height
  ValueNotifier<List<double?>> _positionNotifier = ValueNotifier<List<double?>>([null,null,null,null,null,null]);
  String _imageType = ScriptCommand.IMAGE_TYPE_NONE;
  String _imageRawPath = "";
  String _rawCharBody = "";
  String _rawCharEmo = "";
  String _imageSinglePath = "";
  double _imageOrgWidth = 0;
  double _imageOrgHeight = 0;
  double _imageXOffset = 0;
  double _imageYOffset = 0;
  ValueNotifier<List<double>> _imageColor= ValueNotifier<List<double>>(<double>[]);
  BlendMode _imageBlendMode= BlendMode.srcATop;

  List<String> _buildSaveString(){
    List<String> _saveString = <String>[];
    Size sceneSize= _sceneSize;
    double? posLeftToSave= _positionNotifier.value[0];
    double? posTopToSave= _positionNotifier.value[1];
    double? posRightToSave= _positionNotifier.value[2];
    double? posBottomToSave= _positionNotifier.value[3];
    String commandToSave= ScriptCommand.IMAGE_HEADER;
    commandToSave+= ScriptCommandInfo.buildCommandParam(
        ScriptCommand.COMMON_NAME, containerName);
    commandToSave+= ScriptCommandInfo.buildCommandParam(
        ScriptCommand.COMMON_ACTION, ScriptCommand.IMAGE_ACTION_CREATE);
    commandToSave+= ScriptCommandInfo.buildCommandParam(
        ScriptCommand.IMAGE_TYPE, _imageType);
    commandToSave+= ScriptCommandInfo.buildCommandParam(
        ScriptCommand.IMAGE_LAYER, widget.layerName);
    if(_opacityNotifier.value> 0){
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.IMAGE_ALPHA, _opacityNotifier.value.toString());
    }
    if(_imageColor.value.length== 1){
      Color saveColor= Color(_imageColor.value[0].toInt());
      if(ImageHelper.DEFAULT_COLOR!= saveColor.value.toDouble()){
        commandToSave+= ScriptCommandInfo.buildCommandParam(
            ScriptCommand.IMAGE_COLOR, saveColor.toText());
      }
    }else if(_imageColor.value.length> 0){
      String saveMatrix= _imageColor.value.join(ScriptCommandInfo.PARAM_IN_VALUE_COMMAND_SEPARATOR);
      if(ImageHelper.DEFAULT_MATRIX_STR!= saveMatrix){
        commandToSave+= ScriptCommandInfo.buildCommandParam(
            ScriptCommand.IMAGE_COLOR, saveMatrix);
      }
    }
    commandToSave+= ScriptCommandInfo.buildCommandParam(
        ScriptCommand.IMAGE_COLOR_BLEND_MODE, _imageBlendMode.toText());
    if(_rotateNotifier.value[0]!= 0){
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.IMAGE_ROTATE_Z, _rotateNotifier.value[0].toString());
    }
    if(_rotateNotifier.value[1]!= 0){
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.IMAGE_ROTATE_Y, _rotateNotifier.value[1].toString());
    }
    if(_rotateNotifier.value[2]!= 0){
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.IMAGE_ROTATE_X, _rotateNotifier.value[2].toString());
    }
    commandToSave+= ScriptCommandInfo.buildCommandParam(
        ScriptCommand.IMAGE_PATH, _imageRawPath);
    if(_imageType== ScriptCommand.IMAGE_TYPE_SPRITE && _imageInside is SpriteContainer){
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.IMAGE_TYPE_SPRITE_BODY, _rawCharBody);
      if(_rawCharEmo.length> 0){
        commandToSave+= ScriptCommandInfo.buildCommandParam(
            ScriptCommand.IMAGE_TYPE_SPRITE_EMOTION, _rawCharEmo);
      }
      if(_positionNotifier.value[0]!= null){
        posLeftToSave= _positionNotifier.value[0]!+ (_imageOrgWidth/2);
      }
      if(_positionNotifier.value[2]!= null){
        posRightToSave= _positionNotifier.value[2]!+ (_imageOrgWidth/2);
      }
    }
    if(posLeftToSave!= null){
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.IMAGE_POSITION_LEFT, (posLeftToSave*100/ sceneSize.width).toString());
    }else{
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.IMAGE_POSITION_LEFT, "");
    }
    if(posTopToSave!= null){
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.IMAGE_POSITION_TOP, (posTopToSave*100/ sceneSize.height).toString());
    }else{
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.IMAGE_POSITION_TOP, "");
    }
    if(posRightToSave!= null){
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.IMAGE_POSITION_RIGHT, (posRightToSave*100/ sceneSize.width).toString());
    }else{
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.IMAGE_POSITION_RIGHT, "");
    }
    if(posBottomToSave!= null){
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.IMAGE_POSITION_BOTTOM, (posBottomToSave*100/ sceneSize.height).toString());
    }else{
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.IMAGE_POSITION_BOTTOM, "");
    }
    if(_positionNotifier.value[4]!= null){
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.IMAGE_SIZE_WIDTH, (_positionNotifier.value[4]! *100/ _imageOrgWidth).toString());
    }else{
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.IMAGE_SIZE_WIDTH, "");
    }
    if(_positionNotifier.value[5]!= null){
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.IMAGE_SIZE_HEIGHT, (_positionNotifier.value[5]! *100/ _imageOrgHeight).toString());
    }else{
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.IMAGE_SIZE_HEIGHT, "");
    }
    commandToSave+= ScriptCommandInfo.buildCommandParam(
        ScriptCommand.IMAGE_X_OFFSET, _imageXOffset.toString());
    commandToSave+= ScriptCommandInfo.buildCommandParam(
        ScriptCommand.IMAGE_Y_OFFSET, _imageYOffset.toString());

    _saveString.add(commandToSave);
    return _saveString;
  }

  late Widget _mainWidget;
  @override
  void initState() {
    containerName= widget.initName;
    _createImageCommand(widget.createCommand);
    super.initState();
  }

  void _rebuildMainWidget(){
    _mainWidget= WidgetHelper.getCommonWidgetForGameContainer(
        ValueListenableBuilder(valueListenable: _imageColor, builder: (context, value, child) {
          List<double> colorMatrix= value as List<double>;
          if(colorMatrix.length== 0){
            colorMatrix.add(ImageHelper.DEFAULT_COLOR);
          }
          if(colorMatrix.length== 1){
            return ColorFiltered(colorFilter: ColorFilter.mode(
                Color(colorMatrix[0].toInt()), _imageBlendMode
            ), child: _imageBound,);
          }
          return ColorFiltered(colorFilter: ColorFilter.matrix(
              colorMatrix
          ), child: _imageBound,);
        },),
        _opacityNotifier,
        _rotateNotifier,
        _positionNotifier,
        xOffset: _imageXOffset,
        yOffset: _imageYOffset);
  }

  void processEditPath(ScriptCommandInfo commandInfo) {
    if (commandInfo.containKey(ScriptCommand.IMAGE_PATH)) {
      _imageRawPath = commandInfo.valueOf(ScriptCommand.IMAGE_PATH)!;
    } else {
      _imageRawPath = commandInfo.valueOf(ScriptCommand.COMMON_NAME)!;
    }

    switch (_imageType){
      case ScriptCommand.IMAGE_TYPE_CACHE:
        if(_imageCache.containsKey(_imageRawPath)){
          _imageSinglePath= _imageRawPath;
          _imageInside= RawImage(
            fit: BoxFit.fill,
            image: _imageCache[_imageSinglePath],
          );
        }else{
          //_imageSinglePath = StorageHelper.getCacheImagePath(_imageRawPath);
          //_imageInside= Image(
          //  image: FileImage(File(_imageSinglePath)),
          //);
          throw(ErrorString.NO_CACHED_IMAGE_FOUND+ _imageRawPath);
        }
        break;
      case ScriptCommand.IMAGE_TYPE_BACKGROUND:
        _imageSinglePath = AssetConstant.getTruePath(
            AssetConstant.BACKGROUND_DIR + _imageRawPath);
        Size imageSize = CommonFunc.getImageSizeInPath(_imageSinglePath);

        _imageOrgWidth = imageSize.width * GameConstant.gameCgSizeRatio;
        _imageOrgHeight = imageSize.height * GameConstant.gameCgSizeRatio;

        _imageInside = Image(
          fit: BoxFit.fill,
          image: FileImage(File(_imageSinglePath)),
        );
        break;
      case ScriptCommand.IMAGE_TYPE_MULTIPLE_LANGUAGE:
        _imageSinglePath = AssetConstant.getTruePath(Path.join(
          AssetConstant.MULTIPLE_LANGUAGE_DIR,
          UserConfig.getBool(UserConfig.IS_ACTIVE_MAIN_LANGUAGE)
              ? UserConfig.get(UserConfig.GAME_MAIN_LANGUAGE)
              : UserConfig.get(UserConfig.GAME_SUB_LANGUAGE),
          _imageRawPath));
        Size imageSize = CommonFunc.getImageSizeInPath(_imageSinglePath);

        _imageOrgWidth = imageSize.width * GameConstant.gameCgSizeRatio;
        _imageOrgHeight = imageSize.height * GameConstant.gameCgSizeRatio;

        _imageInside = Image(
          fit: BoxFit.fill,
          image: FileImage(File(_imageSinglePath)),
        );
        break;
      default:
        _imageSinglePath = AssetConstant.getTruePath(
            AssetConstant.IMAGE_DIR + _imageRawPath);
        Size imageSize = CommonFunc.getImageSizeInPath(_imageSinglePath);

        _imageOrgWidth = imageSize.width * GameConstant.gameCgSizeRatio;
        _imageOrgHeight = imageSize.height * GameConstant.gameCgSizeRatio;

        _imageInside = Image(
          fit: BoxFit.fill,
          image: FileImage(File(_imageSinglePath)),
        );
        break;
    }
    _imageBound= Container(child: _imageInside,);
    _rebuildMainWidget();
    setState(() {
      WidgetsBinding.instance!.addPostFrameCallback((_) {
        WidgetsFlutterBinding.ensureInitialized();
        _completeScriptCommand(commandInfo);
      });
    });
  }

  void processEditSprite(ScriptCommandInfo commandInfo) {
    if (commandInfo.containKey(ScriptCommand.IMAGE_PATH)) {
      _imageRawPath = commandInfo.valueOf(ScriptCommand.IMAGE_PATH)!;
    }
    if(commandInfo.containKey(ScriptCommand.IMAGE_TYPE_SPRITE_BODY)){
      _rawCharBody= commandInfo.valueOf(ScriptCommand.IMAGE_TYPE_SPRITE_BODY)!;
      String _pathCharBody = Path.join(
        _imageSinglePath,
        ScriptCommand.IMAGE_TYPE_SPRITE_BODY,
        _rawCharBody);
      _pathCharBody = AssetConstant.getTruePath(_pathCharBody);
      Size bodyImageSize = CommonFunc.getImageSizeInPath(_pathCharBody);

      _imageOrgWidth = bodyImageSize.width * GameConstant.gameSpriteSizeRatio;
      _imageOrgHeight = bodyImageSize.height * GameConstant.gameSpriteSizeRatio;
    }
    if(commandInfo.containKey(ScriptCommand.IMAGE_TYPE_SPRITE_EMOTION)){
      _rawCharEmo= commandInfo.valueOf(ScriptCommand.IMAGE_TYPE_SPRITE_EMOTION)!;
    }
    (_imageInside as SpriteContainer)._state.processEditPath(commandInfo);
  }

  void lipSyncCommand(ScriptCommandInfo commandInfo){
    final String soundPath= commandInfo.valueOf(ScriptCommand.SOUND_PATH)!;
    if(soundPath.length== 0){return;}
    String dirName= soundPath.substring(0, soundPath.lastIndexOf(Platform.pathSeparator));
    dirName= dirName.substring(dirName.lastIndexOf(Platform.pathSeparator)+ 1);

    if((dirName== "01" && _imageRawPath== "kei")
        || (dirName== "02" && _imageRawPath== "re")
        || (dirName== "03" && _imageRawPath== "me")
        || (dirName== "04" && _imageRawPath== "sa")
        || (dirName== "05" && _imageRawPath== "ri")
        || (dirName== "06" && _imageRawPath== "si")
        || (dirName== "07" && _imageRawPath== "sato")
        || (dirName== "08" && _imageRawPath== "tomi")
        || (dirName== "09" && _imageRawPath== "ta")
        || (dirName== "10" && _imageRawPath== "iri")
        || (dirName== "11" && _imageRawPath== "oisi")
        || (dirName== "15" && _imageRawPath== "kasa")
        || (dirName== "16" && _imageRawPath== "aka")
        || (dirName== "18" && _imageRawPath== "ki")
        || (dirName== "19" && _imageRawPath== "kuma")
        || (dirName== "22" && _imageRawPath== "tie")
        || (dirName== "24" && _imageRawPath== "tomita")
        || (dirName== "25" && _imageRawPath== "oka")
    ){
      (_imageInside as SpriteContainer)._state.startLipSync(AssetConstant.SPECTRUM_DIR+ soundPath);
    }
  }

  VideoPlayerController? _videoController;
  void _createImageCommand(ScriptCommandInfo commandInfo) {
    //Return update state or not
    if (commandInfo.containKey(ScriptCommand.IMAGE_PATH)) {
      _imageRawPath = commandInfo.valueOf(ScriptCommand.IMAGE_PATH)!;
    } else {
      _imageRawPath = commandInfo.valueOf(ScriptCommand.COMMON_NAME)!;
    }
    Size sceneSize= _sceneSize;
    int waitForComplete= 1;
    ImageFrameBuilder _frameBuilder= (context, child, frame, wasSynchronouslyLoaded){
      if(frame!= null){
        waitForComplete--;
        if(waitForComplete== 0){
          WidgetsBinding.instance!.addPostFrameCallback((_) {
            WidgetsFlutterBinding.ensureInitialized();
            _completeScriptCommand(commandInfo);
          });
        }else{
          waitForComplete= -1;
        }
      }
      return child;
    };

    if (commandInfo.containKey(ScriptCommand.IMAGE_TYPE)){
      _imageType= commandInfo.valueOf(ScriptCommand.IMAGE_TYPE)!;
    }else{
      _imageType = ScriptCommand.IMAGE_TYPE_NONE;
    }
    switch (_imageType) {
      case ScriptCommand.IMAGE_TYPE_VIDEO:
        _imageSinglePath = AssetConstant.getTruePath(
            AssetConstant.VIDEO_DIR + _imageRawPath);
        Size videoSize = CommonFunc.getImageSizeInPath(_imageSinglePath);

        _imageOrgWidth = videoSize.width * GameConstant.gameVideoSizeRatio;
        _imageOrgHeight = videoSize.height * GameConstant.gameVideoSizeRatio;
        _positionNotifier.value= [0,null,null,0,_imageOrgWidth,_imageOrgHeight];

        _videoController= VideoPlayerController.file(File(_imageSinglePath));
        _imageInside = VideoPlayer(_videoController!);
        break;
      case ScriptCommand.IMAGE_TYPE_CACHE:
        _positionNotifier.value= [0,0,0,0,null,null];

        if(_imageCache.containsKey(_imageRawPath)){
          _imageSinglePath= _imageRawPath;
          _imageOrgWidth = sceneSize.width;
          _imageOrgHeight = sceneSize.height;
          _imageInside= RawImage(
            fit: BoxFit.fill,
            image: _imageCache[_imageSinglePath],
          );
        }else{
          //_imageSinglePath = StorageHelper.getCacheImagePath(_imageRawPath);
          //_imageInside= Image(
          //  image: FileImage(File(_imageSinglePath)),
          //);
          throw(ErrorString.NO_CACHED_IMAGE_FOUND+ _imageRawPath);
        }
        break;
      case ScriptCommand.IMAGE_TYPE_BACKGROUND:
        _imageSinglePath = AssetConstant.getTruePath(
            AssetConstant.BACKGROUND_DIR + _imageRawPath);
        Size imageSize = CommonFunc.getImageSizeInPath(_imageSinglePath);

        _imageOrgWidth = imageSize.width * GameConstant.gameCgSizeRatio;
        _imageOrgHeight = imageSize.height * GameConstant.gameCgSizeRatio;
        _positionNotifier.value= [0,0,0,0,null,null];

        _imageInside = Image(
          fit: BoxFit.fill,
          frameBuilder: _frameBuilder,
          image: FileImage(File(_imageSinglePath)),
        );
        break;
      case ScriptCommand.IMAGE_TYPE_MULTIPLE_LANGUAGE:
        _imageSinglePath = AssetConstant.getTruePath(Path.join(
          AssetConstant.MULTIPLE_LANGUAGE_DIR,
          UserConfig.getBool(UserConfig.IS_ACTIVE_MAIN_LANGUAGE)
              ? UserConfig.get(UserConfig.GAME_MAIN_LANGUAGE)
              : UserConfig.get(UserConfig.GAME_SUB_LANGUAGE),
          _imageRawPath));
        Size imageSize = CommonFunc.getImageSizeInPath(_imageSinglePath);

        _imageOrgWidth = imageSize.width * GameConstant.gameCgSizeRatio;
        _imageOrgHeight = imageSize.height * GameConstant.gameCgSizeRatio;
        _positionNotifier.value= [0,null,null,0,_imageOrgWidth,_imageOrgHeight];

        _imageInside = Image(
          fit: BoxFit.fill,
          frameBuilder: _frameBuilder,
          image: FileImage(File(_imageSinglePath)),
        );
        break;
      case ScriptCommand.IMAGE_TYPE_SPRITE:
        _imageSinglePath= AssetConstant.CHARACTER_DIR + _imageRawPath;
        _rawCharBody= commandInfo.valueOf(ScriptCommand.IMAGE_TYPE_SPRITE_BODY)!;
        if(commandInfo.containKey(ScriptCommand.IMAGE_TYPE_SPRITE_EMOTION)){
          _rawCharEmo= commandInfo.valueOf(ScriptCommand.IMAGE_TYPE_SPRITE_EMOTION)!;
        }
        String _pathCharBody = Path.join(
          _imageSinglePath,
          ScriptCommand.IMAGE_TYPE_SPRITE_BODY,
          _rawCharBody);
        _pathCharBody = AssetConstant.getTruePath(_pathCharBody);
        Size bodyImageSize = CommonFunc.getImageSizeInPath(_pathCharBody);
        _imageInside = SpriteContainer(key: UniqueKey(), commandInfo: commandInfo);

        _imageOrgWidth = bodyImageSize.width * GameConstant.gameSpriteSizeRatio;
        _positionNotifier.value[4] = _imageOrgWidth;
        _imageOrgHeight = bodyImageSize.height * GameConstant.gameSpriteSizeRatio;
        _positionNotifier.value[5] = _imageOrgHeight;
        double _imagePosLeft = sceneSize.width/ 2;
        _imagePosLeft= _imagePosLeft- (_imageOrgWidth/2);
        _positionNotifier.value[0]= _imagePosLeft;
        _positionNotifier.value[3] = 0;
        break;
      default:
        _imageSinglePath = AssetConstant.getTruePath(AssetConstant.IMAGE_DIR + _imageRawPath);
        Size imageSize = CommonFunc.getImageSizeInPath(_imageSinglePath);
        _positionNotifier.value= [0,0,0,0,null,null];

        _imageOrgWidth = imageSize.width * GameConstant.gameCgSizeRatio;
        _imageOrgHeight = imageSize.height * GameConstant.gameCgSizeRatio;

        _imageInside = Image(
          fit: BoxFit.fill,
          frameBuilder: _frameBuilder,
          image: FileImage(File(_imageSinglePath)),
        );
        break;
    }
    if (commandInfo.containKey(ScriptCommand.IMAGE_POSITION_LEFT)) {
      double? _imagePosLeft = commandInfo.valueDoubleOf(ScriptCommand.IMAGE_POSITION_LEFT);
      if(_imagePosLeft!= null){
        _imagePosLeft = (_imagePosLeft/ 100)* sceneSize.width;
        if(_imageType== ScriptCommand.IMAGE_TYPE_SPRITE){
          _imagePosLeft-= _imageOrgWidth/2;
        }
      }
      _positionNotifier.value[0] = _imagePosLeft;
    }
    if (commandInfo.containKey(ScriptCommand.IMAGE_POSITION_TOP)) {
      double? _imagePosTop = commandInfo.valueDoubleOf(ScriptCommand.IMAGE_POSITION_TOP);
      if(_imagePosTop!= null){
        _imagePosTop = (_imagePosTop/ 100)* sceneSize.height;
      }
      _positionNotifier.value[1] = _imagePosTop;
    }
    if (commandInfo.containKey(ScriptCommand.IMAGE_POSITION_RIGHT)) {
      double? _imagePosRight = commandInfo.valueDoubleOf(ScriptCommand.IMAGE_POSITION_RIGHT);
      if(_imagePosRight!= null){
        _imagePosRight = (_imagePosRight/ 100)* sceneSize.width;
        if(_imageType== ScriptCommand.IMAGE_TYPE_SPRITE){
          _imagePosRight-= _imageOrgWidth/2;
        }
      }
      _positionNotifier.value[2] = _imagePosRight;
    }
    if (commandInfo.containKey(ScriptCommand.IMAGE_POSITION_BOTTOM)) {
      double? _imagePosBottom = commandInfo.valueDoubleOf(ScriptCommand.IMAGE_POSITION_BOTTOM);
      if(_imagePosBottom!= null){
        _imagePosBottom = (_imagePosBottom/ 100)* sceneSize.height;
      }
      _positionNotifier.value[3] = _imagePosBottom;
    }
    if (commandInfo.containKey(ScriptCommand.IMAGE_SIZE_WIDTH)) {
      double? _imageWidth = commandInfo.valueDoubleOf(ScriptCommand.IMAGE_SIZE_WIDTH);
      if(_imageWidth!= null){
        _imageWidth = (_imageWidth/ 100)* _imageOrgWidth;
      }
      _positionNotifier.value[4] = _imageWidth;
    }
    if (commandInfo.containKey(ScriptCommand.IMAGE_SIZE_HEIGHT)) {
      double? _imageHeight = commandInfo.valueDoubleOf(ScriptCommand.IMAGE_SIZE_HEIGHT);
      if(_imageHeight!= null){
        _imageHeight = (_imageHeight/ 100)* _imageOrgHeight;
      }
      _positionNotifier.value[5] = _imageHeight;
    }
    if (commandInfo.containKey(ScriptCommand.IMAGE_X_OFFSET)) {
      _imageXOffset = commandInfo.valueDoubleOf(ScriptCommand.IMAGE_X_OFFSET)!;
    }
    if (commandInfo.containKey(ScriptCommand.IMAGE_Y_OFFSET)) {
      _imageYOffset = commandInfo.valueDoubleOf(ScriptCommand.IMAGE_Y_OFFSET)!;
    }
    if (commandInfo.containKey(ScriptCommand.IMAGE_ALPHA)) {
      //Change the start alpha if create command have alpha property
      _opacityNotifier.value =
          commandInfo.valueDoubleOf(ScriptCommand.IMAGE_ALPHA)!;
    }
    if (commandInfo.containKey(ScriptCommand.IMAGE_ROTATE_Z)) {
      //Change the start z-rotate if create command have rotate property
      _rotateNotifier.value[0] = commandInfo.valueDoubleOf(ScriptCommand.IMAGE_ROTATE_Z)!;
    }
    if (commandInfo.containKey(ScriptCommand.IMAGE_ROTATE_Y)) {
      //Change the start y-rotate if create command have yrotate property
      _rotateNotifier.value[1] = commandInfo.valueDoubleOf(ScriptCommand.IMAGE_ROTATE_Y)!;
    }
    if (commandInfo.containKey(ScriptCommand.IMAGE_ROTATE_X)) {
      //Change the start x-rotate if create command have xrotate property
      _rotateNotifier.value[2] = commandInfo.valueDoubleOf(ScriptCommand.IMAGE_ROTATE_X)!;
    }
    if (commandInfo.containKey(ScriptCommand.IMAGE_COLOR)) {
      //Change the start color of image if create command have color property
      _imageColor.value = commandInfo.valueOf(ScriptCommand.IMAGE_COLOR)!.toColorMatrix();
    }
    if (commandInfo.containKey(ScriptCommand.IMAGE_COLOR_BLEND_MODE)) {
      //Change the start image's blend mode if create command have blend property
      _imageBlendMode = commandInfo.valueOf(ScriptCommand.IMAGE_COLOR_BLEND_MODE)!.toBlendMode();
    }

    _imageBound= Container(child: _imageInside,);
    _rebuildMainWidget();
    setState(() {
      if(_imageType== ScriptCommand.IMAGE_TYPE_CACHE){
        WidgetsBinding.instance!.addPostFrameCallback((_) {
          WidgetsFlutterBinding.ensureInitialized();
          _completeScriptCommand(commandInfo);
        });
      } else if(_imageType== ScriptCommand.IMAGE_TYPE_VIDEO){
        _videoController!.initialize().whenComplete(() {
          _completeScriptCommand(commandInfo);
        });
      }
    });
  }

  void processVideoCommand(ScriptCommandInfo commandInfo){
    String? action= commandInfo.valueOf(ScriptCommand.COMMON_ACTION);
    if(action== null || action.length== 0){
      _completeScriptCommand(commandInfo);
      return;
    }
    if(action== ScriptCommand.VIDEO_ACTION_CREATE){
      _imageRawPath = commandInfo.valueOf(ScriptCommand.VIDEO_PATH)!;
      _imageSinglePath = AssetConstant.getTruePath(
          AssetConstant.VIDEO_DIR + _imageRawPath);
      Size videoSize = CommonFunc.getImageSizeInPath(_imageSinglePath);

      _imageOrgWidth = videoSize.width * GameConstant.gameVideoSizeRatio;
      _imageOrgHeight = videoSize.height * GameConstant.gameVideoSizeRatio;
      _positionNotifier.value= [0,null,null,0,_imageOrgWidth,_imageOrgHeight];

      _videoController= VideoPlayerController.file(File(_imageSinglePath));
      _imageInside = VideoPlayer(_videoController!);
    }

    else if(action== ScriptCommand.VIDEO_ACTION_PLAY){
      _videoController!.play().whenComplete(() {
        _completeScriptCommand(commandInfo);
      });
    }

    else if(action== ScriptCommand.VIDEO_ACTION_REMOVE){
      _videoController!.dispose();
      _videoController= null;
    }
  }

  List<AnimationController> _listAnimation= <AnimationController>[];
  void animateImageCommand(ScriptCommandInfo commandInfo) {
    int _timeInMillis = _scriptRunner.parseAnimationTime(commandInfo.valueOf(ScriptCommand.ANIMATION_TIME));
    AnimationController _controller = AnimationController(
        duration: Duration(milliseconds: _timeInMillis), vsync: this);
    Curve curve= ImageHelper.getCurveFromParam(
        commandInfo.valueOf(ScriptCommand.ANIMATION_CURVE),
        commandInfo.valueOf(ScriptCommand.ANIMATION_CUBIC));
    final Animation<double> curveTransition = CurvedAnimation(parent: _controller, curve: curve);
    late Animation<dynamic> animation;
    late Function() listener;
    Size sceneSize= _sceneSize;
    String animationType= commandInfo.valueOf(ScriptCommand.ANIMATION_TYPE)!;

    if (animationType == ScriptCommand.ANIMATION_TYPE_FADE) {
      double _oldValue = _opacityNotifier.value;
      double _newValue = commandInfo.valueDoubleOf(ScriptCommand.IMAGE_ALPHA)!;
      animation = Tween<double>(begin: _oldValue, end: _newValue).animate(curveTransition);
      listener= () {
        _opacityNotifier.value = animation.value;
      }; animation.addListener(listener);
    }

    else if (animationType == ScriptCommand.ANIMATION_TYPE_SIZE){
      final List<double?> startSizePoint= [
        _positionNotifier.value[4], _positionNotifier.value[5]];
      double? endWidthPoint, endHeightPoint;

      if (commandInfo.containKey(ScriptCommand.IMAGE_SIZE_WIDTH)) {
        String posString = commandInfo.valueOf(ScriptCommand.IMAGE_SIZE_WIDTH)!;
        double? delta= posString.getDelta();
        if(null== delta){
          endWidthPoint = (double.parse(posString)/ 100)* _imageOrgWidth;
        }else{
          endWidthPoint = _positionNotifier.value[4]!+ (delta* _imageOrgWidth/ 100);
        }
      }
      if (commandInfo.containKey(ScriptCommand.IMAGE_SIZE_HEIGHT)) {
        String posString = commandInfo.valueOf(ScriptCommand.IMAGE_SIZE_HEIGHT)!;
        double? delta= posString.getDelta();
        if(null== delta){
          endHeightPoint = (double.parse(posString)/ 100)* _imageOrgHeight;
        }else{
          endHeightPoint = _positionNotifier.value[5]!+ (delta* _imageOrgHeight/ 100);
        }
      }

      final List<double?> endSizePoint= [endWidthPoint, endHeightPoint];
      animation = ListDoubleTween(startSizePoint, endSizePoint).animate(curveTransition);
      listener= () {
        if(endWidthPoint!= null){_positionNotifier.value[4] = animation.value[0];}
        if(endHeightPoint!= null){_positionNotifier.value[5] = animation.value[1];}
        _positionNotifier.notifyListeners();
      };
      animation.addListener(listener);
    }

    else if (animationType == ScriptCommand.ANIMATION_TYPE_POSITION) {
      final List<double?> startPosPoint= [
        _positionNotifier.value[0], _positionNotifier.value[1],
        _positionNotifier.value[2], _positionNotifier.value[3]];
      double? endLeftPoint, endTopPoint, endRightPoint, endBottomPoint;

      if (commandInfo.containKey(ScriptCommand.IMAGE_POSITION_LEFT)
          && _positionNotifier.value[0]!= null){
        String posString = commandInfo.valueOf(ScriptCommand.IMAGE_POSITION_LEFT)!;
        double? delta= posString.getDelta();
        if(null== delta){
          endLeftPoint = double.parse(posString)* sceneSize.width/ 100;
          if(_imageType== ScriptCommand.IMAGE_TYPE_SPRITE){
            endLeftPoint-= _imageOrgWidth/2;
          }
        }else{
          endLeftPoint= _positionNotifier.value[0]!+ (delta* sceneSize.width/ 100);
        }
      }
      if (commandInfo.containKey(ScriptCommand.IMAGE_POSITION_TOP)
          && _positionNotifier.value[1]!= null){
        String posString = commandInfo.valueOf(ScriptCommand.IMAGE_POSITION_TOP)!;
        double? delta= posString.getDelta();
        if(null== delta){
          endTopPoint = double.parse(posString)* sceneSize.height/ 100;
        }else{
          endTopPoint= _positionNotifier.value[1]!+ (delta* sceneSize.height/ 100);
        }
      }
      if (commandInfo.containKey(ScriptCommand.IMAGE_POSITION_RIGHT)
          && _positionNotifier.value[2]!= null){
        String posString = commandInfo.valueOf(ScriptCommand.IMAGE_POSITION_RIGHT)!;
        double? delta= posString.getDelta();
        if(null== delta){
          endRightPoint = double.parse(posString)* sceneSize.width/ 100;
          if(_imageType== ScriptCommand.IMAGE_TYPE_SPRITE){
            endRightPoint-= _imageOrgWidth/2;
          }
        }else{
          endRightPoint= _positionNotifier.value[2]!+ (delta* sceneSize.width/ 100);
        }
      }
      if (commandInfo.containKey(ScriptCommand.IMAGE_POSITION_BOTTOM)
          && _positionNotifier.value[3]!= null){
        String posString = commandInfo.valueOf(ScriptCommand.IMAGE_POSITION_BOTTOM)!;
        double? delta= posString.getDelta();
        if(null== delta){
          endBottomPoint = double.parse(posString)* sceneSize.height/ 100;
        }else{
          endBottomPoint= _positionNotifier.value[3]!+ (delta* sceneSize.height/ 100);
        }
      }

      final List<double?> endPosPoint= [
        endLeftPoint, endTopPoint, endRightPoint, endBottomPoint];
      animation = ListDoubleTween(startPosPoint, endPosPoint).animate(curveTransition);
      listener= () {
        if(endLeftPoint!= null){_positionNotifier.value[0] = animation.value[0];}
        if(endTopPoint!= null) {_positionNotifier.value[1] = animation.value[1];}
        if(endRightPoint!= null){_positionNotifier.value[2] = animation.value[2];}
        if(endBottomPoint!= null){_positionNotifier.value[3] = animation.value[3];}
        _positionNotifier.notifyListeners();
      };
      animation.addListener(listener);
    }

    else if (animationType == (ScriptCommand.ANIMATION_TYPE_ROTATE)) {
      final List<double> startRotatePoint= [
        _rotateNotifier.value[0], _rotateNotifier.value[1], _rotateNotifier.value[2]];
      double? endZPoint, endYPoint, endXPoint;

      if (commandInfo.containKey(ScriptCommand.IMAGE_ROTATE_Z)){
        String rotateZString = commandInfo.valueOf(ScriptCommand.IMAGE_ROTATE_Z)!;
        double? delta= rotateZString.getDelta();
        if(null== delta){
          endZPoint = double.parse(rotateZString);
        }else{
          endZPoint= _rotateNotifier.value[0]+ delta;
        }
      }
      if (commandInfo.containKey(ScriptCommand.IMAGE_ROTATE_Y)){
        String rotateYString = commandInfo.valueOf(ScriptCommand.IMAGE_ROTATE_Y)!;
        double? delta= rotateYString.getDelta();
        if(null== delta){
          endYPoint = double.parse(rotateYString);
        }else{
          endYPoint= _rotateNotifier.value[1]+ delta;
        }
      }
      if (commandInfo.containKey(ScriptCommand.IMAGE_ROTATE_X)){
        String rotateXString = commandInfo.valueOf(ScriptCommand.IMAGE_ROTATE_X)!;
        double? delta= rotateXString.getDelta();
        if(null== delta){
          endXPoint = double.parse(rotateXString);
        }else{
          endXPoint= _rotateNotifier.value[2]+ delta;
        }
      }

      final List<double?> endRotatePoint= [endZPoint, endYPoint, endXPoint];
      animation = ListDoubleTween(startRotatePoint, endRotatePoint).animate(curveTransition);
      listener= () {
        _rotateNotifier.value[0] = animation.value[0];
        _rotateNotifier.value[1] = animation.value[1];
        _rotateNotifier.value[2] = animation.value[2];
        _rotateNotifier.notifyListeners();
      };
      animation.addListener(listener);
    }

    else if (animationType == (ScriptCommand.ANIMATION_TYPE_SHOW_MASK)
        || animationType == (ScriptCommand.ANIMATION_TYPE_HIDE_MASK)) {
      if(_imageInside is SpriteContainer){
        _completeScriptCommand(commandInfo);
        return;
      }
      String maskName= commandInfo.valueOf(ScriptCommand.ANIMATION_TYPE_MASK_IMAGE_PATH)!;
      double? destinationOpacity= commandInfo.valueDoubleOf(ScriptCommand.IMAGE_ALPHA);
      ValueNotifier<double> maskNotifier= ValueNotifier<double>(0);
      ImageHelper.getFileUiImage(AssetConstant.getTruePath(AssetConstant.EFFECT_DIR+ maskName),
          sceneSize.width.toInt(), sceneSize.height.toInt()).then((_maskImage){
        _imageBound= ValueListenableBuilder(
          valueListenable: maskNotifier,
          builder: (context, value, child) {
            if((value as double)>= 2 || value< 0){
              return Container(child: _imageInside,);
            }
            return Stack(
              children: [
                ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (bounds) {
                    return ImageShader(_maskImage, TileMode.clamp, TileMode.clamp,
                        Matrix4.identity().storage);
                  },
                  child: Opacity(
                    opacity: value> 1 ? 1 : value,
                    child: _imageInside,
                  ),
                ),
                Opacity(
                  opacity: value> 1 ? value- 1 : 0,
                  child: _imageInside,
                )
              ],
            );
          },
        );
        _rebuildMainWidget();
        bool hideMask= true;
        if(commandInfo.valueOf(ScriptCommand.ANIMATION_TYPE) ==
            (ScriptCommand.ANIMATION_TYPE_SHOW_MASK)){
          hideMask= false;
        }
        animation = Tween<double>(begin: hideMask ? 2 : 0, end: hideMask ? 0 : 2).animate(curveTransition);
        listener= () {
          maskNotifier.value = animation.value;
        };
        animation.addListener(listener);

        _listAnimation.add(_controller);
        setState(() {
          if(destinationOpacity== null){
            _opacityNotifier.value= 1;
          }else{
            _opacityNotifier.value= destinationOpacity;
          }
        });
        _controller.forward().whenCompleteOrCancel(() {
          animation.removeListener(listener);
          _controller.dispose();
          _listAnimation.remove(_controller);
          _completeScriptCommand(commandInfo);
        });
      });
      return;
    }

    else if (animationType == ScriptCommand.ANIMATION_TYPE_VIDEO) {
      if(commandInfo.containKey(ScriptCommand.ANIMATION_TYPE_VIDEO_ACTION)
          && commandInfo.valueOf(ScriptCommand.ANIMATION_TYPE_VIDEO_ACTION)== ScriptCommand.ANIMATION_TYPE_VIDEO_ACTION_STOP){
        _videoController!.dispose().whenComplete(() {
          _completeScriptCommand(commandInfo);
        });
        return;
      }

      _videoController!.setVolume(UserConfig.getDouble(UserConfig.GAME_VOLUME_MASTER));
      if(commandInfo.containKey(ScriptCommand.ANIMATION_TYPE_VIDEO_START_FRAME)){
        Duration? endPosition;
        if(commandInfo.containKey(ScriptCommand.ANIMATION_TYPE_VIDEO_END_FRAME)){
          endPosition= Duration(milliseconds:
          commandInfo.valueIntOf(ScriptCommand.ANIMATION_TYPE_VIDEO_END_FRAME)!);
        }
        _videoController!.seekTo(Duration(milliseconds: commandInfo.valueIntOf(ScriptCommand.ANIMATION_TYPE_VIDEO_START_FRAME)!)).whenComplete(() {
          late Function() listener; listener= (){
            if(endPosition!= null){
              if(_videoController!.value.position>= endPosition){
                _videoController!.pause().whenComplete(() {
                  _completeScriptCommand(commandInfo);
                  _videoController!.removeListener(listener);
                });
              }
            }else{
              if(!_videoController!.value.isPlaying){
                _completeScriptCommand(commandInfo);
                _videoController!.removeListener(listener);
              }
            }
          };
          _videoController!.addListener(listener);
          _videoController!.play();
        });
      }else if(commandInfo.containKey(ScriptCommand.ANIMATION_TYPE_VIDEO_END_FRAME)){
        final Duration endPosition= Duration(milliseconds:
        commandInfo.valueIntOf(ScriptCommand.ANIMATION_TYPE_VIDEO_END_FRAME)!);
        late Function() listener; listener= (){
          if(_videoController!.value.position>= endPosition){
            _videoController!.pause().whenComplete(() {
              _completeScriptCommand(commandInfo);
              _videoController!.removeListener(listener);
            });
          }
        };
        _videoController!.addListener(listener);
        _videoController!.play();
      }else{
        _scriptRunner.clearRunFlag();
        _videoController!.seekTo(Duration(milliseconds: 0)).whenComplete(() {
          _videoController!.play().whenComplete(() {
            _completeScriptCommand(commandInfo);
          });
        });
      }
      return;
    }

    else if (animationType == ScriptCommand.ANIMATION_TYPE_FILTER){
      List<double> oldImageColor= _imageColor.value;
      List<double> newImageColor= commandInfo.valueOf(
          ScriptCommand.ANIMATION_TYPE_FILTER_COLOR)!.toColorMatrix();
      if(oldImageColor.length!= newImageColor.length){
        oldImageColor= newImageColor.length== 1
            ? (<double>[]..add(ImageHelper.DEFAULT_COLOR))
            : "".toColorMatrix();
      }
      if(commandInfo.containKey(ScriptCommand.IMAGE_COLOR_BLEND_MODE)){
        _imageBlendMode= commandInfo.valueOf(ScriptCommand.IMAGE_COLOR_BLEND_MODE)!.toBlendMode();
      }

      if(newImageColor.length== 1){
        animation = ColorTween(begin: Color(oldImageColor[0].toInt())
            , end: Color(newImageColor[0].toInt())).animate(curveTransition);
      }else{
        animation = ListNNDoubleTween(oldImageColor, newImageColor).animate(curveTransition);
      }

      listener= () {
        if(newImageColor.length== 1){
          _imageColor.value= <double>[]..add(animation.value.value.toDouble());
        }else{
          _imageColor.value= animation.value;
        }
      };
      animation.addListener(listener);
    }

    _listAnimation.add(_controller);
    setState(() {});
    _controller.forward(from: 0).whenCompleteOrCancel(() {
      animation.removeListener(listener);
      _controller.dispose();
      _listAnimation.remove(_controller);
      _completeScriptCommand(commandInfo);
    });
  }

  @override
  void dispose() {
    for(AnimationController controller in _listAnimation){
      if(controller.isAnimating){
        controller.stop();
      }
      controller.dispose();
    }
    _listAnimation.clear();
    if(_videoController!= null) {
      _videoController!.dispose();
    }
    _opacityNotifier.dispose();
    _rotateNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _mainWidget;
  }
}

class SpriteContainer extends StatefulWidget {
  SpriteContainer({Key? key, required this.commandInfo}) : super(key: key);
  final ScriptCommandInfo commandInfo;
  final _SpriteContainerState _state= _SpriteContainerState();

  @override
  _SpriteContainerState createState() {
    return _state;
  }
}

class _SpriteContainerState extends State<SpriteContainer> {
  late ScriptCommandInfo _commandInfo;
  late String _charRootPath;

  Image? _imageBody;
  GlobalKey _bodyKey = GlobalKey();
  Widget? _imageBodySwitch;
  String? _rawBodyPath;

  Image? _imageEmo;
  GlobalKey _emoKey = GlobalKey();
  Widget? _imageEmoSwitch;
  String? _rawCharEmo;

  //String _imageCharLip;
  //String _imageCharEye;
  //String _imageCharHair;

  int _waitForCompleteCount= -1;
  bool _isInitial= true;

  void processEditPath(ScriptCommandInfo commandInfo) {
    _commandInfo= commandInfo;
    _waitForCompleteCount= 0;
    if(_isInitial){
      _charRootPath = AssetConstant.CHARACTER_DIR;
      if (commandInfo.containKey(ScriptCommand.IMAGE_PATH)) {
        _charRootPath += commandInfo.valueOf(ScriptCommand.IMAGE_PATH)!;
      } else {
        _charRootPath += commandInfo.valueOf(ScriptCommand.COMMON_NAME)!;
      }
    }

    ImageFrameBuilder _frameBuilder= (context, child, frame, wasSynchronouslyLoaded){
      if(_isInitial && frame!= null){
        _waitForCompleteCount--;
        if(_waitForCompleteCount== 0){
          WidgetsBinding.instance!.addPostFrameCallback((_) {
            WidgetsFlutterBinding.ensureInitialized();
            _completeScriptCommand(_commandInfo);
          });
        }
      }
      return child;
    };

    bool editBody= false;
    if (commandInfo.containKey(ScriptCommand.IMAGE_TYPE_SPRITE_BODY)){
      editBody= true;
      _rawBodyPath= commandInfo.valueOf(ScriptCommand.IMAGE_TYPE_SPRITE_BODY)!;
      String _pathCharBody = Path.join(
        _charRootPath,
        ScriptCommand.IMAGE_TYPE_SPRITE_BODY,
        _rawBodyPath!);
      _pathCharBody = AssetConstant.getTruePath(_pathCharBody);
      _imageBody= Image(
        key: UniqueKey(),
        fit: BoxFit.fill,
        frameBuilder: _frameBuilder,
        isAntiAlias: true,
        image: FileImage(File(_pathCharBody)),
      );
    }
    if(_imageBody!= null){_waitForCompleteCount++;}

    bool editEmo= false;
    if (commandInfo.containKey(ScriptCommand.IMAGE_TYPE_SPRITE_EMOTION)) {
      editEmo= true;
      _rawCharEmo= commandInfo.valueOf(ScriptCommand.IMAGE_TYPE_SPRITE_EMOTION)!;
      String _pathCharEmo = Path.join(
        _charRootPath,
        ScriptCommand.IMAGE_TYPE_SPRITE_EMOTION,
        _rawCharEmo!);
      _pathCharEmo = AssetConstant.getTruePath(_pathCharEmo);
      _imageEmo= Image(
        key: UniqueKey(),
        fit: BoxFit.fill,
        frameBuilder: _frameBuilder,
        image: FileImage(File(_pathCharEmo)),
      );
    }
    if(_imageEmo!= null){_waitForCompleteCount++;}

    if(!_isInitial){
      _prepareImage(editBody: editBody, editEmo: editEmo).whenComplete(() {
        setState(() {});
      });
    }else{
      _isInitial= false;
    }
  }

  Future<void> _prepareImage({bool editBody= false, bool editEmo= false}) async {
    //Don't waste operation when skipping
    if(!_scriptRunner.isNoSkipFlag()){return;}
    if (editBody){
      RenderRepaintBoundary boundary = _bodyKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image capturedBody= await boundary.toImage();
      await precacheImage(_imageBody!.image, context);
      _imageBodySwitch= ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) {
          return ImageShader(capturedBody, TileMode.clamp, TileMode.clamp,
              Matrix4.identity().storage);
          //Float64List.fromList([1.0, 1, 0, 1, 1, 1, 1, 1, 0])
          //Matrix4.identity().storage
        },
        child: _imageBody,
      );
    }

    if(editEmo){
      RenderRepaintBoundary boundary = _emoKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image capturedEmo= await boundary.toImage();
      await precacheImage(_imageEmo!.image, context);
      _imageEmoSwitch= ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) {
          return ImageShader(capturedEmo, TileMode.clamp, TileMode.clamp,
              Matrix4.identity().storage);
        },
        child: _imageEmo,
      );
    }
  }

  ValueNotifier<int> _lipNotifier= ValueNotifier<int>(0);
  String _spectrumPath= "";
  List<Widget> _lipsWidget= <Widget>[]..add(Container());
  Timer? _lipSyncTimer;
  void startLipSync(final String spectrumPath) async {
    _spectrumPath= spectrumPath;
    final String localRawBodyPath= _rawBodyPath!;
    if(_lipSyncTimer!= null && _lipSyncTimer!.isActive){
      _lipSyncTimer!.cancel();
    }
    _lipNotifier.value= 0;
    _lipsWidget= <Widget>[]..add(Container());
    File spectrumFile= File(AssetConstant.getTruePath(spectrumPath));

    if(spectrumFile.existsSync()){
      List<String> spectrumContent= spectrumFile.readAsLinesSync()[0].split(",");
      int lipCount= 0;

      for(int i= 1; i< 3; i++){
        String _pathCharLip = Path.join(
          _charRootPath,
          ScriptCommand.IMAGE_TYPE_SPRITE_BODY,
          localRawBodyPath.substring(0, localRawBodyPath.length- 1)+ i.toString());
        _lipsWidget.add(Image(
          fit: BoxFit.fill,
          image: FileImage(File(AssetConstant.getTruePath(_pathCharLip))),
        ));
      }
      _lipSyncTimer= Timer.periodic(
        Duration(milliseconds: GameConstant.LIP_SYNC_FREQUENCY), (Timer timer) {
        if (lipCount>= spectrumContent.length- 1 || localRawBodyPath!= _rawBodyPath
            || _spectrumPath!= spectrumPath || !mounted) {
          _lipsWidget.clear();
          _lipsWidget.add(Container());
          _lipNotifier.value= 0;
          _spectrumPath= "";
          timer.cancel();
          _lipSyncTimer= null;
        } else {
          _lipNotifier.value= int.parse(spectrumContent[++lipCount]);
        }
      },
      );
    }
  }

  @override
  void initState() {
    processEditPath(widget.commandInfo);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    AnimatedSwitcherLayoutBuilder _layoutBuilder= (Widget? currentChild, List<Widget> previousChildren){
      if(!_isInitial && previousChildren.length== 0){
        _waitForCompleteCount--;
        if(_waitForCompleteCount== 0){
          _imageBodySwitch= null;
          _imageEmoSwitch= null;
          WidgetsBinding.instance!.addPostFrameCallback((_) {
            WidgetsFlutterBinding.ensureInitialized();
            _completeScriptCommand(_commandInfo);
          });
        }
      }
      return Stack(
        children: <Widget>[
          ...previousChildren,
          if (currentChild != null) currentChild,
        ],
        alignment: Alignment.bottomCenter,
      );
    };
    return Stack(
      children: [
        if(_imageBodySwitch!= null) _imageBodySwitch!,
        if(_imageBody!= null) RepaintBoundary(
          key: _bodyKey,
          child: AnimatedSwitcher(
            child: _imageBody,
            layoutBuilder: _layoutBuilder,
            duration: const Duration(milliseconds: GameConstant.GAME_SPRITE_ANIMATE_TIME),
          ),
        ),
        if(_imageEmoSwitch!= null) _imageEmoSwitch!,
        if(_imageEmo!= null) RepaintBoundary(
          key: _emoKey,
          child: AnimatedSwitcher(
            child: _imageEmo,
            layoutBuilder: _layoutBuilder,
            duration: const Duration(milliseconds: GameConstant.GAME_SPRITE_ANIMATE_TIME),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: _lipNotifier,
          builder: (_, lipIndex , __){
            return IndexedStack(
              index: lipIndex as int,
              children: _lipsWidget,
            );
          },
        ),
      ],
    );
  }
}

class TextContainer extends StatefulWidget {
  TextContainer({Key? key, required this.layerName}) : super(key: key);
  final String layerName;
  final _TextContainerState _state = _TextContainerState();
  List<String> getSaveString(){
    return _state._buildSaveString();
  }

  @override
  _TextContainerState createState() {
    return _state;
  }
}

class _TextContainerState extends State<TextContainer>
    with TickerProviderStateMixin {
  final GlobalKey _displayRichTextBoundKey = GlobalKey();
  List<AnimationController> _listAnimation= <AnimationController>[];
  String _textBoxBackgroundPath = AssetConstant.TEXT_BACKGROUND_IMAGE_FILE;

  String _currentCombineText = "";
  String _currentMainText = "";
  String get displayText => _currentCombineText;
  String _lastMainText = "";
  String _currentSubText = "";
  String _lastSubText = "";
  String _currentKanaText = "";
  String _lastKanaText = "";
  List<TextSpan> _displayMainTextSpan = <TextSpan>[];

  double _lastDisplayWidth = 0;
  int _lastDisplayLineCount = 0;

  String _characterBaseName= "";

  Widget? _avatarImage;
  String? _avatarImagePath;
  Widget? _avatarEmotionImage;
  String? _avatarEmotionImagePath;

  ValueNotifier<List<double>?> _displayRichTextClipNotifier = ValueNotifier(null);
  //0 or 3: text is rendering, disable;
  //1: concat command enable, display right arrow animated gif
  //2: goto next text box, display down arrow animated gif
  //4: same as 1 but for read text
  //5: same as 2 but for read text
  ValueNotifier<int> _textRenderDoneGif = ValueNotifier<int>(0);
  //0: Display choice panel
  //1: Display main language
  //2: Display sub language
  //3: Display hiragana of japanese text(if japanese is main)
  //4: Play voice of this sentence
  ValueNotifier<int> _displayTextNotifier = ValueNotifier<int>(1);
  ValueNotifier<int> _runScriptFlagChangeNotifier = ValueNotifier<int>(ScriptRunFlag.STOP);
  ScrollController _scrollControllerForRichText= ScrollController();
  ValueNotifier<double> _opacityNotifier = ValueNotifier<double>(1);
  ValueNotifier<List<double>> _rotateNotifier = ValueNotifier<List<double>>([0,0,0]);
  late ValueNotifier<List<double?>> _positionNotifier;
  late Widget _boundTextBox;

  //Save
  List<String> _buildSaveString(){
    List<String> _saveString = <String>[];
    //_saveString.add(_currentMainTextString);

    Size sceneSize= _sceneSize;
    String commandToSave= ScriptCommand.TEXT_HEADER;
    commandToSave+= ScriptCommandInfo.buildCommandParam(
        UserConfig.get(UserConfig.GAME_MAIN_LANGUAGE), _currentMainText);
    commandToSave+= ScriptCommandInfo.buildCommandParam(
        UserConfig.get(UserConfig.GAME_SUB_LANGUAGE), _currentSubText);
    commandToSave+= ScriptCommandInfo.buildCommandParam(
        ScriptCommand.TEXT_BACKGROUND_IMAGE, _textBoxBackgroundPath);
    if(_positionNotifier.value[0]!= null){
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.IMAGE_POSITION_LEFT, (_positionNotifier.value[0]! *100/ sceneSize.width).toString());
    }else{
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.IMAGE_POSITION_LEFT, "");
    }
    if(_positionNotifier.value[1]!= null){
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.IMAGE_POSITION_TOP, (_positionNotifier.value[1]! *100/ sceneSize.height).toString());
    }else{
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.IMAGE_POSITION_TOP, "");
    }
    if(_positionNotifier.value[2]!= null){
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.IMAGE_POSITION_RIGHT, (_positionNotifier.value[2]! *100/ sceneSize.width).toString());
    }else{
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.IMAGE_POSITION_RIGHT, "");
    }
    if(_positionNotifier.value[3]!= null){
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.IMAGE_POSITION_BOTTOM, (_positionNotifier.value[3]! *100/ sceneSize.height).toString());
    }else{
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.IMAGE_POSITION_BOTTOM, "");
    }
    if(_positionNotifier.value[4]!= null){
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.IMAGE_SIZE_WIDTH, (_positionNotifier.value[4]! *100/ sceneSize.width).toString());
    }else{
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.IMAGE_SIZE_WIDTH, "");
    }
    if(_positionNotifier.value[5]!= null){
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.IMAGE_SIZE_HEIGHT, (_positionNotifier.value[5]! *100/ sceneSize.height).toString());
    }else{
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.IMAGE_SIZE_HEIGHT, "");
    }
    commandToSave+= ScriptCommandInfo.buildCommandParam(
        ScriptCommand.IMAGE_ROTATE_Z, _rotateNotifier.value[0].toString());
    commandToSave+= ScriptCommandInfo.buildCommandParam(
        ScriptCommand.TEXT_OPACITY, _opacityNotifier.value.toString());
    commandToSave+= ScriptCommandInfo.buildCommandParam(
        ScriptCommand.TEXT_CHARACTER_NAME, _characterBaseName);
    if(_avatarImagePath!= null){
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.TEXT_CHARACTER_AVATAR, _avatarImagePath);
    }
    if(_avatarEmotionImagePath!= null){
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.TEXT_CHARACTER_AVATAR_EMOTION, _avatarEmotionImagePath);
    }
    _saveString.add(commandToSave);
    return _saveString;
  }

  @override
  void initState() {
    _positionNotifier = ValueNotifier<List<double?>>([0,null,0,0,null,0]);
    _choiceWidget= ChoiceHelper(onChoiceEnd: (List<ScriptCommandInfo> listScriptCommandResult){
      for(ScriptCommandInfo commandInfo in listScriptCommandResult){
        _completeScriptCommand(commandInfo);
      }
      _scriptRunner.triggerSave(GameSingleSaveType.CHOICE);
    }, onFreezeChoice: (commandInfo){
      (_gameContainerKey.currentState as _GameContainerState)._processCommand(commandInfo);
    },);
    _buildTextBox();
    _scriptRunner.setSwitchFlagCallBack((oldFlag, flag) {
      _runScriptFlagChangeNotifier.notifyListeners();
    });
    super.initState();
  }

  @override
  void dispose() {
    for(AnimationController controller in _listAnimation){
      if(controller.isAnimating){
        controller.stop();
      }
      controller.dispose();
    }
    _listAnimation.clear();
    _displayRichTextClipNotifier.dispose();
    _textRenderDoneGif.dispose();
    _runScriptFlagChangeNotifier.dispose();
    _scrollControllerForRichText.dispose();
    _opacityNotifier.dispose();
    _rotateNotifier.dispose();
    _positionNotifier.dispose();
    super.dispose();
  }

  void _buildTextBox(){
    _boundTextBox= WidgetHelper.getCommonWidgetForGameContainer(
      Stack(
        fit: StackFit.expand,
        children: [
          if(_textBoxBackgroundPath.length> 0 && UserConfig.getDouble(
              UserConfig.TEXT_BOX_BACKGROUND_OPACITY)> 0) ValueListenableBuilder(
              valueListenable: UserConfig.getListener(UserConfig.TEXT_BOX_BACKGROUND_OPACITY),
              builder: (_, box, __) {
                return Image(
                  fit: BoxFit.fill,
                  image: FileImage(File(AssetConstant.getTruePath(
                      AssetConstant.IMAGE_DIR +_textBoxBackgroundPath))),
                  colorBlendMode: BlendMode.modulate,
                  color: Colors.white.withOpacity(UserConfig.getDouble(UserConfig.TEXT_BOX_BACKGROUND_OPACITY)),);
              }
          ),
          Row(
            children: [
              AspectRatio(
                aspectRatio: GameConstant.GAME_TEXT_BOX_AVATAR_ASPECT_RATIO,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if(_avatarImage!= null) Positioned(
                      left: 0, top: 0, right: 0,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds:
                        GameConstant.GAME_TEXTBOX_ELEMENT_ANIMATE_TIME),
                        child: _avatarImage,
                      ),
                    ),
                    if(_avatarEmotionImage!= null) Positioned(
                      left: 0, top: 0, right: 0,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds:
                        GameConstant.GAME_TEXTBOX_ELEMENT_ANIMATE_TIME),
                        child: _avatarEmotionImage,
                      ),
                    ),
                    GestureDetector(
                      onTap: (){
                        _doAppCommand(MyAppCmd.USER_RUN_SCRIPT);
                      },
                      onLongPressStart: (details){
                        if(_tempHideTextBox){
                          hideTextBox(false);
                        }
                        _doAppCommand(MyAppCmd.SWITCH_SKIP_ALL, switchOn: true);
                      },
                      onLongPressEnd: (details){
                        _doAppCommand(MyAppCmd.SWITCH_SKIP_ALL, switchOn: false);
                      },
                      child: Container(color: Colors.transparent),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3, bottom: 3),
                  child: Stack(
                    children: [
                      Container(key: _displayRichTextBoundKey, color: Colors.transparent,),
                      ValueListenableBuilder(
                        valueListenable: _displayTextNotifier,
                        builder: (context, displayIndex, child){
                          if((displayIndex as int)< 0){
                            return _textMenu;
                          }
                          if(displayIndex== 4){
                            final List<String>? listVoice= _scriptRunner.buildBackLog().last.listVoiceCommand;
                            if(listVoice!= null){
                              AudioHelper.playBackLogVoice(listVoice);
                            }
                            displayIndex= 0;
                          }
                          if(displayIndex== 0){
                            return SingleChildScrollView(
                              controller: _scrollControllerForRichText,
                              scrollDirection: Axis.vertical,
                              child: ValueListenableBuilder(
                                valueListenable: _displayRichTextClipNotifier,
                                builder: (_, clipValue, __) => (clipValue as List<double>?)== null ? RichText(
                                  textAlign: TextAlign.start,
                                  text: TextSpan(
                                    children: _displayMainTextSpan,
                                  ),
                                ) : ClipPath(
                                  clipper: TextBoxClipper(
                                    width: clipValue![0],
                                    preHeight: clipValue[1],
                                    height: clipValue[2],
                                    position: clipValue[3],
                                  ),
                                  clipBehavior: Clip.hardEdge,
                                  child: RichText(
                                    textAlign: TextAlign.start,
                                    text: TextSpan(
                                      children: _displayMainTextSpan,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          if(displayIndex== 1){
                            return SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: RichText(
                                textAlign: TextAlign.start,
                                text: TextSpan(
                                  children: TextProcessor.buildSpanFromString(_currentMainText),
                                ),
                              ),
                            );
                          }
                          if(displayIndex== 2){
                            return SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: RichText(
                                textAlign: TextAlign.start,
                                text: TextSpan(
                                  children: TextProcessor.buildSpanFromString(_currentSubText),
                                ),
                              ),
                            );
                          }
                          if(displayIndex== 3){
                            return SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: Center(
                                child: RichText(
                                  //Include clickable text so make it center to prevent being crushed by Menu
                                  textAlign: TextAlign.start,
                                  text: TextSpan(
                                    children: TextProcessor.buildSpanFromString(_currentKanaText),
                                  ),
                                ),
                              ),
                            );
                          }
                          return Container();
                        },
                      ),
                      ValueListenableBuilder(
                        valueListenable: _displayTextNotifier,
                        builder: (context, displayIndex, child){
                          return GestureDetector(//disable onTap when display clickable content to prevent tap override
                            onTap: displayIndex== 3 ? null: () {
                              if(_tempHideTextBox){
                                hideTextBox(false);
                              }else{
                                _doAppCommand(MyAppCmd.USER_RUN_SCRIPT);
                              }
                            },
                            onLongPressStart: (details){
                              if(_tempHideTextBox){
                                hideTextBox(false);
                              }
                              _doAppCommand(MyAppCmd.SWITCH_SKIP_ALL, switchOn: true);
                            },
                            onLongPressEnd: (details){
                              _doAppCommand(MyAppCmd.SWITCH_SKIP_ALL, switchOn: false);
                            },
                            onPanStart: (details){
                              _textMenu= GameTextMenu(boundSize: _displayRichTextBoundKey.currentContext!.size!);
                              _displayTextNotifier.value= -1;
                            },
                            onPanUpdate: (details){
                              (_textMenu as GameTextMenu).update(details.localPosition);
                            },
                            onPanEnd: (details){
                              _displayTextNotifier.value= (_textMenu as GameTextMenu).hide();
                              _textMenu= Container();
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: AspectRatio(
                  aspectRatio: GameConstant.GAME_TEXT_BOX_RIGHT_ASPECT_RATIO,
                  child: Column(
                    children: [
                      Expanded(//_runScriptFlagChangeNotifier
                        flex: 25,
                        child: SizedBox(),
                      ),
                      Expanded(
                        flex: 25,
                        child: SizedBox(),
                      ),
                      Expanded(
                        flex: 25,
                        child: ValueListenableBuilder(
                          valueListenable: _runScriptFlagChangeNotifier,
                          builder: (_, runFlag, __) {
                            return Row(
                              children: [
                                Expanded(
                                    flex: 1,
                                    child: _scriptRunner.haveRunFlag(ScriptRunFlag.AUTO)
                                        ? Center(child: Icon(Icons.play_arrow, color: Colors.yellowAccent,))
                                        : SizedBox()
                                ),
                                Expanded(
                                    flex: 1,
                                    child: _scriptRunner.haveRunFlag(ScriptRunFlag.SKIP_READ)
                                        ? Center(child: Icon(Icons.skip_next, color: Colors.orangeAccent,))
                                        : _scriptRunner.haveRunFlag(ScriptRunFlag.SKIP_ALL)
                                        ? Center(child: Icon(Icons.fast_forward, color: Colors.redAccent,))
                                        : SizedBox()
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      Expanded(
                        flex: 25,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: AspectRatio(
                            aspectRatio: 0.8,
                            child: ValueListenableBuilder(
                              valueListenable: _textRenderDoneGif,
                              builder: (_, afterRenderValue, __) {
                                if((afterRenderValue as int)% 3== 1){
                                  return Transform.rotate(
                                    angle: CommonFunc.getRotateValue(90),
                                    child: Image.asset(
                                      AssetConstant.APP_TEXT_BOX_ARROW_UP_GIF,
                                      color: afterRenderValue> 3 ? Colors.lightBlueAccent : Colors.white,
                                    ),
                                  );
                                }else if(afterRenderValue% 3== 2){
                                  return Transform.rotate(
                                    angle: CommonFunc.getRotateValue(180),
                                    child: Image.asset(
                                      AssetConstant.APP_TEXT_BOX_ARROW_UP_GIF,
                                      color: afterRenderValue> 3 ? Colors.lightBlueAccent : Colors.white,
                                    ),
                                  );
                                }
                                return SizedBox();
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      _opacityNotifier,
      _rotateNotifier,
      _positionNotifier,
    );
  }

  void processTextCommand(ScriptCommandInfo commandInfo) {
    if(commandInfo.containKey(ScriptCommand.COMMON_ACTION)){
      String action= commandInfo.valueOf(ScriptCommand.COMMON_ACTION)!;
      if(action== ScriptCommand.ANIMATION_ACTION_NAME){
        animateTextCommand(commandInfo);
        return;
      }
    }
    _textRenderDoneGif.value= 0;
    if(_lastMainText.length== 0 && _scrollControllerForRichText.hasClients){
      _scrollControllerForRichText.jumpTo(0);
    }

    bool needRebuildTextBox= false;
    if (commandInfo.containKey(ScriptCommand.TEXT_BACKGROUND_IMAGE)){
      needRebuildTextBox= true;
      _textBoxBackgroundPath = commandInfo.valueOf(ScriptCommand.TEXT_BACKGROUND_IMAGE)!;
    }

    if (commandInfo.containKey(ScriptCommand.TEXT_CHARACTER_AVATAR)){
      needRebuildTextBox= true;
      _avatarImagePath = commandInfo.valueOf(ScriptCommand.TEXT_CHARACTER_AVATAR);
      if(_avatarImagePath!.length> 0){
        _avatarImage = Image(
          image: FileImage(File(AssetConstant.getTruePath(
              AssetConstant.AVATAR_DIR + _avatarImagePath!))),
        );
      }else {
        _avatarImage = null;
      }
    }

    if (commandInfo.containKey(ScriptCommand.TEXT_CHARACTER_AVATAR_EMOTION)){
      needRebuildTextBox= true;
      _avatarEmotionImagePath =
          commandInfo.valueOf(ScriptCommand.TEXT_CHARACTER_AVATAR_EMOTION);
      if(_avatarEmotionImagePath!.length> 0){
        _avatarEmotionImage = Image(
          image: FileImage(File(AssetConstant.getTruePath(
              AssetConstant.AVATAR_DIR + _avatarEmotionImagePath!))),
        );
      }else{
        _avatarEmotionImage = null;
      }
    }
    if(needRebuildTextBox){
      _buildTextBox();
    }

    CharacterOfText? _characterOfText;
    if (commandInfo.containKey(ScriptCommand.TEXT_CHARACTER_NAME)){
      String characterName = commandInfo.valueOf(ScriptCommand.TEXT_CHARACTER_NAME)!;
      if(characterName.length> 0){
        _characterOfText= CharacterOfText.get(characterName);
      }
      _characterBaseName= characterName;
    }else if(_lastMainText.length== 0){
      //Reset character name if not concat
      _characterBaseName="";
    }

    String? newMainString= commandInfo.valueOf(UserConfig.get(UserConfig.GAME_MAIN_LANGUAGE));
    if(newMainString== null){newMainString= "";}
    if(_lastMainText.length> 0){
      _currentMainText= _lastMainText + newMainString;
    }else if(_characterOfText!= null){
      _currentMainText= _characterOfText.getDisplayName(
          UserConfig.get(UserConfig.GAME_MAIN_LANGUAGE)) + newMainString;
    }else{
      _currentMainText= newMainString;
    }

    String? newSubString= commandInfo.valueOf(UserConfig.get(UserConfig.GAME_SUB_LANGUAGE));
    if(newSubString== null){newSubString= "";}
    if(_lastSubText.length> 0){
      _currentSubText= _lastSubText + newSubString;
    }else if(_characterOfText!= null){
      _currentSubText= _characterOfText.getDisplayName(
          UserConfig.get(UserConfig.GAME_SUB_LANGUAGE)) + newSubString;
    }else{
      _currentSubText= newSubString;
    }

    //_currentKanaText
    String? newKanaString= commandInfo.valueOf(Language.JP_KANJI_WITH_HIRAGANA);
    if(newKanaString== null){newKanaString= "";}
    if(_lastKanaText.length> 0){
      _currentKanaText= _lastKanaText + newKanaString;
    }else{
      _currentKanaText= newKanaString;
    }

    if(UserConfig.getBool(UserConfig.IS_ACTIVE_MAIN_LANGUAGE)){
      if(UserConfig.getBool(UserConfig.IS_ACTIVE_SUB_LANGUAGE)){
        _currentCombineText= _currentMainText
            + TextProcessor.FULL_TAG_LINE_BREAK + _currentSubText;
      }else{
        _currentCombineText= _currentMainText;
      }
    }else{
      _currentCombineText= _currentSubText;
    }

    Size sceneSize= _sceneSize;
    bool positionChanged= false;
    if (commandInfo.containKey(ScriptCommand.IMAGE_POSITION_LEFT)) {
      positionChanged= true;
      double? _textPosLeft = commandInfo.valueDoubleOf(ScriptCommand.IMAGE_POSITION_LEFT);
      if(_textPosLeft!= null){
        _textPosLeft = (_textPosLeft/ 100)* sceneSize.width;
      }
      _positionNotifier.value[0]= _textPosLeft;
    }
    if (commandInfo.containKey(ScriptCommand.IMAGE_POSITION_RIGHT)) {
      positionChanged= true;
      double? _textPosRight = commandInfo.valueDoubleOf(ScriptCommand.IMAGE_POSITION_RIGHT);
      if(_textPosRight!= null){
        _textPosRight = (_textPosRight/ 100)* sceneSize.width;
      }
      _positionNotifier.value[2]= _textPosRight;
    }
    if (commandInfo.containKey(ScriptCommand.IMAGE_POSITION_TOP)) {
      positionChanged= true;
      double? _textPosTop = commandInfo.valueDoubleOf(ScriptCommand.IMAGE_POSITION_TOP);
      if(_textPosTop!= null){
        _textPosTop = (_textPosTop/ 100)* sceneSize.height;
      }
      _positionNotifier.value[1]= _textPosTop;
    }
    if (commandInfo.containKey(ScriptCommand.IMAGE_POSITION_BOTTOM)) {
      positionChanged= true;
      double? _textPosBottom = commandInfo.valueDoubleOf(ScriptCommand.IMAGE_POSITION_BOTTOM);
      if(_textPosBottom!= null){
        _textPosBottom = (_textPosBottom/ 100)* sceneSize.height;
      }
      _positionNotifier.value[3]= _textPosBottom;
    }
    if (commandInfo.containKey(ScriptCommand.IMAGE_SIZE_WIDTH)) {
      positionChanged= true;
      double? _textSizeWidth = commandInfo.valueDoubleOf(ScriptCommand.IMAGE_SIZE_WIDTH);
      if(_textSizeWidth!= null){
        _textSizeWidth = (_textSizeWidth/ 100)* sceneSize.width;
      }
      _positionNotifier.value[4]= _textSizeWidth;
    }
    if (commandInfo.containKey(ScriptCommand.IMAGE_SIZE_HEIGHT)) {
      positionChanged= true;
      double? _textSizeHeight = commandInfo.valueDoubleOf(ScriptCommand.IMAGE_SIZE_HEIGHT);
      if(_textSizeHeight!= null){
        _textSizeHeight = (_textSizeHeight/ 100)* sceneSize.height;
      }
      _positionNotifier.value[5]= _textSizeHeight;
    }

    bool rotationChanged= false;
    if (commandInfo.containKey(ScriptCommand.IMAGE_ROTATE_Z)) {
      rotationChanged= true;
      _rotateNotifier.value[0] = commandInfo.valueDoubleOf(ScriptCommand.IMAGE_ROTATE_Z)!;
    }

    bool opacityChanged= false;
    if (commandInfo.containKey(ScriptCommand.TEXT_OPACITY)) {
      opacityChanged= true;
      _opacityNotifier.value = commandInfo.valueDoubleOf(ScriptCommand.TEXT_OPACITY)!;
    }

    _displayTextNotifier.value= 0;
    if(SingleSaveInfo.TEXT_ANIMATION_STYLE_TYPE_WRITER== _scriptRunner.getLocalParameter(SingleSaveInfo.TEXT_ANIMATION_STYLE)){
      _displayRichTextClipNotifier.value= null;
      String? localTextSpeedPercent= _scriptRunner.getLocalParameter(SingleSaveInfo.TEXT_SPEED_PERCENT);
      double textSpeedPercent= localTextSpeedPercent.length == 0 ? 1 : double.parse(localTextSpeedPercent);
      Iterator<int> subIndex= TextProcessor.getListSubIndexTypeWriter(_currentCombineText, _lastMainText).iterator;

      if(commandInfo.containKey(ScriptCommand.TEXT_IS_CONCAT)){
        _lastMainText= _currentMainText;
        _lastSubText= _currentSubText;
      }else{
        _lastMainText = "";
        _lastSubText = "";
      }

      if(positionChanged){_positionNotifier.notifyListeners();}
      if(rotationChanged){_rotateNotifier.notifyListeners();}
      if(opacityChanged){_opacityNotifier.notifyListeners();}

      if(_scriptRunner.haveRunFlag(ScriptRunFlag.SKIP_READ)
          || _scriptRunner.haveRunFlag(ScriptRunFlag.SKIP_MAX)
          || (UserConfig.getBool(UserConfig.IS_ACTIVE_MAIN_LANGUAGE)
              && UserConfig.getBool(UserConfig.IS_ACTIVE_SUB_LANGUAGE))){
        _displayMainTextSpan = TextProcessor.buildSpanFromString(_currentCombineText);
        _textRenderDoneGif.value = 0;
        _displayRichTextClipNotifier.notifyListeners();
        _completeScriptCommand(commandInfo);
        return;
      }else{
        int frequency= (UserConfig.getDouble(UserConfig.ONE_CHARACTER_DISPLAY_TIME)
            * textSpeedPercent* timeDilation).toInt();
        RenderBox _displayRichTextBoundBox =
        _displayRichTextBoundKey.currentContext!.findRenderObject() as RenderBox;
        double lastRenderedHeight= 0;

        Timer.periodic(
          Duration(milliseconds: frequency), (Timer timer) {
          if(subIndex.moveNext()){
            _displayMainTextSpan = TextProcessor.buildSpanFromString(_currentCombineText.substring(0, subIndex.current)+ "_");
            TextPainter textPainter = TextPainter(
              textDirection: TextDirection.ltr,
              text: TextSpan(children: _displayMainTextSpan),
            );
            textPainter.layout(minWidth: 0,
              maxWidth: _displayRichTextBoundBox.size.width,
            );
            double height = 0;
            List<ui.LineMetrics> metrics= textPainter.computeLineMetrics();
            _lastDisplayLineCount= metrics.length;
            for (ui.LineMetrics lineMetric in metrics) {
              height+= lineMetric.height;
            }
            _displayRichTextClipNotifier.notifyListeners();
            if(_scriptRunner.isNoSkipFlag()
                && height> _displayRichTextBoundBox.size.height
                && height> lastRenderedHeight){
              lastRenderedHeight= height;
              _scrollControllerForRichText.animateTo(
                  height- _displayRichTextBoundBox.size.height,
                  duration: const Duration(milliseconds: GameConstant.GAME_TEXT_BOX_SCROLL_TIME),
                  curve: Curves.linear);
            }
          }else{
            _displayMainTextSpan = TextProcessor.buildSpanFromString(_currentCombineText);
            if (commandInfo.containKey(ScriptCommand.TEXT_DO_NOT_STOP)
                || _opacityNotifier.value== 0){
              _textRenderDoneGif.value = 0;
            }else if (commandInfo.containKey(ScriptCommand.TEXT_IS_CONCAT)){
              _textRenderDoneGif.value = 1;
            }else{
              _textRenderDoneGif.value = 2;
            }
            if(_scriptRunner.wasRead()){_textRenderDoneGif.value+= 3;}
            _displayRichTextClipNotifier.notifyListeners();
            _lastDisplayLineCount= 0;
            timer.cancel();
            _completeScriptCommand(commandInfo);
          }
        },);
      }
      return;
    }

    _displayMainTextSpan = TextProcessor.buildSpanFromString(_currentCombineText);
    if(commandInfo.containKey(ScriptCommand.TEXT_IS_CONCAT)){
      _lastMainText= _currentMainText;
      _lastSubText= _currentSubText;
    }else{
      _lastMainText = "";
      _lastSubText = "";
    }
    if(_scriptRunner.haveRunFlag(ScriptRunFlag.SKIP_READ)
        || _scriptRunner.haveRunFlag(ScriptRunFlag.SKIP_MAX)
        || (UserConfig.getBool(UserConfig.IS_ACTIVE_MAIN_LANGUAGE)
            && UserConfig.getBool(UserConfig.IS_ACTIVE_SUB_LANGUAGE))){
      if (commandInfo.containKey(ScriptCommand.TEXT_IS_CONCAT)){
        _textRenderDoneGif.value = 1;
        _lastDisplayLineCount = 1;
        _lastDisplayWidth = 1;
      }else{
        _textRenderDoneGif.value = 2;
        _lastDisplayLineCount = 0;
        _lastDisplayWidth = 0;
      }
      if (commandInfo.containKey(ScriptCommand.TEXT_DO_NOT_STOP)
          || _opacityNotifier.value== 0){
        _textRenderDoneGif.value = 0;
      }
      if(_scriptRunner.wasRead()){_textRenderDoneGif.value+= 3;}
      _displayRichTextClipNotifier.value = null;
      _displayRichTextClipNotifier.notifyListeners();
      setState(() {
        if(positionChanged){_positionNotifier.notifyListeners();}
        if(rotationChanged){_rotateNotifier.notifyListeners();}
        if(opacityChanged){_opacityNotifier.notifyListeners();}
      });
      _completeScriptCommand(commandInfo);
      return;
    }
    Size _displayRichTextBoundBoxSize= _displayRichTextBoundKey.currentContext!.size!;
    TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(children: _displayMainTextSpan),
    );
    textPainter.layout(minWidth: 0,
      maxWidth: _displayRichTextBoundBoxSize.width,
    );
    double height = 0;
    List<double> widthList = <double>[];
    List<double> heightIncrease = <double>[]..add(0);
    List<ui.LineMetrics> lines = textPainter.computeLineMetrics();
    for (ui.LineMetrics lineMetric in lines) {
      widthList.add(lineMetric.width);
      height+= lineMetric.height;
      heightIncrease.add(height);
    }
    //No render animation for character name
    int count= (_lastMainText.length== 0 && _characterOfText!= null) ? 1 : _lastDisplayLineCount;
    Duration _duration = Duration(milliseconds:
    TextProcessor.computeClipDuration(widthList[count] - _lastDisplayWidth,
        _scriptRunner.getLocalParameter(SingleSaveInfo.TEXT_SPEED_PERCENT)));
    AnimationController _animationController = AnimationController(
        duration: _duration, vsync: this);
    Tween<double> _displayTextTween= Tween<double>(begin: _lastDisplayWidth, end: widthList[count]);
    Animation<double> _animation = _displayTextTween.animate(_animationController);

    Function() listener= () {
      _displayRichTextClipNotifier.value = [
        _displayRichTextBoundBoxSize.width,
        heightIncrease[count],
        heightIncrease[count+1],
        _animation.value,
      ];
    };
    _animation.addListener(listener);
    late AnimationStatusListener statusListener; statusListener= (status) {
      if (status == AnimationStatus.completed) {
        count++;
        if(count< widthList.length){
          _displayTextTween.begin = 0;
          _displayTextTween.end = widthList[count];
          if(_scriptRunner.haveRunFlag(ScriptRunFlag.SKIP_READ)
              || _scriptRunner.haveRunFlag(ScriptRunFlag.SKIP_MAX)){
            _animationController.duration= Duration(milliseconds: 0);
          }else{
            _animationController.duration= Duration(milliseconds:
            TextProcessor.computeClipDuration(widthList[count],
                _scriptRunner.getLocalParameter(SingleSaveInfo.TEXT_SPEED_PERCENT)));
          }
          _animationController.forward(from: 0);
          if(_scriptRunner.isNoSkipFlag() && (count+1)< heightIncrease.length
              && _displayRichTextBoundBoxSize.height< heightIncrease[count+1]){
            _scrollControllerForRichText.animateTo(
                heightIncrease[count+1] - _displayRichTextBoundBoxSize.height,
                duration: const Duration(milliseconds: GameConstant.GAME_TEXT_BOX_SCROLL_TIME),
                curve: Curves.linear);
          }
        }else{
          if (commandInfo.containKey(ScriptCommand.TEXT_IS_CONCAT)){
            _lastDisplayLineCount = count- 1;
            _lastDisplayWidth = widthList[count- 1];
            _textRenderDoneGif.value = 1;
          }else{
            _lastDisplayLineCount = 0;
            _lastDisplayWidth = 0;
            _textRenderDoneGif.value = 2;
          }
          if (commandInfo.containKey(ScriptCommand.TEXT_DO_NOT_STOP)
              || _opacityNotifier.value== 0){
            _textRenderDoneGif.value = 0;
          }
          if(_scriptRunner.wasRead()){_textRenderDoneGif.value+= 3;}
          _displayRichTextClipNotifier.value = null;
          _animation.removeListener(listener);
          _animationController.removeStatusListener(statusListener);
          _animationController.dispose();
          _listAnimation.remove(_animationController);
          _completeScriptCommand(commandInfo);
        }
      }
    };
    _animationController.addStatusListener(statusListener);
    _listAnimation.add(_animationController);
    setState(() {
      if(positionChanged){_positionNotifier.notifyListeners();}
      if(rotationChanged){_rotateNotifier.notifyListeners();}
      if(opacityChanged){_opacityNotifier.notifyListeners();}
    });
    _animationController.forward(from: 0);
  }

  void animateTextCommand(ScriptCommandInfo commandInfo) {
    int _timeInMillis = _scriptRunner.parseAnimationTime(commandInfo.valueOf(ScriptCommand.ANIMATION_TIME));
    AnimationController _animationController = AnimationController(
        duration: Duration(milliseconds: _timeInMillis), vsync: this);
    Curve curve= ImageHelper.getCurveFromParam(
        commandInfo.valueOf(ScriptCommand.ANIMATION_CURVE),
        commandInfo.valueOf(ScriptCommand.ANIMATION_CUBIC));
    final Animation<double> curveTransition = CurvedAnimation(parent: _animationController, curve: curve);
    late Animation<dynamic> animation;
    late Function() listener;
    Size sceneSize= _sceneSize;

    if (commandInfo.valueOf(ScriptCommand.ANIMATION_TYPE) ==
        ScriptCommand.ANIMATION_TYPE_FADE) {
      double _oldValue = _opacityNotifier.value;
      double _newValue = commandInfo.valueDoubleOf(ScriptCommand.IMAGE_ALPHA)!;
      animation = Tween<double>(begin: _oldValue, end: _newValue).animate(curveTransition);
      listener= () {
        _opacityNotifier.value = animation.value;
      }; animation.addListener(listener);
    }

    else if (commandInfo.valueOf(ScriptCommand.ANIMATION_TYPE) ==
        ScriptCommand.ANIMATION_TYPE_SIZE){
      final List<double?> startSizePoint= [
        _positionNotifier.value[4], _positionNotifier.value[5]];
      double? endWidthPoint, endHeightPoint;

      if (commandInfo.containKey(ScriptCommand.IMAGE_SIZE_WIDTH)) {
        String posString = commandInfo.valueOf(ScriptCommand.IMAGE_SIZE_WIDTH)!;
        double? delta= posString.getDelta();
        if(null== delta){
          endWidthPoint = (double.parse(posString)/ 100)* _sceneSize.width;
        }else{
          endWidthPoint = _positionNotifier.value[4]!+ (delta* _sceneSize.width/ 100);
        }
      }
      if (commandInfo.containKey(ScriptCommand.IMAGE_SIZE_HEIGHT)) {
        String posString = commandInfo.valueOf(ScriptCommand.IMAGE_SIZE_HEIGHT)!;
        double? delta= posString.getDelta();
        if(null== delta){
          endHeightPoint = (double.parse(posString)/ 100)* _sceneSize.height;
        }else{
          endHeightPoint = _positionNotifier.value[5]!+ (delta* _sceneSize.height/ 100);
        }
      }

      final List<double?> endSizePoint= [endWidthPoint, endHeightPoint];
      animation = ListDoubleTween(startSizePoint, endSizePoint).animate(curveTransition);
      listener= () {
        if(endWidthPoint!= null){_positionNotifier.value[4] = animation.value[0];}
        if(endHeightPoint!= null){_positionNotifier.value[5] = animation.value[1];}
        _positionNotifier.notifyListeners();
      };
      animation.addListener(listener);
    }

    else if (commandInfo.valueOf(ScriptCommand.ANIMATION_TYPE) ==
        ScriptCommand.ANIMATION_TYPE_POSITION) {
      final List<double?> startPosPoint= [
        _positionNotifier.value[0], _positionNotifier.value[1],
        _positionNotifier.value[2], _positionNotifier.value[3]];
      double? endLeftPoint, endTopPoint, endRightPoint, endBottomPoint;

      if (commandInfo.containKey(ScriptCommand.IMAGE_POSITION_LEFT)
          && _positionNotifier.value[0]!= null){
        String posString = commandInfo.valueOf(ScriptCommand.IMAGE_POSITION_LEFT)!;
        double? delta= posString.getDelta();
        if(null== delta){
          endLeftPoint = double.parse(posString)* sceneSize.width/ 100;
        }else{
          endLeftPoint= _positionNotifier.value[0]!+ (delta* sceneSize.width/ 100);
        }
      }
      if (commandInfo.containKey(ScriptCommand.IMAGE_POSITION_TOP)
          && _positionNotifier.value[1]!= null){
        String posString = commandInfo.valueOf(ScriptCommand.IMAGE_POSITION_TOP)!;
        double? delta= posString.getDelta();
        if(null== delta){
          endTopPoint = double.parse(posString)* sceneSize.height/ 100;
        }else{
          endTopPoint= _positionNotifier.value[1]!+ (delta* sceneSize.height/ 100);
        }
      }
      if (commandInfo.containKey(ScriptCommand.IMAGE_POSITION_RIGHT)
          && _positionNotifier.value[2]!= null){
        String posString = commandInfo.valueOf(ScriptCommand.IMAGE_POSITION_RIGHT)!;
        double? delta= posString.getDelta();
        if(null== delta){
          endRightPoint = double.parse(posString)* sceneSize.width/ 100;
        }else{
          endRightPoint= _positionNotifier.value[2]!+ (delta* sceneSize.width/ 100);
        }
      }
      if (commandInfo.containKey(ScriptCommand.IMAGE_POSITION_BOTTOM)
          && _positionNotifier.value[3]!= null){
        String posString = commandInfo.valueOf(ScriptCommand.IMAGE_POSITION_BOTTOM)!;
        double? delta= posString.getDelta();
        if(null== delta){
          endBottomPoint = double.parse(posString)* sceneSize.height/ 100;
        }else{
          endBottomPoint= _positionNotifier.value[3]!+ (delta* sceneSize.height/ 100);
        }
      }
      final List<double?> endPosPoint= [
        endLeftPoint, endTopPoint, endRightPoint, endBottomPoint];
      animation = ListDoubleTween(startPosPoint, endPosPoint).animate(curveTransition);
      listener= () {
        if(endLeftPoint!= null){_positionNotifier.value[0] = animation.value[0];}
        if(endTopPoint!= null) {_positionNotifier.value[1] = animation.value[1];}
        if(endRightPoint!= null){_positionNotifier.value[2] = animation.value[2];}
        if(endBottomPoint!= null){_positionNotifier.value[3] = animation.value[3];}
        _positionNotifier.notifyListeners();
      };
      animation.addListener(listener);
    }

    _listAnimation.add(_animationController);
    setState(() {});
    _animationController.forward(from: 0).whenCompleteOrCancel(() {
      animation.removeListener(listener);
      _animationController.dispose();
      _listAnimation.remove(_animationController);
      _completeScriptCommand(commandInfo);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            if(_tempHideTextBox){
              hideTextBox(false);
            }else{
              _doAppCommand(MyAppCmd.USER_RUN_SCRIPT);
            }
          },
          onLongPressStart: (details){
            if(_tempHideTextBox){
              hideTextBox(false);
            }
            _doAppCommand(MyAppCmd.SWITCH_SKIP_ALL, switchOn: true);
          },
          onLongPressEnd: (details){
            _doAppCommand(MyAppCmd.SWITCH_SKIP_ALL, switchOn: false);
          },
          onPanStart: (dragDetail){
            //Size boundSize= _textContainerKey.currentContext.size;
            if(_tempHideTextBox){
              hideTextBox(false);
            }
            _quickMenu.show();
          },
          onPanUpdate: (dragUpdateDetail){
            _quickMenu.update(dragUpdateDetail.localPosition);
          },
          onPanEnd: (dragEndDetail){
            _doAppCommand(_quickMenu.hide());
          },
        ),
        if(!_tempHideTextBox) _boundTextBox,
        _choiceWidget,
        _quickMenu,
      ],
    );
  }

  QuickMenu _quickMenu= QuickMenu();
  Widget _textMenu= Container();

  bool _tempHideTextBox= false;
  void hideTextBox(bool isHide){
    setState(() {
      _tempHideTextBox= isHide;
    });
  }

  late ChoiceHelper _choiceWidget;
  void processChoiceCommand(ScriptCommandInfo commandInfo){
    if(commandInfo.containKey(ScriptCommand.COMMON_ACTION)){
      String action= commandInfo.valueOf(ScriptCommand.COMMON_ACTION)!;
      if(ScriptCommand.CHOICE_ACTION_CLEAR== action){
        _choiceWidget.clearChoice();
        _completeScriptCommand(commandInfo);
      }

      return;
    }
    _choiceWidget.addCommand(commandInfo);
  }
}

class MenuContainer extends StatefulWidget {
  MenuContainer({Key? key}) : super(key: key);
  @override
  _MenuContainerState createState() => _MenuContainerState();
}

class _MenuContainerState extends State<MenuContainer> {
  double _menuOpacity= 0;
  Widget? _triggeringWidget;
  GlobalKey _triggeringWidgetKey= GlobalKey();
  String _triggeringText= "";

  void _switchTriggerWidget(String? triggerText){
    if(AudioHelper.isVoicePlaying()){
      AudioHelper.stopVoice();
    }
    if(null== triggerText){
      _menuOpacity= 0;
      _triggeringWidget= null;
      setState(() {});
      return;
    }
    if(_triggeringText== triggerText){
      _triggeringText= "";
      _triggeringWidget= null;
      setState(() {});
      return;
    }
    _triggeringText= triggerText;
    if(_triggeringText.length== 0){
      _triggeringWidget= null;
      _triggeringText= "";
    }else{
      _triggerWidget();
    }
    setState(() {});
  }

  _triggerWidget(){
    if(_triggeringText== GameText.MENU_SAVE_AND_LOAD){
      _triggeringWidget= GameSaveLoad(
        key: _triggeringWidgetKey,
        canSave: _scriptRunner.isAllowSave(),
        onSave: (saveSlot){
          FileImage(File(SavesInfo.getSaveThumbPath(SavesInfo.getKey(GameSaveType.NORMAL, saveSlot)))).evict().then((isSuccess) {
            RenderRepaintBoundary _renderRepaintBoundary =
            _sceneContainerKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
            _renderRepaintBoundary.toImage(pixelRatio: SavesInfo.THUMBNAIL_WIDTH/ _sceneSize.width).then((capturedImg) {
              _scriptRunner.userSave(GameSaveType.NORMAL,
                  (_textContainerKey.currentState as _TextContainerState).displayText,
                  saveSlot, capturedImg).whenComplete(() {
                _triggeringWidgetKey.currentState!.setState(() {});
              });
            });
          });
        },
        onLoad: (type, slot){
          _scriptRunner.loadSaveData(type, slot);
          _switchTriggerWidget(null);
        },
      );
      return;
    }
    if(_triggeringText== GameText.MENU_BACK_LOG){
      _triggeringWidget= BackLog(
        backlogItems: _scriptRunner.buildBackLog(),
        onJump: (backLogItem){
          _scriptRunner.goBackFromBackLog(backLogItem);
          _switchTriggerWidget(null);
        },
      );
      return;
    }
    if(_triggeringText== GameText.MENU_CONFIG){
      _triggeringWidget= ConfigWidget();
      return;
    }
    _triggeringWidget= null;
  }

  void displayMenu([String? triggerWidgetName]){
    if(_scriptRunner.haveRunFlag(ScriptRunFlag.SKIP_MAX)){
      return;
    }
    if(_scriptRunner.isProcessingCommand()){
      if(_scriptRunner.haveRunFlag(ScriptRunFlag.SKIP_READ)){
        _doAppCommand(MyAppCmd.SWITCH_SKIP_READ, switchOn: false);
      }else if(_scriptRunner.haveRunFlag(ScriptRunFlag.SKIP_ALL)){
        _doAppCommand(MyAppCmd.SWITCH_SKIP_ALL, switchOn: false);
      }else if(!(_textContainerKey.currentState as _TextContainerState)._choiceWidget.haveChoice()
          && !_scriptRunner.haveRunFlag(ScriptRunFlag.AUTO)) {
        return;
      }
    }
    setState(() {
      _menuOpacity= 1;
      if(triggerWidgetName!= null){
        _triggeringText= triggerWidgetName;
      }
      _triggerWidget();
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget triggerWidgetBound= Expanded(
      flex: 4,
      child: IgnorePointer(
        ignoring: _menuOpacity== 0,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: GameConstant.GAME_MENU_SWITCH_TIME),
          child: _triggeringWidget,
        ),
      ),
    );
    //duration: const Duration(milliseconds: GameConstant.GAME_MENU_SWITCH_TIME),
    return Stack(
      children: [
        if(_triggeringText.length== 0 && _menuOpacity== 1) GestureDetector(
          child: Container(color: Colors.transparent),
          onTap: () => _switchTriggerWidget(null),
        ),
        Row(
            children: [
              if(UserConfig.getAlign(UserConfig.MENU_ALIGNMENT)== Alignment.topRight) triggerWidgetBound,
              Expanded(
                flex: 1,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: GameConstant.GAME_MENU_SWITCH_TIME),
                  child: _menuOpacity== 0 ? GestureDetector(
                    onTap: () => displayMenu(),
                    child: Container(color: Colors.transparent),
                  ) : Container(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                    ),
                    child: ListView(
                      padding: EdgeInsets.only(top: 20, bottom: 20),
                      children: [
                        SizedBox(
                          height: 35,
                          child: Row(
                            children: [
                              if(UserConfig.getAlign(UserConfig.MENU_ALIGNMENT)== Alignment.topRight) Expanded(child: Container(color: Colors.transparent,)),
                              AspectRatio(
                                aspectRatio: 1,
                                child: GestureDetector(
                                  child: Container(
                                      color: Colors.blueGrey,
                                      child: Icon(Icons.close, color: Colors.white, size: 30,)
                                  ),
                                  onTap: (){
                                    _switchTriggerWidget(null);
                                  },
                                ),
                              ),
                              if(UserConfig.getAlign(UserConfig.MENU_ALIGNMENT)== Alignment.topLeft) Expanded(child: Container(color: Colors.transparent,)),
                            ],
                          ),
                        ),
                        //WidgetHelper.getMenuButton(GameText.MENU_TRIGGER_AUTO,
                        //    _scriptRunner.haveRunFlag(ScriptRunFlag.AUTO), () {
                        //  _doAppCommand(MyAppCmd.SWITCH_AUTO_READ);
                        //  _switchTriggerWidget(null);
                        //}),
                        //WidgetHelper.getMenuButton(GameText.MENU_TRIGGER_SKIP_READ,
                        //    _scriptRunner.haveRunFlag(ScriptRunFlag.SKIP_READ), () {
                        //  _doAppCommand(MyAppCmd.SWITCH_SKIP_READ);
                        //  _switchTriggerWidget(null);
                        //}),
                        //WidgetHelper.getMenuButton(GameText.MENU_TRIGGER_SKIP_ALL,
                        //    _scriptRunner.haveRunFlag(ScriptRunFlag.SKIP_ALL), () {
                        //  _doAppCommand(MyAppCmd.SWITCH_SKIP_ALL);
                        //  _switchTriggerWidget(null);
                        //}),
                        WidgetHelper.getMenuButton(GameText.MENU_CONFIG,
                            _triggeringText== GameText.MENU_CONFIG, () {
                          _switchTriggerWidget(GameText.MENU_CONFIG);
                        }),
                        WidgetHelper.getMenuButton(GameText.MENU_SAVE_AND_LOAD,
                            _triggeringText== GameText.MENU_SAVE_AND_LOAD, () {
                          _switchTriggerWidget(GameText.MENU_SAVE_AND_LOAD);
                        }),
                        WidgetHelper.getMenuButton(GameText.MENU_BACK_LOG,
                            _triggeringText== GameText.MENU_BACK_LOG, () {
                          _switchTriggerWidget(GameText.MENU_BACK_LOG);
                        }),
                        WidgetHelper.getMenuButton(GameText.MENU_HIDE_TEXT_BOX,
                            false, () {
                          _doAppCommand(MyAppCmd.HIDE_TEXT_BOX);
                          _switchTriggerWidget(null);
                        }),
                        WidgetHelper.getMenuButton("＜ ー ＞",
                            false, () {
                              UserConfig.save(UserConfig.MENU_ALIGNMENT,
                                  UserConfig.getAlign(UserConfig.MENU_ALIGNMENT)== Alignment.topRight
                                      ? Alignment.topLeft.toString() : Alignment.topRight.toString());
                              setState(() {});
                            }),
                        WidgetHelper.getMenuButton(GameText.MENU_EXIT_TO_TITLE,
                            false, () {
                              _doAppCommand(MyAppCmd.BACK_TO_TITLE);
                              _switchTriggerWidget(null);
                            }),
                        WidgetHelper.getMenuButton(GameText.MENU_QUIT,
                            false, () {
                              _scriptRunner.userSave(GameSaveType.CURRENT, "").whenComplete(() {
                                AudioHelper.disposeAllAudio().whenComplete(() {
                                  Navigator.pop(context);
                                });
                              });
                            }),
                        //RaisedButton(
                        //  child: Text("Clock"),
                        //  textColor: Colors.white,
                        //  color: Colors.blueGrey,
                        //  onPressed: () {
                        //  },
                        //),
                      ],
                    ),
                  ),
                ),
              ),
              if(UserConfig.getAlign(UserConfig.MENU_ALIGNMENT)== Alignment.topLeft) triggerWidgetBound,
            ]
        ),
      ],
    );
  }
}

class OverlayContainer extends StatefulWidget {
  OverlayContainer({Key? key}) : super(key: key);

  @override
  _OverlayContainerState createState() => _OverlayContainerState();
}

class _OverlayContainerState extends State<OverlayContainer> {
  String? _toast;
  String? _popUp;
  String? _dialog;
  Function()? _onDialogOk;

  void showToast(String content){
    setState(() {
      _toast= content;
    });
    Timer(Duration(milliseconds: 1500), (){
      setState(() {
        _toast= null;
      });
    });
  }

  void popUp(String content){
    setState(() {
      _popUp= content;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget? toAnimate;
    if(_toast!= null){
      toAnimate= Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          color: Color(0xFF383737),
        ),
        child: Center(child: Text(_toast!),),
      );
    }
    if(_popUp!= null){
      toAnimate= AlertDialog(
        backgroundColor: Color(0xFF383737),
        content: TextProcessor.simpleRichText(_popUp!),
        actions: [
          TextButton(
              onPressed: (){
                setState(() {
                  _popUp= null;
                });
              },
              child: Text("OK")
          )
        ],
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: toAnimate== null ? null : Container(
        color: Colors.black38,
        child: toAnimate,
      ),
    );
  }
}
