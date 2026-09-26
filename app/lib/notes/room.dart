import 'dart:typed_data';

/// A shareable collection of notes, identified by [id] and encrypted with [key].
///
/// A room is the unit of access control: sharing a room grants access to every
/// note in it. Currently the app exposes a single [personalRoomId]; explicit
/// room management arrives with the sharing milestone.
final class Room {
  Room({required this.id, required Uint8List key})
    : _key = Uint8List.fromList(key);

  final String id;
  final Uint8List _key;

  Uint8List get key => Uint8List.fromList(_key);
}

/// The single room that holds a vault's personal notes until room management
/// exists.
const personalRoomId = 'personal';
