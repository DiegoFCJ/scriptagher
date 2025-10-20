import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';

import { BotCardComponent } from '../bot-card/bot-card.component';
import { BotService, LocalizedBotDetails } from '../../services/bot.service';
import { TranslatePipe } from '../../core/i18n/translate.pipe';
import { TranslationService } from '../../core/i18n/translation.service';

@Component({
  selector: 'app-bot-section',
  standalone: true,
  imports: [CommonModule, BotCardComponent, TranslatePipe],
  templateUrl: './bot-section.component.html',
  styleUrls: ['./bot-section.component.scss']
})
export class BotSectionComponent {
  @Input() language: string = '';
  @Input() title: string = '';
  @Input() summary: string = '';
  @Input() bots: LocalizedBotDetails[] = [];

  constructor(private botService: BotService, private translation: TranslationService) {}

  downloadBot(bot: LocalizedBotDetails) {
    bot.language = this.language;
    this.botService.downloadBot(bot).subscribe({
      next: (blob: Blob) => {
        const link = document.createElement('a');
        link.href = window.URL.createObjectURL(blob);
        link.download = `${bot.botName}.zip`;
        link.click();
      },
      error: (error: any) => {
        console.error(this.translation.translate('botSection.downloadErrorLog') + ':', error);
        alert(this.translation.translate('botSection.downloadErrorAlert'));
      }
    });
  }
}
