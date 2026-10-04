# ComfyFrames Changelog

## 0.5 Beta – 04.10.2026
- Added separate controls for Blizzard Player, Target and Target-of-Target frames.
- Blizzard frame visibility changes are deferred until combat ends when required.
- Added Player/Target/Target-of-Target buff and debuff displays with configurable size, spacing, position, timers and stacks.
- Added player periodic damage/heal tick preview with time and learned tick value.
- Added configurable absorb display for Player, Target, Party and Raid, including optional absorb text.
- Reworked Party/Raid range fading for WoW Forever secret values and added separate out-of-range opacity controls.

## 0.4 Beta – 04.10.2026
- Added the first playtest enhancement layer for absorbs and safe range fading.

## 0.3 Beta – 28.09.2026
- Expanded the unit-frame foundation for the Comfy Suite playtest branch.

## 0.2 Beta – 28.09.2026
- Fixed secure frame parenting so hidden mover handles do not hide unit frames.
- Added a deferred post-combat layout queue for protected frame changes.
- Made party/raid layout and enable-state changes combat-safe.
- Prefer a 0.5-second ticker for range fading instead of a permanent per-frame update when available.
- Fixed Lua loop-callback safety in unit options.

## 0.1 Beta – 28.09.2026
- Initial modular unit-frame beta.
- Added player, target, target-of-target, focus and pet frames.
- Added party and 40-player raid frame foundations.
- Added health, power, incoming-heal and absorb elements.
- Added role/status text and range fading.
- Added secure unit buttons, movers, test mode and presets.
- Added ComfyHub Suite Edit Mode integration.
- Added unit-button listener API for ComfyHeal.
