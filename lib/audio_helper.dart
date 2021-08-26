import 'dart:async';
import 'dart:collection';

import 'package:audioplayers/audioplayers.dart';
import 'script_runner.dart';
import 'storage_helper.dart';

class AudioPlayerWithVolume{
  AudioPlayer _audioPlayer;
  String _rawPath;
  double _saveVolume;

  AudioPlayerWithVolume(this._audioPlayer, this._rawPath, this._saveVolume);

  void tempChangeVolume(double percent){
    _audioPlayer.setVolume(_saveVolume* percent);
  }

  void reConfigVolume(double newValue){
    _saveVolume= newValue;
    _audioPlayer.setVolume(_saveVolume);
  }

  AudioPlayer get audioPlayer => _audioPlayer;
  double get saveVolume => _saveVolume;
  String get rawPath => _rawPath;
}

class AudioHelper {
  static HashMap<String, AudioPlayerWithVolume> _loopAudioPlayList =
      HashMap<String, AudioPlayerWithVolume>();
  static AudioPlayer? _voicePlayer;

  static List<String> _saveString = <String>[];
  static List<String> getSaveString(){
    _buildSaveString();
    return _saveString;
  }
  static void _buildSaveString(){
    _saveString.clear();
    for(MapEntry<String, AudioPlayerWithVolume> aCommand in _loopAudioPlayList.entries){
      String commandToSave= ScriptCommand.SOUND_HEADER;
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.COMMON_NAME, aCommand.key);
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.SOUND_TYPE, ScriptCommand.SOUND_TYPE_BG);
      commandToSave+= ScriptCommandInfo.buildCommandParam(
          ScriptCommand.SOUND_PATH, aCommand.value.rawPath);
      _saveString.add(commandToSave);
    }
  }

  static bool isVoicePlaying(){
    return (_voicePlayer != null &&
        _voicePlayer!.state == PlayerState.PLAYING);
  }

  static void playBackLogVoice(List<String> listVoiceCommand){
    if(listVoiceCommand.length== 0){
      backToOldBgVolume();
      return;
    }
    if (_voicePlayer != null && _voicePlayer!.state== PlayerState.PLAYING) {
      _voicePlayer!.stop();
    }
    List<String> syncVoiceList= listVoiceCommand.removeAt(0).split(BackLogItem.SYNC_VOICE_SEPARATOR);
    int waitForComplete= syncVoiceList.length;
    downVolumeForVoice();

    for(String voicePath in syncVoiceList){
      String truePath = AssetConstant.getTruePath(AssetConstant.SOUND_VOICE_DIR + voicePath);
      if(waitForComplete== syncVoiceList.length){
        _voicePlayer= AudioPlayer();
        _voicePlayer!.onPlayerStateChanged.listen((event) {
          if(event== PlayerState.COMPLETED){
            _voicePlayer= null;
            if(waitForComplete== 0){
              Timer(Duration(milliseconds: 300), (){
                playBackLogVoice(listVoiceCommand);
              });
            }
          }
        });
        waitForComplete--;
        _voicePlayer!.play(truePath,
            isLocal: true,
            volume: UserConfig.getDouble(UserConfig.GAME_VOLUME_VOICE_COMMON) * UserConfig.getDouble(UserConfig.GAME_VOLUME_MASTER)
        );
      }else{
        AudioPlayer stackVoicePlayer= AudioPlayer();
        stackVoicePlayer.onPlayerStateChanged.listen((event) {
          if(event== PlayerState.COMPLETED){
            stackVoicePlayer.dispose();
            if(waitForComplete== 0){
              Timer(Duration(milliseconds: 300), (){
                playBackLogVoice(listVoiceCommand);
              });
            }
          }
        });
        waitForComplete--;
        stackVoicePlayer.play(truePath,
            isLocal: true,
            volume: UserConfig.getDouble(UserConfig.GAME_VOLUME_VOICE_COMMON) * UserConfig.getDouble(UserConfig.GAME_VOLUME_MASTER)
        );
      }
    }
  }

  static void stopVoice(){
    if(_voicePlayer!= null){
      _voicePlayer!.stop();
    }
    backToOldBgVolume();
  }

  static Future<void> disposeAllAudio() async {
    for(AudioPlayerWithVolume oneBgAudio in _loopAudioPlayList.values){
      await oneBgAudio.audioPlayer.dispose();
    }
    _loopAudioPlayList.clear();
    if(isVoicePlaying()){
      await _voicePlayer!.dispose();
    }
  }

  static void pauseAllAudio(){
    for(AudioPlayerWithVolume oneBgAudio in _loopAudioPlayList.values){
      oneBgAudio.audioPlayer.pause();
    }
    if(isVoicePlaying()){
      _voicePlayer!.pause();
    }
  }

  static void resumeAllAudio(){
    for(AudioPlayerWithVolume oneBgAudio in _loopAudioPlayList.values){
      oneBgAudio.audioPlayer.resume();
    }
    if(_voicePlayer != null &&
        _voicePlayer!.state == PlayerState.PAUSED){
      _voicePlayer!.resume();
    }
  }

  static bool isThisBgPlaying(ScriptCommandInfo commandInfo){
    //commandInfo.valueOf(SCRIPT_COMMAND.SOUND_TYPE) ==
    //         SCRIPT_COMMAND.SOUND_TYPE_BGM_OR_BGS &&
    return commandInfo.containKey(ScriptCommand.COMMON_NAME) &&
        commandInfo.valueOf(ScriptCommand.COMMON_NAME)!.length > 0 &&
        _loopAudioPlayList.containsKey(commandInfo.valueOf(ScriptCommand.COMMON_NAME));
  }

  static void playCommand(ScriptCommandInfo commandInfo, Function(bool) onComplete,[bool isSkip= false]){
    String soundPath= commandInfo.valueOf(ScriptCommand.SOUND_PATH)!;
    String? truePath;

    if (commandInfo.valueOf(ScriptCommand.SOUND_TYPE) ==
        ScriptCommand.SOUND_TYPE_VOICE) {
      truePath = AssetConstant.getTruePath(AssetConstant.SOUND_VOICE_DIR + soundPath);

      if(commandInfo.containKey(ScriptCommand.SOUND_TYPE_VOICE_STACK)){
        if(!isSkip){
          AudioPlayer toStackVoicePlayer= AudioPlayer();
          toStackVoicePlayer.play(truePath,
              isLocal: true,
              volume: UserConfig.getDouble(UserConfig.GAME_VOLUME_VOICE_COMMON)
                  * UserConfig.getDouble(UserConfig.GAME_VOLUME_MASTER)
          );
          toStackVoicePlayer.onPlayerCompletion.listen((event) {
            toStackVoicePlayer.dispose();
          });
        }
        onComplete(true);
        return;
      }

      if (_voicePlayer != null && _voicePlayer!.state== PlayerState.PLAYING) {
        _voicePlayer!.stop();
      }

      if(!isSkip){
        //PlayerMode.LOW_LATENCY sometime make wrong duration when play audio
        _voicePlayer= AudioPlayer();
        _voicePlayer!.onPlayerStateChanged.listen((event) {
          if(event== PlayerState.COMPLETED){
            _voicePlayer= null;
            backToOldBgVolume();
            onComplete(false);
          }
        });
        _voicePlayer!.play(truePath,
            isLocal: true,
            volume: UserConfig.getDouble(UserConfig.GAME_VOLUME_VOICE_COMMON)
                * UserConfig.getDouble(UserConfig.GAME_VOLUME_MASTER)
        );
        downVolumeForVoice();
      }

      onComplete(true);
    } else if (commandInfo.valueOf(ScriptCommand.SOUND_TYPE) == ScriptCommand.SOUND_TYPE_BG) {
      if (soundPath.length> 0){
        truePath = AssetConstant.getTruePath(AssetConstant.SOUND_BGM_BGS_DIR + soundPath);
      }

      if (_loopAudioPlayList.containsKey(commandInfo.valueOf(ScriptCommand.COMMON_NAME))) {
        //When name provided, you can play new audio path instead of this audio
        //or turn off and remove it from cache list
        _loopAudioPlayList[commandInfo.valueOf(ScriptCommand.COMMON_NAME)]!.audioPlayer.dispose();
        _loopAudioPlayList.remove(commandInfo.valueOf(ScriptCommand.COMMON_NAME));
      }
      double volume= UserConfig.getDouble(UserConfig.GAME_VOLUME_BG)
          * UserConfig.getDouble(UserConfig.GAME_VOLUME_MASTER);
      if (truePath != null) {//Play loop
        AudioPlayer bgPlayer= AudioPlayer();
        bgPlayer.setReleaseMode(ReleaseMode.LOOP);
        bgPlayer.play(truePath,
            isLocal: true,
            volume: volume,
        );

        _loopAudioPlayList.putIfAbsent(commandInfo.valueOf(ScriptCommand.COMMON_NAME)!,
                () => AudioPlayerWithVolume(bgPlayer, soundPath, volume));
      }

      onComplete(true);
    } else if (commandInfo.valueOf(ScriptCommand.SOUND_TYPE) ==
        ScriptCommand.SOUND_TYPE_SOUND_EFFECT) {
      truePath = AssetConstant.getTruePath(AssetConstant.SOUND_SOUND_EFFECT_DIR + soundPath);

      if(isSkip){
        onComplete(true);
      }else{
        AudioPlayer sePlayer= AudioPlayer();
        sePlayer.play(truePath,
            isLocal: true,
            volume: UserConfig.getDouble(UserConfig.GAME_VOLUME_SE)
                * UserConfig.getDouble(UserConfig.GAME_VOLUME_MASTER)
        );
        onComplete(true);
      }
    }
  }

  static void reConfigBgmVolume(){
    for(AudioPlayerWithVolume oneBgAudio in _loopAudioPlayList.values){
      oneBgAudio.reConfigVolume(UserConfig.getDouble(UserConfig.GAME_VOLUME_BG)
          * UserConfig.getDouble(UserConfig.GAME_VOLUME_MASTER));
    }
  }

  static void downVolumeForVoice(){
    for(AudioPlayerWithVolume oneBgAudio in _loopAudioPlayList.values){
      oneBgAudio.tempChangeVolume(0.5);
    }
  }

  static void backToOldBgVolume(){
    for(AudioPlayerWithVolume oneBgAudio in _loopAudioPlayList.values){
      oneBgAudio.tempChangeVolume(1);
    }
  }

  static void setVolume(String name, double volume) {
    if(name.length== 0){
      for(AudioPlayerWithVolume audio in _loopAudioPlayList.values){
        audio.tempChangeVolume(volume);
      }
      return;
    }
    if(!_loopAudioPlayList.containsKey(name)){
      return;
    }
    _loopAudioPlayList[name]!.tempChangeVolume(volume);
  }
}
