import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/colors.dart';
import '../constants/constants.dart';

enum InputFieldType { text, email, password, phone, number, multiline }

class CustomInputField extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconPressed;
  final TextEditingController? controller;
  final String? initialValue;
  final InputFieldType type;
  final bool isRequired;
  final bool isEnabled;
  final bool isReadOnly;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final EdgeInsetsGeometry? contentPadding;
  final bool animate;
  final bool showCharacterCount;

  const CustomInputField({
    super.key,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconPressed,
    this.controller,
    this.initialValue,
    this.type = InputFieldType.text,
    this.isRequired = false,
    this.isEnabled = true,
    this.isReadOnly = false,
    this.maxLines,
    this.minLines,
    this.maxLength,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.validator,
    this.inputFormatters,
    this.contentPadding,
    this.animate = true,
    this.showCharacterCount = false,
  });

  @override
  State<CustomInputField> createState() => _CustomInputFieldState();
}

class _CustomInputFieldState extends State<CustomInputField>
    with SingleTickerProviderStateMixin {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _obscureText = false;
  bool _isFocused = false;
  String _currentValue = '';

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = FocusNode();
    _obscureText = widget.type == InputFieldType.password;
    _currentValue = widget.initialValue ?? _controller.text;

    if (widget.initialValue != null && widget.controller == null) {
      _controller.text = widget.initialValue!;
    }

    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onTextChange);
  }

  /// Validates that an IconData is not null and has a valid codePoint (not 0)
  bool _isValidIcon(IconData? icon) {
    return icon != null && icon.codePoint != 0;
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  void _onTextChange() {
    setState(() {
      _currentValue = _controller.text;
    });
    widget.onChanged?.call(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget field = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) _buildLabel(theme),
        _buildTextField(theme),
        if (widget.helperText != null || widget.showCharacterCount)
          _buildHelperText(theme),
      ],
    );

    if (widget.animate) {
      field = field
          .animate()
          .fadeIn(duration: AppConstants.animationNormal)
          .slideY(begin: 0.1, duration: AppConstants.animationNormal);
    }

    return field;
  }

  Widget _buildLabel(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingS),
      child: RichText(
        text: TextSpan(
          text: widget.label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: _isFocused ? AppColors.primary : AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
          children:
              widget.isRequired
                  ? [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ]
                  : null,
        ),
      ),
    );
  }

  Widget _buildTextField(ThemeData theme) {
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      enabled: widget.isEnabled,
      readOnly: widget.isReadOnly,
      obscureText: _obscureText,
      keyboardType: _getKeyboardType(),
      textInputAction: widget.textInputAction ?? _getDefaultTextInputAction(),
      maxLines:
          widget.type == InputFieldType.multiline
              ? (widget.maxLines ?? 3)
              : (widget.maxLines ?? 1),
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      inputFormatters: widget.inputFormatters ?? _getDefaultInputFormatters(),
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      onTap: widget.onTap,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: widget.isEnabled ? AppColors.textPrimary : AppColors.textLight,
      ),
      decoration: InputDecoration(
        hintText: widget.hint,
        errorText: widget.errorText,
        prefixIcon:
            _isValidIcon(widget.prefixIcon)
                ? Icon(
                  widget.prefixIcon!,
                  color:
                      _isFocused ? AppColors.primary : AppColors.textSecondary,
                  size: 20,
                )
                : null,
        suffixIcon: _buildSuffixIcon(),
        contentPadding:
            widget.contentPadding ??
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        filled: true,
        fillColor:
            widget.isEnabled
                ? (_isFocused ? AppColors.surface : AppColors.background)
                : AppColors.borderLight.withAlpha(77),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        counterText: widget.showCharacterCount ? null : '',
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.textLight,
        ),
        errorStyle: theme.textTheme.bodySmall?.copyWith(color: AppColors.error),
        helperStyle: theme.textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget? _buildSuffixIcon() {
    if (widget.type == InputFieldType.password) {
      return IconButton(
        icon: Icon(
          _obscureText ? Icons.visibility : Icons.visibility_off,
          color: _isFocused ? AppColors.primary : AppColors.textSecondary,
          size: 20,
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
      );
    }

    if (_isValidIcon(widget.suffixIcon)) {
      return IconButton(
        icon: Icon(
          widget.suffixIcon!,
          color: _isFocused ? AppColors.primary : AppColors.textSecondary,
          size: 20,
        ),
        onPressed: widget.onSuffixIconPressed,
      );
    }

    // Clear button for non-empty fields
    if (_currentValue.isNotEmpty && widget.isEnabled && !widget.isReadOnly) {
      return IconButton(
        icon: Icon(Icons.clear, color: AppColors.textSecondary, size: 20),
        onPressed: () {
          _controller.clear();
          widget.onChanged?.call('');
        },
      );
    }

    return null;
  }

  Widget _buildHelperText(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppConstants.spacingS,
        left: 12,
        right: 12,
      ),
      child: Row(
        children: [
          if (widget.helperText != null)
            Expanded(
              child: Text(
                widget.helperText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          if (widget.showCharacterCount && widget.maxLength != null)
            Text(
              '${_currentValue.length}/${widget.maxLength}',
              style: theme.textTheme.bodySmall?.copyWith(
                color:
                    _currentValue.length > (widget.maxLength! * 0.9)
                        ? AppColors.warning
                        : AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  TextInputType _getKeyboardType() {
    switch (widget.type) {
      case InputFieldType.email:
        return TextInputType.emailAddress;
      case InputFieldType.phone:
        return TextInputType.phone;
      case InputFieldType.number:
        return TextInputType.number;
      case InputFieldType.multiline:
        return TextInputType.multiline;
      case InputFieldType.password:
      case InputFieldType.text:
        return TextInputType.text;
    }
  }

  TextInputAction _getDefaultTextInputAction() {
    switch (widget.type) {
      case InputFieldType.multiline:
        return TextInputAction.newline;
      case InputFieldType.password:
        return TextInputAction.done;
      default:
        return TextInputAction.next;
    }
  }

  List<TextInputFormatter>? _getDefaultInputFormatters() {
    switch (widget.type) {
      case InputFieldType.phone:
        return [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(11),
        ];
      case InputFieldType.number:
        return [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
      case InputFieldType.email:
        return [
          FilteringTextInputFormatter.deny(RegExp(r'\s')), // No spaces
        ];
      default:
        return null;
    }
  }
}

// Validation helpers
class InputValidators {
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return AppConstants.errorRequiredField;
    }
    if (!RegExp(AppConstants.emailRegex).hasMatch(value)) {
      return AppConstants.errorInvalidEmail;
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return AppConstants.errorRequiredField;
    }
    if (value.length < AppConstants.minPasswordLength) {
      return AppConstants.errorPasswordTooShort;
    }
    return null;
  }

  static String? required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppConstants.errorRequiredField;
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.isEmpty) {
      return AppConstants.errorRequiredField;
    }
    if (!RegExp(AppConstants.phoneRegex).hasMatch(value)) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppConstants.errorRequiredField;
    }
    if (value.trim().length > AppConstants.maxNameLength) {
      return 'Name is too long';
    }
    return null;
  }

  static String? Function(String?) confirmPassword(String originalPassword) {
    return (String? value) {
      if (value == null || value.isEmpty) {
        return AppConstants.errorRequiredField;
      }
      if (value != originalPassword) {
        return AppConstants.errorPasswordMismatch;
      }
      return null;
    };
  }
}
