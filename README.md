# Progetto Flutter

## Descrizione
Questo progetto è una semplice applicazione mobile/desktop/web sviluppata con Flutter. Flutter è un framework open-source che permette di creare app per dispositivi mobili, desktop e web da una singola base di codice. Questo README include informazioni su come eseguire, configurare, testare e distribuire l'app su diverse piattaforme (Android, iOS, Linux, Windows e altre).

## Struttura del Progetto
La struttura di base di un'app Flutter è la seguente:

```sh
/ScriptAgher
├── android/ # Configurazione e codice per Android 
├── ios/ # Configurazione e codice per iOS 
├── lib/ # Codice Dart (logica dell'app) 
│ ├── main.dart # Punto di ingresso dell'app 
├── test/ # Test dell'app 
├── web/ # Configurazione e codice per il Web 
├── linux/ # Codice specifico per Linux 
├── windows/ # Codice specifico per Windows 
├── macos/ # Codice specifico per macOS 
└── pubspec.yaml # File di configurazione di Flutter
```


### Dipendenze
1. **Flutter SDK**: Assicurati di avere l'ultima versione stabile di Flutter installata sul tuo sistema. Puoi scaricarla e configurarla dal sito ufficiale di Flutter: https://flutter.dev.
   
2. **Editor**: Puoi usare qualsiasi editor di testo, ma ti consigliamo di usare [VS Code](https://code.visualstudio.com/) o [Android Studio](https://developer.android.com/studio) per ottenere un supporto completo per Flutter.

## Come Eseguire il Progetto

### 1. **Installare le dipendenze**
Dopo aver clonato il progetto, esegui il comando seguente per installare tutte le dipendenze necessarie:
```sh
flutter pub get
```

### 2. **Eseguire l'app**
Per avviare l'app su un emulatore o dispositivo fisico:

- Su Android:
```sh
flutter run
```

- Su iOS (richiede un ambiente macOS con Xcode):
```sh
flutter run
```

- Su Windows/Linux/macOS:
```sh
flutter run -d <windows|linux|macos>
```

### 3. **Eseguire i Test**
Per eseguire i test automatizzati dell'app:
```sh
flutter test
```

## Configurazione

### 1. **Configurazione per Android**
Assicurati che la tua macchina abbia l'ambiente di sviluppo Android configurato, con Android Studio e il relativo emulatore o un dispositivo fisico collegato.

- Per costruire un APK per Android:
```sh
flutter build apk --release
```

- Per costruire un AAB (Android App Bundle):
```sh
flutter build appbundle --release
```

### 2. **Configurazione per iOS**
Su macOS, per configurare l'ambiente iOS, è necessario Xcode.

- Per costruire l'app per iOS:
```sh
flutter build ios --release
```

### 3. **Configurazione per Linux**
Assicurati di avere le dipendenze necessarie per compilare applicazioni Flutter su Linux, come GTK3.

- Per costruire l'app per Linux:
```sh
flutter build linux
```

### 4. **Configurazione per Windows**
Flutter supporta lo sviluppo di app Windows su Windows 10 o versioni successive.

- Per costruire l'app per Windows:
```sh
flutter build windows
```

### 5. **Configurazione per macOS**
Per distribuire su macOS, assicurati di avere Xcode installato.

- Per costruire l'app per macOS:
```sh
flutter build macos
```

## Distribuzione

### 1. **Distribuire su Android**
Per distribuire su Android, puoi generare un file APK o un Android App Bundle (AAB).

#### Creare un APK:
```sh
flutter build apk --release
```

Distribuisci l'APK manualmente o caricalo su Google Play Store.

#### Creare un AAB:
```sh
flutter build appbundle --release
```

Carica il file AAB su Google Play Store tramite la console di Google Play Developer.

### 2. **Distribuire su iOS**
Per distribuire su iOS, dovrai usare Xcode per creare un file `.ipa` e pubblicarlo su App Store o TestFlight.

#### Creare un file IPA:
1. Apri il progetto iOS in Xcode (`ios/Runner.xcworkspace`).
2. Seleziona il dispositivo di destinazione.
3. Vai su **Product > Archive** per creare il pacchetto.
4. Carica l'IPA su App Store Connect per la distribuzione.

### 3. **Distribuire su Linux**
Per creare un pacchetto `.deb` o `.AppImage` su Linux:

1. Costruisci il progetto:
```sh
flutter build linux
```

2. Crea un pacchetto `.deb`:
```sh
dpkg-deb --build build/linux/x64/release/bundle
```

3. Crea un pacchetto `.AppImage` utilizzando uno strumento come `AppImageKit`.

Distribuisci il file `.deb` tramite un repository di pacchetti o il file `.AppImage` su un server.

### 4. **Distribuire su Windows**
Per distribuire l'app su Windows, puoi creare un file `.exe` e un installer personalizzato.

1. Costruisci il progetto per Windows:
```sh
flutter build windows
```

2. Crea un installer personalizzato con **Inno Setup** o **NSIS**.
- Scarica e configura Inno Setup: https://jrsoftware.org/isinfo.php.
- Scrivi uno script `.iss` per includere l'eseguibile e altre dipendenze, quindi compila l'installer.

### 5. **Distribuire su macOS**
Per distribuire su macOS, puoi creare un pacchetto `.dmg` o `.pkg`.

1. Costruisci il progetto per macOS:
```sh
flutter build macos
```

2. Usa strumenti come **create-dmg** per creare un file `.dmg`.

### 6. **Distribuire su Web**
Per distribuire l'app sul web, esegui il comando:
```sh
flutter build web
```

Carica i file generati nella cartella `build/web` su un server web per renderli accessibili tramite un browser.

## Considerazioni Finali
- Ogni piattaforma (Android, iOS, Linux, Windows, macOS) ha il suo proprio flusso di lavoro e requisiti di distribuzione.
- Flutter rende possibile la creazione di un'app con un'unica base di codice per più piattaforme, ma la configurazione specifica di ciascuna piattaforma richiede attenzione ai dettagli.
- Per la distribuzione su Android e iOS, la pubblicazione tramite Google Play Store e App Store è il metodo standard.