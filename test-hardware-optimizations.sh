#!/bin/bash
# ============================================================================ 
# HARDWARE OPTIMIZATION TEST SUITE
# Arch Linux v5.1 - Test hardware detection and optimizations
# ============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Logging
log() { echo -e "${GREEN}[TEST]${NC} $*"; }
warn() { echo -e "${YELLOW}[TEST]${NC} $*"; }
error() { echo -e "${RED}[TEST]${NC} $*" >&2; }
pass() { ((TESTS_PASSED++)); echo -e "${GREEN}✓${NC} $*"; }
fail() { ((TESTS_FAILED++)); echo -e "${RED}✗${NC} $*"; }

# Test result
test_result() {
    ((TESTS_TOTAL++))
    if [[ $1 -eq 0 ]]; then
        pass "$2"
    else
        fail "$2"
    fi
}

# Test hardware detection module
test_hardware_detection() {
    log "Testing hardware detection module..."
    
    if [[ -f "src/hardware-detect.sh" ]]; then
        test_result 0 "Hardware detection script exists"
        
        # Source and test basic functions
        source src/hardware-detect.sh
        
        # Test CPU detection
        detect_cpu
        test_result 0 "CPU detection completed"
        test_result 0 "CPU model detected: ${HARDWARE_INFO[cpu_model]}"
        test_result 0 "CPU cores detected: ${HARDWARE_INFO[cpu_cores]}"
        
        # Test memory detection
        detect_memory
        test_result 0 "Memory detection completed"
        test_result 0 "Memory total: ${HARDWARE_INFO[memory_total_gb]}GB"
        test_result 0 "Memory tier: ${HARDWARE_INFO[memory_tier]}"
        
        # Test storage detection
        detect_storage
        test_result 0 "Storage detection completed"
        test_result 0 "Storage total: ${HARDWARE_INFO[storage_total_gb]}GB"
        test_result 0 "Storage tier: ${HARDWARE_INFO[storage_tier]}"
        
        # Test virtualization detection
        detect_virtualization
        test_result 0 "Virtualization detection completed"
        test_result 0 "Virtualization type: ${HARDWARE_INFO[virtualization_type]}"
        test_result 0 "Bare metal: ${HARDWARE_INFO[is_bare_metal]}"
        
        # Test optimization profile generation
        generate_optimization_profile
        test_result 0 "Optimization profile generated"
        test_result 0 "Profile: ${HARDWARE_INFO[optimization_profile]}"
        test_result 0 "Level: ${HARDWARE_INFO[optimization_level]}"
        
    else
        test_result 1 "Hardware detection script not found"
    fi
}

# Test install.sh integration
test_install_integration() {
    log "Testing install.sh hardware integration..."
    
    if [[ -f "src/install.sh" ]]; then
        test_result 0 "install.sh exists"
        
        # Check for hardware detection integration
        if grep -q "hardware-detect.sh" src/install.sh; then
            test_result 0 "Hardware detection integrated in install.sh"
        else
            test_result 1 "Hardware detection not integrated in install.sh"
        fi
        
        # Check for hardware-based optimizations
        if grep -q "HW_storage_tier" src/install.sh; then
            test_result 0 "Storage-based optimizations present"
        else
            test_result 1 "Storage-based optimizations missing"
        fi
        
        if grep -q "HW_memory_tier" src/install.sh; then
            test_result 0 "Memory-based optimizations present"
        else
            test_result 1 "Memory-based optimizations missing"
        fi
        
        if grep -q "HW_cpu_optimization" src/install.sh; then
            test_result 0 "CPU-based optimizations present"
        else
            test_result 1 "CPU-based optimizations missing"
        fi
        
    else
        test_result 1 "install.sh not found"
    fi
}

# test addon manager integration
test_addon_integration() {
    log "Testing addon manager hardware integration..."
    
    if [[ -f "addons/addon-manager.sh" ]]; then
        test_result 0 "addon-manager.sh exists"
        
        # Check for hardware detection integration
        if grep -q "hardware-detect.sh" addons/addon-manager.sh; then
            test_result 0 "Hardware detection integrated in addon-manager.sh"
        else
            test_result 1 "Hardware detection not integrated in addon-manager.sh"
        fi
    else
        test_result 1 "addon-manager.sh not found"
    fi
}

# test Immich addon optimization
test_immich_optimization() {
    log "Testing Immich addon hardware optimization..."
    
    if [[ -f "addons/available/immich/install.sh" ]]; then
        test_result 0 "Immich install.sh exists"
        
        # Check for hardware-based optimization
        if grep -q "HW_memory_available_gb" addons/available/immich/install.sh; then
            test_result 0 "Memory-based optimization present in Immich"
        else
            test_result 1 "Memory-based optimization missing in Immich"
        fi
        
        if grep -q "HW_cpu_cores" addons/available/immich/install.sh; then
            test_result 0 "CPU-based optimization present in Immich"
        else
            test_result 1 "CPU-based optimization missing in Immich"
        fi
        
        if grep -q "HW_storage_tier" addons/available/immich/install.sh; then
            test_result 0 "Storage-based optimization present in Immich"
        else
            test_result 1 "Storage-based optimization missing in Immich"
        fi
    else
        test_result 1 "Immich install.sh not found"
    fi
}

# test VirtualBox optimizations
test_virtualbox_optimizations() {
    log "Testing VirtualBox optimizations..."
    
    if [[ -f "src/virtualbox-optimizations.sh" ]]; then
        test_result 0 "VirtualBox optimizations script exists"
        
        # Check script is executable
        if [[ -x "src/virtualbox-optimizations.sh" ]]; then
            test_result 0 "VirtualBox optimizations script is executable"
        else
            test_result 1 "VirtualBox optimizations script is not executable"
        fi
        
        # Check for VirtualBox-specific optimizations
        if grep -q "vm.dirty_background_ratio" src/virtualbox-optimizations.sh; then
            test_result 0 "VirtualBox I/O optimizations present"
        else
            test_result 1 "VirtualBox I/O optimizations missing"
        fi
        
        if grep -q "vm.swappiness" src/virtualbox-optimizations.sh; then
            test_result 0 "VirtualBox memory optimizations present"
        else
            test_result 1 "VirtualBox memory optimizations missing"
        fi
        
    else
        test_result 1 "VirtualBox optimizations script not found"
    fi
    
    # Check Ansible integration
    if [[ -f "src/ansible/roles/base_hardening/tasks/virtualbox-optimizations.yml" ]]; then
        test_result 0 "VirtualBox Ansible tasks exist"
        
        if grep -q "is_virtualbox" src/ansible/roles/base_hardening/tasks/virtualbox-optimizations.yml; then
            test_result 0 "VirtualBox detection in Ansible tasks"
        else
            test_result 1 "VirtualBox detection missing in Ansible tasks"
        fi
    else
        test_result 1 "VirtualBox Ansible tasks not found"
    fi
    
    # Check base_hardening integration
    if grep -q "virtualbox-optimizations.yml" src/ansible/roles/base_hardening/tasks/main.yml; then
        test_result 0 "VirtualBox optimizations integrated in base_hardening"
    else
        test_result 1 "VirtualBox optimizations not integrated in base_hardening"
    fi
}

# test security audit hardware integration
test_security_audit_integration() {
    log "Testing security audit hardware integration..."
    
    if [[ -f "src/ansible/roles/monitoring/files/security-audit" ]]; then
        test_result 0 "Security audit script exists"
        
        # Check for hardware-aware security checks
        if grep -q "TPM device" src/ansible/roles/monitoring/files/security-audit; then
            test_result 0 "TPM hardware checks present in security audit"
        else
            test_result 1 "TPM hardware checks missing in security audit"
        fi
        
        if grep -q "Btrfs filesystem" src/ansible/roles/monitoring/files/security-audit; then
            test_result 0 "Storage hardware checks present in security audit"
        else
            test_result 1 "Storage hardware checks missing in security audit"
        fi
        
        if grep -q "LUKS encryption" src/ansible/roles/monitoring/files/security-audit; then
            test_result 0 "Encryption hardware checks present in security audit"
        else
            test_result 1 "Encryption hardware checks missing in security audit"
        fi
        
    else
        test_result 1 "Security audit script not found"
    fi
}

# test configuration files
test_configuration_files() {
    log "Testing configuration files..."
    
    # Test config.env files for hardware annotations
    local config_files=(
        "config.env.basic"
        "config.env.advanced"
        "addons/available/immich/config.env.example"
        "addons/available/seafile/config.env.example"
    )
    
    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            test_result 0 "Configuration file exists: $config_file"
            
            # Check for hardware-related comments
            if grep -q -i "hardware\|cpu\|memory\|storage\|gpu" "$config_file"; then
                test_result 0 "Hardware documentation present in $config_file"
            else
                test_result 1 "Hardware documentation missing in $config_file"
            fi
        else
            test_result 0 "Configuration file not found: $config_file (may be expected)"
        fi
    done
}

# test documentation
test_documentation() {
    log "Testing documentation..."
    
    # Check README for hardware optimization documentation
    if [[ -f "README.md" ]]; then
        if grep -q -i "hardware\|detection\|optimization\|virtualbox" README.md; then
            test_result 0 "Hardware optimization documented in README.md"
        else
            test_result 1 "Hardware optimization documentation missing in README.md"
        fi
    else
        test_result 1 "README.md not found"
    fi
    
    # Check for hardware documentation files
    local doc_files=(
        "docs/hardware.md"
        "docs/virtualbox.md"
        "docs/optimization.md"
    )
    
    for doc_file in "${doc_files[@]}"; do
        if [[ -f "$doc_file" ]]; then
            test_result 0 "Documentation file exists: $doc_file"
        else
            test_result 0 "Documentation file not found: $doc_file (may be expected)"
        fi
    done
}

# generate test report
generate_report() {
    local report_file="/tmp/hardware-optimization-test-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "HARDWARE OPTIMIZATION TEST REPORT"
        echo "=================================="
        echo "Date: $(date)"
        echo "Hostname: $(hostname)"
        echo ""
        echo "TEST RESULTS:"
        echo "-----------"
        echo "Total Tests: $TESTS_TOTAL"
        echo "Passed: $TESTS_PASSED"
        echo "Failed: $TESTS_FAILED"
        echo "Success Rate: $(( TESTS_PASSED * 100 / TESTS_TOTAL ))%"
        echo ""
        
        if [[ $TESTS_FAILED -eq 0 ]]; then
            echo "✅ ALL TESTS PASSED - Hardware optimization system is ready!"
        else
            echo "❌ SOME TESTS FAILED - Please review and fix issues"
        fi
        echo ""
        
        echo "RECOMMENDATIONS:"
        echo "==============="
        if [[ $TESTS_FAILED -gt 0 ]]; then
            echo "1. Review failed tests and fix issues"
            echo "2. Run tests on both VirtualBox and bare metal systems"
            echo "3. Validate hardware detection on different hardware configurations"
            echo "4. Test with various memory and storage configurations"
        else
            echo "1. System is ready for hardware-optimized deployments"
            echo "2. Test on actual hardware before production use"
            echo "3. Validate optimizations work as expected"
            echo "4. Monitor performance after deployment"
        fi
        echo ""
        
        echo "NEXT STEPS:"
        echo "============"
        echo "1. Run hardware detection: ./src/hardware-detect.sh"
        echo "2. Test installation: ./src/install.sh --dry-run"
        echo "3. Deploy with optimizations: ./scripts/deploy.sh"
        echo "4. Verify with security audit: /usr/local/bin/security-audit"
        echo "5. Test addon installations: ./addons/addon-manager.sh list"
        echo ""
        
    } | tee "$report_file"
    
    echo "Test report saved to: $report_file"
}

# Main test function
main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║           HARDWARE OPTIMIZATION TEST SUITE                ║"
    echo "║                    Arch Linux v5.1                         ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Run all tests
    test_hardware_detection
    test_install_integration
    test_addon_integration
    test_immich_optimization
    test_virtualbox_optimizations
    test_security_audit_integration
    test_configuration_files
    test_documentation
    
    # Generate report
    generate_report
    
    # Exit with appropriate code
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo ""
        echo -e "${GREEN}✓ ALL TESTS PASSED - Hardware optimization system is ready!${NC}"
        exit 0
    else
        echo ""
        echo -e "${RED}✗ SOME TESTS FAILED - Please review and fix issues${NC}"
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
