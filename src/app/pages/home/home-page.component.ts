import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { RouterLink } from '@angular/router';
import { Subject, takeUntil } from 'rxjs';

import { HeaderComponent } from '../../components/header/header.component';
import { FooterComponent } from '../../components/footer/footer.component';
import { InstallerSectionComponent } from '../../components/installer-section/installer-section.component';
import { TranslatePipe } from '../../core/i18n/translate.pipe';
import { TranslationService } from '../../core/i18n/translation.service';
import { BotService, InstallerAsset } from '../../services/bot.service';

interface HomeFeatureCard {
  titleKey: string;
  descriptionKey: string;
}

@Component({
  selector: 'app-home-page',
  standalone: true,
  imports: [
    CommonModule,
    RouterLink,
    HeaderComponent,
    FooterComponent,
    TranslatePipe,
    InstallerSectionComponent
  ],
  templateUrl: './home-page.component.html',
  styleUrls: ['./home-page.component.scss']
})
export class HomePageComponent implements OnInit, OnDestroy {
  readonly featureCards: HomeFeatureCard[] = [
    {
      titleKey: 'home.features.automation.title',
      descriptionKey: 'home.features.automation.description'
    },
    {
      titleKey: 'home.features.localization.title',
      descriptionKey: 'home.features.localization.description'
    },
    {
      titleKey: 'home.features.trust.title',
      descriptionKey: 'home.features.trust.description'
    }
  ];
  installers: InstallerAsset[] = [];
  loadingInstallers = true;
  installersErrorKey: string | null = null;

  private readonly destroy$ = new Subject<void>();

  constructor(private botService: BotService, private translation: TranslationService) {}

  ngOnInit(): void {
    this.botService
      .listInstallerAssets()
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (installers) => {
          this.installers = (installers ?? []).slice(0, 3);
          this.loadingInstallers = false;
        },
        error: (error) => {
          console.error(this.translation.translate('botList.installersLoadError') + ':', error);
          this.installers = [];
          this.loadingInstallers = false;
          this.installersErrorKey = 'botList.installersLoadError';
        }
      });
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }
}
