# Risolvere gli avvisi di Microsoft Defender SmartScreen

Quando si distribuisce l'installer di Scriptagher per Windows (`ScriptagherSetup.exe`), gli utenti potrebbero ricevere il messaggio:

> **Microsoft Defender SmartScreen ha impedito l'avvio di un'app non riconosciuta. L'esecuzione di tale app potrebbe costituire un rischio per il PC.**
>
> App: ScriptagherSetup.exe
>
> Autore: Editore sconosciuto

Questa guida raccoglie le attività da svolgere **su ogni PC Windows** per sbloccare l'esecuzione in sicurezza e ridurre le segnalazioni in futuro.

## 1. Verifica preliminare dell'integrità

Prima di ignorare l'avviso, verifica che l'installer provenga da una fonte affidabile.

1. **Confronta l'hash** pubblicato dal team con l'hash del file scaricato:
   ```powershell
   Get-FileHash .\ScriptagherSetup.exe -Algorithm SHA256
   ```
   Se l'hash combacia, il file non è stato alterato.
2. **Scansiona l'eseguibile** con Microsoft Defender o un antivirus aziendale aggiornato.
3. **Controlla la provenienza**: scarica solo da repository ufficiali o dal server aziendale di distribuzione.

## 2. Sblocco dell'app su un dispositivo specifico

Per consentire l'esecuzione dell'installer su un singolo PC:

1. Fai clic con il **pulsante destro** su `ScriptagherSetup.exe` > **Proprietà**.
2. Nella scheda **Generale**, spunta **Sblocca** (se presente) e conferma con **Applica**.
3. Avvia l'eseguibile. Nella finestra SmartScreen scegli **Ulteriori informazioni**.
4. Seleziona **Esegui comunque** per completare l'installazione.

> **Suggerimento:** se l'opzione *Sblocca* non è visibile, il file potrebbe essere già considerato attendibile (ad esempio perché firmato internamente).

## 3. Automazione per ambienti gestiti

Su dispositivi aziendali gestiti con criteri di gruppo o strumenti MDM:

- **Criterio di gruppo (GPO):** Abilita la regola *Configura Microsoft Defender SmartScreen* in `Configurazione computer > Modelli amministrativi > Componenti di Windows > Esplora file`, impostandola su **Avvisa**. Specifica l'hash dell'app come eccezione nelle *Impostazioni di elenco App consentite*.
- **Microsoft Intune / Endpoint Manager:** Crea una regola di reputazione per file attendibili includendo l'hash SHA-256 dell'installer o firma digitale personalizzata.
- **Script PowerShell:** Distribuisci uno script che aggiunge l'hash all'elenco consentito e installa il certificato del publisher (vedi sezione successiva).

Documenta le eccezioni applicate per ogni dispositivo, così da poter revocare l'accesso in caso di compromissione.

## 4. Migliorare la reputazione del file

Per ridurre gli avvisi SmartScreen nel tempo:

- **Firma il pacchetto** con un certificato di firma del codice (Code Signing) emesso da una Certification Authority riconosciuta. Se il budget lo consente, prediligi un certificato **EV (Extended Validation)** perché genera fiducia immediata in SmartScreen.
- **Applica una marca temporale (timestamp)** durante la firma (`signtool sign /fd sha256 /tr http://timestamp.digicert.com ...`): evita che la firma risulti scaduta quando il certificato viene rinnovato.
- **Pubblica regolarmente build firmate**: SmartScreen costruisce la reputazione in base al numero di installazioni riuscite di un file firmato.
- **Aggiorna i metadati** dell'installer (CompanyName, ProductName, FileDescription) per mostrare un editore riconoscibile.
- **Evita modifiche inutili** all'eseguibile: ogni nuovo hash richiede di nuovo la reputazione.

### Pipeline consigliata per la firma

1. Acquista e configura il certificato di firma del codice (preferibilmente EV) su un dispositivo sicuro o HSM.
2. Integra nel processo CI/CD un job che, dopo aver generato `ScriptagherSetup.exe`, esegue `signtool sign` con il certificato e la marca temporale.
3. Conserva il file firmato in un archivio verificato e pubblica solo quella versione.
4. Utilizza `signtool verify /pa ScriptagherSetup.exe` per controllare la validità della firma come parte delle checklist di rilascio.

## 5. Risoluzione dei problemi comuni

| Problema | Causa possibile | Soluzione |
| --- | --- | --- |
| L'opzione "Esegui comunque" non appare | Criteri aziendali bloccano SmartScreen | Richiedi un'eccezione al reparto IT o distribuisci l'installer tramite strumenti approvati (es. SCCM, Intune). |
| L'avviso ricompare a ogni aggiornamento | Nuovo hash privo di reputazione | Distribuisci build firmate e aggiorna l'elenco hash nelle policy. |
| L'utente non può modificare le proprietà del file | Account senza privilegi amministrativi | Esegui l'installazione con credenziali amministrative o programma l'installazione centrale. |
| Hash diversi tra dispositivi | Download corrotto o manomissione | Elimina il file e riscaricalo dalla fonte ufficiale. |

## 6. Rendere l'installer affidabile per Windows

Per evitare che Windows identifichi l'installer come potenzialmente dannoso, adotta anche le seguenti pratiche proattive:

1. **Includi Scriptagher nella Microsoft Security Intelligence**: carica il pacchetto firmato nel portale [Microsoft Security Intelligence](https://www.microsoft.com/en-us/wdsi/filesubmission) e richiedi la valutazione come software legittimo. Allegare dettagli (descrizione, hash, firma) accelera la revisione e riduce i falsi positivi.
2. **Partecipa al programma SmartScreen Application Reputation**: assicurati che l'account Microsoft Partner sia verificato, mantieni la firma EV attiva e pubblica versioni con numeri di versione incrementali. Più utenti eseguono versioni identiche firmate, maggiore sarà la reputazione assegnata.
3. **Distribuisci tramite canali fidati**: preferisci Windows Package Manager, Microsoft Store oppure link HTTPS aziendali con certificato valido. Un download da fonti inattese può far scattare ulteriori controlli antivirus.
4. **Elimina comportamenti sospetti**: assicurati che l'installer non scarichi componenti non firmati, non modifichi impostazioni di sicurezza e non richieda privilegi amministrativi superflui. Compila in modalità *Release* e riduci al minimo i *packer* o compressioni autoestraenti che possono ricordare malware.
5. **Monitora il feedback degli utenti**: raccogli hash e log dagli endpoint che segnalano l'app come minaccia. Invia questi dati a Microsoft durante le segnalazioni per far aggiornare le definizioni.
6. **Mantieni aggiornati i certificati**: rinnova il certificato di firma prima della scadenza e distribuisci rapidamente nuove build firmate; un certificato scaduto annulla la fiducia costruita.

## 7. Checklist per ogni dispositivo

1. Conferma l'hash con `Get-FileHash`.
2. Avvia la scansione antivirus manuale.
3. Sblocca il file dalle proprietà, se richiesto.
4. Passa da **Ulteriori informazioni** > **Esegui comunque**.
5. Registra l'installazione nel registro interno dei dispositivi.
6. Verifica l'esito dell'installazione e aggiorna eventuali policy.

Seguendo questi passaggi, l'installer `ScriptagherSetup.exe` può essere eseguito in sicurezza e con il minimo impatto sulle policy di protezione impostate da Microsoft Defender SmartScreen.
