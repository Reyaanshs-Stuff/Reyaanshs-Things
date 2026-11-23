import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_models.dart';

class ChatService {
  ChatService([SupabaseClient? client])
    : client = client ?? Supabase.instance.client;

  final SupabaseClient client;

  String get currentUserId {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw ChatServiceException('You must be signed in.');
    return userId;
  }

  Future<List<ChatChannel>> loadChannels() async {
    final rows = await client
        .from('channels')
        .select('id, name, is_public, creator_id, avatar_path')
        .order('created_at');
    return rows.map((row) {
      final avatarPath = row['avatar_path'] as String?;
      return ChatChannel(
        id: row['id'] as String,
        name: row['name'] as String,
        isPublic: row['is_public'] as bool,
        creatorId: row['creator_id'] as String,
        avatarUrl: avatarPath == null
            ? null
            : client.storage.from('channel-avatars').getPublicUrl(avatarPath),
      );
    }).toList();
  }

  Future<ChatChannel> createChannel({
    required String name,
    Uint8List? avatarBytes,
    String? avatarFileName,
    String? avatarMimeType,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || trimmedName.length > 64) {
      throw ChatServiceException(
        'Channel names must be between 1 and 64 characters.',
      );
    }

    String? avatarPath;
    if (avatarBytes != null && avatarFileName != null) {
      if (avatarBytes.isEmpty ||
          avatarBytes.length > 5 * 1024 * 1024 ||
          !(avatarMimeType == 'image/jpeg' ||
              avatarMimeType == 'image/png' ||
              avatarMimeType == 'image/webp')) {
        throw const ChatServiceException(
          'Channel photos must be JPG, PNG, or WebP images smaller than 5 MB.',
        );
      }
      final extension = _extension(avatarFileName);
      avatarPath =
          '$currentUserId/${DateTime.now().microsecondsSinceEpoch}.$extension';
      await client.storage
          .from('channel-avatars')
          .uploadBinary(
            avatarPath,
            avatarBytes,
            fileOptions: FileOptions(
              contentType: avatarMimeType ?? 'image/$extension',
            ),
          );
    }

    late final Map<String, dynamic> row;
    try {
      row = await client
          .from('channels')
          .insert({
            'name': trimmedName,
            'creator_id': currentUserId,
            'is_public': false,
            'avatar_path': avatarPath,
          })
          .select('id, name, is_public, creator_id, avatar_path')
          .single();
    } on Exception catch (error, stackTrace) {
      if (avatarPath != null) {
        try {
          await client.storage.from('channel-avatars').remove([avatarPath]);
        } on Exception catch (cleanupError) {
          throw ChatServiceException(
            'Channel creation failed: $error. The uploaded image could not '
            'be removed: $cleanupError',
          );
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

    return ChatChannel(
      id: row['id'] as String,
      name: row['name'] as String,
      isPublic: row['is_public'] as bool,
      creatorId: row['creator_id'] as String,
      avatarUrl: avatarPath == null
          ? null
          : client.storage.from('channel-avatars').getPublicUrl(avatarPath),
    );
  }

  Future<List<ChatUser>> searchUsers(
    String query, {
    required String channelId,
  }) async {
    final term = query.trim().replaceAll('%', '').replaceAll('_', '');
    if (term.length < 2) return const [];

    final memberRows = await client
        .from('channel_members')
        .select('user_id')
        .eq('channel_id', channelId);
    final excludedIds = memberRows.map((row) => row['user_id'] as String).toSet();
    final pendingInvites = await client
        .from('channel_invites')
        .select('invitee_id')
        .eq('channel_id', channelId)
        .eq('status', 'pending');
    excludedIds.addAll(
      pendingInvites.map((row) => row['invitee_id'] as String),
    );
    final rows = await client
        .from('profiles')
        .select('id, username, avatar_path')
        .neq('id', currentUserId)
        .ilike('username', '%$term%')
        .limit(30);
    return rows
        .where((row) => !excludedIds.contains(row['id']))
        .take(12)
        .map(_chatUserFromRow)
        .toList();
  }

  Future<void> inviteUser({
    required String channelId,
    required String inviteeId,
  }) async {
    await client.from('channel_invites').insert({
      'channel_id': channelId,
      'inviter_id': currentUserId,
      'invitee_id': inviteeId,
    });
  }

  Future<List<ChatInvite>> loadPendingInvites() async {
    final rows = await client
        .from('channel_invites')
        .select(
          'id, channel_id, channels!channel_invites_channel_id_fkey'
          '(name, avatar_path), '
          'profiles!channel_invites_inviter_id_fkey(username, avatar_path)',
        )
        .eq('invitee_id', currentUserId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return rows.map((row) {
      final channel = _asMap(row['channels']);
      final inviter = _asMap(row['profiles']);
      final channelAvatarPath = channel['avatar_path'] as String?;
      final inviterAvatarPath = inviter['avatar_path'] as String?;
      return ChatInvite(
        id: row['id'] as String,
        channelId: row['channel_id'] as String,
        channelName: channel['name'] as String? ?? 'Channel',
        inviterName: inviter['username'] as String? ?? 'A user',
        channelAvatarUrl: channelAvatarPath == null
            ? null
            : client.storage
                  .from('channel-avatars')
                  .getPublicUrl(channelAvatarPath),
        inviterAvatarUrl: inviterAvatarPath == null
            ? null
            : client.storage
                  .from('profile-avatars')
                  .getPublicUrl(inviterAvatarPath),
      );
    }).toList();
  }

  Future<void> respondToInvite({
    required String inviteId,
    required bool accept,
  }) async {
    await client.rpc(
      'respond_to_channel_invite',
      params: {'invite_id': inviteId, 'accept_invite': accept},
    );
  }

  Future<List<ChatMessage>> loadMessages(String channelId) async {
    final rows = await client
        .from('messages')
        .select(
          'id, sender_id, body, created_at, '
          'profiles!messages_sender_id_fkey(username, avatar_path)',
        )
        .eq('channel_id', channelId)
        .order('created_at', ascending: false)
        .limit(100);
    final orderedRows = rows.reversed.toList();
    if (orderedRows.isEmpty) return const [];

    final messageIds = orderedRows.map((row) => row['id'] as String).toList();
    final attachmentRows = await client
        .from('message_attachments')
        .select(
          'id, message_id, sender_id, storage_path, file_name, mime_type, '
          'size_bytes',
        )
        .inFilter('message_id', messageIds);
    final reactionRows = await client
        .from('message_reactions')
        .select('message_id, user_id, emoji')
        .inFilter('message_id', messageIds);

    final attachmentsByMessage = <String, List<ChatAttachment>>{};
    for (final row in attachmentRows) {
      final path = row['storage_path'] as String;
      final signedUrl = await client.storage
          .from('chat-attachments')
          .createSignedUrl(path, 60 * 60);
      final attachment = ChatAttachment(
        id: row['id'] as String,
        senderId: row['sender_id'] as String,
        storagePath: path,
        fileName: row['file_name'] as String,
        mimeType: row['mime_type'] as String,
        sizeBytes: (row['size_bytes'] as num).toInt(),
        signedUrl: signedUrl,
      );
      attachmentsByMessage
          .putIfAbsent(row['message_id'] as String, () => [])
          .add(attachment);
    }

    final currentId = currentUserId;
    final reactionsByMessage = <String, Map<String, List<String>>>{};
    for (final row in reactionRows) {
      final messageId = row['message_id'] as String;
      final emoji = row['emoji'] as String;
      final userId = row['user_id'] as String;
      reactionsByMessage
          .putIfAbsent(messageId, () => {})
          .putIfAbsent(emoji, () => [])
          .add(userId);
    }

    return orderedRows.map((row) {
      final profile = _asMap(row['profiles']);
      final avatarPath = profile['avatar_path'] as String?;
      final id = row['id'] as String;
      final reactionGroups = reactionsByMessage[id] ?? {};
      final reactions = reactionGroups.entries.map((entry) {
        return ChatReaction(
          emoji: entry.key,
          count: entry.value.length,
          isSelectedByMe: entry.value.contains(currentId),
        );
      }).toList();

      return ChatMessage(
        id: id,
        senderId: row['sender_id'] as String,
        senderName: profile['username'] as String? ?? 'Unknown user',
        senderAvatarUrl: avatarPath == null
            ? null
            : client.storage.from('profile-avatars').getPublicUrl(avatarPath),
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
        body: row['body'] as String,
        attachments: attachmentsByMessage[id] ?? const [],
        reactions: reactions,
      );
    }).toList();
  }

  Future<void> sendMessage({
    required String channelId,
    required String body,
    required List<PendingUpload> attachments,
  }) async {
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty && attachments.isEmpty) {
      throw ChatServiceException('Write a message or attach a file.');
    }
    if (trimmedBody.length > 4000) {
      throw ChatServiceException(
        'Messages can contain up to 4,000 characters.',
      );
    }
    if (attachments.length > 10) {
      throw ChatServiceException('Attach up to 10 files per message.');
    }
    for (final attachment in attachments) {
      if (attachment.sizeBytes < 1 || attachment.sizeBytes > 50 * 1024 * 1024) {
        throw ChatServiceException('Each file must be smaller than 50 MB.');
      }
    }

    final uploadedPaths = <String>[];
    String? messageId;
    final userId = currentUserId;
    try {
      for (var index = 0; index < attachments.length; index++) {
        final file = attachments[index];
        final extension = _extension(file.name);
        final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
        final path =
            '$channelId/$userId/'
            '${DateTime.now().microsecondsSinceEpoch}_${index}_$safeName';
        await client.storage.from('chat-attachments').uploadBinary(
          path,
          Uint8List.fromList(file.bytes),
          fileOptions: FileOptions(
            contentType: file.mimeType.isEmpty
                ? 'application/$extension'
                : file.mimeType,
            upsert: false,
          ),
        );
        uploadedPaths.add(path);
      }

      final message = await client
          .from('messages')
          .insert({
            'channel_id': channelId,
            'sender_id': userId,
            'body': trimmedBody,
          })
          .select('id')
          .single();
      messageId = message['id'] as String;

      if (attachments.isNotEmpty) {
        await client.from('message_attachments').insert([
          for (var index = 0; index < attachments.length; index++)
            {
              'message_id': messageId,
              'channel_id': channelId,
              'sender_id': userId,
              'storage_path': uploadedPaths[index],
              'file_name': attachments[index].name,
              'mime_type': attachments[index].mimeType.isEmpty
                  ? 'application/${_extension(attachments[index].name)}'
                  : attachments[index].mimeType,
              'size_bytes': attachments[index].sizeBytes,
            },
        ]);
      }
    } on Exception catch (error, stackTrace) {
      final cleanupErrors = <String>[];
      if (messageId != null) {
        try {
          await client.from('messages').delete().eq('id', messageId);
        } on Exception catch (cleanupError) {
          cleanupErrors.add(cleanupError.toString());
        }
      }
      if (uploadedPaths.isNotEmpty) {
        try {
          await client.storage.from('chat-attachments').remove(uploadedPaths);
        } on Exception catch (cleanupError) {
          cleanupErrors.add(cleanupError.toString());
        }
      }
      if (cleanupErrors.isNotEmpty) {
        throw ChatServiceException(
          'Message send failed: $error. Cleanup also failed: '
          '${cleanupErrors.join('; ')}',
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<Uint8List> downloadAttachment(String path) {
    return client.storage.from('chat-attachments').download(path);
  }

  Future<void> deleteAttachment(String attachmentId) async {
    final userId = currentUserId;
    final row = await client
        .from('message_attachments')
        .select('storage_path')
        .eq('id', attachmentId)
        .eq('sender_id', userId)
        .maybeSingle();
    if (row == null) {
      throw const ChatServiceException(
        'You can only delete attachments you uploaded.',
      );
    }

    final path = row['storage_path'] as String;
    await client.storage.from('chat-attachments').remove([path]);
    try {
      final deleted = await client
          .from('message_attachments')
          .delete()
          .eq('id', attachmentId)
          .eq('sender_id', userId)
          .select('id')
          .maybeSingle();
      if (deleted == null) {
        throw const ChatServiceException('The attachment record was not found.');
      }
    } on Exception catch (error) {
      throw ChatServiceException(
        'The attachment file was removed, but its record could not be deleted: '
        '$error',
      );
    }
  }

  Future<void> deleteMessage(String messageId) async {
    final userId = currentUserId;
    final message = await client
        .from('messages')
        .select('id')
        .eq('id', messageId)
        .eq('sender_id', userId)
        .maybeSingle();
    if (message == null) {
      throw const ChatServiceException('You can only delete your own messages.');
    }

    final rows = await client
        .from('message_attachments')
        .select('storage_path')
        .eq('message_id', messageId);
    final paths = rows.map((row) => row['storage_path'] as String).toList();
    if (paths.isNotEmpty) {
      await client.storage.from('chat-attachments').remove(paths);
    }
    try {
      final deleted = await client
          .from('messages')
          .delete()
          .eq('id', messageId)
          .eq('sender_id', userId)
          .select('id')
          .maybeSingle();
      if (deleted == null) {
        throw const ChatServiceException('The message was not found.');
      }
    } on Exception catch (error) {
      throw ChatServiceException(
        'The message files were removed, but the message could not be deleted: '
        '$error',
      );
    }
  }

  Future<void> deleteChannel(String channelId) async {
    final userId = currentUserId;
    final channel = await client
        .from('channels')
        .select('avatar_path')
        .eq('id', channelId)
        .eq('creator_id', userId)
        .eq('is_public', false)
        .maybeSingle();
    if (channel == null) {
      throw const ChatServiceException(
        'Only the owner can delete a private channel.',
      );
    }

    final attachmentRows = await client
        .from('message_attachments')
        .select('storage_path')
        .eq('channel_id', channelId);
    final paths = attachmentRows
        .map((row) => row['storage_path'] as String)
        .toList();
    if (paths.isNotEmpty) {
      try {
        await client.storage.from('chat-attachments').remove(paths);
      } on Exception catch (error) {
        throw ChatServiceException(
          'Channel files could not be cleaned up; the channel was not deleted: '
          '$error',
        );
      }
    }

    final avatarPath = channel['avatar_path'] as String?;
    if (avatarPath != null) {
      try {
        await client.storage.from('channel-avatars').remove([avatarPath]);
      } on Exception catch (error) {
        throw ChatServiceException(
          'Channel attachments were removed, but the channel image could not '
          'be cleaned up, so the channel was not deleted: $error',
        );
      }
    }
    try {
      final deleted = await client
          .from('channels')
          .delete()
          .eq('id', channelId)
          .eq('creator_id', userId)
          .select('id')
          .maybeSingle();
      if (deleted == null) {
        throw const ChatServiceException('The channel was not found.');
      }
    } on Exception catch (error) {
      throw ChatServiceException(
        'The channel files were removed, but the channel could not be deleted: '
        '$error',
      );
    }
  }

  Future<void> toggleReaction({
    required String channelId,
    required String messageId,
    required String emoji,
  }) async {
    final existing = await client
        .from('message_reactions')
        .select('message_id')
        .eq('message_id', messageId)
        .eq('channel_id', channelId)
        .eq('user_id', currentUserId)
        .eq('emoji', emoji)
        .maybeSingle();

    if (existing == null) {
      await client.from('message_reactions').insert({
        'channel_id': channelId,
        'message_id': messageId,
        'user_id': currentUserId,
        'emoji': emoji,
      });
    } else {
      await client
          .from('message_reactions')
          .delete()
          .eq('message_id', messageId)
          .eq('user_id', currentUserId)
          .eq('emoji', emoji);
    }
  }

  RealtimeChannel subscribeToChannel(
    String channelId,
    void Function() onChanged,
  ) {
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'channel_id',
      value: channelId,
    );
    return client
        .channel('messages:$channelId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: filter,
          callback: (_) => onChanged(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'message_reactions',
          filter: filter,
          callback: (_) => onChanged(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'message_attachments',
          filter: filter,
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  RealtimeChannel subscribeToInvites(void Function() onChanged) {
    return client
        .channel('invites:$currentUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'channel_invites',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'invitee_id',
            value: currentUserId,
          ),
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  Future<void> removeRealtimeChannel(RealtimeChannel? channel) async {
    if (channel != null) await client.removeChannel(channel);
  }

  ChatUser _chatUserFromRow(Map<String, dynamic> row) {
    final avatarPath = row['avatar_path'] as String?;
    return ChatUser(
      id: row['id'] as String,
      username: row['username'] as String,
      avatarUrl: avatarPath == null
          ? null
          : client.storage.from('profile-avatars').getPublicUrl(avatarPath),
    );
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

String _extension(String name) {
  final parts = name.split('.');
  final extension = parts.length > 1 ? parts.last.toLowerCase() : 'bin';
  return RegExp(r'^[a-z0-9]{1,8}$').hasMatch(extension) ? extension : 'bin';
}

class ChatServiceException implements Exception {
  const ChatServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
