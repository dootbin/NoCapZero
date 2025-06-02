# Bootstrap Process for Prebuilt Components

## Overview

The build system uses prebuilt components (kernel, U-Boot, etc.) to avoid disk space issues during CI/CD builds. This document explains how to bootstrap the initial components.

## Initial Setup (One-time)

1. **Run the Bootstrap Workflow**
   ```bash
   gh workflow run bootstrap-components.yml -f release_tag=v1.0.0
   ```
   
   Or via GitHub UI:
   - Go to Actions → Bootstrap Prebuilt Components
   - Click "Run workflow"
   - Enter release tag (e.g., v1.0.0)
   - Click "Run workflow"

2. **Wait for Build Completion**
   - This will take ~30-40 minutes
   - Creates a release with all prebuilt components
   - Only needs to be done once

3. **Verify Release**
   - Check Releases page for the new release
   - Ensure all components are present:
     - u-boot-sunxi-with-spl.bin
     - Image (kernel)
     - sun50i-h618-orangepi-zero2w.dtb
     - modules.tar.gz
     - libmali.so

## Regular Builds

After bootstrap, regular builds will:
1. Try to download prebuilt components from the release
2. If download fails, fall back to building from source
3. Complete in ~5 minutes instead of ~30 minutes

## Updating Components

When kernel or U-Boot needs updating:

1. **Option A: Manual Update**
   - Run bootstrap-components.yml with a new version tag
   - Update `COMPONENTS_VERSION` in build.yml

2. **Option B: Automatic Weekly Updates**
   - The build-components.yml workflow runs weekly
   - Creates timestamped releases
   - Update `COMPONENTS_VERSION` to use new components

## Versioning Strategy

- **Production**: Use specific version tags (e.g., v1.0.0, v1.1.0)
- **Development**: Use timestamped releases (e.g., components-20240602-143022)
- **Testing**: Can override via workflow dispatch

## Troubleshooting

### "Failed to download prebuilt components"
- Check if the release exists
- Verify COMPONENTS_VERSION matches a valid release tag
- Run bootstrap workflow if needed

### "No space left on device" 
- This means prebuilt components aren't being used
- Check workflow logs for download failures
- Ensure proper release tag is configured

### "DTB file not found"
- The kernel source may not include the exact DTB
- The workflow searches for alternative names
- May need to add kernel patches for proper DTB support