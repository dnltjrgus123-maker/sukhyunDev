import "package:flutter/material.dart";

void showAppSnackBar(
  BuildContext context, {
  required String message,
  bool isError = false,
}) {
  final scheme = Theme.of(context).colorScheme;
  final contentColor = isError ? scheme.onError : scheme.onInverseSurface;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: TextStyle(color: contentColor)),
      backgroundColor: isError ? scheme.error : scheme.inverseSurface,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
