# bullrithm

Bullrithm adalah aplikasi Flutter untuk eksplorasi saham berbasis Alpha Vantage API.

## Menjalankan App

1. Install dependency:
```bash
flutter pub get
```

2. Jalankan app dengan URL Cloudflare Worker proxy:
```bash
flutter run --dart-define=ALPHA_VANTAGE_PROXY_URL=https://your-domain.com/query
```

Contoh URL untuk Worker:
- `https://bullrithm-proxy.<subdomain>.workers.dev/query`

## Keamanan API Key

- App ini hanya mendukung mode proxy untuk Alpha Vantage.
- API key tidak disimpan di Flutter client.
- API key harus disimpan di server-side secret (contoh: Cloudflare Worker Secret).
- Flutter hanya memanggil endpoint proxy `ALPHA_VANTAGE_PROXY_URL`.

Catatan: pastikan Worker mengizinkan function yang dibutuhkan app (`SYMBOL_SEARCH`, `OVERVIEW`, `TIME_SERIES_DAILY`, `NEWS_SENTIMENT`, `TOP_GAINERS_LOSERS`) atau sediakan endpoint terpisah.

## Setup Worker (ringkas)

1. Buat Worker di Cloudflare Dashboard.
2. Copy isi `cloudflare/worker.js` ke editor Worker.
3. Set secret:
   - `ALPHA_VANTAGE_KEY` = API key Alpha Vantage
4. (Opsional, direkomendasikan) set variable biasa:
   - `ALLOWED_ORIGIN` = origin Flutter Web kamu (contoh `https://bullrithm.pages.dev`)
