import 'package:flutter/material.dart';

import 'ai_assistant_repository.dart';

/// Minimal streaming chat UI for the Casandra AI assistant.
/// Wire into your router; swap the plain setState for your app's state mgmt.
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key, this.repository});

  final AiAssistantRepository? repository;

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  late final AiAssistantRepository _repo =
      widget.repository ?? AiAssistantRepository();
  final _controller = TextEditingController();
  final List<AiMessage> _history = [];
  bool _sending = false;

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    _controller.clear();

    setState(() {
      _history.add(AiMessage('user', text));
      _history.add(const AiMessage('assistant', '')); // streaming placeholder
      _sending = true;
    });

    final assistantIndex = _history.length - 1;
    final buffer = StringBuffer();
    try {
      // Send everything except the empty placeholder.
      await for (final delta
          in _repo.sendStreaming(_history.sublist(0, assistantIndex))) {
        buffer.write(delta);
        setState(() {
          _history[assistantIndex] = AiMessage('assistant', buffer.toString());
        });
      }
    } catch (e) {
      setState(() {
        _history[assistantIndex] = AiMessage('assistant', '⚠️ $e');
      });
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Casandra Assistant')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _history.length,
              itemBuilder: (context, i) {
                final m = _history[i];
                final isUser = m.role == 'user';
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(m.content.isEmpty ? '…' : m.content),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask about your car…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sending ? null : _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
