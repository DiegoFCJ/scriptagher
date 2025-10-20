import { CommonModule } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { Component, OnInit, inject, signal } from '@angular/core';

@Component({
  selector: 'app-license',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './license.component.html',
  styleUrls: ['./license.component.scss']
})
export class LicenseComponent implements OnInit {
  private readonly http = inject(HttpClient);

  protected readonly licenseText = signal<string>('');
  protected readonly isLoading = signal<boolean>(true);
  protected readonly errorMessage = signal<string | null>(null);

  ngOnInit(): void {
    this.http.get('/LICENSE', { responseType: 'text' }).subscribe({
      next: (text) => {
        this.licenseText.set(text);
        this.isLoading.set(false);
      },
      error: () => {
        this.errorMessage.set('Impossibile caricare la licenza. Riprova più tardi.');
        this.isLoading.set(false);
      }
    });
  }
}
