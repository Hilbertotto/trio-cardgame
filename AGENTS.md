# TRIO fejlesztési utasítások

Minden munka megkezdése előtt olvasd el teljesen:

1. `docs/PROJECT_CONTEXT.md`
2. az érintett komponens README-jét és konfigurációját

## Repó felépítése

- A repó gyökere Laravel alkalmazás. Ne helyezd át alkönyvtárba, mert az Ubuntu telepítés erre a szerkezetre épül.
- A Flutter kliens a `mobile/` mappában van.
- A mobil és a szerver együtt alkotja a terméket; API-változásnál mindkét oldalt ellenőrizd.

## Biztonság

Soha ne commitold:

- `.env` vagy valódi adatbázis-/OAuth-jelszavak
- `mobile/android/key.properties`
- `.jks` vagy `.keystore` aláírókulcs
- APK/AAB, build cache, `vendor/`, `.dart_tool/`, Android `.gradle/`

Titoknak tűnő adatot push előtt ellenőrizz. Ne cseréld le a package ID-t
(`hu.triogame.trio_android`) és a Play aláírást egyeztetés nélkül.

## Minőségi kapuk

- Flutter: `cd mobile`, majd `flutter test` és legalább egy Android debug build.
- Laravel: `composer install` után `php artisan test`.
- Ne engedd, hogy a bot rejtett lapértéket használjon döntéshez.
- A szerveres játékban a kliens nem lehet a hiteles játékállapot forrása.

## Projektmemória karbantartása

Jelentős funkció, architekturális döntés, telepítési változás vagy ismert
hiba után frissítsd a `docs/PROJECT_CONTEXT.md` dokumentumot. Ez adja át a
kontextust a következő gépen dolgozó Codexnek.

Minden fejlesztési menet végén frissítsd a `docs/CURRENT_HANDOFF.md` fájlt is:

- mi készült el az adott menetben;
- milyen tesztek futottak le;
- mi a következő konkrét feladat;
- van-e ismert hiba vagy blokkoló körülmény.

Ezután futtasd Windows alatt:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\sync-context.ps1
```

Ha a Google Drive `G:` meghajtó elérhető, a szkript a projektmemóriát a
`G:\Saját meghajtó\applikacio\trio\context` mappába is elmenti. A kontextusfájlokat
commitold és pushold is, hogy a Drive nélküli gépek is megkapják.
