import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CustomAppButton extends StatelessWidget {
  final String text;
  final Future<void> Function()? onPressed; // <-- Update here
  final bool isLoading;
  final double height;
  final double radius;

  const CustomAppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.height = 55,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : () async {
          if (onPressed != null) {
            await onPressed!(); // <-- Allow async call
          }
        },
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
        child: isLoading
            ? const SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : Text(
          text,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
