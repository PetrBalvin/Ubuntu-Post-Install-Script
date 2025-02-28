# Ubuntu Post-Install Script
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)  
[![Ubuntu Version](https://img.shields.io/badge/Ubuntu-22.04%20LTS%2B-orange)](https://ubuntu.com/)  
[![AMD Optimized](https://img.shields.io/badge/Optimized-AMD%20GPU%2FCPU-red)](https://www.amd.com/)

## Co skript dělá?
Komplexní konfigurace Ubuntu s:
- 🔧 **Optimalizací AMD GPU/CPU** (ovladače, kodeky, thermald)
- 🔄 **Systémové aktualizace** a čištění
- 🛠️ **Produktivita**: LibreOffice, OBS, Mozilla VPN
- 🎨 **GNOME konfigurace**: Témata, rozšíření, HiDPI
- 🔒 **Ubuntu Pro** (ESM/Livepatch pro LTS)
- 🎮 **Zábava**: Steam, Spotify, Discord

## Požadavky
- Ubuntu 22.04+ (testováno na 22.04/23.10/24.04/24.10)
- AMD CPU/GPU (Ryzen 3000+, Radeon RX 5000+)
- Jádro Linux 5.15+
- Aktivní internet a sudo práva

## Instalace
```bash
git clone https://github.com/vas-jmeno/Ubuntu-Post-Install-Script
cd Ubuntu-Post-Install-Script
chmod +x postinstall.sh
sudo ./postinstall.sh
