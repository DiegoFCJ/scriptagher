import { CommonModule } from '@angular/common';
import { Component, Input } from '@angular/core';
import { Router, NavigationEnd } from '@angular/router';
import { filter } from 'rxjs/operators';

@Component({
  selector: 'app-header',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './header.component.html',
  styleUrls: ['./header.component.scss']
})
export class HeaderComponent {
  isPdfToTxtPage: boolean = false;

  constructor(private router: Router) {
    // Ascolta il router per sapere se siamo nella pagina PDF to Txt
    this.router.events
      .pipe(filter(event => event instanceof NavigationEnd))
      .subscribe((event: NavigationEnd) => {
        this.isPdfToTxtPage = event.url === '/pdf-to-txt';
      });
  }

  navigateHome() {
    this.router.navigate(['/']);
  }

  navigateConverterPage() {
    this.router.navigate(['pdf-to-txt']);
  }
}
