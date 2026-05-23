import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/biometric_service.dart';

class BiometricGateScreen extends StatefulWidget {
  const BiometricGateScreen({super.key});

  @override
  State<BiometricGateScreen> createState() => _BiometricGateScreenState();
}

class _BiometricGateScreenState extends State<BiometricGateScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAuth());
  }

  Future<void> _startAuth() async {
    final biometric = context.read<BiometricService>();
    final enrolled = await biometric.hasEnrolledBiometrics();

    if (!enrolled && mounted) {
      await _showEnrollDialog();
      return;
    }

    await biometric.authenticate(
      reason:
          'Utilisez votre empreinte digitale pour accéder à l\'application',
    );
  }

  Future<void> _showEnrollDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Empreinte requise'),
        content: const Text(
          'Aucune empreinte digitale n\'est enregistrée sur cet appareil. '
          'Configurez-en une dans les paramètres système pour sécuriser votre smartphone.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await context.read<BiometricService>().openBiometricSettings();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Ouvrir les paramètres'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startAuth();
            },
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final biometric = context.watch<BiometricService>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.fingerprint,
                size: 96,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Authentification biométrique',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'L\'accès à l\'application nécessite la vérification de votre identité par empreinte digitale.',
                textAlign: TextAlign.center,
              ),
              if (biometric.lastError != null) ...[
                const SizedBox(height: 16),
                Text(
                  biometric.lastError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed:
                    biometric.isAuthenticating ? null : () => _startAuth(),
                icon: biometric.isAuthenticating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fingerprint),
                label: Text(
                  biometric.isAuthenticating
                      ? 'Vérification...'
                      : 'Scanner l\'empreinte',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _showEnrollDialog(),
                child: const Text('Configurer une empreinte'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
