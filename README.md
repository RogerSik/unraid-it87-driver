# Unraid IT87 Driver plugin

Unraid plugin for the ITE IT87 hwmon driver from https://github.com/frankcrawford/it87 (supports chips like IT8613E, IT8686E that the in-kernel driver doesn't), for use with the Dynamix System Temperature and Auto Fan Control plugins.

Continuation of [ich777/unraid-it87-driver](https://github.com/ich777/unraid-it87-driver); ich777 stopped working on Unraid plugins.

## Install

Plugins → Install Plugin:

```
https://github.com/RogerSik/unraid-it87-driver/releases/latest/download/it87-driver.plg
```

## How it works

- **Kernel modules:** the `Build kernel modules` workflow checks the Unraid releases daily and builds the module for every new kernel (release tag = kernel release, e.g. `6.18.64-Unraid`). Run it by hand for a fresh Unraid release: `gh workflow run kernel-modules.yml -f unraid_version=<version>`.
- **Plugin:** on install/boot the plugin downloads the module for the running kernel from this repo (ich777's releases as fallback) and loads it with `ignore_resource_conflict=1`. After an Unraid update the module for the new kernel is downloaded on the first boot (needs internet); there is no Plugin Update Helper.
- **Releases:** push a tag `YYYY.MM.DD[a]` on `master` with a matching `###<version>` entry in the plg `<CHANGES>`; the `Release plugin` workflow publishes the plg.
