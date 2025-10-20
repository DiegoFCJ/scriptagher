import { Routes } from '@angular/router';
import { BotListComponent } from './components/bot-list/bot-list.component';

export const routes: Routes = [
  {
    path: '', // Rotta di default
    component: BotListComponent
  },
  {
    path: 'bots',
    loadComponent: () => import('./pages/bots-page/bots-page.component').then((m) => m.BotsPageComponent)
  },
  {
    path: 'bots/:language/:botName',
    loadComponent: () => import('./pages/bot-detail-page/bot-detail-page.component').then((m) => m.BotDetailPageComponent)
  },
  {
    path: 'installers',
    loadComponent: () => import('./pages/installers-page/installers-page.component').then((m) => m.InstallersPageComponent)
  },
  {
    path: 'pdf-to-txt',
    loadComponent: () => import('./components/pdf-to-txt/pdf-to-txt.component').then(m => m.PdfToTxtComponent)
  },
  {
    path: 'license',
    loadComponent: () => import('./components/legal/license/license.component').then(m => m.LicenseComponent)
  },
  {
    path: '**', // Rotta per errori 404
    loadComponent: () => import('./components/not-found/not-found.component').then(m => m.NotFoundComponent)
  }
];
