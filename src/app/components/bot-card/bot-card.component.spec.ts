import { DestroyRef } from '@angular/core';
import { Router } from '@angular/router';
import { of } from 'rxjs';

import { BotCardComponent } from './bot-card.component';
import { BotService, LocalizedBotDetails } from '../../services/bot.service';
import { TranslationService } from '../../core/i18n/translation.service';

describe('BotCardComponent', () => {
  class MockDestroyRef implements DestroyRef {
    private callbacks: Array<() => void> = [];

    onDestroy(callback: () => void): () => void {
      this.callbacks.push(callback);
      return () => {
        this.callbacks = this.callbacks.filter((stored) => stored !== callback);
      };
    }

    destroy(): void {
      this.callbacks.forEach((callback) => callback());
      this.callbacks = [];
    }
  }

  function createComponent(isRepoPublic: boolean): BotCardComponent {
    const router = jasmine.createSpyObj<Router>('Router', ['navigate']);
    const botService = {
      isSourceRepoPublic$: of(isRepoPublic),
      openBot: jasmine.createSpy('openBot')
    } as unknown as BotService;
    const translation = jasmine.createSpyObj('TranslationService', ['translate']) as unknown as TranslationService;
    const destroyRef = new MockDestroyRef();

    return new BotCardComponent(router, botService, translation, destroyRef);
  }

  function buildBotDetails(): LocalizedBotDetails {
    return {
      botName: 'TestBot',
      language: 'en',
      displayName: 'Test Bot',
      shortDescription: 'A test bot',
      actions: {},
      translations: {},
      sourceUrl: 'https://example.com/repo'
    } as LocalizedBotDetails;
  }

  it('allows viewing the source when the repository is public', () => {
    const component = createComponent(true);
    component.bot = buildBotDetails();

    expect(component.canViewSource).toBeTrue();
  });

  it('hides the source when the repository is private', () => {
    const component = createComponent(false);
    component.bot = buildBotDetails();

    expect(component.canViewSource).toBeFalse();
  });
});
