# ComfyFrames

**Version 0.2 – Beta**

Modular unit frames for **World of Warcraft: Forever**.

## 0.2 Beta

- Secure unit frames are now anchored to independent mover handles instead of being children of hidden movers.
- Protected layout changes are queued until combat ends.
- Party/raid range checks use a throttled 0.5-second ticker when available.

## 0.1 Beta

- Player, target, target-of-target, focus and pet frames.
- Party frames for player + party1-4.
- Raid frames for raid1-40.
- Secure unit buttons for normal targeting.
- Health and power bars.
- Incoming-heal and absorb indicators that pass Forever values to widgets instead of assuming every value is readable.
- Dead/offline and role status.
- Optional class colors.
- Range fading for party and raid.
- Test mode.
- Standalone movers plus ComfyHub Suite Edit Mode integration.
- Minimal, Standard, Healer and Raid presets.
- Character, account and custom profiles.
- Public unit-button listener API for ComfyHeal integration.

The first beta intentionally keeps aura/dispel logic outside the frame core so that ComfyHeal can build that layer separately.

## Commands

- `/cf`
- `/cf test`
- `/cf unlock`
- `/cf lock`
- `/cf reset`

## Target

WoW Forever 1.60.1 / Interface 16001.

ComfyFrames changes the UI only and does not automate gameplay.
