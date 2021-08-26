import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'com_cons.dart';
import 'dart:math' as Math;

import 'script_runner.dart';

class ListDoubleTween extends Tween<List<double?>> {
  ListDoubleTween(List<double?> begin, List<double?> end ) : super(begin: begin, end: end);

  @override
  List<double?> lerp(double t) {
    List<double?> ret= <double?>[];
    for(int i= 0; i< Math.min(begin!.length, end!.length); i++){
      if(begin![i]== null || end![i]== null){
        ret.add(null);
      }else{
        ret.add(begin![i]! * (1.0 - t) + end![i]! * t);
      }
    }

    return ret;
  }
}

//ListNoneNullDoubleTween
class ListNNDoubleTween extends Tween<List<double>> {
  ListNNDoubleTween(List<double> begin, List<double> end ) : super(begin: begin, end: end);

  @override
  List<double> lerp(double t) {
    List<double> ret= <double>[];
    for(int i= 0; i< Math.min(begin!.length, end!.length); i++){
      ret.add(begin![i] * (1.0 - t) + end![i] * t);
    }

    return ret;
  }
}

class ImageHelper {
  static const double DEFAULT_COLOR= 0x00000000;
  static const String DEFAULT_MATRIX_STR= "1.0,0.0,0.0,0.0,0,0.0,1.0,0.0,0.0,0,0.0,0.0,1.0,0.0,0,0.0,0.0,0.0,1.0,0";
  static Future<ui.Image> getFileUiImage(String imagePath, int width, int height) {
    Completer<ui.Image> completer = new Completer<ui.Image>();
    ResizeImage resizeImage = ResizeImage(
      FileImage(File(imagePath)),
      width: width,
      height: height,
    );
    resizeImage.resolve(new ImageConfiguration())
        .addListener(ImageStreamListener((ImageInfo info, bool _) {
      completer.complete(info.image);
    }));
    //new AssetImage(imageAssetPath)
    //    .resolve(new ImageConfiguration(devicePixelRatio: 50))
    //    .addListener(ImageStreamListener((ImageInfo info, bool _) {
    //  completer.complete(info.image);
    //}));
    return completer.future;
  }

  static Gradient getGradientByName([String? name, double? timeValue, List<double> param = const <double>[]]){
    if(name== null || name== "show"){
      return LinearGradient(tileMode: TileMode.clamp,
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.white,
            Colors.white,
          ]
      );
    }
    if(name.length== 0 || name== "hide"){
      return LinearGradient(tileMode: TileMode.clamp,
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.transparent,
            Colors.transparent,
          ]
      );
    }

    if(timeValue== null){
      timeValue= 0;
    }
    double animationValue;
    double stopStart;
    if(name.startsWith("center-")){
      double gradientAreaByPercent= 0.4;
      if(param.length> 0){
        gradientAreaByPercent= param[0];
      }
      animationValue= timeValue * (1+gradientAreaByPercent);
      stopStart= animationValue - gradientAreaByPercent;
      if(name== "center-cross-appear"){
        return LinearGradient(tileMode: TileMode.mirror,
            transform: GradientRotation(-Math.tan(GameConstant.GAME_ASPECT_RATIO)),
            begin: Alignment.center,
            end: Alignment(1.5, 1.5),
            stops: [
              0,
              stopStart < 0 ? 0 : stopStart,
              animationValue > 1 ? 1 : animationValue,
              1,
            ],
            colors: [
              Colors.white,
              Colors.white,
              Colors.transparent,
              Colors.transparent,
            ]
        );
      }
      if(name== "center-cross-disappear"){
        return LinearGradient(tileMode: TileMode.mirror,
            transform: GradientRotation(-Math.tan(GameConstant.GAME_ASPECT_RATIO)),
            begin: Alignment(1.5, 1.5),
            end: Alignment.center,
            stops: [
              0,
              stopStart < 0 ? 0 : stopStart,
              animationValue > 1 ? 1 : animationValue,
              1,
            ],
            colors: [
              Colors.transparent,
              Colors.transparent,
              Colors.white,
              Colors.white,
            ]
        );
      }
      if(name== "center-vertical-appear"){
        return LinearGradient(tileMode: TileMode.mirror,
            begin: Alignment.center,
            end: Alignment.centerLeft,
            stops: [
              0,
              stopStart < 0 ? 0 : stopStart,
              animationValue > 1 ? 1 : animationValue,
              1,
            ],
            colors: [
              Colors.white,
              Colors.white,
              Colors.transparent,
              Colors.transparent,
            ]
        );
      }
      if(name== "center-vertical-disappear"){
        return LinearGradient(tileMode: TileMode.mirror,
            begin: Alignment.center,
            end: Alignment.centerLeft,
            stops: [
              0,
              stopStart < 0 ? 0 : stopStart,
              animationValue > 1 ? 1 : animationValue,
              1,
            ],
            colors: [
              Colors.transparent,
              Colors.transparent,
              Colors.white,
              Colors.white,
            ]
        );
      }
      if(name== "center-horizontal-appear"){
        return LinearGradient(tileMode: TileMode.mirror,
            begin: Alignment.topCenter,
            end: Alignment.center,
            stops: [
              0,
              stopStart < 0 ? 0 : stopStart,
              animationValue > 1 ? 1 : animationValue,
              1,
            ],
            colors: [
              Colors.white,
              Colors.white,
              Colors.transparent,
              Colors.transparent,
            ]
        );
      }
      if(name== "center-horizontal-disappear"){
        return LinearGradient(tileMode: TileMode.mirror,
            begin: Alignment.center,
            end: Alignment.topCenter,
            stops: [
              0,
              stopStart < 0 ? 0 : stopStart,
              animationValue > 1 ? 1 : animationValue,
              1,
            ],
            colors: [
              Colors.transparent,
              Colors.transparent,
              Colors.white,
              Colors.white,
            ]
        );
      }
    }

    if(name.startsWith("curtain-")){
      double gradientAreaByPercent= 0.4;
      double curtainCount= 16;
      if(param.length> 0){
        gradientAreaByPercent= param[1];
        if(param.length> 1){
          curtainCount= param[0];
        }
      }
      animationValue= timeValue * (1+gradientAreaByPercent);
      stopStart= animationValue - gradientAreaByPercent;
      if(name== "curtain-soft-appear"){
        return LinearGradient(tileMode: TileMode.repeated,
            begin: Alignment.center,
            end: Alignment(2/ curtainCount, 0.0),
            stops: [
              0,
              stopStart < 0 ? 0 : stopStart,
              animationValue > 1 ? 1 : animationValue,
              1,
            ],
            colors: [
              Colors.white,
              Colors.white,
              Colors.transparent,
              Colors.transparent,
            ]
        );
      }
      if(name== "curtain-soft-disappear"){
        return LinearGradient(tileMode: TileMode.repeated,
            begin: Alignment.center,
            end: Alignment(2/ curtainCount, 0.0),
            stops: [
              0,
              stopStart < 0 ? 0 : stopStart,
              animationValue > 1 ? 1 : animationValue,
              1,
            ],
            colors: [
              Colors.transparent,
              Colors.transparent,
              Colors.white,
              Colors.white,
            ]
        );
      }
    }

    if(name.startsWith("linear-")){
      double gradientAreaByPercent= 0.4;
      if(param.length> 0){
        gradientAreaByPercent= param[0];
      }
      animationValue= timeValue * (1+gradientAreaByPercent);
      stopStart= animationValue - gradientAreaByPercent;
      if(name== "linear-left-appear"){
        return LinearGradient(tileMode: TileMode.clamp,
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            stops: [
              0,
              stopStart < 0 ? 0 : stopStart,
              animationValue > 1 ? 1 : animationValue,
              1,
            ],
            colors: [
              Colors.white,
              Colors.white,
              Colors.transparent,
              Colors.transparent,
            ]
        );
      }
      if(name== "linear-left-disappear"){
        return LinearGradient(tileMode: TileMode.clamp,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: [
              0,
              stopStart < 0 ? 0 : stopStart,
              animationValue > 1 ? 1 : animationValue,
              1,
            ],
            colors: [
              Colors.transparent,
              Colors.transparent,
              Colors.white,
              Colors.white,
            ]
        );
      }
      if(name== "linear-right-appear"){
        return LinearGradient(tileMode: TileMode.clamp,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: [
              0,
              stopStart < 0 ? 0 : stopStart,
              animationValue > 1 ? 1 : animationValue,
              1,
            ],
            colors: [
              Colors.white,
              Colors.white,
              Colors.transparent,
              Colors.transparent,
            ]
        );
      }
      if(name== "linear-right-disappear"){
        return LinearGradient(tileMode: TileMode.clamp,
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            stops: [
              0,
              stopStart < 0 ? 0 : stopStart,
              animationValue > 1 ? 1 : animationValue,
              1,
            ],
            colors: [
              Colors.transparent,
              Colors.transparent,
              Colors.white,
              Colors.white,
            ]
        );
      }
      if(name== "linear-top-appear"){
        return LinearGradient(tileMode: TileMode.clamp,
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            stops: [
              0,
              stopStart < 0 ? 0 : stopStart,
              animationValue > 1 ? 1 : animationValue,
              1,
            ],
            colors: [
              Colors.white,
              Colors.white,
              Colors.transparent,
              Colors.transparent,
            ]
        );
      }
      if(name== "linear-top-disappear"){
        return LinearGradient(tileMode: TileMode.clamp,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [
              0,
              stopStart < 0 ? 0 : stopStart,
              animationValue > 1 ? 1 : animationValue,
              1,
            ],
            colors: [
              Colors.transparent,
              Colors.transparent,
              Colors.white,
              Colors.white,
            ]
        );
      }
      if(name== "linear-bottom-appear"){
        return LinearGradient(tileMode: TileMode.clamp,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [
              0,
              stopStart < 0 ? 0 : stopStart,
              animationValue > 1 ? 1 : animationValue,
              1,
            ],
            colors: [
              Colors.white,
              Colors.white,
              Colors.transparent,
              Colors.transparent,
            ]
        );
      }
      if(name== "linear-bottom-disappear"){
        return LinearGradient(tileMode: TileMode.clamp,
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            stops: [
              0,
              stopStart < 0 ? 0 : stopStart,
              animationValue > 1 ? 1 : animationValue,
              1,
            ],
            colors: [
              Colors.transparent,
              Colors.transparent,
              Colors.white,
              Colors.white,
            ]
        );
      }
    }
    if(name.startsWith("radial-")){
      double gradientAreaByPercent= 0.4;
      if(param.length> 0){
        gradientAreaByPercent= param[0];
      }
      animationValue= timeValue * (1+gradientAreaByPercent);
      stopStart= animationValue - gradientAreaByPercent;
      if(name== "radial-appear"){
        return RadialGradient(tileMode: TileMode.clamp,
            radius: 1.5,
            stops: [
              0,
              stopStart < 0 ? 0 : stopStart,
              animationValue > 1 ? 1 : animationValue,
              1,
            ],
            colors: [
              Colors.white,
              Colors.white,
              Colors.transparent,
              Colors.transparent,
            ]
        );
      }
      if(name== "radial-disappear"){
        return RadialGradient(tileMode: TileMode.clamp,
            radius: 1.5,
            stops: [
              0,
              stopStart < 0 ? 0 : stopStart,
              animationValue > 1 ? 1 : animationValue,
              1,
            ],
            colors: [
              Colors.transparent,
              Colors.transparent,
              Colors.white,
              Colors.white,
            ]
        );
      }
      if(name== "radial-mirror-appear"){
        return RadialGradient(tileMode: TileMode.mirror,
            radius: 0.06,
            stops: [
              0,
              stopStart < 0 ? 0 : stopStart,
              animationValue > 1 ? 1 : animationValue,
              1,
            ],
            colors: [
              Colors.white,
              Colors.white,
              Colors.transparent,
              Colors.transparent,
            ]
        );
      }
    }
    if(name.startsWith("sweep-")){
      double gradientAreaByPercent= 0.1;
      if(param.length> 0){
        gradientAreaByPercent= param[0];
      }
      animationValue= timeValue * (1+gradientAreaByPercent);
      stopStart= animationValue - gradientAreaByPercent;
      if(name== "sweep-appear"){
        return SweepGradient(
            tileMode: TileMode.clamp,
            transform: GradientRotation(3 * Math.pi/ 2),
            stops: [
              0,
              stopStart < 0 ? 0 : stopStart,
              animationValue > 1 ? 1 : animationValue,
              1,
            ],
            colors: [
              Colors.white,
              Colors.white,
              Colors.transparent,
              Colors.transparent,
            ]
        );
      }
      if(name== "sweep-disappear"){
        return SweepGradient(
            tileMode: TileMode.clamp,
            transform: GradientRotation(3 * Math.pi/ 2),
            stops: [
              0,
              stopStart < 0 ? 0 : stopStart,
              animationValue > 1 ? 1 : animationValue,
              1,
            ],
            colors: [
              Colors.transparent,
              Colors.transparent,
              Colors.white,
              Colors.white,
            ]
        );
      }
    }
    if(name== "cinema-appear"){
      double gradientAreaByPercent= 0.1;
      if(param.length> 0){
        gradientAreaByPercent= param[0];
      }
      animationValue= timeValue * (1+gradientAreaByPercent);
      stopStart= (animationValue - gradientAreaByPercent)/ 2;
      animationValue/= 2;
      return SweepGradient(
          tileMode: TileMode.clamp,
          stops: [
            0,
            stopStart < 0 ? 0 : stopStart,
            animationValue > 0.5 ? 0.5 : animationValue,
            0.5,
            0.5,
            stopStart + 0.5 < 0.5 ? 0.5 : stopStart + 0.5,
            animationValue + 0.5 > 1 ? 1 : animationValue + 0.5,
            1,
          ],
          colors: [
            Colors.white,
            Colors.white,
            Colors.transparent,
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
            Colors.transparent,
          ]
      );
    }
    return LinearGradient(tileMode: TileMode.clamp,
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Colors.white,
          Colors.white,
        ]
    );
  }

  static Curve getCurveFromParam(String? curve, String? cubic){
    Curve ret= Curves.linear;
    if(curve!= null){
      ret= ImageHelper.getCurveByName(curve);
    }
    if(cubic!= null){
      ret= ImageHelper.getCurveByCubic(cubic);
    }
    return ret;
  }

  static Curve getCurveByCubic(String stringParams){
    List<double> param= stringParams.split(
        ScriptCommandInfo.PARAM_IN_VALUE_COMMAND_SEPARATOR).map(
            (s) => double.parse(s)).toList();
    return Cubic(param[0], param[1], param[2], param[3]);
  }

  static Curve getCurveByName(String? name){
    if(name== null || name.length== 0){
      return Curves.linear;
    }
    String lowName= name.trim().toLowerCase();
    if("linear"== lowName){return Curves.linear;}
    if("decelerate"== lowName){return Curves.decelerate;}
    if("fastlineartosloweasein"== lowName){return Curves.fastLinearToSlowEaseIn;}
    if("ease"== lowName){return Curves.ease;}
    if("easein"== lowName){return Curves.easeIn;}
    if("easeintolinear"== lowName){return Curves.easeInToLinear;}
    if("easeinsine"== lowName){return Curves.easeInSine;}
    if("easeinquad"== lowName){return Curves.easeInQuad;}
    if("easeincubic"== lowName){return Curves.easeInCubic;}
    if("easeinquart"== lowName){return Curves.easeInQuart;}
    if("easeinquint"== lowName){return Curves.easeInQuint;}
    if("easeinexpo"== lowName){return Curves.easeInExpo;}
    if("easeincirc"== lowName){return Curves.easeInCirc;}
    if("easeinback"== lowName){return Curves.easeInBack;}
    if("easeout"== lowName){return Curves.easeOut;}
    if("lineartoeaseout"== lowName){return Curves.linearToEaseOut;}
    if("easeoutsine"== lowName){return Curves.easeOutSine;}
    if("easeoutquad"== lowName){return Curves.easeOutQuad;}
    if("easeoutcubic"== lowName){return Curves.easeOutCubic;}
    if("easeoutquart"== lowName){return Curves.easeOutQuart;}
    if("easeoutquint"== lowName){return Curves.easeOutQuint;}
    if("easeoutexpo"== lowName){return Curves.easeOutExpo;}
    if("easeoutcirc"== lowName){return Curves.easeOutCirc;}
    if("easeoutback"== lowName){return Curves.easeOutBack;}
    if("easeinout"== lowName){return Curves.easeInOut;}
    if("easeinoutsine"== lowName){return Curves.easeInOutSine;}
    if("easeinoutcubic"== lowName){return Curves.easeInOutCubic;}
    if("easeinoutquad"== lowName){return Curves.easeInOutQuad;}
    if("easeinoutquint"== lowName){return Curves.easeInOutQuint;}
    if("easeinoutexpo"== lowName){return Curves.easeInOutExpo;}
    if("easeinoutcirc"== lowName){return Curves.easeInOutCirc;}
    if("easeinoutback"== lowName){return Curves.easeInOutBack;}
    if("fastoutslowin"== lowName){return Curves.fastOutSlowIn;}
    if("slowmiddle"== lowName){return Curves.slowMiddle;}
    if("bouncein"== lowName){return Curves.bounceIn;}
    if("bounceout"== lowName){return Curves.bounceOut;}
    if("bounceinout"== lowName){return Curves.bounceInOut;}
    if("elasticin"== lowName){return Curves.elasticIn;}
    if("elasticout"== lowName){return Curves.elasticOut;}
    if("elasticinout"== lowName){return Curves.elasticInOut;}
    return Curves.linear;
  }


}