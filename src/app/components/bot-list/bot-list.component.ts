import { Component, OnInit } from '@angular/core';
import { BotService, InstallerAsset } from '../../services/bot.service';
import { CommonModule } from '@angular/common';
import { BotSectionComponent } from '../bot-section/bot-section.component';
import { HeaderComponent } from '../header/header.component';
import { FooterComponent } from '../footer/footer.component';
import { InstallerSectionComponent } from '../installer-section/installer-section.component';
import { forkJoin } from 'rxjs';

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
    FooterComponent
  ]
})
export class BotListComponent implements OnInit {
  botSections: any[] = [];
  errorMessage: string = '';
  installerAssets: InstallerAsset[] = [];

  constructor(private botService: BotService) {}

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
        for (const language in botsConfig) {
          const bots = botsConfig[language];
          if (!bots || bots.length === 0) continue;
          const botDetails = await Promise.all(
            bots.map(async (bot: any) => {
              try {
                bot.language = language;
                return await this.botService.getBotDetails(bot).toPromise();
              } catch {
                return { botName: bot.botName, description: 'Error loading details' };
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
        console.error('Error fetching bots configuration:', err);
        this.errorMessage = 'Failed to load the bot list.';
      },
    });
  }
}