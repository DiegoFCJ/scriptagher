import { Component, Input, OnDestroy } from '@angular/core';
import { BotCardComponent } from '../bot-card/bot-card.component';
import { CommonModule } from '@angular/common';
import { BotService } from '../../services/bot.service';
import { I18nService, UiStrings } from '../../services/i18n.service';
import { Subscription } from 'rxjs';

@Component({
  selector: 'app-bot-section',
  standalone: true,
  imports: [
    CommonModule,
    BotCardComponent
  ],
  templateUrl: './bot-section.component.html',
  styleUrls: ['./bot-section.component.scss']
})
export class BotSectionComponent implements OnDestroy {
  @Input() language: string = '';
  @Input() languageLabel: string = '';
  @Input() title: string = '';
  @Input() summary?: string;
  @Input() bots: any[] = [];

  uiText: UiStrings;
  private languageSubscription?: Subscription;

  constructor(private botService: BotService, private readonly i18nService: I18nService) {
    this.uiText = this.i18nService.getUiStrings();
    this.languageSubscription = this.i18nService.language$.subscribe(() => {
      this.uiText = this.i18nService.getUiStrings();
    });
  }

  ngOnDestroy(): void {
    this.languageSubscription?.unsubscribe();
  }

  get resolvedLanguageLabel(): string {
    if (this.languageLabel) {
      return this.languageLabel;
    }
    return this.language ? this.language.toUpperCase() : '';
  }

  get resolvedTitle(): string {
    if (this.title) {
      return this.title;
    }
    if (this.language) {
      const capitalized = this.language.charAt(0).toUpperCase() + this.language.slice(1);
      return `${capitalized} ${this.uiText.botsLabel}`.trim();
    }
    return this.uiText.botsLabel;
  }

  downloadBot(bot: any) {
    bot.language = this.language;
    this.botService.downloadBot(bot).subscribe({
      next: (blob: Blob) => {
        const link = document.createElement('a');
        link.href = window.URL.createObjectURL(blob);
        link.download = `${bot.botName}.zip`;
        link.click();
      },
      error: (error: any) => {
        console.error('Error downloading bot:', error);
        alert('Could not download the bot. Please try again.');
      }
    })
  }
}
