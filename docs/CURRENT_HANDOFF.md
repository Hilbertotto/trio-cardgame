# TRIO aktuális átadás

Frissítve: 2026-11-19

## Legutóbbi elkészült munka

- A Laravel szerver és a Flutter Android kliens egyetlen GitHub-repóba került.
- A mobilalkalmazás a `mobile/` mappában található az összes használt grafikai eszközzel.
- Elkészült a Soft, Medium és Hard helyi botnehézség.
- A Medium legfeljebb két teljes játékoskörig emlékszik a felfedett lapokra.
- A Hard a játék végéig emlékszik a nyilvánosan felfedett lapokra.
- Egyik bot sem használhat kezdetben rejtett lapértéket a döntéshez.
- A projektmemória és a több gépes Windows setup szkript elkészült.
- Az Android aláírás, Laravel `.env`, Google OAuth és SSH fájlok külön
  mentése elkészült a Google Drive TRIO mappájában.

## Ellenőrzések

- Flutter widgettesztek: 3/3 sikeres.
- Flutter Android debug build: sikeres.
- GitHub push: sikeres, `main` ág.
- Titokellenőrzés: aláírókulcs, `.env`, OAuth-secret és SSH-kulcs nincs Gitben.
- Laravel teszt ezen a Windows-gépen nem futott, mert a `php` nincs a PATH-ban.

## Következő feladat

- A Soft/Medium/Hard nehézségválasztás teljes játékmenetes kézi tesztelése
  Android emulátoron és fizikai telefonon.
- Szükség esetén a Medium és Hard döntési stratégiájának finomhangolása.

## Fejlesztés másik gépen

```powershell
git clone https://github.com/Hilbertotto/trio-cardgame.git C:\dev\trio-cardgame
cd C:\dev\trio-cardgame
powershell -ExecutionPolicy Bypass -File .\scripts\setup-windows.ps1 -InstallDependencies
```

A Codex először az `AGENTS.md`, majd a `docs/PROJECT_CONTEXT.md` és ezt a fájlt
olvassa el.

## Új Windows fejlesztőgép – 2026-11-19

- A C:\dev\trio-cardgame munkapéldány frissítve a GitHub main ágáról.
- A Drive-ról átmásolt Android key.properties és upload-keystore.jks hash alapján ellenőrizve, Git által figyelmen kívül hagyva. A storeFile útvonal feloldható.
- A szerver éles .env és az OAuth JSON külön, a felhasználói .trio mappában van. Az SSH kulcspár a felhasználói .ssh mappába került. A privát fájlok nem kerültek Gitbe.
- Flutter 3.44.9, Android SDK C:\Android\Sdk, Pixel_7 AVD.
- Flutter tesztek 3/3 sikeresek.
- A composer install a PHP-verzió ellenőrzésén megállt. A PATH PHP 8.2.12 verziót tartalmaz, a függőségek legalább 8.3-at igényelnek. Laravel tesztek nem futottak.

- Felhasználói előírás ezen a gépen: szerverelérés kizárólag solarisminer.com domainen, SSH 8022 porton. Az Android API továbbra is https://trio.solarisminer.com/api/v1.
- Android debug build sikeres, 1.0.2+3. Az APK telepítése sikeres. A korábbi Pixel_7 feloldatlan Android-felhasználója miatt külön TRIO_Test emulátor készült a meglévő Android 35 rendszerképből. Ezen az alkalmazás telepítése és indítása sikeres, a MainActivity előtérben van (adb ResumedActivity). Az ablak képrögzítése időtúllépést adott, vizuális ellenőrzés nem történt.
