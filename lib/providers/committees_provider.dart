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
  /// Fetch all committees for a user (admin or member)
  /// ------------------------
  void fetchUserCommittees(String userId) {
    print("🔹 fetchUserCommittees called for userId: $userId");
    isLoading = true;
    error = null;
    committees = [];
    notifyListeners();

    _subscription?.cancel();

    _subscription = _db
        .collection("committees")
        .orderBy("createdAt", descending: true)
        .snapshots()
        .listen((snapshot) {
      print("📌 Firestore snapshot received: ${snapshot.docs.length} documents");

      committees = snapshot.docs.map((doc) {
        final data = doc.data();
        data["id"] = doc.id; // Attach doc ID for later usage
        return data;
      }).where((committee) {
        // Admin sees own committees
        if (committee["adminId"] == userId) return true;

        // Member sees only joined committees
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
    }, onError: (e) {
      error = e.toString();
      isLoading = false;
      print("❌ Error fetching committees: $error");
      notifyListeners();
    });
  }

  /// ------------------------
  /// Add a new committee
  /// ------------------------
  Future<String?> addCommittee({
    required String name,
    required int monthlyAmount,              // FINAL CALCULATED TOTAL AMOUNT
    required int totalMembers,               // NEW FIELD
    required List<Map<String, String>> memberPhones,
    required DateTime startMonth,
    required DateTime endMonth,
    required String adminId,
    required String type,
    required int totalAmount,                // NEW auto-calculated total field
  }) async {
    print("🔹 addCommittee called for adminId: $adminId, name: $name, type: $type");

    try {
      Map<String, dynamic> membersMap = {};
      Map<String, Map<String, dynamic>> membersPayments = {};
      List<Map<String, dynamic>> members = [];

      // Prepare members data
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

      // Create committee document in Firestore
      final docRef = await _db.collection("committees").add({
        "name": name,
        "monthlyAmount": monthlyAmount,          // Final calculated total
        "totalMembers": totalMembers,            // Total members
        "totalAmount": totalAmount,              // Auto-calculated field
        "perMemberAmount": type == "monthly"
            ? monthlyAmount ~/ totalMembers
            : null, // optional per-member amount

        "members": members,
        "membersMap": membersMap,
        "membersPayments": membersPayments,

        "adminId": adminId,
        "startMonth": startMonth,
        "endMonth": endMonth,
        "type": type,

        "status": "Active",
        "winners": {},
        "createdAt": FieldValue.serverTimestamp(),
      });

      print("✅ Committee added with ID: ${docRef.id}");
      return docRef.id;
    } catch (e) {
      debugPrint("❌ Error adding committee: $e");
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
    print("🔹 acceptInvitation called: committeeId=$committeeId, userId=$userId, phone=$phone");
    final docRef = _db.collection("committees").doc(committeeId);
    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      print("❌ Committee does not exist!");
      return;
    }

    Map<String, dynamic> committee = snapshot.data()!;

    // Update member status in members list
    List members = List.from(committee["members"] ?? []);
    bool exists = false;

    for (var m in members) {
      if (m["phone"] == phone) {
        m["status"] = "Joined";
        m["uid"] = userId;
        exists = true;
        break;
      }
    }

    // Add new member if not exists
    if (!exists) {
      members.add({
        "name": name,
        "phone": phone,
        "uid": userId,
        "status": "Joined",
        "payments": {},
      });
      print("🆕 New member added to committee");
    }

    // Update membersMap
    Map<String, dynamic> membersMap = Map<String, dynamic>.from(committee["membersMap"] ?? {});
    membersMap[userId] = true;

    // Initialize payments for the member
    Map<String, Map<String, String>> membersPayments = Map<String, Map<String, String>>.from(committee["membersPayments"] ?? {});
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

    print("✅ Invitation accepted for userId=$userId");
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


  /// ------------------------
  /// Dispose to avoid memory leaks
  /// ------------------------
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
