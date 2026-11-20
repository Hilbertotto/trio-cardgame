# TRIO aktuális átadás

## Négy ranglistanézet és rezgés – 2026-11-20

- Új 941x1672 ranglistapanel, négy szűrő: globális/országos, teljes/napi. Ranglista modal a kezdőképernyő fölött, dinamikus címmel és kijelölt gombbal.
- API scope=global|country, period=all|daily. Napi pontok point_transactions összegéből, Europe/Budapest napi határok UTC-re alakítva; csak pozitív napi ponttal szerepel valaki. Ország a saját profil országkódja, hiányában 422.
- Szerverjavítás telepítve, PHP szintaxis ellenőrizve. Országos/napi regressziós teszt hozzáadva, futtatás még PHP fejlesztői környezetet igényel.
- Triónál egy mediumImpact, győzelemnél két mediumImpact 220ms különbséggel, helyben és online állapotváltáskor.
- Flutter tesztek 3/3, debug build sikeres. Emulátor frissítve; fizikai teszt APK: G:\Saját meghajtó\applikacio\trio\TRIO-test-latest.apk. Rezgés és ranglistaszűrők kézi ellenőrzése következik.

## Globális ranglista és profil – 2026-11-20

- Új kezdőkép alsó középső Ranglista gombbal; megnyitáskor hitelesített GET /api/v1/leaderboard: top 5 és saját helyezés, pont szerint, id holtverseny-sorrenddel, vendégek nélkül.
- Ranglistanézet a mellékelt háttérrel, avatarral, teljes névvel, országzászlóval és ponttal. Országos/napi szűrés még nincs.
- Szerver profiles: full_name és country_code mezők, PATCH /api/v1/profile. Google-név alapérték, ország kézi kétbetűs kód (HU stb.). Profil szerkesztés ranglista jobb felső gombjáról; hiányzó országnál automatikus adatbekérés.
- Szerverre git pull és adatbázis-migráció sikeresen lefutott. PHP szintaxis és route-regisztráció ellenőrizve. Laravel regressziós teszt hozzáadva, de éles környezetben nincs test parancs; ott tesztet nem futtattunk.
- Flutter tesztek 3/3 és debug build sikeres. Emulátorra telepítve; teljes Google-belépéses és ranglista/profil kézi próba következik.

## Ranglista háttér – 2026-11-20

- A felhasználó ranglistagrafikája elmentve: mobile/assets/design/leaderboard_panel.png.
- Öt kiemelt hely és alsó saját helyezés mező van rajta. A globális cím a kép része; országos/napi nézethez dinamikus címezés szükséges.
- A ranglista API és kliensnézet még nincs megvalósítva. Korábbi igény: globális, országos és napi rangpontlista; országot külön választani, Google országinformációra nem támaszkodni.
- Ebben a menetben kizárólag grafikai asset és dokumentáció került be, build nem futott.

- 2026-11-20: A szerverpanel ismétlődő alsó sárga alapüzenete eltávolítva. A képen lévő útmutató és a tényleges hibák visszajelzése megmarad. Debug build és emulátortelepítés sikeres.

- 2026-11-20: Csatlakozás/Belépés felirat betűmérete 25-ről 22-re csökkent, stílus megtartva. Debug build sikeres, emulátor frissítve.

## Hangok és szerverpanel tipográfia – 2026-11-20

- Android natív MethodChannel és halk ToneGenerator jelzés: lapfelfedés rövid beep, trió rövid ACK. Média hangerőt követ. Helyi és online felfedéshez bekötve; hangzás kézi ellenőrzendő.
- Csatlakozás/Belépés felirat vastag serif, enyhe árnyékkal. Szobakód szöveg középre igazítva, dupla számláló takarása javítva.
- Emulátor újraindult hw.keyboard=yes konfigurációval, virtuális billentyűzet is engedélyezett. Kézi bevitel még ellenőrzendő.
- Flutter tesztek 3/3, debug build és emulátortelepítés sikeres.

## Szerverpanel vissza és input javítás – 2026-11-20

- Szobakód mező kitöltése átlátszó. A grafikus Vissza gomb visszaállítja a játékválasztót.
- A TextEditingController felszabadítása a dialog route completed állapotát várja meg a bezáró animáció miatti korai dispose elkerülésére.
- Flutter 3/3 teszt, debug build és emulátortelepítés sikeres; a felhasználó által jelzett visszalépési hiba kézi újrapróbálása szükséges.

## Szerverjáték grafikus panel – 2026-11-20

- Új server_panel.png a felhasználó mellékletéből. Szobakód nélkül az alsó gomb Csatlakozás (X fő), kóddal Belépés a szobába. A szobalétrehozás külön képgomb maradt.
- A várakozó szoba továbbra is a meglévő résztvevőlistás felületet használja.
- Flutter tesztek 3/3 és debug build sikeres; emulátorra telepítve. Vizuális és online végponttól végpontig ellenőrzés még szükséges.

## Profilnév és győzelmi érmejelzés – 2026-11-20

- Helyi játékban a bejelentkezett profil neve jelenik meg; a nevet a kliens menti és profilfrissítésből is átveszi.
- A győzelmi panel arany érmeikonnal mutatja a játék eleji és szerverről frissített egyenleg különbségét, alatta az egyenleget. A jutalom pontos külön API-mezőre váltása később javasolt, ha párhuzamos jóváírások is lehetnek.
- Flutter tesztek 3/3, debug build és emulátortelepítés sikeres.

## Animált szabálybemutató – 2026-11-20

- A szabálymodal 15 másodperces ismétlődő lapfordítós bemutatót kapott: két eltérő lap, két egyforma és egy eltérő, végül három egyforma.
- Hibánál szöveges visszajelzés és visszafordítás, sikeres triónál kiemelkedés és zöld fény jelzi a helyes megoldást.
- Flutter tesztek 3/3 sikeresek, debug APK build sikeres; emulátorra telepítve.
- Új widget: mobile/lib/rules_card_demo.dart. Kézi vizuális ellenőrzés következik a Játékszabály ablakban.

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
- A kezdőképernyő háttérképe és a be-/kijelentkezési gombok a kapott TRIO-grafikákra cserélve.
- A kapott gombgrafika mérete nagyobb lett, hogy jobban illeszkedjen a kezdőképernyő arányaihoz.

## Online köridő meghosszabbítása – 2026-11-19

- A szerveres játék körideje 40 másodpercről 120 másodpercre nőtt (90 mp alapidő + 30 mp figyelmeztetési szakasz).
- A kliens megszakítási üzenete ehhez a 30 másodperces türelmi időhöz igazodott.

## Laravel API 500 javítása – 2026-11-19

- Az Apache naplóban `Target class [view] does not exist` hiba jelent meg.
- A `ViewServiceProvider` regisztrálva lett, és létrejött a hiányzó `config/view.php`.
- Szerveren frissítés után `composer dump-autoload` és `php artisan optimize:clear` szükséges.
- A friss log megmutatta a `Route [login] not defined` hibát; az API vendégkérései most nem irányulnak webes login route-ra.

## Azonnali WINNER matchmaking után

- Ok: a JoinMatchmakingAction a korábbi bejegyzés szobáját állapotellenőrzés nélkül visszaadta.
- Javítás: csak várakozó/aktív, győztes nélküli szoba és emberi játékoshely használható újra. Lezárt játék résztvevőit megőrizzük.
- Laravel teszt blokkolva: helyi PHP 8.2.12, szükséges >=8.3. Szerveren php artisan test futtatandó.
- Következő lépés: szerver frissítése és új véletlen keresés ellenőrzése.
- A felhasználó igazolta a 3edead8 éles letöltését. Három emulátor fut, TRIO megnyitva; a teljes új online játék még ellenőrizendő.

## Drive-mentés és részletes átadás

- Részletes leírás: docs/BACKUP_HANDOFF_2026-11-19.md; környezet, javítások, jogosultságok, tesztek és visszaállítási korlátok.
- Dátumozott forrás ZIP, release teszt APK és kontextusmásolat készül a Drive applikacio/trio/backups mappájába, SHA256 ellenőrzéssel.
- Ez forrás- és kliensmentés; éles adatbázist és titkokat nem tartalmaz. Új build/játékteszt a mentési menetben nem futott.
