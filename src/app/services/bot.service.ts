import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class BotService {
  private readonly APP_NAME = 'scriptagher';
  private readonly BASE_PATH = `https://raw.githubusercontent.com/diegofcj/${this.APP_NAME}/gh-pages/bots`;
  private readonly BASE_SOURCE = `https://github.com/diegofcj/${this.APP_NAME}/tree/gh-pages/bots`;

  constructor(private http: HttpClient) { }

  /**
   * Fetch the bots configuration from bots.json.
   */
  getBotsConfig(): Observable<any> {
    const botsJsonPath = `${this.BASE_PATH}/bots.json`;
    return this.http.get(botsJsonPath);
  }

  /**
   * Costruisce il percorso completo per ottenere i dettagli di un bot specifico.
   * Fetch detailed bot information from Bot.json.
   * @param bot - The bot's name.
   */
  getBotDetails(bot: any): Observable<any> {
    const botJsonPath = `${this.BASE_PATH}/${bot.language}/${bot.botName}/Bot.json`;
    return this.http.get(botJsonPath);
  }

  /**
   * Fetch and download the bot ZIP file.
   * @param bot - The bot's name.
   */
  downloadBot(bot: any): Observable<Blob> {
    const zipPath = `${this.BASE_PATH}/${bot.language}/${bot.botName}/${bot.botName}.zip`;
    return this.http.get(zipPath, { responseType: 'blob' });
  }

  /**
   * Open the bot source code in a new tab.
   * @param bot - Bot object containing language and name.
   */
  openBot(bot: any): void {
    const sourcePath = `${this.BASE_SOURCE}/${bot.language}/${bot.botName}`;
    window.open(sourcePath, '_blank');
  }
}