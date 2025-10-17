import { Inject, Injectable, Optional } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { APP_BASE_HREF, DOCUMENT } from '@angular/common';

@Injectable({
  providedIn: 'root'
})
export class BotService {
  private readonly botsBaseUrl: URL;
  private readonly botsSourceBaseUrl: URL;

  constructor(
    private http: HttpClient,
    @Optional() @Inject(DOCUMENT) private readonly documentRef: Document | null,
    @Optional() @Inject(APP_BASE_HREF) private readonly appBaseHref?: string
  ) {
    const baseUrl = this.resolveBaseUrl();
    this.botsBaseUrl = new URL('bots/', baseUrl);
    this.botsSourceBaseUrl = new URL('bots/', baseUrl);
  }

  private resolveBaseUrl(): string {
    const documentBase = this.documentRef?.baseURI;
    if (documentBase) {
      return this.ensureTrailingSlash(documentBase);
    }

    const locationHref = typeof location !== 'undefined' ? location.href : undefined;

    const origin = locationHref ? new URL('.', locationHref).toString() : 'http://localhost/';
    const base = new URL(this.appBaseHref ?? '/', origin).toString();
    return this.ensureTrailingSlash(base);
  }

  private ensureTrailingSlash(url: string): string {
    return url.endsWith('/') ? url : `${url}/`;
  }

  /**
   * Fetch the bots configuration from bots.json.
   */
  getBotsConfig(): Observable<any> {
    const botsJsonPath = new URL('bots.json', this.botsBaseUrl).toString();
    return this.http.get(botsJsonPath);
  }

  /**
   * Costruisce il percorso completo per ottenere i dettagli di un bot specifico.
   * Fetch detailed bot information from Bot.json.
   * @param bot - The bot's name.
   */
  getBotDetails(bot: any): Observable<any> {
    const botJsonPath = new URL(`${bot.language}/${bot.botName}/Bot.json`, this.botsBaseUrl).toString();
    return this.http.get(botJsonPath);
  }

  /**
   * Fetch and download the bot ZIP file.
   * @param bot - The bot's name.
   */
  downloadBot(bot: any): Observable<Blob> {
    const assetName = bot.path || `${bot.botName}.zip`;
    const zipPath = new URL(`${bot.language}/${bot.botName}/${assetName}`, this.botsBaseUrl).toString();
    return this.http.get(zipPath, { responseType: 'blob' });
  }

  /**
   * Open the bot source code in a new tab.
   * @param bot - Bot object containing language and name.
   */
  openBot(bot: any): void {
    const assetName = bot.path || `${bot.botName}.zip`;
    const sourcePath = new URL(`${bot.language}/${bot.botName}/${assetName}`, this.botsSourceBaseUrl).toString();
    window.open(sourcePath, '_blank');
  }
}