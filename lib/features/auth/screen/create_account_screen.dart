import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/widgets/gradient_text.dart';
import '../../../core/widgets/staggered_reveal.dart';

class CreateAccountScreen extends ConsumerStatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  ConsumerState<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
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
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final ok = await ref
        .read(authControllerProvider)
        .createUser(
          name: _name.text,
          email: _email.text,
          password: _password.text,
        );
    if (mounted) setState(() => _busy = false);
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created. Please sign in.')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not create account (email may already exist).'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedOpacity(
        opacity: _navOut ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 96),
        curve: Curves.easeInOutCubic,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(48, 40, 48, 40),
            child: Row(
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
                                      alignment: PlaceholderAlignment.baseline,
                                      baseline: TextBaseline.alphabetic,
                                      child: GradientText(
                                        'Precision',
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.displaySmall?.copyWith(
                                              fontWeight: FontWeight.w800,
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
                                'Create Account',
                                style: Theme.of(context).textTheme.headlineLarge
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
                                'Set up your laboratory access in minutes.',
                                style: Theme.of(context).textTheme.titleMedium
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
                                controller: _name,
                                decoration: _decoration(
                                  'Name',
                                  Icons.person_outline,
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Enter name'
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 12),
                            StaggeredReveal(
                              delay: const Duration(milliseconds: 90),
                              child: TextFormField(
                                controller: _email,
                                decoration: _decoration('Email', Icons.mail),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Enter email/username'
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 12),
                            StaggeredReveal(
                              delay: const Duration(milliseconds: 120),
                              child: TextFormField(
                                controller: _password,
                                obscureText: true,
                                decoration: _decoration('Password', Icons.lock),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Enter password'
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 12),
                            StaggeredReveal(
                              delay: const Duration(milliseconds: 150),
                              child: TextFormField(
                                controller: _confirm,
                                obscureText: true,
                                decoration: _decoration(
                                  'Confirm Password',
                                  Icons.lock,
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Confirm password';
                                  }
                                  if (v != _password.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (_) => _create(),
                              ),
                            ),
                            const SizedBox(height: 18),
                            StaggeredReveal(
                              delay: const Duration(milliseconds: 180),
                              child: _primaryGradientButton(
                                label: _busy ? 'Creating…' : 'Create Account',
                                onPressed: _busy ? null : _create,
                              ),
                            ),
                            const SizedBox(height: 10),
                            StaggeredReveal(
                              delay: const Duration(milliseconds: 210),
                              child: TextButton(
                                onPressed: _busy
                                    ? null
                                    : () async {
                                        setState(() => _navOut = true);
                                        await Future.delayed(
                                          const Duration(milliseconds: 96),
                                        );
                                        if (!context.mounted) return;
                                        Navigator.pop(context);
                                      },
                                style: ButtonStyle(
                                  foregroundColor: WidgetStatePropertyAll(
                                    Colors.white.withOpacity(0.85),
                                  ),
                                  textStyle: WidgetStateProperty.resolveWith((
                                    states,
                                  ) {
                                    final underline = states.contains(
                                      WidgetState.hovered,
                                    );
                                    return TextStyle(
                                      fontWeight: FontWeight.w600,
                                      decoration: underline
                                          ? TextDecoration.underline
                                          : TextDecoration.none,
                                      decorationColor: Colors.white.withOpacity(
                                        0.85,
                                      ),
                                    );
                                  }),
                                ),
                                child: const Text('Back to Log In'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
