
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../services/chat_service.dart';
import 'full_image_view.dart';

class CommitteeMediaScreen extends StatelessWidget {
  final String committeeId;
  final String committeeName;

  const CommitteeMediaScreen({
    Key? key,
    required this.committeeId,
    required this.committeeName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.goldColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Media • $committeeName',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: chatService.getMediaMessages(committeeId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: AppColors.red),
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
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.goldSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.photo_library,
                      size: 48,
                      color: AppColors.goldColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No media shared yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index].data() as Map<String, dynamic>;
              final imageUrl = message['imageUrl'];

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FullImageScreen(imageUrl: imageUrl),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppColors.r12),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppColors.surface2,
                      child: const Center(
                        child: CircularProgressIndicator(color: AppColors.goldColor),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.surface2,
                      child: Icon(Icons.error, color: AppColors.red),
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