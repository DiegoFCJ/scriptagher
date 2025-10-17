#!/bin/bash
set -e

# 🧱 Evita l'esecuzione come root (non serve qui)
if [ "$EUID" -eq 0 ]; then
  echo "❌ Non eseguire questo script come root (con sudo)."
  exit 1
fi

# ────────────────────────────────────────────────────────────────────────────────
# Rilevamento OS / Utilità
# ────────────────────────────────────────────────────────────────────────────────
get_os() {
  case "$(uname -s)" in
    Darwin) echo "macOS" ;;
    Linux) echo "Linux" ;;
    CYGWIN*|MINGW32*|MSYS*|MINGW*) echo "Windows" ;;
    *) echo "Unknown" ;;
  esac
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

has_device() {
  # $1 = regex (case-insensitive) per "flutter devices"
  flutter devices 2>/dev/null | grep -iqE "$1"
}

# ────────────────────────────────────────────────────────────────────────────────
# Installazione Flutter/Dart per piattaforma
# ────────────────────────────────────────────────────────────────────────────────
install_flutter() {
  local OS; OS="$(get_os)"
  echo "🚀 Installazione automatica di Flutter/Dart su $OS..."

  if [ "$OS" = "macOS" ]; then
    if ! command_exists brew; then
      echo "🍺 Homebrew non trovato, lo installo..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile" 2>/dev/null || true
      eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
    fi
    brew install flutter dart
    flutter precache

  elif [ "$OS" = "Linux" ]; then
    if command_exists apt; then
      sudo apt update
      sudo apt install -y curl git unzip xz-utils zip libglu1-mesa
    fi
    if [ ! -d "$HOME/flutter" ]; then
      git clone https://github.com/flutter/flutter.git -b stable "$HOME/flutter"
    fi
    export PATH="$PATH:$HOME/flutter/bin"
    flutter precache

  elif [ "$OS" = "Windows" ]; then
    echo "⚙️  Setup Flutter per Windows (Git Bash/WSL)."
    if ! command_exists git; then
      echo "❌ Git non trovato. Installa Git for Windows: https://git-scm.com/download/win"
      exit 1
    fi
    local FLUTTER_DIR="$HOME/flutter"
    if [ ! -d "$FLUTTER_DIR" ]; then
      echo "⬇️  Clono Flutter in $FLUTTER_DIR ..."
      git clone https://github.com/flutter/flutter.git -b stable "$FLUTTER_DIR"
    else
      echo "✅ Flutter già presente in $FLUTTER_DIR"
    fi
    export PATH="$PATH:$FLUTTER_DIR/bin"
    flutter precache
  else
    echo "❌ Sistema operativo non supportato per installazione automatica."
    exit 1
  fi
}

check_flutter() {
  if command_exists flutter && command_exists dart; then
    echo "✅ Flutter e Dart presenti."
  else
    echo "⚠️  Flutter/Dart non trovati. Procedo con l'installazione..."
    install_flutter
  fi
  # Validazione finale
  if ! command_exists flutter; then
    echo "❌ Flutter non disponibile dopo l'installazione (PATH?)."
    echo "   PATH attuale: $PATH"
    exit 1
  fi
  flutter --version || true
}

# ────────────────────────────────────────────────────────────────────────────────
# Abilitazione piattaforme + creazione scaffolding
# ────────────────────────────────────────────────────────────────────────────────
ensure_platforms() {
  # $1 = lista piattaforme per flutter create (es: "windows,web")
  local targets="$1"
  local OS; OS="$(get_os)"

  echo "🔧 Abilito piattaforme per $OS (targets: $targets)"
  case "$OS" in
    Windows)
      flutter config --enable-windows-desktop --enable-web || true
      ;;
    macOS)
      flutter config --enable-macos-desktop --enable-web || true
      ;;
    Linux)
      flutter config --enable-linux-desktop --enable-web || true
      ;;
  esac

  echo "📦 Genero/aggiorno file di piattaforma mancanti..."
  flutter create . --platforms="$targets"
}

# ────────────────────────────────────────────────────────────────────────────────
# Configurazione progetto
# ────────────────────────────────────────────────────────────────────────────────
configure_project() {
  echo "🔍 Controllo configurazione progetto..."
  # Se non esiste un progetto Flutter, crealo
  if [ ! -f "pubspec.yaml" ]; then
    echo "🆕 Progetto non inizializzato. Eseguo 'flutter create .'"
    flutter create .
  fi

  local OS; OS="$(get_os)"
  local need_platforms=0
  case "$OS" in
    Windows)
      [ ! -d "windows" ] && need_platforms=1
      [ ! -d "web" ] && need_platforms=1
      [ $need_platforms -eq 1 ] && ensure_platforms "windows,web"
      ;;
    macOS)
      [ ! -d "macos" ] && need_platforms=1
      [ ! -d "web" ] && need_platforms=1
      [ $need_platforms -eq 1 ] && ensure_platforms "macos,web"
      ;;
    Linux)
      [ ! -d "linux" ] && need_platforms=1
      [ ! -d "web" ] && need_platforms=1
      [ $need_platforms -eq 1 ] && ensure_platforms "linux,web"
      ;;
  esac

  echo "📥 flutter pub get"
  flutter pub get
  echo "✅ Configurazione OK."
}

# ────────────────────────────────────────────────────────────────────────────────
# Run per piattaforma
# ────────────────────────────────────────────────────────────────────────────────
run_on_unix() {
  local OS; OS="$(get_os)"
  echo "🏁 Avvio su $OS ..."
  configure_project

  # Preferisci desktop se device presente, altrimenti web
  if [ "$OS" = "macOS" ]; then
    if has_device "macos.*macOS"; then
      flutter run -d macos
    else
      echo "ℹ️  macOS desktop non disponibile, avvio su web (chrome)."
      flutter run -d chrome
    fi
  else # Linux
    # Su alcune distro serve GDK_BACKEND=x11 per Flutter desktop
    if has_device "linux.*linux-x64"; then
      echo "💻 Forzo backend GDK su X11 (se necessario)..."
      GDK_BACKEND=x11 flutter run -d linux
    else
      echo "ℹ️  Linux desktop non disponibile, avvio su web (chrome)."
      flutter run -d chrome
    fi
  fi
}

run_on_windows() {
  echo "🏁 Avvio su Windows ..."
  configure_project

  # Preferisci desktop Windows se presente, altrimenti web (Edge/Chrome)
  if has_device "Windows \(desktop\).*windows-x64"; then
    flutter run -d windows
  elif has_device "edge.*web-javascript"; then
    echo "ℹ️  Target Windows non disponibile, avvio su web (Edge)."
    flutter run -d edge
  elif has_device "chrome.*web-javascript"; then
    echo "ℹ️  Target Windows non disponibile, avvio su web (Chrome)."
    flutter run -d chrome
  else
    echo "❌ Nessun device supportato trovato."
    echo "   Suggerimenti:"
    echo "   • Per Desktop Windows: installa Visual Studio 2022 con 'Desktop development with C++' (MSVC, Windows SDK, CMake, Ninja)."
    echo "   • Per Web: assicurati di avere Edge o Chrome installati."
    exit 1
  fi
}

# ────────────────────────────────────────────────────────────────────────────────
# Main
# ────────────────────────────────────────────────────────────────────────────────
main() {
  local OS; OS="$(get_os)"
  echo "🧭 Sistema operativo rilevato: $OS"

  check_flutter

  echo "🩺 flutter doctor (diagnostica)..."
  flutter doctor -v || true
  echo "────────────────────────────────────────────────────────"

  case "$OS" in
    macOS|Linux) run_on_unix ;;
    Windows)     run_on_windows ;;
    *) echo "❌ Sistema operativo non supportato"; exit 1 ;;
  esac
}

main