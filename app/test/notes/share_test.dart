import 'dart:typed_data';

import 'package:e2ee_notes/notes/share.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const roomId = 'test-room';

  test('a recipient recovers the room key from an invitation', () async {
    final inviter = await generateShareKeys();
    final recipient = await generateShareKeys();
    final roomKey = Uint8List.fromList(
      List<int>.generate(32, (index) => index),
    );
    final sharer = RoomKeySharer();

    final invitation = await sharer.wrap(
      roomKey: roomKey,
      inviter: inviter,
      recipientPublicKey: recipient.publicKey,
      roomId: roomId,
    );

    expect(invitation.roomId, roomId);
    expect(await sharer.unwrap(invitation: invitation, recipient: recipient), roomKey);
  });

  test('another participant cannot recover the room key', () async {
    final inviter = await generateShareKeys();
    final recipient = await generateShareKeys();
    final outsider = await generateShareKeys();
    final roomKey = Uint8List(32);
    final sharer = RoomKeySharer();

    final invitation = await sharer.wrap(
      roomKey: roomKey,
      inviter: inviter,
      recipientPublicKey: recipient.publicKey,
      roomId: roomId,
    );

    await expectLater(
      sharer.unwrap(invitation: invitation, recipient: outsider),
      throwsA(anything),
    );
  });

  test('an invitation round-trips through JSON', () async {
    final inviter = await generateShareKeys();
    final recipient = await generateShareKeys();
    final roomKey = Uint8List.fromList(
      List<int>.generate(32, (index) => index),
    );
    final sharer = RoomKeySharer();

    final invitation = await sharer.wrap(
      roomKey: roomKey,
      inviter: inviter,
      recipientPublicKey: recipient.publicKey,
      roomId: roomId,
    );

    final restored = RoomInvitation.fromJson(invitation.toJson());
    expect(await sharer.unwrap(invitation: restored, recipient: recipient), roomKey);
  });
}
