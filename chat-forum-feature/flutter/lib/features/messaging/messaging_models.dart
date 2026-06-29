import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared data models for the hybrid forum + chat.
///
/// Forum side:  Board -> Thread -> Post   (async, persistent)
/// Chat side:   Room  -> Message + Presence (real-time)

class Board {
  final String id;
  final String title;
  final String description;

  const Board({required this.id, required this.title, required this.description});

  factory Board.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Board(
      id: doc.id,
      title: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
    );
  }
}

class Thread {
  final String id;
  final String boardId;
  final String title;
  final String authorId;
  final DateTime createdAt;
  final DateTime lastActivityAt;
  final int postCount;

  const Thread({
    required this.id,
    required this.boardId,
    required this.title,
    required this.authorId,
    required this.createdAt,
    required this.lastActivityAt,
    required this.postCount,
  });

  factory Thread.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Thread(
      id: doc.id,
      boardId: d['boardId'] as String? ?? '',
      title: d['title'] as String? ?? '',
      authorId: d['authorId'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActivityAt:
          (d['lastActivityAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      postCount: d['postCount'] as int? ?? 0,
    );
  }
}

class Post {
  final String id;
  final String threadId;
  final String authorId;
  final String body;
  final DateTime createdAt;

  const Post({
    required this.id,
    required this.threadId,
    required this.authorId,
    required this.body,
    required this.createdAt,
  });

  factory Post.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Post(
      id: doc.id,
      threadId: d['threadId'] as String? ?? '',
      authorId: d['authorId'] as String? ?? '',
      body: d['body'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class ChatMessage {
  final String id;
  final String roomId;
  final String authorId;
  final String text;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.authorId,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return ChatMessage(
      id: doc.id,
      roomId: d['roomId'] as String? ?? '',
      authorId: d['authorId'] as String? ?? '',
      text: d['text'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
