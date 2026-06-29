import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../messaging/messaging_models.dart';

/// Async forum data access: boards, threads, posts.
class ForumRepository {
  ForumRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get _uid => _auth.currentUser!.uid;

  Stream<List<Board>> watchBoards() {
    return _db.collection('boards').orderBy('title').snapshots().map(
          (s) => s.docs.map(Board.fromDoc).toList(),
        );
  }

  Stream<List<Thread>> watchThreads(String boardId) {
    return _db
        .collection('boards')
        .doc(boardId)
        .collection('threads')
        .where('boardId', isEqualTo: boardId)
        .orderBy('lastActivityAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Thread.fromDoc).toList());
  }

  Stream<List<Post>> watchPosts(String boardId, String threadId) {
    return _db
        .collection('boards')
        .doc(boardId)
        .collection('threads')
        .doc(threadId)
        .collection('posts')
        .where('threadId', isEqualTo: threadId)
        .orderBy('createdAt')
        .snapshots()
        .map((s) => s.docs.map(Post.fromDoc).toList());
  }

  /// Creates a thread plus its first post in a single batch.
  Future<String> createThread({
    required String boardId,
    required String title,
    required String firstPostBody,
  }) async {
    final now = FieldValue.serverTimestamp();
    final threadRef = _db
        .collection('boards')
        .doc(boardId)
        .collection('threads')
        .doc();
    final postRef = threadRef.collection('posts').doc();

    final batch = _db.batch();
    batch.set(threadRef, {
      'boardId': boardId,
      'title': title,
      'authorId': _uid,
      'createdAt': now,
      'lastActivityAt': now,
      'postCount': 1,
    });
    batch.set(postRef, {
      'threadId': threadRef.id,
      'authorId': _uid,
      'body': firstPostBody,
      'createdAt': now,
    });
    await batch.commit();
    return threadRef.id;
  }

  Future<void> addPost({
    required String boardId,
    required String threadId,
    required String body,
  }) async {
    final threadRef = _db
        .collection('boards')
        .doc(boardId)
        .collection('threads')
        .doc(threadId);

    final batch = _db.batch();
    batch.set(threadRef.collection('posts').doc(), {
      'threadId': threadId,
      'authorId': _uid,
      'body': body,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(threadRef, {
      'lastActivityAt': FieldValue.serverTimestamp(),
      'postCount': FieldValue.increment(1),
    });
    await batch.commit();
  }
}
