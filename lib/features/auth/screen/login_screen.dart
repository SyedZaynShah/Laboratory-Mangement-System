import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/widgets/gradient_text.dart';
import '../../../core/widgets/staggered_reveal.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _navOut = false;

  InputDecoration _decoration(String label, IconData icon) {
    const radius = BorderRadius.all(Radius.circular(14));
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      prefixIcon: Icon(icon, size: 18, color: Colors.white70),
      enabledBorder: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: Colors.transparent),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: Color(0xFF2E6BFF), width: 1.25),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _primaryGradientButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    const radius = BorderRadius.all(Radius.circular(14));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          colors: [Color(0xFF173B8A), Color(0xFF2E6BFF)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E6BFF).withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: const RoundedRectangleBorder(borderRadius: radius),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(authControllerProvider);
    return Scaffold(
      body: AnimatedOpacity(
        opacity: _navOut ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 96),
        curve: Curves.easeInOutCubic,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(48, 40, 48, 40),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  children: [
                    Expanded(
                      flex: 55,
                      child: Align(
                        alignment: const Alignment(-1, -0.15),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StaggeredReveal(
                                delay: const Duration(milliseconds: 0),
                                child: DefaultTextStyle(
                                  style:
                                      Theme.of(
                                        context,
                                      ).textTheme.displaySmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        height: 1.12,
                                        color: Colors.white,
                                      ) ??
                                      const TextStyle(
                                        fontSize: 44,
                                        fontWeight: FontWeight.w800,
                                        height: 1.12,
                                        color: Colors.white,
                                      ),
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        WidgetSpan(
                                          alignment:
                                              PlaceholderAlignment.baseline,
                                          baseline: TextBaseline.alphabetic,
                                          child: GradientText(
                                            'Precision',
                                            style:
                                                Theme.of(context)
                                                    .textTheme
                                                    .displaySmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      height: 1.12,
                                                    ) ??
                                                const TextStyle(
                                                  fontSize: 44,
                                                  fontWeight: FontWeight.w800,
                                                  height: 1.12,
                                                ),
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF173B8A),
                                                Color(0xFF2E6BFF),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const TextSpan(
                                          text:
                                              ' in Every Test.\nConfidence in Every Result.',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              StaggeredReveal(
                                delay: const Duration(milliseconds: 40),
                                child: Text(
                                  'An offline-first laboratory management system for reliable diagnostics and seamless workflows.',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w500,
                                        height: 1.5,
                                        color: Colors.white.withOpacity(0.78),
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                    Expanded(
                      flex: 45,
                      child: Align(
                        alignment: const Alignment(0, -0.10),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                StaggeredReveal(
                                  delay: const Duration(milliseconds: 0),
                                  child: Text(
                                    'Log In',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.2,
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                StaggeredReveal(
                                  delay: const Duration(milliseconds: 30),
                                  child: Text(
                                    'Welcome back. Please enter your credentials.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white.withOpacity(0.76),
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 22),
                                StaggeredReveal(
                                  delay: const Duration(milliseconds: 60),
                                  child: TextFormField(
                                    controller: _email,
                                    decoration: _decoration(
                                      'Username',
                                      Icons.person,
                                    ),
                                    validator: (v) => (v == null || v.isEmpty)
                                        ? 'Enter username'
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                StaggeredReveal(
                                  delay: const Duration(milliseconds: 90),
                                  child: TextFormField(
                                    controller: _password,
                                    obscureText: true,
                                    decoration: _decoration(
                                      'Password',
                                      Icons.lock,
                                    ),
                                    validator: (v) => (v == null || v.isEmpty)
                                        ? 'Enter password'
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                StaggeredReveal(
                                  delay: const Duration(milliseconds: 120),
                                  child: _primaryGradientButton(
                                    label: 'Log In',
                                    onPressed: () async {
                                      if (!_formKey.currentState!.validate())
                                        return;
                                      final messenger = ScaffoldMessenger.of(
                                        context,
                                      );
                                      final ok = await auth.signIn(
                                        _email.text,
                                        _password.text,
                                      );
                                      if (!ok) {
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Invalid credentials',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
