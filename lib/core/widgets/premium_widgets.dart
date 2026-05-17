import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

// REFINED PREMIUM CARD (Clean Dark Gradient)
class PremiumCard extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin; // FIXED: Added missing margin

  const PremiumCard({
    super.key,
    required this.child,
    this.glowColor = AppColors.primary,
    this.onTap,
    this.padding,
    this.margin, // FIXED: Added to constructor
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin, // FIXED: Applied margin here
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2A2A), Color(0xFF121212)],
        ),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(0),
            child: child,
          ),
        ),
      ),
    );
  }
}

// PREMIUM BUTTON (Vibrant Gradient)
class PremiumButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final LinearGradient gradient;
  final bool isLoading;
  final IconData? icon;

  const PremiumButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.gradient = AppColors.greenButtonGradient,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: onPressed == null ? null : gradient,
        color: onPressed == null ? Colors.grey.shade800 : null,
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8)
                  ],
                  Text(text.toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 1)),
                ],
              ),
      ),
    );
  }
}

// COMPACT TAG (For Details Screen)
class PremiumTag extends StatelessWidget {
  final String text;
  final Color color;

  const PremiumTag({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(text.toUpperCase(),
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}