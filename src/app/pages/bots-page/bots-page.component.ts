import { Component } from '@angular/core';

import { BotListComponent } from '../../components/bot-list/bot-list.component';

@Component({
  selector: 'app-bots-page',
  standalone: true,
  imports: [BotListComponent],
  templateUrl: './bots-page.component.html',
  styleUrls: ['./bots-page.component.scss']
})
export class BotsPageComponent {}
