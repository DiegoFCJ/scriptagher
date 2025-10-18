import { CommonModule } from '@angular/common';
import { Component, EventEmitter, Input, Output } from '@angular/core';

@Component({
  selector: 'app-installer-card',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './installer-card.component.html',
  styleUrl: './installer-card.component.scss'
})
export class InstallerCardComponent {
  @Input() installer: any;
  @Output() download = new EventEmitter<void>();

  onDownload(): void {
    this.download.emit();
  }
}
