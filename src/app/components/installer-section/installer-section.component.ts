import { CommonModule } from '@angular/common';
import { Component, Input } from '@angular/core';
import { BotService } from '../../services/bot.service';
import { InstallerCardComponent } from '../installer-card/installer-card.component';

@Component({
  selector: 'app-installer-section',
  standalone: true,
  imports: [CommonModule, InstallerCardComponent],
  templateUrl: './installer-section.component.html',
  styleUrl: './installer-section.component.scss'
})
export class InstallerSectionComponent {
  @Input() installers: any[] = [];
  @Input() errorMessage: string = '';

  constructor(private botService: BotService) {}

  downloadInstaller(installer: any): void {
    if (!installer?.asset && !installer?.filename) {
      console.warn('Installer asset missing for', installer);
      return;
    }

    this.botService.downloadInstaller(installer).subscribe({
      next: (blob: Blob) => {
        const link = document.createElement('a');
        const objectUrl = window.URL.createObjectURL(blob);
        link.href = objectUrl;
        const assetName = installer.asset || installer.filename || 'installer';
        link.download = assetName;
        link.click();
        window.URL.revokeObjectURL(objectUrl);
      },
      error: (error: any) => {
        console.error('Error downloading installer:', error);
        alert('Could not download the installer. Please try again later.');
      }
    });
  }
}
