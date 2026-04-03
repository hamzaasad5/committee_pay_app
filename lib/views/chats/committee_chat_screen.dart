import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:committee_pay_app/views/chats/widgets/committee_media_screen.dart';
import 'package:committee_pay_app/views/chats/widgets/full_image_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/committees_provider.dart';
import '../../../services/chat_service.dart';
import '../../../services/image_upload_service.dart';
import '../my_committees/committee_members_screen.dart';

class CommitteeChatScreen extends StatefulWidget {
  final String committeeId;
  final String committeeName;
  final String? committeeImage;

  const CommitteeChatScreen({
    Key? key,
    required this.committeeId,
    required this.committeeName,
    this.committeeImage,
  }) : super(key: key);

  @override
  State<CommitteeChatScreen> createState() => _CommitteeChatScreenState();
}

class _CommitteeChatScreenState extends State<CommitteeChatScreen> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  late ChatService _chatService;
  late CommitteesProvider _committeesProvider;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _isSending = false;
  bool _isUploading = false;
  File? _selectedImage;
  String? _fileName;
  Map<String, String> _userNames = {};
  Map<String, String> _userAvatars = {};
  List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;
  Timer? _typingTimer;
  String? _currentUserId;
  bool _isLoading = true;
  String? _committeeAdminId;
  Map<String, dynamic>? _committeeData;
  Set<String> _previousMembers = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
    _setupListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _markAllMessagesAsRead();
      _updateOnlineStatus(true);
    } else if (state == AppLifecycleState.paused) {
      _updateOnlineStatus(false);
    }
  }

  void _initializeServices() {
    _chatService = ChatService();
    _committeesProvider = CommitteesProvider();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;

    _markAllMessagesAsRead();
    _fetchCommitteeMembers();
    _fetchCommitteeAdmin();
    _setupTypingListener();
    _setupMessageReadReceipts();
    _updateOnlineStatus(true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      setState(() => _isLoading = false);
    });
  }

  void _setupListeners() {
    // Listen for member changes to show system messages
    FirebaseFirestore.instance
        .collection('committees')
        .doc(widget.committeeId)
        .snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
        final data = doc.data();
        final membersMap = Map<String, bool>.from(data?['membersMap'] ?? {});
        final currentMembers = membersMap.keys.toSet();

        // Check for new members
        final newMembers = currentMembers.difference(_previousMembers);

        if (newMembers.isNotEmpty && _previousMembers.isNotEmpty) {
          for (var newMemberId in newMembers) {
            final newMemberName = _userNames[newMemberId] ?? 'A new member';
            _sendSystemMessage('$newMemberName has joined the ${widget.committeeName} committee');
          }
        }

        _previousMembers = currentMembers;

        // Update committee data
        _committeeData = data;
        _committeeAdminId = data?['adminId'];
      }
    });
  }

  Future<void> _fetchCommitteeAdmin() async {
    try {
      final committeeDoc = await FirebaseFirestore.instance
          .collection('committees')
          .doc(widget.committeeId)
          .get();

      if (committeeDoc.exists) {
        final data = committeeDoc.data();
        _committeeAdminId = data?['adminId'];
        _committeeData = data;

        // Initialize previous members set
        final membersMap = Map<String, bool>.from(data?['membersMap'] ?? {});
        _previousMembers = membersMap.keys.toSet();
      }
    } catch (e) {
      print('Error fetching committee admin: $e');
    }
  }

  Future<void> _sendSystemMessage(String message) async {
    try {
      await _chatService.sendSystemMessage(widget.committeeId, message);
      print('✅ System message sent: $message');
    } catch (e) {
      print('❌ Error sending system message: $e');
    }
  }

  @override
  void dispose() {
    _updateOnlineStatus(false);
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    _committeesProvider.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _setupTypingListener() {
    _messageController.addListener(() {
      if (_messageController.text.isNotEmpty && !_isTyping) {
        _setTypingStatus(true);
      } else if (_messageController.text.isEmpty && _isTyping) {
        _setTypingStatus(false);
      }
    });
  }

  void _setTypingStatus(bool typing) {
    if (typing == _isTyping) return;
    _isTyping = typing;
    _chatService.setTypingStatus(
      widget.committeeId,
      _currentUserId!,
      typing,
    );

    if (_typingTimer != null) _typingTimer!.cancel();
    if (typing) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _setTypingStatus(false);
      });
    }
  }

  void _setupMessageReadReceipts() {
    _chatService.getMessages(widget.committeeId).listen((QuerySnapshot snapshot) {
      if (_currentUserId != null) {
        for (var doc in snapshot.docs) {
          final messageData = doc.data() as Map<String, dynamic>;
          final messageId = doc.id;
          final senderId = messageData['senderId'];
          final status = messageData['status'];

          if (senderId != _currentUserId && status == 'delivered') {
            _chatService.markMessageAsRead(messageId, _currentUserId!);
          }
        }
      }
    });
  }

  Future<void> _markAllMessagesAsRead() async {
    if (_currentUserId == null) return;
    await _chatService.markAllMessagesAsRead(widget.committeeId, _currentUserId!);
  }

  Future<void> _updateOnlineStatus(bool isOnline) async {
    if (_currentUserId == null) return;
    await _chatService.updateOnlineStatus(widget.committeeId, _currentUserId!, isOnline);
  }

  Future<void> _fetchCommitteeMembers() async {
    try {
      final members = await _chatService.getCommitteeMembers(widget.committeeId);
      for (var member in members) {
        setState(() {
          _userNames[member['userId']] = member['name'] ?? 'Unknown';
          _userAvatars[member['userId']] = member['avatar'] ?? '';
        });
      }
    } catch (e) {
      print('Error fetching members: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty && _selectedImage == null) return;
    if (_isSending || _isUploading) return;

    setState(() => _isSending = true);

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        setState(() => _isUploading = true);
        imageUrl = await ImageUploadService.uploadImage(
          _selectedImage!,
          'committee_chats/${widget.committeeId}',
        );
        setState(() => _isUploading = false);
      }

      await _chatService.sendMessage(
        committeeId: widget.committeeId,
        message: _messageController.text.trim(),
        imageUrl: imageUrl,
        fileName: _fileName,
      );

      _messageController.clear();
      _selectedImage = null;
      _fileName = null;
      _setTypingStatus(false);

      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error sending message: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _fileName = pickedFile.name;
      });
      _focusNode.unfocus();
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _fileName = pickedFile.name;
      });
      _focusNode.unfocus();
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppColors.r20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: AppColors.goldColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.goldSoft,
                    borderRadius: BorderRadius.circular(AppColors.r12),
                  ),
                  child: Icon(Icons.photo_library, color: AppColors.goldColor),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.goldSoft,
                    borderRadius: BorderRadius.circular(AppColors.r12),
                  ),
                  child: Icon(Icons.camera_alt, color: AppColors.goldColor),
                ),
                title: const Text('Take a Photo', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageOptions(Map<String, dynamic> message) {
    final isMe = message['senderId'] == _currentUserId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppColors.r20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: AppColors.goldColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              if (message['imageUrl'] != null)
                ListTile(
                  leading: Icon(Icons.download, color: AppColors.goldColor),
                  title: const Text('Save Image', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _saveImage(message['imageUrl']);
                  },
                ),
              if (message['message'] != null && message['message'].toString().isNotEmpty)
                ListTile(
                  leading: Icon(Icons.copy, color: AppColors.goldColor),
                  title: const Text('Copy Text', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _copyToClipboard(message['message']);
                  },
                ),
              if (isMe)
                ListTile(
                  leading: Icon(Icons.delete, color: AppColors.red),
                  title: const Text('Delete for Everyone', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteConfirmation(message['messageId']);
                  },
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(String text) {
    _showSnackBar('Copied to clipboard');
  }

  void _saveImage(String imageUrl) async {
    _showSnackBar('Image saved to gallery');
  }

  void _showDeleteConfirmation(String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.r16),
        ),
        title: const Text('Delete Message', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this message?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _chatService.deleteMessage(messageId);
              _showSnackBar('Message deleted');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.r8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.red : AppColors.goldColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.r12),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final names = name.split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.goldColor),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessages(widget.committeeId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildErrorWidget(snapshot.error.toString());
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.goldColor),
                  );
                }

                final messages = snapshot.data!.docs;

                if (messages.isEmpty) {
                  return _buildEmptyState();
                }

                return Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      reverse: true,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final doc = messages[messages.length - 1 - index];
                        final message = doc.data() as Map<String, dynamic>;
                        final messageId = doc.id;
                        final messageType = message['type'];

                        // Check if it's a system message
                        if (messageType == 'system') {
                          return _buildSystemMessage(message);
                        }

                        final isMe = message['senderId'] == _currentUserId;
                        final senderName = message['senderName'] ?? _userNames[message['senderId']] ?? 'Unknown';
                        final senderAvatar = _userAvatars[message['senderId']];
                        final messageStatus = message['status'] as String? ?? 'sent';
                        final isCreator = message['senderId'] == _committeeAdminId;

                        return GestureDetector(
                          onLongPress: () => _showMessageOptions(message),
                          child: _buildMessageBubble(
                            message: message,
                            isMe: isMe,
                            senderName: senderName,
                            senderAvatar: senderAvatar,
                            messageStatus: messageStatus,
                            messageId: messageId,
                            isCreator: isCreator,
                          ),
                        );
                      },
                    ),
                    StreamBuilder<Map<String, bool>>(
                      stream: _chatService.getTypingStatus(widget.committeeId),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox();

                        final typingUsers = snapshot.data!.entries
                            .where((e) => e.value && e.key != _currentUserId)
                            .toList();

                        if (typingUsers.isEmpty) return const SizedBox();

                        return Positioned(
                          bottom: 10,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceDark,
                              borderRadius: BorderRadius.circular(AppColors.r20),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.goldColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_userNames[typingUsers.first.key]} is typing...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          if (_selectedImage != null) _buildImagePreview(),
          if (_isUploading) _buildUploadProgress(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildSystemMessage(Map<String, dynamic> message) {
    final text = message['message'] ?? '';
    final timestamp = (message['timestamp'] as Timestamp?)?.toDate();
    final formattedTime = timestamp != null
        ? DateFormat('hh:mm a').format(timestamp)
        : '';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.goldColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.goldColor.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: AppColors.goldColor,
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.goldColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (formattedTime.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  formattedTime,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.goldColor.withOpacity(0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble({
    required Map<String, dynamic> message,
    required bool isMe,
    required String senderName,
    String? senderAvatar,
    required String messageStatus,
    required String messageId,
    required bool isCreator,
  }) {
    final timestamp = (message['timestamp'] as Timestamp?)?.toDate();
    final formattedTime = timestamp != null
        ? DateFormat('hh:mm a').format(timestamp)
        : 'Sending...';
    final isImageMessage = message['imageUrl'] != null;
    final hasText = message['message'] != null && message['message'].toString().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _showUserProfile(message['senderId']),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.goldColor,
                        AppColors.goldColor.withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(senderName),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: isMe ? AppColors.goldColor : AppColors.surfaceDark,
                borderRadius: _getBubbleBorderRadius(isMe, isImageMessage),
                border: !isMe ? Border.all(color: AppColors.border) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCreator ? Icons.star : Icons.person,
                            size: 12,
                            color: isCreator ? AppColors.goldColor : AppColors.goldColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            senderName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppColors.goldColor,
                            ),
                          ),
                          if (isCreator) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.goldColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Creator',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: AppColors.goldColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (isImageMessage) ...[
                    GestureDetector(
                      onTap: () => _showFullImage(message['imageUrl']),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: message['imageUrl'],
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 200,
                            color: AppColors.surface2,
                            child: const Center(
                              child: CircularProgressIndicator(color: AppColors.goldColor),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 200,
                            color: AppColors.surface2,
                            child: Icon(Icons.error, color: AppColors.red),
                          ),
                        ),
                      ),
                    ),
                    if (hasText) const SizedBox(height: 8),
                  ],
                  if (hasText)
                    Padding(
                      padding: EdgeInsets.only(
                        left: 12,
                        right: 12,
                        top: isImageMessage ? 0 : 8,
                        bottom: 4,
                      ),
                      child: Text(
                        message['message'],
                        style: TextStyle(
                          color: isMe ? Colors.white : Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formattedTime,
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe
                                ? Colors.white70
                                : AppColors.textSecondary,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          _buildMessageStatusIcon(messageStatus),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BorderRadius _getBubbleBorderRadius(bool isMe, bool isImageMessage) {
    if (isMe) {
      return BorderRadius.only(
        topLeft: const Radius.circular(16),
        topRight: const Radius.circular(16),
        bottomLeft: const Radius.circular(16),
        bottomRight: const Radius.circular(4),
      );
    } else {
      return BorderRadius.only(
        topLeft: const Radius.circular(16),
        topRight: const Radius.circular(16),
        bottomLeft: const Radius.circular(4),
        bottomRight: const Radius.circular(16),
      );
    }
  }

  Widget _buildMessageStatusIcon(String status) {
    switch (status) {
      case 'sending':
        return Icon(Icons.hourglass_empty, size: 12, color: Colors.white70);
      case 'sent':
        return Icon(Icons.check, size: 12, color: Colors.white70);
      case 'delivered':
        return Icon(Icons.done_all, size: 12, color: Colors.white70);
      case 'read':
        return Icon(Icons.done_all, size: 12, color: AppColors.goldColor);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildImagePreview() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              _selectedImage!,
              height: 50,
              width: 50,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fileName ?? 'Image',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap send to upload',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: AppColors.red),
            onPressed: () {
              setState(() {
                _selectedImage = null;
                _fileName = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUploadProgress() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: AppColors.goldSoft,
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.goldColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Uploading image...',
              style: TextStyle(color: AppColors.goldColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.add,
              color: AppColors.goldColor,
              size: 28,
            ),
            onPressed: _showImageOptions,
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) {
                  if (_messageController.text.trim().isNotEmpty || _selectedImage != null) {
                    _sendMessage();
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 4),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _messageController,
            builder: (context, value, child) {
              final hasText = value.text.trim().isNotEmpty;
              final hasImage = _selectedImage != null;
              final canSend = (hasText || hasImage) && !_isSending;

              return Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: canSend ? AppColors.goldColor : AppColors.textSecondary.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    _isSending ? Icons.hourglass_empty : Icons.send,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: canSend ? _sendMessage : null,
                ),
              );
            },
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.goldSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: AppColors.goldColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Messages Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start the conversation by sending a message',
            style: TextStyle(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
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
            'Error loading messages',
            style: TextStyle(color: AppColors.red),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() {}),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.goldColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.r12),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _showFullImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullImageScreen(imageUrl: imageUrl),
      ),
    );
  }

  void _showUserProfile(String userId) {
    _showSnackBar('User profile coming soon');
  }

  void _showGroupInfoDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppColors.r20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: AppColors.goldColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.goldColor,
                    AppColors.goldColor.withOpacity(0.7),
                  ],
                ),
              ),
              child: Center(
                child: widget.committeeImage != null
                    ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: widget.committeeImage!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Text(
                      _getInitials(widget.committeeName),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
                    : Text(
                  _getInitials(widget.committeeName),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.committeeName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<int>(
              stream: _chatService.getMembersCount(widget.committeeId),
              builder: (context, snapshot) {
                return Text(
                  '${snapshot.data ?? 0} members',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            _buildInfoTile(
              icon: Icons.people_outline,
              title: 'Members',
              onTap: () {
                Navigator.pop(context);
                _showMembersList();
              },
            ),
            _buildInfoTile(
              icon: Icons.photo_library_outlined,
              title: 'Media',
              onTap: () {
                Navigator.pop(context);
                _showMediaGallery();
              },
            ),
            _buildInfoTile(
              icon: Icons.search_outlined,
              title: 'Search Messages',
              onTap: () {
                Navigator.pop(context);
                _showSearchMessages();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.goldSoft,
          borderRadius: BorderRadius.circular(AppColors.r12),
        ),
        child: Icon(icon, color: AppColors.goldColor),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }

  void _showMembersList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommitteeMembersScreen(
          committeeId: widget.committeeId,
        ),
      ),
    );
  }

  void _showMediaGallery() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommitteeMediaScreen(
          committeeId: widget.committeeId,
          committeeName: widget.committeeName,
        ),
      ),
    );
  }

  void _showSearchMessages() {
    showSearch(
      context: context,
      delegate: MessageSearchDelegate(_chatService, widget.committeeId),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surfaceDark,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: AppColors.goldColor),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.goldColor,
                  AppColors.goldColor.withOpacity(0.7),
                ],
              ),
            ),
            child: Center(
              child: widget.committeeImage != null
                  ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: widget.committeeImage!,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Text(
                    _getInitials(widget.committeeName),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
                  : Text(
                _getInitials(widget.committeeName),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.committeeName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                StreamBuilder<int>(
                  stream: _chatService.getOnlineMembersCount(widget.committeeId),
                  builder: (context, snapshot) {
                    final onlineCount = snapshot.data ?? 0;
                    return Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: onlineCount > 0 ? AppColors.green : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          onlineCount > 0 ? '$onlineCount online' : 'Offline',
                          style: TextStyle(
                            fontSize: 11,
                            color: onlineCount > 0 ? AppColors.green : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.search, color: AppColors.goldColor),
          onPressed: () => _showSearchMessages(),
        ),
        IconButton(
          icon: Icon(Icons.more_vert, color: AppColors.goldColor),
          onPressed: () => _showGroupInfoDialog(),
        ),
      ],
    );
  }
}

// Message Search Delegate (same as before)
class MessageSearchDelegate extends SearchDelegate {
  final ChatService _chatService;
  final String committeeId;

  MessageSearchDelegate(this._chatService, this.committeeId);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear, color: AppColors.goldColor),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back, color: AppColors.goldColor),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: AppColors.goldColor.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Type a message to search...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.searchMessages(committeeId, query),
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
                  'Error: ${snapshot.error}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.goldColor),
          );
        }

        final messages = snapshot.data!.docs;

        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: AppColors.goldColor.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No messages found',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try searching with different keywords',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index].data() as Map<String, dynamic>;
            final timestamp = (message['timestamp'] as Timestamp?)?.toDate();
            final formattedTime = timestamp != null
                ? DateFormat('MMM dd, hh:mm a').format(timestamp)
                : '';
            final isImage = message['imageUrl'] != null;
            final messageText = isImage ? '📷 Image' : (message['message'] ?? '');

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    close(context, null);
                  },
                  borderRadius: BorderRadius.circular(AppColors.r12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(AppColors.r12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.goldColor,
                                AppColors.goldColor.withOpacity(0.7),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              message['senderName']?[0]?.toUpperCase() ?? '?',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message['senderName'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                messageText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formattedTime,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isImage)
                          Icon(
                            Icons.image,
                            size: 20,
                            color: AppColors.goldColor,
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
    );
  }
}