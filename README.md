# Bot List - Documentation

Welcome to the **Bot List**, a curated collection of runnable bots organized by language.
This repository provides a framework for managing, downloading, and executing bots seamlessly.
Below you'll find instructions on how to add your own bot to the list,
the rules to follow, and how bots are structured.

> 📘 **Need the full deployment and operations playbook?** Read the [Bot List User Guide](docs/user-guide.md) for details on the application architecture, environment variables, authoring workflows, and GitHub Pages deployment steps. Regenerate and republish that guide whenever you refresh the GitHub Pages assets so production documentation stays in sync with the live site.

---

## 🚀 How to Add Your Bot

Adding your bot to the repository involves the following steps:

### 1. Fork and Clone the Repository
1. Fork this repository to your GitHub account.
2. Clone your forked repository to your local machine:
   ```bash
   git clone https://github.com/<your-username>/scriptagher.git
   cd scriptagher
   ```

### 2. Create a Folder for Your Bot
- Navigate to the appropriate language folder (e.g., bots/java, bots/python, bots/javascript).
- Create a new folder with your bot's name. For example:
    ```bash
    mkdir bots/python/MyAwesomeBot
    ```

### 3. Add Your Bot Files
- Place your runnable bot file(s) inside this folder.
- Rules for file structure:
    - Single file execution: Your bot must be executable with a single command, such as:
        - Python: python3 `<file>`.py
        - JavaScript: node `<file>`.js
        - Java: java -jar `<file>`.jar
    - For complex bots: Bundle your bot as a runnable JAR file, standalone executable, or other self-contained format.
- Include a JSON metadata file in the folder (see below for the required structure).

### 4. Create a JSON Metadata File
Each bot folder must include a JSON file named `<bot-name>`.json. This file should contain:
```json
{
    "botName": "",
    "description": "",
    "startCommand": "",
    "sourcePath": "",
    "language": ""
}
```

### 🔑 Rules for Adding Bots
1. Independent Execution: Each bot must be self-contained and executable with a single command (no manual setup required).
2. Runnable Formats:
    - Python: Single .py file or a directory with `__main__`.py for execution.
    - JavaScript: Single .js file.
    - Java: A single .jar file (preferred for complex bots).
3. Include Metadata: Add a `<bot-name>`.json file in the same folder as your bot file.
4. Follow File Naming Conventions:
    - Folder and file names should be descriptive and match your bot's purpose.
    - Avoid spaces or special characters in folder/file names.
5. Documentation:
    - Add a description of your bot in the JSON file.
    - Provide clear instructions in your bot's code comments if necessary.

### 📋 Example Bot Structure
```sh
bots/
└── python/
    └── MyAwesomeBot/
        ├── MyAwesomeBot.zip
        ├── MyAwesomeBot.json
```

#### MyAwesomeBot.json:
```json
{
    "botName": "MyAwesomeBot",
    "description": "This bot performs automated data scraping for websites.",
    "startCommand": "python3 bots/python/MyAwesomeBot/MyAwesomeBot.py",
    "sourcePath": "https://github.com/<YourGitHubName>/MyAwesomeBot",
    "language": "Python"
}
```

### 🛠 How the System Works
1. Bot Metadata: The backend fetches metadata from the JSON file in each bot folder to list and manage bots.
2. Execution: When a bot is executed, the backend runs the startCommand specified in the JSON file.
3. Bot Hosting: Bots are hosted in this repository and served via GitHub Pages for easy downloading.

### 🌟 Submitting a Pull Request
1. Create a new branch under bot-list-feature branch:
    ```bash
    git checkout bot-list-feature
    git checkout -b Your-Bot-Name
    ```

2. After adding your bot and updating the necessary files, commit your changes:
    ```bash
    git add .
    git commit -m "Added MyAwesomeBot"
    ```

3. Push your changes to your forked repository:
    ```bash
    git push origin main
    ```

4. Open a Pull Request to the original repository with a clear description of your bot.

### 🛡 License
By contributing, you agree that your bot will be open-sourced under the same license as this repository. Ensure you have the rights to share the bot.

#### Maintaining the license during deploy
To keep the published application aligned with the current licence terms:

1. Update the root `LICENSE` file with the approved text whenever the terms change.
2. Regenerate the production bundle with `npm run build` so the updated file is copied to `dist/bot-list/browser/LICENSE` through the Angular asset pipeline.
3. Deploy the freshly built `dist/bot-list/browser` directory (e.g. via `npm run deploy`) to publish both the static file and the `/license` page with the new content.
4. After deployment, open `/license` in the hosted site to confirm the rendered text matches the committed `LICENSE` file.

## ⚙️ GitHub installer configuration

The application now fetches installer binaries directly from the `installers/` directory of a GitHub repository (default branch: `gh-pages`).
Configure the runtime environment with the following variables so the Angular app can call the GitHub Contents API:

| Variable | Purpose | Default |
| --- | --- | --- |
| `NG_APP_GITHUB_OWNER` | Repository owner or organization. | – |
| `NG_APP_GITHUB_REPO` | Repository name that hosts the installers. | – |
| `NG_APP_GITHUB_TOKEN` | **Optional.** Personal access token used for authenticated requests. Required for private repositories and recommended to avoid unauthenticated rate limits. | – |
| `NG_APP_GITHUB_API_URL` | Base URL for the GitHub API. Override when using GitHub Enterprise. | `https://api.github.com` |
| `NG_APP_GITHUB_API_VERSION` | Custom `X-GitHub-Api-Version` header value. | GitHub default |
| `NG_APP_GITHUB_INSTALLERS_BRANCH` | Branch where the `installers/` directory lives. | `gh-pages` |
| `NG_APP_GITHUB_INSTALLERS_PATH` | Directory path containing installer binaries. | `installers` |

> ℹ️ The service also checks for the same variables without the `NG_APP_` prefix (e.g. `GITHUB_OWNER`) to support hosting platforms that expose only unprefixed environment variables.

### Authentication and rate limits

* Public repositories can be queried without a token, but the GitHub REST API enforces a limit of **60 requests per hour** for unauthenticated traffic. Provide a token to raise the limit to the authenticated quota (typically 5,000 requests per hour).
* The token only needs the `public_repo` scope for public repositories and the `repo` scope for private repositories. Store it securely (for example by injecting it at runtime through a server-rendered `window.__env = { ... }` script).
* Private repositories require either a fine-grained personal access token or a GitHub App installation token with `contents:read` permission because the installers are retrieved via the [Contents API](https://docs.github.com/en/rest/repos/contents?apiVersion=2022-11-28#list-repository-contents).
* When using GitHub Enterprise Server, set `NG_APP_GITHUB_API_URL` to your enterprise API endpoint (e.g. `https://ghe.example.com/api/v3`).

Example runtime configuration snippet to inject from the hosting platform:

```html
<script>
  window.__env = {
    NG_APP_GITHUB_OWNER: 'my-org',
    NG_APP_GITHUB_REPO: 'my-repo',
    NG_APP_GITHUB_TOKEN: '<token-with-contents-read>',
    NG_APP_GITHUB_INSTALLERS_BRANCH: 'gh-pages'
  };
</script>
```