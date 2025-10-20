import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { forkJoin } from 'rxjs';

import { BotService, InstallerAsset } from '../../services/bot.service';
import { TranslatePipe } from '../../core/i18n/translate.pipe';
import { TranslationService } from '../../core/i18n/translation.service';
import { BotSectionComponent } from '../bot-section/bot-section.component';
import { HeaderComponent } from '../header/header.component';
import { FooterComponent } from '../footer/footer.component';
import { InstallerSectionComponent } from '../installer-section/installer-section.component';

@Component({
  selector: 'app-bot-list',
  templateUrl: './bot-list.component.html',
  styleUrls: ['./bot-list.component.scss'],
  standalone: true,
  imports: [
    CommonModule,
    HeaderComponent,
    BotSectionComponent,
    InstallerSectionComponent,
    FooterComponent,
    TranslatePipe
  ]
})
export class BotListComponent implements OnInit {
  botSections: any[] = [];
  errorMessageKey: string | null = null;
  installerAssets: InstallerAsset[] = [];

  constructor(private botService: BotService, private translation: TranslationService) {}

  ngOnInit() {
    this.populateBotList();
  }

  populateBotList() {
    forkJoin({
      botsConfig: this.botService.getBotsConfig(),
      installers: this.botService.listInstallerAssets()
    }).subscribe({
      next: async ({ botsConfig, installers }) => {
        this.botSections = [];
        this.installerAssets = installers ?? [];
        this.errorMessageKey = null;
        for (const language in botsConfig) {
          const bots = botsConfig[language];
          if (!bots || bots.length === 0) continue;
          const botDetails = await Promise.all(
            bots.map(async (bot: any) => {
              try {
                bot.language = language;
                return await this.botService.getBotDetails(bot).toPromise();
              } catch {
                return {
                  botName: bot.botName,
                  description: this.translation.translate('botList.cardLoadError'),
                };
              }
            })
          );
          this.botSections.push({
            language,
            botDetails,
          });
        }
      },
      error: (err) => {
        console.error(this.translation.translate('botList.loadError') + ':', err);
        this.errorMessageKey = 'botList.loadError';
      },
    });
  }
}