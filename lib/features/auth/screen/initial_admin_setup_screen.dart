import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_controller.dart';

class InitialAdminSetupScreen extends ConsumerStatefulWidget {
  const InitialAdminSetupScreen({super.key});

  @override
  ConsumerState<InitialAdminSetupScreen> createState() =>
      _InitialAdminSetupScreenState();
}

class _InitialAdminSetupScreenState
    extends ConsumerState<InitialAdminSetupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Initial Admin Setup',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Enter name' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Enter email' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Enter password' : null,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              if (!_formKey.currentState!.validate()) return;
                              final messenger = ScaffoldMessenger.of(context);
                              setState(() => _busy = true);
                              final ok = await ref
                                  .read(authControllerProvider)
                                  .createInitialAdmin(
                                    name: _name.text,
                                    email: _email.text,
                                    password: _password.text,
                                  );
                              setState(() => _busy = false);
                              if (!ok) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Admin already exists or error creating admin',
                                    ),
                                  ),
                                );
                              }
                            },
                      child: Text(_busy ? 'Creating...' : 'Create Admin'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
