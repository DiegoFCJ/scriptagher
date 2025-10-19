#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR=${1:-bot-sources}
OUTPUT_DIR=${2:-build/botlist}

# Prepare output directory structure
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/bots"

metadata_file=$(mktemp)
: > "$metadata_file"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "[botlist] Nessuna directory sorgente trovata in '$SOURCE_DIR'. Verrà generata una botlist vuota." >&2
else
  for platform_dir in "$SOURCE_DIR"/*; do
    [ -d "$platform_dir" ] || continue
    platform="$(basename "$platform_dir")"

    for bot_dir in "$platform_dir"/*; do
      [ -d "$bot_dir" ] || continue
      bot_name="$(basename "$bot_dir")"
      manifest_path="$bot_dir/Bot.json"

      if [ ! -f "$manifest_path" ]; then
        echo "[botlist] Avviso: nessun Bot.json trovato per $platform/$bot_name, salto." >&2
        continue
      fi

      zip_rel_path="bots/$platform/$bot_name.zip"
      manifest_rel_path="bots/$platform/$bot_name.json"
      zip_out_path="$OUTPUT_DIR/$zip_rel_path"
      manifest_out_path="$OUTPUT_DIR/$manifest_rel_path"

      mkdir -p "$(dirname "$zip_out_path")"

      tmp_dir=$(mktemp -d)
      cp -R "$bot_dir" "$tmp_dir/$bot_name"
      (cd "$tmp_dir" && zip -qr "$zip_out_path" "$bot_name")
      rm -rf "$tmp_dir"

      if command -v sha256sum >/dev/null 2>&1; then
        archive_sha=$(sha256sum "$zip_out_path" | awk '{print $1}')
      else
        archive_sha=$(shasum -a 256 "$zip_out_path" | awk '{print $1}')
      fi
      if archive_size=$(stat -c%s "$zip_out_path" 2>/dev/null); then
        :
      else
        archive_size=$(stat -f%z "$zip_out_path")
      fi

      mkdir -p "$(dirname "$manifest_out_path")"
      jq --arg sha "$archive_sha" \
         --arg url "$zip_rel_path" \
         --argjson size "$archive_size" \
         '.archiveSha256 = $sha
          | .archiveUrl = $url
          | .archiveSize = $size' "$manifest_path" > "$manifest_out_path"

      echo "$platform|$bot_name|$zip_rel_path|$manifest_rel_path|$archive_sha|$archive_size" >> "$metadata_file"
    done
  done
fi

bots_json="[]"

while IFS='|' read -r platform bot_name zip_rel manifest_rel archive_sha archive_size; do
  [ -n "${platform:-}" ] || continue
  manifest_out_path="$OUTPUT_DIR/$manifest_rel"
  bots_json=$(jq \
    --arg platform "$platform" \
    --arg name "$bot_name" \
    --arg zip "$zip_rel" \
    --arg manifest "$manifest_rel" \
    --arg sha "$archive_sha" \
    --arg size "$archive_size" \
    --slurpfile manifestJson "$manifest_out_path" \
    '. + [{
      platform: $platform,
      name: $name,
      archiveUrl: $zip,
      manifestUrl: $manifest,
      archiveSha256: $sha,
      archiveSize: ($size | tonumber),
      manifest: $manifestJson[0]
    }]' <<< "$bots_json")
done < "$metadata_file"

rm -f "$metadata_file"

jq -n \
  --arg generatedAt "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --argjson bots "$bots_json" \
  '{generatedAt: $generatedAt, bots: $bots}' > "$OUTPUT_DIR/botlist.json"

printf '[botlist] Generazione completata in %s\n' "$OUTPUT_DIR" >&2
