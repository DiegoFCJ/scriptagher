import { InjectionToken, Provider } from '@angular/core';

export interface BotRuntimeConfig {
  githubRepoOwner?: string;
  githubRepoName?: string;
  githubInstallersBranch?: string;
  /**
   * Absolute URL to the public installers directory published via GitHub Pages.
   */
  publicInstallersBaseUrl?: string;
}

export const BOT_CONFIG = new InjectionToken<BotRuntimeConfig>('BOT_CONFIG', {
  providedIn: 'root',
  factory: () => createBotRuntimeConfig(),
});

export function provideBotConfig(overrides: Partial<BotRuntimeConfig> = {}): Provider {
  return {
    provide: BOT_CONFIG,
    useValue: createBotRuntimeConfig(overrides),
  };
}

function createBotRuntimeConfig(overrides: Partial<BotRuntimeConfig> = {}): BotRuntimeConfig {
  const owner = overrides.githubRepoOwner ?? readEnvironmentValue('NG_APP_GITHUB_OWNER') ?? readEnvironmentValue('GITHUB_OWNER');
  const repo = overrides.githubRepoName ?? readEnvironmentValue('NG_APP_GITHUB_REPO') ?? readEnvironmentValue('GITHUB_REPO');
  const branch =
    overrides.githubInstallersBranch ??
    readEnvironmentValue('NG_APP_GITHUB_INSTALLERS_BRANCH') ??
    readEnvironmentValue('GITHUB_INSTALLERS_BRANCH') ??
    'gh-pages';

  const installersBaseUrl =
    overrides.publicInstallersBaseUrl ??
    readEnvironmentValue('NG_APP_INSTALLERS_BASE_URL') ??
    readEnvironmentValue('INSTALLERS_BASE_URL') ??
    (owner && repo ? `https://${owner}.github.io/${repo}/installers/` : undefined);

  return {
    githubRepoOwner: owner,
    githubRepoName: repo,
    githubInstallersBranch: branch,
    publicInstallersBaseUrl: installersBaseUrl,
  };
}

function readEnvironmentValue(key: string): string | undefined {
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
