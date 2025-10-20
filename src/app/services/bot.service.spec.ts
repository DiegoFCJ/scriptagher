import { TestBed, fakeAsync, tick } from '@angular/core/testing';
import { HttpClientTestingModule, HttpTestingController } from '@angular/common/http/testing';
import { APP_BASE_HREF } from '@angular/common';
import { PLATFORM_ID } from '@angular/core';
import { firstValueFrom, take } from 'rxjs';

import { BotService, LocalizedBotDetails } from './bot.service';
import { TranslationService } from '../core/i18n/translation.service';
import { provideBotConfig } from './bot-config';

describe('BotService localization', () => {
  let service: BotService;
  let httpMock: HttpTestingController;
  let translations: TranslationService;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [HttpClientTestingModule],
      providers: [
        BotService,
        TranslationService,
        { provide: PLATFORM_ID, useValue: 'server' },
        { provide: APP_BASE_HREF, useValue: '/' },
        provideBotConfig({ githubRepoOwner: 'test-owner', githubRepoName: 'test-repo' })
      ]
    });

    service = TestBed.inject(BotService);
    httpMock = TestBed.inject(HttpTestingController);
    translations = TestBed.inject(TranslationService);
  });

  afterEach(() => {
    httpMock.verify();
  });

  it('normalizes bot configuration including section translations', async () => {
    const configPromise = firstValueFrom(service.getBotsConfig());

    const request = httpMock.expectOne((req) => req.url.endsWith('/bots/bots.json'));
    request.flush({
      sections: {
        python: {
          translations: {
            it: { title: 'Bot Python', summary: 'Sezione italiana' },
            en: { title: 'Python Bots', summary: 'English section' }
          },
          bots: [{ botName: 'Zipper', path: 'Zipper.zip' }]
        }
      },
      python: [{ botName: 'Zipper', path: 'Zipper.zip' }]
    });

    const config = await configPromise;

    expect(Object.keys(config.sections)).toContain('python');
    expect(config.sections['python'].translations['it']?.title).toBe('Bot Python');
    expect(config.sections['python'].bots.length).toBe(1);
    expect(config.botsByLanguage['python'].length).toBe(1);
  });

  it('merges bot translations and reacts to language changes', fakeAsync(() => {
    const results: LocalizedBotDetails[] = [];
    const subscription = service
      .getBotDetails({ botName: 'Zipper', path: 'Zipper.zip', language: 'python' })
      .subscribe((value) => results.push(value));

    const repoRequest = httpMock.expectOne((req) => req.url === 'https://api.github.com/repos/test-owner/test-repo');
    repoRequest.flush({ private: false });

    const request = httpMock.expectOne((req) => req.url.endsWith('/bots/python/Zipper/Bot.json'));
    request.flush({
      botName: 'Zipper',
      startCommand: 'python3 bots/python/Zipper/Zipper.py',
      sourceUrl: 'https://example.com/zipper',
      translations: {
        it: { displayName: 'Zipper IT', shortDescription: 'Descrizione IT' },
        en: { displayName: 'Zipper EN', shortDescription: 'English description' }
      }
    });

    tick();
    expect(results[0].displayName).toBe('Zipper IT');
    expect(results[0].shortDescription).toBe('Descrizione IT');
    expect(results[0].sourceUrl).toBe('https://example.com/zipper');

    translations.changeLanguage('en');
    tick();

    expect(results[results.length - 1].displayName).toBe('Zipper EN');
    expect(results[results.length - 1].shortDescription).toBe('English description');
    expect(results[results.length - 1].sourceUrl).toBe('https://example.com/zipper');

    subscription.unsubscribe();
  }));

  it('removes the source URL when the repository is private', fakeAsync(() => {
    const results: LocalizedBotDetails[] = [];
    const subscription = service
      .getBotDetails({ botName: 'Hidden', path: 'Hidden.zip', language: 'python' })
      .subscribe((value) => results.push(value));

    const repoRequest = httpMock.expectOne((req) => req.url === 'https://api.github.com/repos/test-owner/test-repo');
    repoRequest.flush({ private: true });

    const request = httpMock.expectOne((req) => req.url.endsWith('/bots/python/Hidden/Bot.json'));
    request.flush({
      botName: 'Hidden',
      sourceUrl: 'https://example.com/hidden',
      translations: {
        it: { displayName: 'Hidden IT', shortDescription: 'Descrizione nascosta' }
      }
    });

    tick();

    expect(results[0].sourceUrl).toBeUndefined();

    subscription.unsubscribe();
  }));

  it('falls back to English translations when Italian content is missing', async () => {
    translations.changeLanguage('no');

    const details$ = service.getBotDetails({ botName: 'Fallback', language: 'python' });
    const valuePromise = firstValueFrom(details$.pipe(take(1)));
    const repoRequest = httpMock.expectOne((req) => req.url === 'https://api.github.com/repos/test-owner/test-repo');
    repoRequest.flush({ private: false });
    const request = httpMock.expectOne((req) => req.url.endsWith('/bots/python/Fallback/Bot.json'));
    request.flush({
      botName: 'Fallback',
      translations: {
        en: { displayName: 'Fallback EN', shortDescription: 'English only description' }
      }
    });

    const value = await valuePromise;

    expect(value.displayName).toBe('Fallback EN');
    expect(value.shortDescription).toBe('English only description');
    expect(value.sourceUrl).toBeUndefined();
  });
});
