# Secure Audio Player

Application mobile Flutter (sécurité + audio + Firebase) conforme au cahier des charges :

- Authentification **biométrique** (empreinte) au lancement, avec redirection vers les paramètres si aucune empreinte n'est configurée
- Son système de succès après validation biométrique
- Authentification **Firebase** (inscription, connexion, mot de passe oublié)
- Champs obligatoires à l'inscription : prénom, nom, date de naissance (âge ≥ 13 ans)
- Page **statistiques** : bienvenue (nom en gras), temps d'écoute, histogramme mensuel, top morceaux, objectif mensuel (défaut 20 h, stocké localement)
- Page **lecteur** : playlist dynamique par sourates / récitateurs via l'API [quran.yousefheiba.com](https://quran.yousefheiba.com) (`quranapi.pages.dev`)
- Lecture en **arrière-plan**, pause, répétition du morceau
- **Favoris** synchronisés Firestore ; suppression protégée par empreinte

## Prérequis

- Flutter SDK 3.2+
- Compte [Firebase](https://console.firebase.google.com/)
- Appareil Android physique ou émulateur avec empreinte configurée (pour tester la biométrie)

## Configuration Firebase

1. Créez un projet Firebase et activez **Authentication** (e-mail / mot de passe) et **Cloud Firestore**.
2. Installez la CLI FlutterFire :

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

3. Remplacez le contenu de `lib/firebase_options.dart` par la sortie générée.
4. Téléchargez `google-services.json` dans `android/app/` (fourni par Firebase).

### Règles Firestore (exemple développement)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Lancement

```bash
cd C:\Users\youyo\Projects\secure_audio_player
flutter pub get
flutter run
```

> Sur Windows, si `flutter pub get` échoue à cause des symlinks, activez le **Mode développeur** : `ms-settings:developers`

## Structure

| Dossier | Rôle |
|---------|------|
| `lib/screens/biometric_gate_screen.dart` | Porte biométrique au démarrage |
| `lib/screens/auth/` | Connexion, inscription, reset |
| `lib/screens/stats_screen.dart` | Statistiques et objectif mensuel |
| `lib/screens/player_screen.dart` | Lecteur, favoris, API Quran |
| `lib/services/` | Auth, biométrie, stats, audio, favoris |

## API audio

Les catégories correspondent aux **114 sourates** ; les morceaux aux **récitations** disponibles pour chaque sourate :

- Liste : `https://quranapi.pages.dev/api/surah.json`
- Audio : `https://quranapi.pages.dev/api/audio/{numéro}.json`
