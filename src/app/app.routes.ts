import { Routes } from '@angular/router';
import { BotListComponent } from './components/bot-list/bot-list.component';

export const routes: Routes = [
  {
    path: '', // Rotta di default
    component: BotListComponent
  },
  {
    path: 'pdf-to-txt',
    loadComponent: () => import('./components/pdf-to-txt/pdf-to-txt.component').then(m => m.PdfToTxtComponent)
  },
  {
    path: '**', // Rotta per errori 404
    loadComponent: () => import('./components/not-found/not-found.component').then(m => m.NotFoundComponent)
  }
];