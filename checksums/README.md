# Supply Chain Security - Binary Checksums

This directory contains SHA256 checksums for external binary dependencies to ensure supply chain integrity.

## Purpose

All external binaries downloaded during the build process are verified against known-good checksums. This protects against:
- Supply chain attacks (compromised upstream sources)
- Man-in-the-middle attacks during download
- Accidental file corruption
- Unauthorized binary modifications

## Current Verified Binaries

### Mali G31 GPU Driver (`libmali-bifrost-g31-r16p0-gbm.so`)
- **Source**: LibreELEC GitHub repository
- **Checksum file**: `libmali-bifrost-g31-r16p0-gbm.sha256`
- **Verification**: Automated on every build in all workflows

## How It Works

1. **Download**: Binary is downloaded from upstream source
2. **Calculate**: SHA256 checksum is calculated for the downloaded file
3. **Compare**: Checksum is compared against the expected value in this directory
4. **Action**:
   - ✅ **Match**: Build continues - supply chain integrity confirmed
   - ❌ **Mismatch**: Build fails with security warning

## First-Time Setup

When setting up verification for the first time:

1. Run a build - it will warn that no checksum is configured
2. Review the build logs to get the calculated checksum
3. Verify the checksum is from a trusted source
4. Add the checksum to the appropriate `.sha256` file
5. Commit the checksum file

## Updating Checksums

⚠️ **Only update checksums when you've verified a legitimate upstream update!**

### When LibreELEC releases a new Mali driver version:

1. Build will fail with checksum mismatch
2. Investigate why the checksum changed:
   - Check LibreELEC's release notes
   - Verify the change is legitimate
   - Consider security implications
3. If legitimate, get the new checksum from build logs
4. Update `libmali-bifrost-g31-r16p0-gbm.sha256`
5. Commit with detailed explanation:
   ```bash
   git commit -m "Update Mali driver checksum for version X.Y.Z

   LibreELEC released new driver version X.Y.Z on DATE.
   Verified legitimate update via [method].

   Old: <old_checksum>
   New: <new_checksum>

   Source: <upstream_release_url>"
   ```

## Security Best Practices

- ✅ Never disable checksum verification
- ✅ Always investigate checksum mismatches
- ✅ Document all checksum updates with rationale
- ✅ Verify checksums from multiple sources when possible
- ✅ Review upstream release notes before updating
- ❌ Never blindly update checksums without investigation

## Adding New Binary Verification

To add verification for a new binary:

1. Create a new `.sha256` file in this directory
2. Add verification logic to the workflow that downloads the binary
3. Document it in this README
4. Run a test build to capture and verify the checksum

## File Format

Each `.sha256` file contains:
```
# Comments explaining the binary source and purpose
# Multiple comment lines are allowed
<sha256_checksum>  <filename>
```

Comments (lines starting with `#`) and blank lines are ignored during verification.
