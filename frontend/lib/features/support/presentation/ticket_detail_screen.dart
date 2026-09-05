import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/support_models.dart';
import '../data/support_repository.dart';
import '../providers/support_provider.dart';

class TicketDetailScreen extends ConsumerWidget {
  final String ticketId;

  const TicketDetailScreen({required this.ticketId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(ticketMessagesProvider(ticketId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket Details'),
      ),
      body: messagesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load messages: $e')),
        data: (messages) => _TicketConversationView(
          ticketId: ticketId,
          messages: messages,
        ),
      ),
    );
  }
}

class _TicketConversationView extends ConsumerStatefulWidget {
  final String ticketId;
  final List<SupportMessage> messages;

  const _TicketConversationView({
    required this.ticketId,
    required this.messages,
  });

  @override
  ConsumerState<_TicketConversationView> createState() => _TicketConversationViewState();
}

class _TicketConversationViewState extends ConsumerState<_TicketConversationView> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void didUpdateWidget(covariant _TicketConversationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length > oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Messages list
        Expanded(
          child: widget.messages.isEmpty
              ? Center(
                  child: Text('No messages yet. Send a message to get started.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.messages.length,
                  itemBuilder: (context, index) => _MessageBubble(
                    message: widget.messages[index],
                    isOwn: widget.messages[index].senderId == 'current-user',
                  ),
                ),
        ),

        // Input
        Container(
          padding: EdgeInsets.only(
            left: 12, right: 12, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type your message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                  maxLines: 3,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _sending ? null : (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sending ? null : _sendMessage,
                icon: _sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    _messageController.clear();

    try {
      await ref.read(supportRepositoryProvider).replyToTicket(widget.ticketId, text);
      // Refresh messages
      ref.invalidate(ticketMessagesProvider(widget.ticketId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _MessageBubble extends StatelessWidget {
  final SupportMessage message;
  final bool isOwn;

  const _MessageBubble({required this.message, required this.isOwn});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Sender name
          Padding(
            padding: EdgeInsets.only(left: isOwn ? 0 : 16, right: isOwn ? 16 : 0, bottom: 2),
            child: Text(
              message.senderName,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: message.isAdminReply ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          // Bubble
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: message.isAdminReply
                  ? theme.colorScheme.primaryContainer
                  : isOwn
                      ? theme.colorScheme.secondaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isOwn ? 16 : 4),
                bottomRight: Radius.circular(isOwn ? 4 : 16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.message,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
