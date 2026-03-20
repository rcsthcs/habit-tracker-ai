import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_colors.dart';
import '../core/theme_extensions.dart';
import '../providers/app_providers.dart';
import '../widgets/gradient_button.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool _isLogin = true;
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- Validators ---
  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty)
      return 'Введите имя пользователя';
    final v = value.trim();
    if (v.length < 3) return 'Минимум 3 символа';
    if (v.length > 30) return 'Максимум 30 символов';
    if (v.contains(' ')) return 'Пробелы запрещены';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v))
      return 'Только буквы, цифры и _';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Введите email';
    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(value.trim())) {
      return 'Неверный формат email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Введите пароль';
    if (_isLogin) return null;
    if (value.length < 8) return 'Минимум 8 символов';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Нужна заглавная буква';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'Нужна строчная буква';
    if (!RegExp(r'\d').hasMatch(value)) return 'Нужна хотя бы одна цифра';
    return null;
  }

  double _passwordStrength(String password) {
    if (password.isEmpty) return 0;
    double s = 0;
    if (password.length >= 8) s += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(password)) s += 0.25;
    if (RegExp(r'[a-z]').hasMatch(password)) s += 0.25;
    if (RegExp(r'\d').hasMatch(password)) s += 0.15;
    if (RegExp(r'[!@#\$%\^&\*(),.?":{}|<>]').hasMatch(password)) s += 0.10;
    return s.clamp(0.0, 1.0);
  }

  Color _strengthColor(double strength) {
    if (strength < 0.3) return AppColors.error;
    if (strength < 0.6) return AppColors.warning;
    if (strength < 0.9) return AppColors.primary;
    return AppColors.success;
  }

  String _strengthLabel(double strength) {
    if (strength < 0.3) return 'Слабый';
    if (strength < 0.6) return 'Средний';
    if (strength < 0.9) return 'Хороший';
    return 'Отличный';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    if (_isLogin) {
      await ref
          .read(authProvider.notifier)
          .login(_usernameController.text.trim(), _passwordController.text);
    } else {
      await ref.read(authProvider.notifier).register(
            _usernameController.text.trim(),
            _emailController.text.trim(),
            _passwordController.text,
          );
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final passwordStrength = _passwordStrength(_passwordController.text);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: context.isDark
                ? [AppColors.darkBg, const Color(0xFF1A1030)]
                : [AppColors.lightBg, const Color(0xFFE8E0FF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ─── Logo ───
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: Colors.white, size: 42),
                  ).animate().fadeIn(duration: 600.ms).scale(
                      begin: const Offset(0.5, 0.5), curve: Curves.easeOutBack),
                  const SizedBox(height: 24),
                  Text(
                    'Habit Tracker AI',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                        ),
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _isLogin ? 'Войди в аккаунт' : 'Создай аккаунт',
                      key: ValueKey(_isLogin),
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: context.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ─── Glassmorphism form card ───
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: context.glassColor,
                          borderRadius: BorderRadius.circular(24),
                          border:
                              Border.all(color: context.glassBorder, width: 1),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // Error
                              if (authState.error != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: context.errorColor
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: context.errorColor
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.error_outline,
                                          color: context.errorColor, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(authState.error!,
                                            style: TextStyle(
                                                color: context.errorColor,
                                                fontSize: 13)),
                                      ),
                                    ],
                                  ),
                                ).animate().shakeX(hz: 3, amount: 4),

                              // Username
                              TextFormField(
                                controller: _usernameController,
                                validator: _validateUsername,
                                autovalidateMode: _isLogin
                                    ? AutovalidateMode.disabled
                                    : AutovalidateMode.onUserInteraction,
                                inputFormatters: [
                                  FilteringTextInputFormatter.deny(
                                      RegExp(r'\s')),
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Имя пользователя',
                                  prefixIcon: const Icon(Icons.person_outline),
                                  helperText: _isLogin
                                      ? null
                                      : 'Буквы, цифры и _ (3–30 символов)',
                                  helperMaxLines: 1,
                                ),
                              ),

                              // Email (registration only)
                              AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                child: _isLogin
                                    ? const SizedBox.shrink()
                                    : Padding(
                                        padding: const EdgeInsets.only(top: 16),
                                        child: TextFormField(
                                          controller: _emailController,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          validator: _validateEmail,
                                          autovalidateMode: AutovalidateMode
                                              .onUserInteraction,
                                          decoration: const InputDecoration(
                                            labelText: 'Email',
                                            prefixIcon:
                                                Icon(Icons.email_outlined),
                                            hintText: 'example@mail.com',
                                          ),
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 16),

                              // Password
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                validator: _validatePassword,
                                autovalidateMode: _isLogin
                                    ? AutovalidateMode.disabled
                                    : AutovalidateMode.onUserInteraction,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: 'Пароль',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility),
                                    onPressed: () => setState(() =>
                                        _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                onFieldSubmitted: (_) => _submit(),
                              ),

                              // Password strength
                              AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                child: (!_isLogin &&
                                        _passwordController.text.isNotEmpty)
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: LinearProgressIndicator(
                                                  value: passwordStrength,
                                                  backgroundColor:
                                                      context.dividerColor,
                                                  color: _strengthColor(
                                                      passwordStrength),
                                                  minHeight: 4,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              _strengthLabel(passwordStrength),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: _strengthColor(
                                                    passwordStrength),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              const SizedBox(height: 24),

                              // Submit
                              GradientButton(
                                onPressed: _loading ? null : _submit,
                                gradient: AppColors.primaryGradient,
                                child: _loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white))
                                    : Text(
                                        _isLogin
                                            ? 'Войти'
                                            : 'Зарегистрироваться',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                            color: Colors.white)),
                              ),
                              const SizedBox(height: 12),

                              // Google Sign-In
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: OutlinedButton.icon(
                                  onPressed: _loading
                                      ? null
                                      : () async {
                                          setState(() => _loading = true);
                                          await ref
                                              .read(authProvider.notifier)
                                              .loginWithGoogle();
                                          setState(() => _loading = false);
                                        },
                                  icon: const Text('G',
                                      style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red)),
                                  label: const Text('Войти через Google'),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    side:
                                        BorderSide(color: context.dividerColor),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
                  const SizedBox(height: 20),

                  // Toggle
                  TextButton(
                    onPressed: () => setState(() {
                      _isLogin = !_isLogin;
                      _formKey.currentState?.reset();
                    }),
                    child: Text(
                      _isLogin
                          ? 'Нет аккаунта? Зарегистрироваться'
                          : 'Уже есть аккаунт? Войти',
                      style: TextStyle(
                        color: context.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
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
