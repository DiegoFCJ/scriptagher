import { CommonModule, DOCUMENT } from '@angular/common';
import { Component, Inject, OnDestroy, OnInit } from '@angular/core';
import { NavigationEnd, Router, RouterModule } from '@angular/router';
import { Subscription } from 'rxjs';
import { filter } from 'rxjs/operators';

import { TranslatePipe } from '../../core/i18n/translate.pipe';
import { LanguageSwitcherComponent } from './language-switcher.component';

@Component({
  selector: 'app-header',
  standalone: true,
  imports: [CommonModule, RouterModule, TranslatePipe, LanguageSwitcherComponent],
  templateUrl: './header.component.html',
  styleUrls: ['./header.component.scss']
})
export class HeaderComponent implements OnInit, OnDestroy {
  isPdfToTxtPage = false;
  isHomePage = false;
  isBotsPage = false;
  private readonly pdfRouteExists: boolean;
  private navigationSubscription?: Subscription;

  constructor(
    private readonly router: Router,
    @Inject(DOCUMENT) private readonly document: Document | null
  ) {
    this.pdfRouteExists = this.router.config.some((route) => route.path === 'pdf-to-txt');
  }

  ngOnInit(): void {
    this.evaluateCurrentRoute(this.router.url);

    this.navigationSubscription = this.router.events
      .pipe(filter((event): event is NavigationEnd => event instanceof NavigationEnd))
      .subscribe((event) => this.evaluateCurrentRoute(event.urlAfterRedirects));
  }

  ngOnDestroy(): void {
    this.navigationSubscription?.unsubscribe();
  }

  navigateHome(): void {
    this.router.navigate(['/']);
  }

  handleExploreBots(): void {
    if ((this.isHomePage || this.isBotsPage) && this.scrollToBotsSection()) {
      return;
    }

    this.router.navigate(['/bots']);
  }

  private evaluateCurrentRoute(url: string): void {
    if (!this.pdfRouteExists) {
      this.isPdfToTxtPage = false;
    } else {
      this.isPdfToTxtPage = url.startsWith('/pdf-to-txt');
    }

    this.isHomePage = url === '/' || url.startsWith('/?') || url.startsWith('/#');
    this.isBotsPage = url.startsWith('/bots');
  }

  private scrollToBotsSection(): boolean {
    if (!this.document) {
      return false;
    }

    const target = this.document.getElementById('bots');
    if (!target) {
      return false;
    }

    target.scrollIntoView({ behavior: 'smooth', block: 'start' });
    return true;
  }
}
