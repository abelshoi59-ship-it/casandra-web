import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../messaging/messaging_models.dart';

/// Real-time chat data access: room messages, presence, typing indicators.
class ChatRepository {
  ChatRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get _uid => _auth.currentUser!.uid;

  /// Newest messages first; reverse the ListView for chat order.
  Stream<List<ChatMessage>> watchMessages(String roomId, {int limit = 50}) {
    return _db
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .where('roomId', isEqualTo: roomId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(ChatMessage.fromDoc).toList());
  }

  Future<void> sendMessage(String roomId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _db.collection('rooms').doc(roomId).collection('messages').add({
      'roomId': roomId,
      'authorId': _uid,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Clear our typing flag once a message is sent.
    await setTyping(roomId, false);
  }

  /// Heartbeat presence; call on room enter and periodically.
  Future<void> setPresence(String roomId, {required bool online}) {
    return _db
        .collection('rooms')
        .doc(roomId)
        .collection('presence')
        .doc(_uid)
        .set({
      'online': online,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setTyping(String roomId, bool typing) {
    return _db
        .collection('rooms')
        .doc(roomId)
        .collection('typing')
        .doc(_uid)
        .set({
      'typing': typing,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// uids (excluding self) currently typing in the last few seconds.
  Stream<List<String>> watchTyping(String roomId) {
    return _db
        .collection('rooms')
        .doc(roomId)
        .collection('typing')
        .snapshots()
        .map((s) => s.docs
            .where((d) => d.id != _uid && (d.data()['typing'] as bool? ?? false))
            .map((d) => d.id)
            .toList());
  }
}
