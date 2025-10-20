import { CommonModule } from '@angular/common';
import { Component, Input, Output, EventEmitter } from '@angular/core';
import { Router } from '@angular/router';
import { BotService, LocalizedBotDetails } from '../../services/bot.service';
import { TranslatePipe } from '../../core/i18n/translate.pipe';
import { TranslationService } from '../../core/i18n/translation.service';

@Component({
  selector: 'app-bot-card',
  standalone: true,
  imports: [CommonModule, TranslatePipe],
  templateUrl: './bot-card.component.html',
  styleUrls: ['./bot-card.component.scss']
})
export class BotCardComponent {
  @Input() bot!: LocalizedBotDetails;
  @Input() language: string = '';
  @Output() download = new EventEmitter<void>();

  constructor(
    private router: Router,
    private botService: BotService,
    private translation: TranslationService
  ) {}

  openBot() {
    this.bot.language = this.language;
    this.botService.openBot(this.bot);
  }

  downloadBot() {
    this.download.emit();
  }

  viewDetails(): void {
    this.router.navigate(['/bots', this.language, this.bot.botName]);
  }

  navigateToPdfToTxt() {
    try {
      this.router.navigate(['/pdf-to-txt']);
    } catch (error) {
      console.error(this.translation.translate('botCard.navigationError') + ':', error);
    }
  }
}
