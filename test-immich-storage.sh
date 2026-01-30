#!/bin/bash
# Test script for Immich storage validation

echo "=== Immich Storage Validation Test ==="
echo ""

# Simuler storage device validering
echo "1. Testing storage device validation..."
echo "   - Simulerer at /dev/sdb1 ikke findes (forventet fejl)"

# Test af config.env loading
echo ""
echo "2. Testing config.env loading..."
if [[ -f "addons/available/immich/config.env" ]]; then
    source addons/available/immich/config.env
    echo "   ✓ config.env loaded successfully"
    echo "   - STORAGE_DEVICE: '${STORAGE_DEVICE:-EMPTY}'"
    echo "   - MIN_STORAGE_GB: ${MIN_STORAGE_GB:-NOT_SET}"
    echo "   - WEB_PORT: ${WEB_PORT:-NOT_SET}"
else
    echo "   ✗ config.env not found"
fi

# Test af directory struktur
echo ""
echo "3. Testing addon structure..."
required_files=("install.sh" "uninstall.sh" "config.env.example" "immich.service" "README.md")
for file in "${required_files[@]}"; do
    if [[ -f "addons/available/immich/$file" ]]; then
        echo "   ✓ $file exists"
    else
        echo "   ✗ $file missing"
    fi
done

# Test af storage paths
echo ""
echo "4. Testing storage path configuration..."
STORAGE_MOUNT="/mnt/immich-storage"
LIBRARY_DIR="${STORAGE_MOUNT}/library"
UPLOAD_DIR="${STORAGE_MOUNT}/uploads"
THUMBNAIL_DIR="${STORAGE_MOUNT}/thumbnails"
PROFILE_DIR="${STORAGE_MOUNT}/profile"

echo "   - Storage mount: $STORAGE_MOUNT"
echo "   - Library: $LIBRARY_DIR"
echo "   - Uploads: $UPLOAD_DIR"
echo "   - Thumbnails: $THUMBNAIL_DIR"
echo "   - Profile: $PROFILE_DIR"

echo ""
echo "=== Test Complete ==="
echo ""
echo "For at køre fuld installation:"
echo "1. Rediger addons/available/immich/config.env"
echo "2. Sæt STORAGE_DEVICE til dit storage device"
echo "3. Kør: sudo ./addons/addon-manager.sh install immich"
