import '../../widgets/animations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../main_navigation_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isRegisterMode = false;
  bool _obscurePassword = true;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  String _selectedYear = AppConstants.academicYears.first;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (email.isEmpty || !email.contains('@')) {
      messenger.showSnackBar(const SnackBar(content: Text('اكتب بريدك الإلكتروني أولًا ثم اضغط «نسيت كلمة المرور»')));
      return;
    }
    final error = await Provider.of<UserAuthProvider>(context, listen: false).resetPassword(email);
    messenger.showSnackBar(SnackBar(
      content: Text(error ?? 'تم إرسال رابط إعادة تعيين كلمة المرور إلى $email'),
      backgroundColor: error == null ? Colors.green : Colors.redAccent,
    ));
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<UserAuthProvider>(context, listen: false);

    bool success;
    if (_isRegisterMode) {
      success = await auth.register(
        email: _emailController.text,
        password: _passwordController.text,
        displayName: _nameController.text,
        academicYear: _selectedYear,
      );
    } else {
      success = await auth.signIn(
        _emailController.text,
        _passwordController.text,
      );
    }

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        AppRoute.fadeSlide(const MainNavigationScreen()),
      );
    }
  }

  void _handleGuestEntry() {
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    auth.loginAsGuest();
    Navigator.pushReplacement(
      context,
      AppRoute.fadeSlide(const MainNavigationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<UserAuthProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Branding Header
                  Center(
                    child: Floating(child: const AppLogo(size: 120, hero: true, glow: true)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isRegisterMode ? 'إنشاء حساب طالب' : 'مرحبًا بك في GenZoo',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isRegisterMode
                        ? 'انضم لمجتمع كليتك للمواد والإعلانات والأدوات'
                        : 'سجّل الدخول للوصول إلى المواد الدراسية والإعلانات',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Mode Toggle Segment
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _isRegisterMode = false);
                              auth.clearError();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_isRegisterMode ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: !_isRegisterMode
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Text(
                                'تسجيل الدخول',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: !_isRegisterMode ? FontWeight.bold : FontWeight.w500,
                                  color: !_isRegisterMode ? AppColors.primary : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _isRegisterMode = true);
                              auth.clearError();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _isRegisterMode ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _isRegisterMode
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Text(
                                'حساب جديد',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: _isRegisterMode ? FontWeight.bold : FontWeight.w500,
                                  color: _isRegisterMode ? AppColors.primary : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Error Banner
                  if (auth.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              auth.errorMessage!,
                              style: const TextStyle(color: AppColors.error, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Auth Form
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_isRegisterMode) ...[
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'الاسم الكامل',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'من فضلك أدخل اسمك' : null,
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            value: _selectedYear,
                            decoration: const InputDecoration(
                              labelText: 'الفرقة الدراسية',
                              prefixIcon: Icon(Icons.class_outlined),
                            ),
                            items: AppConstants.academicYears.map((year) {
                              return DropdownMenuItem(value: year, child: Text(year));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedYear = val);
                            },
                          ),
                          const SizedBox(height: 14),
                        ],

                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'من فضلك أدخل بريدك الإلكتروني';
                            if (!v.contains('@')) return 'أدخل بريدًا إلكترونيًا صحيحًا';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() => _obscurePassword = !_obscurePassword);
                              },
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.length < 6) {
                              return 'كلمة المرور يجب ألا تقل عن 6 أحرف';
                            }
                            return null;
                          },
                        ),
                        if (!_isRegisterMode)
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton(
                              onPressed: _handleForgotPassword,
                              child: const Text('نسيت كلمة المرور؟'),
                            ),
                          ),

                        const SizedBox(height: 16),

                        // Submit Button
                        ElevatedButton(
                          onPressed: auth.isLoading ? null : _handleSubmit,
                          child: auth.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  _isRegisterMode ? 'إنشاء الحساب' : 'تسجيل الدخول',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Guest Access Button
                  OutlinedButton.icon(
                    onPressed: _handleGuestEntry,
                    icon: const Icon(Icons.explore_outlined),
                    label: const Text('الدخول كزائر'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
