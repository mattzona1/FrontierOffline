# Frontier Offline

A single-player, offline, mobile-first RPG prototype inspired by classic squad-building RPG combat.

This repository contains the Godot 4 Android prototype and an automated GitHub Actions workflow that exports a versioned APK for testing.

## Current prototype

- Offline local save data
- Six-unit starter squad
- Summoning with earned currency
- Prototype quest battle
- Brave Burst gauge foundation
- Android portrait layout and touch input
- Automated APK builds through GitHub Actions

## Android builds

Every push to `main` triggers an Android APK build. The resulting APK is stored under the repository's **Actions** tab as a downloadable artifact. Manual workflow runs can additionally publish a prerelease with the APK attached.

The Android package identity and development signing certificate stay fixed so newer prototype APKs can install as updates over earlier builds while preserving compatible local save data.

This project currently uses original placeholder data and artwork hooks. Copyrighted third-party game assets are not bundled in the repository.
