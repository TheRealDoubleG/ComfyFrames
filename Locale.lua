ComfyFrames = ComfyFrames or {}
local A=ComfyFrames
local de=GetLocale and GetLocale()=="deDE"

local EN={
 GENERAL="General", UNITS="Units", GROUPS="Party / Raid", STYLE="Style", PROFILES="Profiles", INFO="Info",
 ENABLE="Enable ComfyFrames", TEST="Test mode", UNLOCK="Unlock frames", LOCK="Lock frames", RESET_POSITIONS="Reset positions",
 PLAYER="Player", TARGET="Target", TARGETTARGET="Target of Target", FOCUS="Focus", PET="Pet", PARTY="Party", RAID="Raid",
 WIDTH="Width", HEIGHT="Height", FONT_SIZE="Font size", SHOW_POWER="Show power bar", SHOW_ROLE="Show role",
 RANGE_FADE="Fade out-of-range units", INCLUDE_PLAYER="Include player in party frames", RAID_COLUMNS="Raid columns",
 STYLE_CLASS_COLORS="Use class colors", HEALTH_TEXT="Show health text", POWER_TEXT="Show power text",
 INCOMING_HEAL="Show incoming heals", ABSORB="Show absorbs",
 PRESET_MINIMAL="Minimal", PRESET_STANDARD="Standard", PRESET_HEALER="Healer", PRESET_RAID="Raid",
 PROFILES_HINT="Every character has its own profile. Account and custom profiles are also available.",
 CHARACTER_PROFILE="Character", ACCOUNT_PROFILE="Account", CUSTOM_PROFILE="Custom profile",
 CREATE="Create", DELETE="Delete custom", RESET_PROFILE="Reset profile",
 DEAD="Dead", OFFLINE="Offline", TEST_NAME="Test Unit", INFO_NOTICE="ComfyFrames changes the UI only and does not automate gameplay.",
 INFO_COMMANDS="/cf, /cf test, /cf unlock, /cf lock, /cf reset",
 LOADED="Loaded.", LOCKED_COMBAT="Frames cannot be moved or securely reconfigured during combat.",
}

local DE={
 GENERAL="Allgemein", UNITS="Einheiten", GROUPS="Gruppe / Raid", STYLE="Stil", PROFILES="Profile", INFO="Info",
 ENABLE="ComfyFrames aktivieren", TEST="Testmodus", UNLOCK="Frames entsperren", LOCK="Frames sperren", RESET_POSITIONS="Positionen zurücksetzen",
 PLAYER="Spieler", TARGET="Ziel", TARGETTARGET="Ziel des Ziels", FOCUS="Fokus", PET="Begleiter", PARTY="Gruppe", RAID="Raid",
 WIDTH="Breite", HEIGHT="Höhe", FONT_SIZE="Schriftgröße", SHOW_POWER="Ressourcenleiste anzeigen", SHOW_ROLE="Rolle anzeigen",
 RANGE_FADE="Einheiten außerhalb der Reichweite ausblenden", INCLUDE_PLAYER="Spieler in Gruppenframes anzeigen", RAID_COLUMNS="Raid-Spalten",
 STYLE_CLASS_COLORS="Klassenfarben verwenden", HEALTH_TEXT="Gesundheitstext anzeigen", POWER_TEXT="Ressourcentext anzeigen",
 INCOMING_HEAL="Eingehende Heilung anzeigen", ABSORB="Absorbs anzeigen",
 PRESET_MINIMAL="Minimal", PRESET_STANDARD="Standard", PRESET_HEALER="Heiler", PRESET_RAID="Raid",
 PROFILES_HINT="Jeder Charakter hat ein eigenes Profil. Account- und eigene Profile sind ebenfalls verfügbar.",
 CHARACTER_PROFILE="Charakter", ACCOUNT_PROFILE="Account", CUSTOM_PROFILE="Eigenes Profil",
 CREATE="Erstellen", DELETE="Eigenes löschen", RESET_PROFILE="Profil zurücksetzen",
 DEAD="Tot", OFFLINE="Offline", TEST_NAME="Testeinheit", INFO_NOTICE="ComfyFrames verändert nur die Benutzeroberfläche und automatisiert keine Spielaktionen.",
 INFO_COMMANDS="/cf, /cf test, /cf unlock, /cf lock, /cf reset",
 LOADED="Geladen.", LOCKED_COMBAT="Frames können im Kampf nicht verschoben oder sicher neu konfiguriert werden.",
}

local L=de and DE or EN
function A:T(k) return L[k] or EN[k] or k end
