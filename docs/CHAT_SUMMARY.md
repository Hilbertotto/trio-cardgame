# TRIO fejlesztési beszélgetés összesítő

Utolsó frissítés: 2026-11-25

## 2026. november 24–25. · Windows és trióanimáció

- A GitHub-forrás a C:\dev\trio-cardgame mappába került. Helyi Laravel SQLite-adatbázissal indult, az /up végpont HTTP 200-at adott. A tesztfutásban 21/24 Laravel-teszt ment át.
- Az USB-n csatlakozó készülék hiányában két Android-emulátor készült. A Windows Hypervisor Platform az újraindítás után működött. A TRIO_Pixel_10_Pro hivatalos Pixel 10 Pro profillal, Android 16-tal és 1280 × 2856 felbontással fut.
- A megszerzett trió három lapja egyenként ívben ugrik a megszerző játékos avatarja melletti paklira. A számláló a harmadik lap után frissül. Flutter widgettesztek 4/4. A debug APK sikeresen elindult a Pixel 10 Pro emulátoron.
- A helyi és online trió kézi látványellenőrzése még hátravan. A beszélgetés üzeneteit és végső válaszait a [2026-11-25-i átirat](CHAT_TRANSCRIPT_2026-11-25.md) tartalmazza.

## Korábbi összefoglaló · 2026-11-19

## Projekt és környezet

- Repository: https://github.com/Hilbertotto/trio-cardgame
- Laravel API: https://trio.solarisminer.com/api/v1
- Éles szerver: `solarisminer.com`, SSH port `8022`, felhasználó `hilbi1`
- Mobil kliens: `mobile/`, package ID: `hu.triogame.trio_android`
- Teszt APK: `G:\Saját meghajtó\apllikacio\trio-cardgame-test.apk`
- Projektmemória Drive-mappája: `G:\Saját meghajtó\applikacio\trio\context`

## Elkészült funkciók

- Laravel szerverre átállított, szerveroldali játékállapot és matchmaking.
- Google- és vendég-hitelesítés, Sanctum tokenek, profil és ponttörténet.
- Gép átvétele inaktivitás után a szerveres játékban.
- Virtuális érmék: 3/4/5/6 játékosnál a győztes 100/120/140/160 érmét kap.
- Gép elleni játék bejelentkezett felhasználónál is pontozható az offline eredmény API-n keresztül.
- A belépési token helyben megmarad, ezért az app újraindításakor nem kell újra belépni.
- TRIO-számláló kártya az avatar mellett; a kártyán látszik az adott játékos által szerzett triók száma.
- A mobil teszt APK elkészült, tesztek: 3/3 sikeres, debug build sikeres.

## Fontos commitok

- `d0b39a4` – szerveroldali érmejutalmazás
- `c970c29` – gép elleni eredmény hitelesített rögzítése
- `9001925` – Google OAuth kliens-konfiguráció javítási kísérlete
- `3ea64ca` – TRIO-számláló kártya
- `3377353` – eredeti Google Web Client ID visszaállítása
- `9c80784` – számláló kártya elhelyezése az avatar bal oldalán

## Jelenlegi blokkoló

A Google-belépés az emulátoron és telefonon a Google-fiók kiválasztása után `canceled` hibával leáll. A hálózat már működik. A szerver és az app az eredeti Web Client ID-t használja, de a Google Cloud Console-ban Android OAuth kliens szükséges:

- Package: `hu.triogame.trio_android`
- Debug SHA-1: `F5:49:6F:10:49:96:AC:EA:AF:0D:52:83:1B:98:72:EE:D4:F1:70:34`
- Release SHA-1: `EA:EC:EB:F0:C7:88:3D:51:49:18:5C:E2:43:DB:34:EB:85:AD:16:25`

Google Cloud Console: APIs & Services → Credentials → Create credentials → OAuth client ID → Android.

## Legutóbbi ellenőrzések

- SolarisMiner szerver commitja és GitHub `main` egyezik.
- `POST /api/v1/offline-results` route aktív.
- Flutter widget tesztek 3/3 sikeres.
- Android debug APK build sikeres és az emulátorra telepítve.
- A Chrome-ban megnyitva az OAuth kliens létrehozási oldal; a mezőket kézzel kell kitölteni, ha a böngészővezérlés nem érhető el.

## Következő konkrét lépés

1. Hozd létre az Android OAuth klienst a fenti package ID-val és SHA-1-ekkel.
2. Telepítsd újra a friss APK-t telefonra és emulátorra.
3. Ellenőrizd a Google-belépést, majd egy gép elleni győzelemmel a pontjóváírást.
