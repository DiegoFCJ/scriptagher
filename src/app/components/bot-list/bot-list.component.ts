import { Component, OnDestroy, OnInit } from '@angular/core';
import {
  BotService,
  BotDetails,
  BotSummary,
  BotsConfiguration,
  InstallerAsset,
  SectionTranslation
} from '../../services/bot.service';
import { CommonModule } from '@angular/common';
import { BotSectionComponent } from '../bot-section/bot-section.component';
import { HeaderComponent } from '../header/header.component';
import { FooterComponent } from '../footer/footer.component';
import { InstallerSectionComponent } from '../installer-section/installer-section.component';
import { Subscription, firstValueFrom, forkJoin } from 'rxjs';
import { I18nService, UiStrings } from '../../services/i18n.service';

interface BotSectionView {
  language: string;
  languageLabel: string;
  title: string;
  summary?: string;
  botDetails: BotDetails[];
}

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
    FooterComponent
  ]
})
export class BotListComponent implements OnInit, OnDestroy {
  botSections: BotSectionView[] = [];
  errorMessage: string = '';
  installerAssets: InstallerAsset[] = [];
  uiText: UiStrings;

  private botsConfiguration?: BotsConfiguration;
  private languageSubscription?: Subscription;

  constructor(private botService: BotService, private readonly i18nService: I18nService) {
    this.uiText = this.i18nService.getUiStrings();
  }

  ngOnInit() {
    this.languageSubscription = this.i18nService.language$.subscribe(() => {
      this.uiText = this.i18nService.getUiStrings();
      if (this.errorMessage) {
        this.errorMessage = this.uiText.genericErrorMessage;
      }
      if (this.botsConfiguration) {
        this.rebuildBotSections().catch((error) =>
          console.error('Error rebuilding bot sections after language change', error)
        );
      }
    });

    this.populateBotList();
  }

  ngOnDestroy(): void {
    this.languageSubscription?.unsubscribe();
  }

  populateBotList() {
    forkJoin({
      botsConfig: this.botService.getBotsConfig(),
      installers: this.botService.listInstallerAssets()
    }).subscribe({
      next: ({ botsConfig, installers }) => {
        this.botSections = [];
        this.botsConfiguration = botsConfig;
        this.installerAssets = installers ?? [];
        this.rebuildBotSections().catch((error) =>
          console.error('Error building bot sections', error)
        );
      },
      error: (err) => {
        console.error('Error fetching bots configuration:', err);
        this.errorMessage = this.uiText.genericErrorMessage;
      },
    });
  }

  private async rebuildBotSections(): Promise<void> {
    if (!this.botsConfiguration) {
      this.botSections = [];
      return;
    }

    const sections: BotSectionView[] = [];
    const botsByLanguage = this.botsConfiguration.bots ?? {};
    const fallbackChain = this.i18nService.getFallbackLanguages();

    for (const language of Object.keys(botsByLanguage)) {
      const bots = botsByLanguage[language];
      if (!Array.isArray(bots) || bots.length === 0) {
        continue;
      }

      const translation = this.pickSectionTranslation(
        this.botsConfiguration.sections?.[language]?.translations,
        fallbackChain
      );

      const title = translation?.title ?? this.buildDefaultSectionTitle(language);
      const summary = translation?.summary;

      const botDetails = await Promise.all(
        bots.map(async (bot: BotSummary) => {
          try {
            const details = await firstValueFrom(
              this.botService.getBotDetails({ ...bot, language })
            );
            details.language = language;
            details.path = details.path ?? bot.path;
            return details;
          } catch (error) {
            console.error(`Error loading details for bot ${bot?.botName}`, error);
            return this.createFallbackBot(language, bot);
          }
        })
      );

      sections.push({
        language,
        languageLabel: language.toUpperCase(),
        title,
        summary,
        botDetails
      });
    }

    this.botSections = sections;
  }

  private pickSectionTranslation(
    translations: Record<string, SectionTranslation> | undefined,
    fallbackChain: string[]
  ): SectionTranslation | undefined {
    if (!translations) {
      return undefined;
    }
    for (const language of fallbackChain) {
      const translation = translations[language];
      if (translation) {
        return translation;
      }
    }
    return undefined;
  }

  private buildDefaultSectionTitle(language: string): string {
    if (!language) {
      return this.uiText.botsLabel;
    }
    const capitalized = language.charAt(0).toUpperCase() + language.slice(1);
    return `${capitalized} ${this.uiText.botsLabel}`.trim();
  }

  private createFallbackBot(language: string, bot: BotSummary): BotDetails {
    const uiText = this.uiText;
    const botName = bot?.botName ?? uiText.missingValueFallback;
    const description = bot?.description ?? uiText.noDescriptionFallback;
    return {
      ...bot,
      language,
      botName,
      displayName: botName,
      description,
      shortDescription: bot?.shortDescription ?? description,
      startCommand: bot?.startCommand ?? '',
    };
  }
}