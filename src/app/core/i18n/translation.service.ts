import { Injectable, Signal, computed, inject, signal } from '@angular/core';
import { isPlatformBrowser } from '@angular/common';
import { PLATFORM_ID } from '@angular/core';
import { toObservable } from '@angular/core/rxjs-interop';
import { Observable } from 'rxjs';

export type TranslationDictionaries = Record<string, Record<string, string>>;
export type TranslationParams = Record<string, string | number | boolean>;

type SupportedLanguage = 'it' | 'en' | 'no' | 'de' | 'ru' | 'es';

@Injectable({ providedIn: 'root' })
export class TranslationService {
  readonly supportedLanguages: SupportedLanguage[] = ['it', 'en', 'no', 'de', 'ru', 'es'];
  readonly fallbackLanguage: SupportedLanguage = 'it';
  private readonly storageKey = 'scriptagher.language';
  private readonly platformId = inject(PLATFORM_ID);

  private readonly dictionaries = signal<TranslationDictionaries>({});
  private readonly currentLanguageSignal = signal<SupportedLanguage>(this.fallbackLanguage);

  readonly language: Signal<SupportedLanguage> = computed(() => this.currentLanguageSignal());
  readonly language$ = toObservable(this.currentLanguageSignal) as Observable<SupportedLanguage>;

  constructor() {
    const stored = this.getStoredLanguage();
    if (stored && this.isSupported(stored)) {
      this.currentLanguageSignal.set(stored);
    }
  }

  setDictionaries(dictionaries: TranslationDictionaries): void {
    this.dictionaries.set(dictionaries);
  }

  translate(key: string, params?: TranslationParams): string {
    const language = this.currentLanguageSignal();
    const activeDictionary = this.dictionaries()[language] ?? {};
    const fallbackDictionary = this.dictionaries()[this.fallbackLanguage] ?? {};

    let template = activeDictionary[key] ?? fallbackDictionary[key] ?? key;
    if (!params || !template) {
      return template;
    }

    return template.replace(/{{\s*(\w+)\s*}}/g, (_match, paramKey: string) => {
      if (params[paramKey] === undefined || params[paramKey] === null) {
        return '';
      }
      return String(params[paramKey]);
    });
  }

  changeLanguage(language: string): void {
    if (!this.isSupported(language)) {
      return;
    }
    const normalized = language as SupportedLanguage;
    this.currentLanguageSignal.set(normalized);
    this.storeLanguage(normalized);
  }

  getDictionary(language: string): Record<string, string> | undefined {
    return this.dictionaries()[language];
  }

  private isSupported(language: string | null | undefined): language is SupportedLanguage {
    return !!language && this.supportedLanguages.includes(language as SupportedLanguage);
  }

  private getStoredLanguage(): SupportedLanguage | null {
    if (!isPlatformBrowser(this.platformId)) {
      return null;
    }
    try {
      const stored = window.localStorage.getItem(this.storageKey);
      return this.isSupported(stored) ? (stored as SupportedLanguage) : null;
    } catch {
      return null;
    }
  }

  private storeLanguage(language: SupportedLanguage): void {
    if (!isPlatformBrowser(this.platformId)) {
      return;
    }
    try {
      window.localStorage.setItem(this.storageKey, language);
    } catch {
      // Ignore storage errors
    }
  }
}
