import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, Router } from '@angular/router';
import { Subject } from 'rxjs';

import { BotCardComponent } from './bot-card.component';
import { BotService, LocalizedBotDetails } from '../../services/bot.service';
import { TranslationService } from '../../core/i18n/translation.service';

describe('BotCardComponent', () => {
  let fixture: ComponentFixture<BotCardComponent>;
  let component: BotCardComponent;
  let visibilitySubject: Subject<boolean>;

  const createBot = (overrides: Partial<LocalizedBotDetails> = {}): LocalizedBotDetails => ({
    botName: 'TestBot',
    language: 'python',
    displayName: 'Test Bot',
    shortDescription: 'A test bot',
    actions: {},
    ...overrides
  });

  beforeEach(async () => {
    visibilitySubject = new Subject<boolean>();

    await TestBed.configureTestingModule({
      imports: [BotCardComponent],
      providers: [
        {
          provide: BotService,
          useValue: {
            isSourceRepoPublic$: visibilitySubject.asObservable(),
            openBot: jasmine.createSpy('openBot')
          }
        },
        {
          provide: TranslationService,
          useValue: { translate: jasmine.createSpy('translate').and.callFake((key: string) => key) }
        },
        { provide: Router, useValue: { navigate: jasmine.createSpy('navigate') } },
        { provide: ActivatedRoute, useValue: {} }
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(BotCardComponent);
    component = fixture.componentInstance;
    component.language = 'python';
  });

  afterEach(() => {
    fixture.destroy();
  });

  it('allows viewing source when repository is public', () => {
    component.bot = createBot({ sourceUrl: 'https://example.com/source' });
    fixture.detectChanges();

    visibilitySubject.next(true);

    expect(component.canViewSource).toBeTrue();
  });

  it('prevents viewing source when repository is private', () => {
    component.bot = createBot({ sourceUrl: 'https://example.com/source' });
    fixture.detectChanges();

    visibilitySubject.next(false);

    expect(component.canViewSource).toBeFalse();
  });
});
