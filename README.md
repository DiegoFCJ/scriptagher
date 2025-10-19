# Progetto Flutter

## Descrizione
Questo progetto è una semplice applicazione mobile/desktop/web sviluppata con Flutter. Flutter è un framework open-source che permette di creare app per dispositivi mobili, desktop e web da una singola base di codice. Questo README include informazioni su come eseguire, configurare, testare e distribuire l'app su diverse piattaforme (Android, iOS, Linux, Windows e altre).

## Bot per Scriptagher

Scriptagher consente di scaricare, installare ed eseguire bot provenienti da marketplace, repository locali o filesystem.

- Consulta la guida completa su come strutturare e distribuire un bot in [`docs/create-your-bot.md`](docs/create-your-bot.md).
- Troverai un esempio completo di `Bot.json`, il flusso di download/esecuzione e una checklist di sicurezza e best practice.

### Struttura rapida di un bot

```
my-awesome-bot/
├── Bot.json
├── main.py
├── requirements.txt
└── resources/
```

Il file `Bot.json` contiene i metadati (nome, descrizione, versione), l'entrypoint da eseguire, variabili d'ambiente, comandi post installazione e le permission richieste. Consulta la guida per un esempio dettagliato e per comprendere come il backend esegue i comandi dichiarati in sicurezza.

### Flusso di download ed esecuzione

1. **Scoperta** – i bot online vengono caricati dall'API e presentati nella UI.
2. **Download** – il pacchetto viene salvato nel database locale e nel filesystem.
3. **Installazione** – eventuali comandi `postInstall` vengono eseguiti in un ambiente controllato.
4. **Esecuzione** – l'entrypoint dichiarato in `Bot.json` viene avviato con argomenti e variabili configurate.
5. **Monitoraggio** – l'interfaccia mostra i log in tempo reale nella pagina di dettaglio del bot.

> **Sicurezza:** sviluppa bot in ambienti isolati, dichiara solo le permission indispensabili e controlla l'origine dei pacchetti. Altri suggerimenti sono disponibili nella guida dedicata.

### Aggiornare la botlist con la pipeline GitHub Actions

Il repository include il workflow [`deploy-botlist`](.github/workflows/deploy-botlist.yml) che, ad ogni push sul branch `main` o al tag di una release, comprime i bot disponibili e pubblica i file risultanti su `gh-pages`.

1. **Aggiungi o modifica un bot** nella directory `bot-sources/<piattaforma>/<nome-bot>/` assicurandoti che contenga un file `Bot.json` valido secondo la guida.
2. **Esegui lo script di packaging in locale** (opzionale) con `bash tool/package_bots.sh bot-sources build/botlist` per verificare che vengano generati gli archivi `.zip` e i manifest aggiornati.
3. **Apri una pull request o esegui un push su `main`**: il workflow eseguirà automaticamente lo script, aggiornerà `botlist.json` aggregando i metadati e pubblicherà la cartella `build/botlist/` sul branch `gh-pages` tramite `peaceiris/actions-gh-pages`, mantenendo la cronologia e i file esistenti.
4. **Recupera la botlist pubblicata** dal branch `gh-pages` (`bots/<piattaforma>/<nome>.zip`, `bots/<piattaforma>/<nome>.json` e `botlist.json`) per distribuirla via CDN o per l'app Scriptagher.

Se la directory `bot-sources/` è vuota il workflow pubblicherà comunque un `botlist.json` valido con un array di bot vuoto, preservando la cache dei client.

### Backend API e CORS

Il server backend Shelf esposto su `http://localhost:8080` gestisce automaticamente le richieste `OPTIONS` e applica gli header CORS `Access-Control-Allow-Origin`, `Access-Control-Allow-Methods` e `Access-Control-Allow-Headers` a tutte le risposte, inclusi gli stream SSE. Assicurati che qualsiasi client personalizzato invii le richieste con gli header previsti (ad esempio `Content-Type` o `Authorization`) per sfruttare correttamente il supporto CORS fornito dal backend.

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

### Flusso di backup e ripristino degli installer

Per aiutare i maintainer a gestire in sicurezza gli asset pubblicati su `gh-pages`, ogni pull request che modifica gli installer viene accompagnata da un backup automatico. Quando la PR viene chiusa entra in azione il workflow [`installers-pr-teardown.yml`](.github/workflows/installers-pr-teardown.yml):

1. Il workflow si attiva alla chiusura della PR e lavora direttamente sul branch `gh-pages` con permessi di scrittura.
2. Se la PR è stata **mergeata**, viene eliminata la cartella di backup `installers-backups/pr-<numero_pr>` relativa a quella PR (se presente).
3. Se la PR è stata **chiusa senza merge**, il workflow ripristina la cartella `installers/` copiandola dal backup `installers-backups/pr-<numero_pr>` e poi rimuove il backup ormai inutile.
4. In assenza di backup (ad esempio per PR che non toccano gli installer) il workflow registra semplicemente un messaggio e non effettua modifiche.

> **Nota per i maintainer:** non è necessario alcun intervento manuale nella maggior parte dei casi. Se dovesse servire un ripristino manuale, è sufficiente copiare i contenuti da `installers-backups/pr-<numero_pr>` nel branch `gh-pages` seguendo la stessa struttura usata dal workflow.

## Considerazioni Finali
- Ogni piattaforma (Android, iOS, Linux, Windows, macOS) ha il suo proprio flusso di lavoro e requisiti di distribuzione.
- Flutter rende possibile la creazione di un'app con un'unica base di codice per più piattaforme, ma la configurazione specifica di ciascuna piattaforma richiede attenzione ai dettagli.
- Per la distribuzione su Android e iOS, la pubblicazione tramite Google Play Store e App Store è il metodo standard.