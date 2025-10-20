import { Routes } from '@angular/router';
import { BotListComponent } from './components/bot-list/bot-list.component';

export const routes: Routes = [
  {
    path: '',
    pathMatch: 'full',
    loadComponent: () => import('./pages/home/home-page.component').then(m => m.HomePageComponent)
  },
  {
    path: 'bots',
    component: BotListComponent
  },
  {
    path: 'bots/:language/:botName',
    loadComponent: () => import('./pages/bot-detail/bot-detail-page.component').then(m => m.BotDetailPageComponent)
  },
  {
    path: 'installers',
    loadComponent: () => import('./pages/installers/installers-page.component').then(m => m.InstallersPageComponent)
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
    path: '**',
    loadComponent: () => import('./components/not-found/not-found.component').then(m => m.NotFoundComponent)
  }
];
