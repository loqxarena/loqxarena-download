import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType; // Made nullable for smart defaults
  final int? maxLines; // Made nullable so chat/text boxes can expand infinitely
  final bool isPassword;
  final Function(String)? onChanged;
  final TextInputAction? textInputAction; // Added to manually override if needed

  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.maxLines,
    this.isPassword = false, 
    this.onChanged,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Identify if it's a number pad
    bool isPhone = keyboardType == TextInputType.phone || keyboardType == TextInputType.number;

    // 2. STRICT RULE: Passwords MUST be exactly 1 line or Flutter will crash.
    // For everything else, if maxLines isn't provided, we set it to null so the box expands when they press Enter.
    int? resolvedMaxLines = isPassword ? 1 : (maxLines ?? (isPhone ? 1 : null));

    // 3. Force the keyboard into Multiline mode to enable the Enter arrow (unless it's a password)
    TextInputType resolvedKeyboardType = isPassword 
        ? TextInputType.visiblePassword 
        : (keyboardType ?? TextInputType.multiline);

    // 4. THE MAGIC LINE: Replace the "Tick/Done" with the "Return Arrow" globally!
    // (Except for Passwords and Phone numbers, which keep 'Done')
    TextInputAction resolvedInputAction = textInputAction ?? 
        (isPassword || isPhone ? TextInputAction.done : TextInputAction.newline);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          
          // Apply the smart logic
          keyboardType: resolvedKeyboardType,
          maxLines: resolvedMaxLines,
          textInputAction: resolvedInputAction,
          obscureText: isPassword, 
          onChanged: onChanged, 
          
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
      ],
    );
  }
}