# TRIO kártyajáték

Egy közös repóban található a Flutter Android kliens és a Laravel többjátékos szerver.

## Mappák

- `mobile/` – Flutter alkalmazás Androidra
- `app/`, `routes/`, `database/`, `config/` – Laravel API-szerver
- `docs/PROJECT_CONTEXT.md` – projektmemória fejlesztőknek és Codexnek
- `scripts/setup-windows.ps1` – új Windows fejlesztőgép ellenőrzése

## Első indítás Windows alatt

```powershell
git clone https://github.com/Hilbertotto/trio-cardgame.git C:\dev\trio-cardgame
cd C:\dev\trio-cardgame
powershell -ExecutionPolicy Bypass -File .\scripts\setup-windows.ps1
```

Az Android kiadási kulcs, a `mobile/android/key.properties` és a Laravel `.env`
nem része a repónak. Ezeket biztonságos csatornán kell az új gépre másolni.

## Napi munkafolyamat

Munka előtt:

```powershell
git pull --ff-only
```

Munka után:

```powershell
git status
git add -A
git commit -m "Rövid leírás"
git push
```

Részletes állapot: [docs/PROJECT_CONTEXT.md](docs/PROJECT_CONTEXT.md).
