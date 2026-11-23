class ChatChannel {
  const ChatChannel({
    required this.id,
    required this.name,
    required this.isPublic,
    required this.creatorId,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final bool isPublic;
  final String creatorId;
  final String? avatarUrl;
}

class ChatUser {
  const ChatUser({
    required this.id,
    required this.username,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String? avatarUrl;
}

class ChatInvite {
  const ChatInvite({
    required this.id,
    required this.channelId,
    required this.channelName,
    required this.inviterName,
    this.channelAvatarUrl,
    this.inviterAvatarUrl,
  });

  final String id;
  final String channelId;
  final String channelName;
  final String inviterName;
  final String? channelAvatarUrl;
  final String? inviterAvatarUrl;
}

class ChatAttachment {
  const ChatAttachment({
    required this.id,
    required this.senderId,
    required this.storagePath,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.signedUrl,
  });

  final String id;
  final String senderId;
  final String storagePath;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final String signedUrl;

  bool get isImage => mimeType.startsWith('image/');
  bool get isVideo => mimeType.startsWith('video/');
}

class ChatReaction {
  const ChatReaction({
    required this.emoji,
    required this.count,
    required this.isSelectedByMe,
  });

  final String emoji;
  final int count;
  final bool isSelectedByMe;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.createdAt,
    required this.body,
    required this.attachments,
    required this.reactions,
    this.senderAvatarUrl,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final DateTime createdAt;
  final String body;
  final List<ChatAttachment> attachments;
  final List<ChatReaction> reactions;
}

class PendingUpload {
  const PendingUpload({
    required this.name,
    required this.bytes,
    required this.sizeBytes,
    required this.mimeType,
  });

  final String name;
  final List<int> bytes;
  final int sizeBytes;
  final String mimeType;
}
