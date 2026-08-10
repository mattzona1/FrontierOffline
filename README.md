# Frontier Offline

A single-player, offline, mobile-first RPG prototype inspired by classic squad-building gacha RPG combat.

This repository contains the Godot 4 Android prototype and an automated GitHub Actions workflow that exports a versioned APK for testing.

## Current prototype

- Offline local save data
- Six-unit squads
- Summoning with earned currency
- Quest progression
- Elemental strengths and weaknesses
- Multi-hit attacks and Sparks
- Brave Burst gauges and attacks
- Android portrait layout and touch input
- Automated APK builds through GitHub Actions

## Android builds

Pushes to `main` build an Android APK as a GitHub Actions artifact. Manual workflow runs also create a prerelease with the APK attached.

This project currently uses original placeholder data and artwork hooks. Copyrighted third-party game assets are not bundled in the repository.
