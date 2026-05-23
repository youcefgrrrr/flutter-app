import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService extends ChangeNotifier {
  final LocalAuthentication _auth = LocalAuthentication();

  bool sessionUnlocked = false;
  bool isAuthenticating = false;
  String? lastError;

  Future<bool> get canCheckBiometrics async {
    try {
      return await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> get availableBiometrics async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  Future<bool> isDeviceSupported() => _auth.isDeviceSupported();

  Future<bool> hasEnrolledBiometrics() async {
    final supported = await isDeviceSupported();
    if (!supported) return false;
    final available = await availableBiometrics;
    return available.isNotEmpty;
  }

  Future<void> openBiometricSettings() async {
    await AppSettings.openAppSettings(type: AppSettingsType.security);
  }

  Future<bool> authenticate({String reason = 'Vérifiez votre identité'}) async {
    isAuthenticating = true;
    lastError = null;
    notifyListeners();

    try {
      final enrolled = await hasEnrolledBiometrics();
      if (!enrolled) {
        lastError =
            'Aucune empreinte enregistrée. Configurez-en une dans les paramètres.';
        return false;
      }

      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (ok) {
        await SystemSound.play(SystemSoundType.alert);
        sessionUnlocked = true;
      }
      return ok;
    } on LocalAuthException catch (e) {
      lastError = e.description ?? 'Échec de l\'authentification biométrique.';
      return false;
    } on PlatformException catch (e) {
      lastError = e.message ?? 'Échec de l\'authentification biométrique.';
      return false;
    } finally {
      isAuthenticating = false;
      notifyListeners();
    }
  }

  void lockSession() {
    sessionUnlocked = false;
    notifyListeners();
  }
}
