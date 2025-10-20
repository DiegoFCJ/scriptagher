import { Component, OnDestroy, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Subject, combineLatest, of } from 'rxjs';
import { catchError, filter, map, startWith, switchMap, takeUntil } from 'rxjs/operators';
import { NavigationEnd, Router } from '@angular/router';

import {
  BotConfiguration,
  BotService,
  InstallerAsset,
  LocalizedBotDetails,
  NormalizedBotSection
} from '../../services/bot.service';
import { TranslatePipe } from '../../core/i18n/translate.pipe';
import { TranslationService } from '../../core/i18n/translation.service';
import { BotSectionComponent } from '../bot-section/bot-section.component';
import { HeaderComponent } from '../header/header.component';
import { FooterComponent } from '../footer/footer.component';
import { InstallerSectionComponent } from '../installer-section/installer-section.component';

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
    FooterComponent,
    TranslatePipe
  ]
})
export class BotListComponent implements OnInit, OnDestroy {
  botSections: LocalizedBotSectionView[] = [];
  errorMessageKey: string | null = null;
  installerAssets: InstallerAsset[] = [];
  showHero: boolean = true;
  showInstallerSection: boolean = true;
  private readonly destroy$ = new Subject<void>();

  constructor(
    private botService: BotService,
    private translation: TranslationService,
    private router: Router
  ) {}

  ngOnInit() {
    this.updateLayoutForRoute(this.router.url);
    this.router.events
      .pipe(
        filter((event): event is NavigationEnd => event instanceof NavigationEnd),
        takeUntil(this.destroy$)
      )
      .subscribe((event) => this.updateLayoutForRoute(event.urlAfterRedirects));

    this.listenForInstallers();
    this.listenForBotSections();
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }

  private listenForInstallers(): void {
    this.botService.listInstallerAssets()
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (installers) => {
          this.installerAssets = installers ?? [];
        },
        error: (error) => {
          console.error(this.translation.translate('botList.installersLoadError') + ':', error);
        }
      });
  }

  private listenForBotSections(): void {
    const botsConfig$ = this.botService.getBotsConfig().pipe(
      catchError((error) => {
        console.error(this.translation.translate('botList.loadError') + ':', error);
        this.errorMessageKey = 'botList.loadError';
        return of<BotConfiguration>({ sections: {}, botsByLanguage: {} });
      })
    );

    combineLatest([
      botsConfig$,
      this.translation.language$.pipe(startWith(this.translation.language()))
    ])
      .pipe(
        switchMap(([config, language]) => this.buildSectionsStream(config, language)),
        takeUntil(this.destroy$)
      )
      .subscribe({
        next: (sections) => {
          this.botSections = sections;
          if (!sections.length) {
            this.errorMessageKey = this.errorMessageKey ?? 'botList.noBotsAvailable';
          } else {
            this.errorMessageKey = null;
          }
        },
        error: (error) => {
          console.error(this.translation.translate('botList.loadError') + ':', error);
          this.errorMessageKey = 'botList.loadError';
        }
      });
  }

  private buildSectionsStream(config: BotConfiguration, language: string) {
    const sectionEntries = Object.entries(config.sections ?? {});
    if (!sectionEntries.length) {
      return of<LocalizedBotSectionView[]>([]);
    }

    const streams = sectionEntries.map(([languageKey, section]) =>
      this.buildSectionStream(languageKey, section, config, language)
    );

    return streams.length
      ? combineLatest(streams).pipe(map((sections) => sections.filter((section) => section.bots.length)))
      : of<LocalizedBotSectionView[]>([]);
  }

  private buildSectionStream(
    languageKey: string,
    section: NormalizedBotSection,
    config: BotConfiguration,
    currentLanguage: string
  ) {
    const info = this.resolveSectionTranslations(languageKey, section, currentLanguage);
    const bots = (section.bots?.length ? section.bots : config.botsByLanguage[languageKey]) ?? [];

    if (!bots.length) {
      return of<LocalizedBotSectionView>({
        language: languageKey,
        title: info.title,
        summary: info.summary,
        bots: []
      });
    }

    const requests = bots.map((bot) => this.botService.getBotDetails({ ...bot, language: languageKey }));
    return combineLatest(requests).pipe(
      map((botDetails) => ({
        language: languageKey,
        title: info.title,
        summary: info.summary,
        bots: botDetails
      }))
    );
  }

  private resolveSectionTranslations(languageKey: string, section: NormalizedBotSection, currentLanguage: string) {
    const placeholder = '—';
    const translations = section.translations ?? {};
    const order = this.buildLanguageFallbackOrder(currentLanguage);

    let selectedTitle: string | undefined;
    let selectedSummary: string | undefined;

    for (const candidate of order) {
      const data = translations[candidate ?? ''];
      if (!data) {
        continue;
      }
      if (!selectedTitle && data.title) {
        selectedTitle = data.title;
      }
      if (!selectedSummary && data.summary) {
        selectedSummary = data.summary;
      }
      if (selectedTitle && selectedSummary) {
        break;
      }
    }

    const defaultTitle = this.translation.translate(`languages.${languageKey}.label`);

    return {
      title: selectedTitle || defaultTitle || languageKey,
      summary: selectedSummary || placeholder
    } satisfies SectionTranslationView;
  }

  private buildLanguageFallbackOrder(language: string): string[] {
    const order: string[] = [];
    if (language) {
      order.push(language);
    }

    const fallback = this.translation.fallbackLanguage;
    if (fallback && !order.includes(fallback)) {
      order.push(fallback);
    }

    if (!order.includes('en')) {
      order.push('en');
    }

    return order;
  }

  private updateLayoutForRoute(url: string): void {
    const normalizedUrl = this.normalizeUrl(url);
    const isHomePage = normalizedUrl === '' || normalizedUrl === '/';
    this.showHero = isHomePage;
    this.showInstallerSection = isHomePage;
  }

  private normalizeUrl(url: string): string {
    const [pathWithQuery] = url.split('#');
    const [path] = pathWithQuery.split('?');
    return path;
  }
}

interface LocalizedBotSectionView {
  language: string;
  title: string;
  summary: string;
  bots: LocalizedBotDetails[];
}

interface SectionTranslationView {
  title: string;
  summary: string;
}