# C2 Enumeration Toolkit - Changelog

## [2.1-enhanced] - 2025-10-02

### 🎯 Major Addition: Port Scanning & Enhanced Reachability

**Problem Addressed:** Sites don't appear to be live - needed better port checking

### Added
- **Multi-protocol reachability testing** - Tests both HTTP and HTTPS automatically
- **Multi-port auto-discovery** - Tries 6 common ports (80, 443, 8080, 8443, 9000, 9001)
- **Comprehensive port scanner** - Full 12-port scan with service fingerprinting
- **Quick reachability menu option** - Main menu option "R" for fast testing
- **Port scanner in advanced menu** - Dedicated port scanning option
- **Working config caching** - Saves discovered protocol/port combinations
- **Detailed scan reports** - Per-target port scan results with statistics

### Enhanced
- `test_onion_reachable()` - Now tries multiple protocols and ports
- Advanced menu - Added "Port-Scanner" as first option
- Deep scan - Now includes port scanning
- Reachability feedback - Shows each protocol/port attempt

### Documentation
- **PORT-SCANNING.md** - Comprehensive port scanning guide (11KB)
- Updated README.md with port scanning features
- Updated QUICKSTART.md with new menu options

### Technical Details
- **New function:** `scan_onion_ports()` - Lines 290-358
- **Enhanced function:** `test_onion_reachable()` - Lines 229-288
- **Script size:** 1,481 lines (+141 from v2.0)
- **New menu options:** 17 total (+1)

### Ports Scanned
**Auto-Discovery (reachability):**
- 80, 443, 8080, 8443, 9000, 9001

**Full Port Scanner:**
- Web: 80, 443, 8080, 8443
- Custom: 9000, 9001
- Admin: 22, 21
- Databases: 3306, 5432, 6379, 27017

---

## [2.0-enhanced] - 2025-10-02

### 🚀 Complete Rewrite & Enhancement

### Added
- **Dependency validation system** - Checks and warns about missing tools
- **Enhanced Tor connectivity** - API-based verification with exit node display
- **Retry logic** - 2-3 retries for all network operations
- **PCAP enhancements** - Production-ready with stats and duration tracking
- **Parallel processing** - Job control for efficient enumeration
- **Comprehensive static analysis** - ELF headers, symbols, intelligent string filtering
- **JSON export** - Machine-readable reports via jq
- **Summary dashboard** - Visual session overview
- **Advanced modules** - Certificate analysis, deep scanning options
- **Progress indicators** - Timed with success/failure feedback

### Enhanced
- Network helpers with better error handling
- Core enumeration with 18 common paths (was 9)
- TUI menus with status bar
- PCAP capture with multi-tool support
- Static analysis with comprehensive binary inspection
- Advanced menu with "run all" option

### Documentation
- **README.md** - Toolkit overview (6.7KB)
- **QUICKSTART.md** - Comprehensive user guide (8.6KB)
- **ENHANCEMENTS.md** - Technical documentation (11KB)

### Technical Details
- **Script size:** 1,340 lines (2.74x original)
- **Functions:** 45+ (vs ~20 original)
- **Menu options:** 16 (vs 11 original)
- **Tool integrations:** 17 (vs 12 original)

---

## [1.0-original] - Original Version

### Features
- Basic TUI enumeration
- Simple PCAP capture
- Basic static analysis
- 11 menu options
- 489 lines

### Known Targets
- wtxqf54djhp5pskv2lfyduub5ievxbyvlzjgjopk6hxge5umombr63ad.onion
- 2hdv5kven4m422wx4dmqabotumkeisrstzkzaotvuhwx3aebdig573qd.onion:9000

---

## Version Comparison

| Feature | v1.0 | v2.0 | v2.1 |
|---------|------|------|------|
| Script Size | 489 | 1,340 | 1,481 |
| Functions | ~20 | 45+ | 47+ |
| Menu Options | 11 | 16 | 17 |
| Dependency Check | ❌ | ✅ | ✅ |
| Tor Verification | Basic | API-based | API-based |
| Retry Logic | ❌ | ✅ | ✅ |
| PCAP Stats | ❌ | ✅ | ✅ |
| Parallel Jobs | ❌ | ✅ | ✅ |
| JSON Export | ❌ | ✅ | ✅ |
| Dashboard | ❌ | ✅ | ✅ |
| Port Scanning | ❌ | ❌ | ✅ |
| Multi-Protocol | ❌ | ❌ | ✅ |
| Documentation | 0 files | 3 files | 4 files |

---

## Upgrade Notes

### From v1.0 to v2.1
- All original functionality preserved
- No breaking changes to command-line arguments
- New features are opt-in via menu
- Auto-enumeration behavior unchanged

### Performance Impact
- Reachability checks add 10-30s per target (best case)
- Port scanning adds 60-90s per target (optional)
- Use "R" menu option for quick checks before full enumeration

### Migration
No migration needed - v2.1 is backward compatible:
```bash
# Old usage still works
./c2-enum-tui.sh

# New features available via menus
# Press R for quick reachability
# Press A for port scanner
```

---

## Roadmap

### Planned Features (v2.2)
- [ ] Custom port list configuration
- [ ] Bulk target import from file
- [ ] Automated target discovery
- [ ] Integration with threat intel feeds
- [ ] Historical trend tracking
- [ ] Web-based results viewer

### Under Consideration
- [ ] Plugin system for custom analyzers
- [ ] Real-time monitoring mode
- [ ] Network graph visualization
- [ ] MISP integration
- [ ] Automated alert system

---

## Contributors

Enhanced by Claude Code (Anthropic)
For defensive security research purposes only

## License

Use responsibly for defensive security research only.
