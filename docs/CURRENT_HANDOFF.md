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

## Jutalmazási rendszer első mérföldköve – 2026-11-19

- A felhasználókhoz virtuális érmeegyenleg és külön `coin_transactions` napló került.
- A győztes 3, 4, 5 és 6 fős szobában rendre 100, 120, 140 vagy 160 érmét kap.
- A meglévő rangpont-elszámolás megmaradt.
- A lezárt mérkőzés jutalmazását a játékterem API automatikusan meghívja, és ismételt lekérésre sem duplázza.
- A Laravel tesztek ezen a gépen nem futtathatók, mert a telepített PHP 8.2.12, a projekt PHP 8.3-at igényel. Az érintett PHP-fájlok szintaktikai ellenőrzése sikeres.
- Következő feladat: jutalomcsomag visszaadása az API-ban, majd napi küldetések és rangpont-statisztikák.

## Android érmék megjelenítése – 2026-11-19

- A Flutter kliens belépés után átveszi a szerver által visszaadott `coins` egyenleget.
- A lezárt online játék eredménypanelén megjelenik az aktuális „Érmeegyenleg”.
- A profil újratöltése csak akkor történik meg, amikor a játék először lezárul, ezért az ismételt polling nem indít felesleges kéréseket.
- Flutter tesztek: 3/3 sikeres. Debug APK elkészült.
- A teszt APK Drive-másolata: `G:\Saját meghajtó\apllikacio\trio-cardgame-test.apk`.

## Gép elleni játék és megjegyzett belépés – 2026-11-19

- A bejelentkezési gomb most Google-belépést indít; sikeres belépés után a játékos a játékbeállításokhoz jut.
- A Sanctum token és az alap játékosadatok helyben megmaradnak, ezért az alkalmazás újraindítása után nem kell ismét belépni.
- Bejelentkezett játékos gép elleni győzelme külön hitelesített API-végponton kerül pontozásra, ismétlés ellen egyedi játékazonosító véd.
- Az új debug APK ismét a `G:\Saját meghajtó\apllikacio\trio-cardgame-test.apk` fájlban van.

## Google-belépés javítása – 2026-11-19

- A szerver Web Client ID-ja az eredeti `geobj7...` azonosító; az OAuth-fájlban lévő `installed` kliens nem használható szerver Web Clientként.
- Az app és a SolarisMiner `.env` ismét ugyanazt a Web Client ID-t használja.
- Az Android OAuth belépéshez a Google Cloud Console-ban az alkalmazás package ID-jához és SHA-1 aláírásához Android OAuth klienst is fel kell venni.

## TRIO-számláló az avatarok mellett – 2026-11-19

- A kapott TRIO-kártyagrafika bekerült az avatarok mellé.
- A kártya közepén játék közben látszik az adott játékos által megszerzett triók száma.
- Helyi és szerveres játékban is a játékállapotból frissül.
- Flutter tesztek: 3/3 sikeres; Android debug APK build sikeres.

## TRIO-kártya elhelyezése – 2026-11-19

- A TRIO-számláló kártyapakli az avatar bal oldalára került, a gépes referenciaelrendezéshez igazítva.
- A számláló most külön 0, 1, 2 és 3 értékű TRIO-kártyaképeket használ, nem ráírt szöveget.
- A triószámláló paklikártyája nagyobb lett (72×86), és kijjebb került az avatar bal oldalán.

## Játékszabály modal – 2026-11-19

- A kezdőképernyő alsó Játékszabály gombja most kattintható.
- Türkiz–sárga, TRIO-stílusú modal készült saját `cards_new` kártyaképekkel és a játék rövid szabályaival.
- Flutter tesztek: 3/3 sikeres; release APK build sikeres.

## Dinamikus bejelentkezés/kijelentkezés – 2026-11-19

- A kezdőképernyő statikus bejelentkezési feliratát lefedő, egységes dinamikus gomb készült.
- Kijelentkezve „Bejelentkezés”, mentett munkamenetnél „Kijelentkezés” látszik.
- A sima „Játék indítása” nem kér belépést; hitelesítés csak szerveres játékhoz szükséges.
- Kijelentkezéskor törlődik a helyben mentett token, játékosazonosító és érmeegyenleg.

## Ikonos bejelentkezési gomb – 2026-11-19

- A kezdőképernyő mintaképéhez igazítva a gomb most csak az állapotnak megfelelő ikont mutatja, felirat nélkül.
