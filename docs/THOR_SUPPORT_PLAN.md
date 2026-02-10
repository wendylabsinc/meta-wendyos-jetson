# Thor AGX Support Plan for WendyOS

**Status**: Planning Phase
**Created**: 2026-02-10
**Target Hardware**: NVIDIA Jetson AGX Thor Developer Kit (T264 SoC)
**Priority**: Future Development

---

## Executive Summary

Adding support for NVIDIA Jetson AGX Thor to WendyOS requires significant changes due to:
- Different Yocto release (Whinlatter 5.3 vs current Scarthgap 5.0 LTS)
- New L4T version (R38.x vs current R36.4.4)
- Different SoC architecture (T264 Neoverse V3AE vs T234 Cortex-A78AE)
- Non-LTS Yocto support timeline (expires May 2026)

**Recommended Approach**: Create separate development branch, wait for Yocto 6.0 LTS (April 2026) for production stability.

---

## Current State Analysis

### WendyOS (Orin Platform)
- **Yocto Version**: Scarthgap 5.0 LTS (April 2024)
- **Support Until**: April 2028 (4-year LTS)
- **L4T Version**: R36.4.4 (JetPack 6.1)
- **SoC**: Tegra234 (Orin) - 12x Cortex-A78AE cores
- **meta-tegra Branch**: `scarthgap`
- **Status**: Production-ready, stable

### Thor Platform Requirements
- **Yocto Version**: Whinlatter 5.3 (October 2025)
- **Support Until**: May 2026 (7-month non-LTS)
- **L4T Version**: R38.2.2 (JetPack 7.0) or R38.4.0 (JetPack 7.1)
- **SoC**: Tegra264 (Thor) - Neoverse V3AE cores (ARMv9-A)
- **meta-tegra Branch**: `master-l4t-r38.2.x` or `wip-l4t-r38.4.0`
- **Status**: Development/evaluation only (Thor released August 2025)

---

## The Timeline Problem

### Release Timeline
```
April 2024:  Yocto Scarthgap 5.0 LTS released
             └─ Supported until April 2028

August 2025: Jetson AGX Thor + JetPack 7.0 released
             └─ Targets Yocto Whinlatter 5.3

October 2025: Yocto Whinlatter 5.3 released
              └─ Supported until May 2026 (4 months from now!)

April 2026:  Yocto 6.0 LTS expected
             └─ Next 4-year LTS release
```

### Why Thor Isn't on LTS

When Thor launched (August 2025), Scarthgap LTS was already 16 months old. Meta-tegra maintainers chose to target the current Yocto release (Whinlatter) rather than backport bleeding-edge hardware to an older LTS.

**Challenges with LTS backport:**
- Thor requires Linux 6.8 LTS kernel, Scarthgap ships 6.6
- Thor firmware built with newer toolchain (gcc 14.2, glibc 2.40)
- T264 architecture differences from T234
- NVIDIA's L4T R38 components not tested against older Yocto

---

## Strategic Options

### Option A: Separate Branch on Non-LTS (Pragmatic)

**Description**: Create `feature/thor-whinlatter` branch using Yocto Whinlatter 5.3.

**Timeline**: 2-4 weeks for initial bring-up

**Pros**:
- Fastest path to Thor support
- Matches meta-tegra's official support
- Can evaluate hardware immediately
- Orin remains stable on LTS

**Cons**:
- Non-LTS expires May 2026 (4 months)
- Must upgrade to 5.4, 5.5, 6.0 as they release
- Production risk - frequent updates required
- Maintain two branches (Orin + Thor)

**Best For**: Development, evaluation, demos, early access programs

**Effort Estimate**:
- Week 1: Setup (repos, Docker, bootstrap)
- Week 2: Initial boot, basic functionality
- Week 3-4: Feature parity (Mender, containers, networking)
- Week 5-6: Testing and validation

---

### Option B: Wait for Yocto 6.0 LTS (Conservative)

**Description**: Wait ~2 months for Yocto 6.0 LTS (April 2026), then create Thor support.

**Timeline**: Begin April 2026, complete May-June 2026

**Pros**:
- 4-year LTS stability (April 2026 - April 2030)
- Production-ready from day 1
- Meta-tegra likely to create LTS branch
- Align with next major WendyOS version

**Cons**:
- 2-month wait before starting
- Risk: meta-tegra may not create LTS branch immediately
- Thor evaluation delayed
- May miss market opportunities

**Best For**: Production deployments, enterprise customers, long-term products

**Effort Estimate**:
- April 2026: Wait for Yocto 6.0 LTS release
- May 2026: Wait for meta-tegra 6.0 branch (if available)
- June 2026: 2-4 weeks implementation
- July 2026: Testing and validation

---

### Option C: Backport to Scarthgap LTS (Heroic)

**Description**: Create `scarthgap-l4t-r38.x` branch by backporting Thor support to Scarthgap.

**Timeline**: 2-3 months of intensive development

**Pros**:
- Thor gets LTS stability immediately
- Single Yocto version for all platforms
- Production-ready if successful
- Contribution to meta-tegra community

**Cons**:
- **Massive effort** - kernel, toolchain, firmware backports
- Against meta-tegra development model
- Maintenance burden (all upstream fixes need backport)
- May break on corner cases
- Unofficial/unsupported configuration

**Best For**: Organizations with dedicated Yocto expertise and urgent production needs

**Effort Estimate**:
- Week 1-2: Linux kernel 6.8 backport to Scarthgap
- Week 3-4: Toolchain updates (gcc, glibc)
- Week 5-6: L4T R38 firmware integration
- Week 7-8: T264 machine configuration
- Week 9-10: Testing and debugging
- Week 11-12: Feature parity and validation

**Risk**: Very high - may encounter unsolvable compatibility issues

---

## Recommended Approach

### Phase 1: Immediate (Now - April 2026)

**Keep Orin Stable**
- Maintain current Scarthgap LTS setup for Orin
- Continue production use on stable platform
- Version: WendyOS 0.11.x series

**Optional Thor Evaluation Branch**
- If Thor hardware arrives before April 2026:
  - Create `feature/thor-whinlatter` branch
  - Use for evaluation and testing only
  - Accept non-LTS status as temporary
  - Document limitations clearly

### Phase 2: LTS Migration (April-June 2026)

**Wait for Yocto 6.0 LTS**
- April 2026: Yocto 6.0 LTS releases
- Monitor meta-tegra for Thor LTS branch
- If available: Create production Thor branch
- Version: WendyOS 0.12.0 (Thor support)

**Migration Path**:
```
Current:  Orin on Scarthgap 5.0 LTS
          └─ WendyOS 0.11.x

April 26: Thor on Yocto 6.0 LTS (if meta-tegra supports)
          └─ WendyOS 0.12.0

Future:   Consider migrating Orin to 6.0 LTS
          └─ WendyOS 1.0.0 (unified)
```

### Phase 3: Long-Term (2026+)

**Unified Platform Strategy**
- Once Thor is on LTS, consider migrating Orin to same LTS
- Maintain single codebase for both platforms
- Shared features, easier maintenance
- Version: WendyOS 1.0.0+

---

## Technical Requirements

### Hardware Differences

| Feature | Orin (T234) | Thor (T264) |
|---------|-------------|-------------|
| CPU | 12x Cortex-A78AE | Neoverse V3AE (ARMv9-A) |
| CUDA Arch | sm_87 | sm_110 |
| CUDA Version | 12.6 | 13.0 |
| TensorRT | 10.3 | 10.13 |
| cuDNN | 9.3 | 9.12 |
| Linux Kernel | 6.1 LTS | 6.8 LTS |
| Boot | UEFI | UEFI |
| Storage | NVMe/eMMC | NVMe (QSPI boot) |

### Software Stack Changes

**Core System**:
- Yocto Project 5.3 (Whinlatter) → 6.0 (next LTS)
- Linux kernel 6.8 LTS
- GCC 14.2, glibc 2.40
- systemd 256+

**BSP Updates**:
- meta-tegra: master-l4t-r38.2.x or r38.4.0
- L4T R38.x firmware and drivers
- New partition layouts (T264-specific)
- Updated flash scripts

**AI/ML Stack**:
- CUDA 13.0
- cuDNN 9.12
- TensorRT 10.13
- DeepStream 7.x (if available)

**WendyOS Features to Validate**:
- Mender 5.0.x OTA updates
- UEFI capsule updates (bootloader)
- Container runtime (containerd)
- NVIDIA Container Toolkit
- PipeWire audio
- NetworkManager
- USB gadget mode
- Custom identity/hostname

---

## Implementation Steps (Option A: Non-LTS Branch)

### 1. Repository Setup (Week 1)

```bash
# Create Thor development branch
cd meta-wendyos-jetson
git checkout main
git checkout -b feature/thor-whinlatter

# Update bootstrap.sh for Thor
# - Change YOCTO_BRANCH="scarthgap" to "master"
# - Add Thor machine configs
# - Update layer versions

# Create Thor machine configuration
conf/machine/jetson-agx-thor-devkit-wendyos.conf
```

### 2. Layer Version Updates (Week 1)

Update all layer versions in `bootstrap.sh`:

```bash
# Yocto/OE Core
poky: master (whinlatter)
meta-openembedded: master (whinlatter)

# NVIDIA
meta-tegra: master-l4t-r38.2.x or wip-l4t-r38.4.0

# Mender
meta-mender: master (verify 5.0.x compatibility)

# Python
meta-python: master
```

### 3. Machine Configuration (Week 1)

Create `conf/machine/jetson-agx-thor-devkit-wendyos.conf`:

```bitbake
#@TYPE: Machine
#@NAME: Nvidia AGX Thor Developer Kit (WendyOS)
#@DESCRIPTION: WendyOS for Nvidia AGX Thor dev kit with NVMe boot

require conf/machine/jetson-agx-thor-devkit.conf

# WendyOS-specific settings
DISTRO = "wendyos"

# Use redundant A/B layout for Mender
USE_REDUNDANT_FLASH_LAYOUT = "1"

# NVMe boot configuration
TNSPEC_BOOTDEV = "nvme0n1p1"
TEGRAFLASH_NO_INTERNAL_STORAGE = "1"

# Flash image size
WENDYOS_FLASH_IMAGE_SIZE = "64GB"
```

### 4. Distro Configuration Updates (Week 1-2)

Update `conf/distro/wendyos.conf`:
- Add Thor-specific L4T version include
- Update CUDA/TensorRT versions
- Validate Mender compatibility

Create `conf/distro/include/l4t-r38-2-2.conf`:
```bitbake
# L4T R38.2.2 Version Pinning
L4T_VERSION = "38.2.2"
L4T_BSP_VERSION = "r38.2.2"
CUDA_VERSION = "13.0"
CUDNN_VERSION = "9.12.0"
TENSORRT_VERSION = "10.13.0"
```

### 5. Build and Test (Week 2)

```bash
# Setup and build
make setup DOCKER_TAG=whinlatter
make build MACHINE=jetson-agx-thor-devkit-wendyos

# Flash and test
make flash-to-external
```

### 6. Feature Validation (Week 3-4)

Test all WendyOS features on Thor:
- [ ] Boot to login prompt
- [ ] Network connectivity (Ethernet, WiFi)
- [ ] USB gadget mode
- [ ] Container runtime
- [ ] NVIDIA Container Toolkit
- [ ] CUDA/TensorRT inference
- [ ] Audio (PipeWire)
- [ ] Mender OTA updates
- [ ] UEFI capsule updates
- [ ] System monitoring (jtop)
- [ ] Custom hostname/identity

### 7. Documentation (Week 4)

- Update README.md with Thor support
- Document Yocto version differences
- Add Thor-specific troubleshooting
- Update TESTING_CHECKLIST.md

---

## Implementation Steps (Option B: Wait for LTS)

### April 2026: Monitor Releases

- [ ] Watch Yocto Project for 6.0 LTS release
- [ ] Monitor meta-tegra for Thor LTS branch
- [ ] Review release notes and migration guides

### May 2026: Evaluate and Plan

- [ ] Assess meta-tegra Thor support on 6.0 LTS
- [ ] Review breaking changes from 5.0 to 6.0
- [ ] Create detailed migration plan

### June 2026: Implementation

Follow Option A steps but on Yocto 6.0 LTS:
- 2 weeks: Setup and bring-up
- 2 weeks: Feature parity
- 2 weeks: Testing and validation

---

## Risk Assessment

### Option A Risks (Non-LTS)

| Risk | Impact | Mitigation |
|------|--------|------------|
| Whinlatter support expires May 2026 | High | Plan upgrade to 6.0 LTS |
| Frequent Yocto updates required | Medium | Automated testing, CI/CD |
| Two branches to maintain | Medium | Share common recipes |
| Production instability | High | Development only until LTS |

### Option B Risks (Wait for LTS)

| Risk | Impact | Mitigation |
|------|--------|------------|
| meta-tegra may not create LTS branch | High | Fallback to Option A |
| 2-month delay | Medium | Use time for Orin testing |
| Market opportunity loss | Medium | Evaluate competitive landscape |

### Option C Risks (Backport)

| Risk | Impact | Mitigation |
|------|--------|------------|
| Massive development effort | High | Dedicated team required |
| Unsupported configuration | High | Thorough testing required |
| Maintenance burden | High | Consider Option B instead |
| May not be feasible | Critical | Abandon if blocked |

---

## Resource Requirements

### Option A (Non-LTS Branch)
- **Developer Time**: 1 person, 4-6 weeks
- **Hardware**: Jetson AGX Thor DevKit
- **Infrastructure**: NVMe storage, development workstation
- **Expertise**: Yocto, L4T, embedded Linux

### Option B (Wait for LTS)
- **Developer Time**: 1 person, 4-6 weeks (starting April 2026)
- **Hardware**: Jetson AGX Thor DevKit
- **Infrastructure**: Same as Option A
- **Expertise**: Same as Option A

### Option C (Backport to LTS)
- **Developer Time**: 2-3 people, 8-12 weeks
- **Hardware**: Same as Option A
- **Infrastructure**: Additional CI/CD infrastructure
- **Expertise**: Advanced Yocto, kernel development, toolchain

---

## Success Criteria

### Minimum Viable Product (MVP)
- [ ] Thor boots to login prompt
- [ ] Network connectivity works
- [ ] Can run containerized applications
- [ ] Basic system monitoring available

### Feature Parity with Orin
- [ ] All WendyOS features work on Thor
- [ ] Mender OTA updates functional
- [ ] CUDA/TensorRT inference working
- [ ] Container pass-through (GPU, devices) working
- [ ] Audio system operational
- [ ] USB gadget mode functional

### Production Ready
- [ ] LTS Yocto support (6.0 or later)
- [ ] Comprehensive testing completed
- [ ] Documentation updated
- [ ] CI/CD pipeline integrated
- [ ] Support procedures documented

---

## Decision Matrix

| Criteria | Option A (Non-LTS) | Option B (Wait LTS) | Option C (Backport) |
|----------|-------------------|---------------------|---------------------|
| Time to Market | ✅ Fast (4-6 weeks) | ⚠️ Delayed (4 months) | ❌ Slow (3 months) |
| LTS Stability | ❌ Non-LTS | ✅ 4-year LTS | ✅ 4-year LTS |
| Effort Required | ✅ Low | ✅ Low | ❌ Very High |
| Production Ready | ❌ Development only | ✅ Yes | ⚠️ Maybe |
| Maintenance | ⚠️ Frequent updates | ✅ Stable | ❌ High burden |
| Risk | ⚠️ Medium | ✅ Low | ❌ Very High |
| **Recommendation** | For evaluation | **For production** | Not recommended |

---

## Recommendation

### Immediate Action (Feb-April 2026)

**Do NOT add Thor support yet.** Instead:

1. **Focus on Orin stability**
   - Complete current PR #19 (Makefile build system)
   - Test and validate WendyOS 0.11.0
   - Document known issues and workflows

2. **Monitor Thor ecosystem**
   - Watch meta-tegra for LTS branch announcements
   - Track Yocto 6.0 LTS release (April 2026)
   - Evaluate Thor hardware if available (informal testing)

3. **Prepare for Thor**
   - Document current architecture
   - Identify Thor-specific challenges
   - Plan resource allocation for Q2 2026

### Next Steps (April-June 2026)

When Yocto 6.0 LTS releases:

1. **Evaluate meta-tegra support**
   - Check for `scarthgap-l4t-r38.x` or `6.0-l4t-r38.x` branch
   - Review support status and community feedback

2. **Decision point**:
   - If LTS branch exists → Implement Option B
   - If no LTS branch → Consider Option A for evaluation only

3. **Implementation**
   - Follow steps outlined above
   - Target WendyOS 0.12.0 release with Thor support
   - Maintain Orin on current LTS

---

## Timeline Summary

```
Now (Feb 2026):
  └─ Complete PR #19, stabilize Orin builds

March 2026:
  └─ Testing and validation on Orin
  └─ Monitor Yocto/meta-tegra for 6.0 LTS

April 2026:
  └─ Yocto 6.0 LTS releases
  └─ Evaluate meta-tegra Thor support
  └─ Decision: Wait or start non-LTS branch

May-June 2026:
  └─ Implement Thor support (4-6 weeks)
  └─ WendyOS 0.12.0 with Thor support

July 2026+:
  └─ Production testing and validation
  └─ Consider unified platform strategy
```

---

## References

### NVIDIA Documentation
- JetPack 7.0 Release Notes: https://developer.nvidia.com/embedded/jetpack
- Jetson Thor Developer Guide: https://developer.ridgerun.com/wiki/index.php/NVIDIA_Jetson_AGX_Thor/JetPack_7.0
- L4T R38.2 Documentation: NVIDIA Developer Forums

### Yocto Project
- Scarthgap 5.0 LTS: https://docs.yoctoproject.org/migration-guides/migration-5.0.html
- Whinlatter 5.3: https://docs.yoctoproject.org/dev/migration-guides/release-notes-5.3.html
- Release Schedule: https://wiki.yoctoproject.org/wiki/Releases

### meta-tegra
- Repository: https://github.com/OE4T/meta-tegra
- Thor Branch: master-l4t-r38.2.x
- Community: https://github.com/OE4T/meta-tegra/discussions

### WendyOS Internal
- Current Makefile build system: PR #19
- Orin machine configs: conf/machine/jetson-orin-nano-devkit-*-wendyos.conf
- Distro configuration: conf/distro/wendyos.conf

---

## Appendix: Thor Machine Specification

### Jetson AGX Thor Developer Kit
- **Module**: P3834-0008
- **Carrier**: P4071-0000
- **SoC**: Tegra264 (Thor)
- **CPU**: Neoverse V3AE cores (ARMv9-A)
- **GPU**: NVIDIA Ampere architecture
- **Memory**: LPDDR5X
- **Storage**: NVMe (QSPI boot)
- **Networking**: PCIe Ethernet
- **WiFi**: RTL8852CE
- **USB**: USB 3.2, Type-C
- **Display**: DP 2.1
- **Power**: 19V DC

### Software Support
- **JetPack**: 7.0 (L4T R38.2) or 7.1 (L4T R38.4)
- **Ubuntu**: 24.04 LTS
- **Kernel**: Linux 6.8 LTS
- **CUDA**: 13.0
- **cuDNN**: 9.12
- **TensorRT**: 10.13

---

**Document Owner**: Technical Team
**Last Updated**: 2026-02-10
**Next Review**: April 2026 (Yocto 6.0 LTS release)
