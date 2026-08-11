#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT HUP INT TERM
settings=$test_root/settings.xml
manifest=$test_root/definitions.conf

cat >"$settings" <<'EOF'
<romraider>
  <files>
  </files>
  <logger>
  </logger>
</romraider>
EOF
cat >"$manifest" <<'EOF'
EDITOR_DEFINITION=/tmp/editor & <metric> "test" 'one'.xml
LOGGER_DEFINITION=/tmp/logger & <metric> "test" 'two'.xml
EOF

ROMRAIDER_SETTINGS="$settings" ROMRAIDER_DEFINITIONS_MANIFEST="$manifest" \
    "$repo_root/linux/configure-romraider-definitions"

grep -F 'name="/tmp/editor &amp; &lt;metric&gt; &quot;test&quot; &apos;one&apos;.xml"' \
    "$settings" >/dev/null
grep -F 'path="/tmp/logger &amp; &lt;metric&gt; &quot;test&quot; &apos;two&apos;.xml"' \
    "$settings" >/dev/null
if command -v xmllint >/dev/null 2>&1; then
    xmllint --noout "$settings"
fi

echo 'RomRaider settings tests passed.'
