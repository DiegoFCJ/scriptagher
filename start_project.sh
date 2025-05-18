#!/bin/bash

# Blocca l'esecuzione come root
if [ "$EUID" -eq 0 ]; then
  echo "❌ Non eseguire questo script come root (con sudo)."
  exit 1
fi

# Funzione per verificare il sistema operativo
function get_os() {
    case "$(uname -s)" in
        Darwin) echo "macOS" ;;
        Linux) echo "Linux" ;;
        CYGWIN*|MINGW32*|MSYS*|MINGW*) echo "Windows" ;;
        *) echo "Unknown OS" ;;
    esac
}

# Funzione per verificare e configurare il progetto
function configure_project() {
    echo "Controllo della configurazione del progetto..."
    flutter devices | grep -q "No devices found"
    if [ $? -eq 0 ]; then
        echo "Nessun dispositivo rilevato."
        echo "Esecuzione di 'flutter create .' per configurare il progetto..."
        flutter create .
    else
        echo "Il progetto sembra essere configurato correttamente."
    fi
}

# Funzione per eseguire il comando su macOS/Linux
function run_on_unix() {
    echo "Avvio del progetto su macOS/Linux..."
    configure_project
    echo "Forzatura backend GDK su X11 per compatibilità con Flutter Desktop..."
    GDK_BACKEND=x11 flutter run
}

# Funzione per eseguire il comando su Windows
function run_on_windows() {
    echo "Avvio del progetto su Windows..."
    configure_project
    flutter run
}

# Funzione principale
function main() {
    OS=$(get_os)
    echo "Sistema operativo rilevato: $OS"

    if [ "$OS" == "macOS" ] || [ "$OS" == "Linux" ]; then
        run_on_unix
    elif [ "$OS" == "Windows" ]; then
        run_on_windows
    else
        echo "Sistema operativo non supportato"
        exit 1
    fi
}

# Avvia lo script
main