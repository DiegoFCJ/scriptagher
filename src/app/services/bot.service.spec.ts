import { TestBed } from '@angular/core/testing';
import { HttpClientTestingModule, HttpTestingController } from '@angular/common/http/testing';
import { BotDetails, BotService, BotsConfiguration } from './bot.service';
import { APP_BASE_HREF } from '@angular/common';
import { I18nService } from './i18n.service';

describe('BotService', () => {
  let service: BotService;
  let httpMock: HttpTestingController;
  let i18n: I18nService;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [HttpClientTestingModule],
      providers: [{ provide: APP_BASE_HREF, useValue: '/' }]
    });

    service = TestBed.inject(BotService);
    httpMock = TestBed.inject(HttpTestingController);
    i18n = TestBed.inject(I18nService);
  });

  afterEach(() => {
    httpMock.verify();
  });

  it('should normalize bots configuration with section translations', () => {
    let config: BotsConfiguration | undefined;

    service.getBotsConfig().subscribe((value) => {
      config = value;
    });

    const request = httpMock.expectOne((req) => req.url.includes('bots.json'));
    request.flush({
      sections: {
        python: {
          translations: {
            EN: {
              title: 'Python Bots',
              summary: 'Summary'
            }
          }
        }
      },
      python: [
        { botName: 'Zipper', path: 'Zipper.zip' }
      ]
    });

    expect(config).toBeDefined();
    expect(config?.sections['python'].translations['en'].title).toBe('Python Bots');
    expect(config?.bots['python']?.[0].botName).toBe('Zipper');
  });

  it('should merge english translations when available', () => {
    i18n.setLanguage('en');

    let details: BotDetails | undefined;
    service.getBotDetails({ botName: 'Zipper', language: 'python' }).subscribe((value) => {
      details = value;
    });

    const request = httpMock.expectOne((req) => req.url.includes('bots/python/Zipper/Bot.json'));
    request.flush({
      botName: 'Zipper',
      startCommand: 'run zipper',
      description: 'Base description',
      translations: {
        en: {
          displayName: 'Zipper EN',
          shortDescription: 'English short description',
          description: 'English description'
        },
        it: {
          displayName: 'Zipper IT',
          shortDescription: 'Italiana'
        }
      }
    });

    expect(details).toBeDefined();
    expect(details?.displayName).toBe('Zipper EN');
    expect(details?.shortDescription).toBe('English short description');
    expect(details?.description).toBe('English description');
  });

  it('should fallback to italian translation when requested language is missing', () => {
    i18n.setLanguage('fr');

    let details: BotDetails | undefined;
    service.getBotDetails({ botName: 'Zipper', language: 'python' }).subscribe((value) => {
      details = value;
    });

    const request = httpMock.expectOne((req) => req.url.includes('bots/python/Zipper/Bot.json'));
    request.flush({
      botName: 'Zipper',
      startCommand: 'run zipper',
      description: 'Base description',
      translations: {
        it: {
          displayName: 'Zipper IT',
          shortDescription: 'Descrizione breve'
        }
      }
    });

    expect(details).toBeDefined();
    expect(details?.displayName).toBe('Zipper IT');
    expect(details?.shortDescription).toBe('Descrizione breve');
    expect(details?.description).toBe('Base description');
  });

  it('should provide safe fallbacks when translations are missing', () => {
    i18n.setLanguage('fr');

    let details: BotDetails | undefined;
    service.getBotDetails({ botName: 'Unknown', language: 'python' }).subscribe((value) => {
      details = value;
    });

    const request = httpMock.expectOne((req) => req.url.includes('bots/python/Unknown/Bot.json'));
    request.flush({
      botName: 'Unknown',
      startCommand: '',
      description: '',
      translations: {}
    });

    const uiStrings = i18n.getUiStrings();
    expect(details).toBeDefined();
    expect(details?.displayName).toBe('Unknown');
    expect(details?.shortDescription).toBe(uiStrings.noDescriptionFallback);
    expect(details?.description).toBe(uiStrings.noDescriptionFallback);
    expect(details?.startCommand).toBe('');
  });
});
