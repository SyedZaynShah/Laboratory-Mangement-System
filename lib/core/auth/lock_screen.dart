import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/motions.dart';
import 'app_lock_controller.dart';
import 'auth_controller.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    Future(() {
      if (mounted) setState(() => _show = true);
    });
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final ok = await ref
        .read(authControllerProvider)
        .verifyCurrentUserPassword(password: _password.text);
    if (mounted) setState(() => _busy = false);
    if (!mounted) return;

    if (ok) {
      await ref.read(appLockProvider.notifier).unlock();
      _password.clear();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Incorrect password')));
    }
  }

  Future<void> _logout() async {
    await ref.read(authControllerProvider).signOut();
    await ref.read(appLockProvider.notifier).unlock();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF0B1220),
                    const Color(0xFF0E1A2F),
                    const Color(0xFF0B1220),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                color: const Color(0xFF0B1220).withOpacity(0.35),
              ),
            ),
          ),
          Center(
            child: AnimatedOpacity(
              duration: Motions.slow,
              curve: Motions.ease,
              opacity: _show ? 1.0 : 0.0,
              child: AnimatedScale(
                duration: Motions.slow,
                curve: Motions.ease,
                scale: _show ? 1.0 : 0.96,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF000000).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.14)),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondary.withOpacity(0.14),
                          blurRadius: 26,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                height: 44,
                                width: 44,
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary.withOpacity(0.22),
                                  ),
                                ),
                                child: Icon(
                                  Icons.lock,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Laboratory Management System',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white.withOpacity(
                                              0.8,
                                            ),
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Locked',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: Colors.white.withOpacity(
                                              0.6,
                                            ),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _password,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Enter password'
                                : null,
                            onFieldSubmitted: (_) => _unlock(),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _busy ? null : _unlock,
                            child: Text(_busy ? 'Unlocking…' : 'Unlock'),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _busy ? null : _logout,
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
