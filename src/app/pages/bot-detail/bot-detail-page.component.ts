import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { ActivatedRoute, RouterModule } from '@angular/router';
import { Subject, of, throwError } from 'rxjs';
import { catchError, map, switchMap, take, takeUntil } from 'rxjs/operators';

import { BotService, BotSummary, LocalizedBotDetails } from '../../services/bot.service';
import { HeaderComponent } from '../../components/header/header.component';
import { FooterComponent } from '../../components/footer/footer.component';
import { TranslatePipe } from '../../core/i18n/translate.pipe';
import { TranslationService } from '../../core/i18n/translation.service';

interface BotActionEntry {
  key: string;
  value: string;
}

@Component({
  selector: 'app-bot-detail-page',
  standalone: true,
  imports: [CommonModule, RouterModule, HeaderComponent, FooterComponent, TranslatePipe],
  templateUrl: './bot-detail-page.component.html',
  styleUrls: ['./bot-detail-page.component.scss']
})
export class BotDetailPageComponent implements OnInit, OnDestroy {
  detail: LocalizedBotDetails | null = null;
  actionEntries: BotActionEntry[] = [];
  loading = true;
  errorKey: string | null = null;

  private readonly destroy$ = new Subject<void>();

  constructor(
    private readonly route: ActivatedRoute,
    private readonly botService: BotService,
    private readonly translation: TranslationService
  ) {}

  ngOnInit(): void {
    this.route.paramMap
      .pipe(takeUntil(this.destroy$))
      .subscribe((params) => {
        const language = params.get('language');
        const botName = params.get('botName');

        if (!language || !botName) {
          this.setError('botDetail.missingParams');
          return;
        }

        this.fetchBotDetail(language, botName);
      });
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }

  downloadBot(): void {
    if (!this.detail) {
      return;
    }

    this.botService
      .downloadBot(this.detail)
      .pipe(take(1))
      .subscribe({
        next: (blob) => {
          const link = document.createElement('a');
          link.href = window.URL.createObjectURL(blob);
          link.download = `${this.detail!.botName}.zip`;
          link.click();
        },
        error: (error) => {
          console.error(this.translation.translate('botSection.downloadErrorLog') + ':', error);
          alert(this.translation.translate('botSection.downloadErrorAlert'));
        }
      });
  }

  openSource(): void {
    if (!this.detail?.sourceUrl) {
      return;
    }

    this.botService.openBot(this.detail);
  }

  private fetchBotDetail(language: string, botName: string): void {
    this.loading = true;
    this.errorKey = null;

    this.botService
      .getBotsConfig()
      .pipe(
        take(1),
        map((config) => this.resolveSummary(config.botsByLanguage[language], language, botName)),
        switchMap((summary) => {
          if (!summary) {
            return throwError(() => new Error('notFound'));
          }

          return this.botService.getBotDetails(summary);
        }),
        catchError((error) => {
          const isNotFound = error instanceof Error && error.message === 'notFound';
          const translationKey = isNotFound ? 'botDetail.notFound' : 'botDetail.loadError';
          this.setError(translationKey, !isNotFound ? error : undefined);
          return of<LocalizedBotDetails | null>(null);
        })
      )
      .subscribe((detail) => {
        this.detail = detail;
        this.loading = false;

        if (!detail) {
          this.actionEntries = [];
          return;
        }

        this.actionEntries = Object.entries(detail.actions ?? {}).map(([key, value]) => ({
          key,
          value
        }));
      });
  }

  private resolveSummary(
    bots: BotSummary[] | undefined,
    language: string,
    botName: string
  ): BotSummary | null {
    const summary = bots?.find((bot) => bot.botName === botName);
    if (summary) {
      return summary;
    }

    return null;
  }

  private setError(key: string, error?: unknown): void {
    if (error) {
      console.error(this.translation.translate('botDetail.loadErrorLog') + ':', error);
    }

    this.loading = false;
    this.errorKey = key;
    this.detail = null;
    this.actionEntries = [];
  }
}
