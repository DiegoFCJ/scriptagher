import { CommonModule } from '@angular/common';
import { Component, Input, Output, EventEmitter, DestroyRef } from '@angular/core';
import { Router } from '@angular/router';
import { BotService, LocalizedBotDetails } from '../../services/bot.service';
import { TranslatePipe } from '../../core/i18n/translate.pipe';
import { TranslationService } from '../../core/i18n/translation.service';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';

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
  private isSourceRepoPublic = true;

  constructor(
    private router: Router,
    private botService: BotService,
    private translation: TranslationService,
    destroyRef: DestroyRef
  ) {
    this.botService.isSourceRepoPublic$
      .pipe(takeUntilDestroyed(destroyRef))
      .subscribe((isPublic) => {
        this.isSourceRepoPublic = isPublic;
      });
  }

  get canViewSource(): boolean {
    return !!this.bot?.sourceUrl && this.isSourceRepoPublic;
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
