import { CommonModule } from '@angular/common';
import { Component, Input, Output, EventEmitter, OnDestroy } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { Subscription } from 'rxjs';

import { BotService, LocalizedBotDetails } from '../../services/bot.service';
import { TranslatePipe } from '../../core/i18n/translate.pipe';
import { TranslationService } from '../../core/i18n/translation.service';

@Component({
  selector: 'app-bot-card',
  standalone: true,
  imports: [CommonModule, TranslatePipe, RouterLink],
  templateUrl: './bot-card.component.html',
  styleUrls: ['./bot-card.component.scss']
})
export class BotCardComponent implements OnDestroy {
  @Input() bot!: LocalizedBotDetails;
  @Input() language: string = '';
  @Output() download = new EventEmitter<void>();

  private isSourceRepoPublic = true;
  private readonly sourceVisibilitySubscription: Subscription;

  constructor(
    private router: Router,
    private botService: BotService,
    private translation: TranslationService
  ) {
    this.sourceVisibilitySubscription = this.botService.isSourceRepoPublic$.subscribe(
      (isPublic) => {
        this.isSourceRepoPublic = isPublic;
      }
    );
  }

  get canViewSource(): boolean {
    return !!this.bot?.sourceUrl && this.isSourceRepoPublic;
  }

  ngOnDestroy(): void {
    this.sourceVisibilitySubscription.unsubscribe();
  }

  openBot() {
    if (!this.canViewSource) {
      return;
    }

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
      console.error(this.translation.translate('botCard.navigationError') + ':', error);
    }
  }
}
