#!/usr/bin/env bash
set -e

# ==============================================================================
# CarLog Platform - Universal Server Deployment Script (cPanel & Enhance Panel)
# Automatically syncs backend files to public_html/karkare
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== CarLog Platform: Initializing Deployment to public_html/karkare ==="

CANDIDATE_ROOTS=("../.." ".." "." "$HOME")
DEPLOYED=false

for ROOT in "${CANDIDATE_ROOTS[@]}"; do
    ABS_ROOT="$(cd "$ROOT" 2>/dev/null && pwd || true)"
    if [ -n "$ABS_ROOT" ] && [ -d "$ABS_ROOT/public_html" ] && [ "$ABS_ROOT/public_html" != "$SCRIPT_DIR/public_html" ]; then
        TARGET="$ABS_ROOT/public_html/karkare"
        echo "-> Detected live webroot at: $ABS_ROOT/public_html"
        echo "-> Deploying to: $TARGET"
        
        mkdir -p "$TARGET"
        cp -rf backend/* "$TARGET/" 2>/dev/null || true
        cp -f backend/.htaccess "$TARGET/" 2>/dev/null || true
        cp -f backend/index.php "$TARGET/" 2>/dev/null || true
        mkdir -p "$TARGET/uploads"
        chmod 755 "$TARGET/uploads" 2>/dev/null || true
        
        echo "-> CarLog successfully deployed to $TARGET"
        DEPLOYED=true
        break
    fi
done

if [ "$DEPLOYED" = false ]; then
    echo "Notice: Standalone environment. Files ready in backend/."
fi

exit 0
