import { Injectable } from '@angular/core';
import { BehaviorSubject } from 'rxjs';

export interface UiStrings {
  viewSourceLabel: string;
  downloadLabel: string;
  startCommandLabel: string;
  noDescriptionFallback: string;
  noStartCommandFallback: string;
  pdfCtaLabel: string;
  botsLabel: string;
  genericErrorTitle: string;
  genericErrorMessage: string;
  missingValueFallback: string;
}

@Injectable({
  providedIn: 'root'
})
export class I18nService {
  private readonly defaultLanguage = 'it';
  private readonly fallbackLanguages = ['it', 'en'];
  private readonly language$Subject = new BehaviorSubject<string>(this.defaultLanguage);

  readonly language$ = this.language$Subject.asObservable();

  private readonly uiTranslations: Record<string, Partial<UiStrings>> = {
    it: {
      viewSourceLabel: 'Vedi sorgente',
      downloadLabel: 'Scarica',
      startCommandLabel: 'Comando di avvio',
      noDescriptionFallback: 'Descrizione non disponibile',
      noStartCommandFallback: 'Nessun comando disponibile',
      pdfCtaLabel: 'Vai al convertitore PDF in TXT',
      botsLabel: 'Bot',
      genericErrorTitle: 'Ops, qualcosa è andato storto.',
      genericErrorMessage: 'Nessun bot disponibile.',
      missingValueFallback: '—'
    },
    en: {
      viewSourceLabel: 'View source',
      downloadLabel: 'Download',
      startCommandLabel: 'Start command',
      noDescriptionFallback: 'No description available',
      noStartCommandFallback: 'No start commands provided',
      pdfCtaLabel: 'Go to the PDF to TXT converter',
      botsLabel: 'Bots',
      genericErrorTitle: 'Oops, something went wrong.',
      genericErrorMessage: 'No bots available.',
      missingValueFallback: '—'
    }
  };

  setLanguage(language: string): void {
    const normalized = this.normalizeLanguage(language);
    if (normalized && normalized !== this.language$Subject.value) {
      this.language$Subject.next(normalized);
    }
  }

  getCurrentLanguage(): string {
    return this.language$Subject.value;
  }

  getFallbackLanguages(preferred?: string): string[] {
    const normalized = this.normalizeLanguage(preferred ?? this.getCurrentLanguage());
    const chain = [normalized, ...this.fallbackLanguages];
    const unique: string[] = [];
    for (const lang of chain) {
      if (!lang) {
        continue;
      }
      if (!unique.includes(lang)) {
        unique.push(lang);
      }
    }
    return unique;
  }

  getUiStrings(language?: string): UiStrings {
    const defaults: UiStrings = {
      viewSourceLabel: 'View source',
      downloadLabel: 'Download',
      startCommandLabel: 'Start command',
      noDescriptionFallback: 'No description available',
      noStartCommandFallback: 'No start commands provided',
      pdfCtaLabel: 'Go to the PDF to TXT converter',
      botsLabel: 'Bots',
      genericErrorTitle: 'Oops, something went wrong.',
      genericErrorMessage: 'No bots available.',
      missingValueFallback: '—'
    };

    const chain = this.getFallbackLanguages(language);
    for (let i = chain.length - 1; i >= 0; i--) {
      const lang = chain[i];
      const translations = this.uiTranslations[lang];
      if (!translations) {
        continue;
      }
      Object.assign(defaults, translations);
    }

    return defaults;
  }

  private normalizeLanguage(language: string | undefined | null): string {
    if (!language) {
      return this.defaultLanguage;
    }
    return language.toLowerCase().split('-')[0] || this.defaultLanguage;
  }
}
