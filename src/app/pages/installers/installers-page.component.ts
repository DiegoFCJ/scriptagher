import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { Subject, of } from 'rxjs';
import { catchError, takeUntil } from 'rxjs/operators';

import { InstallerAsset, BotService } from '../../services/bot.service';
import { HeaderComponent } from '../../components/header/header.component';
import { FooterComponent } from '../../components/footer/footer.component';
import { InstallerSectionComponent } from '../../components/installer-section/installer-section.component';
import { TranslatePipe } from '../../core/i18n/translate.pipe';

@Component({
  selector: 'app-installers-page',
  standalone: true,
  imports: [CommonModule, HeaderComponent, FooterComponent, InstallerSectionComponent, TranslatePipe],
  templateUrl: './installers-page.component.html',
  styleUrls: ['./installers-page.component.scss']
})
export class InstallersPageComponent implements OnInit, OnDestroy {
  installers: InstallerAsset[] = [];
  loading = true;
  errorKey: string | null = null;

  private readonly destroy$ = new Subject<void>();

  constructor(private botService: BotService) {}

  ngOnInit(): void {
    this.botService
      .listInstallerAssets()
      .pipe(
        takeUntil(this.destroy$),
        catchError((error) => {
          console.error('Failed to load installers', error);
          this.errorKey = 'installers.error';
          this.loading = false;
          return of<InstallerAsset[]>([]);
        })
      )
      .subscribe((installers) => {
        this.installers = installers ?? [];
        this.loading = false;
        if (!this.installers.length && !this.errorKey) {
          this.errorKey = 'installers.empty';
        }
      });
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }
}
