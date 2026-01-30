#!/bin/bash
# Test script for Seafile storage validation

echo "=== Seafile Storage Validation Test ==="
echo ""

# Simuler storage device validering
echo "1. Testing storage device validation..."
echo "   - Simulerer at /dev/sdc1 ikke findes (forventet fejl)"

# Test af config.env loading
echo ""
echo "2. Testing config.env loading..."
if [[ -f "addons/available/seafile/config.env" ]]; then
    source addons/available/seafile/config.env
    echo "   ✓ config.env loaded successfully"
    echo "   - STORAGE_DEVICE: '${STORAGE_DEVICE:-EMPTY}'"
    echo "   - MIN_STORAGE_GB: ${MIN_STORAGE_GB:-NOT_SET}"
    echo "   - WEB_PORT: ${WEB_PORT:-NOT_SET}"
    echo "   - FILE_SERVER_PORT: ${FILE_SERVER_PORT:-NOT_SET}"
    echo "   - ADMIN_EMAIL: ${ADMIN_EMAIL:-NOT_SET}"
else
    echo "   ✗ config.env not found"
fi

# Test af directory struktur
echo ""
echo "3. Testing addon structure..."
required_files=("install.sh" "uninstall.sh" "config.env.example" "seafile.service" "README.md")
for file in "${required_files[@]}"; do
    if [[ -f "addons/available/seafile/$file" ]]; then
        echo "   ✓ $file exists"
    else
        echo "   ✗ $file missing"
    fi
done

# Test af storage paths
echo ""
echo "4. Testing storage path configuration..."
STORAGE_MOUNT="/mnt/seafile-storage"
SEAFILE_DATA_DIR="${STORAGE_MOUNT}/seafile-data"
CCNET_DIR="${STORAGE_MOUNT}/ccnet"
CONF_DIR="${STORAGE_MOUNT}/conf"
SEAFILE_DIR="${STORAGE_MOUNT}/seafile"
SEAHUB_DIR="${STORAGE_MOUNT}/seahub-data"

echo "   - Storage mount: $STORAGE_MOUNT"
echo "   - Seafile data: $SEAFILE_DATA_DIR"
echo "   - CCNET: $CCNET_DIR"
echo "   - Config: $CONF_DIR"
echo "   - Seafile server: $SEAFILE_DIR"
echo "   - Seahub data: $SEAHUB_DIR"

# Test af Seafile specifikke indstillinger
echo ""
echo "5. Testing Seafile specific configuration..."
echo "   - Max upload size: ${MAX_UPLOAD_SIZE:-NOT_SET} MB"
echo "   - Max files: ${MAX_NUMBER_OF_FILES:-NOT_SET}"
echo "   - File history: ${ENABLE_FILE_HISTORY:-NOT_SET}"
echo "   - History retention: ${FILE_HISTORY_KEEP_DAYS:-NOT_SET} days"
echo "   - Timezone: ${TIMEZONE:-NOT_SET}"

echo ""
echo "=== Test Complete ==="
echo ""
echo "For at køre fuld installation:"
echo "1. Rediger addons/available/seafile/config.env"
echo "2. Sæt STORAGE_DEVICE til dit storage device"
echo "3. Sæt ADMIN_EMAIL til din admin email"
echo "4. Kør: sudo ./addons/addon-manager.sh install seafile"
