public class testBotExample {

    public static void main(String[] args) {
        log("Bot avviato.");

        eseguiCompito("Controllo connessione internet", () -> {
            Thread.sleep(1000); // Simulazione
            log("Connessione OK.");
        });

        eseguiCompito("Pulizia file temporanei", () -> {
            Thread.sleep(800);
            log("File temporanei eliminati.");
        });

        eseguiCompito("Controllo aggiornamenti", () -> {
            Thread.sleep(1200);
            log("Nessun aggiornamento disponibile.");
        });

        log("Bot terminato.");
    }

    // Metodo per eseguire un compito con log
    public static void eseguiCompito(String nome, Compito compito) {
        log("Inizio compito: " + nome);
        try {
            compito.esegui();
        } catch (Exception e) {
            log("Errore durante il compito '" + nome + "': " + e.getMessage());
        }
        log("Fine compito: " + nome);
    }

    // Interfaccia funzionale per i compiti
    interface Compito {
        void esegui() throws Exception;
    }

    // Metodo per loggare con timestamp
    public static void log(String messaggio) {
        System.out.println("[" + java.time.LocalTime.now() + "] " + messaggio);
    }
}