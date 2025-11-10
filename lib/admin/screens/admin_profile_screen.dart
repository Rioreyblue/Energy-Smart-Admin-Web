import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import '../../constants/constant.dart';
import '../services/firebase_auth_service.dart';
import '../models/firebase_chat_models.dart';
import '../utils/responsive_layout.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuthService _authService = FirebaseAuthService();
  late TabController _tabController;

  FirebaseUser? _currentUser;
  bool _isLoading = true;
  bool _isSuperAdmin = false;

  // Profile form controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _photoUrlController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Add admin form controllers
  final _addAdminNameController = TextEditingController();
  final _addAdminEmailController = TextEditingController();
  final _addAdminPasswordController = TextEditingController();

  List<FirebaseUser> _adminUsers = [];
  bool _isLoadingAdminUsers = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        // Use the new method that ensures user data exists
        final userData = await _authService.ensureCurrentUserData();
        if (userData != null) {
          final isSuperAdmin = userData.role == 'super_admin';

          setState(() {
            _currentUser = userData;
            _isSuperAdmin = isSuperAdmin;
            _nameController.text = userData.name;
            _emailController.text = userData.email;
            _photoUrlController.text = userData.photoUrl ?? '';
            _isLoading = false;
          });

          // Load admin users asynchronously without blocking UI
          if (isSuperAdmin) {
            _loadAdminUsersAsync();
          }
        } else {
          // Try to create admin data manually as fallback
          await _createFallbackAdminData(currentUser);
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('No user currently signed in');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error loading profile: $e');
    }
  }

  /// Fallback method to create admin data if all else fails
  Future<void> _createFallbackAdminData(currentUser) async {
    try {
      // Create a basic admin user
      final fallbackUser = FirebaseUser(
        id: currentUser.uid,
        name:
            currentUser.displayName ??
            currentUser.email?.split('@')[0] ??
            'Admin User',
        email: currentUser.email ?? 'admin@energysmart.com',
        role: 'admin',
        photoUrl: currentUser.photoURL,
        createdAt: DateTime.now(),
        lastSeen: DateTime.now(),
        isOnline: true,
      );

      setState(() {
        _currentUser = fallbackUser;
        _isSuperAdmin = false;
        _nameController.text = fallbackUser.name;
        _emailController.text = fallbackUser.email;
        _isLoading = false;
      });

      _showSuccessSnackBar('Profile loaded with default admin settings');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to create admin profile: $e');
    }
  }

  // Load admin users asynchronously without blocking UI
  Future<void> _loadAdminUsersAsync() async {
    if (_isLoadingAdminUsers) return; // Prevent multiple concurrent loads

    setState(() {
      _isLoadingAdminUsers = true;
    });

    try {
      final adminUsers = await _authService.getAdminUsers();
      if (mounted) {
        setState(() {
          _adminUsers = adminUsers;
          _isLoadingAdminUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAdminUsers = false;
        });
        _showErrorSnackBar('Error loading admin users: $e');
      }
    }
  }

  Future<void> _loadAdminUsers() async {
    try {
      final adminUsers = await _authService.getAdminUsers();
      setState(() {
        _adminUsers = adminUsers;
      });
    } catch (e) {
      _showErrorSnackBar('Error loading admin users: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColor.accentGreen),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColor.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColor.textPrimary,
        elevation: 0,
        title: Text(
          'Admin Profile',
          style: ResponsiveText.title(
            context,
          ).copyWith(fontWeight: FontWeight.bold, color: AppColor.textPrimary),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColor.accentGreen,
          unselectedLabelColor: AppColor.textSecondary,
          indicatorColor: AppColor.accentGreen,
          tabs: [
            const Tab(text: 'Profile', icon: Icon(Iconsax.profile_circle)),
            const Tab(text: 'Security', icon: Icon(Iconsax.security_safe)),
            if (_isSuperAdmin)
              const Tab(text: 'Manage Admins', icon: Icon(Iconsax.people)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProfileTab(),
          _buildSecurityTab(),
          if (_isSuperAdmin) _buildManageAdminsTab(),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ResponsiveLayout(
        mobile: _buildProfileForm(),
        desktop: Center(
          child: SizedBox(width: 600, child: _buildProfileForm()),
        ),
      ),
    );
  }

  Widget _buildProfileForm() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Row(
              children: [
                _buildProfileAvatar(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentUser?.name ?? 'Admin User',
                        style: ResponsiveText.title(context).copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColor.textPrimary,
                        ),
                      ),
                      Text(
                        _isSuperAdmin ? 'Super Administrator' : 'Administrator',
                        style: ResponsiveText.body(context).copyWith(
                          color: AppColor.accentGreen,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _currentUser?.email ?? '',
                        style: ResponsiveText.caption(
                          context,
                        ).copyWith(color: AppColor.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _showChangeAvatarDialog,
                  icon: const Icon(Iconsax.camera),
                  tooltip: 'Change Avatar',
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Profile Form
            Text(
              'Profile Information',
              style: ResponsiveText.body(context).copyWith(
                fontWeight: FontWeight.bold,
                color: AppColor.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(Iconsax.profile_circle),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColor.accentGreen),
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email Address',
                prefixIcon: const Icon(Iconsax.sms),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColor.accentGreen),
                ),
              ),
              enabled: false, // Email cannot be changed
            ),
            const SizedBox(height: 24),

            TextFormField(
              controller: _photoUrlController,
              decoration: InputDecoration(
                labelText: 'Photo URL',
                prefixIcon: const Icon(Iconsax.image),
                hintText: 'https://.../profile.jpg',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColor.accentGreen),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetForm,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppColor.textSecondary),
                    ),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _updateProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColor.accentGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Update Profile'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ResponsiveLayout(
        mobile: _buildSecurityForm(),
        desktop: Center(
          child: SizedBox(width: 600, child: _buildSecurityForm()),
        ),
      ),
    );
  }

  Widget _buildSecurityForm() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Change Password',
              style: ResponsiveText.title(context).copyWith(
                fontWeight: FontWeight.bold,
                color: AppColor.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _currentPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Current Password',
                prefixIcon: const Icon(Iconsax.lock),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColor.accentGreen),
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password',
                prefixIcon: const Icon(Iconsax.lock),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColor.accentGreen),
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                prefixIcon: const Icon(Iconsax.lock),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColor.accentGreen),
                ),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.accentGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Change Password'),
              ),
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            // Account Status
            _buildAccountStatus(),
          ],
        ),
      ),
    );
  }

  Widget _buildManageAdminsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add Admin Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Iconsax.user_add, color: AppColor.accentGreen),
                      const SizedBox(width: 8),
                      Text(
                        'Add New Admin',
                        style: ResponsiveText.title(context).copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColor.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _addAdminNameController,
                          decoration: InputDecoration(
                            labelText: 'Admin Name',
                            prefixIcon: const Icon(Iconsax.profile_circle),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _addAdminEmailController,
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: const Icon(Iconsax.sms),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _addAdminPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Temporary Password',
                      prefixIcon: const Icon(Iconsax.lock),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: _addAdmin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColor.accentGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Add Admin'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Admin List Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Iconsax.people, color: AppColor.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Admin Users (${_adminUsers.length})',
                        style: ResponsiveText.title(context).copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColor.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _loadAdminUsers,
                        icon: const Icon(Iconsax.refresh),
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_isLoadingAdminUsers)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColor.accentGreen,
                          ),
                        ),
                      ),
                    )
                  else if (_adminUsers.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No admin users found'),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _adminUsers.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final admin = _adminUsers[index];
                        return _buildAdminListItem(admin);
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminListItem(FirebaseUser admin) {
    final isCurrentUser = admin.id == _currentUser?.id;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            admin.role == 'super_admin'
                ? AppColor.accentRed
                : AppColor.accentGreen,
        child: Text(
          admin.name.split(' ').map((e) => e[0]).take(2).join(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Row(
        children: [
          Text(
            admin.name,
            style: ResponsiveText.body(context).copyWith(
              fontWeight: FontWeight.w600,
              color: AppColor.textPrimary,
            ),
          ),
          if (isCurrentUser) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColor.accentGreen.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'You',
                style: ResponsiveText.caption(context).copyWith(
                  color: AppColor.accentGreen,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(admin.email),
          Text(
            admin.role == 'super_admin'
                ? 'Super Administrator'
                : 'Administrator',
            style: ResponsiveText.caption(context).copyWith(
              color:
                  admin.role == 'super_admin'
                      ? AppColor.accentRed
                      : AppColor.accentGreen,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      trailing:
          admin.role != 'super_admin' && !isCurrentUser
              ? PopupMenuButton<String>(
                onSelected: (value) => _handleAdminAction(value, admin),
                itemBuilder:
                    (context) => [
                      const PopupMenuItem(
                        value: 'promote',
                        child: Row(
                          children: [
                            Icon(Icons.star, size: 16),
                            SizedBox(width: 8),
                            Text('Promote to Super Admin'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'reset_password',
                        child: Row(
                          children: [
                            Icon(Iconsax.key, size: 16),
                            SizedBox(width: 8),
                            Text('Send Password Reset'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'disable',
                        child: Row(
                          children: [
                            Icon(Iconsax.pause, size: 16, color: Colors.orange),
                            SizedBox(width: 8),
                            Text(
                              'Disable Admin',
                              style: TextStyle(color: Colors.orange),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(
                              Iconsax.trash,
                              size: 16,
                              color: AppColor.accentRed,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Remove Admin',
                              style: TextStyle(color: AppColor.accentRed),
                            ),
                          ],
                        ),
                      ),
                    ],
              )
              : null,
    );
  }

  Widget _buildAccountStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account Status',
          style: ResponsiveText.body(
            context,
          ).copyWith(fontWeight: FontWeight.bold, color: AppColor.textPrimary),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: AppColor.accentGreen,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Account Active',
              style: ResponsiveText.body(context).copyWith(
                color: AppColor.accentGreen,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Text(
          'Last login: ${_formatDateTime(_currentUser?.lastSeen ?? DateTime.now())}',
          style: ResponsiveText.caption(
            context,
          ).copyWith(color: AppColor.textSecondary),
        ),
        Text(
          'Account created: ${_formatDateTime(_currentUser?.createdAt ?? DateTime.now())}',
          style: ResponsiveText.caption(
            context,
          ).copyWith(color: AppColor.textSecondary),
        ),
      ],
    );
  }

  Widget _buildProfileAvatar() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: _isSuperAdmin ? AppColor.accentRed : AppColor.accentGreen,
        shape: BoxShape.circle,
        border: Border.all(color: AppColor.surface, width: 3),
      ),
      child:
          _currentUser?.photoUrl != null
              ? ClipOval(
                child: Image.network(
                  _currentUser!.photoUrl!,
                  fit: BoxFit.cover,
                ),
              )
              : Icon(
                _isSuperAdmin ? Icons.star : Iconsax.profile_circle,
                color: Colors.white,
                size: 40,
              ),
    );
  }

  // Action Methods
  void _resetForm() {
    _nameController.text = _currentUser?.name ?? '';
    _emailController.text = _currentUser?.email ?? '';
    _photoUrlController.text = _currentUser?.photoUrl ?? '';
  }

  Future<void> _updateProfile() async {
    try {
      if (_currentUser != null) {
        await _authService.updateUserProfile(
          userId: _currentUser!.id,
          name: _nameController.text.trim(),
          photoUrl:
              _photoUrlController.text.trim().isEmpty
                  ? null
                  : _photoUrlController.text.trim(),
        );

        _showSuccessSnackBar('Profile updated successfully');
        _loadCurrentUser(); // Reload user data
      }
    } catch (e) {
      _showErrorSnackBar('Error updating profile: $e');
    }
  }

  Future<void> _changePassword() async {
    if (_currentPasswordController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter your current password');
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showErrorSnackBar('New passwords do not match');
      return;
    }

    if (_newPasswordController.text.length < 6) {
      _showErrorSnackBar('Password must be at least 6 characters');
      return;
    }

    if (_newPasswordController.text == _currentPasswordController.text) {
      _showErrorSnackBar(
        'New password must be different from current password',
      );
      return;
    }

    try {
      await _authService.changePassword(
        currentPassword: _currentPasswordController.text.trim(),
        newPassword: _newPasswordController.text.trim(),
      );

      _showSuccessSnackBar('Password changed successfully');

      // Clear form
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } catch (e) {
      _showErrorSnackBar('Error changing password: $e');
    }
  }

  Future<void> _addAdmin() async {
    final name = _addAdminNameController.text.trim();
    final email = _addAdminEmailController.text.trim();
    final password = _addAdminPasswordController.text.trim();

    // Validation
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showErrorSnackBar('Please fill in all fields');
      return;
    }

    if (name.length < 2) {
      _showErrorSnackBar('Name must be at least 2 characters');
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showErrorSnackBar('Please enter a valid email address');
      return;
    }

    if (password.length < 6) {
      _showErrorSnackBar('Password must be at least 6 characters');
      return;
    }

    // Check if email already exists in admin list
    if (_adminUsers.any(
      (admin) => admin.email.toLowerCase() == email.toLowerCase(),
    )) {
      _showErrorSnackBar('An admin with this email already exists');
      return;
    }

    try {
      await _authService.createAdminUser(
        email: email,
        password: password,
        name: name,
      );

      _showSuccessSnackBar('Admin user created successfully');

      // Clear form
      _addAdminNameController.clear();
      _addAdminEmailController.clear();
      _addAdminPasswordController.clear();

      // Reload admin list
      _loadAdminUsers();
    } catch (e) {
      _showErrorSnackBar('Error creating admin: $e');
    }
  }

  void _handleAdminAction(String action, FirebaseUser admin) {
    switch (action) {
      case 'promote':
        _showPromoteDialog(admin);
        break;
      case 'reset_password':
        _showPasswordResetDialog(admin);
        break;
      case 'disable':
        _showDisableAdminDialog(admin);
        break;
      case 'remove':
        _showRemoveAdminDialog(admin);
        break;
    }
  }

  void _showPromoteDialog(FirebaseUser admin) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Promote to Super Admin'),
            content: Text(
              'Are you sure you want to promote ${admin.name} to Super Administrator? '
              'This will give them full administrative privileges.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _promoteToSuperAdmin(admin);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.accentRed,
                ),
                child: const Text('Promote'),
              ),
            ],
          ),
    );
  }

  void _showRemoveAdminDialog(FirebaseUser admin) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Remove Admin'),
            content: Text(
              'Are you sure you want to remove ${admin.name} as an administrator? '
              'This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _removeAdmin(admin);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.accentRed,
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
    );
  }

  Future<void> _promoteToSuperAdmin(FirebaseUser admin) async {
    try {
      await _authService.updateUserProfile(
        userId: admin.id,
        additionalData: {'role': 'super_admin'},
      );

      _showSuccessSnackBar('${admin.name} promoted to Super Administrator');
      _loadAdminUsers();
    } catch (e) {
      _showErrorSnackBar('Error promoting admin: $e');
    }
  }

  Future<void> _removeAdmin(FirebaseUser admin) async {
    try {
      await _authService.removeAdminUser(admin.id);
      _showSuccessSnackBar('${admin.name} has been removed from admin role');
      _loadAdminUsers(); // Refresh admin list
    } catch (e) {
      _showErrorSnackBar('Error removing admin: $e');
    }
  }

  void _showPasswordResetDialog(FirebaseUser admin) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Send Password Reset'),
            content: Text(
              'Send a password reset email to ${admin.name} (${admin.email})?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _sendPasswordReset(admin);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.accentGreen,
                ),
                child: const Text('Send Reset Email'),
              ),
            ],
          ),
    );
  }

  void _showDisableAdminDialog(FirebaseUser admin) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Disable Admin'),
            content: Text(
              'Are you sure you want to disable ${admin.name}? '
              'They will lose admin access but their account will remain active.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _disableAdmin(admin);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Disable'),
              ),
            ],
          ),
    );
  }

  Future<void> _sendPasswordReset(FirebaseUser admin) async {
    try {
      await _authService.sendAdminPasswordReset(admin.email);
      _showSuccessSnackBar('Password reset email sent to ${admin.email}');
    } catch (e) {
      _showErrorSnackBar('Error sending password reset: $e');
    }
  }

  Future<void> _disableAdmin(FirebaseUser admin) async {
    try {
      await _authService.disableAdminUser(admin.id);
      _showSuccessSnackBar('${admin.name} has been disabled');
      _loadAdminUsers(); // Refresh admin list
    } catch (e) {
      _showErrorSnackBar('Error disabling admin: $e');
    }
  }

  void _showChangeAvatarDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Change Avatar'),
            content: const Text(
              'Avatar change functionality will be implemented with image upload.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  // Utility Methods
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: AwesomeSnackbarContent(
          title: 'Success',
          message: message,
          contentType: ContentType.success,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: AwesomeSnackbarContent(
          title: 'Error',
          message: message,
          contentType: ContentType.failure,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _photoUrlController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _addAdminNameController.dispose();
    _addAdminEmailController.dispose();
    _addAdminPasswordController.dispose();
    super.dispose();
  }
}
