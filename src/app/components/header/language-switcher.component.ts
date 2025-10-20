import { CommonModule } from '@angular/common';
import { Component, computed, inject } from '@angular/core';
import { TranslatePipe } from '../../core/i18n/translate.pipe';
import { TranslationService } from '../../core/i18n/translation.service';

@Component({
  selector: 'app-language-switcher',
  standalone: true,
  imports: [CommonModule, TranslatePipe],
  templateUrl: './language-switcher.component.html',
  styleUrls: ['./language-switcher.component.scss'],
})
export class LanguageSwitcherComponent {
  private readonly translationService = inject(TranslationService);

  readonly languages = this.translationService.supportedLanguages;
  readonly currentLanguage = computed(() => this.translationService.language());

  onLanguageChange(language: string): void {
    this.translationService.changeLanguage(language);
  }
}
