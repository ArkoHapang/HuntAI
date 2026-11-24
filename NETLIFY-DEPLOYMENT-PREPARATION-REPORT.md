# HuntAI — Netlify Manual Deployment Preparation Report

**Project:** HuntAI — AI-Assisted Threat Hunting Platform  
**Project Directory:** `D:\huntai (4)\huntai`  
**Deployment Platform:** Netlify  
**Deployment Method:** Manual Static-Site Deployment (Drag-and-Drop / Directory Upload)  
**Date:** 2026-11-21  
**Readiness Verdict:** **READY FOR NETLIFY DEPLOYMENT**  

---

## 1. Executive Summary

This report provides the pre-deployment verification and manual deployment instructions for publishing the HuntAI Flutter Web application to Netlify.

The inspection verified that a complete, standalone production release build exists at `build\web` with root base path (`/`), updated project metadata, complete CanvasKit and asset bundles, and no runtime server or database dependencies.

The site is ready for immediate manual static upload to Netlify without requiring a rebuild, Git repository connection, or backend infrastructure.

---

## 2. Release Build Inspection Results

The release build directory at `D:\huntai (4)\huntai\build\web` was inspected. All required static hosting assets are present, fully intact, and verified:

| File / Folder | Size / Status | Purpose & Verification Notes |
| :--- | :--- | :--- |
| **`index.html`** | 1,624 bytes | Web entry point. Verified `<base href="/">`, `<title>HuntAI — AI-Assisted Threat Hunting Platform</title>`, `<meta name="description" content="HuntAI — AI-Assisted Threat Hunting Demonstration Platform">`, and Flutter bootstrap loader. |
| **`flutter_bootstrap.js`** | 13,094 bytes | Asynchronous Flutter Web engine and CanvasKit loader. |
| **`flutter.js`** | 12,136 bytes | Core Flutter runtime bootstrap script. |
| **`flutter_service_worker.js`** | 815 bytes | PWA cache management and offline service worker. |
| **`main.dart.js`** | 2,935,756 bytes | Compiled production JavaScript application bundle containing the complete HuntAI SOC platform, investigation workflows, and graph renderers. |
| **`manifest.json`** | 1,021 bytes | PWA web app manifest with updated name (`HuntAI — AI-Assisted Threat Hunting Platform`) and description. |
| **`favicon.png`** | 917 bytes | Application browser favicon. |
| **`assets/`** | Directory | Contains `FontManifest.json`, `AssetManifest.bin`, license notices, and tree-shaken Material font icons. |
| **`canvaskit/`** | Directory | WebAssembly and CanvasKit rendering engine files (`canvaskit.wasm` 7.28 MB, `canvaskit.js`, `skwasm.*`, `wimp.*`). |
| **`icons/`** | Directory | Standard and maskable PWA icons (`Icon-192.png`, `Icon-512.png`, `Icon-maskable-192.png`, `Icon-maskable-512.png`). |
| **`version.json`** | 82 bytes | Application build version metadata (`version: 1.0.0+1`). |

---

## 3. Base-Href & Root Path Verification

- **Configured Base Href:** `<base href="/">` (verified in `build\web\index.html` line 17).
- **Netlify Hosting Compatibility:** Netlify serves sites from the web root domain (e.g., `https://<site-name>.netlify.app/` or a custom apex/subdomain such as `https://demo.huntai.dev/`).
- **Path Resolution:** Because the base href is `/`, all asset fetches (`flutter_bootstrap.js`, `main.dart.js`, `canvaskit/canvaskit.wasm`, icons, and fonts) resolve correctly from the root of the Netlify domain without path truncation or 404 errors.
- **Routing Safety:** HuntAI uses an in-memory page index (`_selectedPage` in `HuntAiHome`) rather than browser history path rewrites. Direct hits and page reloads consistently request `/index.html`, which Netlify serves naturally.

---

## 4. Required Upload Directory

When uploading HuntAI to Netlify, provide the exact folder path below:

```text
D:\huntai (4)\huntai\build\web
```

> [!IMPORTANT]
> Upload the **contents** of `build\web` (or drop the `web` folder itself into the Netlify drag-and-drop target). Do **NOT** upload the project root `D:\huntai (4)\huntai` or the parent `build` directory.

---

## 5. Netlify Manual Deployment Instructions

Deploying HuntAI to Netlify requires no Git repository, build hooks, or command-line installation. Follow either of the two standard manual deployment options:

### Option A: Web Dashboard Drag-and-Drop (Recommended)

1. Open your browser and log in to the [Netlify App Console](https://app.netlify.com/).
2. Navigate to the **Sites** tab:
   - If creating a new site: Scroll down to the bottom where it says **"Want to deploy a new site without connecting to Git? Drag and drop your site output folder here"** (or visit `https://app.netlify.com/drop`).
   - If updating an existing site: Open the site overview, go to the **Deploys** tab, and locate the drop zone at the bottom of the page.
3. Open Windows File Explorer and navigate to:
   ```text
   D:\huntai (4)\huntai\build
   ```
4. Drag the **`web`** folder and drop it onto the designated Netlify upload box in your browser.
5. Wait for the upload and deploy progress to complete (usually 10–20 seconds).
6. Netlify will generate a live URL (e.g., `https://<random-name>.netlify.app`).
7. (Optional) Go to **Site settings** → **Change site name** to assign a custom Netlify subdomain (e.g., `https://huntai-soc-demo.netlify.app`).

### Option B: Netlify CLI Manual Deploy (Alternative)

If Netlify CLI is installed on your local workstation and you prefer deploying via terminal:

```powershell
cd "D:\huntai (4)\huntai"
npx netlify-cli deploy --dir=build/web --prod
```

Follow the interactive prompts to link an existing site or create a new site.

---

## 6. Known Limitations & Operating Boundaries

The following design characteristics and limitations apply to this deployment:

1. **In-Memory Persistence:**  
   HuntAI is an evaluation and demonstration platform. All investigation records, evidence items, hypothesis assessments, and alert review states exist only in browser memory. Reloading the page or closing the tab resets data to initial demo fixtures.
2. **Air-Gapped External Services:**  
   No external connections to MITRE ATT&CK APIs, VirusTotal, live SIEM platforms, or third-party AI LLMs are active. All external services are catalogued as unconfigured in Settings.
3. **Synthetic Data Only:**  
   All alerts, events, and graph entities are synthetic SOC demonstration fixtures. The platform does not monitor live endpoints, operating systems, or enterprise networks.
4. **Browser Hardware Acceleration:**  
   The application uses CanvasKit and WebGL rendering for 2D/3D attack graphs. Evergreen modern browsers (Chrome, Edge, Firefox, Safari) with WebGL enabled are recommended for optimal performance.

---

## 7. Final Readiness Verdict

### **VERDICT: READY FOR NETLIFY DEPLOYMENT**

- **Build Integrity:** Complete static release bundle located at `D:\huntai (4)\huntai\build\web`.
- **Root Configuration:** Base href `/` matches Netlify root hosting.
- **Dependencies & Backend:** Zero external server or runtime dependencies required.
- **Action Required:** Proceed with manual drag-and-drop of `D:\huntai (4)\huntai\build\web` to Netlify.
