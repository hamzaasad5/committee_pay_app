import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../constants/app_colors.dart';
import '../../../services/chat_service.dart';
import '../../widgets/custom_app_bar.dart';
import 'committee_chat_screen.dart';

class ChatsListScreen extends StatefulWidget {
  final String userId;
  const ChatsListScreen({super.key, required this.userId});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  late Stream<QuerySnapshot> _chatsStream;
  late ChatService _chatService;
  bool _isLoading = true;
  String? _error;
  Map<String, int> _onlineStatusCache = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
    _setupChatsStream();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh chats when app comes to foreground
      _refreshChats();
    }
  }

  void _initializeServices() {
    _chatService = ChatService();
  }

  void _setupChatsStream() {
    _chatsStream = FirebaseFirestore.instance
        .collection('committee_chats')
        .where('participants', arrayContains: widget.userId)
        .where('status', isEqualTo: 'active')
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .handleError((error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _isLoading = false;
        });
      }
    });

    setState(() => _isLoading = false);
  }

  Future<void> _refreshChats() async {
    // Force refresh by resetting the stream
    _setupChatsStream();
    setState(() {});
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
    final lastMessageType = chatData['lastMessageType'] as String?;
    final currentUserId = widget.userId;

    if (lastMessage == null) return 'No messages yet';

    // Handle different message types
    if (lastMessageType == 'image') {
      if (lastMessageSender == currentUserId) {
        return 'You: 📷 Sent an image';
      }
      return '📷 Image';
    }

    // If the last message was sent by current user, show "You: "
    if (lastMessageSender == currentUserId) {
      return 'You: $lastMessage';
    }

    return lastMessage;
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading chats',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Something went wrong',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _error = null;
                _isLoading = true;
                _setupChatsStream();
              });
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
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.goldSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 50,
              color: AppColors.goldColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Chats Yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Start a conversation by joining a committee',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/browse_committees');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.goldColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.r12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 14,
              ),
            ),
            child: const Text(
              'Browse Committees',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.goldColor,
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            'Loading chats...',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: CustomAppBar(
        title: "Chats",
        showBackButton: false,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.goldColor),
            onPressed: _refreshChats,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
          ? _buildErrorWidget()
          : StreamBuilder<QuerySnapshot>(
        stream: _chatsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorWidget();
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          final chats = snapshot.data?.docs ?? [];

          if (chats.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: _refreshChats,
            color: AppColors.goldColor,
            backgroundColor: AppColors.surfaceDark,
            child: ListView.builder(
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
                final participantCount = (chatData['participants'] as List?)?.length ?? 0;

                return Dismissible(
                  key: Key(committeeId),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(AppColors.r16),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  confirmDismiss: (direction) async {
                    return await _showDeleteConfirmation(context, committeeName);
                  },
                  onDismissed: (direction) {
                    _archiveChat(committeeId);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          // Mark messages as read before navigating
                          await _chatService.markAllMessagesAsRead(
                            committeeId,
                            widget.userId,
                          );
                          if (mounted) {
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
                          }
                        },
                        borderRadius: BorderRadius.circular(AppColors.r16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
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
                              // Committee Avatar
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
                                    child: CachedNetworkImage(
                                      imageUrl: committeeImage,
                                      width: 55,
                                      height: 55,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => const SizedBox(
                                        width: 55,
                                        height: 55,
                                        child: Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.goldColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Text(
                                        _getInitials(committeeName),
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
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
                                    const SizedBox(height: 4),
                                    // Member count indicator
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.people_outline,
                                          size: 10,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$participantCount members',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textSecondary,
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
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context, String committeeName) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.r16),
        ),
        title: const Text(
          'Archive Chat',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to archive the chat for "$committeeName"?\n\nYou can still access it from the archived section.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.goldColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.r8),
              ),
            ),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }

  Future<void> _archiveChat(String committeeId) async {
    try {
      await FirebaseFirestore.instance
          .collection('committee_chats')
          .doc(committeeId)
          .update({
        'status': 'archived',
        'archivedFor.${widget.userId}': true,
        'archivedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Chat archived'),
            backgroundColor: AppColors.goldColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppColors.r12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to archive: ${e.toString()}'),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}