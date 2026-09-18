import os

html_content = '''<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
  <title>知序 Ordo - 知其轻重，行止有序 | 跨平台离线优先待办应用</title>
  <meta name="description" content="知序 Ordo 是一款跨平台、离线优先、安全可靠的待办与项目管理应用。支持清晰四态生命周期、三级结构化任务树、全景农历节气日历与 WebDAV/S3 私有云同步。">
  <link rel="icon" type="image/png" href="assets/app_logo.png">
  <style>
    :root {
      --primary: #05976A;
      --primary-rgb: 5, 151, 106;
      --primary-hover: #047857;
      --primary-light: rgba(5, 151, 106, 0.08);
      --primary-subtle: rgba(5, 151, 106, 0.16);
      --bg: #F8FAFC;
      --surface: #FFFFFF;
      --surface-glass: rgba(255, 255, 255, 0.88);
      --text: #0F172A;
      --text-muted: #475569;
      --text-sub: #64748B;
      --border: #E2E8F0;
      --border-subtle: #EDF2F7;
      --shadow-sm: 0 1px 3px rgba(0,0,0,0.05), 0 1px 2px rgba(0,0,0,0.03);
      --shadow-md: 0 4px 16px -2px rgba(0,0,0,0.06), 0 2px 6px -1px rgba(0,0,0,0.03);
      --shadow-lg: 0 20px 30px -10px rgba(0,0,0,0.08), 0 10px 15px -3px rgba(0,0,0,0.04);
      --shadow-popover: 0 20px 40px -10px rgba(15, 23, 42, 0.22), 0 0 0 1px rgba(0,0,0,0.06);
      --shadow-glow: 0 10px 30px -5px rgba(var(--primary-rgb), 0.25);
      --radius-sm: 8px;
      --radius-md: 14px;
      --radius-lg: 20px;
      --radius-xl: 28px;
      --font-sans: -apple-system, BlinkMacSystemFont, "SF Pro Display", "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", sans-serif;
    }

    * { margin: 0; padding: 0; box-sizing: border-box; }
    html { scroll-behavior: smooth; }
    body {
      font-family: var(--font-sans);
      background-color: var(--bg);
      color: var(--text);
      line-height: 1.6;
      -webkit-font-smoothing: antialiased;
      overflow-x: hidden;
      width: 100%;
    }

    a { text-decoration: none; color: inherit; }
    img { max-width: 100%; height: auto; display: block; }
    button { font-family: inherit; border: none; cursor: pointer; background: none; }

    .container {
      width: 100%;
      max-width: 1200px;
      margin: 0 auto;
      padding: 0 24px;
    }

    /* ==========================================================================
       Header & Navigation
       ========================================================================== */
    header.site-header {
      position: sticky;
      top: 0;
      z-index: 100;
      backdrop-filter: blur(16px);
      -webkit-backdrop-filter: blur(16px);
      background: var(--surface-glass);
      border-bottom: 1px solid var(--border);
      transition: all 0.3s ease;
    }
    .header-inner {
      display: flex;
      align-items: center;
      justify-content: space-between;
      height: 72px;
      gap: 16px;
    }
    .brand-logo {
      display: flex;
      align-items: center;
      gap: 12px;
      font-weight: 700;
      font-size: 20px;
      letter-spacing: -0.02em;
      flex-shrink: 0;
    }
    .brand-logo-img {
      width: 42px;
      height: 42px;
      border-radius: 10px;
      object-fit: cover;
      box-shadow: 0 3px 10px rgba(0, 0, 0, 0.12);
      flex-shrink: 0;
    }
    .brand-title { display: flex; flex-direction: column; }
    .brand-title span.app-name { font-size: 18px; font-weight: 800; line-height: 1.2; }
    .brand-title span.app-slogan { font-size: 11px; color: var(--text-sub); font-weight: 500; letter-spacing: 0.05em; }

    .nav-links {
      display: flex;
      align-items: center;
      gap: 28px;
    }
    .nav-links a {
      font-size: 15px;
      font-weight: 500;
      color: var(--text-muted);
      transition: color 0.2s ease;
      white-space: nowrap;
    }
    .nav-links a:hover {
      color: var(--primary);
    }

    .header-actions {
      display: flex;
      align-items: center;
      gap: 12px;
      flex-shrink: 0;
    }
    .btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      padding: 10px 20px;
      border-radius: var(--radius-sm);
      font-size: 14px;
      font-weight: 600;
      transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
      white-space: nowrap;
      user-select: none;
    }
    .btn-primary {
      background: var(--primary);
      color: white;
      box-shadow: var(--shadow-sm);
    }
    .btn-primary:hover {
      background: var(--primary-hover);
      box-shadow: var(--shadow-glow);
      transform: translateY(-1px);
    }
    .btn-secondary {
      background: var(--surface);
      color: var(--text);
      border: 1px solid var(--border);
    }
    .btn-secondary:hover {
      border-color: var(--text-muted);
      background: var(--bg);
    }

    /* Mobile hamburger menu toggle */
    .mobile-menu-toggle {
      display: none;
      width: 40px;
      height: 40px;
      border-radius: var(--radius-sm);
      align-items: center;
      justify-content: center;
      color: var(--text);
      border: 1px solid var(--border);
      background: var(--surface);
    }
    .mobile-menu-toggle svg { width: 22px; height: 22px; stroke: currentColor; fill: none; stroke-width: 2; }

    /* Mobile Dropdown Nav Menu */
    .mobile-nav-drawer {
      display: none;
      position: absolute;
      top: 100%;
      left: 0;
      width: 100%;
      background: var(--surface);
      border-bottom: 1px solid var(--border);
      box-shadow: var(--shadow-md);
      padding: 16px 24px 24px;
      flex-direction: column;
      gap: 14px;
      z-index: 99;
    }
    .mobile-nav-drawer.active {
      display: flex;
    }
    .mobile-nav-drawer a {
      font-size: 16px;
      font-weight: 600;
      color: var(--text-muted);
      padding: 8px 0;
      border-bottom: 1px solid var(--border-subtle);
    }
    .mobile-nav-drawer a:last-child {
      border-bottom: none;
    }

    /* ==========================================================================
       Desktop Hover Dropdown & Universal Popovers
       ========================================================================== */
    .download-dropdown-wrapper {
      position: relative;
      display: inline-flex;
    }

    .download-popover {
      position: absolute;
      z-index: 300;
      background: #FFFFFF;
      border-radius: var(--radius-lg);
      padding: 24px;
      width: 480px;
      box-shadow: var(--shadow-popover);
      border: 1px solid var(--border);
      opacity: 0;
      visibility: hidden;
      pointer-events: none;
      transition: all 0.28s cubic-bezier(0.16, 1, 0.3, 1);
      text-align: left;
    }
    .download-popover::before {
      content: "";
      position: absolute;
      inset: -14px -14px -14px -14px;
      z-index: -1;
    }

    .header-dropdown .download-popover {
      top: calc(100% + 14px);
      right: 0;
      transform: translateY(10px);
    }
    .hero-dropdown .download-popover {
      top: calc(100% + 14px);
      left: 0;
      transform: translateY(10px);
    }
    .cta-dropdown .download-popover {
      bottom: calc(100% + 16px);
      left: 50%;
      transform: translateX(-50%) translateY(-10px);
      color: var(--text);
    }

    /* Desktop Hover states */
    @media (min-width: 641px) {
      .download-dropdown-wrapper:hover .download-popover {
        opacity: 1;
        visibility: visible;
        pointer-events: auto;
      }
      .header-dropdown:hover .download-popover {
        transform: translateY(0);
      }
      .hero-dropdown:hover .download-popover {
        transform: translateY(0);
      }
      .cta-dropdown:hover .download-popover {
        transform: translateX(-50%) translateY(0);
      }
    }

    /* ==========================================================================
       Universal Top-Level Modal (Click on any button & Mobile Viewports)
       ========================================================================== */
    .global-modal-backdrop {
      position: fixed;
      inset: 0;
      background: rgba(15, 23, 42, 0.65);
      backdrop-filter: blur(8px);
      -webkit-backdrop-filter: blur(8px);
      z-index: 1000;
      opacity: 0;
      visibility: hidden;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 16px;
      transition: opacity 0.25s ease, visibility 0.25s ease;
    }
    .global-modal-backdrop.active {
      opacity: 1;
      visibility: visible;
    }
    .global-modal-content {
      background: #FFFFFF;
      border-radius: var(--radius-lg);
      padding: 28px;
      width: min(520px, 92vw);
      max-height: 88vh;
      overflow-y: auto;
      box-shadow: 0 25px 60px -15px rgba(0, 0, 0, 0.4);
      border: 1px solid var(--border);
      position: relative;
      transform: scale(0.95) translateY(10px);
      transition: transform 0.25s cubic-bezier(0.16, 1, 0.3, 1);
    }
    .global-modal-backdrop.active .global-modal-content {
      transform: scale(1) translateY(0);
    }
    .modal-close-btn {
      position: absolute;
      top: 14px;
      right: 14px;
      width: 36px;
      height: 36px;
      border-radius: 50%;
      background: var(--bg);
      color: var(--text-sub);
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      font-size: 20px;
      transition: background 0.2s;
    }
    .modal-close-btn:hover {
      background: var(--border);
      color: var(--text);
    }

    .popover-header {
      margin-bottom: 18px;
      position: relative;
    }
    .popover-header h4 {
      font-size: 16px;
      font-weight: 700;
      color: var(--text);
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 4px;
      padding-right: 28px;
    }
    .popover-header h4 svg {
      width: 18px;
      height: 18px;
      color: var(--primary);
      flex-shrink: 0;
    }
    .popover-header p {
      font-size: 12px;
      color: var(--text-muted);
      line-height: 1.5;
    }

    .popover-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 16px;
    }
    .qr-card {
      background: var(--bg);
      border: 1px solid var(--border);
      border-radius: var(--radius-md);
      padding: 12px;
      text-align: center;
      display: flex;
      flex-direction: column;
      align-items: center;
      transition: all 0.2s ease;
      cursor: zoom-in;
      position: relative;
    }
    .qr-card:hover {
      border-color: var(--primary);
      background: var(--surface);
      transform: translateY(-3px);
      box-shadow: var(--shadow-md);
    }
    .qr-badge {
      font-size: 12px;
      font-weight: 700;
      padding: 4px 10px;
      border-radius: 999px;
      background: var(--surface);
      color: var(--text);
      margin-bottom: 10px;
      border: 1px solid var(--border);
      display: inline-flex;
      align-items: center;
      gap: 5px;
    }
    .qr-badge svg { width: 13px; height: 13px; color: var(--primary); }
    .qr-img-box {
      width: 100%;
      aspect-ratio: 1 / 1.35;
      overflow: hidden;
      border-radius: 8px;
      background: #FFFFFF;
      margin-bottom: 10px;
      box-shadow: 0 2px 6px rgba(0,0,0,0.06);
      position: relative;
    }
    .qr-img-box img {
      width: 100%;
      height: 100%;
      object-fit: cover;
      object-position: center;
      transition: transform 0.3s ease;
    }
    .qr-card:hover .qr-img-box img {
      transform: scale(1.04);
    }
    .qr-zoom-tip {
      position: absolute;
      bottom: 6px;
      right: 6px;
      background: rgba(0, 0, 0, 0.65);
      color: #fff;
      padding: 2px 6px;
      border-radius: 4px;
      font-size: 10px;
      display: flex;
      align-items: center;
      gap: 3px;
      backdrop-filter: blur(4px);
    }
    .qr-zoom-tip svg { width: 11px; height: 11px; stroke: currentColor; fill: none; }
    .qr-desc {
      font-size: 11px;
      color: var(--text-sub);
      line-height: 1.4;
    }
    .qr-hint-tip {
      margin-top: 14px;
      padding-top: 12px;
      border-top: 1px solid var(--border-subtle);
      font-size: 11px;
      color: var(--text-sub);
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .qr-hint-tip span.highlight-tag {
      color: var(--primary);
      font-weight: 600;
    }

    /* ==========================================================================
       Hero Section
       ========================================================================== */
    .hero-section {
      padding: 72px 0 50px;
      position: relative;
      overflow: hidden;
    }
    .hero-bg-glow {
      position: absolute;
      top: -120px;
      left: 50%;
      transform: translateX(-50%);
      width: 100%;
      max-width: 800px;
      height: 400px;
      background: radial-gradient(circle, rgba(var(--primary-rgb), 0.12) 0%, rgba(var(--primary-rgb), 0) 70%);
      z-index: -1;
      pointer-events: none;
    }
    .hero-grid {
      display: grid;
      grid-template-columns: 1.15fr 0.85fr;
      gap: 50px;
      align-items: center;
    }
    .hero-badge {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 6px 14px;
      background: var(--primary-light);
      color: var(--primary);
      border-radius: 999px;
      font-size: 13px;
      font-weight: 600;
      margin-bottom: 20px;
      border: 1px solid rgba(var(--primary-rgb), 0.2);
    }
    .hero-badge svg { width: 14px; height: 14px; fill: currentColor; }
    .hero-title {
      font-size: clamp(34px, 4.5vw, 52px);
      line-height: 1.18;
      font-weight: 800;
      letter-spacing: -0.03em;
      margin-bottom: 18px;
      color: var(--text);
    }
    .hero-title .highlight {
      color: var(--primary);
      background: linear-gradient(135deg, var(--primary) 0%, #10B981 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    .hero-desc {
      font-size: clamp(15px, 1.8vw, 18px);
      color: var(--text-muted);
      line-height: 1.7;
      margin-bottom: 32px;
      max-width: 540px;
    }
    .hero-cta-group {
      display: flex;
      flex-wrap: wrap;
      gap: 14px;
      margin-bottom: 36px;
      position: relative;
    }
    .btn-lg {
      padding: 13px 26px;
      font-size: 15px;
      border-radius: var(--radius-md);
    }
    .hero-meta {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 20px;
      color: var(--text-sub);
      font-size: 13px;
    }
    .hero-meta-item {
      display: flex;
      align-items: center;
      gap: 6px;
      white-space: nowrap;
    }
    .hero-meta-item svg { width: 16px; height: 16px; color: var(--primary); flex-shrink: 0; }

    /* Hero Visual Phone Mockup */
    .hero-visual {
      position: relative;
      display: flex;
      justify-content: center;
      width: 100%;
    }
    .hero-phone-wrap {
      position: relative;
      width: 100%;
      max-width: 310px;
      filter: drop-shadow(0 25px 35px rgba(0,0,0,0.18));
      transition: transform 0.4s ease;
    }
    .hero-phone-wrap:hover {
      transform: translateY(-6px) rotate(1deg);
    }
    .hero-phone-wrap img {
      width: 100%;
      border-radius: 40px;
      display: block;
      border: 5px solid #111;
    }
    .hero-floating-card {
      position: absolute;
      background: var(--surface);
      padding: 12px 16px;
      border-radius: var(--radius-md);
      box-shadow: var(--shadow-lg);
      border: 1px solid var(--border);
      display: flex;
      align-items: center;
      gap: 10px;
      z-index: 10;
      animation: floatSlow 4s ease-in-out infinite alternate;
    }
    .card-top-left {
      top: 15%;
      left: -30px;
    }
    .card-bottom-right {
      bottom: 15%;
      right: -25px;
      animation-delay: -2s;
    }
    @keyframes floatSlow {
      0% { transform: translateY(0px); }
      100% { transform: translateY(-8px); }
    }
    .floating-icon {
      width: 34px;
      height: 34px;
      border-radius: 8px;
      background: var(--primary-light);
      color: var(--primary);
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
    }
    .floating-icon svg { width: 18px; height: 18px; stroke: currentColor; fill: none; stroke-width: 2; }
    .floating-text h4 { font-size: 13px; font-weight: 700; color: var(--text); }
    .floating-text p { font-size: 11px; color: var(--text-sub); }

    /* ==========================================================================
       Section Styling Shared
       ========================================================================= */
    section { padding: 80px 0; }
    .section-header {
      text-align: center;
      max-width: 680px;
      margin: 0 auto 48px;
      padding: 0 12px;
    }
    .section-tag {
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 0.1em;
      text-transform: uppercase;
      color: var(--primary);
      margin-bottom: 10px;
      display: block;
    }
    .section-title {
      font-size: clamp(26px, 3.8vw, 36px);
      font-weight: 800;
      letter-spacing: -0.02em;
      color: var(--text);
      margin-bottom: 14px;
      line-height: 1.28;
    }
    .section-desc {
      font-size: clamp(14px, 1.6vw, 16px);
      color: var(--text-muted);
      line-height: 1.7;
    }

    /* ==========================================================================
       Store Promo Shots Gallery Section
       ========================================================================== */
    .promo-gallery-section {
      background: #FFFFFF;
      border-top: 1px solid var(--border);
      border-bottom: 1px solid var(--border);
    }
    .gallery-filter-tabs {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
      margin-bottom: 36px;
      flex-wrap: wrap;
    }
    .tab-btn {
      padding: 10px 22px;
      border-radius: 999px;
      font-size: 14px;
      font-weight: 600;
      color: var(--text-muted);
      background: var(--bg);
      border: 1px solid var(--border);
      transition: all 0.2s ease;
      white-space: nowrap;
    }
    .tab-btn:hover {
      color: var(--text);
      border-color: var(--text-sub);
    }
    .tab-btn.active {
      background: var(--primary);
      color: white;
      border-color: var(--primary);
      box-shadow: 0 4px 14px rgba(var(--primary-rgb), 0.25);
    }

    .gallery-grid {
      display: grid;
      grid-template-columns: repeat(5, 1fr);
      gap: 18px;
    }
    .gallery-item {
      background: var(--bg);
      border-radius: var(--radius-md);
      overflow: hidden;
      border: 1px solid var(--border);
      transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
      cursor: pointer;
      position: relative;
    }
    .gallery-item:hover {
      transform: translateY(-5px);
      box-shadow: var(--shadow-lg);
      border-color: var(--primary);
    }
    .gallery-thumb {
      width: 100%;
      aspect-ratio: 9 / 19.5;
      overflow: hidden;
      background: #EAEFF5;
      position: relative;
    }
    .gallery-thumb.aspect-raw {
      aspect-ratio: 9 / 20;
    }
    .gallery-thumb img {
      width: 100%;
      height: 100%;
      object-fit: cover;
      object-position: top center;
      transition: transform 0.4s ease;
    }
    .gallery-item:hover .gallery-thumb img {
      transform: scale(1.03);
    }
    .gallery-info {
      padding: 12px;
      background: var(--surface);
      border-top: 1px solid var(--border);
    }
    .gallery-info h4 {
      font-size: 13px;
      font-weight: 700;
      color: var(--text);
      margin-bottom: 2px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .gallery-info p {
      font-size: 11px;
      color: var(--text-sub);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .gallery-overlay-badge {
      position: absolute;
      top: 8px;
      right: 8px;
      padding: 3px 6px;
      border-radius: 4px;
      background: rgba(0,0,0,0.6);
      color: white;
      font-size: 10px;
      font-weight: 600;
      backdrop-filter: blur(4px);
    }

    /* Lightbox Modal */
    .lightbox-modal {
      position: fixed;
      inset: 0;
      z-index: 2000;
      background: rgba(10, 15, 25, 0.88);
      backdrop-filter: blur(12px);
      -webkit-backdrop-filter: blur(12px);
      display: none;
      align-items: center;
      justify-content: center;
      padding: 16px;
      opacity: 0;
      transition: opacity 0.3s ease;
    }
    .lightbox-modal.active {
      display: flex;
      opacity: 1;
    }
    .lightbox-content {
      max-width: 92vw;
      max-height: 92vh;
      position: relative;
      display: flex;
      flex-direction: column;
      align-items: center;
    }
    .lightbox-img {
      max-height: 80vh;
      max-width: 88vw;
      object-fit: contain;
      border-radius: 14px;
      box-shadow: 0 25px 50px rgba(0,0,0,0.5);
    }
    .lightbox-caption {
      margin-top: 12px;
      color: white;
      text-align: center;
      font-size: 14px;
      font-weight: 600;
    }
    .lightbox-close {
      position: absolute;
      top: -46px;
      right: 0;
      color: white;
      font-size: 28px;
      width: 40px;
      height: 40px;
      display: flex;
      align-items: center;
      justify-content: center;
      border-radius: 50%;
      background: rgba(255,255,255,0.18);
      cursor: pointer;
      transition: background 0.2s;
    }
    .lightbox-close:hover {
      background: rgba(255,255,255,0.35);
    }

    /* ==========================================================================
       Features Section (Detailed Vertical Slices)
       ========================================================================== */
    .feature-slice-wrap {
      display: flex;
      flex-direction: column;
      gap: 80px;
    }
    .feature-slice {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 50px;
      align-items: center;
    }
    .feature-slice.reverse {
      grid-template-columns: 1fr 1fr;
      direction: rtl;
    }
    .feature-slice.reverse .feature-content {
      direction: ltr;
    }
    .feature-slice.reverse .feature-img-box {
      direction: ltr;
    }
    .feature-tag-pill {
      display: inline-block;
      font-size: 12px;
      font-weight: 700;
      color: var(--primary);
      text-transform: uppercase;
      letter-spacing: 0.08em;
      margin-bottom: 10px;
    }
    .feature-title {
      font-size: clamp(24px, 3.2vw, 32px);
      font-weight: 800;
      letter-spacing: -0.02em;
      line-height: 1.3;
      margin-bottom: 16px;
      color: var(--text);
    }
    .feature-desc {
      font-size: clamp(14px, 1.5vw, 16px);
      color: var(--text-muted);
      line-height: 1.8;
      margin-bottom: 22px;
    }
    .feature-points {
      list-style: none;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .feature-points li {
      display: flex;
      align-items: flex-start;
      gap: 10px;
      font-size: clamp(13px, 1.4vw, 15px);
      color: var(--text);
    }
    .feature-points li svg {
      width: 18px;
      height: 18px;
      stroke: var(--primary);
      fill: none;
      stroke-width: 2.5;
      flex-shrink: 0;
      margin-top: 3px;
    }

    .feature-img-box {
      background: linear-gradient(135deg, #F1F5F9 0%, #E2E8F0 100%);
      padding: 32px;
      border-radius: var(--radius-xl);
      display: flex;
      align-items: center;
      justify-content: center;
      border: 1px solid var(--border);
      box-shadow: var(--shadow-sm);
    }
    .feature-img-box img {
      max-height: 440px;
      width: auto;
      max-width: 100%;
      border-radius: 24px;
      box-shadow: 0 16px 36px -6px rgba(0,0,0,0.14);
      border: 3px solid #111;
      transition: transform 0.3s ease;
    }
    .feature-img-box:hover img {
      transform: scale(1.02);
    }

    /* ==========================================================================
       Grid Feature Cards (Security, Sync, Themes)
       ========================================================================== */
    .cards-grid-section {
      background: #FFFFFF;
      border-top: 1px solid var(--border);
      border-bottom: 1px solid var(--border);
    }
    .cards-3-col {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 24px;
    }
    .service-card {
      background: var(--bg);
      border-radius: var(--radius-lg);
      padding: 28px;
      border: 1px solid var(--border);
      transition: all 0.3s ease;
      display: flex;
      flex-direction: column;
    }
    .service-card:hover {
      transform: translateY(-4px);
      box-shadow: var(--shadow-md);
      border-color: rgba(var(--primary-rgb), 0.4);
    }
    .service-icon {
      width: 48px;
      height: 48px;
      border-radius: var(--radius-md);
      background: var(--primary-light);
      color: var(--primary);
      display: flex;
      align-items: center;
      justify-content: center;
      margin-bottom: 20px;
      flex-shrink: 0;
    }
    .service-icon svg { width: 24px; height: 24px; stroke: currentColor; fill: none; stroke-width: 2; }
    .service-card h3 {
      font-size: 18px;
      font-weight: 700;
      color: var(--text);
      margin-bottom: 10px;
    }
    .service-card p {
      font-size: 14px;
      color: var(--text-muted);
      line-height: 1.7;
    }

    /* ==========================================================================
       Theme Palette Showcase
       ========================================================================== */
    .theme-showcase-section {
      text-align: center;
    }
    .theme-palette-bar {
      display: flex;
      justify-content: center;
      gap: 12px;
      margin: 28px 0 20px;
      flex-wrap: wrap;
    }
    .theme-chip-btn {
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 8px 16px;
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 999px;
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s ease;
      white-space: nowrap;
    }
    .theme-chip-btn:hover {
      transform: translateY(-2px);
      box-shadow: var(--shadow-sm);
    }
    .theme-chip-btn.active {
      border-color: var(--primary);
      box-shadow: 0 0 0 2px var(--primary);
    }
    .theme-circle {
      width: 14px;
      height: 14px;
      border-radius: 50%;
    }

    /* ==========================================================================
       Download & CTA Section
       ========================================================================== */
    .cta-banner-section {
      background: linear-gradient(135deg, #0A221A 0%, #04140F 100%);
      color: white;
      border-radius: var(--radius-xl);
      padding: 60px 36px;
      text-align: center;
      margin-bottom: 60px;
      box-shadow: var(--shadow-lg);
      position: relative;
      overflow: visible;
    }
    .cta-banner-section::before {
      content: '';
      position: absolute;
      top: -50%;
      left: 50%;
      transform: translateX(-50%);
      width: 100%;
      max-width: 600px;
      height: 300px;
      background: radial-gradient(circle, rgba(5, 151, 106, 0.4) 0%, rgba(5, 151, 106, 0) 70%);
      pointer-events: none;
      border-radius: 50%;
    }
    .cta-banner-section h2 {
      font-size: clamp(26px, 4vw, 38px);
      font-weight: 800;
      letter-spacing: -0.02em;
      margin-bottom: 14px;
    }
    .cta-banner-section p {
      font-size: clamp(14px, 1.8vw, 17px);
      color: #9FE2CD;
      max-width: 580px;
      margin: 0 auto 30px;
      line-height: 1.6;
    }
    .cta-buttons {
      display: flex;
      justify-content: center;
      gap: 16px;
      flex-wrap: wrap;
      position: relative;
    }
    .btn-white {
      background: white;
      color: #0A221A;
      font-weight: 700;
    }
    .btn-white:hover {
      background: #F1F5F9;
      transform: translateY(-2px);
    }
    .btn-outline-white {
      border: 1px solid rgba(255,255,255,0.3);
      color: white;
    }
    .btn-outline-white:hover {
      background: rgba(255,255,255,0.1);
      border-color: white;
    }

    /* ==========================================================================
       Footer
       ========================================================================== */
    footer.site-footer {
      background: #FFFFFF;
      border-top: 1px solid var(--border);
      padding: 40px 0;
      color: var(--text-sub);
      font-size: 13px;
    }
    .footer-inner {
      display: flex;
      align-items: center;
      justify-content: space-between;
      flex-wrap: wrap;
      gap: 16px;
    }
    .footer-links {
      display: flex;
      gap: 20px;
      flex-wrap: wrap;
    }
    .footer-links a:hover {
      color: var(--primary);
    }

    /* ==========================================================================
       Responsive Breakpoints
       ========================================================================== */
    @media (max-width: 1024px) {
      .gallery-grid { grid-template-columns: repeat(3, 1fr); }
      .hero-grid { gap: 36px; }
      .feature-slice, .feature-slice.reverse { gap: 36px; }
    }

    @media (max-width: 960px) {
      .nav-links { display: none; }
      .mobile-menu-toggle { display: inline-flex; }
      .hero-grid { grid-template-columns: 1fr; text-align: center; }
      .hero-desc { margin-left: auto; margin-right: auto; }
      .hero-cta-group { justify-content: center; }
      .hero-meta { justify-content: center; }
      .feature-slice, .feature-slice.reverse { grid-template-columns: 1fr; direction: ltr; text-align: left; }
      .cards-3-col { grid-template-columns: 1fr; }
      .card-top-left { left: 0; }
      .card-bottom-right { right: 0; }
    }

    @media (max-width: 640px) {
      .container { padding: 0 16px; }
      header.site-header .header-inner { height: 60px; }
      .brand-logo-img { width: 34px; height: 34px; }
      .brand-title span.app-name { font-size: 16px; }
      .brand-title span.app-slogan { display: none; }
      .btn { padding: 8px 14px; font-size: 13px; }
      .header-actions .btn-secondary { display: none; }

      .hero-section { padding: 44px 0 36px; }
      .hero-cta-group { flex-direction: column; width: 100%; gap: 10px; }
      .hero-cta-group .download-dropdown-wrapper { width: 100%; }
      .hero-cta-group .btn { width: 100%; }
      .hero-phone-wrap { max-width: 250px; }
      .hero-floating-card { display: none; }

      .gallery-grid { grid-template-columns: repeat(2, 1fr); gap: 10px; }
      .gallery-info { padding: 8px; }
      .gallery-info h4 { font-size: 11px; }
      .gallery-info p { font-size: 10px; }

      .feature-slice-wrap { gap: 50px; }
      .feature-img-box { padding: 18px; border-radius: var(--radius-lg); }
      .feature-img-box img { max-height: 320px; border-radius: 16px; }

      .cta-banner-section { padding: 40px 20px; }
      .cta-buttons { flex-direction: column; width: 100%; }
      .cta-buttons .download-dropdown-wrapper { width: 100%; }
      .cta-buttons .btn { width: 100%; }

      /* Hide inline hover popover on touch screens since click opens top-level modal */
      .download-popover { display: none !important; }

      .popover-grid { grid-template-columns: 1fr; gap: 12px; }
      .qr-card { padding: 10px; }
      .qr-img-box { max-width: 190px; }

      .lightbox-close { top: -40px; right: 4px; width: 34px; height: 34px; font-size: 24px; }
      .footer-inner { flex-direction: column; text-align: center; }
      .footer-links { justify-content: center; gap: 14px; }
    }
  </style>
</head>
<body>

  <!-- Site Header -->
  <header class="site-header">
    <div class="container header-inner">
      <a href="#" class="brand-logo">
        <img src="assets/app_logo.png" alt="知序 Logo" class="brand-logo-img">
        <div class="brand-title">
          <span class="app-name">知序 Ordo</span>
          <span class="app-slogan">知其轻重 · 行止有序</span>
        </div>
      </a>

      <!-- Desktop Navigation Links -->
      <nav class="nav-links">
        <a href="#promo">界面预览</a>
        <a href="#features">核心功能</a>
        <a href="#security">数据安全</a>
        <a href="#themes">主题配色</a>
        <a href="#download">下载应用</a>
      </nav>

      <div class="header-actions">
        <!-- GitHub link (Desktop only) -->
        <a href="https://github.com" target="_blank" class="btn btn-secondary">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/></svg>
          GitHub
        </a>

        <!-- Header Download Button (Hover triggers popover, Click triggers global modal) -->
        <div class="download-dropdown-wrapper header-dropdown">
          <button class="btn btn-primary" onclick="openDownloadModal(event)">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
            下载应用
          </button>
          <!-- Desktop Hover Popover -->
          <div class="download-popover">
            <div class="popover-header">
              <h4>
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2"/><rect x="7" y="7" width="3" height="3"/><rect x="14" y="7" width="3" height="3"/><rect x="7" y="14" width="3" height="3"/></svg>
                获取应用与官方社群交流
              </h4>
              <p>扫码加入知序官方社群，获取最新安装包、抢先体验新功能并与其他用户交流反馈：</p>
            </div>
            <div class="popover-grid">
              <div class="qr-card" onclick="openQrLightbox('assets/qq_group_qr.jpg', '知序 Ordo · QQ 官方交流群', event)">
                <span class="qr-badge">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
                  QQ 官方群
                </span>
                <div class="qr-img-box">
                  <img src="assets/qq_group_qr.jpg" alt="QQ群二维码" loading="lazy">
                  <div class="qr-zoom-tip"><svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line><line x1="11" y1="8" x2="11" y2="14"></line><line x1="8" y1="11" x2="14" y2="11"></line></svg>点击放大</div>
                </div>
                <div class="qr-desc">群内实时获取最新构建包<br>点击可放大扫码</div>
              </div>
              <div class="qr-card" onclick="openQrLightbox('assets/qq_channel_qr.jpg', '知序 Ordo · QQ 官方频道', event)">
                <span class="qr-badge">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="12 2 2 7 12 12 22 7 12 2"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"/></svg>
                  QQ 官方频道
                </span>
                <div class="qr-img-box">
                  <img src="assets/qq_channel_qr.jpg" alt="QQ频道二维码" loading="lazy">
                  <div class="qr-zoom-tip"><svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line><line x1="11" y1="8" x2="11" y2="14"></line><line x1="8" y1="11" x2="14" y2="11"></line></svg>点击放大</div>
                </div>
                <div class="qr-desc">参与版本动态与话题讨论<br>点击可放大扫码</div>
              </div>
            </div>
            <div class="qr-hint-tip">
              <span>手机 QQ 扫一扫直接加入</span>
              <span class="highlight-tag">安装包持续更新中</span>
            </div>
          </div>
        </div>

        <!-- Mobile Menu Hamburger Button -->
        <button class="mobile-menu-toggle" onclick="toggleMobileNav()" aria-label="打开导航菜单">
          <svg viewBox="0 0 24 24"><line x1="3" y1="12" x2="21" y2="12"/><line x1="3" y1="6" x2="21" y2="6"/><line x1="3" y1="18" x2="21" y2="18"/></svg>
        </button>
      </div>
    </div>

    <!-- Mobile Drawer Navigation -->
    <div id="mobile-drawer" class="mobile-nav-drawer">
      <a href="#promo" onclick="toggleMobileNav()">界面预览</a>
      <a href="#features" onclick="toggleMobileNav()">核心功能</a>
      <a href="#security" onclick="toggleMobileNav()">数据安全</a>
      <a href="#themes" onclick="toggleMobileNav()">主题配色</a>
      <a href="javascript:void(0)" onclick="toggleMobileNav(); openDownloadModal()">下载应用</a>
      <a href="https://github.com" target="_blank" onclick="toggleMobileNav()">开源仓库 (GitHub)</a>
    </div>
  </header>

  <!-- Hero Section -->
  <section class="hero-section">
    <div class="hero-bg-glow"></div>
    <div class="container hero-grid">
      <div class="hero-content">
        <div class="hero-badge">
          <svg viewBox="0 0 24 24"><path d="M12 2L15.09 8.26L22 9.27L17 14.14L18.18 21.02L12 17.77L5.82 21.02L7 14.14L2 9.27L8.91 8.26L12 2Z"/></svg>
          全新发布 · 跨平台离线优先待办应用
        </div>
        <h1 class="hero-title">
          知其轻重<br><span class="highlight">行止有序</span>
        </h1>
        <p class="hero-desc">
          专为追求专注与清爽节奏打造的现代化任务管理工具。四态生命周期、三级任务树、全景农历节气日历，搭配离线优先与 WebDAV / S3 私有云同步，让工作与生活回归从容自如。
        </p>
        <div class="hero-cta-group">

          <!-- Hero Download Button -->
          <div class="download-dropdown-wrapper hero-dropdown">
            <button class="btn btn-primary btn-lg" onclick="openDownloadModal(event)">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
              下载应用
            </button>
            <!-- Desktop Hover Popover -->
            <div class="download-popover">
              <div class="popover-header">
                <h4>
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2"/><rect x="7" y="7" width="3" height="3"/><rect x="14" y="7" width="3" height="3"/><rect x="7" y="14" width="3" height="3"/></svg>
                  获取应用与官方社群交流
                </h4>
                <p>扫码加入知序官方社群，获取最新安装包、抢先体验新功能并与其他用户交流反馈：</p>
              </div>
              <div class="popover-grid">
                <div class="qr-card" onclick="openQrLightbox('assets/qq_group_qr.jpg', '知序 Ordo · QQ 官方交流群', event)">
                  <span class="qr-badge">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
                    QQ 官方群
                  </span>
                  <div class="qr-img-box">
                    <img src="assets/qq_group_qr.jpg" alt="QQ群二维码" loading="lazy">
                    <div class="qr-zoom-tip"><svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line><line x1="11" y1="8" x2="11" y2="14"></line><line x1="8" y1="11" x2="14" y2="11"></line></svg>点击放大</div>
                  </div>
                  <div class="qr-desc">群内实时获取最新构建包<br>点击可放大扫码</div>
                </div>
                <div class="qr-card" onclick="openQrLightbox('assets/qq_channel_qr.jpg', '知序 Ordo · QQ 官方频道', event)">
                  <span class="qr-badge">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="12 2 2 7 12 12 22 7 12 2"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"/></svg>
                    QQ 官方频道
                  </span>
                  <div class="qr-img-box">
                    <img src="assets/qq_channel_qr.jpg" alt="QQ频道二维码" loading="lazy">
                    <div class="qr-zoom-tip"><svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line><line x1="11" y1="8" x2="11" y2="14"></line><line x1="8" y1="11" x2="14" y2="11"></line></svg>点击放大</div>
                  </div>
                  <div class="qr-desc">参与版本动态与话题讨论<br>点击可放大扫码</div>
                </div>
              </div>
              <div class="qr-hint-tip">
                <span>手机 QQ 扫一扫直接加入</span>
                <span class="highlight-tag">安装包持续更新中</span>
              </div>
            </div>
          </div>

          <a href="#features" class="btn btn-secondary btn-lg">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>
            了解核心特性
          </a>
        </div>
        <div class="hero-meta">
          <div class="hero-meta-item">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"></polyline></svg>
            离线毫秒响应
          </div>
          <div class="hero-meta-item">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"></polyline></svg>
            无广告与跟踪
          </div>
          <div class="hero-meta-item">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"></polyline></svg>
            WebDAV/S3 私有同步
          </div>
        </div>
      </div>

      <!-- Hero Visual Phone -->
      <div class="hero-visual">
        <div class="hero-phone-wrap">
          <img src="dist/iphone-6.9/01-headline-top-bleed.png" alt="知序今日待办界面">
        </div>

        <!-- Floating highlights (desktop only) -->
        <div class="hero-floating-card card-top-left">
          <div class="floating-icon">
            <svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
          </div>
          <div class="floating-text">
            <h4>今日专注流转</h4>
            <p>清晰优先级与四态流转</p>
          </div>
        </div>

        <div class="hero-floating-card card-bottom-right">
          <div class="floating-icon">
            <svg viewBox="0 0 24 24"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
          </div>
          <div class="floating-text">
            <h4>私有数据主权</h4>
            <p>本地 SQLite + 私有云</p>
          </div>
        </div>
      </div>
    </div>
  </section>

  <!-- Store Promo Shots Gallery Section -->
  <section id="promo" class="promo-gallery-section">
    <div class="container">
      <div class="section-header">
        <span class="section-tag">Interface & Experience</span>
        <h2 class="section-title">优雅极简，行止有序的界面美学</h2>
        <p class="section-desc">
          每一次轻触交互，都回归专注与从容。知序将专业严谨的任务管理理念融入至简优雅的设计中，无论是今日行动聚焦、全景日历纵览，还是敏捷看板流转，每一处细节都清晰利落。
        </p>
      </div>

      <!-- Tabs: Store Shots & Raw App Shots -->
      <div class="gallery-filter-tabs">
        <button class="tab-btn active" onclick="switchTab('store', this)">移动应用商店截图 (5张)</button>
        <button class="tab-btn" onclick="switchTab('raw', this)">真实应用截图 (10张)</button>
      </div>

      <!-- Gallery Grid Container -->
      <div id="gallery-container" class="gallery-grid">
        <!-- Rendered by JS -->
      </div>
    </div>
  </section>

  <!-- Detailed Feature Slices Section -->
  <section id="features">
    <div class="container feature-slice-wrap">

      <!-- Slice 1: Today & Lifecycle -->
      <div class="feature-slice">
        <div class="feature-content">
          <span class="feature-tag-pill">核心理念</span>
          <h2 class="feature-title">知其轻重，聚焦今日待办</h2>
          <p class="feature-desc">
            拒绝无意义的任务堆积与焦虑。知序提供清晰严谨的「待办 → 进行中 → 已完成 / 已放弃」四态生命周期，支持一键激活与灵活重启。直观的 P0/P1/P2/P3 优先级与今日规划，帮助你始终把握最关键的行动。
          </p>
          <ul class="feature-points">
            <li>
              <svg viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"></polyline></svg>
              <span>四态生命周期闭环，告别单选框的含糊不清</span>
            </li>
            <li>
              <svg viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"></polyline></svg>
              <span>今日视图专属排序，按紧急与重要程度自动梯队排列</span>
            </li>
            <li>
              <svg viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"></polyline></svg>
              <span>全手势滑动操作：右滑完成、左滑放弃，指尖行云流水</span>
            </li>
          </ul>
        </div>
        <div class="feature-img-box">
          <img src="shots/01 今日.jpg" alt="今日待办界面">
        </div>
      </div>

      <!-- Slice 2: Calendar & Almanac -->
      <div class="feature-slice reverse">
        <div class="feature-content">
          <span class="feature-tag-pill">全景视角</span>
          <h2 class="feature-title">日程与传统历法同屏呈现</h2>
          <p class="feature-desc">
            将月度全景日历与传统农历、二十四节气、法定节假日深度结合。计划截止日直观标注在日期网格中，点击单日即可迅速展开当日待办与重要节点，让时间规划富有东方文化韵律。
          </p>
          <ul class="feature-points">
            <li>
              <svg viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"></polyline></svg>
              <span>农历、初一十五、二十四节气与放假补班标记</span>
            </li>
            <li>
              <svg viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"></polyline></svg>
              <span>月度热力任务分布点，直观洞察高负荷与空闲周期</span>
            </li>
            <li>
              <svg viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"></polyline></svg>
              <span>跨日拖拽快速重新排期，轻松应对突发变化</span>
            </li>
          </ul>
        </div>
        <div class="feature-img-box">
          <img src="shots/03 日历.jpg" alt="全景日历界面">
        </div>
      </div>

      <!-- Slice 3: Views & Kanban -->
      <div class="feature-slice">
        <div class="feature-content">
          <span class="feature-tag-pill">自由定制</span>
          <h2 class="feature-title">多维视图与敏捷看板</h2>
          <p class="feature-desc">
            不再局限于传统列表！知序支持创建自定义视图，自由设定过滤规则、分组条件与展示样式。无论是多列样式、看板拖拽卡片，还是按文件夹、标签筛选，都能随心搭建契合个人习惯的工作台。
          </p>
          <ul class="feature-points">
            <li>
              <svg viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"></polyline></svg>
              <span>看板视图自由流转，横向滑动直观把控项目流水线</span>
            </li>
            <li>
              <svg viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"></polyline></svg>
              <span>多条件复合过滤：包含标签、匹配状态、排除文件夹</span>
            </li>
            <li>
              <svg viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"></polyline></svg>
              <span>多列并排展示，宽屏与折叠屏设备的绝佳利器</span>
            </li>
          </ul>
        </div>
        <div class="feature-img-box">
          <img src="shots/06 自定义视图-看板样式.jpg" alt="看板视图界面">
        </div>
      </div>

    </div>
  </section>

  <!-- Security, Sync, Architecture Section -->
  <section id="security" class="cards-grid-section">
    <div class="container">
      <div class="section-header">
        <span class="section-tag">Privacy & Architecture</span>
        <h2 class="section-title">离线优先，私有同步与数据主权</h2>
        <p class="section-desc">
          知序始终坚信：待办事项涉及用户最私密的工作与生活节奏，数据必须完全属于用户自己。
        </p>
      </div>

      <div class="cards-3-col">
        <div class="service-card">
          <div class="service-icon">
            <svg viewBox="0 0 24 24"><path d="M18 10h-1.26A8 8 0 1 0 9 20h9a5 5 0 0 0 0-10z"/></svg>
          </div>
          <h3>WebDAV & S3 云端同步</h3>
          <p>
            支持标准 WebDAV 协议与各大 S3 兼容对象存储（如 MinIO、阿里云 OSS、AWS S3 等）。采用中继合并与端到端校验策略，多设备间无冲突合并不丢失任何一条记录。
          </p>
        </div>

        <div class="service-card">
          <div class="service-icon">
            <svg viewBox="0 0 24 24"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
          </div>
          <h3>本地快照与加密备份</h3>
          <p>
            内置本地快照历史池，支持修改误操作一键回滚恢复。随时导出加密或明文 <code>.ordobak</code> 标准备份包，即便无网络也可安全离线冷备份。
          </p>
        </div>

        <div class="service-card">
          <div class="service-icon">
            <svg viewBox="0 0 24 24"><polygon points="12 2 2 7 12 12 22 7 12 2"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"/></svg>
          </div>
          <h3>响应式底层与无缝多端</h3>
          <p>
            基于 Flutter + Riverpod + Drift (SQLite3) 纯原生编译。零外部分析追踪代码，内存极小，毫秒冷启动，完美支持 Android、iOS、桌面与 Web 全端覆盖。
          </p>
        </div>
      </div>
    </div>
  </section>

  <!-- Themes Showcase Section -->
  <section id="themes" class="theme-showcase-section">
    <div class="container">
      <div class="section-header">
        <span class="section-tag">Aesthetic Design</span>
        <h2 class="section-title">八款东方雅致主题</h2>
        <p class="section-desc">
          汲取传统中国色调美学，精心调配 8 套高对比度、符合 WCAG 标准的质感配色，完美兼容浅色与深色模式。
        </p>
      </div>

      <div class="theme-palette-bar">
        <div class="theme-chip-btn active" onclick="previewTheme('#05976A', '松绿 (默认)', this)">
          <span class="theme-circle" style="background: #05976A;"></span> 松绿 (默认)
        </div>
        <div class="theme-chip-btn" onclick="previewTheme('#18181B', '墨黑', this)">
          <span class="theme-circle" style="background: #18181B;"></span> 墨黑
        </div>
        <div class="theme-chip-btn" onclick="previewTheme('#3B82F6', '皓白/群青', this)">
          <span class="theme-circle" style="background: #3B82F6;"></span> 群青
        </div>
        <div class="theme-chip-btn" onclick="previewTheme('#4F46E5', '黛蓝', this)">
          <span class="theme-circle" style="background: #4F46E5;"></span> 黛蓝
        </div>
        <div class="theme-chip-btn" onclick="previewTheme('#DC2626', '丹砂', this)">
          <span class="theme-circle" style="background: #DC2626;"></span> 丹砂
        </div>
        <div class="theme-chip-btn" onclick="previewTheme('#9333EA', '紫棠', this)">
          <span class="theme-circle" style="background: #9333EA;"></span> 紫棠
        </div>
        <div class="theme-chip-btn" onclick="previewTheme('#D97706', '琥珀', this)">
          <span class="theme-circle" style="background: #D97706;"></span> 琥珀
        </div>
      </div>
      <p id="theme-preview-tip" style="font-size: 13px; color: var(--text-sub);">点击上方色块，可实时切换本页面的品牌主色调预览！</p>
    </div>
  </section>

  <!-- CTA Banner & Download Section -->
  <section id="download" class="container">
    <div class="cta-banner-section">
      <h2>知其轻重，即刻开启有序生活</h2>
      <p>
        体验纯净、快速、无压力的待办与项目管理。所有数据完全由你掌控，无广告、无多余通知打扰。
      </p>
      <div class="cta-buttons">

        <!-- CTA Download Button -->
        <div class="download-dropdown-wrapper cta-dropdown">
          <button class="btn btn-white btn-lg" onclick="openDownloadModal(event)">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
            下载应用
          </button>
          <!-- Desktop Hover Popover -->
          <div class="download-popover">
            <div class="popover-header">
              <h4>
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2"/><rect x="7" y="7" width="3" height="3"/><rect x="14" y="7" width="3" height="3"/><rect x="7" y="14" width="3" height="3"/></svg>
                获取应用与官方社群交流
              </h4>
              <p>扫码加入知序官方社群，获取最新安装包、抢先体验新功能并与其他用户交流反馈：</p>
            </div>
            <div class="popover-grid">
              <div class="qr-card" onclick="openQrLightbox('assets/qq_group_qr.jpg', '知序 Ordo · QQ 官方交流群', event)">
                <span class="qr-badge">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
                  QQ 官方群
                </span>
                <div class="qr-img-box">
                  <img src="assets/qq_group_qr.jpg" alt="QQ群二维码" loading="lazy">
                  <div class="qr-zoom-tip"><svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line><line x1="11" y1="8" x2="11" y2="14"></line><line x1="8" y1="11" x2="14" y2="11"></line></svg>点击放大</div>
                </div>
                <div class="qr-desc">群内实时获取最新构建包<br>点击可放大扫码</div>
              </div>
              <div class="qr-card" onclick="openQrLightbox('assets/qq_channel_qr.jpg', '知序 Ordo · QQ 官方频道', event)">
                <span class="qr-badge">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="12 2 2 7 12 12 22 7 12 2"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"/></svg>
                  QQ 官方频道
                </span>
                <div class="qr-img-box">
                  <img src="assets/qq_channel_qr.jpg" alt="QQ频道二维码" loading="lazy">
                  <div class="qr-zoom-tip"><svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line><line x1="11" y1="8" x2="11" y2="14"></line><line x1="8" y1="11" x2="14" y2="11"></line></svg>点击放大</div>
                </div>
                <div class="qr-desc">参与版本动态与话题讨论<br>点击可放大扫码</div>
              </div>
            </div>
            <div class="qr-hint-tip">
              <span>手机 QQ 扫一扫直接加入</span>
              <span class="highlight-tag">安装包持续更新中</span>
            </div>
          </div>
        </div>

        <a href="#features" class="btn btn-outline-white btn-lg">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>
          探索更多特性
        </a>
      </div>
    </div>
  </section>

  <!-- Site Footer -->
  <footer class="site-footer">
    <div class="container footer-inner">
      <div class="footer-brand">
        <strong>知序 Ordo</strong> — 知其轻重，行止有序
      </div>
      <div class="footer-links">
        <a href="#promo">界面预览</a>
        <a href="#features">核心功能</a>
        <a href="#security">数据安全</a>
        <a href="#themes">主题配色</a>
        <a href="javascript:void(0)" onclick="openDownloadModal()">官方交流群与下载</a>
      </div>
      <div class="footer-copy">
        &copy; 2026 知序 Ordo. All rights reserved.
      </div>
    </div>
  </footer>

  <!-- ==========================================================================
       Top-Level Universal Download Modal (Never trapped by header stacking context)
       ========================================================================== -->
  <div id="global-download-modal" class="global-modal-backdrop" onclick="closeDownloadModal(event)">
    <div class="global-modal-content" onclick="event.stopPropagation()">
      <button class="modal-close-btn" onclick="closeDownloadModal()" aria-label="关闭">&times;</button>
      <div class="popover-header">
        <h4>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2"/><rect x="7" y="7" width="3" height="3"/><rect x="14" y="7" width="3" height="3"/><rect x="7" y="14" width="3" height="3"/></svg>
          获取应用与官方社群交流
        </h4>
        <p>扫码加入知序官方社群，获取最新安装包、抢先体验新功能并与其他用户交流反馈：</p>
      </div>
      <div class="popover-grid">
        <div class="qr-card" onclick="openQrLightbox('assets/qq_group_qr.jpg', '知序 Ordo · QQ 官方交流群', event)">
          <span class="qr-badge">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
            QQ 官方群
          </span>
          <div class="qr-img-box">
            <img src="assets/qq_group_qr.jpg" alt="QQ群二维码" loading="lazy">
            <div class="qr-zoom-tip"><svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line><line x1="11" y1="8" x2="11" y2="14"></line><line x1="8" y1="11" x2="14" y2="11"></line></svg>点击放大</div>
          </div>
          <div class="qr-desc">群内实时获取最新构建包<br>点击可放大扫码</div>
        </div>
        <div class="qr-card" onclick="openQrLightbox('assets/qq_channel_qr.jpg', '知序 Ordo · QQ 官方频道', event)">
          <span class="qr-badge">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="12 2 2 7 12 12 22 7 12 2"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"/></svg>
            QQ 官方频道
          </span>
          <div class="qr-img-box">
            <img src="assets/qq_channel_qr.jpg" alt="QQ频道二维码" loading="lazy">
            <div class="qr-zoom-tip"><svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line><line x1="11" y1="8" x2="11" y2="14"></line><line x1="8" y1="11" x2="14" y2="11"></line></svg>点击放大</div>
          </div>
          <div class="qr-desc">参与版本动态与话题讨论<br>点击可放大扫码</div>
        </div>
      </div>
      <div class="qr-hint-tip">
        <span>手机 QQ 扫一扫直接加入</span>
        <span class="highlight-tag">安装包持续更新中</span>
      </div>
    </div>
  </div>

  <!-- Lightbox Modal (For screenshots & full QR magnification) -->
  <div id="lightbox" class="lightbox-modal" onclick="closeLightbox(event)">
    <div class="lightbox-content">
      <button class="lightbox-close" onclick="closeLightbox()">&times;</button>
      <img id="lightbox-img" class="lightbox-img" src="" alt="放大预览">
      <div id="lightbox-caption" class="lightbox-caption"></div>
    </div>
  </div>

  <script>
    // Toggle Mobile Navigation Drawer
    function toggleMobileNav() {
      const drawer = document.getElementById('mobile-drawer');
      drawer.classList.toggle('active');
    }

    // Open/Close Universal Top-Level Download Modal
    function openDownloadModal(event) {
      if (event) {
        event.stopPropagation();
        event.preventDefault();
      }
      const modal = document.getElementById('global-download-modal');
      if (modal) modal.classList.add('active');
    }

    function closeDownloadModal(event) {
      if (!event || event.target === document.getElementById('global-download-modal') || event.target.classList.contains('modal-close-btn')) {
        const modal = document.getElementById('global-download-modal');
        if (modal) modal.classList.remove('active');
      }
    }

    // Universal QR Lightbox opener
    function openQrLightbox(qrKey, title, event) {
      if (event) {
        event.stopPropagation();
      }
      let src = qrKey;
      if (typeof EMBEDDED_ASSETS !== 'undefined' && EMBEDDED_ASSETS[qrKey]) {
        src = EMBEDDED_ASSETS[qrKey];
      }
      openLightbox(src, title);
    }

    // Gallery Data Sets: Store Promo Shots & Raw App Screenshots
    const galleryData = {
      store: [
        {
          title: "01 今日专注待办",
          sub: "知其轻重 · 行止有序",
          img: "dist/iphone-6.9/01-headline-top-bleed.png",
          badge: "精选特性"
        },
        {
          title: "02 全景日历与农历节气",
          sub: "全景日历 · 农历节气同屏",
          img: "dist/iphone-6.9/02-headline-top-float.png",
          badge: "精选特性"
        },
        {
          title: "03 自由看板定制视图",
          sub: "自由看板 · 随心定制视图",
          img: "dist/iphone-6.9/03-headline-bottom.png",
          badge: "精选特性"
        },
        {
          title: "04 灵感收集箱速记",
          sub: "即想即录 · 灵感不遗漏",
          img: "dist/iphone-6.9/04-tilted.png",
          badge: "精选特性"
        },
        {
          title: "05 任务树与多维组织",
          sub: "多维结构 · 任务层层分明",
          img: "dist/iphone-6.9/05-stack.png",
          badge: "精选特性"
        }
      ],
      raw: [
        { title: "01 今日", sub: "聚焦今日待办清单", img: "shots/01 今日.jpg", badge: "真实截图", aspect: "aspect-raw" },
        { title: "02 收件箱", sub: "快速收集捕获灵感", img: "shots/02 收件箱.jpg", badge: "真实截图", aspect: "aspect-raw" },
        { title: "03 日历", sub: "月视图与农历节气", img: "shots/03 日历.jpg", badge: "真实截图", aspect: "aspect-raw" },
        { title: "04 概览", sub: "三级任务树与项目", img: "shots/04 概览.jpg", badge: "真实截图", aspect: "aspect-raw" },
        { title: "05 新建自定义视图", sub: "条件过滤与排序分组", img: "shots/05 新建自定义视图.jpg", badge: "真实截图", aspect: "aspect-raw" },
        { title: "06 多列样式视图", sub: "多维度并列对比", img: "shots/06 自定义视图-多列样式.jpg", badge: "真实截图", aspect: "aspect-raw" },
        { title: "06 看板样式视图", sub: "横向卡片流动看板", img: "shots/06 自定义视图-看板样式.jpg", badge: "真实截图", aspect: "aspect-raw" },
        { title: "07 设置 - 选项", sub: "主题与偏好设置", img: "shots/07 设置 1.jpg", badge: "真实截图", aspect: "aspect-raw" },
        { title: "07 设置 - 云同步", sub: "WebDAV 与 S3 配置", img: "shots/07 设置 2.jpg", badge: "真实截图", aspect: "aspect-raw" },
        { title: "07 设置 - 备份容灾", sub: "本地快照池与导出", img: "shots/07 设置 3.jpg", badge: "真实截图", aspect: "aspect-raw" }
      ]
    };

    function renderGallery(tabKey) {
      const list = galleryData[tabKey] || [];
      const container = document.getElementById('gallery-container');
      container.innerHTML = list.map(item => {
        let src = item.img;
        if (typeof EMBEDDED_ASSETS !== 'undefined' && EMBEDDED_ASSETS[item.img]) {
          src = EMBEDDED_ASSETS[item.img];
        }
        return `
        <div class="gallery-item" onclick="openLightbox('${src}', '${item.title} - ${item.sub}')">
          <div class="gallery-thumb ${item.aspect || ''}">
            <img src="${src}" alt="${item.title}" loading="lazy">
            <span class="gallery-overlay-badge">${item.badge}</span>
          </div>
          <div class="gallery-info">
            <h4>${item.title}</h4>
            <p>${item.sub}</p>
          </div>
        </div>
      `;
      }).join('');
    }

    function switchTab(tabKey, btn) {
      document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      renderGallery(tabKey);
    }

    // Lightbox Controls
    function openLightbox(src, caption) {
      const modal = document.getElementById('lightbox');
      const img = document.getElementById('lightbox-img');
      const cap = document.getElementById('lightbox-caption');
      img.src = src;
      cap.textContent = caption;
      modal.classList.add('active');
    }

    function closeLightbox(e) {
      if (!e || e.target === document.getElementById('lightbox') || e.target.classList.contains('lightbox-close')) {
        document.getElementById('lightbox').classList.remove('active');
      }
    }

    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        closeLightbox();
        closeDownloadModal();
      }
    });

    // Theme Switcher Demo
    function previewTheme(colorHex, name, el) {
      document.documentElement.style.setProperty('--primary', colorHex);
      let c = colorHex.replace('#', '');
      let r = parseInt(c.substring(0, 2), 16);
      let g = parseInt(c.substring(2, 4), 16);
      let b = parseInt(c.substring(4, 6), 16);
      document.documentElement.style.setProperty('--primary-rgb', `${r}, ${g}, ${b}`);

      document.querySelectorAll('.theme-chip-btn').forEach(b => b.classList.remove('active'));
      el.classList.add('active');
      document.getElementById('theme-preview-tip').textContent = `当前预览主题色：${name} (${colorHex})`;
    }

    // Init
    renderGallery('store');
  </script>
</body>
</html>
'''

with open("/mnt/Data/Personal/04_others/My_Development/todo/promo/index.html", "w", encoding="utf-8") as f:
    f.write(html_content)

print("Regenerated promo/index.html with top-level universal modal!")
