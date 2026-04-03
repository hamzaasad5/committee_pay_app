import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class CommitteesProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool isLoading = false;
  String? error;
  List<Map<String, dynamic>> committees = [];
  StreamSubscription? _subscription;

  /// Fetch all committees for a user (creator or joined member)
  Future<void> fetchUserCommittees(String userId) {
    print("🔹 fetchUserCommittees called for userId: $userId");
    isLoading = true;
    error = null;
    committees = [];
    notifyListeners();

    _subscription?.cancel();

    final completer = Completer<void>();

    _subscription = _db
        .collection("committees")
        .orderBy("createdAt", descending: true)
        .snapshots()
        .listen((snapshot) {
      print("📌 Firestore snapshot received: ${snapshot.docs.length} documents");

      committees = snapshot.docs.map((doc) {
        final data = doc.data();
        data["id"] = doc.id;
        return data;
      }).where((committee) {
        if (committee["adminId"] == userId) return true;
        Map membersMap = Map<String, dynamic>.from(committee["membersMap"] ?? {});
        return membersMap[userId] == true;
      }).toList();

      for (var c in committees) {
        print("📄 Committee fetched: ${c['name']} with ID: ${c['id']}");
      }

      isLoading = false;
      error = null;
      print("✅ Committees list updated, total: ${committees.length}");
      notifyListeners();

      if (!completer.isCompleted) {
        completer.complete();
      }
    }, onError: (e) {
      error = e.toString();
      isLoading = false;
      print("❌ Error fetching committees: $error");
      notifyListeners();

      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    });

    return completer.future;
  }

  /// Add a new committee (creator becomes initial member)
  Future<String?> addCommittee({
    required String name,
    required int monthlyAmount,
    required int totalMembers,
    required List<Map<String, String>> memberPhones,
    required DateTime startMonth,
    required DateTime endMonth,
    required String creatorId,
    required String creatorName,
    required String type,
    required int totalAmount,
    required String committeeCode,
  }) async {
    try {
      Map<String, bool> membersMap = {};
      Map<String, Map<String, dynamic>> membersPayments = {};
      List<Map<String, dynamic>> members = [];
      List<String> allMemberIds = [];

      // Add creator
      membersMap[creatorId] = true;
      members.add({
        "name": creatorName,
        "uid": creatorId,
        "status": "Joined",
        "payments": {},
      });
      allMemberIds.add(creatorId);

      // Add invited members
      for (var member in memberPhones) {
        String phone = member["phone"]!;
        String memberName = member["name"]!;
        membersMap[phone] = false;
        members.add({
          "name": memberName,
          "phone": phone,
          "status": "Pending",
          "payments": {},
        });
        allMemberIds.add(phone);
      }

      final docRef = await _db.collection("committees").add({
        "name": name,
        "adminName": creatorName,
        "adminId": creatorId,
        "monthlyAmount": monthlyAmount,
        "totalMembers": totalMembers,
        "totalAmount": totalAmount,
        "committeeCode": committeeCode,
        "perMemberAmount": type == "monthly" ? monthlyAmount ~/ totalMembers : null,
        "members": members,
        "membersMap": membersMap,
        "membersPayments": membersPayments,
        "startMonth": startMonth,
        "endMonth": endMonth,
        "type": type,
        "status": "Active",
        "winners": {},
        "createdAt": FieldValue.serverTimestamp(),
      });

      // Create chat document for this committee
      await _createChatDocument(
        committeeId: docRef.id,
        committeeName: name,
        committeeImage: null,
        creatorId: creatorId,
        creatorName: creatorName,
        members: allMemberIds,
      );

      // Create activity for committee creation
      await FirebaseFirestore.instance.collection("activity").add({
        "userId": creatorId,
        "type": "committee_created",
        "committeeId": docRef.id,
        "committeeName": name,
        "timestamp": Timestamp.now(),
        "details": "Created committee: $name",
      });

      // Create separate activity entries for invited members
      for (var member in memberPhones) {
        await FirebaseFirestore.instance.collection("activity").add({
          "userId": member["phone"],
          "type": "committee_invitation",
          "committeeId": docRef.id,
          "committeeName": name,
          "timestamp": Timestamp.now(),
          "details": "Invited to committee: $name",
        });
      }

      return docRef.id;
    } catch (e) {
      print("❌ Error adding committee: $e");
      return null;
    }
  }

  /// Create or update chat document when a member joins
  Future<void> createOrUpdateChatOnJoin({
    required String committeeId,
    required String committeeName,
    String? committeeImage,
    required String userId,
    required String userName,
  }) async {
    try {
      final chatRef = _db.collection('committee_chats').doc(committeeId);
      final chatDoc = await chatRef.get();

      // Get all current members from committee document
      final committeeDoc = await _db.collection('committees').doc(committeeId).get();
      if (!committeeDoc.exists) return;

      final committeeData = committeeDoc.data()!;
      final membersMap = Map<String, bool>.from(committeeData['membersMap'] ?? {});
      final participants = membersMap.keys.toList();

      if (!chatDoc.exists) {
        // Create new chat document
        // Get participant names
        final participantNames = await _getParticipantNames(participants);

        // Initialize unread counts
        final Map<String, int> unreadCounts = {};
        for (var participant in participants) {
          unreadCounts[participant] = 0;
        }

        // Create the chat document
        await chatRef.set({
          'committeeId': committeeId,
          'committeeName': committeeName,
          'committeeImage': committeeImage,
          'participants': participants,
          'participantNames': participantNames,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': participants.isNotEmpty ? participants.first : userId,
          'createdByName': participantNames[participants.isNotEmpty ? participants.first : userId] ?? userName,
          'lastMessage': 'Welcome to the committee!',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageSender': userId,
          'lastMessageSenderName': userName,
          'unreadCounts': unreadCounts,
          'status': 'active',
        });

        print('✅ Chat document created for committee: $committeeId');
      } else {
        // Update existing chat with new member
        await chatRef.update({
          'participants': FieldValue.arrayUnion([userId]),
          'participantNames.$userId': userName,
          'unreadCounts.$userId': 0,
        });

        print('✅ Chat document updated for committee: $committeeId');
      }

      // Add system message about new member joining
      await _addJoinSystemMessage(committeeId, userName, committeeName);

    } catch (e) {
      print('❌ Error creating/updating chat document: $e');
    }
  }

  /// Helper method to create chat document
  Future<void> _createChatDocument({
    required String committeeId,
    required String committeeName,
    String? committeeImage,
    required String creatorId,
    required String creatorName,
    required List<String> members,
  }) async {
    try {
      List<String> participantIds = [];

      for (var member in members) {
        // Check if member is a phone number or user ID
        if (member.contains('@') || member.length > 10) {
          participantIds.add(member);
        } else {
          // It's a phone number, need to find user ID
          final userDoc = await _db
              .collection('users')
              .where('phone', isEqualTo: member)
              .limit(1)
              .get();

          if (userDoc.docs.isNotEmpty) {
            participantIds.add(userDoc.docs.first.id);
          } else {
            participantIds.add(member);
          }
        }
      }

      // Initialize unread counts for all participants
      final Map<String, int> unreadCounts = {};
      for (var participant in participantIds) {
        unreadCounts[participant] = 0;
      }

      // Create the chat document
      await _db.collection('committee_chats').doc(committeeId).set({
        'committeeId': committeeId,
        'committeeName': committeeName,
        'committeeImage': committeeImage,
        'participants': participantIds,
        'participantNames': await _getParticipantNames(participantIds),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': creatorId,
        'createdByName': creatorName,
        'lastMessage': 'Committee created. Start the conversation!',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': creatorId,
        'lastMessageSenderName': creatorName,
        'unreadCounts': unreadCounts,
        'status': 'active',
      });

      print('✅ Chat document created for committee: $committeeId');

      // Create welcome message
      await _createWelcomeMessage(committeeId, creatorId, creatorName, committeeName);

    } catch (e) {
      print('❌ Error creating chat document: $e');
    }
  }

  /// Get participant names from user IDs
  Future<Map<String, String>> _getParticipantNames(List<String> userIds) async {
    final Map<String, String> names = {};

    for (var userId in userIds) {
      try {
        final userDoc = await _db.collection('users').doc(userId).get();
        if (userDoc.exists) {
          names[userId] = userDoc.data()?['name'] ?? 'Unknown User';
        } else {
          names[userId] = 'Unknown User';
        }
      } catch (e) {
        names[userId] = 'Unknown User';
      }
    }

    return names;
  }

  /// Create welcome message in the chat
  Future<void> _createWelcomeMessage(
      String committeeId,
      String creatorId,
      String creatorName,
      String committeeName,
      ) async {
    try {
      final messagesRef = _db
          .collection('committee_chats')
          .doc(committeeId)
          .collection('messages');

      await messagesRef.add({
        'messageId': DateTime.now().millisecondsSinceEpoch.toString(),
        'senderId': creatorId,
        'senderName': creatorName,
        'message': '🎉 Welcome to $committeeName committee! This is the official chat for this committee. Feel free to discuss, ask questions, and stay updated about committee activities.',
        'type': 'system',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sent',
        'readBy': [creatorId],
      });

      print('✅ Welcome message created for committee: $committeeId');
    } catch (e) {
      print('❌ Error creating welcome message: $e');
    }
  }

  /// Add join system message
  Future<void> _addJoinSystemMessage(
      String committeeId,
      String userName,
      String committeeName,
      ) async {
    try {
      final messagesRef = _db
          .collection('committee_chats')
          .doc(committeeId)
          .collection('messages');

      await messagesRef.add({
        'messageId': DateTime.now().millisecondsSinceEpoch.toString(),
        'senderId': 'system',
        'senderName': 'System',
        'message': '$userName has joined the $committeeName committee',
        'type': 'system',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sent',
        'readBy': [],
      });

      print('✅ Join system message added for: $userName');
    } catch (e) {
      print('❌ Error adding join system message: $e');
    }
  }

  /// Update payment status for a member
  Future<void> updatePaymentStatus(
      String committeeId,
      String memberPhone,
      String monthKey,
      String status
      ) async {
    print(" updatePaymentStatus called: committeeId=$committeeId, member=$memberPhone, month=$monthKey, status=$status");
    try {
      final docRef = _db.collection("committees").doc(committeeId);
      await docRef.update({
        "membersPayments.$memberPhone.$monthKey": status,
      });
      print(" Payment updated successfully");
      notifyListeners();
    } catch (e) {
      debugPrint(" Error updating payment: $e");
    }
  }

  /// Announce winner for a month
  Future<void> announceWinner(String committeeId, String monthKey, String memberPhone) async {
    print(" announceWinner called: committeeId=$committeeId, month=$monthKey, member=$memberPhone");
    try {
      final docRef = _db.collection("committees").doc(committeeId);
      await docRef.update({
        "winners.$monthKey": memberPhone,
      });
      print(" Winner announced successfully");
      notifyListeners();
    } catch (e) {
      debugPrint(" Error announcing winner: $e");
    }
  }

  /// Accept invitation to a committee
  Future<void> acceptInvitation({
    required String committeeId,
    required String userId,
    required String phone,
    required String name,
  }) async {
    final docRef = _db.collection("committees").doc(committeeId);
    final snapshot = await docRef.get();
    if (!snapshot.exists) return;

    Map<String, dynamic> committee = snapshot.data()!;

    // Update member status or add new member
    List members = List.from(committee["members"] ?? []);
    bool exists = false;

    for (var m in members) {
      if (m["uid"] == userId || m["phone"] == phone) {
        m["uid"] = userId;
        m["status"] = "Joined";
        exists = true;
        break;
      }
    }

    if (!exists) {
      members.add({
        "name": name,
        "phone": phone,
        "uid": userId,
        "status": "Joined",
        "payments": {},
      });
    }

    // Update membersMap
    Map<String, dynamic> membersMap =
    Map<String, dynamic>.from(committee["membersMap"] ?? {});
    membersMap[userId] = true;

    // Initialize payments for user
    Map<String, Map<String, String>> membersPayments =
    Map<String, Map<String, String>>.from(committee["membersPayments"] ?? {});
    DateTime startMonth = (committee["startMonth"] as Timestamp).toDate();
    DateTime endMonth = (committee["endMonth"] as Timestamp).toDate();
    Map<String, String> payments = {};
    DateTime temp = DateTime(startMonth.year, startMonth.month);
    while (!temp.isAfter(endMonth)) {
      String key = "${temp.year}-${temp.month.toString().padLeft(2, '0')}";
      payments[key] = "Pending";
      temp = DateTime(temp.year, temp.month + 1);
    }
    membersPayments[userId] = payments;

    await docRef.update({
      "members": members,
      "membersMap": membersMap,
      "membersPayments": membersPayments,
    });

    // Update chat document
    await createOrUpdateChatOnJoin(
      committeeId: committeeId,
      committeeName: committee['name'],
      userId: userId,
      userName: name,
    );

    notifyListeners();
  }

  /// Fetch committee by ID
  Future<Map<String, dynamic>?> fetchCommitteeById(String committeeId) async {
    try {
      final doc = await _db.collection("committees").doc(committeeId).get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      data["id"] = doc.id;

      return data;
    } catch (e) {
      debugPrint(" Error fetching committee: $e");
      return null;
    }
  }

  /// Save winner manually
  Future<void> saveWinnerManual({
    required String committeeId,
    required String monthKey,
    required String memberId,
  }) async {
    await FirebaseFirestore.instance
        .collection("committees")
        .doc(committeeId)
        .update({
      "winners.$monthKey": memberId,
    });

    await fetchCommitteeById(committeeId);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}