#!/bin/bash
set -euo pipefail
"$(node -e "process.stdout.write(require('puppeteer').executablePath())")" --no-sandbox "$@"
