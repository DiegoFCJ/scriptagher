import { CommonModule } from '@angular/common';
import { Component, Input } from '@angular/core';
import { InstallerAsset } from '../../services/bot.service';

@Component({
  selector: 'app-installer-section',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './installer-section.component.html',
  styleUrl: './installer-section.component.scss'
})
export class InstallerSectionComponent {
  @Input() installers: InstallerAsset[] = [];

  trackByPath(_: number, installer: InstallerAsset): string {
    return installer.path ?? installer.filename;
  }

  getDisplayName(installer: InstallerAsset): string {
    return installer.metadata?.displayName || installer.name || installer.filename;
  }
}
