import { ChangeDetectorRef, Pipe, PipeTransform, effect, inject } from '@angular/core';
import { TranslationParams, TranslationService } from './translation.service';

@Pipe({
  name: 'translate',
  standalone: true,
  pure: false,
})
export class TranslatePipe implements PipeTransform {
  private readonly translationService = inject(TranslationService);
  private readonly cdr = inject(ChangeDetectorRef);

  constructor() {
    effect(() => {
      this.translationService.language();
      this.cdr.markForCheck();
    });
  }

  transform(key: string | null | undefined, params?: TranslationParams): string {
    if (!key) {
      return '';
    }
    return this.translationService.translate(key, params);
  }
}
