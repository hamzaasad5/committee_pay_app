import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_colors.dart';
import 'committee_chat_screen.dart';

class ChatsListScreen extends StatefulWidget {
  final String userId;
  const ChatsListScreen({super.key, required this.userId});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  late Stream<QuerySnapshot> _chatsStream;

  @override
  void initState() {
    super.initState();
    _chatsStream = FirebaseFirestore.instance
        .collection('committee_chats')
        .where('participants', arrayContains: widget.userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Color _getColorFromString(String str) {
    final hash = str.hashCode.abs();
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.7, 0.5).toColor();
  }

  String _formatLastMessageTime(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final DateTime messageTime = timestamp.toDate();
    final DateTime now = DateTime.now();
    final difference = now.difference(messageTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(messageTime);
    } else if (difference.inDays > 0) {
      return DateFormat('EEE').format(messageTime);
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Just now';
    }
  }

  String _getMessagePreview(Map<String, dynamic> chatData) {
    final lastMessage = chatData['lastMessage'] as String?;
    final lastMessageSender = chatData['lastMessageSender'] as String?;
    final currentUserId = widget.userId;

    if (lastMessage == null) return 'No messages yet';

    // If the last message was sent by current user, show "You: "
    if (lastMessageSender == currentUserId) {
      return 'You: $lastMessage';
    }

    return lastMessage;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        title: const Text(
          'Chats',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.goldColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _chatsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppColors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading chats',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.goldColor,
              ),
            );
          }

          final chats = snapshot.data?.docs ?? [];

          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.goldSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline,
                      size: 40,
                      color: AppColors.goldColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No Chats Yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a conversation by joining a committee',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.goldColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppColors.r12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Browse Committees'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final chatData = chat.data() as Map<String, dynamic>;
              final committeeName = chatData['committeeName'] ?? 'Committee';
              final committeeId = chatData['committeeId'];
              final lastMessageTime = chatData['lastMessageTime'] as Timestamp?;
              final unreadCount = chatData['unreadCounts']?[widget.userId] ?? 0;
              final messagePreview = _getMessagePreview(chatData);
              final committeeImage = chatData['committeeImage'];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CommitteeChatScreen(
                            committeeId: committeeId,
                            committeeName: committeeName,
                            committeeImage: committeeImage,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(AppColors.r16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: unreadCount > 0
                            ? AppColors.surfaceDark
                            : AppColors.surfaceDark.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(AppColors.r16),
                        border: Border.all(
                          color: unreadCount > 0
                              ? AppColors.goldColor.withOpacity(0.3)
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Group Icon with Initials
                          Container(
                            width: 55,
                            height: 55,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  _getColorFromString(committeeName),
                                  _getColorFromString(committeeName).withOpacity(0.7),
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: committeeImage != null && committeeImage.isNotEmpty
                                  ? ClipOval(
                                child: Image.network(
                                  committeeImage,
                                  width: 55,
                                  height: 55,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Text(
                                      _getInitials(committeeName),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    );
                                  },
                                ),
                              )
                                  : Text(
                                _getInitials(committeeName),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Chat Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        committeeName,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: unreadCount > 0
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (lastMessageTime != null)
                                      Text(
                                        _formatLastMessageTime(lastMessageTime),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: unreadCount > 0
                                              ? AppColors.goldColor
                                              : AppColors.textSecondary,
                                          fontWeight: unreadCount > 0
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        messagePreview,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: unreadCount > 0
                                              ? Colors.white
                                              : AppColors.textSecondary,
                                          fontWeight: unreadCount > 0
                                              ? FontWeight.w500
                                              : FontWeight.normal,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (unreadCount > 0)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.goldColor,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}