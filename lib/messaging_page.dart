import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import 'app_profile.dart';
import 'chat_models.dart';
import 'chat_service.dart';

class MessagingPage extends StatefulWidget {
  const MessagingPage({
    required this.profile,
    required this.isWide,
    required this.onBack,
    super.key,
  });

  final AppProfile profile;
  final bool isWide;
  final VoidCallback onBack;

  @override
  State<MessagingPage> createState() => _MessagingPageState();
}

class _MessagingPageState extends State<MessagingPage> {
  final _service = ChatService();
  final _messageController = TextEditingController();
  final _messageScrollController = ScrollController();
  final _pendingUploads = <PendingUpload>[];
  List<ChatChannel> _channels = [];
  List<ChatMessage> _messages = [];
  List<ChatInvite> _invites = [];
  ChatChannel? _selectedChannel;
  RealtimeChannel? _messageSubscription;
  RealtimeChannel? _inviteSubscription;
  String? _errorMessage;
  bool _isLoadingChannels = true;
  bool _isLoadingMessages = false;
  bool _isSending = false;
  bool _isPickingFiles = false;
  bool _showChannelsOnMobile = true;
  int _messageLoadToken = 0;

  @override
  void initState() {
    super.initState();
    _inviteSubscription = _service.subscribeToInvites(() {
      if (mounted) unawaited(_loadInvites());
    });
    unawaited(_loadChannels());
    unawaited(_loadInvites());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageScrollController.dispose();
    unawaited(_service.removeRealtimeChannel(_messageSubscription));
    unawaited(_service.removeRealtimeChannel(_inviteSubscription));
    super.dispose();
  }

  Future<void> _loadChannels({String? preferredChannelId}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingChannels = true;
      _errorMessage = null;
    });
    try {
      final channels = await _service.loadChannels();
      if (!mounted) return;
      final nextChannel =
          channels.where((channel) {
            return channel.id == preferredChannelId;
          }).firstOrNull ??
          channels.where((channel) => channel.name == 'global').firstOrNull ??
          channels.firstOrNull;
      final previousId = _selectedChannel?.id;
      setState(() {
        _channels = channels;
        _isLoadingChannels = false;
        if (previousId == nextChannel?.id) _selectedChannel = nextChannel;
      });
      if (nextChannel == null) {
        setState(() => _selectedChannel = null);
      } else if (previousId != nextChannel.id) {
        await _selectChannel(nextChannel);
      } else {
        _selectedChannel = nextChannel;
        unawaited(_refreshMessages(nextChannel.id));
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _isLoadingChannels = false;
          _errorMessage = error.toString();
        });
      }
    }
  }

  Future<void> _loadInvites() async {
    try {
      final invites = await _service.loadPendingInvites();
      if (mounted) setState(() => _invites = invites);
    } on Exception catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    }
  }

  Future<void> _selectChannel(ChatChannel channel) async {
    setState(() {
      _selectedChannel = channel;
      _messages = [];
      _isLoadingMessages = true;
      _showChannelsOnMobile = false;
      _errorMessage = null;
    });
    await _service.removeRealtimeChannel(_messageSubscription);
    if (!mounted || _selectedChannel?.id != channel.id) return;
    _messageSubscription = _service.subscribeToChannel(
      channel.id,
      () => unawaited(_refreshMessages(channel.id)),
    );
    await _refreshMessages(channel.id);
  }

  Future<void> _refreshMessages(String channelId) async {
    if (!mounted) return;
    final request = ++_messageLoadToken;
    setState(() => _isLoadingMessages = true);
    try {
      final messages = await _service.loadMessages(channelId);
      if (!mounted ||
          request != _messageLoadToken ||
          _selectedChannel?.id != channelId) {
        return;
      }
      setState(() {
        _messages = messages;
        _isLoadingMessages = false;
        _errorMessage = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_messageScrollController.hasClients) {
          _messageScrollController.jumpTo(
            _messageScrollController.position.maxScrollExtent,
          );
        }
      });
    } on Exception catch (error) {
      if (mounted &&
          request == _messageLoadToken &&
          _selectedChannel?.id == channelId) {
        setState(() {
          _isLoadingMessages = false;
          _errorMessage = error.toString();
        });
      }
    }
  }

  Future<void> _pickFiles() async {
    setState(() {
      _isPickingFiles = true;
      _errorMessage = null;
    });
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);
      if (files.isEmpty || !mounted) return;
      if (_pendingUploads.length + files.length > 10) {
        throw const FormatException('Attach up to 10 files per message.');
      }

      final selectedFiles = <PendingUpload>[];
      for (final file in files) {
        final size = file.lengthSync() ?? await file.length();
        if (size == null || size < 1 || size > 50 * 1024 * 1024) {
          throw FormatException(
            '${file.name} is empty or larger than the 50 MB limit.',
          );
        }
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) {
          throw FormatException('${file.name} could not be read.');
        }
        selectedFiles.add(
          PendingUpload(
            name: file.name,
            bytes: bytes,
            sizeBytes: size,
            mimeType: _mimeTypeFor(file.name),
          ),
        );
      }
      if (!mounted) return;
      setState(() => _pendingUploads.addAll(selectedFiles));
    } on Exception catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isPickingFiles = false);
    }
  }

  Future<void> _sendMessage() async {
    final channel = _selectedChannel;
    if (channel == null || _isSending) return;
    final body = _messageController.text;
    if (body.trim().isEmpty && _pendingUploads.isEmpty) return;

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });
    try {
      await _service.sendMessage(
        channelId: channel.id,
        body: body,
        attachments: List.of(_pendingUploads),
      );
      if (!mounted) return;
      _messageController.clear();
      setState(_pendingUploads.clear);
      await _refreshMessages(channel.id);
    } on Exception catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _createChannel() async {
    final draft = await showDialog<_ChannelDraft>(
      context: context,
      builder: (context) => const _CreateChannelDialog(),
    );
    if (draft == null || !mounted) return;

    try {
      final channel = await _service.createChannel(
        name: draft.name,
        avatarBytes: draft.avatarBytes,
        avatarFileName: draft.avatarFileName,
        avatarMimeType: draft.avatarMimeType,
      );
      await _loadChannels(preferredChannelId: channel.id);
    } on Exception catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    }
  }

  Future<void> _invitePeople(ChatChannel channel) async {
    await showDialog<void>(
      context: context,
      builder: (context) =>
          _InviteUsersDialog(service: _service, channel: channel),
    );
  }

  Future<void> _showInvites() async {
    await _loadInvites();
    if (!mounted || _invites.isEmpty) return;

    final decision = await showDialog<({ChatInvite invite, bool accept})>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Expanded(child: Text('Channel invitations')),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _invites.length,
            separatorBuilder: (context, index) => const Divider(height: 24),
            itemBuilder: (context, index) {
              final invite = _invites[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Avatar(url: invite.channelAvatarUrl, radius: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${invite.inviterName} invited you to '
                          '#${invite.channelName}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, (
                          invite: invite,
                          accept: false,
                        )),
                        child: const Text('Decline'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, (
                          invite: invite,
                          accept: true,
                        )),
                        child: const Text('Accept'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    if (decision == null || !mounted) return;
    try {
      await _service.respondToInvite(
        inviteId: decision.invite.id,
        accept: decision.accept,
      );
      await _loadInvites();
      if (decision.accept) {
        await _loadChannels(preferredChannelId: decision.invite.channelId);
      }
    } on Exception catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    }
  }

  Future<void> _toggleReaction(ChatMessage message, String emoji) async {
    final channel = _selectedChannel;
    if (channel == null) return;
    try {
      await _service.toggleReaction(
        channelId: channel.id,
        messageId: message.id,
        emoji: emoji,
      );
    } on Exception catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    }
  }

  Future<bool> _confirmDeletion({
    required String title,
    required String message,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    final confirmed = await _confirmDeletion(
      title: 'Delete message?',
      message: 'This will permanently delete your message and its attachments.',
    );
    if (!confirmed || !mounted) return;
    try {
      await _service.deleteMessage(message.id);
      if (mounted) {
        setState(() {
          _messages.removeWhere((item) => item.id == message.id);
          _errorMessage = null;
        });
      }
    } on Exception catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    }
  }

  Future<void> _deleteAttachment(ChatAttachment attachment) async {
    final confirmed = await _confirmDeletion(
      title: 'Delete attachment?',
      message: 'This will permanently delete ${attachment.fileName}.',
    );
    if (!confirmed || !mounted) return;
    try {
      await _service.deleteAttachment(attachment.id);
      final channelId = _selectedChannel?.id;
      if (channelId != null) await _refreshMessages(channelId);
    } on Exception catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    }
  }

  Future<void> _deleteChannel(ChatChannel channel) async {
    final confirmed = await _confirmDeletion(
      title: 'Delete #${channel.name}?',
      message:
          'This will permanently delete the private channel, its messages, '
          'and its uploaded files.',
    );
    if (!confirmed || !mounted) return;
    try {
      await _service.deleteChannel(channel.id);
      if (mounted) await _loadChannels();
    } on Exception catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    }
  }

  Future<void> _downloadAttachment(ChatAttachment attachment) async {
    try {
      final bytes = await _service.downloadAttachment(attachment.storagePath);
      final extension = _extensionFor(attachment.fileName);
      final dotIndex = attachment.fileName.lastIndexOf('.');
      final name = dotIndex > 0
          ? attachment.fileName.substring(0, dotIndex)
          : attachment.fileName;
      final savedTo = await FileSaver.instance.saveAs(
        name: name,
        bytes: bytes,
        fileExtension: extension,
        mimeType: MimeType.custom,
        customMimeType: attachment.mimeType,
        dialogTitle: 'Save ${attachment.fileName}',
      );
      if (savedTo == null) return;
      if (savedTo.startsWith('Something went wrong')) {
        throw const ChatServiceException('The file could not be saved.');
      }
    } on Exception catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    }
  }

  Future<void> _openEmojiPicker({
    required ValueChanged<String> onSelected,
  }) async {
    const emojis = [
      '😀',
      '😄',
      '😂',
      '🥰',
      '😍',
      '😎',
      '🤔',
      '😮',
      '😢',
      '👏',
      '👍',
      '👎',
      '❤️',
      '🔥',
      '🎉',
      '🚀',
      '🙏',
      '✨',
      '💯',
      '🙌',
      '💜',
      '🤝',
      '👀',
      '✅',
    ];
    final emoji = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (final value in emojis)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.pop(context, value),
                  child: Center(
                    child: Text(value, style: const TextStyle(fontSize: 28)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (emoji != null && mounted) onSelected(emoji);
  }

  void _insertEmoji(String emoji) {
    final current = _messageController.value;
    final selection = current.selection;
    final start = selection.isValid ? selection.start : current.text.length;
    final end = selection.isValid ? selection.end : current.text.length;
    final text = current.text.replaceRange(start, end, emoji);
    _messageController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
          child: Row(
            children: [
              if (!widget.isWide)
                Builder(
                  builder: (context) => IconButton(
                    tooltip: 'Open sidebar',
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    icon: const Icon(Icons.menu_rounded),
                  ),
                ),
              IconButton(
                tooltip: 'Back to home',
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Messages',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: _invites.isEmpty
                    ? 'Invitations'
                    : '${_invites.length} pending invitations',
                onPressed: _showInvites,
                icon: Badge(
                  isLabelVisible: _invites.isNotEmpty,
                  label: Text('${_invites.length}'),
                  child: const Icon(Icons.notifications_none_rounded),
                ),
              ),
              const SizedBox(width: 4),
              CircleAvatar(
                radius: 20,
                backgroundColor: colors.primaryContainer,
                foregroundImage: widget.profile.profilePictureUrl == null
                    ? null
                    : NetworkImage(widget.profile.profilePictureUrl!),
                child: widget.profile.profilePictureUrl == null
                    ? Icon(
                        Icons.person_rounded,
                        color: colors.onPrimaryContainer,
                      )
                    : null,
              ),
            ],
          ),
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Material(
              color: colors.errorContainer,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: colors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: colors.onErrorContainer),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Dismiss',
                      onPressed: () => setState(() => _errorMessage = null),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: widget.isWide
              ? Row(
                  children: [
                    SizedBox(width: 270, child: _buildChannelList()),
                    const VerticalDivider(width: 1),
                    Expanded(child: _buildChatPanel()),
                  ],
                )
              : _showChannelsOnMobile
              ? _buildChannelList()
              : _buildChatPanel(),
        ),
      ],
    );
  }

  Widget _buildChannelList() {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Your channels',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Create channel',
                onPressed: _createChannel,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
        ),
        if (!_isLoadingChannels && _channels.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'No channels yet. Check your Supabase setup, then try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
        if (_isLoadingChannels)
          const Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              for (final channel in _channels)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    selected: _selectedChannel?.id == channel.id,
                    selectedTileColor: colors.primaryContainer.withValues(
                      alpha: 0.6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    leading: _Avatar(url: channel.avatarUrl, radius: 18),
                    title: Text(
                      '# ${channel.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      channel.isPublic ? 'Global room' : 'Private',
                    ),
                    onTap: () => _selectChannel(channel),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatPanel() {
    final colors = Theme.of(context).colorScheme;
    final channel = _selectedChannel;
    if (channel == null) {
      return Center(
        child: FilledButton.icon(
          onPressed: () => _loadChannels(),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Load channels'),
        ),
      );
    }

    final canInvite =
        !channel.isPublic && channel.creatorId == widget.profile.userId;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
          child: Row(
            children: [
              if (!widget.isWide)
                IconButton(
                  tooltip: 'Back to channels',
                  onPressed: () => setState(() => _showChannelsOnMobile = true),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              _Avatar(url: channel.avatarUrl, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '# ${channel.name}',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      channel.isPublic
                          ? 'Global community'
                          : 'Invite-only channel',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (canInvite)
                FilledButton.tonalIcon(
                  onPressed: () => _invitePeople(channel),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Invite'),
                ),
              if (!channel.isPublic &&
                  channel.creatorId == widget.profile.userId)
                IconButton(
                  tooltip: 'Delete private channel',
                  onPressed: () => _deleteChannel(channel),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              IconButton(
                tooltip: 'Refresh messages',
                onPressed: () => _refreshMessages(channel.id),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: colors.outlineVariant),
        Expanded(
          child: _messages.isEmpty && _isLoadingMessages
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.waving_hand_rounded,
                        size: 42,
                        color: colors.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'You’re at the start of #${channel.name}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Say hello to everyone.',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _messageScrollController,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return _MessageBubble(
                      message: message,
                      isMine: message.senderId == widget.profile.userId,
                      onReact: (emoji) => _toggleReaction(message, emoji),
                      onOpenEmojiPicker: () => _openEmojiPicker(
                        onSelected: (emoji) => _toggleReaction(message, emoji),
                      ),
                      onDownload: _downloadAttachment,
                      onDeleteMessage: () => _deleteMessage(message),
                      onDeleteAttachment: _deleteAttachment,
                    );
                  },
                ),
        ),
        _buildComposer(),
      ],
    );
  }

  Widget _buildComposer() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.9),
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pendingUploads.isNotEmpty)
            SizedBox(
              height: 74,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _pendingUploads.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final file = _pendingUploads[index];
                  return Container(
                    width: 220,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Icon(_fileIcon(file.mimeType), color: colors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                file.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _formatFileSize(file.sizeBytes),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: colors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove attachment',
                          onPressed: () =>
                              setState(() => _pendingUploads.removeAt(index)),
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Attach files',
                onPressed: _isPickingFiles ? null : _pickFiles,
                icon: _isPickingFiles
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.attach_file_rounded),
              ),
              IconButton(
                tooltip: 'Insert emoji',
                onPressed: () => _openEmojiPicker(onSelected: _insertEmoji),
                icon: const Icon(Icons.emoji_emotions_outlined),
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 4000,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Message #${_selectedChannel?.name ?? ''}',
                    counterText: '',
                    filled: true,
                    fillColor: colors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: colors.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: colors.outlineVariant),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Send message',
                onPressed: _isSending ? null : _sendMessage,
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.onReact,
    required this.onOpenEmojiPicker,
    required this.onDownload,
    required this.onDeleteMessage,
    required this.onDeleteAttachment,
  });

  final ChatMessage message;
  final bool isMine;
  final ValueChanged<String> onReact;
  final VoidCallback onOpenEmojiPicker;
  final ValueChanged<ChatAttachment> onDownload;
  final VoidCallback onDeleteMessage;
  final ValueChanged<ChatAttachment> onDeleteAttachment;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMine) ...[
            _Avatar(url: message.senderAvatarUrl, radius: 18),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message.senderName,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          TimeOfDay.fromDateTime(message.createdAt)
                              .format(context),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMine
                          ? colors.primaryContainer
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMine ? 18 : 5),
                        bottomRight: Radius.circular(isMine ? 5 : 18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.body.isNotEmpty)
                          SelectableText(message.body),
                        for (final attachment in message.attachments) ...[
                          if (message.body.isNotEmpty)
                            const SizedBox(height: 10),
                          _AttachmentView(
                            attachment: attachment,
                            onDownload: () => onDownload(attachment),
                            canDelete:
                                attachment.senderId == message.senderId &&
                                isMine,
                            onDelete: () => onDeleteAttachment(attachment),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    alignment: isMine ? WrapAlignment.end : WrapAlignment.start,
                    children: [
                      for (final reaction in message.reactions)
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          label: Text('${reaction.emoji} ${reaction.count}'),
                          backgroundColor: reaction.isSelectedByMe
                              ? colors.primaryContainer
                              : colors.surfaceContainerLow,
                          onPressed: () => onReact(reaction.emoji),
                        ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'React',
                        onPressed: onOpenEmojiPicker,
                        icon: const Icon(Icons.add_reaction_outlined, size: 18),
                      ),
                      if (isMine)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Delete message',
                          onPressed: onDeleteMessage,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMine) const SizedBox(width: 8),
          if (isMine) _Avatar(url: message.senderAvatarUrl, radius: 18),
        ],
      ),
    );
  }
}

class _AttachmentView extends StatelessWidget {
  const _AttachmentView({
    required this.attachment,
    required this.onDownload,
    required this.canDelete,
    required this.onDelete,
  });

  final ChatAttachment attachment;
  final VoidCallback onDownload;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth.clamp(0.0, 320.0).toDouble()
            : 320.0;
        if (attachment.isImage) {
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  attachment.signedUrl,
                  width: width,
                  height: width * 0.68,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _FileCard(
                    attachment: attachment,
                    onDownload: onDownload,
                    width: width,
                    canDelete: canDelete,
                    onDelete: onDelete,
                  ),
                ),
              ),
              if (canDelete)
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton.filledTonal(
                    tooltip: 'Delete attachment',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ),
            ],
          );
        }
        if (attachment.isVideo) {
          return _VideoAttachment(
            attachment: attachment,
            onDownload: onDownload,
            width: width,
            canDelete: canDelete,
            onDelete: onDelete,
          );
        }
        return _FileCard(
          attachment: attachment,
          onDownload: onDownload,
          width: width,
          canDelete: canDelete,
          onDelete: onDelete,
        );
      },
    );
  }
}

class _VideoAttachment extends StatefulWidget {
  const _VideoAttachment({
    required this.attachment,
    required this.onDownload,
    required this.width,
    required this.canDelete,
    required this.onDelete,
  });

  final ChatAttachment attachment;
  final VoidCallback onDownload;
  final double width;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  State<_VideoAttachment> createState() => _VideoAttachmentState();
}

class _VideoAttachmentState extends State<_VideoAttachment> {
  late final VideoPlayerController _controller;
  late final Future<void> _initializeVideo;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.attachment.signedUrl),
    );
    _initializeVideo = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: widget.width,
        color: Colors.black,
        child: FutureBuilder<void>(
          future: _initializeVideo,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _VideoFallback(
                attachment: widget.attachment,
                onDownload: widget.onDownload,
                width: widget.width,
                canDelete: widget.canDelete,
                onDelete: widget.onDelete,
              );
            }
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 190,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(_controller),
                  IconButton.filledTonal(
                    onPressed: () {
                      setState(() {
                        _controller.value.isPlaying
                            ? _controller.pause()
                            : _controller.play();
                      });
                    },
                    icon: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: colors.onSurface,
                    ),
                  ),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 4,
                    child: VideoProgressIndicator(
                      _controller,
                      allowScrubbing: true,
                      colors: VideoProgressColors(
                        playedColor: colors.primary,
                        bufferedColor: colors.onSurfaceVariant,
                        backgroundColor: colors.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  if (widget.canDelete)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton.filledTonal(
                        tooltip: 'Delete attachment',
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _VideoFallback extends StatelessWidget {
  const _VideoFallback({
    required this.attachment,
    required this.onDownload,
    required this.width,
    required this.canDelete,
    required this.onDelete,
  });

  final ChatAttachment attachment;
  final VoidCallback onDownload;
  final double width;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return _FileCard(
      attachment: attachment,
      onDownload: onDownload,
      width: width,
      canDelete: canDelete,
      onDelete: onDelete,
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({
    required this.attachment,
    required this.onDownload,
    required this.width,
    required this.canDelete,
    required this.onDelete,
  });

  final ChatAttachment attachment;
  final VoidCallback onDownload;
  final double width;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(_fileIcon(attachment.mimeType), color: colors.primary, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  _formatFileSize(attachment.sizeBytes),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Download ${attachment.fileName}',
            onPressed: onDownload,
            icon: const Icon(Icons.download_rounded),
          ),
          if (canDelete)
            IconButton(
              tooltip: 'Delete attachment',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.radius});

  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: colors.primaryContainer,
      child: Icon(
        Icons.person_rounded,
        size: radius,
        color: colors.onPrimaryContainer,
      ),
    );
    if (url == null) return fallback;
    return ClipOval(
      child: Image.network(
        url!,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}

class _ChannelDraft {
  const _ChannelDraft({
    required this.name,
    this.avatarBytes,
    this.avatarFileName,
    this.avatarMimeType,
  });

  final String name;
  final Uint8List? avatarBytes;
  final String? avatarFileName;
  final String? avatarMimeType;
}

class _CreateChannelDialog extends StatefulWidget {
  const _CreateChannelDialog();

  @override
  State<_CreateChannelDialog> createState() => _CreateChannelDialogState();
}

class _CreateChannelDialogState extends State<_CreateChannelDialog> {
  final _nameController = TextEditingController();
  Uint8List? _avatarBytes;
  String? _avatarFileName;
  String? _avatarMimeType;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final file = await FilePicker.pickFile(type: FileType.image);
      if (file == null) return;
      final size = file.lengthSync() ?? await file.length();
      if (size == null || size > 5 * 1024 * 1024) {
        throw const FormatException('Choose an image smaller than 5 MB.');
      }
      if (!mounted) return;
      final bytes = await file.readAsBytes();
      final mimeType = _mimeTypeFor(file.name);
      if (!mounted) return;
      if (bytes.isEmpty || !mimeType.startsWith('image/')) {
        throw const FormatException(
          'Choose a readable image smaller than 5 MB.',
        );
      }
      setState(() {
        _avatarBytes = bytes;
        _avatarFileName = file.name;
        _avatarMimeType = mimeType;
        _errorMessage = null;
      });
    } on Exception catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    }
  }

  void _create() {
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length > 64) {
      setState(
        () => _errorMessage = 'Channel names must be 1 to 64 characters.',
      );
      return;
    }
    Navigator.pop(
      context,
      _ChannelDraft(
        name: name,
        avatarBytes: _avatarBytes,
        avatarFileName: _avatarFileName,
        avatarMimeType: _avatarMimeType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Create a channel'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              maxLength: 64,
              decoration: const InputDecoration(
                labelText: 'Channel name',
                prefixText: '# ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colors.primaryContainer,
                  foregroundImage: _avatarBytes == null
                      ? null
                      : MemoryImage(_avatarBytes!),
                  child: _avatarBytes == null
                      ? const Icon(Icons.tag_rounded)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickAvatar,
                    icon: const Icon(Icons.upload_rounded),
                    label: Text(
                      _avatarBytes == null ? 'Upload channel photo' : 'Change',
                    ),
                  ),
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: TextStyle(color: colors.error)),
            ],
            const SizedBox(height: 10),
            Text(
              'New channels are private. Invite signed-up users to join.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _create, child: const Text('Create')),
      ],
    );
  }
}

class _InviteUsersDialog extends StatefulWidget {
  const _InviteUsersDialog({required this.service, required this.channel});

  final ChatService service;
  final ChatChannel channel;

  @override
  State<_InviteUsersDialog> createState() => _InviteUsersDialogState();
}

class _InviteUsersDialogState extends State<_InviteUsersDialog> {
  final _searchController = TextEditingController();
  List<ChatUser> _results = [];
  final Set<String> _invitedIds = {};
  String? _errorMessage;
  bool _isSearching = false;
  final Set<String> _invitingIds = {};
  int _searchGeneration = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final generation = ++_searchGeneration;
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });
    try {
      final users = await widget.service.searchUsers(
        query,
        channelId: widget.channel.id,
      );
      if (mounted && generation == _searchGeneration) {
        setState(() {
          _results = users;
          _isSearching = false;
        });
      }
    } on Exception catch (error) {
      if (mounted && generation == _searchGeneration) {
        setState(() {
          _isSearching = false;
          _errorMessage = error.toString();
        });
      }
    }
  }

  Future<void> _invite(ChatUser user) async {
    setState(() {
      _invitingIds.add(user.id);
      _errorMessage = null;
    });
    try {
      await widget.service.inviteUser(
        channelId: widget.channel.id,
        inviteeId: user.id,
      );
      if (mounted) setState(() => _invitedIds.add(user.id));
    } on Exception catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _invitingIds.remove(user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text('Invite to #${widget.channel.name}'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Search usernames',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(_errorMessage!, style: TextStyle(color: colors.error)),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.trim().length < 2
                            ? 'Type at least two characters.'
                            : 'No matching users.',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final user = _results[index];
                        final invited = _invitedIds.contains(user.id);
                        return ListTile(
                          leading: _Avatar(url: user.avatarUrl, radius: 19),
                          title: Text(user.username),
                          trailing: invited
                              ? const Icon(Icons.check_circle_rounded)
                              : IconButton(
                                  tooltip: 'Invite ${user.username}',
                                  onPressed: _invitingIds.contains(user.id)
                                      ? null
                                      : () => _invite(user),
                                  icon: _invitingIds.contains(user.id)
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.person_add_alt_1_rounded,
                                        ),
                                ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

IconData _fileIcon(String mimeType) {
  if (mimeType.startsWith('image/')) return Icons.image_outlined;
  if (mimeType.startsWith('video/')) return Icons.movie_outlined;
  if (mimeType.startsWith('audio/')) return Icons.audio_file_outlined;
  if (mimeType == 'application/pdf') return Icons.picture_as_pdf_outlined;
  return Icons.insert_drive_file_outlined;
}

String _mimeTypeFor(String fileName) {
  final extension = _extensionFor(fileName);
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'bmp' => 'image/bmp',
    'mp4' => 'video/mp4',
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    'mkv' => 'video/x-matroska',
    'avi' => 'video/x-msvideo',
    'mp3' => 'audio/mpeg',
    'wav' => 'audio/wav',
    'pdf' => 'application/pdf',
    'txt' => 'text/plain',
    'zip' => 'application/zip',
    'json' => 'application/json',
    _ => 'application/octet-stream',
  };
}

String _extensionFor(String fileName) {
  final index = fileName.lastIndexOf('.');
  if (index < 0 || index == fileName.length - 1) return 'bin';
  return fileName.substring(index + 1).toLowerCase();
}

String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
