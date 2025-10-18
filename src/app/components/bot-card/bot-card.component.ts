import { CommonModule } from '@angular/common';
import { Component, Input, Output, EventEmitter } from '@angular/core';
import { Router } from '@angular/router';
import { BotService } from '../../services/bot.service';

@Component({
  selector: 'app-bot-card',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './bot-card.component.html',
  styleUrls: ['./bot-card.component.scss']
})
export class BotCardComponent {
  @Input() bot: any;
  @Input() language: string = '';
  @Output() download = new EventEmitter<void>();

  constructor(private router: Router, private botService: BotService) {}

  openBot() {
    this.bot.language = this.language;
    this.botService.openBot(this.bot);
  }

  downloadBot() {
    this.download.emit();
  }

  navigateToPdfToTxt() {
    try {
      this.router.navigate(['/pdf-to-txt']);
    } catch (error) {
      console.error('Errore durante la navigazione verso la pagina PDF to Txt:', error);
    }
  }
}
