import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final List<Widget>? actions;
  final VoidCallback? onBackPressed;
  final Color? backgroundColor;
  final Color? titleColor;
  final double? titleFontSize;
  final FontWeight? titleFontWeight;
  final bool centerTitle;
  final double elevation;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.actions,
    this.onBackPressed,
    this.backgroundColor,
    this.titleColor,
    this.titleFontSize,
    this.titleFontWeight,
    this.centerTitle = true,
    this.elevation = 0,
    this.leading,
    this.automaticallyImplyLeading = false,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor ?? AppColors.surfaceDark,
      elevation: elevation,
      centerTitle: centerTitle,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading ?? (showBackButton ? _buildBackButton(context) : null),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: titleFontWeight ?? FontWeight.bold,
          color: titleColor ?? Colors.white,
          fontSize: titleFontSize ?? 20,
        ),
      ),
      actions: actions,
      bottom: bottom,
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back, color: AppColors.goldColor),
      onPressed: onBackPressed ?? () => Navigator.pop(context),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
    bottom != null ? kToolbarHeight + bottom!.preferredSize.height : kToolbarHeight,
  );
}

// Extension methods for easy use
extension CustomAppBarExtension on CustomAppBar {
  static CustomAppBar withRefresh({
    required String title,
    required VoidCallback onRefresh,
    bool showBackButton = true,
    VoidCallback? onBackPressed,
    List<Widget>? additionalActions,
    bool centerTitle = true,
  }) {
    final actions = <Widget>[
      IconButton(
        icon: Icon(Icons.refresh, color: AppColors.goldColor),
        onPressed: onRefresh,
        tooltip: "Refresh",
      ),
      if (additionalActions != null) ...additionalActions,
    ];

    return CustomAppBar(
      title: title,
      showBackButton: showBackButton,
      onBackPressed: onBackPressed,
      actions: actions,
      centerTitle: centerTitle,
    );
  }

  static CustomAppBar withSearch({
    required String title,
    required VoidCallback onSearch,
    bool showBackButton = true,
    VoidCallback? onBackPressed,
    List<Widget>? additionalActions,
    bool centerTitle = true,
  }) {
    final actions = <Widget>[
      IconButton(
        icon: Icon(Icons.search, color: AppColors.goldColor),
        onPressed: onSearch,
        tooltip: "Search",
      ),
      if (additionalActions != null) ...additionalActions,
    ];

    return CustomAppBar(
      title: title,
      showBackButton: showBackButton,
      onBackPressed: onBackPressed,
      actions: actions,
      centerTitle: centerTitle,
    );
  }

  static CustomAppBar withMenu({
    required String title,
    required VoidCallback onMenu,
    bool showBackButton = true,
    VoidCallback? onBackPressed,
    List<Widget>? additionalActions,
    bool centerTitle = true,
  }) {
    final actions = <Widget>[
      IconButton(
        icon: Icon(Icons.more_vert, color: AppColors.goldColor),
        onPressed: onMenu,
        tooltip: "Menu",
      ),
      if (additionalActions != null) ...additionalActions,
    ];

    return CustomAppBar(
      title: title,
      showBackButton: showBackButton,
      onBackPressed: onBackPressed,
      actions: actions,
      centerTitle: centerTitle,
    );
  }

  static CustomAppBar withCustomActions({
    required String title,
    required List<Widget> actions,
    bool showBackButton = true,
    VoidCallback? onBackPressed,
    bool centerTitle = true,
  }) {
    return CustomAppBar(
      title: title,
      showBackButton: showBackButton,
      onBackPressed: onBackPressed,
      actions: actions,
      centerTitle: centerTitle,
    );
  }

  static CustomAppBar simple({
    required String title,
    bool showBackButton = true,
    VoidCallback? onBackPressed,
    bool centerTitle = true,
  }) {
    return CustomAppBar(
      title: title,
      showBackButton: showBackButton,
      onBackPressed: onBackPressed,
      centerTitle: centerTitle,
    );
  }
}