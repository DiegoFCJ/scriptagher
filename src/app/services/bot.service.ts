import { Inject, Injectable, Optional } from '@angular/core';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import {
  Observable,
  forkJoin,
  map,
  of,
  switchMap,
  catchError,
  combineLatest,
  startWith,
  shareReplay
} from 'rxjs';
import { APP_BASE_HREF, DOCUMENT } from '@angular/common';
import { TranslationService } from '../core/i18n/translation.service';

@Injectable({
  providedIn: 'root'
})
export class BotService {
  private readonly botsBaseUrl: URL;
  private readonly botsSourceBaseUrl: URL;
  private readonly installersBaseUrl: URL;
  private readonly githubApiBaseUrl: string;
  private readonly githubRepoOwner: string;
  private readonly githubRepoName: string;
  private readonly githubToken: string | undefined;
  private readonly githubApiVersion: string | undefined;
  private readonly githubInstallersBranch: string;
  private readonly githubInstallersPath: string;

  private botsConfig$?: Observable<BotConfiguration>;
  private readonly botDetailsCache = new Map<string, Observable<LocalizedBotDetails>>();

  constructor(
    private http: HttpClient,
    private translations: TranslationService,
    @Optional() @Inject(DOCUMENT) private readonly documentRef: Document | null,
    @Optional() @Inject(APP_BASE_HREF) private readonly appBaseHref?: string
  ) {
    const baseUrl = this.resolveBaseUrl();
    const inferredRepoInfo = this.detectGithubRepoInfo(baseUrl);

    this.botsBaseUrl = new URL('bots/', baseUrl);
    this.botsSourceBaseUrl = new URL('bots/', baseUrl);
    this.installersBaseUrl = new URL('installers/', baseUrl);
    this.githubApiBaseUrl = this.getEnvironmentValue('NG_APP_GITHUB_API_URL')
      || this.getEnvironmentValue('GITHUB_API_URL')
      || 'https://api.github.com';
    this.githubRepoOwner = this.getEnvironmentValue('NG_APP_GITHUB_OWNER')
      || this.getEnvironmentValue('GITHUB_OWNER')
      || inferredRepoInfo.owner
      || '';
    this.githubRepoName = this.getEnvironmentValue('NG_APP_GITHUB_REPO')
      || this.getEnvironmentValue('GITHUB_REPO')
      || inferredRepoInfo.repo
      || '';
    this.githubToken = this.getEnvironmentValue('NG_APP_GITHUB_TOKEN')
      || this.getEnvironmentValue('GITHUB_TOKEN');
    this.githubApiVersion = this.getEnvironmentValue('NG_APP_GITHUB_API_VERSION')
      || this.getEnvironmentValue('GITHUB_API_VERSION');
    this.githubInstallersBranch = this.getEnvironmentValue('NG_APP_GITHUB_INSTALLERS_BRANCH')
      || this.getEnvironmentValue('GITHUB_INSTALLERS_BRANCH')
      || 'gh-pages';
    this.githubInstallersPath = this.getEnvironmentValue('NG_APP_GITHUB_INSTALLERS_PATH')
      || this.getEnvironmentValue('GITHUB_INSTALLERS_PATH')
      || 'installers';
  }

  private resolveBaseUrl(): string {
    const documentBase = this.documentRef?.baseURI;
    if (documentBase) {
      return this.ensureTrailingSlash(documentBase);
    }

    const locationHref = typeof location !== 'undefined' ? location.href : undefined;

    const origin = locationHref ? new URL('.', locationHref).toString() : 'http://localhost/';
    const base = new URL(this.appBaseHref ?? '/', origin).toString();
    return this.ensureTrailingSlash(base);
  }

  private ensureTrailingSlash(url: string): string {
    return url.endsWith('/') ? url : `${url}/`;
  }

  private detectGithubRepoInfo(baseUrl: string): { owner?: string; repo?: string } {
    try {
      const parsedUrl = new URL(baseUrl);
      const host = parsedUrl.hostname.toLowerCase();
      if (!host.endsWith('github.io')) {
        return {};
      }

      const owner = host.replace(/\.github\.io$/, '');
      const pathSegments = parsedUrl.pathname.split('/').filter(Boolean);
      if (pathSegments.length) {
        return { owner, repo: pathSegments[0] };
      }

      if (owner) {
        return { owner, repo: `${owner}.github.io` };
      }

      return {};
    } catch {
      return {};
    }
  }

  listInstallerAssets(): Observable<InstallerAsset[]> {
    return this.loadInstallerManifest().pipe(
      switchMap((manifest) => {
        if (manifest) {
          return this.createInstallerAssetsFromManifest(manifest).pipe(
            switchMap((assets) => {
              if (assets.length) {
                return of(assets);
              }
              return this.listInstallerAssetsFromGithub();
            })
          );
        }

        return this.listInstallerAssetsFromGithub();
      }),
      catchError((error) => {
        console.error('Error loading installer manifest, falling back to GitHub', error);
        return this.listInstallerAssetsFromGithub();
      })
    );
  }

  private listInstallerAssetsFromGithub(): Observable<InstallerAsset[]> {
    if (!this.githubRepoOwner || !this.githubRepoName) {
      return of([]);
    }

    return this.fetchInstallerContents(this.githubInstallersPath).pipe(
      switchMap((files) => {
        const metadataFiles = files.filter((item) => this.isMetadataFile(item.path));
        const binaryFiles = files.filter((item) => this.isBinaryFile(item.path));

        const metadataRequests = metadataFiles.map((file) => this.fetchMetadataForFile(file));
        const metadataStream = metadataRequests.length ? forkJoin(metadataRequests) : of([]);

        return metadataStream.pipe(
          map((metadataEntries) => {
            const metadataMap = new Map<string, InstallerMetadata>();
            const metadataByPlatform = new Map<string, InstallerMetadata>();

            for (const entry of metadataEntries) {
              if (!entry) {
                continue;
              }
              for (const key of entry.keys) {
                if (!key) {
                  continue;
                }
                metadataMap.set(key, entry.metadata);
              }
              if (entry.metadata?.platform) {
                const normalizedPlatform = this.normalizePlatform(entry.metadata.platform).toLowerCase();
                metadataByPlatform.set(normalizedPlatform, entry.metadata);
              }
            }

            return binaryFiles
              .map((file) => this.mapGithubContentToInstaller(file, metadataMap, metadataByPlatform))
              .sort((a, b) => {
                const platformComparison = a.platform.localeCompare(b.platform);
                if (platformComparison !== 0) {
                  return platformComparison;
                }
                return a.filename.localeCompare(b.filename);
              });
          })
        );
      }),
      catchError((error) => {
        console.error('Error fetching installer assets from GitHub:', error);
        return of([]);
      })
    );
  }

  private loadInstallerManifest(): Observable<unknown | null> {
    const manifestCandidates = ['installers.json', 'manifest.json', 'index.json'];

    return manifestCandidates.reduce((stream, candidate) => {
      return stream.pipe(
        switchMap((result) => {
          if (result) {
            return of(result);
          }
          return this.fetchManifestCandidate(candidate);
        })
      );
    }, of<unknown | null>(null));
  }

  private fetchManifestCandidate(filename: string): Observable<unknown | null> {
    try {
      const manifestUrl = new URL(filename, this.installersBaseUrl).toString();
      return this.http.get<unknown>(manifestUrl).pipe(
        catchError(() => of(null))
      );
    } catch {
      return of(null);
    }
  }

  private createInstallerAssetsFromManifest(manifest: unknown): Observable<InstallerAsset[]> {
    const entries = this.extractInstallerEntriesFromManifest(manifest);
    if (!entries.length) {
      return of([]);
    }

    const assetRequests = entries.map((entry) =>
      this.createInstallerAssetFromManifestEntry(entry).pipe(
        catchError((error) => {
          console.error(`Unable to map installer manifest entry for ${entry.path}`, error);
          return of(null);
        })
      )
    );

    return forkJoin(assetRequests).pipe(
      map((assets) =>
        assets
          .filter((asset): asset is InstallerAsset => !!asset)
          .sort((a, b) => {
            const platformComparison = a.platform.localeCompare(b.platform);
            if (platformComparison !== 0) {
              return platformComparison;
            }
            return a.filename.localeCompare(b.filename);
          })
      )
    );
  }

  private extractInstallerEntriesFromManifest(manifest: unknown): ManifestFileEntry[] {
    const entries = new Map<string, ManifestFileEntry>();

    const visit = (value: unknown, context: string[]): void => {
      if (value === null || value === undefined) {
        return;
      }

      if (typeof value === 'string') {
        const fullPath = this.combineContextPath(context, value);
        if (this.isBinaryFile(fullPath)) {
          const normalized = this.normalizeManifestRelativePath(fullPath);
          if (!entries.has(normalized)) {
            entries.set(normalized, { path: fullPath });
          }
        }
        return;
      }

      if (Array.isArray(value)) {
        value.forEach((item) => visit(item, context));
        return;
      }

      if (typeof value !== 'object') {
        return;
      }

      const node = value as Record<string, unknown>;
      const type = this.pickString(node, ['type']);
      const pathProperty = this.pickString(node, ['path', 'file', 'filename', 'relativePath', 'download']);
      const metadataPath = this.pickString(node, ['metadataPath', 'metadataFile']);
      const downloadUrl = this.pickString(node, ['downloadUrl', 'url', 'href']);
      const displayName = this.pickString(node, ['displayName', 'title']);
      const name = this.pickString(node, ['name']);
      const platform = this.pickString(node, ['platform', 'os', 'system']);
      const description = this.pickString(node, ['description', 'details', 'summary']);
      const contentType = this.pickString(node, ['contentType', 'mimeType']);
      const checksum = this.pickString(node, ['checksum', 'sha256', 'sha1', 'md5']);
      const size = this.pickNumber(node, ['size', 'fileSize', 'bytes']);

      const embeddedMetadata = this.extractEmbeddedMetadata(node);

      if (pathProperty && this.isBinaryFile(pathProperty)) {
        const fullPath = this.combineContextPath(context, pathProperty);
        const normalized = this.normalizeManifestRelativePath(fullPath);
        const existing = entries.get(normalized) ?? { path: fullPath };

        existing.path = fullPath;
        if (metadataPath) {
          existing.metadataPath = this.combineContextPath(context, metadataPath);
        }
        if (embeddedMetadata) {
          existing.metadata = this.mergeManifestMetadata(existing.metadata, embeddedMetadata);
        }
        if (displayName || name) {
          existing.overrideName = existing.overrideName ?? displayName ?? name;
        }
        if (platform) {
          existing.platform = existing.platform ?? platform;
        }
        if (description) {
          existing.description = existing.description ?? description;
        }
        if (downloadUrl) {
          existing.downloadUrl = existing.downloadUrl ?? downloadUrl;
        }
        if (contentType) {
          existing.contentType = existing.contentType ?? contentType;
        }
        if (checksum) {
          existing.checksum = existing.checksum ?? checksum;
        }
        if (size !== undefined) {
          existing.size = existing.size ?? size;
        }

        entries.set(normalized, existing);
        return;
      }

      const directoryContext = (() => {
        if (type && type.toLowerCase() === 'directory') {
          const directorySource = pathProperty ?? name;
          if (directorySource) {
            return this.combineContextSegments(context, directorySource);
          }
        }
        if (pathProperty && !this.isBinaryFile(pathProperty)) {
          return this.combineContextSegments(context, pathProperty);
        }
        if (name && !this.isBinaryFile(name)) {
          return this.combineContextSegments(context, name);
        }
        return context;
      })();

      const childKeys = ['children', 'items', 'entries', 'installers', 'files', 'directories', 'folders', 'contents'];
      for (const key of childKeys) {
        const child = node[key];
        if (child !== undefined) {
          visit(child, directoryContext);
        }
      }

      for (const [key, child] of Object.entries(node)) {
        if (childKeys.includes(key)) {
          continue;
        }
        if (
          [
            'type',
            'path',
            'file',
            'filename',
            'relativePath',
            'download',
            'metadata',
            'metadataPath',
            'metadataFile',
            'downloadUrl',
            'url',
            'href',
            'displayName',
            'title',
            'name',
            'platform',
            'os',
            'system',
            'description',
            'details',
            'summary',
            'contentType',
            'mimeType',
            'checksum',
            'sha256',
            'sha1',
            'md5',
            'size',
            'fileSize',
            'bytes'
          ].includes(key)
        ) {
          continue;
        }

        const nextContext = this.shouldTreatKeyAsDirectory(key, child)
          ? this.combineContextSegments(directoryContext, key)
          : directoryContext;

        visit(child, nextContext);
      }
    };

    visit(manifest, []);

    return Array.from(entries.values());
  }

  private createInstallerAssetFromManifestEntry(entry: ManifestFileEntry): Observable<InstallerAsset | null> {
    const normalizedPath = this.normalizeManifestRelativePath(entry.path);
    if (!normalizedPath) {
      return of(null);
    }

    const isAbsolute = this.isAbsoluteUrl(normalizedPath);
    const filename = this.extractFilename(normalizedPath);
    const relativePath = isAbsolute ? filename : this.getRelativeInstallerPath(normalizedPath);
    const directories = isAbsolute ? [] : this.getInstallerDirectories(normalizedPath);

    return this.loadInstallerMetadataForManifestEntry(entry, normalizedPath).pipe(
      map((metadata) => {
        const metadataOverrides = this.buildMetadataOverrides(entry);
        const combinedMetadata = this.mergeManifestMetadata(metadata, metadataOverrides);

        const platform = this.normalizePlatform(
          combinedMetadata?.platform ?? entry.platform ?? this.inferPlatformFromName(filename)
        );

        const finalMetadata = combinedMetadata && Object.keys(combinedMetadata).length
          ? combinedMetadata
          : undefined;

        const downloadUrl = isAbsolute
          ? normalizedPath
          : this.getInstallerDownloadUrl(normalizedPath, relativePath, null, finalMetadata);

        const size = entry.size ?? this.extractSizeFromMetadata(finalMetadata) ?? 0;

        return {
          name: finalMetadata?.displayName
            ?? finalMetadata?.name
            ?? entry.overrideName
            ?? filename,
          filename,
          path: normalizedPath,
          downloadUrl,
          size,
          platform,
          contentType: finalMetadata?.contentType ?? entry.contentType ?? this.inferContentType(filename),
          metadata: finalMetadata,
          directories,
          relativePath,
        } satisfies InstallerAsset;
      })
    );
  }

  private loadInstallerMetadataForManifestEntry(
    entry: ManifestFileEntry,
    normalizedPath: string
  ): Observable<InstallerMetadata | undefined> {
    const derivedMetadataPath = this.deriveMetadataPathFromRelativePath(normalizedPath);
    const metadataPath = entry.metadataPath ?? derivedMetadataPath;

    if (!metadataPath) {
      return of(entry.metadata);
    }

    const resolvedMetadataUrl = this.resolveManifestAssetUrl(metadataPath);

    return this.http.get<InstallerMetadata>(resolvedMetadataUrl).pipe(
      map((remoteMetadata) => this.mergeManifestMetadata(entry.metadata, remoteMetadata)),
      catchError(() => of(entry.metadata))
    );
  }

  private mergeManifestMetadata(
    ...metadatas: (InstallerMetadata | undefined)[]
  ): InstallerMetadata | undefined {
    const merged = metadatas.reduce<InstallerMetadata | undefined>((acc, metadata) => {
      if (!metadata) {
        return acc;
      }

      if (!acc) {
        return { ...metadata };
      }

      return { ...acc, ...metadata };
    }, undefined);

    if (!merged || Object.keys(merged).length === 0) {
      return undefined;
    }

    return merged;
  }

  private buildMetadataOverrides(entry: ManifestFileEntry): InstallerMetadata | undefined {
    const overrides: InstallerMetadata = {};

    if (entry.overrideName) {
      overrides.displayName = entry.overrideName;
    }
    if (entry.description) {
      overrides.description = entry.description;
    }
    if (entry.platform) {
      overrides.platform = entry.platform;
    }
    if (entry.downloadUrl) {
      overrides.downloadUrl = this.resolveManifestAssetUrl(entry.downloadUrl);
    }
    if (entry.contentType) {
      overrides.contentType = entry.contentType;
    }
    if (entry.checksum) {
      overrides.checksum = entry.checksum;
    }

    return Object.keys(overrides).length ? overrides : undefined;
  }

  private resolveManifestAssetUrl(pathOrUrl: string): string {
    if (!pathOrUrl) {
      return pathOrUrl;
    }

    const trimmed = pathOrUrl.trim();
    if (!trimmed) {
      return trimmed;
    }

    if (this.isAbsoluteUrl(trimmed)) {
      return trimmed;
    }

    const sanitized = trimmed.replace(/^\.\/+/, '').replace(/^\/+/, '');
    return new URL(sanitized, this.installersBaseUrl).toString();
  }

  private normalizeManifestRelativePath(path: string): string {
    if (!path) {
      return '';
    }

    const trimmed = path.trim();
    if (!trimmed) {
      return '';
    }

    if (this.isAbsoluteUrl(trimmed)) {
      return trimmed;
    }

    let sanitized = trimmed.replace(/^\.\/+/, '').replace(/^\/+/, '');
    const base = this.githubInstallersPath.replace(/^\/+/, '');
    if (base && sanitized.toLowerCase().startsWith(base.toLowerCase())) {
      sanitized = sanitized.slice(base.length);
      sanitized = sanitized.replace(/^\/+/, '');
    }

    return sanitized;
  }

  private combineContextSegments(context: string[], segment: string): string[] {
    if (!segment) {
      return context;
    }

    const trimmed = segment.trim();
    if (!trimmed || this.isAbsoluteUrl(trimmed)) {
      return context;
    }

    const sanitized = trimmed.replace(/^\.\/+/, '').replace(/^\/+/, '');
    let parts = sanitized.split('/').filter(Boolean);
    if (!parts.length) {
      return context;
    }

    const base = this.githubInstallersPath.replace(/^\/+/, '').toLowerCase();
    if (base && parts[0].toLowerCase() === base) {
      parts = parts.slice(1);
    }

    if (!parts.length) {
      return context;
    }

    return [...context, ...parts];
  }

  private combineContextPath(context: string[], value: string): string {
    if (!value) {
      return value;
    }

    const trimmed = value.trim();
    if (!trimmed) {
      return trimmed;
    }

    if (this.isAbsoluteUrl(trimmed)) {
      return trimmed;
    }

    const sanitized = trimmed.replace(/^\.\/+/, '').replace(/^\/+/, '');
    if (!context.length) {
      return sanitized;
    }

    const base = this.githubInstallersPath.replace(/^\/+/, '').toLowerCase();
    if (base && sanitized.toLowerCase().startsWith(base)) {
      return sanitized;
    }

    const contextPath = context.join('/');
    const lowerContextPath = contextPath.toLowerCase();
    const lowerSanitized = sanitized.toLowerCase();

    if (lowerSanitized.startsWith(lowerContextPath + '/')) {
      return sanitized;
    }

    if (lowerSanitized === lowerContextPath) {
      return sanitized;
    }

    return [...context, sanitized].filter(Boolean).join('/');
  }

  private shouldTreatKeyAsDirectory(key: string, value: unknown): boolean {
    if (!key) {
      return false;
    }

    if (value === null || value === undefined) {
      return false;
    }

    if (typeof value !== 'object') {
      return false;
    }

    const lowered = key.toLowerCase();
    const reservedKeys = new Set([
      'children',
      'items',
      'entries',
      'installers',
      'files',
      'directories',
      'folders',
      'contents',
      'metadata',
      'path',
      'file',
      'filename',
      'relativepath',
      'download',
      'downloadurl',
      'url',
      'href',
      'description',
      'details',
      'summary',
      'platform',
      'os',
      'system',
      'type',
      'size',
      'filesize',
      'bytes',
      'contenttype',
      'mimetype',
      'checksum',
      'sha256',
      'sha1',
      'md5'
    ]);

    if (reservedKeys.has(lowered)) {
      return false;
    }

    if (/^\d+$/.test(key)) {
      return false;
    }

    if (key.includes('.')) {
      return false;
    }

    return true;
  }

  private pickString(source: Record<string, unknown>, keys: string[]): string | undefined {
    for (const key of keys) {
      const value = source[key];
      if (typeof value === 'string' && value.trim()) {
        return value;
      }
    }
    return undefined;
  }

  private pickNumber(source: Record<string, unknown>, keys: string[]): number | undefined {
    for (const key of keys) {
      const value = source[key];
      if (typeof value === 'number' && !Number.isNaN(value)) {
        return value;
      }
      if (typeof value === 'string' && value.trim()) {
        const parsed = Number(value);
        if (!Number.isNaN(parsed)) {
          return parsed;
        }
      }
    }
    return undefined;
  }

  private extractEmbeddedMetadata(node: Record<string, unknown>): InstallerMetadata | undefined {
    const metadataValue = node['metadata'];
    if (!metadataValue || typeof metadataValue !== 'object' || Array.isArray(metadataValue)) {
      return undefined;
    }
    return metadataValue as InstallerMetadata;
  }

  private deriveMetadataPathFromRelativePath(path: string): string | undefined {
    if (!path || this.isAbsoluteUrl(path)) {
      return undefined;
    }

    const lower = path.toLowerCase();
    if (lower.endsWith('.tar.gz')) {
      return `${path.slice(0, -7)}.json`;
    }
    if (lower.endsWith('.tar.xz')) {
      return `${path.slice(0, -7)}.json`;
    }
    if (lower.endsWith('.tar.bz2')) {
      return `${path.slice(0, -8)}.json`;
    }
    const lastDot = path.lastIndexOf('.');
    if (lastDot === -1) {
      return `${path}.json`;
    }
    return `${path.slice(0, lastDot)}.json`;
  }

  private extractFilename(path: string): string {
    if (!path) {
      return '';
    }
    const segments = path.split('/').filter(Boolean);
    return segments.length ? segments[segments.length - 1] : path;
  }

  private extractSizeFromMetadata(metadata: InstallerMetadata | undefined): number | undefined {
    if (!metadata) {
      return undefined;
    }

    const keys = ['size', 'fileSize', 'bytes'];
    for (const key of keys) {
      const value = metadata[key];
      if (typeof value === 'number' && !Number.isNaN(value)) {
        return value;
      }
      if (typeof value === 'string' && value.trim()) {
        const parsed = Number(value);
        if (!Number.isNaN(parsed)) {
          return parsed;
        }
      }
    }

    return undefined;
  }

  private isAbsoluteUrl(value: string): boolean {
    return /^https?:\/\//i.test(value);
  }

  private fetchInstallerContents(path: string): Observable<GitHubContentItem[]> {
    const url = this.buildContentsUrl(path);
    const params = new HttpParams().set('ref', this.githubInstallersBranch);

    return this.http.get<GitHubContentItem[]>(url, { headers: this.buildGithubHeaders(), params }).pipe(
      switchMap((items) => {
        if (!items?.length) {
          return of([]);
        }

        const files = items.filter((item) => item.type === 'file');
        const directories = items.filter((item) => item.type === 'dir');

        if (!directories.length) {
          return of(files);
        }

        const directoryRequests = directories.map((dir) => this.fetchInstallerContents(dir.path));

        return forkJoin(directoryRequests).pipe(
          map((nestedItems) => files.concat(...nestedItems))
        );
      }),
      catchError((error) => {
        console.error(`Error fetching installer directory contents from ${path}`, error);
        return of([]);
      })
    );
  }

  /**
   * Fetch the bots configuration from bots.json.
   */
  getBotsConfig(): Observable<BotConfiguration> {
    if (!this.botsConfig$) {
      const botsJsonPath = new URL('bots.json', this.botsBaseUrl).toString();
      this.botsConfig$ = this.http.get<RawBotConfiguration>(botsJsonPath).pipe(
        map((raw) => this.normalizeBotConfiguration(raw)),
        shareReplay(1)
      );
    }

    return this.botsConfig$;
  }

  /**
   * Costruisce il percorso completo per ottenere i dettagli di un bot specifico.
   * Fetch detailed bot information from Bot.json.
   * @param bot - The bot's name.
   */
  getBotDetails(bot: BotSummary): Observable<LocalizedBotDetails> {
    const cacheKey = `${bot.language}/${bot.botName}`;
    if (!this.botDetailsCache.has(cacheKey)) {
      const botJsonPath = new URL(`${bot.language}/${bot.botName}/Bot.json`, this.botsBaseUrl).toString();
      const raw$ = this.http.get<BotDetails>(botJsonPath).pipe(
        catchError((error) => {
          console.error(`Failed to load bot details for ${cacheKey}`, error);
          return of<BotDetails | null>(null);
        }),
        shareReplay(1)
      );

      const localized$ = combineLatest([
        raw$,
        this.translations.language$.pipe(startWith(this.translations.language()))
      ]).pipe(
        map(([raw, language]) => this.mergeBotDetails(raw, language, bot)),
        catchError(() => of(this.buildFallbackBot(bot))),
        shareReplay(1)
      );

      this.botDetailsCache.set(cacheKey, localized$);
    }

    return this.botDetailsCache.get(cacheKey)!;
  }

  /**
   * Fetch and download the bot ZIP file.
   * @param bot - The bot's name.
   */
  downloadBot(bot: any): Observable<Blob> {
    const assetName = bot.path || `${bot.botName}.zip`;
    const zipPath = new URL(`${bot.language}/${bot.botName}/${assetName}`, this.botsBaseUrl).toString();
    return this.http.get(zipPath, { responseType: 'blob' });
  }

  /**
   * Open the bot source code in a new tab.
   * @param bot - Bot object containing language and name.
   */
  openBot(bot: any): void {
    const assetName = bot.path || `${bot.botName}.zip`;
    const sourcePath = new URL(`${bot.language}/${bot.botName}/${assetName}`, this.botsSourceBaseUrl).toString();
    window.open(sourcePath, '_blank');
  }

  private normalizeBotConfiguration(raw: RawBotConfiguration | null | undefined): BotConfiguration {
    const sections: Record<string, NormalizedBotSection> = {};
    const botsByLanguage: Record<string, BotSummary[]> = {};

    if (!raw) {
      return { sections, botsByLanguage };
    }

    const rawSections = raw.sections ?? {};
    for (const [language, section] of Object.entries(rawSections)) {
      const bots = this.normalizeBotSummaries(section?.bots, language);
      sections[language] = {
        translations: section?.translations ?? {},
        bots
      };

      if (bots.length) {
        botsByLanguage[language] = bots;
      }
    }

    for (const [key, value] of Object.entries(raw)) {
      if (key === 'sections') {
        continue;
      }

      if (!Array.isArray(value)) {
        continue;
      }

      const bots = this.normalizeBotSummaries(value, key);
      if (bots.length) {
        botsByLanguage[key] = bots;
        if (sections[key]) {
          sections[key].bots = sections[key].bots.length ? sections[key].bots : bots;
        } else {
          sections[key] = { translations: {}, bots };
        }
      }
    }

    return { sections, botsByLanguage };
  }

  private normalizeBotSummaries(entries: unknown, language?: string): BotSummary[] {
    if (!Array.isArray(entries)) {
      return [];
    }

    return entries
      .map((entry) => this.normalizeBotSummary(entry, language))
      .filter((entry): entry is BotSummary => !!entry);
  }

  private normalizeBotSummary(entry: unknown, language?: string): BotSummary | null {
    if (!entry || typeof entry !== 'object') {
      return null;
    }

    const value = entry as Record<string, unknown>;
    const botNameValue = value['botName'];
    const botName = typeof botNameValue === 'string' ? botNameValue : null;
    if (!botName) {
      return null;
    }

    const pathValue = value['path'];
    const languageValue = value['language'];
    const path = typeof pathValue === 'string' ? pathValue : undefined;
    const detectedLanguage = typeof languageValue === 'string' ? languageValue : undefined;

    return {
      botName,
      path,
      language: language ?? detectedLanguage ?? ''
    } satisfies BotSummary;
  }

  private mergeBotDetails(raw: BotDetails | null, language: string, fallback: BotSummary): LocalizedBotDetails {
    if (!raw) {
      return this.buildFallbackBot(fallback);
    }

    const translations = raw.translations ?? {};
    const placeholder = '—';
    const order = this.getLanguageFallbackOrder(language);

    let selected: BotTranslation | undefined;
    for (const candidate of order) {
      if (candidate && translations[candidate]) {
        selected = translations[candidate];
        break;
      }
    }

    const displayName = selected?.displayName
      ?? raw.displayName
      ?? raw.botName
      ?? fallback.botName
      ?? placeholder;

    const shortDescription = selected?.shortDescription
      ?? raw.shortDescription
      ?? raw.description
      ?? placeholder;

    const longDescription = selected?.longDescription
      ?? raw.longDescription
      ?? raw.description;

    const startCommand = selected?.startCommand ?? raw.startCommand;
    const actions = { ...(raw.actions ?? {}), ...(selected?.actions ?? {}) };

    return {
      ...raw,
      botName: raw.botName ?? fallback.botName ?? placeholder,
      language: fallback.language || raw.language || '',
      path: fallback.path ?? raw.path,
      displayName: displayName || placeholder,
      shortDescription: shortDescription || placeholder,
      longDescription,
      startCommand,
      actions,
      translations
    } satisfies LocalizedBotDetails;
  }

  private getLanguageFallbackOrder(language: string): string[] {
    const order: string[] = [];
    if (language) {
      order.push(language);
    }

    const fallback = this.translations.fallbackLanguage;
    if (fallback && !order.includes(fallback)) {
      order.push(fallback);
    }

    if (!order.includes('en')) {
      order.push('en');
    }

    return order;
  }

  private buildFallbackBot(bot: BotSummary): LocalizedBotDetails {
    const placeholder = '—';
    return {
      botName: bot.botName ?? placeholder,
      language: bot.language,
      path: bot.path,
      displayName: bot.botName ?? placeholder,
      shortDescription: placeholder,
      actions: {},
      translations: {}
    } satisfies LocalizedBotDetails;
  }

  private buildContentsUrl(path: string): string {
    const sanitizedPath = path.replace(/^\/+/, '');
    return `${this.githubApiBaseUrl.replace(/\/$/, '')}/repos/${this.githubRepoOwner}/${this.githubRepoName}/contents/${sanitizedPath}`;
  }

  private buildGithubHeaders(raw = false): HttpHeaders {
    let headers = new HttpHeaders({
      Accept: raw ? 'application/vnd.github.v3.raw' : 'application/vnd.github.v3+json'
    });

    if (this.githubToken) {
      headers = headers.set('Authorization', `Bearer ${this.githubToken}`);
    }

    if (this.githubApiVersion) {
      headers = headers.set('X-GitHub-Api-Version', this.githubApiVersion);
    }

    return headers;
  }

  private fetchMetadataForFile(file: GitHubContentItem): Observable<InstallerMetadataEntry | null> {
    const url = this.buildContentsUrl(file.path);
    const params = new HttpParams().set('ref', this.githubInstallersBranch);

    return this.http.get<GitHubFileContent>(url, { headers: this.buildGithubHeaders(), params }).pipe(
      map((response) => {
        if (!response?.content) {
          return null;
        }
        const decoded = this.decodeBase64(response.content);
        if (!decoded) {
          return null;
        }
        try {
          const metadata = JSON.parse(decoded) as InstallerMetadata;
          const pathKey = this.getMetadataKey(file.path);
          const nameKey = this.getMetadataKey(file.name);
          const keys = Array.from(new Set([pathKey, nameKey]));
          return { keys, metadata } satisfies InstallerMetadataEntry;
        } catch (error) {
          console.error(`Invalid installer metadata in ${file.path}`, error);
          return null;
        }
      }),
      catchError((error) => {
        console.error(`Unable to load installer metadata from ${file.path}`, error);
        return of(null);
      })
    );
  }

  private mapGithubContentToInstaller(
    item: GitHubContentItem,
    metadataMap: Map<string, InstallerMetadata>,
    metadataByPlatform: Map<string, InstallerMetadata>
  ): InstallerAsset {
    const metadataKey = this.getMetadataKeyForBinary(item.path);
    const directMetadata = metadataMap.get(metadataKey)
      || metadataMap.get(this.getMetadataKeyForBinary(item.name));
    const inferredPlatform = this.normalizePlatform(
      directMetadata?.platform ?? this.inferPlatformFromName(item.name)
    );
    const platformMetadata = metadataByPlatform.get(inferredPlatform.toLowerCase());
    const mergedMetadata = {
      ...(platformMetadata ?? {}),
      ...(directMetadata ?? {})
    } as InstallerMetadata;
    const metadata = Object.keys(mergedMetadata).length ? mergedMetadata : undefined;

    const relativePath = this.getRelativeInstallerPath(item.path);
    const directories = this.getInstallerDirectories(item.path);

    return {
      name: metadata?.displayName ?? metadata?.name ?? item.name,
      filename: item.name,
      path: item.path,
      downloadUrl: this.getInstallerDownloadUrl(item.path, relativePath, item.download_url, metadata),
      size: item.size,
      platform: this.normalizePlatform(metadata?.platform ?? inferredPlatform),
      contentType: metadata?.contentType ?? this.inferContentType(item.name),
      metadata: metadata ?? undefined,
      directories,
      relativePath,
    };
  }

  private isMetadataFile(pathOrName: string): boolean {
    return this.normalizePath(pathOrName).endsWith('.json');
  }

  private isBinaryFile(pathOrName: string): boolean {
    const lowerName = this.normalizePath(pathOrName);
    const binaryExtensions = [
      '.exe',
      '.msi',
      '.zip',
      '.tar.gz',
      '.tgz',
      '.tar.xz',
      '.tar.bz2',
      '.dmg',
      '.pkg',
      '.appimage',
      '.deb',
      '.rpm',
      '.apk',
      '.aab',
      '.ipa'
    ];

    return binaryExtensions.some((extension) => lowerName.endsWith(extension));
  }

  private getMetadataKey(pathOrName: string): string {
    return this.normalizePath(pathOrName).replace(/\.json$/i, '');
  }

  private getMetadataKeyForBinary(pathOrName: string): string {
    const lower = this.normalizePath(pathOrName);
    if (lower.endsWith('.tar.gz')) {
      return lower.replace(/\.tar\.gz$/, '');
    }
    if (lower.endsWith('.tar.xz')) {
      return lower.replace(/\.tar\.xz$/, '');
    }
    if (lower.endsWith('.tar.bz2')) {
      return lower.replace(/\.tar\.bz2$/, '');
    }
    const lastDotIndex = lower.lastIndexOf('.');
    return lastDotIndex >= 0 ? lower.substring(0, lastDotIndex) : lower;
  }

  private inferPlatformFromName(name: string): string {
    const lower = name.toLowerCase();
    if (/(windows|win32|win64|\.exe$|\.msi$)/.test(lower)) {
      return 'Windows';
    }
    if (/(mac|darwin|osx|\.dmg$|\.pkg$)/.test(lower)) {
      return 'macOS';
    }
    if (/(linux|\.appimage$|\.deb$|\.rpm$|\.tar\.gz$|\.tar\.xz$|\.tar\.bz2$|\.tgz$)/.test(lower)) {
      return 'Linux';
    }
    if (/(android|\.apk$|\.aab$)/.test(lower)) {
      return 'Android';
    }
    if (/(ios|\.ipa$)/.test(lower)) {
      return 'iOS';
    }
    return 'Other';
  }

  private normalizePlatform(platform: string | undefined): string {
    if (!platform) {
      return 'Other';
    }
    const normalized = platform.trim().toLowerCase();
    switch (normalized) {
      case 'windows':
      case 'win':
      case 'win32':
      case 'win64':
        return 'Windows';
      case 'mac':
      case 'macos':
      case 'osx':
        return 'macOS';
      case 'linux':
        return 'Linux';
      case 'android':
        return 'Android';
      case 'ios':
      case 'iphone':
      case 'ipad':
        return 'iOS';
      default:
        return platform;
    }
  }

  private inferContentType(name: string): string | undefined {
    const lower = name.toLowerCase();
    if (lower.endsWith('.exe')) {
      return 'application/vnd.microsoft.portable-executable';
    }
    if (lower.endsWith('.msi')) {
      return 'application/x-msi';
    }
    if (lower.endsWith('.zip')) {
      return 'application/zip';
    }
    if (lower.endsWith('.tar.gz') || lower.endsWith('.tgz')) {
      return 'application/gzip';
    }
    if (lower.endsWith('.tar.xz')) {
      return 'application/x-xz';
    }
    if (lower.endsWith('.tar.bz2')) {
      return 'application/x-bzip2';
    }
    if (lower.endsWith('.dmg')) {
      return 'application/x-apple-diskimage';
    }
    if (lower.endsWith('.pkg')) {
      return 'application/octet-stream';
    }
    if (lower.endsWith('.appimage')) {
      return 'application/octet-stream';
    }
    if (lower.endsWith('.deb')) {
      return 'application/vnd.debian.binary-package';
    }
    if (lower.endsWith('.rpm')) {
      return 'application/x-rpm';
    }
    if (lower.endsWith('.apk')) {
      return 'application/vnd.android.package-archive';
    }
    if (lower.endsWith('.aab')) {
      return 'application/octet-stream';
    }
    if (lower.endsWith('.ipa')) {
      return 'application/octet-stream';
    }
    return undefined;
  }

  private decodeBase64(content: string): string {
    if (!content) {
      return '';
    }

    if (typeof atob === 'function') {
      try {
        const binary = atob(content);
        const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
        if (typeof TextDecoder !== 'undefined') {
          return new TextDecoder('utf-8').decode(bytes);
        }
        return binary;
      } catch {
        return atob(content);
      }
    }

    const globalBuffer = typeof globalThis !== 'undefined' ? (globalThis as any).Buffer : undefined;
    if (globalBuffer) {
      return globalBuffer.from(content, 'base64').toString('utf-8');
    }

    return content;
  }

  private normalizePath(pathOrName: string): string {
    if (!pathOrName) {
      return '';
    }
    return pathOrName.replace(/\\/g, '/').toLowerCase();
  }

  private getInstallerDirectories(fullPath: string): string[] {
    const segments = fullPath.split('/').filter(Boolean);
    if (!segments.length) {
      return [];
    }
    const normalizedSegments = this.stripBaseInstallerSegments(segments);
    return normalizedSegments.slice(0, -1);
  }

  private getRelativeInstallerPath(fullPath: string): string {
    const segments = fullPath.split('/').filter(Boolean);
    if (!segments.length) {
      return fullPath;
    }
    const normalizedSegments = this.stripBaseInstallerSegments(segments);
    if (!normalizedSegments.length) {
      return segments[segments.length - 1];
    }
    return normalizedSegments.join('/');
  }

  private stripBaseInstallerSegments(segments: string[]): string[] {
    if (!segments.length) {
      return segments;
    }

    const baseSegments = this.githubInstallersPath.split('/').filter(Boolean);
    if (!baseSegments.length) {
      return segments;
    }

    const normalizedBase = baseSegments.map((segment) => segment.toLowerCase());
    const normalizedSegments = segments.map((segment) => segment.toLowerCase());

    for (let index = 0; index <= normalizedSegments.length - normalizedBase.length; index++) {
      const windowMatches = normalizedBase.every(
        (baseSegment, baseIndex) => normalizedSegments[index + baseIndex] === baseSegment
      );

      if (windowMatches) {
        return segments.slice(index + normalizedBase.length);
      }
    }

    const prPrefixPattern = /^pr-\d+$/i;
    if (segments.length && prPrefixPattern.test(segments[0])) {
      return segments.slice(1);
    }

    return segments;
  }

  private getInstallerDownloadUrl(
    fullPath: string,
    relativePath: string,
    githubDownloadUrl: string | null,
    metadata?: InstallerMetadata
  ): string {
    if (metadata?.downloadUrl) {
      return metadata.downloadUrl;
    }

    if (relativePath) {
      try {
        return new URL(relativePath, this.installersBaseUrl).toString();
      } catch {
        // fall through to GitHub URLs
      }
    }

    if (githubDownloadUrl) {
      return githubDownloadUrl;
    }

    return `${this.buildContentsUrl(fullPath)}?ref=${encodeURIComponent(this.githubInstallersBranch)}`;
  }

  private getEnvironmentValue(key: string): string | undefined {
    if (!key) {
      return undefined;
    }

    const globalObj: any = typeof globalThis !== 'undefined' ? globalThis : {};
    if (typeof globalObj[key] === 'string') {
      return globalObj[key];
    }
    if (globalObj.__env && typeof globalObj.__env[key] === 'string') {
      return globalObj.__env[key];
    }
    if (globalObj.env && typeof globalObj.env[key] === 'string') {
      return globalObj.env[key];
    }
    try {
      const metaEnv = (import.meta as any)?.env;
      if (metaEnv && typeof metaEnv[key] === 'string') {
        return metaEnv[key];
      }
    } catch {
      // ignore missing import.meta
    }

    return undefined;
  }
}

interface RawBotConfiguration {
  sections?: Record<string, RawBotSection | null | undefined> | null;
  [language: string]: unknown;
}

interface RawBotSection {
  translations?: Record<string, BotSectionTranslation | null | undefined> | null;
  bots?: unknown;
}

export interface BotSectionTranslation {
  title?: string;
  summary?: string;
}

export interface BotConfiguration {
  sections: Record<string, NormalizedBotSection>;
  botsByLanguage: Record<string, BotSummary[]>;
}

export interface NormalizedBotSection {
  translations: Record<string, BotSectionTranslation | null | undefined>;
  bots: BotSummary[];
}

export interface BotSummary {
  botName: string;
  path?: string;
  language: string;
}

interface BotDetails extends BotSummary {
  description?: string;
  shortDescription?: string;
  longDescription?: string;
  displayName?: string;
  startCommand?: string;
  actions?: Record<string, string>;
  translations?: Record<string, BotTranslation | null | undefined>;
}

export interface BotTranslation {
  displayName?: string;
  shortDescription?: string;
  longDescription?: string;
  startCommand?: string;
  actions?: Record<string, string>;
}

export interface LocalizedBotDetails extends BotDetails {
  displayName: string;
  shortDescription: string;
  actions: Record<string, string>;
}

interface GitHubContentItem {
  name: string;
  path: string;
  sha: string;
  size: number;
  url: string;
  html_url: string;
  download_url: string | null;
  type: 'file' | 'dir' | 'symlink' | 'submodule';
}

interface GitHubFileContent {
  content: string;
  encoding: string;
  name: string;
  path: string;
  sha: string;
  size: number;
  url: string;
}

export interface InstallerMetadata {
  name?: string;
  displayName?: string;
  description?: string;
  platform?: string;
  contentType?: string;
  checksum?: string;
  releaseNotesUrl?: string;
  downloadUrl?: string;
  license?: string | InstallerLicenseMetadata;
  licence?: string | InstallerLicenseMetadata;
  licenseUrl?: string;
  licenceUrl?: string;
  licenseId?: string;
  licenseText?: string;
  licenseName?: string;
  projectUrl?: string | InstallerRepositoryInfo;
  projectURL?: string | InstallerRepositoryInfo;
  sourceUrl?: string | InstallerRepositoryInfo;
  source?: string | InstallerRepositoryInfo;
  repositoryUrl?: string | InstallerRepositoryInfo;
  repository?: string | InstallerRepositoryInfo;
  homepage?: string | InstallerRepositoryInfo;
  homePage?: string | InstallerRepositoryInfo;
  maintainer?: InstallerContactValue;
  maintainers?: InstallerContactValue;
  publisher?: InstallerContactValue;
  author?: InstallerContactValue;
  owner?: InstallerContactValue;
  vendor?: InstallerContactValue;
  [key: string]: any;
}

export type InstallerContactValue = string | InstallerContact | InstallerContact[];

export interface InstallerContact {
  name?: string;
  displayName?: string;
  fullName?: string;
  login?: string;
  username?: string;
  email?: string;
  url?: string;
  html_url?: string;
  [key: string]: unknown;
}

export interface InstallerRepositoryInfo {
  url?: string;
  html_url?: string;
  href?: string;
  link?: string;
  [key: string]: unknown;
}

export interface InstallerLicenseMetadata {
  name?: string;
  title?: string;
  spdx_id?: string;
  spdxId?: string;
  key?: string;
  id?: string;
  url?: string;
  html_url?: string;
  [key: string]: unknown;
}

export interface InstallerAsset {
  name: string;
  filename: string;
  path: string;
  downloadUrl: string;
  size: number;
  platform: string;
  contentType?: string;
  metadata?: InstallerMetadata;
  directories: string[];
  relativePath: string;
}

interface InstallerMetadataEntry {
  keys: string[];
  metadata: InstallerMetadata;
}

interface ManifestFileEntry {
  path: string;
  metadataPath?: string;
  metadata?: InstallerMetadata;
  overrideName?: string;
  platform?: string;
  description?: string;
  downloadUrl?: string;
  contentType?: string;
  checksum?: string;
  size?: number;
}
