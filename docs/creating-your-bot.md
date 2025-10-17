# Guida allo sviluppo di un bot Scriptagher

Questa guida descrive come è organizzato l'ecosistema dei bot di Scriptagher, come confezionare correttamente un pacchetto con `Bot.json` e quali buone pratiche seguire per mantenerlo sicuro.

## Architettura in breve

1. **Repository remoto dei bot** – L'app legge la lista di bot pubblici dal ramo `gh-pages` del repository GitHub (`bots/bots.json`). Ogni bot è organizzato per linguaggio (`bots/<linguaggio>/<nomeBot>/`).
2. **Backend locale** – Il server Shelf (`lib/backend/server`) scarica i bot richiesti tramite `BotDownloadService`. Il pacchetto `.zip` viene salvato in `data/remote/<linguaggio>/<nomeBot>/`, estratto e registrato nel database locale (`BotDatabase`).
3. **Frontend Flutter** – Le pagine `BotList` e `BotDetailView` mostrano le informazioni contenute in `Bot.json`. Il comando di avvio (`startCommand`) verrà usato dal runner per eseguire il bot.
4. **Bot locali** – Ogni bot scaricato viene salvato anche nel filesystem (`localbots/<linguaggio>/<nomeBot>/`) e reso disponibile tramite l'endpoint `/localbots`.

Lo schema riassuntivo del flusso di download ed esecuzione è il seguente:

```text
GitHub (bots.json & .zip)
        │
        ▼
BotGetService ──► BotDownloadService ──► data/remote/<linguaggio>/<nomeBot>
        │                                   │
        │                                   ├─► Estrazione Bot.json + sorgenti
        │                                   └─► Registrazione nel database locale
        ▼
Frontend Flutter (BotList/BotDetailView) ──► Avvio bot tramite startCommand
```

## Struttura consigliata del pacchetto bot

Ogni bot deve essere distribuito come archivio `.zip` con la seguente struttura minima:

```
<NomeBot>.zip
└── <NomeBot>/
    ├── Bot.json
    ├── README.md (opzionale)
    ├── src/ (cartella o file con il codice del bot)
    └── assets/ (opzionale per configurazioni o modelli)
```

### Esempio di `Bot.json`

```json
{
  "botName": "TrendFollower",
  "description": "Esegue ordini seguendo il trend delle medie mobili.",
  "language": "python",
  "version": "1.0.0",
  "entryPoint": "src/main.py",
  "startCommand": "python src/main.py --config config.yaml",
  "dependencies": [
    "pandas==2.2.2",
    "numpy==2.0.1"
  ],
  "environment": {
    "PYTHONUNBUFFERED": "1"
  },
  "permissions": {
    "network": false,
    "filesystem": "read"
  },
  "author": {
    "name": "Team Scriptagher",
    "contact": "devs@example.com"
  }
}
```

**Campi obbligatori**

- `botName`: Nome mostrato nella UI.
- `description`: Breve descrizione mostrata in `BotDetailView`.
- `startCommand`: Comando che il runner dovrà eseguire (ad esempio `python src/main.py`).
- `language`: Linguaggio del bot, deve corrispondere alla cartella che lo contiene.

Gli altri campi sono opzionali ma fortemente raccomandati per fornire contesto, dipendenze e requisiti di esecuzione.

## Flusso di download ed esecuzione

1. L'utente seleziona un bot dalla UI (`BotList`).
2. Il frontend chiama il backend (`/bots/{language}/{botName}`) che scarica lo zip da GitHub e lo estrae in `data/remote`.
3. `BotDownloadService` legge `Bot.json`, crea/aggiorna la voce nel database (`BotDatabase`) e salva la copia locale.
4. Il frontend mostra i dettagli del bot (`BotDetailView`). Quando l'utente sceglie **Esegui Bot**, il comando `startCommand` viene preparato per l'esecuzione dal runner (integrazione futura).
5. Se il bot è già presente in locale, il backend lo restituisce direttamente senza riscaricarlo, permettendo l'esecuzione offline.

## Best practice di sicurezza

- **Firma e verifica**: pubblica gli archivi `.zip` firmati digitalmente o accompagnati da hash (SHA-256) e valida l'integrità prima dell'estrazione.
- **Dipendenze controllate**: dichiara le dipendenze nel `Bot.json` e bloccale a versioni specifiche. Evita dipendenze non verificate.
- **Principio del minimo privilegio**: esegui il bot in un ambiente isolato (container, virtualenv, sandbox) con accesso limitato a rete e filesystem. Utilizza il campo `permissions` per documentare le necessità.
- **Gestione delle credenziali**: non inserire segreti all'interno del pacchetto. Affidati a variabili d'ambiente o secret manager locali.
- **Logging e audit**: implementa log chiari delle azioni del bot (senza dati sensibili) per permettere audit successivi.
- **Aggiornamenti**: incrementa `version` e `changelog` ad ogni modifica, in modo che il backend possa riconoscere release differenti.
- **Revisione manuale**: prima di caricare un bot, effettua code review e analisi statica (es. linters, scanner di sicurezza).

## Risorse utili

- [Documentazione Flutter](https://docs.flutter.dev/)
- [Pacchetto shelf](https://pub.dev/packages/shelf)
- [Repository dei bot Scriptagher](https://github.com/diegofcj/scriptagher/tree/gh-pages/bots)

Per ulteriori dettagli o contributi, consulta anche il file `README.md` principale del progetto.
