// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'storage_helper.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************
//F:\phan_mem\flutter\bin\flutter packages pub run build_runner build
//F:\phan_mem\flutter\bin\flutter doctor -v
//F:\phan_mem\flutter\bin\flutter build apk --release -t lib/splash.dart
class SingleSaveInfoAdapter extends TypeAdapter<SingleSaveInfo> {
  @override
  final int typeId = 1;

  @override
  SingleSaveInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SingleSaveInfo()
      .._type = fields[0] as int
      .._note = fields[1] as String
      .._scriptsStack = fields[3] as String
      .._parametersSave = (fields[4] as Map).cast<String, String>()
      .._saveScriptContent = (fields[5] as List).cast<String>();
  }

  @override
  void write(BinaryWriter writer, SingleSaveInfo obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj._type)
      ..writeByte(1)
      ..write(obj._note)
      ..writeByte(3)
      ..write(obj._scriptsStack)
      ..writeByte(4)
      ..write(obj._parametersSave)
      ..writeByte(5)
      ..write(obj._saveScriptContent);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SingleSaveInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SavesInfoAdapter extends TypeAdapter<SavesInfo> {
  @override
  final int typeId = 2;

  @override
  SavesInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SavesInfo()
      .._type = fields[0] as int
      .._slot = fields[1] as int
      .._currentScriptLine = fields[2] as int
      .._thumbPath = fields[3] as String
      .._text = fields[4] as String
      .._note = fields[5] as String
      .._dateTime = fields[6] as String
      .._singleSaveArray = (fields[7] as List).cast<SingleSaveInfo>();
  }

  @override
  void write(BinaryWriter writer, SavesInfo obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj._type)
      ..writeByte(1)
      ..write(obj._slot)
      ..writeByte(2)
      ..write(obj._currentScriptLine)
      ..writeByte(3)
      ..write(obj._thumbPath)
      ..writeByte(4)
      ..write(obj._text)
      ..writeByte(5)
      ..write(obj._note)
      ..writeByte(6)
      ..write(obj._dateTime)
      ..writeByte(7)
      ..write(obj._singleSaveArray);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavesInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
