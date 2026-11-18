# sigrok for Linux ARM64 (AArch64)

This build configuration produces two ARM64 Type 2 AppImages: PulseView (GUI) and sigrok-cli. Both package the matching sigrok libraries, protocol decoders, firmware files, and runtime dependencies.

## Build

Run the workflow in a **public GitHub repository** using `Actions → Build ARM64 AppImages → Run workflow`. It builds on GitHub's native `ubuntu-22.04-arm` runner and attaches both files to the workflow run. The older build base improves compatibility with distributions that ship an older glibc. A private repository may require an eligible paid ARM runner.

The current Windows environment has no available Docker or WSL Linux environment, so the ARM binaries cannot be executed or produced locally here. The workflow is prepared to do that native build; it has not been run from this workspace.

## Run

```sh
chmod +x pulseview-NIGHTLY-aarch64.AppImage sigrok-cli-NIGHTLY-aarch64.AppImage
./pulseview-NIGHTLY-aarch64.AppImage
./sigrok-cli-NIGHTLY-aarch64.AppImage --scan
```

AppImages do not install udev permissions. Hardware access may require the sigrok udev rules and appropriate user-group permissions on the target distribution.

The target is **AArch64 / ARM64**, not 32-bit ARM (`armhf`). The GUI artifact uses Qt5 and bundles both XCB and Wayland platform plugins for desktop sessions. Sources are built from the upstream sigrok project repositories at build time.

## Fedora 45

The artifacts are built on Ubuntu 22.04 ARM64 to keep their glibc requirement lower than Fedora 45. Fedora 45 ships glibc 2.44, so it is newer than the build baseline. AppImage still relies on the host for some system interfaces and graphics/device access, so test both launch and hardware access on the actual Fedora system.

If the AppImage reports a missing `libfuse.so.2`, install Fedora's FUSE 2 compatibility packages with `sudo dnf install fuse fuse-libs`, or try extract-and-run mode:

```sh
APPIMAGE_EXTRACT_AND_RUN=1 ./pulseview-NIGHTLY-aarch64.AppImage
```
