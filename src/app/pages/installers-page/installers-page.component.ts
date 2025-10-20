import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { Subject } from 'rxjs';
import { takeUntil } from 'rxjs/operators';

import { InstallerAsset, BotService } from '../../services/bot.service';
import { HeaderComponent } from '../../components/header/header.component';
import { FooterComponent } from '../../components/footer/footer.component';
import { InstallerSectionComponent } from '../../components/installer-section/installer-section.component';
import { TranslatePipe } from '../../core/i18n/translate.pipe';
import { TranslationService } from '../../core/i18n/translation.service';

@Component({
  selector: 'app-installers-page',
  standalone: true,
  imports: [
    CommonModule,
    HeaderComponent,
    InstallerSectionComponent,
    FooterComponent,
    TranslatePipe
  ],
  templateUrl: './installers-page.component.html',
  styleUrls: ['./installers-page.component.scss']
})
export class InstallersPageComponent implements OnInit, OnDestroy {
  installers: InstallerAsset[] = [];
  loading = true;
  errorMessageKey: string | null = null;
  private readonly destroy$ = new Subject<void>();

  constructor(private readonly botService: BotService, private readonly translation: TranslationService) {}

  ngOnInit(): void {
    this.loadInstallers();
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }

  private loadInstallers(): void {
    this.botService
      .listInstallerAssets()
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (installers) => {
          this.installers = installers ?? [];
          this.loading = false;
          this.errorMessageKey = this.installers.length ? null : 'installersPage.empty';
        },
        error: (error) => {
          console.error(this.translation.translate('botList.installersLoadError') + ':', error);
          this.installers = [];
          this.loading = false;
          this.errorMessageKey = 'installersPage.error';
        }
      });
  }
}
