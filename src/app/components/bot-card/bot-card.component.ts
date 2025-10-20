import { CommonModule } from '@angular/common';
import { Component, Input, Output, EventEmitter, OnDestroy } from '@angular/core';
import { Router } from '@angular/router';
import { BotService } from '../../services/bot.service';
import { I18nService, UiStrings } from '../../services/i18n.service';
import { Subscription } from 'rxjs';

@Component({
  selector: 'app-bot-card',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './bot-card.component.html',
  styleUrls: ['./bot-card.component.scss']
})
export class BotCardComponent implements OnDestroy {
  @Input() bot: any;
  @Input() language: string = '';
  @Output() download = new EventEmitter<void>();

  uiText: UiStrings;
  private languageSubscription?: Subscription;

  constructor(
    private router: Router,
    private botService: BotService,
    private readonly i18nService: I18nService
  ) {
    this.uiText = this.i18nService.getUiStrings();
    this.languageSubscription = this.i18nService.language$.subscribe(() => {
      this.uiText = this.i18nService.getUiStrings();
    });
  }

  ngOnDestroy(): void {
    this.languageSubscription?.unsubscribe();
  }

  get displayName(): string {
    return this.bot?.displayName ?? this.bot?.botName ?? this.uiText.missingValueFallback;
  }

  get description(): string {
    return this.bot?.shortDescription ?? this.bot?.description ?? this.uiText.noDescriptionFallback;
  }

  get startCommand(): string {
    if (typeof this.bot?.startCommand === 'string' && this.bot.startCommand.trim()) {
      return this.bot.startCommand;
    }
    return this.uiText.noStartCommandFallback;
  }

  openBot() {
    this.bot.language = this.language;
    this.botService.openBot(this.bot);
  }

  downloadBot() {
    this.download.emit();
  }

  navigateToPdfToTxt() {
    try {
      this.router.navigate(['/pdf-to-txt']);
    } catch (error) {
      console.error('Errore durante la navigazione verso la pagina PDF to Txt:', error);
    }
  }
}
