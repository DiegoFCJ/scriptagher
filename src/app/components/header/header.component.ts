import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { Router, NavigationEnd } from '@angular/router';
import { filter } from 'rxjs/operators';
import { Subscription } from 'rxjs';

@Component({
  selector: 'app-header',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './header.component.html',
  styleUrls: ['./header.component.scss']
})
export class HeaderComponent implements OnInit, OnDestroy {
  isPdfToTxtPage: boolean = false;
  private readonly pdfRouteExists: boolean;
  private navigationSubscription?: Subscription;

  constructor(private router: Router) {
    this.pdfRouteExists = this.router.config.some(route => route.path === 'pdf-to-txt');
  }

  ngOnInit(): void {
    // Allinea lo stato anche con ricariche dirette.
    this.evaluateCurrentRoute(this.router.url);

    this.navigationSubscription = this.router.events
      .pipe(filter((event): event is NavigationEnd => event instanceof NavigationEnd))
      .subscribe(event => this.evaluateCurrentRoute(event.urlAfterRedirects));
  }

  ngOnDestroy(): void {
    this.navigationSubscription?.unsubscribe();
  }

  navigateHome(): void {
    this.router.navigate(['/']);
  }

  private evaluateCurrentRoute(url: string): void {
    if (!this.pdfRouteExists) {
      this.isPdfToTxtPage = false;
      return;
    }

    this.isPdfToTxtPage = url.startsWith('/pdf-to-txt');
  }
}
