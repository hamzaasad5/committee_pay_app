
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';

class FullImageScreen extends StatelessWidget {
  final String imageUrl;

  const FullImageScreen({Key? key, required this.imageUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: AppColors.goldColor),
            onPressed: () {
              // Implement share
            },
          ),
          IconButton(
            icon: Icon(Icons.download, color: AppColors.goldColor),
            onPressed: () {
              // Implement download
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(color: AppColors.goldColor),
            ),
            errorWidget: (context, url, error) => Icon(
              Icons.error,
              color: AppColors.red,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}