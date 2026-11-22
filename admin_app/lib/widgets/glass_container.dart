import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final Border? border;
  final Color? color;
  final Gradient? gradient;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final List<BoxShadow>? boxShadow;

  const GlassContainer({
    Key? key,
    required this.child,
    this.blur = 18.0,
    this.opacity = 0.78,
    this.borderRadius,
    this.border,
    this.color,
    this.gradient,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.onTap,
    this.boxShadow,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(20);

    Widget innerContent = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white.withOpacity(opacity),
        gradient: gradient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(opacity + 0.12),
                Colors.white.withOpacity(opacity - 0.05),
              ],
            ),
        borderRadius: effectiveRadius,
        border: border ??
            Border.all(
              color: const Color(0xFFEFF2F7),
              width: 1.2,
            ),
      ),
      child: child,
    );

    if (onTap != null) {
      innerContent = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveRadius,
          splashColor: AppTheme.primary.withOpacity(0.08),
          highlightColor: AppTheme.primary.withOpacity(0.04),
          child: innerContent,
        ),
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.8),
                blurRadius: 1,
                offset: const Offset(0, -1),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: innerContent,
        ),
      ),
    );
  }
}

/// Ambient canvas background that diffuses subtle colors through frosted glass
class IosAmbientBackground extends StatelessWidget {
  final Widget child;

  const IosAmbientBackground({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base canvas
        Container(color: AppTheme.lightBg),
        // Ambient soft bubble 1 (Top right Modern Royal Purple glow)
        Positioned(
          top: -90,
          right: -90,
          child: Container(
            width: 330,
            height: 330,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary.withOpacity(0.08),
            ),
          ),
        ),
        // Ambient soft bubble 2 (Mid-left Electric Magenta glow)
        Positioned(
          top: 240,
          left: -80,
          child: Container(
            width: 290,
            height: 290,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.secondary.withOpacity(0.06),
            ),
          ),
        ),
        // Ambient soft bubble 3 (Bottom right Radiant Cyan glow)
        Positioned(
          bottom: 30,
          right: -60,
          child: Container(
            width: 270,
            height: 270,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accent.withOpacity(0.07),
            ),
          ),
        ),
        // Main child surface
        child,
      ],
    );
  }
}
