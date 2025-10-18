import { Component, OnInit } from '@angular/core';
import { BotService } from '../../services/bot.service';
import { CommonModule } from '@angular/common';
import { BotSectionComponent } from '../bot-section/bot-section.component';
import { HeaderComponent } from '../header/header.component';
import { FooterComponent } from '../footer/footer.component';

@Component({
  selector: 'app-bot-list',
  templateUrl: './bot-list.component.html',
  styleUrls: ['./bot-list.component.scss'],
  standalone: true,
  imports: [
    CommonModule,
    HeaderComponent,
    BotSectionComponent,
    FooterComponent
  ]
})
export class BotListComponent implements OnInit {
  botSections: any[] = [];
  errorMessage: string = '';

  constructor(private botService: BotService) {}

  ngOnInit() {
    this.populateBotList();
  }

  populateBotList() {
    this.botService.getBotsConfig().subscribe({
      next: async (botsConfig) => {
        this.botSections = [];
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