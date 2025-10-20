import { CommonModule } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { Component, OnInit } from '@angular/core';
import { finalize } from 'rxjs/operators';

import { TranslatePipe } from '../../../core/i18n/translate.pipe';

@Component({
  selector: 'app-license',
  standalone: true,
  imports: [CommonModule, TranslatePipe],
  templateUrl: './license.component.html',
  styleUrls: ['./license.component.scss']
})
export class LicenseComponent implements OnInit {
  protected licenseText = '';
  protected isLoading = true;
  protected hasError = false;

  constructor(private readonly http: HttpClient) {}

  ngOnInit(): void {
    this.http
      .get('/LICENSE', { responseType: 'text' })
      .pipe(
        finalize(() => {
          this.isLoading = false;
        })
      )
      .subscribe({
        next: text => {
          this.licenseText = text;
        },
        error: () => {
          this.hasError = true;
        }
      });
  }
}
