# Panduan Deploy ke Vercel (Godot Web)

Folder ini disiapkan untuk hasil export Web Godot yang siap di-deploy ke Vercel.

## Cara 1: Export Langsung dari Godot Editor (Lokal)
1. Buka Godot Engine.
2. Di menu atas, pilih **Editor > Manage Export Templates**.
3. Klik **Download and Install** untuk versi Godot Anda.
4. Buka menu **Project > Export**.
5. Pilih preset **Web** (sudah kami buatkan di `export_presets.cfg`).
6. Klik tombol **Export Project**, arahkan simpan ke folder ini dengan nama file `index.html`.
7. Setelah selesai, folder ini akan berisi:
   - `index.html`
   - `index.js`
   - `index.wasm`
   - `index.pck`
   - `vercel.json` (sudah disiapkan untuk header COOP/COEP)
8. Buka terminal di folder `export/` ini, lalu jalankan:
   ```bash
   npx vercel deploy --prod
   ```
   Atau drag-and-drop folder ini ke dashboard [Vercel](https://vercel.com).

---

## Cara 2: Otomatisasi via GitHub Actions (Tanpa Download Template di PC)
Jika proyek ini di-push ke GitHub, Anda bisa menggunakan GitHub Actions untuk meng-compile Godot Web secara otomatis di cloud, lalu langsung men-deploy hasilnya ke Vercel atau GitHub Pages tanpa membebani penyimpanan komputer Anda.
