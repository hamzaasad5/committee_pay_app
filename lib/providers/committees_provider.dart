import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class CommitteesProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool isLoading = false;
  String? error;
  List<Map<String, dynamic>> committees = [];
  StreamSubscription? _subscription;

  /// ------------------------
  /// Fetch all committees for a user (creator or joined member)
  /// ------------------------
  void fetchUserCommittees(String userId) {
    print("🔹 fetchUserCommittees called for userId: $userId");

    if (userId.isEmpty) {
      print("⚠️ fetchUserCommittees: userId is empty!");
      isLoading = false;
      error = "Invalid user ID";
      notifyListeners();
      return;
    }

    isLoading = true;
    error = null;
    committees = [];
    notifyListeners();

    _subscription?.cancel();
    print("🔹 Previous subscription cancelled (if any)");

    _subscription = _db
        .collection("committees")
        .orderBy("createdAt", descending: true)
        .snapshots()
        .listen((snapshot) {
      print("🔹 Received snapshot with ${snapshot.docs.length} committees");

      committees = snapshot.docs.map((doc) {
        final data = doc.data();
        data["id"] = doc.id; // store doc id
        print("  🔹 Committee fetched: ${data["name"] ?? "Unnamed"} (ID: ${doc.id})");
        return data;
      }).where((committee) {
        // 1️⃣ Include committees created by this user
        if (committee["adminId"] == userId) {
          print("    ✅ Included as creator: ${committee["name"]}");
          return true;
        }

        // 2️⃣ Include committees where user has joined
        final members = List.from(committee["members"] ?? []);
        bool isMember = false;

        for (var m in members) {
          final mUid = m["uid"] ?? "-";
          final mStatus = m["status"]?.toString().toLowerCase() ?? "";
          print("      🔹 Checking member: $mUid, status: $mStatus");

          if (mUid == userId && mStatus == "joined") {
            isMember = true;
            print("        ✅ User is a joined member");
            break;
          }
        }

        if (isMember) {
          print("    ✅ Included as member: ${committee["name"]}");
        } else {
          print("    ❌ Excluded: ${committee["name"]}");
        }

        return isMember;
      }).toList();

      print("🔹 Total committees after filtering: ${committees.length}");

      isLoading = false;
      error = null;
      notifyListeners();
    }, onError: (e) {
      print("⚠️ Error fetching committees: $e");
      error = e.toString();
      isLoading = false;
      notifyListeners();
    });
  }



  /// ------------------------
  /// Add a new committee (creator becomes initial member)
  /// ------------------------
  Future<String?> addCommittee({
    required String name,
    required int monthlyAmount,
    required int totalMembers,
    required List<Map<String, String>> memberPhones, // [{name, phone}]
    required DateTime startMonth,
    required DateTime endMonth,
    required String creatorId,
    required String creatorName,
    required String type, // "monthly" or "daily"
    required int totalAmount,
    required String committeeCode,
  }) async {
    try {
      Map<String, dynamic> membersMap = {};
      Map<String, Map<String, dynamic>> membersPayments = {};
      List<Map<String, dynamic>> members = [];

      // Initialize invited members (pending)
      for (var member in memberPhones) {
        String phone = member["phone"]!;
        String memberName = member["name"]!;
        membersMap[phone] = false; // pending
        members.add({
          "name": memberName,
          "phone": phone,
          "status": "Pending",
          "payments": {},
        });
      }

      // Add creator as member with "Joined" status
      membersMap[creatorId] = true;
      members.add({
        "name": creatorName,
        "uid": creatorId,
        "status": "Joined",
        "payments": {},
      });

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

      return docRef.id;
    } catch (e) {
      print("❌ Error adding committee: $e");
      return null;
    }
  }




  /// ------------------------
  /// Update payment status for a member
  /// ------------------------
  Future<void> updatePaymentStatus(
      String committeeId, String memberPhone, String monthKey, String status) async {
    print("🔹 updatePaymentStatus called: committeeId=$committeeId, member=$memberPhone, month=$monthKey, status=$status");
    try {
      final docRef = _db.collection("committees").doc(committeeId);
      await docRef.update({
        "membersPayments.$memberPhone.$monthKey": status,
      });
      print("✅ Payment updated successfully");
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error updating payment: $e");
    }
  }

  /// ------------------------
  /// Announce winner for a month
  /// ------------------------
  Future<void> announceWinner(String committeeId, String monthKey, String memberPhone) async {
    print("🔹 announceWinner called: committeeId=$committeeId, month=$monthKey, member=$memberPhone");
    try {
      final docRef = _db.collection("committees").doc(committeeId);
      await docRef.update({
        "winners.$monthKey": memberPhone,
      });
      print("✅ Winner announced successfully");
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error announcing winner: $e");
    }
  }

  /// ------------------------
  /// Accept invitation to a committee
  /// ------------------------
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

    notifyListeners();
  }




  Future<Map<String, dynamic>?> fetchCommitteeById(String committeeId) async {
    try {
      final doc = await _db.collection("committees").doc(committeeId).get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      data["id"] = doc.id;

      return data;
    } catch (e) {
      debugPrint("❌ Error fetching committee: $e");
      return null;
    }
  }

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


  /// ------------------------
  /// Dispose
  /// ------------------------
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
