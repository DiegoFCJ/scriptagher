import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { ActivatedRoute, RouterModule } from '@angular/router';
import { of, Subject } from 'rxjs';
import { catchError, switchMap, takeUntil } from 'rxjs/operators';

import { FooterComponent } from '../../components/footer/footer.component';
import { HeaderComponent } from '../../components/header/header.component';
import { TranslatePipe } from '../../core/i18n/translate.pipe';
import { TranslationService } from '../../core/i18n/translation.service';
import { BotService, LocalizedBotDetails } from '../../services/bot.service';

@Component({
  selector: 'app-bot-detail-page',
  standalone: true,
  imports: [CommonModule, RouterModule, HeaderComponent, FooterComponent, TranslatePipe],
  templateUrl: './bot-detail-page.component.html',
  styleUrls: ['./bot-detail-page.component.scss']
})
export class BotDetailPageComponent implements OnInit, OnDestroy {
  bot: LocalizedBotDetails | null = null;
  loading = true;
  errorMessageKey: string | null = null;
  language = '';
  private readonly destroy$ = new Subject<void>();

  constructor(
    private readonly route: ActivatedRoute,
    private readonly botService: BotService,
    private readonly translation: TranslationService
  ) {}

  ngOnInit(): void {
    this.observeRoute();
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }

  downloadBot(): void {
    if (!this.bot) {
      return;
    }

    const payload = { ...this.bot, language: this.language };
    this.botService.downloadBot(payload).subscribe({
      error: (error) => {
        console.error(this.translation.translate('botSection.downloadErrorLog') + ':', error);
        alert(this.translation.translate('botSection.downloadErrorAlert'));
      }
    });
  }

  openSource(): void {
    if (!this.bot) {
      return;
    }

    const payload = { ...this.bot, language: this.language };
    this.botService.openBot(payload);
  }

  private observeRoute(): void {
    this.route.paramMap
      .pipe(
        takeUntil(this.destroy$),
        switchMap((params) => {
          const language = params.get('language');
          const botName = params.get('botName');

          this.loading = true;
          this.errorMessageKey = null;
          this.bot = null;

          if (!language || !botName) {
            this.loading = false;
            this.errorMessageKey = 'botDetail.missing';
            return of<LocalizedBotDetails | null>(null);
          }

          this.language = language;

          return this.botService.getBotDetails({ botName, language }).pipe(
            catchError((error) => {
              console.error(this.translation.translate('botDetail.loadErrorLog') + ':', error);
              this.errorMessageKey = 'botDetail.error';
              return of<LocalizedBotDetails | null>(null);
            })
          );
        })
      )
      .subscribe((bot) => {
        this.bot = bot;
        this.loading = false;

        if (!bot) {
          this.errorMessageKey = this.errorMessageKey ?? 'botDetail.missing';
        }
      });
  }
}
