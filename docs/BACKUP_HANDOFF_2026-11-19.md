# TRIO részletes mentés és átadás – 2026-11-19

## A mentés tartalma

A Drive backups könyvtárának dátumozott almappája a Gitben követett forráskód ZIP-archívumát, a legutóbb elkészült release teszt APK-t és a projekt kontextusfájljait tartalmazza. A ZIP nem tartalmaz függőségeket, build cache-t, helyi emulátornaplókat vagy Git történetet. A Git történet a GitHubon érhető el.

Nem teljes szervermentés: éles adatbázis, szerver .env, OAuth titkok, SSH-kulcs és Android aláírókulcs nincs benne. Ezek visszaállításhoz külön szükségesek. A Drive fájlmásolat és SHA256 ellenőrzés helyben igazolható; a felhőszinkron befejeződését külön kell ellenőrizni a Drive-ban.

## Környezet és elérhetőségek

- Helyi forrás: C:\dev\trio-cardgame; Laravel a gyökérben, Flutter a mobile könyvtárban.
- GitHub: https://github.com/Hilbertotto/trio-cardgame, main ág.
- API: https://trio.solarisminer.com/api/v1.
- Ubuntu: solarisminer.com, SSH port 8022, felhasználó hilbi1.
- Szerverkönyvtár: /var/www/trio-cardgame; Apache DocumentRoot: public alkönyvtár.
- Szerveren jelentett verziók: PHP 8.3.6, Laravel 13.42.0, MySQL.
- Android package: hu.triogame.trio_android. Package ID és aláírás nem cserélhető.
- Három elérhető emulátor: emulator-5554, emulator-5556, emulator-5558. AVD-k: Pixel_7, TRIO_Test, TRIO_Test_2; AVD tároló E:\Android\Avd.

## Elkészült mobilváltozások

A kezdőképernyő a felhasználó TRIO-grafikáját használja. A külön BELÉPÉS és KILÉPÉS képgomb a helyi hitelesítési állapot szerint vált; mérete megnőtt. A Játék indítása helyi játékhoz nem kér bejelentkezést, szerveres mód Google-hitelesítést kér. A külön vendéggomb megszűnt.

A token és játékosadatok alkalmazás-újraindítás után helyben megmaradnak. Kijelentkezés törli a helyi tokent, játékosazonosítót és érmeegyenleget. Ez helyi kijelentkezés, nem szerveroldali tokenvisszavonás.

Az avatarok mellett a megszerzett triók számát külön 0–3 grafikák mutatják; a pakli nagyobb és kijjebb helyezett. A Játékszabály gomb tematikus modalt nyit saját kártyákkal. A véletlen keresés külön matchmaking lekérdezést használ 3 másodpercenként; a még hiányzó szoba nem okoz null-hivatkozási hibát.

## Szerverhiba és javítások

Az 500-as hiba vizsgálata során először csak régi Google JWT hiba látszott. A megfelelő Apache napló /var/log/apache2/trio-cardgame-error.log, a kérések naplója trio-cardgame-access.log. A VirtualHost helyesen a public könyvtárra mutatott.

A view szolgáltatás hibájára explicit ViewServiceProvider és config/view.php került be (f030af0). A Route [login] not defined hiba javítása API-vendégkérésnél megszünteti a webes login átirányítást (5462066). A storage és bootstrap/cache jogosultságait úgy kellett rendezni, hogy hilbi1 és www-data is írhasson: tulajdonos hilbi1:www-data, ug+rwX, könyvtárakon setgid. A kizárólag www-data tulajdonosra állítás a hilbi1 által futtatott Composer számára hibát okozott.

A szerver 2026-11-19 19:50:49 UTC-kor a token nélküli profiltesztre 401 Unauthorized választ adott. Ez az adott végpont hitelesítés nélküli viselkedését igazolja, nem a Google-belépés és teljes online játék sikerét.

Az online köridő 120 másodperc lett, 90 mp alapidővel és 30 mp figyelmeztetéssel (83ada40). A botátvétel után az egyetlen megmaradó ember győzhet, ezért WINNER önmagában nem bizonyít alkalmazás-összeomlást.

Az azonnali WINNER konkrét kódhibája: a JoinMatchmakingAction állapotellenőrzés nélkül visszaadta a játékos korábbi szobáját. A 3edead8 javítás csak várakozó vagy aktív, győztes nélküli szobát és ember által kezelt helyet enged újra használni. Lezárt játék résztvevőit nem törli. A felhasználó sikeres git pull kimenettel igazolta e javítás éles szerverre letöltését. Az új párosítás végponttól végpontig tartó próbája még nincs igazolva.

## Tesztek és korlátok

Korábbi mobilmenetekben 3/3 Flutter teszt és release APK build sikeres. A mentett APK a legutóbbi helyi release build, nem új Play Store kiadás. A legutóbbi szerverjavítás nem igényelt új APK-t. Ebben a mentési menetben új build vagy játékteszt nem futott.

A helyi Laravel teszt PHP-verzió miatt blokkolt: a parancssori PHP 8.2.12, a projekt >=8.3 verziót kér. A szerveren php artisan test futtatandó. A mostani matchmaking javítás regressziós teszttel és három külön játékossal még ellenőrizendő. Azonos Google-fiók több emulátoron ugyanazt a szerveres játékost jelenti, nem három külön játékost.

## Következő konkrét ellenőrzés

1. Három külön Google-fiókkal belépni, azonos játékosszámot választani és véletlen keresést indítani.
2. Ellenőrizni, hogy friss szoba indul, nincs korábbi WINNER és mindhárom kliens azonos állapotot lát.
3. Egy játékost időtúllépésig váratni: csak a megfelelő játékoshelyet vegye át bot; új keresés ne adja vissza ezt a helyet.
4. Befejezés után új keresést indítani; ne a lezárt szoba térjen vissza.
5. Éles hibánál a friss Laravel logot olvasni; naplót ne töröljünk újabb bizonyíték nélkül.

## Visszaállítás másik gépen

A forrás ZIP kicsomagolása után PHP >=8.3 és Composer, Flutter és Android SDK szükséges. A Laravel gyökérszerkezet maradjon meg. Függőségek: composer install, mobile könyvtárban flutter pub get. A titkok és aláírókulcsok külön, biztonságos másolásból állítandók vissza. Éles adatbázis-visszaállítást ez a csomag nem biztosít. APK telepítéshez C:\Android\Sdk\platform-tools\adb.exe használható.
