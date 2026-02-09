# Testing Checklist for PR #19: Makefile Build System

This checklist should be completed before merging to ensure the Makefile works correctly across all supported platforms and scenarios.

## Pre-Testing Setup

- [ ] Clean environment: Remove any existing `build/`, `docker/`, `repos/` directories
- [ ] Verify Docker is running and has sufficient resources (150GB+ disk, 8GB+ RAM)

## macOS Testing

### Initial Setup
- [ ] `make setup` completes successfully
- [ ] Docker volumes created: `wendyos-build-scarthgap`, `wendyos-sstate-scarthgap`, `wendyos-downloads-scarthgap`
- [ ] Docker image `wendyos-build:scarthgap` exists

### Build Testing
- [ ] `make build` completes successfully (NVMe target)
- [ ] `make build MACHINE=jetson-orin-nano-devkit-wendyos` works (SD card target)
- [ ] `make deploy` copies tegraflash tarball to `./deploy/`
- [ ] Build artifacts visible in Docker volumes (not host filesystem)

### Flash Testing
- [ ] `make flash-to-external` creates `wendyos.img`
- [ ] FLASH_IMAGE_SIZE validation catches mismatches with local.conf
- [ ] Interactive mode lists external disks correctly
- [ ] Non-interactive mode: `make flash-to-external FLASH_DEVICE=/dev/diskX FLASH_CONFIRM=yes`

### Clean Testing
- [ ] `make clean` removes build artifacts from Docker volume
- [ ] `make clean` preserves downloads and sstate-cache volumes
- [ ] `make distclean` removes all Docker volumes after confirmation
- [ ] Disk space reclaimed after distclean (check `docker system df`)

### Other Targets
- [ ] `make shell` opens interactive shell in container
- [ ] `make help` displays all available targets
- [ ] `make docker-create` rebuilds Docker image if needed

## Linux Testing

### Initial Setup
- [ ] `make setup` completes successfully
- [ ] `repos/`, `build/`, `downloads/`, `sstate-cache/` directories created
- [ ] Docker image `wendyos-build:scarthgap` exists

### Build Testing
- [ ] `make build` completes successfully (NVMe target)
- [ ] `make build MACHINE=jetson-orin-nano-devkit-wendyos` works (SD card target)
- [ ] Build artifacts visible in `./build/tmp/deploy/images/`
- [ ] No volume creation (artifacts on host filesystem)

### Flash Testing
- [ ] `make flash-to-external` creates `wendyos.img`
- [ ] FLASH_IMAGE_SIZE validation catches mismatches with local.conf
- [ ] Interactive mode lists block devices correctly (lsblk output)
- [ ] Non-interactive mode: `make flash-to-external FLASH_DEVICE=/dev/sdX FLASH_CONFIRM=yes`

### Clean Testing
- [ ] `make clean` removes `build/tmp` and `build/cache`
- [ ] `make clean` preserves `downloads/` and `sstate-cache/`
- [ ] `make distclean` removes all directories after confirmation
- [ ] Disk space reclaimed after distclean (check `du -sh`)

### Other Targets
- [ ] `make shell` opens interactive shell in container
- [ ] `make help` displays all available targets
- [ ] `make docker-create` rebuilds Docker image if needed

## Edge Cases & Error Handling

### Setup Failures
- [ ] `make build` without `make setup` shows clear error message
- [ ] Missing Docker image triggers helpful error with recovery steps

### Build Failures
- [ ] Failed build doesn't leave container running
- [ ] Error messages are visible and actionable

### Volume/Permission Issues
- [ ] `_ensure-volumes` catches ownership errors (macOS)
- [ ] Clear error message if Docker volumes can't be created
- [ ] Permission errors provide recovery instructions

### FLASH_IMAGE_SIZE Validation
- [ ] Mismatch between Makefile and local.conf is caught before image creation
- [ ] Error message clearly explains the mismatch
- [ ] Recovery instructions are actionable (update Makefile or local.conf)
- [ ] Test with all sizes: 4GB, 8GB, 16GB, 32GB, 64GB

### Flash Tool Edge Cases
- [ ] Quit option ('q') works in interactive mode
- [ ] Invalid disk names rejected with clear error
- [ ] Missing tegraflash tarball shows "Run 'make build' first" message
- [ ] Confirmation prompt works correctly (case-insensitive y/n)

## Cross-Platform Consistency

- [ ] Same commands work on both macOS and Linux
- [ ] Help messages are consistent
- [ ] Error messages are clear on both platforms
- [ ] Documentation matches actual behavior

## Documentation Verification

- [ ] README.md TL;DR section works as written
- [ ] All make targets listed in README exist
- [ ] Docker volume documentation matches actual behavior (macOS)
- [ ] Troubleshooting section covers common issues

## Performance & Resource Usage

- [ ] Clean build completes in reasonable time (2-4 hours first build)
- [ ] Incremental builds use sstate-cache effectively
- [ ] Docker Desktop doesn't run out of disk space during build
- [ ] Memory usage stays within Docker Desktop allocation

## Regression Testing

- [ ] Previous workflow (manual bootstrap + docker-util.sh) still works
- [ ] Existing users can transition from old to new workflow
- [ ] No breaking changes for users who have already built images

## Notes

- macOS testing requires Docker Desktop 4.0+
- Linux testing should cover both Ubuntu and other distributions if possible
- Test with both clean slate and existing build artifacts
- Verify all error messages provide actionable recovery steps
- Check that colors/formatting display correctly in terminal
