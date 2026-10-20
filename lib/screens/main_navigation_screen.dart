import '../widgets/animations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../core/constants/app_colors.dart';
import '../widgets/custom_widgets.dart';
import 'home/home_screen.dart';
import 'materials/materials_screen.dart';
import 'azkar/azkar_screen.dart';
import 'essential_info/essential_info_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'auth/login_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  final List<Widget> _screens = const [
    HomeScreen(),
    MaterialsScreen(),
    AzkarScreen(),
    EssentialInfoScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<UserAuthProvider>(context);
    final user = authProvider.user ?? AppUser.guestUser();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const AppLogo(size: 38, hero: true),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'بوابة GenZoo',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  user.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Dynamic Role Badge (Admin / Student / Guest)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: RoleBadge(role: user.role),
          ),

          // Admin Dashboard Direct Shortcut
          if (user.isAdmin)
            IconButton(
              icon: const Icon(Icons.dashboard_customize_rounded, color: AppColors.primary),
              tooltip: 'لوحة المسؤول',
              onPressed: () {
                Navigator.push(
                  context,
                  AppRoute.fadeSlide(const AdminDashboardScreen()),
                );
              },
            ),

          // Profile / Account Menu
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'حسابي',
            onPressed: () => _showAccountDialog(context, user, authProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        children: _screens.map((w) => KeepAlivePage(child: w)).toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.newspaper_outlined),
            selectedIcon: Icon(Icons.newspaper_rounded),
            label: 'الإعلانات',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder_rounded),
            label: 'المواد',
          ),
          NavigationDestination(
            icon: Icon(Icons.spa_outlined),
            selectedIcon: Icon(Icons.spa_rounded),
            label: 'الأذكار',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate_rounded),
            label: 'المعلومات والمعدل',
          ),
        ],
      ),
    );
  }

  void _showAccountDialog(BuildContext context, AppUser user, UserAuthProvider authProvider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  user.displayName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (user.email.isNotEmpty)
                  Text(
                    user.email,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                const SizedBox(height: 8),
                RoleBadge(role: user.role),
                const SizedBox(height: 20),
                const Divider(),
                if (user.isAdmin) ...[
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined, color: AppColors.primary),
                    title: const Text('فتح لوحة المسؤول'),
                    subtitle: const Text('انشر الأخبار وأدر الملفات والروابط'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        AppRoute.fadeSlide(const AdminDashboardScreen()),
                      );
                    },
                  ),
                ],
                ListTile(
                  leading: Icon(
                    user.role == UserRole.guest ? Icons.login : Icons.logout,
                    color: user.role == UserRole.guest ? AppColors.primary : AppColors.error,
                  ),
                  title: Text(
                    user.role == UserRole.guest ? 'تسجيل الدخول / حساب جديد' : 'تسجيل الخروج',
                    style: TextStyle(
                      color: user.role == UserRole.guest ? AppColors.primary : AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await authProvider.signOut();
                    if (context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        AppRoute.fadeSlide(const LoginScreen()),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
