# FBInk Binary for Amazon Kindle

FBInk is a high-performance library and command-line tool created by **NiLuJe** for rendering images, text, and graphics directly to the Kindle e-ink framebuffer.

## Obtaining FBInk for Your Kindle

1. Download the latest pre-compiled release from the official NiLuJe FBInk thread on MobileRead:
   - **MobileRead Thread**: [https://www.mobileread.com/forums/showthread.php?t=299066](https://www.mobileread.com/forums/showthread.php?t=299066)
   - Or download the standalone release archive from GitHub: [https://github.com/NiLuJe/FBInk/releases](https://github.com/NiLuJe/FBInk/releases)

2. Choose the correct build for your Kindle architecture:
   - **Kindle Paperwhite 2/3/4, Voyage, Oasis 1/2/3, Basic 7/8/10**: `fbink-armhf` or `fbink-armel`
   - **Kindle 4, Touch, Paperwhite 1**: `fbink-armel`

3. Rename the binary to `fbink` and place it in this folder (`kindle/bin/fbink`).

4. Make it executable:
   ```bash
   chmod +x /mnt/us/kindle-trmnl-dashboard/bin/fbink
   ```

*Note: If you have already installed FBInk system-wide via NiLuJe's KUAL extension packages (e.g. `/usr/bin/fbink`), our scripts will automatically detect and use the system copy!*