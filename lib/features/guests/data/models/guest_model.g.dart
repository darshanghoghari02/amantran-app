// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guest_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GuestModelAdapter extends TypeAdapter<GuestModel> {
  @override
  final int typeId = 1;

  @override
  GuestModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GuestModel(
      id: fields[0] as String,
      name: fields[1] as String,
      phone: fields[2] as String,
      familySide: fields[3] as FamilySide,
      rsvpStatus: fields[4] as RsvpStatus,
      addedAt: fields[5] as DateTime?,
      notes: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, GuestModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.phone)
      ..writeByte(3)
      ..write(obj.familySide)
      ..writeByte(4)
      ..write(obj.rsvpStatus)
      ..writeByte(5)
      ..write(obj.addedAt)
      ..writeByte(6)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GuestModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FamilySideAdapter extends TypeAdapter<FamilySide> {
  @override
  final int typeId = 2;

  @override
  FamilySide read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return FamilySide.bride;
      case 1:
        return FamilySide.groom;
      case 2:
        return FamilySide.common;
      case 3:
        return FamilySide.unassigned;
      default:
        return FamilySide.bride;
    }
  }

  @override
  void write(BinaryWriter writer, FamilySide obj) {
    switch (obj) {
      case FamilySide.bride:
        writer.writeByte(0);
        break;
      case FamilySide.groom:
        writer.writeByte(1);
        break;
      case FamilySide.common:
        writer.writeByte(2);
        break;
      case FamilySide.unassigned:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FamilySideAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RsvpStatusAdapter extends TypeAdapter<RsvpStatus> {
  @override
  final int typeId = 3;

  @override
  RsvpStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return RsvpStatus.pending;
      case 1:
        return RsvpStatus.confirmed;
      case 2:
        return RsvpStatus.declined;
      default:
        return RsvpStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, RsvpStatus obj) {
    switch (obj) {
      case RsvpStatus.pending:
        writer.writeByte(0);
        break;
      case RsvpStatus.confirmed:
        writer.writeByte(1);
        break;
      case RsvpStatus.declined:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RsvpStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
