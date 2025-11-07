import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/colors.dart';
import '../constants/constants.dart';

enum ButtonType { primary, secondary, outline, text, icon }

enum ButtonSize { small, medium, large }

class CustomButton extends StatefulWidget {
  final String? text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final ButtonType type;
  final ButtonSize size;
  final bool isLoading;
  final bool isDisabled;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Widget? child;
  final bool animate;

  const CustomButton({
    super.key,
    this.text,
    this.icon,
    this.onPressed,
    this.type = ButtonType.primary,
    this.size = ButtonSize.medium,
    this.isLoading = false,
    this.isDisabled = false,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.width,
    this.height,
    this.padding,
    this.borderRadius,
    this.child,
    this.animate = true,
  }) : assert(
         text != null || icon != null || child != null,
         'Either text, icon, or child must be provided',
       );

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  /// Validates that an IconData is not null and has a valid codePoint (not 0)
  bool _isValidIcon(IconData? icon) {
    return icon != null && icon.codePoint != 0;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled =
        !widget.isDisabled && !widget.isLoading && widget.onPressed != null;

    return GestureDetector(
      onTapDown: isEnabled ? (_) => _handleTapDown() : null,
      onTapUp: isEnabled ? (_) => _handleTapUp() : null,
      onTapCancel: isEnabled ? () => _handleTapCancel() : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.animate ? _scaleAnimation.value : 1.0,
            child: _buildButton(context, theme, isEnabled),
          );
        },
      ),
    );
  }

  Widget _buildButton(BuildContext context, ThemeData theme, bool isEnabled) {
    final buttonStyle = _getButtonStyle(theme, isEnabled);
    final content = _buildButtonContent(theme, isEnabled);

    Widget button;

    switch (widget.type) {
      case ButtonType.primary:
        button = ElevatedButton(
          onPressed: isEnabled ? widget.onPressed : null,
          style: buttonStyle,
          child: content,
        );
        break;
      case ButtonType.secondary:
      case ButtonType.outline:
        button = OutlinedButton(
          onPressed: isEnabled ? widget.onPressed : null,
          style: buttonStyle,
          child: content,
        );
        break;
      case ButtonType.text:
        button = TextButton(
          onPressed: isEnabled ? widget.onPressed : null,
          style: buttonStyle,
          child: content,
        );
        break;
      case ButtonType.icon:
        button = IconButton(
          onPressed: isEnabled ? widget.onPressed : null,
          style: buttonStyle,
          icon: content,
        );
        break;
    }

    if (widget.width != null || widget.height != null) {
      button = SizedBox(
        width: widget.width,
        height: widget.height,
        child: button,
      );
    }

    if (widget.animate) {
      button = button
          .animate()
          .fadeIn(duration: AppConstants.animationNormal)
          .slideY(begin: 0.1, duration: AppConstants.animationNormal);
    }

    return button;
  }

  ButtonStyle _getButtonStyle(ThemeData theme, bool isEnabled) {
    final colors = _getButtonColors(theme, isEnabled);
    final sizes = _getButtonSizes();

    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colors['disabledBackground'];
        }
        if (states.contains(WidgetState.pressed)) {
          return colors['pressedBackground'];
        }
        if (states.contains(WidgetState.hovered)) {
          return colors['hoveredBackground'];
        }
        return colors['backgroundColor'];
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colors['disabledForeground'];
        }
        return colors['foregroundColor'];
      }),
      side:
          widget.type == ButtonType.outline ||
                  widget.type == ButtonType.secondary
              ? WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return BorderSide(color: colors['disabledBorder']!, width: 1);
                }
                return BorderSide(color: colors['borderColor']!, width: 1.5);
              })
              : null,
      padding: WidgetStateProperty.all(
        widget.padding ?? sizes['padding'] as EdgeInsetsGeometry,
      ),
      minimumSize: WidgetStateProperty.all(sizes['minimumSize'] as Size),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius:
              widget.borderRadius ??
              BorderRadius.circular(AppConstants.borderRadius),
        ),
      ),
      elevation:
          widget.type == ButtonType.primary
              ? WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) return 0;
                if (states.contains(WidgetState.pressed)) return 1;
                return AppConstants.cardElevation;
              })
              : WidgetStateProperty.all(0),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return colors['overlayColor'];
        }
        return null;
      }),
    );
  }

  Map<String, Color?> _getButtonColors(ThemeData theme, bool isEnabled) {
    switch (widget.type) {
      case ButtonType.primary:
        return {
          'backgroundColor': widget.backgroundColor ?? AppColors.primary,
          'foregroundColor': widget.textColor ?? AppColors.textOnPrimary,
          'pressedBackground': (widget.backgroundColor ?? AppColors.primary)
              .withAlpha(204),
          'hoveredBackground': (widget.backgroundColor ?? AppColors.primary)
              .withAlpha(230),
          'disabledBackground': AppColors.borderLight,
          'disabledForeground': AppColors.textLight,
          'overlayColor': AppColors.textOnPrimary.withAlpha(26),
          'borderColor': null,
          'disabledBorder': null,
        };

      case ButtonType.secondary:
        return {
          'backgroundColor': widget.backgroundColor ?? AppColors.surface,
          'foregroundColor': widget.textColor ?? AppColors.primary,
          'pressedBackground': AppColors.primary.withAlpha(26),
          'hoveredBackground': AppColors.primary.withAlpha(13),
          'disabledBackground': AppColors.surface,
          'disabledForeground': AppColors.textLight,
          'overlayColor': AppColors.primary.withAlpha(26),
          'borderColor': widget.borderColor ?? AppColors.primary,
          'disabledBorder': AppColors.borderLight,
        };

      case ButtonType.outline:
        return {
          'backgroundColor': widget.backgroundColor ?? Colors.transparent,
          'foregroundColor': widget.textColor ?? AppColors.primary,
          'pressedBackground': AppColors.primary.withAlpha(26),
          'hoveredBackground': AppColors.primary.withAlpha(13),
          'disabledBackground': Colors.transparent,
          'disabledForeground': AppColors.textLight,
          'overlayColor': AppColors.primary.withAlpha(26),
          'borderColor': widget.borderColor ?? AppColors.primary,
          'disabledBorder': AppColors.borderLight,
        };

      case ButtonType.text:
        return {
          'backgroundColor': widget.backgroundColor ?? Colors.transparent,
          'foregroundColor': widget.textColor ?? AppColors.primary,
          'pressedBackground': AppColors.primary.withAlpha(26),
          'hoveredBackground': AppColors.primary.withAlpha(13),
          'disabledBackground': Colors.transparent,
          'disabledForeground': AppColors.textLight,
          'overlayColor': AppColors.primary.withAlpha(26),
          'borderColor': null,
          'disabledBorder': null,
        };

      case ButtonType.icon:
        return {
          'backgroundColor': widget.backgroundColor ?? Colors.transparent,
          'foregroundColor': widget.textColor ?? AppColors.primary,
          'pressedBackground': AppColors.primary.withAlpha(26),
          'hoveredBackground': AppColors.primary.withAlpha(13),
          'disabledBackground': Colors.transparent,
          'disabledForeground': AppColors.textLight,
          'overlayColor': AppColors.primary.withAlpha(26),
          'borderColor': null,
          'disabledBorder': null,
        };
    }
  }

  Map<String, dynamic> _getButtonSizes() {
    switch (widget.size) {
      case ButtonSize.small:
        return {
          'padding': const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          'minimumSize': const Size(64, 32),
          'textStyle': const TextStyle(fontSize: 12),
          'iconSize': 16.0,
        };

      case ButtonSize.medium:
        return {
          'padding': const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          'minimumSize': const Size(88, AppConstants.buttonHeight),
          'textStyle': const TextStyle(fontSize: 14),
          'iconSize': 20.0,
        };

      case ButtonSize.large:
        return {
          'padding': const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          'minimumSize': const Size(120, 56),
          'textStyle': const TextStyle(fontSize: 16),
          'iconSize': 24.0,
        };
    }
  }

  Widget _buildButtonContent(ThemeData theme, bool isEnabled) {
    if (widget.child != null) {
      return widget.child!;
    }

    final sizes = _getButtonSizes();
    final iconSize = sizes['iconSize'] as double;
    final textStyle = sizes['textStyle'] as TextStyle;

    if (widget.isLoading) {
      return SizedBox(
        width: iconSize,
        height: iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            widget.type == ButtonType.primary
                ? AppColors.textOnPrimary
                : AppColors.primary,
          ),
        ),
      );
    }

    if (widget.type == ButtonType.icon) {
      if (!_isValidIcon(widget.icon)) {
        return const SizedBox.shrink();
      }
      return Icon(widget.icon!, size: iconSize);
    }

    if (_isValidIcon(widget.icon) && widget.text != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon!, size: iconSize),
          const SizedBox(width: AppConstants.spacingS),
          Text(widget.text!, style: textStyle),
        ],
      );
    }

    if (_isValidIcon(widget.icon)) {
      return Icon(widget.icon!, size: iconSize);
    }

    return Text(widget.text!, style: textStyle);
  }

  void _handleTapDown() {
    if (widget.animate) {
      _animationController.forward();
    }
  }

  void _handleTapUp() {
    if (widget.animate) {
      _animationController.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.animate) {
      _animationController.reverse();
    }
  }
}
