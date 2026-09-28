import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Dynamic user credentials & details loaded from Firebase / Google Account
  String _fullName = 'Explorer';
  String _email = 'explorer@nextripia.ai';
  String _authProvider = 'Google Sign-In';
  String _memberSince = 'September 2026';
  String? _photoUrl;

  bool _notificationsEnabled = true;

  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'September 2026';
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Fetch from Firebase Auth currentUser
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      if (mounted) {
        setState(() {
          if (currentUser.displayName != null && currentUser.displayName!.trim().isNotEmpty) {
            _fullName = currentUser.displayName!.trim();
          } else if (currentUser.email != null && currentUser.email!.isNotEmpty) {
            _fullName = currentUser.email!.split('@').first;
          }

          if (currentUser.email != null && currentUser.email!.isNotEmpty) {
            _email = currentUser.email!;
          }

          if (currentUser.photoURL != null && currentUser.photoURL!.isNotEmpty) {
            _photoUrl = currentUser.photoURL;
          }

          if (currentUser.metadata.creationTime != null) {
            _memberSince = _formatDate(currentUser.metadata.creationTime);
          }

          if (currentUser.providerData.any((p) => p.providerId == 'google.com')) {
            _authProvider = 'Google Sign-In';
          } else if (currentUser.providerData.any((p) => p.providerId == 'password')) {
            _authProvider = 'Email & Password';
          } else {
            _authProvider = 'Google Account';
          }
        });
      }

      // Check for local customized photo override
      final savedPhotoPath = prefs.getString('user_profile_image_path');
      if (savedPhotoPath != null && File(savedPhotoPath).existsSync()) {
        if (mounted) {
          setState(() {
            _profileImage = File(savedPhotoPath);
          });
        }
      }

      // 2. Fetch extra profile fields from Cloud Firestore
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
        if (doc.exists && doc.data() != null && mounted) {
          final data = doc.data()!;
          setState(() {
            if (data['displayName'] != null && (data['displayName'] as String).isNotEmpty) {
              _fullName = data['displayName'];
            }
            if (data['photoUrl'] != null && (data['photoUrl'] as String).isNotEmpty && _profileImage == null) {
              _photoUrl = data['photoUrl'];
            }
          });
        }
      } catch (e) {
        debugPrint('Firestore profile load note: $e');
      }
    } else {
      // Offline / guest mode - load saved prefs
      final savedName = prefs.getString('user_profile_name');
      final savedEmail = prefs.getString('user_profile_email');
      final savedPhotoPath = prefs.getString('user_profile_image_path');

      if (mounted) {
        setState(() {
          if (savedName != null && savedName.isNotEmpty) _fullName = savedName;
          if (savedEmail != null && savedEmail.isNotEmpty) _email = savedEmail;
          if (savedPhotoPath != null && File(savedPhotoPath).existsSync()) {
            _profileImage = File(savedPhotoPath);
          }
          _authProvider = 'Guest User';
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                source == ImageSource.camera
                    ? 'Photo captured & uploaded to profile!'
                    : 'Photo selected & updated from storage!',
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access image: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _showPhotoSourceBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Profile Photo',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Capture a live photo or upload from your device storage',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            // Option 1: Camera
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE0E7FF)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Take Photo',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Click on-spot photo using your camera',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Option 2: Gallery / Storage
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFDCFCE7)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.photo_library_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upload from Storage',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Choose an existing photo from gallery',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),
            if (_profileImage != null || (_photoUrl != null && _photoUrl!.isNotEmpty)) ...[
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  Navigator.pop(ctx);
                  setState(() {
                    _profileImage = null;
                    _photoUrl = null;
                  });
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('user_profile_image_path');
                  await prefs.remove('user_profile_photo_url');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Profile photo removed'),
                        backgroundColor: const Color(0xFF64748B),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFEE2E2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFFEF4444),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Remove Photo',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Revert back to initial letter avatar',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showEditProfileBottomSheet() {
    final nameController = TextEditingController(text: _fullName);
    final emailController = TextEditingController(text: _email);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Edit Profile Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E1B4B),
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField('Full Name', Icons.person_outline, nameController),
              const SizedBox(height: 14),
              _buildTextField('Email Address', Icons.email_outlined, emailController),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final newName = nameController.text.trim().isNotEmpty
                        ? nameController.text.trim()
                        : _fullName;
                    final newEmail = emailController.text.trim().isNotEmpty
                        ? emailController.text.trim()
                        : _email;

                    setState(() {
                      _fullName = newName;
                      _email = newEmail;
                    });

                    // Save locally to SharedPreferences
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('user_profile_name', newName);
                    await prefs.setString('user_profile_email', newEmail);

                    // Update in Firebase Auth and Firestore if logged in
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      if (newName != user.displayName) {
                        user.updateDisplayName(newName).catchError((_) {});
                      }
                      FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                        'displayName': newName,
                        'email': newEmail,
                      }, SetOptions(merge: true)).catchError((e) {
                        debugPrint('Firestore update profile note: $e');
                      });
                    }

                    if (!mounted || !ctx.mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile updated successfully!'),
                        backgroundColor: Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: const TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      cursorColor: const Color(0xFF6366F1),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFF334155),
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        floatingLabelStyle: const TextStyle(
          color: Color(0xFF4F46E5),
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF4F46E5), size: 22),
        filled: true,
        fillColor: const Color(0xFFF8F9FE),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF94A3B8), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF94A3B8), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2.2),
        ),
      ),
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out from NexTripia-AI?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await FirebaseAuth.instance.signOut();
              } catch (_) {}
              try {
                await GoogleSignIn().signOut();
              } catch (_) {}
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isDark) {
    final initial = _fullName.trim().isNotEmpty
        ? _fullName.trim()[0].toUpperCase()
        : (_email.isNotEmpty ? _email[0].toUpperCase() : 'U');

    Widget content;
    if (_profileImage != null) {
      content = ClipOval(
        child: Image.file(
          _profileImage!,
          width: 88,
          height: 88,
          fit: BoxFit.cover,
        ),
      );
    } else if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      content = ClipOval(
        child: Image.network(
          _photoUrl!,
          width: 88,
          height: 88,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => Center(
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
      );
    } else {
      content = Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );
    }

    final bool hasImage = _profileImage != null || (_photoUrl != null && _photoUrl!.isNotEmpty);

    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        gradient: !hasImage
            ? const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: hasImage ? (isDark ? const Color(0xFF334155) : Colors.grey.shade200) : null,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'My Profile',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E1B4B),
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF6366F1)),
            tooltip: 'Edit Profile',
            onPressed: _showEditProfileBottomSheet,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        child: Column(
          children: [
            // User Header Card
            _buildProfileHeaderCard(),
            const SizedBox(height: 24),

            // Login / User Details Section
            _buildSectionHeader('Login & Account Details'),
            const SizedBox(height: 12),
            _buildAccountDetailsCard(),
            const SizedBox(height: 24),

            // Settings & Preferences Section
            _buildSectionHeader('Preferences'),
            const SizedBox(height: 12),
            _buildPreferencesCard(),
            const SizedBox(height: 28),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? const Color(0xFFF87171) : Colors.red.shade600,
                  side: BorderSide(color: isDark ? const Color(0xFF7F1D1D) : Colors.red.shade200),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text(
                  'Log Out',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: _handleLogout,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeaderCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar with edit badge
          Stack(
            children: [
              GestureDetector(
                onTap: _showPhotoSourceBottomSheet,
                child: _buildAvatar(isDark),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _showPhotoSourceBottomSheet,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // User Name
          Text(
            _fullName,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),

          // User Email
          Text(
            _email,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Karnataka Explorer Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_rounded,
                  size: 16,
                  color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF6366F1),
                ),
                const SizedBox(width: 6),
                Text(
                  'Karnataka Explorer',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E1B4B),
        ),
      ),
    );
  }

  Widget _buildAccountDetailsCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildDetailRow(
            icon: Icons.person_rounded,
            iconColor: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
            bgColor: isDark ? const Color(0xFF2E1065) : const Color(0xFFF3E8FF),
            label: 'Full Name',
            value: _fullName,
          ),
          _buildDivider(),
          _buildDetailRow(
            icon: Icons.email_rounded,
            iconColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
            bgColor: isDark ? const Color(0xFF082F49) : const Color(0xFFE0F2FE),
            label: 'Email',
            value: _email,
          ),

          _buildDivider(),
          _buildDetailRow(
            icon: Icons.lock_person_rounded,
            iconColor: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF6366F1),
            bgColor: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF),
            label: 'Auth Method',
            value: _authProvider,
          ),
          _buildDivider(),
          _buildDetailRow(
            icon: Icons.calendar_today_rounded,
            iconColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            bgColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
            label: 'Member Since',
            value: _memberSince,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required String value,
    bool isLast = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Divider(
      height: 1,
      thickness: 1,
      indent: 68,
      endIndent: 16,
      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
    );
  }

  Widget _buildPreferencesCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Push Notifications
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF312E81) : const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.notifications_active_rounded,
                    color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF7C3AED),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Push Notifications',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E1B4B),
                        ),
                      ),
                      Text(
                        'Trip updates & recommendations',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _notificationsEnabled,
                  activeThumbColor: const Color(0xFF818CF8),
                  activeTrackColor: const Color(0xFF4338CA),
                  onChanged: (val) {
                    setState(() {
                      _notificationsEnabled = val;
                    });
                  },
                ),
              ],
            ),
          ),
          _buildDivider(),

          // Dark Theme Toggle (Requested under Push Notifications)
          InkWell(
            onTap: () {
              AppTheme.toggleTheme();
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF312E81) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFFD97706),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDark ? 'Dark Theme' : 'Light Theme',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E1B4B),
                          ),
                        ),
                        Text(
                          isDark ? 'Tap to switch to Light Theme' : 'Tap to switch to Dark Theme',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isDark,
                    activeThumbColor: const Color(0xFF818CF8),
                    activeTrackColor: const Color(0xFF4338CA),
                    inactiveThumbColor: const Color(0xFF64748B),
                    inactiveTrackColor: const Color(0xFFE2E8F0),
                    onChanged: (val) {
                      AppTheme.toggleTheme();
                    },
                  ),
                ],
              ),
            ),
          ),
          _buildDivider(),

          // Default Travel Region
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.map_rounded,
                color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF6366F1),
                size: 20,
              ),
            ),
            title: Text(
              'Default Travel Region',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E1B4B),
              ),
            ),
            subtitle: Text(
              'Karnataka, India',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('App is currently set to Karnataka State.')),
              );
            },
          ),
        ],
      ),
    );
  }
}
