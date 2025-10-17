# Guida: crea il tuo bot Scriptagher

Questa guida illustra la struttura prevista per un bot compatibile con Scriptagher,
mostra un esempio completo di `Bot.json` e descrive il flusso con cui l'applicazione
download e avvia i bot. Include inoltre suggerimenti di sicurezza e best practice
per gli sviluppatori.

## Struttura minima di un bot

Ogni bot è distribuito come directory comprimibile (zip) con la seguente struttura
minima:

```
my-awesome-bot/
├── Bot.json
├── main.py            # entrypoint principale (il nome può cambiare, vedi Bot.json)
├── requirements.txt   # dipendenze opzionali
└── resources/         # asset opzionali
```

* **Bot.json** descrive metadati, comandi e runtime richiesti.
* **File sorgente**: lo script o binario che implementa la logica del bot.
* **Dipendenze**: file opzionali (`requirements.txt`, `package.json`, ecc.) usati
  durante la fase di installazione.

## Esempio di `Bot.json`

```json
{
  "botName": "MyAwesomeBot",
  "version": "1.0.0",
  "description": "Esempio di bot che stampa un messaggio",
  "author": "Jane Doe",
  "language": "python",
  "entrypoint": "main.py",
  "args": ["--verbose"],
  "environment": {
    "PYTHONPATH": "./"
  },
  "postInstall": [
    "pip install -r requirements.txt"
  ],
  "permissions": [
    "network",
    "filesystem:read"
  ]
}
```

Campi principali:

* **botName** – identificativo mostrato nell'interfaccia.
* **version** – utile per aggiornamenti.
* **description** – anteprima rapida della funzionalità.
* **language** – usato dal backend per scegliere il runtime.
* **entrypoint** – file o comando da eseguire.
* **args** – argomenti opzionali.
* **environment** – variabili d'ambiente aggiuntive.
* **postInstall** – comandi eseguiti dopo il download per preparare il bot.
* **permissions** – elenco dichiarativo delle risorse richieste.

## Flusso di download ed esecuzione

1. **Scoperta** – i bot pubblicati online vengono elencati nella sezione "Online".
2. **Download** – l'utente avvia il download; il pacchetto zip viene salvato nel
   database locale e sul filesystem.
3. **Installazione** – se `postInstall` contiene comandi, il backend li esegue
   nell'ambiente isolato del bot.
4. **Esecuzione** – dall'interfaccia è possibile avviare il bot: il backend
   esegue l'`entrypoint` impostando argomenti e variabili indicati.
5. **Monitoraggio** – l'output viene mostrato in tempo reale nella pagina di
   dettaglio del bot.

## Crea il tuo bot

1. Clona questo repository o scarica il template dal sito.
2. Crea una nuova cartella per il bot e aggiungi `Bot.json` con i metadati.
3. Implementa l'`entrypoint` e assicurati che sia eseguibile localmente.
4. Se servono dipendenze, aggiungi i file necessari (`requirements.txt`,
   `package.json`, ecc.) e riportale in `postInstall`.
5. Comprimi la cartella e caricala nel marketplace Scriptagher oppure
   posizionala nelle directory monitorate dall'applicazione.

## Note di sicurezza e best practice

* **Esegui sempre il bot in un ambiente isolato** (es. container, ambiente
  virtuale) per evitare che processi malevoli compromettano il sistema.
* **Valida l'input** proveniente da utenti o servizi esterni per prevenire
  injection e escalation.
* **Limita le dipendenze** a quelle strettamente necessarie e blocca le versioni
  per ridurre l'esposizione a vulnerabilità note.
* **Dichiara solo le permission indispensabili** in `Bot.json` e verifica che il
  bot non acceda a risorse non necessarie.
* **Gestisci in modo sicuro i segreti** (token, chiavi API) usando variabili
  d'ambiente o servizi di secret management, evitando di inserirli nel codice.
* **Firma digitalmente o verifica l'origine del pacchetto** prima di pubblicarlo.
* **Monitora l'esecuzione** con log strutturati e gestisci gli errori in modo
  esplicito per migliorare la diagnosi.

Per ulteriori dettagli, consulta il README principale o contatta il team.
