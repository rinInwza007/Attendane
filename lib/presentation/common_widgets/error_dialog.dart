import 'package:flutter/material.dart';

class ErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback? onPressed;

  const ErrorDialog({
    super.key,
    this.title = 'Error',
    required this.message,
    this.buttonText = 'OK',
    this.onPressed,
  });

  static Future<void> show(
    BuildContext context, {
    String title = 'Error',
    required String message,
    String buttonText = 'OK',
    VoidCallback? onPressed,
  }) {
    return showDialog(
      context: context,
      builder: (context) => ErrorDialog(
        title: title,
        message: message,
        buttonText: buttonText,
        onPressed: onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            if (onPressed != null) {
              onPressed!();
            }
          },
          child: Text(buttonText),
        ),
      ],
    );
  }
}
