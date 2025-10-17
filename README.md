# Scriptagher

Scriptagher è un'applicazione Flutter con backend integrato (Shelf) pensata per scoprire, scaricare ed eseguire bot di trading o automazione. Il progetto include una UI desktop/web, un server locale che comunica con GitHub per recuperare i pacchetti dei bot e un database SQLite per conservarne i metadati.

## Contenuti
- [Prerequisiti](#prerequisiti)
- [Avvio rapido](#avvio-rapido)
- [Struttura del progetto](#struttura-del-progetto)
- [Flusso di gestione dei bot](#flusso-di-gestione-dei-bot)
- [Guida "Crea il tuo bot"](#guida-crea-il-tuo-bot)
- [Test](#test)
- [Risorse aggiuntive](#risorse-aggiuntive)

## Prerequisiti

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.5 o superiore
- Dart SDK (incluso con Flutter)
- Strumenti di piattaforma specifici (Android Studio/Xcode se necessari)

## Avvio rapido

```bash
flutter pub get
flutter run
```

Il backend Shelf viene avviato automaticamente da `lib/main.dart` all'avvio dell'app.

## Struttura del progetto

```
lib/
├── main.dart                      # bootstrap frontend + backend
├── backend/                       # server Shelf, database e servizi bot
├── frontend/                      # widget, pagine e servizi Flutter
├── shared/                        # utilità condivise, logger, costanti
assets/                            # risorse statiche
start_project.sh                   # script di bootstrap opzionale
docs/                              # documentazione tecnica
```

## Flusso di gestione dei bot

1. **Discovery** – `BotGetService` interroga il repository GitHub `gh-pages/bots/bots.json` per ottenere l'elenco dei bot.
2. **Download** – Quando l'utente sceglie un bot, `BotDownloadService` scarica l'archivio `.zip`, lo estrae in `data/remote/<linguaggio>/<bot>` e registra i metadati in SQLite.
3. **Catalogo locale** – L'endpoint `/localbots` unisce i bot salvati nel database e quelli trovati nella cartella `localbots/`.
4. **Esecuzione** – La UI mostra `startCommand` e altri dettagli da `Bot.json`; il runner (in sviluppo) userà quel comando per avviare il processo del bot.

## Guida "Crea il tuo bot"

Per istruzioni dettagliate su:
- Struttura consigliata di un pacchetto bot
- Esempio completo di `Bot.json`
- Flusso di download ed esecuzione end-to-end
- Best practice di sicurezza per sviluppatori di bot

consulta la documentazione dedicata in [`docs/creating-your-bot.md`](docs/creating-your-bot.md). La guida è richiamabile anche dalla UI (Home e pagine Bot).

## Test

Esegui la suite di test unitari Flutter:

```bash
flutter test
```

## Risorse aggiuntive

- [Documentazione Flutter](https://docs.flutter.dev/)
- [Pacchetto Shelf](https://pub.dev/packages/shelf)
- [Repository dei bot (ramo gh-pages)](https://github.com/diegofcj/scriptagher/tree/gh-pages/bots)
