import { CommonModule } from '@angular/common';
import { Component, Input, OnChanges, SimpleChanges } from '@angular/core';

import { InstallerAsset } from '../../services/bot.service';
import { TranslatePipe } from '../../core/i18n/translate.pipe';

@Component({
  selector: 'app-installer-section',
  standalone: true,
  imports: [CommonModule, TranslatePipe],
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

  formatSize(size?: number | null): string | null {
    if (!size || size <= 0) {
      return null;
    }

    const megabytes = size / (1024 * 1024);
    if (megabytes >= 10) {
      return `${megabytes.toFixed(1)} MB`;
    }

    if (megabytes >= 1) {
      return `${megabytes.toFixed(2)} MB`;
    }

    if (megabytes >= 0.01) {
      return `${megabytes.toFixed(2)} MB`;
    }

    return `${megabytes.toFixed(3)} MB`;
  }

  getMaintainer(installer: InstallerAsset): string | undefined {
    const metadata = installer.metadata as Record<string, unknown> | undefined;
    if (!metadata) {
      return undefined;
    }

    const keys = ['maintainer', 'maintainers', 'publisher', 'author', 'owner', 'vendor'];
    for (const key of keys) {
      const value = metadata[key];
      const normalized = this.normalizeContact(value);
      if (normalized) {
        return normalized;
      }
    }

    return undefined;
  }

  getLicense(installer: InstallerAsset): LicenseInfo | undefined {
    const metadata = installer.metadata as Record<string, unknown> | undefined;
    if (!metadata) {
      return undefined;
    }

    const licenseCandidate = metadata['license'] ?? metadata['licence'] ?? metadata['licenseName'];
    const text = this.extractLicenseName(licenseCandidate)
      ?? this.extractLicenseName(metadata['licenseText'])
      ?? this.extractLicenseName(metadata['licenseId']);

    if (!text) {
      return undefined;
    }

    const licenseUrlCandidate = metadata['licenseUrl']
      ?? metadata['licenseURL']
      ?? metadata['licenceUrl']
      ?? metadata['licenseLink']
      ?? (typeof licenseCandidate === 'object' ? (licenseCandidate as Record<string, unknown>)['url'] : undefined)
      ?? (typeof licenseCandidate === 'object' ? (licenseCandidate as Record<string, unknown>)['html_url'] : undefined);

    const licenseInfo: LicenseInfo = { text };
    const url = this.extractFirstUrl(licenseUrlCandidate);
    if (url) {
      licenseInfo.url = url;
    }

    return licenseInfo;
  }

  getHomepage(installer: InstallerAsset): string | undefined {
    const metadata = installer.metadata as Record<string, unknown> | undefined;
    if (!metadata) {
      return undefined;
    }

    const candidates = [
      metadata['homepage'],
      metadata['homePage'],
      metadata['projectUrl'],
      metadata['projectURL'],
      metadata['sourceUrl'],
      metadata['source'],
      metadata['repositoryUrl'],
      metadata['repository'],
    ];

    for (const candidate of candidates) {
      const url = this.extractFirstUrl(candidate);
      if (url) {
        return url;
      }
    }

    return undefined;
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

  private normalizeContact(value: unknown): string | undefined {
    if (!value) {
      return undefined;
    }

    if (typeof value === 'string') {
      const trimmed = value.trim();
      return trimmed.length ? trimmed : undefined;
    }

    if (Array.isArray(value)) {
      const parts = value
        .map((entry) => this.normalizeContact(entry))
        .filter((entry): entry is string => !!entry);
      return parts.length ? Array.from(new Set(parts)).join(', ') : undefined;
    }

    if (typeof value === 'object') {
      const record = value as Record<string, unknown>;
      const candidates = [
        record['name'],
        record['displayName'],
        record['fullName'],
        record['login'],
        record['username'],
      ];
      const email = typeof record['email'] === 'string' ? record['email'].trim() : undefined;
      const url = this.extractFirstUrl(record['url'] ?? record['html_url']);

      const name = candidates
        .map((candidate) => this.normalizeContact(candidate))
        .find((candidate): candidate is string => !!candidate);

      const segments = [name, email, url].filter((segment): segment is string => !!segment);
      if (segments.length) {
        return Array.from(new Set(segments)).join(' · ');
      }
    }

    return undefined;
  }

  private extractLicenseName(value: unknown): string | undefined {
    if (!value) {
      return undefined;
    }

    if (typeof value === 'string') {
      const trimmed = value.trim();
      return trimmed.length ? trimmed : undefined;
    }

    if (typeof value === 'object') {
      const record = value as Record<string, unknown>;
      const keys = ['name', 'title', 'spdx_id', 'spdxId', 'key', 'id'];
      for (const key of keys) {
        const candidate = record[key];
        if (typeof candidate === 'string') {
          const trimmed = candidate.trim();
          if (trimmed.length) {
            return trimmed;
          }
        }
      }
    }

    return undefined;
  }

  private extractFirstUrl(value: unknown): string | undefined {
    if (!value) {
      return undefined;
    }

    if (typeof value === 'string') {
      const trimmed = value.trim();
      return trimmed.length ? trimmed : undefined;
    }

    if (Array.isArray(value)) {
      for (const entry of value) {
        const result = this.extractFirstUrl(entry);
        if (result) {
          return result;
        }
      }
      return undefined;
    }

    if (typeof value === 'object') {
      const record = value as Record<string, unknown>;
      const keys = ['url', 'html_url', 'href', 'link'];
      for (const key of keys) {
        const candidate = record[key];
        const normalized = this.extractFirstUrl(candidate);
        if (normalized) {
          return normalized;
        }
      }
    }

    return undefined;
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

interface LicenseInfo {
  text: string;
  url?: string;
}
