import { CommonModule, DOCUMENT } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { Component, Inject, OnInit } from '@angular/core';
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

  private readonly baseHref: string;

  constructor(
    private readonly http: HttpClient,
    @Inject(DOCUMENT) private readonly document: Document
  ) {
    const baseElement = this.document?.querySelector?.('base');
    this.baseHref = baseElement?.href ?? this.document?.baseURI ?? '/';
  }

  ngOnInit(): void {
    const licenseUrl = new URL('LICENSE', this.baseHref).toString();

    this.http
      .get(licenseUrl, { responseType: 'text' })
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
