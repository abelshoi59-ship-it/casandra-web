import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// A single turn in the assistant conversation.
class AiMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  const AiMessage(this.role, this.content);

  Map<String, String> toJson() => {'role': role, 'content': content};
}

/// Talks to the `aiAssistantStream` Cloud Function and yields text deltas as
/// they arrive (SSE). The Anthropic API key lives only in the function.
class AiAssistantRepository {
  AiAssistantRepository({http.Client? client, FirebaseAuth? auth})
      : _client = client ?? http.Client(),
        _auth = auth ?? FirebaseAuth.instance;

  final http.Client _client;
  final FirebaseAuth _auth;

  // TODO: replace with your deployed function URL.
  static const _functionUrl =
      'https://<region>-<project>.cloudfunctions.net/aiAssistantStream';

  /// Streams assistant text deltas for the given conversation [history]
  /// (which must already include the latest user message).
  Stream<String> sendStreaming(List<AiMessage> history) async* {
    final idToken = await _auth.currentUser?.getIdToken();
    if (idToken == null) {
      throw StateError('Not signed in');
    }

    final request = http.Request('POST', Uri.parse(_functionUrl))
      ..headers['Authorization'] = 'Bearer $idToken'
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'messages': history.map((m) => m.toJson()).toList(),
      });

    final response = await _client.send(request);
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw Exception('Assistant error ${response.statusCode}: $body');
    }

    // Parse the SSE stream: lines beginning with "data: ".
    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (!line.startsWith('data: ')) continue;
      final payload = line.substring(6).trim();
      if (payload.isEmpty) continue;

      final event = jsonDecode(payload) as Map<String, dynamic>;
      switch (event['type']) {
        case 'delta':
          yield event['text'] as String;
        case 'error':
          throw Exception(event['error'] as String? ?? 'Assistant error');
        case 'done':
          return;
      }
    }
  }
}
