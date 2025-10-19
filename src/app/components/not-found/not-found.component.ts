import { Component } from '@angular/core';
import { Router } from '@angular/router';

import { TranslatePipe } from '../../core/i18n/translate.pipe';

@Component({
  selector: 'app-not-found',
  standalone: true,
  imports: [TranslatePipe],
  templateUrl: './not-found.component.html',
  styleUrls: ['./not-found.component.scss']
})
export class NotFoundComponent {

  constructor(private router: Router) {
  }
  navigateHome() {
    this.router.navigate(['/']);
  }
}
