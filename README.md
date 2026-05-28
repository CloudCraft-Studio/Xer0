# Xer0

**Xer0** is a cyberpunk-themed chat client for [Ollama](https://ollama.com), built by [CloudCraft Studio](https://github.com/CloudCraft-Studio). It is a privacy-first, multi-platform app to chat with self-hosted LLMs, with per-conversation control over system prompts, model selection, and generation options.

> Xer0 is a fork of [Reins](https://github.com/ibrahimcetin/reins) by İbrahim Çetin. See [Credits & License](#credits--license).

## What this fork changes

Compared to upstream Reins, Xer0:

- **Rebrands** the app to Xer0 with a cyberpunk visual identity (neon palette, Orbitron / Chakra Petch fonts, glitch title, custom robot icon with "X" eyes and matching splash screen).
- **Adds optional API token support** for connecting to Ollama Cloud / authenticated endpoints.
- Uses the iOS bundle identifier `studio.cloudcraft.xer0`.

## Features

- **Per-conversation configuration**: system prompt, model, temperature, seed, context size, max tokens.
- **Model selection & switching** mid-chat.
- **Message editing & regeneration.**
- **Save custom models** from system/chat prompts.
- **Image integration** in chats.
- **Multiple chat management** and **real-time message streaming**.
- **Optional API token** for Ollama Cloud / authenticated servers.

## Status

This is a private fork for internal CloudCraft Studio use. It is **not** published on any app store.

**Tested platforms:** iPhone 17 Pro (iOS 26.5) only, so far. Other iOS devices, macOS, Linux, Android, and Windows inherit upstream support but have not been verified in this fork.

## Building & running

Requires the Flutter SDK (3.44+).

```bash
flutter pub get
flutter run            # debug on a connected device
flutter run --release  # release build
```

For iOS device installs, open `ios/Runner.xcworkspace` in Xcode and select your own signing **Team** under *Signing & Capabilities* before building.

## Credits & License

Xer0 is based on **[Reins](https://github.com/ibrahimcetin/reins)** by **İbrahim Çetin**, licensed under **GPL-3.0**. All original credit goes to the upstream author and contributors.

In accordance with GPL-3.0, Xer0 is also distributed under the **[GPL-3.0](LICENSE)** license, and its source remains open. If you redistribute Xer0, you must keep this attribution and make the corresponding source available under the same license.
