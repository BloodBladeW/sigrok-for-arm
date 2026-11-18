# sigrok for Linux ARM64 (AArch64)

This build configuration produces two ARM64 Type 2 AppImages: PulseView (GUI) and sigrok-cli. Both package the matching sigrok libraries, protocol decoders, firmware files, and runtime dependencies.

## Build

Run the workflow in a **public GitHub repository** using `Actions → Build ARM64 AppImages → Run workflow`. It builds on GitHub's native `ubuntu-24.04-arm` runner and attaches both files to the workflow run. A private repository may require an eligible paid ARM runner.

The current Windows environment has no available Docker or WSL Linux environment, so the ARM binaries cannot be executed or produced locally here. The workflow is prepared to do that native build; it has not been run from this workspace.

## Run

```sh
chmod +x pulseview-NIGHTLY-aarch64.AppImage sigrok-cli-NIGHTLY-aarch64.AppImage
./pulseview-NIGHTLY-aarch64.AppImage
./sigrok-cli-NIGHTLY-aarch64.AppImage --scan
```

AppImages do not install udev permissions. Hardware access may require the sigrok udev rules and appropriate user-group permissions on the target distribution.

The target is **AArch64 / ARM64**, not 32-bit ARM (`armhf`). The GUI artifact uses Qt5 and expects a Linux desktop session. Sources are built from the upstream sigrok project repositories at build time.
