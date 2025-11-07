import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../constants/constant.dart';

class AuthTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final IconData? prefixIcon;
  final bool enabled;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final FocusNode? focusNode;
  final String? initialValue;

  const AuthTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.prefixIcon,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.initialValue,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _obscureText;
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  /// Validates that an IconData is not null and has a valid codePoint (not 0)
  bool _isValidIcon(IconData? icon) {
    return icon != null && icon.codePoint != 0;
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: ResponsiveText.body(context).copyWith(
            fontWeight: FontWeight.w600,
            color: AppColor.textPrimary,
            fontSize: 14,
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
        const SizedBox(height: 8),
        TextFormField(
              controller: widget.controller,
              validator: widget.validator,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              obscureText: _obscureText,
              enabled: widget.enabled,
              onChanged: widget.onChanged,
              onFieldSubmitted: widget.onSubmitted,
              focusNode: _focusNode,
              initialValue: widget.initialValue,
              style: ResponsiveText.body(
                context,
              ).copyWith(color: AppColor.textPrimary, fontSize: 16),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: ResponsiveText.body(context).copyWith(
                  color: AppColor.textSecondary.withAlpha(179),
                  fontSize: 16,
                ),
                prefixIcon:
                    _isValidIcon(widget.prefixIcon)
                        ? Icon(
                          widget.prefixIcon!,
                          color:
                              _isFocused
                                  ? AppColor.accentGreen
                                  : AppColor.textSecondary,
                          size: 20,
                        )
                        : null,
                suffixIcon:
                    widget.obscureText
                        ? IconButton(
                          icon: Icon(
                            _obscureText ? Iconsax.eye_slash : Iconsax.eye,
                            color:
                                _isFocused
                                    ? AppColor.accentGreen
                                    : AppColor.textSecondary,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureText = !_obscureText;
                            });
                          },
                        )
                        : null,
                filled: true,
                fillColor: AppColor.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColor.textSecondary.withAlpha(51),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColor.accentGreen,
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColor.accentRed,
                    width: 1,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColor.accentRed,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            )
            .animate()
            .fadeIn(duration: 400.ms, delay: 100.ms)
            .slideY(begin: 0.1, end: 0),
      ],
    );
  }
}
