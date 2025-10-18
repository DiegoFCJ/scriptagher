import { Inject, Injectable, Optional } from '@angular/core';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { Observable, forkJoin, map, of, switchMap, catchError } from 'rxjs';
import { APP_BASE_HREF, DOCUMENT } from '@angular/common';

@Injectable({
  providedIn: 'root'
})
export class BotService {
  private readonly botsBaseUrl: URL;
  private readonly botsSourceBaseUrl: URL;
  private readonly githubApiBaseUrl: string;
  private readonly githubRepoOwner: string;
  private readonly githubRepoName: string;
  private readonly githubToken: string | undefined;
  private readonly githubApiVersion: string | undefined;
  private readonly githubInstallersBranch: string;
  private readonly githubInstallersPath: string;

  constructor(
    private http: HttpClient,
    @Optional() @Inject(DOCUMENT) private readonly documentRef: Document | null,
    @Optional() @Inject(APP_BASE_HREF) private readonly appBaseHref?: string
  ) {
    const baseUrl = this.resolveBaseUrl();
    this.botsBaseUrl = new URL('bots/', baseUrl);
    this.botsSourceBaseUrl = new URL('bots/', baseUrl);
    this.githubApiBaseUrl = this.getEnvironmentValue('NG_APP_GITHUB_API_URL')
      || this.getEnvironmentValue('GITHUB_API_URL')
      || 'https://api.github.com';
    this.githubRepoOwner = this.getEnvironmentValue('NG_APP_GITHUB_OWNER')
      || this.getEnvironmentValue('GITHUB_OWNER')
      || '';
    this.githubRepoName = this.getEnvironmentValue('NG_APP_GITHUB_REPO')
      || this.getEnvironmentValue('GITHUB_REPO')
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

  listInstallerAssets(): Observable<InstallerAsset[]> {
    if (!this.githubRepoOwner || !this.githubRepoName) {
      return of([]);
    }

    const url = this.buildContentsUrl(this.githubInstallersPath);
    const params = new HttpParams().set('ref', this.githubInstallersBranch);

    return this.http.get<GitHubContentItem[]>(url, { headers: this.buildGithubHeaders(), params }).pipe(
      switchMap((items) => {
        const files = items.filter((item) => item.type === 'file');
        const metadataFiles = files.filter((item) => this.isMetadataFile(item.name));
        const binaryFiles = files.filter((item) => this.isBinaryFile(item.name));

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
              const [key, metadata] = entry;
              metadataMap.set(key, metadata);
              if (metadata?.platform) {
                const normalizedPlatform = this.normalizePlatform(metadata.platform).toLowerCase();
                metadataByPlatform.set(normalizedPlatform, metadata);
              }
            }

            return binaryFiles.map((file) =>
              this.mapGithubContentToInstaller(file, metadataMap, metadataByPlatform)
            );
          })
        );
      }),
      catchError((error) => {
        console.error('Error fetching installer assets from GitHub:', error);
        return of([]);
      })
    );
  }

  /**
   * Fetch the bots configuration from bots.json.
   */
  getBotsConfig(): Observable<any> {
    const botsJsonPath = new URL('bots.json', this.botsBaseUrl).toString();
    return this.http.get(botsJsonPath);
  }

  /**
   * Costruisce il percorso completo per ottenere i dettagli di un bot specifico.
   * Fetch detailed bot information from Bot.json.
   * @param bot - The bot's name.
   */
  getBotDetails(bot: any): Observable<any> {
    const botJsonPath = new URL(`${bot.language}/${bot.botName}/Bot.json`, this.botsBaseUrl).toString();
    return this.http.get(botJsonPath);
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

  private fetchMetadataForFile(file: GitHubContentItem): Observable<[string, InstallerMetadata] | null> {
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
          const key = this.getMetadataKey(file.name);
          return [key, metadata] as [string, InstallerMetadata];
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
    const metadataKey = this.getMetadataKeyForBinary(item.name);
    const directMetadata = metadataMap.get(metadataKey) || metadataMap.get(item.name.toLowerCase());
    const inferredPlatform = this.normalizePlatform(
      directMetadata?.platform ?? this.inferPlatformFromName(item.name)
    );
    const platformMetadata = metadataByPlatform.get(inferredPlatform.toLowerCase());
    const mergedMetadata = {
      ...(platformMetadata ?? {}),
      ...(directMetadata ?? {})
    } as InstallerMetadata;
    const metadata = Object.keys(mergedMetadata).length ? mergedMetadata : undefined;

    return {
      name: metadata?.displayName ?? metadata?.name ?? item.name,
      filename: item.name,
      path: item.path,
      downloadUrl: metadata?.downloadUrl
        ?? item.download_url
        ?? `${this.buildContentsUrl(item.path)}?ref=${encodeURIComponent(this.githubInstallersBranch)}`,
      size: item.size,
      platform: this.normalizePlatform(metadata?.platform ?? inferredPlatform),
      contentType: metadata?.contentType ?? this.inferContentType(item.name),
      metadata: metadata ?? undefined,
    };
  }

  private isMetadataFile(name: string): boolean {
    return name.toLowerCase().endsWith('.json');
  }

  private isBinaryFile(name: string): boolean {
    const lowerName = name.toLowerCase();
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

  private getMetadataKey(name: string): string {
    return name.replace(/\.json$/i, '').toLowerCase();
  }

  private getMetadataKeyForBinary(name: string): string {
    const lower = name.toLowerCase();
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
  [key: string]: any;
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
}