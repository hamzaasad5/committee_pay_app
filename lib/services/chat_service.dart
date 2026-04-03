import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Send message to committee chat
  Future<void> sendMessage({
    required String committeeId,
    required String message,
    String? imageUrl,
    String? fileName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ No authenticated user found');
      throw Exception('User not authenticated');
    }

    print('📤 Sending message to committee: $committeeId');

    try {
      // Create a message reference first to get the ID
      final messageRef = _firestore.collection('committee_chats').doc();
      final messageId = messageRef.id;
      print('📝 Generated message ID: $messageId');

      // Get user details
      final userName = await _getUserName(user.uid);
      final userPhoto = await _getUserPhoto(user.uid);
      print('👤 Sender name: $userName');

      final messageData = {
        'messageId': messageId,
        'committeeId': committeeId,
        'senderId': user.uid,
        'senderName': userName,
        'senderPhoto': userPhoto,
        'message': message.trim(),
        'imageUrl': imageUrl,
        'fileName': fileName,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sending',
        'readBy': [user.uid],
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Add message with sending status
      await messageRef.set(messageData);
      print('✅ Message saved with status: sending');

      // After successful save, update status to 'sent'
      await messageRef.update({
        'status': 'sent',
        'sentAt': FieldValue.serverTimestamp(),
      });
      print('✅ Status updated to: sent');

      // Update last message in committee document
      final committeeRef = _firestore.collection('committees').doc(committeeId);
      final committeeDoc = await committeeRef.get();

      if (committeeDoc.exists) {
        await committeeRef.update({
          'lastMessage': message.isNotEmpty ? message : '📷 Image',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageSender': user.uid,
          'lastMessageSenderName': userName,
        });
        print('✅ Committee last message updated');
      } else {
        print('⚠️ Committee document not found, skipping update');
      }

      print('🎉 Message sent successfully!');
    } catch (e) {
      print('❌ Error sending message: $e');
      rethrow;
    }
  }

  // Mark message as delivered
  Future<void> markMessageAsDelivered(String messageId, String userId) async {
    try {
      final messageDoc = await _firestore.collection('committee_chats').doc(messageId).get();
      final messageData = messageDoc.data();

      if (messageData != null && messageData['senderId'] != userId) {
        final currentStatus = messageData['status'] as String?;
        if (currentStatus == 'sent') {
          await _firestore.collection('committee_chats').doc(messageId).update({
            'status': 'delivered',
            'deliveredAt': FieldValue.serverTimestamp(),
          });
          print('✅ Message marked as delivered: $messageId');
        }
      }
    } catch (e) {
      print('❌ Error marking message as delivered: $e');
    }
  }

  // Mark message as read
  Future<void> markMessageAsRead(String messageId, String userId) async {
    try {
      final messageDoc = await _firestore.collection('committee_chats').doc(messageId).get();
      final messageData = messageDoc.data();

      if (messageData != null && messageData['senderId'] != userId) {
        final readBy = List<String>.from(messageData['readBy'] ?? []);

        if (!readBy.contains(userId)) {
          await _firestore.collection('committee_chats').doc(messageId).update({
            'readBy': FieldValue.arrayUnion([userId]),
            'status': 'read',
            'readAt': FieldValue.serverTimestamp(),
          });
          print('✅ Message marked as read: $messageId');
        }
      }
    } catch (e) {
      print('❌ Error marking message as read: $e');
    }
  }

  // Get messages for a committee
  Stream<QuerySnapshot> getMessages(String committeeId) {
    final currentUserId = _auth.currentUser?.uid;

    return _firestore
        .collection('committee_chats')
        .where('committeeId', isEqualTo: committeeId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .handleError((error) {
      print('❌ Error in getMessages stream: $error');
      return Stream.error(error);
    })
        .asyncMap((snapshot) async {
      // Mark messages as delivered when they are fetched
      if (currentUserId != null && snapshot.docs.isNotEmpty) {
        for (var doc in snapshot.docs) {
          final messageData = doc.data() as Map<String, dynamic>;
          final messageId = doc.id;
          final status = messageData['status'] as String?;
          final senderId = messageData['senderId'] as String;

          // If message is sent and current user is not the sender, mark as delivered
          if (status == 'sent' && senderId != currentUserId) {
            await markMessageAsDelivered(messageId, currentUserId);
          }
        }
      }
      return snapshot;
    });
  }

  // Listen for message status changes in real-time - FIXED return type
  Stream<Map<String, dynamic>> getMessageStatus(String messageId) {
    return _firestore
        .collection('committee_chats')
        .doc(messageId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          // Cast to Map<String, dynamic> explicitly
          return Map<String, dynamic>.from(data);
        }
      }
      return <String, dynamic>{};
    })
        .handleError((error) {
      print('❌ Error getting message status: $error');
      return Stream.error(error);
    });
  }

  // Get unread count for a committee
  Stream<int> getUnreadCount(String committeeId, String userId) {
    return _firestore
        .collection('committee_chats')
        .where('committeeId', isEqualTo: committeeId)
        .where('senderId', isNotEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      int unreadCount = 0;
      for (var doc in snapshot.docs) {
        final readBy = List<String>.from(doc['readBy'] ?? []);
        if (!readBy.contains(userId)) {
          unreadCount++;
        }
      }
      return unreadCount;
    })
        .handleError((error) {
      print('❌ Error getting unread count: $error');
      return Stream.value(0);
    });
  }

  // Get all unread counts for user's committees
  Stream<Map<String, int>> getAllUnreadCounts(List<String> committeeIds, String userId) {
    if (committeeIds.isEmpty) {
      return Stream.value({});
    }

    return _firestore
        .collection('committee_chats')
        .where('committeeId', whereIn: committeeIds)
        .where('senderId', isNotEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final Map<String, int> unreadCounts = {};

      for (var doc in snapshot.docs) {
        final committeeId = doc['committeeId'];
        final readBy = List<String>.from(doc['readBy'] ?? []);

        if (!readBy.contains(userId)) {
          unreadCounts[committeeId] = (unreadCounts[committeeId] ?? 0) + 1;
        }
      }

      return unreadCounts;
    })
        .handleError((error) {
      print('❌ Error getting all unread counts: $error');
      return Stream.value({});
    });
  }

  // Get user name
  Future<String> _getUserName(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data()?['name'] ?? 'Unknown User';
      }
      return 'Unknown User';
    } catch (e) {
      print('❌ Error getting user name: $e');
      return 'Unknown User';
    }
  }

  // Get user photo
  Future<String> _getUserPhoto(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data()?['photoUrl'] ?? '';
      }
      return '';
    } catch (e) {
      print('❌ Error getting user photo: $e');
      return '';
    }
  }

  // Update online status
  Future<void> updateOnlineStatus(String committeeId, String userId, bool isOnline) async {
    try {
      await _firestore
          .collection('committees')
          .doc(committeeId)
          .collection('members')
          .doc(userId)
          .set({
        'userId': userId,
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('✅ Online status updated: $userId isOnline: $isOnline');
    } catch (e) {
      print('❌ Error updating online status: $e');
    }
  }

  // Get online members count
  Stream<int> getOnlineMembersCount(String committeeId) {
    return _firestore
        .collection('committees')
        .doc(committeeId)
        .collection('members')
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.length)
        .handleError((error) {
      print('❌ Error getting online members count: $error');
      return Stream.value(0);
    });
  }

  // Get members count
  Stream<int> getMembersCount(String committeeId) {
    return _firestore
        .collection('committees')
        .doc(committeeId)
        .collection('members')
        .snapshots()
        .map((snapshot) => snapshot.docs.length)
        .handleError((error) {
      print('❌ Error getting members count: $error');
      return Stream.value(0);
    });
  }

  // Get committee members as stream
  Stream<List<Map<String, dynamic>>> getCommitteeMembersStream(String committeeId) {
    return _firestore
        .collection('committees')
        .doc(committeeId)
        .collection('members')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'userId': doc.id,
          'name': data['name'] ?? 'Unknown',
          'email': data['email'] ?? '',
          'avatar': data['avatar'] ?? '',
          'isOnline': data['isOnline'] ?? false,
          'lastSeen': data['lastSeen'],
        };
      }).toList();
    })
        .handleError((error) {
      print('❌ Error getting committee members stream: $error');
      return Stream.value([]);
    });
  }

  // Get committee members (single fetch)
  Future<List<Map<String, dynamic>>> getCommitteeMembers(String committeeId) async {
    try {
      final snapshot = await _firestore
          .collection('committees')
          .doc(committeeId)
          .collection('members')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'userId': doc.id,
          'name': data['name'] ?? 'Unknown',
          'avatar': data['avatar'] ?? '',
          'email': data['email'] ?? '',
          'isOnline': data['isOnline'] ?? false,
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting committee members: $e');
      return [];
    }
  }

  // Add member to committee chat
  Future<void> addMemberToChat(String committeeId, String userId, String userName) async {
    try {
      await _firestore
          .collection('committees')
          .doc(committeeId)
          .collection('members')
          .doc(userId)
          .set({
        'userId': userId,
        'name': userName,
        'isOnline': false,
        'joinedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('✅ Member added to chat: $userId');
    } catch (e) {
      print('❌ Error adding member to chat: $e');
    }
  }

  // Get typing status
  Stream<Map<String, bool>> getTypingStatus(String committeeId) {
    return _firestore
        .collection('committees')
        .doc(committeeId)
        .collection('typing')
        .snapshots()
        .map((snapshot) {
      final Map<String, bool> typingUsers = {};
      for (var doc in snapshot.docs) {
        typingUsers[doc.id] = doc['isTyping'] ?? false;
      }
      return typingUsers;
    })
        .handleError((error) {
      print('❌ Error getting typing status: $error');
      return Stream.value({});
    });
  }

  // Set typing status
  Future<void> setTypingStatus(String committeeId, String userId, bool isTyping) async {
    try {
      await _firestore
          .collection('committees')
          .doc(committeeId)
          .collection('typing')
          .doc(userId)
          .set({
        'isTyping': isTyping,
        'userId': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('❌ Error setting typing status: $e');
    }
  }

  // Mark all messages as read
  Future<void> markAllMessagesAsRead(String committeeId, String userId) async {
    try {
      final messages = await _firestore
          .collection('committee_chats')
          .where('committeeId', isEqualTo: committeeId)
          .where('senderId', isNotEqualTo: userId)
          .get();

      for (var doc in messages.docs) {
        final readBy = List<String>.from(doc['readBy'] ?? []);
        if (!readBy.contains(userId)) {
          await doc.reference.update({
            'readBy': FieldValue.arrayUnion([userId]),
            'status': 'read',
            'readAt': FieldValue.serverTimestamp(),
          });
        }
      }
      print('✅ All messages marked as read for user: $userId');
    } catch (e) {
      print('❌ Error marking all messages as read: $e');
    }
  }

  // Delete message
  Future<void> deleteMessage(String messageId) async {
    try {
      await _firestore.collection('committee_chats').doc(messageId).delete();
      print('✅ Message deleted: $messageId');
    } catch (e) {
      print('❌ Error deleting message: $e');
    }
  }

  // Search messages
  Stream<QuerySnapshot> searchMessages(String committeeId, String searchQuery) {
    if (searchQuery.isEmpty) {
      return Stream.empty();
    }

    return _firestore
        .collection('committee_chats')
        .where('committeeId', isEqualTo: committeeId)
        .where('message', isGreaterThanOrEqualTo: searchQuery)
        .where('message', isLessThanOrEqualTo: '$searchQuery\uf8ff')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .handleError((error) {
      print('❌ Error searching messages: $error');
      return Stream.error(error);
    });
  }

  // Get media messages
  Stream<QuerySnapshot> getMediaMessages(String committeeId) {
    return _firestore
        .collection('committee_chats')
        .where('committeeId', isEqualTo: committeeId)
        .where('imageUrl', isNotEqualTo: null)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .handleError((error) {
      print('❌ Error getting media messages: $error');
      return Stream.error(error);
    });
  }

  // Get user details
  Future<Map<String, dynamic>?> getUserDetails(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data();
      }
      return null;
    } catch (e) {
      print('❌ Error getting user details: $e');
      return null;
    }
  }

  /// Send system message(not used)
  Future<void> sendSystemMessage(String committeeId, String message) async {
    try {
      final messageRef = _firestore.collection('committee_chats').doc();
      final messageId = messageRef.id;

      await messageRef.set({
        'messageId': messageId,
        'committeeId': committeeId,
        'senderId': 'system',
        'senderName': 'System',
        'message': message,
        'type': 'system',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sent',
        'readBy': [],
      });
      print('✅ System message sent: $message');
    } catch (e) {
      print('❌ Error sending system message: $e');
    }
  }

  // Clean up offline members (run periodically)
  Future<void> cleanupOfflineMembers(String committeeId) async {
    try {
      final cutoffTime = DateTime.now().subtract(const Duration(minutes: 5));
      final offlineMembers = await _firestore
          .collection('committees')
          .doc(committeeId)
          .collection('members')
          .where('isOnline', isEqualTo: false)
          .where('lastSeen', isLessThan: cutoffTime)
          .get();

      for (var doc in offlineMembers.docs) {
        await doc.reference.delete();
      }
      print('✅ Cleaned up ${offlineMembers.docs.length} offline members');
    } catch (e) {
      print('❌ Error cleaning up offline members: $e');
    }
  }
}