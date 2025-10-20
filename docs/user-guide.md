# Bot List User Guide

This guide describes how the Bot List application is structured, how to configure and build it, and the workflows used to publish updates to GitHub Pages.

## Application architecture

The Bot List project is an Angular single-page application that also ships with a Node.js/Express layer for server-side rendering (SSR) and static asset hosting.

- **Angular frontend** – The SPA is bootstrapped from `src/main.ts` and rendered in the browser with the components under `src/app/`. Angular configuration (build options, assets, SSR target, etc.) is managed through `angular.json`.
- **Express backend** – When SSR or custom hosting is required, `server.ts` constructs an Express application that serves the prebuilt browser bundle and delegates unmatched routes to Angular's `CommonEngine` renderer. This enables SSR-friendly deployments while still emitting a static bundle for GitHub Pages.
- **Installer integration** – `BotService` (under `src/app/services/bot.service.ts`) loads bot listings and installer binaries. Installers can be sourced either from a JSON manifest published with the site or directly from the GitHub Contents API, enabling air-gapped publishing via GitHub Pages.

## Environment configuration

Runtime configuration is injected through environment variables so the frontend can locate GitHub repositories that host bot installers:

| Variable | Purpose | Default |
| --- | --- | --- |
| `NG_APP_GITHUB_OWNER` | Repository owner or organisation that hosts the installers. | – |
| `NG_APP_GITHUB_REPO` | Repository name containing the installers directory. | – |
| `NG_APP_GITHUB_TOKEN` | *Optional.* Personal access token for authenticated GitHub API calls. Needed for private repos or to avoid unauthenticated rate limits. | – |
| `NG_APP_GITHUB_API_URL` | Base URL for the GitHub API (override for GitHub Enterprise). | `https://api.github.com` |
| `NG_APP_GITHUB_API_VERSION` | Custom `X-GitHub-Api-Version` header value. | GitHub default |
| `NG_APP_GITHUB_INSTALLERS_BRANCH` | Git branch that exposes the installers folder. | `gh-pages` |
| `NG_APP_GITHUB_INSTALLERS_PATH` | Path inside the repository where installers (and metadata) live. | `installers` |

> The application automatically falls back to the same variable names **without** the `NG_APP_` prefix (for example `GITHUB_OWNER`) so that hosting providers that only expose unprefixed names remain compatible.

## Local development and build commands

1. **Install dependencies**
   ```bash
   npm install
   ```
2. **Run the SPA in development mode**
   ```bash
   npm start
   ```
   Angular's dev server serves the client at `http://localhost:4200/` by default.
3. **Execute unit tests**
   ```bash
   npm test
   ```
4. **Build a production bundle**
   ```bash
   npm run build
   ```
   The command produces an SSR-aware distribution under `dist/bot-list/` with separate `browser/` and `server/` targets.

## Deployment to GitHub Pages

The repository provides a deployment helper that rebuilds the project and pushes the static bundle to the `gh-pages` branch:

```bash
npm run deploy
```

The script runs `npm run build`, then publishes the contents of `dist/bot-list/browser` using the `gh-pages` CLI with the commit message `Deploy to GitHub Pages`. Ensure your Git remote has write access to the `gh-pages` branch before running the command.

After deployment, open the published site to confirm that translated copy, bot listings, and download links match the expected state.

## Content authoring

### Bots and metadata

1. **Bots catalogue** – `BotService` loads `bots.json` from the published `bots/` directory. Define your available languages, sections, and bot entries inside this file. Each entry should include a `botName` and the language key the bot belongs to.
2. **Per-bot detail files** – For every bot listed in `bots.json`, publish a corresponding `bots/<language>/<BotName>/Bot.json`. These files hold display names, descriptions, and language-specific overrides. Include any download actions (for example `startCommand`) and supplementary metadata the frontend should display.
3. **Distributable assets** – Place runnable archives (for example ZIP files) alongside the `Bot.json` file. The application requests `${language}/${botName}/${botName}.zip` by default unless a custom `path` value is specified in the bot summary.

### Installer manifests

Installer downloads can be curated in two ways:

- **Static manifest** – Ship an `installers.json`, `manifest.json`, or `index.json` file inside the published `installers/` directory. The manifest can declare download URLs, platform hints, checksums, and metadata (licences, maintainers, repository links, etc.).
- **GitHub Contents API discovery** – When no manifest (or no matching entries) are present, the application recursively lists files from the configured GitHub repository and branch. Any sidecar metadata files (for example `.json` descriptors) are matched to installer binaries by name so the UI can display rich information.

Organise installers into subdirectories to group related assets. The UI nests folders and sorts installers by their `platform` and file name.

## Localization assets

Translations live under `src/assets/i18n/` with one JSON file per locale (for example `en.json`, `es.json`, `de.json`). Add new locales by creating additional JSON files that mirror the structure of `en.json`, then update your deployment pipeline so the files are copied to the built assets.

## Update workflow: build → deploy → verify

1. **Build** – Run `npm run build` to generate the latest Angular and installer assets under `dist/bot-list/`.
2. **Deploy** – Publish `dist/bot-list/browser` to GitHub Pages (for example with `npm run deploy`).
3. **Verify** – Load the live site and confirm that bot listings, installer downloads, localization strings, and licence text match the freshly built artifacts. Repeat if any discrepancies are found.

Always regenerate and republish this user guide whenever GitHub Pages assets are refreshed so that documentation stays aligned with the deployed experience.
