# Reyaanshs-Things

**One app. Many features. Endless possibilities.**

Reyaanshs-Things is an open-source, all-in-one, cross-platform application built with Flutter. It brings together multiple useful features in a single application, with the goal of making everyday tasks and activities easier from one place.

Designed to grow over time, Reyaanshs-Things aims to provide a unified experience across desktop, mobile, and web platforms.

## ✨ Features

Reyaanshs-Things is built around the idea of bringing multiple features together instead of requiring separate applications for everything.

More features are being developed and will be introduced as the project grows.

## 💻 Supported Platforms

- Windows
- Linux
- Android
- Web

## 📦 Downloads

**Releases are now live!** 🎉

You can download the latest Android APK from the [Releases page](https://github.com/Reyaanshs-Stuff/Reyaanshs-Things/releases).

1. Open the [Releases page](https://github.com/Reyaanshs-Stuff/Reyaanshs-Things/releases).
2. Find the latest release.
3. Download the APK from the release assets.
4. Follow the installation instructions provided in the release description.

Make sure to download the latest version for the newest features, improvements, and fixes.

## 🛠️ Built With

- [Flutter](https://flutter.dev/) — Cross-platform UI framework
- [Dart](https://dart.dev/) — Programming language

## 🚀 Getting Started

Want to try the project locally? Follow these steps.

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- Git

### Clone the repository

```bash
git clone https://github.com/Reyaanshs-Stuff/Reyaanshs-Things.git
cd Reyaanshs-Things
```

### Install dependencies

```bash
flutter pub get
```

### Run the application

```bash
flutter run
```

### Supabase setup

Authentication and messaging require a Supabase project.

1. Create a project at [supabase.com](https://supabase.com/).
2. In the project's SQL Editor, run [`supabase/schema.sql`](supabase/schema.sql) once. It creates the profile, global chat, private-channel, invitation, message, reaction, and storage policies.
3. Enable Email authentication in **Authentication → Providers**. Email confirmation is recommended; users will need to confirm new accounts before signing in.
4. Copy the project URL and the public anon/publishable key from **Project Settings → API**.
5. Run the app with those values:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY
```

Use the public anon/publishable key only. Never put a service-role or secret key in a Flutter app or commit project credentials. If the project has existing tables or policies, review the SQL before applying it rather than running it unchanged.

The login screen signs in existing users and attempts account creation when an email is not registered. New accounts need a username; profile photos can be selected from a file picker. With email confirmation enabled, sign in after confirming and upload or change the photo from **My Profile**.

Messages are shared in the public `global` room. User-created channels are private and invite-only; the creator can invite registered users by username. Invitations can be accepted or declined in Messages. Image and video attachments preview in chat; other files have a download action. Attachments are limited to 50 MB each.

## 📁 Project Structure

```text
Reyaanshs-Things/
├── android/
├── linux/
├── web/
├── windows/
├── lib/
├── screenshots/
│   ├── login.png
│   └── home.png
├── test/
└── pubspec.yaml
```

## 📚 Documentation

Useful resources for working with the technologies behind this project:

- [Flutter Documentation](https://docs.flutter.dev/)
- [Dart Documentation](https://dart.dev/guides)

## 🤝 Contributing

Contributions, suggestions, and ideas are welcome!

If you'd like to improve the project or contribute a feature, please check the [CONTRIBUTING.md](CONTRIBUTING.md) file for contribution guidelines before submitting a pull request.

Feel free to fork the repository and contribute!

## 📄 License

See [LICENSE](LICENSE) for details.

---

<p align="center">
  Made with ❤️ and Flutter
</p>
