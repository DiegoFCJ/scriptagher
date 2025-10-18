import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { catchError, forkJoin, of, firstValueFrom } from 'rxjs';
import { BotService } from '../../services/bot.service';
import { BotSectionComponent } from '../bot-section/bot-section.component';
import { HeaderComponent } from '../header/header.component';
import { FooterComponent } from '../footer/footer.component';
import { InstallerSectionComponent } from '../installer-section/installer-section.component';

@Component({
  selector: 'app-bot-list',
  templateUrl: './bot-list.component.html',
  styleUrls: ['./bot-list.component.scss'],
  standalone: true,
  imports: [
    CommonModule,
    HeaderComponent,
    BotSectionComponent,
    InstallerSectionComponent,
    FooterComponent
  ]
})
export class BotListComponent implements OnInit {
  botSections: any[] = [];
  errorMessage: string = '';
  installers: any[] = [];
  installersError: string = '';

  constructor(private botService: BotService) {}

  ngOnInit() {
    this.populateBotList();
  }

  populateBotList() {
    forkJoin({
      botsConfig: this.botService.getBotsConfig().pipe(
        catchError((err) => {
          console.error('Error fetching bots configuration:', err);
          this.errorMessage = 'Failed to load the bot list.';
          return of(null);
        })
      ),
      installers: this.botService.getInstallers().pipe(
        catchError((err) => {
          console.error('Error fetching installers manifest:', err);
          this.installersError = 'Failed to load installers.';
          return of({ installers: [], __error: true });
        })
      )
    }).subscribe(({ botsConfig, installers }) => {
      const hasInstallerError = !!(installers as any)?.__error;
      const installerList = Array.isArray(installers)
        ? installers
        : installers?.installers ?? [];
      this.installersError = hasInstallerError ? this.installersError : '';
      this.installers = installerList.filter(Boolean);

      if (!botsConfig) {
        this.botSections = [];
        return;
      }

      const languages = Object.keys(botsConfig);
      const sectionPromises = languages.map(async (language) => {
        const bots = botsConfig[language];
        if (!bots || bots.length === 0) {
          return null;
        }

        const botDetails = await Promise.all(
          bots.map(async (bot: any) => {
            try {
              bot.language = language;
              return await firstValueFrom(this.botService.getBotDetails(bot));
            } catch {
              return { botName: bot.botName, description: 'Error loading details' };
            }
          })
        );

        return {
          language,
          botDetails
        };
      });

      Promise.all(sectionPromises)
        .then((sections) => {
          this.botSections = sections.filter((section): section is { language: string; botDetails: any[] } => !!section);
        })
        .catch((err) => {
          console.error('Error building bot sections:', err);
          this.errorMessage = 'Failed to process the bot list.';
        });
    });
  }
}