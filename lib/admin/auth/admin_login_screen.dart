import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/constant.dart';
import 'admin_auth_service.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_button.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AdminAuthService();

  bool _isLoading = false;
  bool _rememberMe = false;

  late AnimationController _logoAnimationController;
  late Timer _logoTimer;
  int _currentLogoIndex = 0;
  final List<String> _logoAssets = [
    'assets/A_1.json',
    'assets/A_2.json',
    'assets/A_3.json',
    'assets/A_4.json',
  ];

  @override
  void initState() {
    super.initState();
    _logoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Start logo carousel
    _startLogoCarousel();
  }

  void _startLogoCarousel() {
    _logoTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        _logoAnimationController.forward().then((_) {
          setState(() {
            _currentLogoIndex = (_currentLogoIndex + 1) % _logoAssets.length;
          });
          _logoAnimationController.reset();
        });
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _logoAnimationController.dispose();
    _logoTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive layout: split on desktop/tablet, stacked on mobile
          if (constraints.maxWidth > 768) {
            return _buildSplitLayout();
          } else {
            return _buildMobileLayout();
          }
        },
      ),
    );
  }

  Widget _buildSplitLayout() {
    return Row(
      children: [
        // Left Section - Form Panel (3/5 width)
        Expanded(flex: 3, child: _buildFormPanel()),
        // Right Section - Branding Panel (2/5 width)
        Expanded(flex: 2, child: _buildBrandingPanel()),
      ],
    );
  }

  Widget _buildMobileLayout() {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Compact branding section for mobile (on top)
          _buildMobileBranding(isCompact: isSmallScreen),
          const SizedBox(height: 20),
          // Form section for mobile
          _buildFormPanel(isMobile: true, isCompact: isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildFormPanel({bool isMobile = false, bool isCompact = false}) {
    return Container(
      padding: EdgeInsets.all(isMobile ? (isCompact ? 16.0 : 24.0) : 48.0),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMobile ? double.infinity : 400,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFormHeader(isMobile: isMobile, isCompact: isCompact),
              SizedBox(height: isCompact ? 24 : 40),
              _buildLoginForm(isCompact: isCompact),
              SizedBox(height: isCompact ? 16 : 24),
              _buildFooter(isCompact: isCompact),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormHeader({bool isMobile = false, bool isCompact = false}) {
    final titleFontSize = isCompact ? 24.0 : (isMobile ? 28.0 : 32.0);
    final subtitleFontSize = isCompact ? 14.0 : (isMobile ? 15.0 : 16.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Gradient Title
        ShaderMask(
          shaderCallback:
              (bounds) => LinearGradient(
                colors: [AppColor.primary, AppColor.accentGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
          child: Text(
            'EnergySmart Admin Portal',
            style: ResponsiveText.headline(context).copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: titleFontSize,
              letterSpacing: 0.5,
            ),
          ),
        ).animate().fadeIn(duration: 800.ms).slideX(begin: -0.3, end: 0),
        SizedBox(height: isCompact ? 8 : 12),
        Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 12 : 16,
                vertical: isCompact ? 6 : 8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColor.accentGreen.withAlpha(26),
                    AppColor.primary.withAlpha(26),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColor.accentGreen.withAlpha(77),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Iconsax.shield_tick,
                    size: isCompact ? 16 : 18,
                    color: AppColor.accentGreen,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Secure access to system controls',
                      style: ResponsiveText.body(context).copyWith(
                        color: AppColor.textPrimary,
                        fontSize: subtitleFontSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
            .animate()
            .fadeIn(duration: 800.ms, delay: 300.ms)
            .slideX(begin: -0.2, end: 0),
      ],
    );
  }

  Widget _buildLoginForm({bool isCompact = false}) {
    return Card(
          elevation: 8,
          shadowColor: AppColor.primary.withAlpha(51),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.all(isCompact ? 24.0 : 36.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, AppColor.accentGreen.withAlpha(5)],
              ),
              border: Border.all(
                color: AppColor.accentGreen.withAlpha(26),
                width: 1,
              ),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthTextField(
                    label: 'Email Address',
                    hint: 'admin@energysmart.com',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    prefixIcon: Iconsax.sms,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email address';
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  AuthTextField(
                    label: 'Password',
                    hint: 'Enter your password',
                    controller: _passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    prefixIcon: Iconsax.lock,
                    onSubmitted: (_) => _signIn(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildRememberMeRow(),
                  const SizedBox(height: 32),
                  AuthButton(
                    text: 'Sign In',
                    icon: Iconsax.login,
                    onPressed: _isLoading ? null : _signIn,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 16),
                  AuthTextButton(
                    text: 'Forgot Password?',
                    onPressed: _showForgotPasswordDialog,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 800.ms, delay: 400.ms)
        .slideY(begin: 0.2, end: 0);
  }

  Widget _buildRememberMeRow() {
    return Row(
      children: [
        Checkbox(
          value: _rememberMe,
          onChanged: (value) {
            setState(() {
              _rememberMe = value ?? false;
            });
          },
          activeColor: AppColor.accentGreen,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        Text(
          'Remember me',
          style: ResponsiveText.body(
            context,
          ).copyWith(color: AppColor.textSecondary, fontSize: 14),
        ),
      ],
    ).animate().fadeIn(duration: 600.ms, delay: 600.ms);
  }

  Widget _buildBrandingPanel() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColor.primary, AppColor.accentGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLogo(),
            const SizedBox(height: 32),
            _buildTagline(),
            const SizedBox(height: 48),
            _buildEnergyAnimation(),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBranding({bool isCompact = false}) {
    return Container(
      height: isCompact ? 160 : 270,
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColor.primary, AppColor.accentGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColor.primary.withAlpha(77),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLogo(isMobile: true, isCompact: isCompact),
            SizedBox(height: isCompact ? 8 : 16),
            _buildTagline(isMobile: true, isCompact: isCompact),
            // Add carousel indicators
            SizedBox(height: isCompact ? 8 : 12),
            _buildCarouselIndicators(),
          ],
        ),
      ),
    );
  }

  Widget _buildCarouselIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _logoAssets.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentLogoIndex == index ? 12 : 8,
          height: 8,
          decoration: BoxDecoration(
            color:
                _currentLogoIndex == index
                    ? Colors.white
                    : Colors.white.withAlpha(102),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo({bool isMobile = false, bool isCompact = false}) {
    final logoSize = isCompact ? 80.0 : (isMobile ? 100.0 : 160.0);
    return Container(
          width: logoSize,
          height: logoSize,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(38),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withAlpha(77), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(26),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              );
            },
            child: Lottie.asset(
              _logoAssets[_currentLogoIndex],
              key: ValueKey(_currentLogoIndex),
              fit: BoxFit.contain,
              repeat: true,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Iconsax.flash,
                  size: isMobile ? 48 : 64,
                  color: Colors.white,
                );
              },
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 1000.ms, delay: 200.ms)
        .scale(begin: const Offset(0.6, 0.6), end: const Offset(1.0, 1.0));
  }

  Widget _buildTagline({bool isMobile = false, bool isCompact = false}) {
    final titleFontSize = isCompact ? 20.0 : (isMobile ? 24.0 : 36.0);
    final subtitleFontSize = isCompact ? 12.0 : (isMobile ? 14.0 : 18.0);
    return Column(
          children: [
            // Main title with enhanced styling
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 12 : 20,
                vertical: isCompact ? 4 : 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(26),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.white.withAlpha(77), width: 1),
              ),
              child: Text(
                'EnergySmart',
                style: ResponsiveText.headline(context).copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: titleFontSize,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            SizedBox(height: isCompact ? 8 : 16),
            // Subtitle with icon
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Iconsax.flash,
                  color: Colors.white.withAlpha(204),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Empowering Smart Energy Management',
                  style: ResponsiveText.body(context).copyWith(
                    color: Colors.white.withAlpha(230),
                    fontSize: subtitleFontSize,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(width: 8),
                Icon(
                  Iconsax.flash,
                  color: Colors.white.withAlpha(204),
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Version indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                'Admin Dashboard v2.0',
                style: ResponsiveText.caption(context).copyWith(
                  color: Colors.white.withAlpha(204),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 1000.ms, delay: 400.ms)
        .slideY(begin: 0.3, end: 0);
  }

  Widget _buildEnergyAnimation() {
    return Container(
      width: 200,
      height: 200,
      child: Lottie.asset(
        'assets/animations/energy_wave.json', // You can add this Lottie file
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to a simple animated icon if Lottie file is not available
          return Icon(
                Iconsax.flash_1,
                size: 80,
                color: Colors.white.withAlpha(179),
              )
              .animate(onPlay: (controller) => controller.repeat())
              .rotate(duration: 3000.ms)
              .then()
              .fadeOut(duration: 500.ms)
              .then()
              .fadeIn(duration: 500.ms);
        },
      ),
    ).animate().fadeIn(duration: 1000.ms, delay: 600.ms);
  }

  Widget _buildFooter({bool isCompact = false}) {
    return Column(
      children: [
        SizedBox(height: isCompact ? 20 : 32),
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                AppColor.accentGreen.withAlpha(77),
                Colors.transparent,
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.copyright, size: 14, color: AppColor.textSecondary),
            const SizedBox(width: 6),
            Text(
              '2025 EnergySmart',
              style: ResponsiveText.caption(context).copyWith(
                color: AppColor.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: AppColor.accentGreen,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'All Rights Reserved',
              style: ResponsiveText.caption(context).copyWith(
                color: AppColor.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColor.accentGreen.withAlpha(26),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColor.accentGreen.withAlpha(51),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Iconsax.security_safe,
                size: 12,
                color: AppColor.accentGreen,
              ),
              const SizedBox(width: 6),
              Text(
                'Secured by Firebase',
                style: ResponsiveText.caption(context).copyWith(
                  color: AppColor.accentGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'dev: Rey Francisco',
                style: ResponsiveText.caption(context).copyWith(
                  color: AppColor.accentGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 1000.ms, delay: 800.ms);
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final adminUser = await _authService.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (adminUser != null && mounted) {
        _showSuccessSnackBar('Welcome back, ${adminUser.email}!');

        // The AdminAuthWrapper will automatically handle navigation
        // No need to manually navigate as the auth state change will trigger it
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage;
        switch (e.code) {
          case 'user-not-found':
            errorMessage = 'No admin found for this email address.';
            break;
          case 'wrong-password':
            errorMessage = 'Incorrect password. Please try again.';
            break;
          case 'invalid-email':
            errorMessage = 'Invalid email format. Please check your email.';
            break;
          case 'user-disabled':
            errorMessage = 'This admin account has been disabled.';
            break;
          case 'too-many-requests':
            errorMessage = 'Too many failed attempts. Please try again later.';
            break;
          case 'network-request-failed':
            errorMessage = 'Network error. Please check your connection.';
            break;
          default:
            errorMessage = 'Login failed. Please try again.';
        }
        _showErrorSnackBar(errorMessage);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('An unexpected error occurred. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Reset Password', style: ResponsiveText.title(context)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter your email address to receive password reset instructions.',
                  style: ResponsiveText.body(
                    context,
                  ).copyWith(color: AppColor.textSecondary),
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'Email Address',
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Iconsax.sms,
                ),
              ],
            ),
            actions: [
              AuthTextButton(
                text: 'Cancel',
                onPressed: () => Navigator.of(context).pop(),
                textColor: AppColor.textSecondary,
              ),
              AuthButton(
                text: 'Send Reset Email',
                onPressed: () async {
                  try {
                    await _authService.resetPassword(
                      emailController.text.trim(),
                    );
                    Navigator.of(context).pop();
                    _showSuccessSnackBar('Password reset email sent!');
                  } catch (e) {
                    _showErrorSnackBar(e.toString());
                  }
                },
                isPrimary: true,
              ),
            ],
          ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: AwesomeSnackbarContent(
          title: 'Success!',
          message: message,
          contentType: ContentType.success,
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: AwesomeSnackbarContent(
          title: 'Error!',
          message: message,
          contentType: ContentType.failure,
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}
