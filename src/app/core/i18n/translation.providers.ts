import { APP_INITIALIZER, EnvironmentProviders, makeEnvironmentProviders } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { forkJoin, lastValueFrom, map, of } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { TranslationDictionaries, TranslationService } from './translation.service';

function loadDictionaries(
  translationService: TranslationService,
  http: HttpClient
): () => Promise<void> {
  return async () => {
    const requests = translationService.supportedLanguages.map((language) =>
      http
        .get<Record<string, string>>(`assets/i18n/${language}.json`)
        .pipe(catchError(() => of({})))
    );

    const dictionaries$ = forkJoin(requests).pipe(
      map((results) => {
        return results.reduce<TranslationDictionaries>((acc, dictionary, index) => {
          const language = translationService.supportedLanguages[index];
          acc[language] = dictionary ?? {};
          return acc;
        }, {});
      })
    );

    const dictionaries = await lastValueFrom(dictionaries$);
    translationService.setDictionaries(dictionaries);
  };
}

export function provideTranslations(): EnvironmentProviders {
  return makeEnvironmentProviders([
    {
      provide: APP_INITIALIZER,
      multi: true,
      useFactory: loadDictionaries,
      deps: [TranslationService, HttpClient],
    },
  ]);
}
