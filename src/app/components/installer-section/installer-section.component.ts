import { CommonModule } from '@angular/common';
import { Component, Input, OnChanges, SimpleChanges } from '@angular/core';
import { InstallerAsset } from '../../services/bot.service';

@Component({
  selector: 'app-installer-section',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './installer-section.component.html',
  styleUrl: './installer-section.component.scss'
})
export class InstallerSectionComponent implements OnChanges {
  @Input() installers: InstallerAsset[] = [];
  groupedInstallers: InstallerGroup[] = [];
  rootInstallers: InstallerAsset[] = [];

  trackByPath(_: number, installer: InstallerAsset): string {
    return installer.path ?? installer.filename;
  }

  getDisplayName(installer: InstallerAsset): string {
    return installer.metadata?.displayName || installer.name || installer.filename;
  }

  trackByGroupPath(_: number, group: InstallerGroup): string {
    return group.path.join('/') || group.name;
  }

  ngOnChanges(changes: SimpleChanges): void {
    if (changes['installers']) {
      const installerList = this.installers ?? [];
      this.rootInstallers = this.sortInstallers(
        installerList.filter((installer) => !installer.directories?.length)
      );
      this.groupedInstallers = this.buildInstallerTree(
        installerList.filter((installer) => (installer.directories?.length ?? 0) > 0)
      );
    }
  }

  private buildInstallerTree(installers: InstallerAsset[]): InstallerGroup[] {
    const rootMap = new Map<string, InstallerGroupBuilder>();

    for (const installer of installers) {
      const directories = installer.directories ?? [];
      if (!directories.length) {
        continue;
      }

      let currentLevel = rootMap;
      const pathSegments: string[] = [];

      directories.forEach((segment, index) => {
        pathSegments.push(segment);
        let node = currentLevel.get(segment);
        if (!node) {
          node = {
            name: segment,
            path: [...pathSegments],
            installers: [],
            children: new Map<string, InstallerGroupBuilder>(),
          };
          currentLevel.set(segment, node);
        }

        if (index === directories.length - 1) {
          node.installers.push(installer);
        }

        currentLevel = node.children;
      });
    }

    return this.mapGroups(rootMap);
  }

  private mapGroups(map: Map<string, InstallerGroupBuilder>): InstallerGroup[] {
    return Array.from(map.values())
      .sort((a, b) => a.name.localeCompare(b.name))
      .map((node) => ({
        name: node.name,
        path: node.path,
        installers: this.sortInstallers(node.installers),
        children: this.mapGroups(node.children),
      }));
  }

  private sortInstallers(installers: InstallerAsset[]): InstallerAsset[] {
    return [...installers].sort((a, b) => {
      const nameComparison = this.getDisplayName(a).localeCompare(this.getDisplayName(b));
      if (nameComparison !== 0) {
        return nameComparison;
      }
      return a.filename.localeCompare(b.filename);
    });
  }
}

interface InstallerGroup {
  name: string;
  path: string[];
  installers: InstallerAsset[];
  children: InstallerGroup[];
}

interface InstallerGroupBuilder {
  name: string;
  path: string[];
  installers: InstallerAsset[];
  children: Map<string, InstallerGroupBuilder>;
}
