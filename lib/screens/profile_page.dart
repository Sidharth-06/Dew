import 'package:appwrite/models.dart' as models;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dew/config/appwrite_config.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dew/core/theme/aura_colors.dart';
import 'package:dew/core/widgets/glass_container.dart';
import 'package:dew/services/appwrite_service.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  models.User? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      final user = await AppwriteService().account.get();
      if (mounted) setState(() => _user = user);
    } catch (_) {
      // Not logged in
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await AppwriteService().account.deleteSession(sessionId: 'current');
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) context.go('/login');
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuraColors.deepBlack,
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(color: AuraColors.electricViolet))
          : _user == null
              ? _buildGuestView()
              : _buildUserView(_user!),
    );
  }

  Widget _buildGuestView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A1A2E),
            AuraColors.deepBlack,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AuraColors.electricViolet.withOpacity(0.1),
                border: Border.all(
                    color: AuraColors.electricViolet.withOpacity(0.3),
                    width: 1),
              ),
              child: const Icon(Icons.person_outline_rounded,
                  size: 60, color: AuraColors.electricViolet),
            ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 24),
            Text(
              'Join the Community',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
            const SizedBox(height: 12),
            Text(
              'Sign in to track history, join chatrooms,\nand listen with friends.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  height: 1.5,
                  fontSize: 16),
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 48),
            _buildAuthButton(
              label: 'Sign In',
              color: AuraColors.electricViolet,
              onTap: () => context.push('/login'),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
            const SizedBox(height: 16),
            _buildAuthButton(
              label: 'Create Account',
              color: Colors.transparent,
              borderColor: Colors.white24,
              onTap: () => context.push('/register'),
            ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildUserView(models.User user) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildProfileHeader(user),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SOCIAL',
                  style: TextStyle(
                    color: AuraColors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSocialGrid(),
                const SizedBox(height: 32),
                const Text(
                  'ACCOUNT',
                  style: TextStyle(
                    color: AuraColors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                _buildAccountOptions(user),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(models.User user) {
    return Stack(
      children: [
        Container(
          height: 300,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AuraColors.electricViolet.withOpacity(0.4),
                AuraColors.deepBlack,
              ],
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 300,
          child: FutureBuilder<models.Document>(
            future: AppwriteService().databases.getDocument(
                  databaseId: AppwriteConfig.databaseId,
                  collectionId: 'users',
                  documentId: user.$id,
                ),
            builder: (context, snapshot) {
              final userData = snapshot.data?.data;
              final username = userData?['username'] ?? user.name;
              final photoUrl = userData?['profilePictureUrl'];

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.black26,
                      backgroundImage: photoUrl != null
                          ? CachedNetworkImageProvider(photoUrl)
                          : null,
                      child: photoUrl == null
                          ? const Icon(Icons.person,
                              size: 50, color: Colors.white54)
                          : null,
                    ),
                  ).animate().scale(),
                  const SizedBox(height: 16),
                  Text(
                    username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ).animate().fadeIn().slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ).animate().fadeIn(delay: 100.ms),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSocialGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildSocialCard(
            title: 'Chatrooms',
            icon: Icons.chat_bubble_outline_rounded,
            color: const Color(0xFF4CAF50),
            onTap: () => context.push('/chatrooms'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSocialCard(
            title: 'Friends',
            icon: Icons.people_outline_rounded,
            color: const Color(0xFF2196F3),
            onTap: () => context.push('/friend-requests'),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: GlassContainer(
          height: 120,
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withOpacity(0.05),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountOptions(models.User user) {
    return Column(
      children: [
        // PC App Options
        _buildOptionTile(
          title: 'Scan QR to Login PC',
          icon: Icons.qr_code_scanner_rounded,
          onTap: () => context.push('/scan-qr'),
        ),
        const SizedBox(height: 12),
        _buildOptionTile(
          title: 'Manage Devices',
          icon: Icons.devices_rounded,
          onTap: () => context.push('/devices'),
        ),
        const SizedBox(height: 12),
        _buildOptionTile(
          title: 'Sign Out',
          icon: Icons.logout_rounded,
          textColor: Colors.redAccent,
          iconColor: Colors.redAccent,
          onTap: _signOut,
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Color textColor = Colors.white,
    Color iconColor = Colors.white70,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: GlassContainer(
          height: 60,
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.05),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white24, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
    Color? borderColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 250,
        height: 50,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(25),
          border: borderColor != null ? Border.all(color: borderColor) : null,
          boxShadow: color != Colors.transparent
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
