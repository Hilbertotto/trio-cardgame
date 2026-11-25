# TRIO projektmemória

Utolsó frissítés: 2026-11-25

## Cél

Magyar nyelvű, mexikói népművészeti megjelenésű TRIO kártyajáték Androidra.
Működjön helyi gépi ellenfelekkel és internetes többjátékos módban.

## Technológia és környezet

- Mobil: Flutter/Dart, Android, álló nézet
- Android package ID: `hu.triogame.trio_android`
- Mobil verzió a dokumentum készítésekor: `1.0.2+3`
- Backend: Laravel API, Sanctum tokenek, MySQL a SolarisMiner éles környezetében
- Éles API: `https://trio.solarisminer.com/api/v1`
- Forrás: `https://github.com/Hilbertotto/trio-cardgame`
- Szerver: saját Ubuntu gép, belső IP `192.168.0.214`, külső SSH `solarisminer.com:8022`

## Játékszabályok

- A lapok értéke 1–12, minden értékből három példány van.
- A játékos egy körben három azonos értékű lapot próbál felfedni.
- A saját vagy más játékos kezéből csak az aktuálisan elérhető legalacsonyabb (`Lo`) vagy legmagasabb (`Hi`) lap kérhető.
- A 7-es trió azonnali győzelem.
- Egyébként három megszerzett trió nyeri meg a játékot.
- Ha a szerveres játékban már csak egy ember marad és minden más helyet bot vett át, az aktív ember a győztes.

## Helyi gépi nehézségek

- Soft: véletlenszerű, nem őriz emléket a felfedett lapokról.
- Medium: okosabban párosít, de egy ismert lapot legfeljebb két teljes játékoskörig tart meg.
- Hard: a játék végéig emlékszik a nyilvánosan felfordított lapokra.
- Egyik nehézség sem ismerheti a kezdetben lefordított asztali lapokat vagy a játékosok rejtett kezét.

## Mobil kliens jelenlegi állapota

- 3–6 játékos választható.
- Gépi és szerveres módválasztás; szerverhez Google-bejelentkezés szükséges.
- Egyedi teljes képernyős türkiz játéktér, mexikói kártyák, avatarok, névtáblák, Lo/Hi gombok, győzelmi panel.
- A játékoselrendezés és a középső laprács a játékosszámtól függ.
- Lapválasztási hang, lapmozgatási animáció és soron lévő játékos jelölés van.
- A trió lapjai egymás után a triót megszerző játékos avatarja melletti paklira ugranak.
- Fő mobil forrás: `mobile/lib/main.dart`; API-kliens: `mobile/lib/trio_api.dart`.

## Szerver jelenlegi állapota

- Vendég- és Google-hitelesítés, profil és virtuális ponttörténet.
- Szobalétrehozás, szobakódos belépés és automatikus matchmaking.
- Új keresés nem használhat lezárt szobát vagy bot által átvett játékoshelyet.
- Szerver által kezelt játékállapot és lépések.
- Inaktivitás: 90 másodperc alapidő után 30 másodperces figyelmeztetés; összesen 120 másodperc után bot veszi át a helyet.
- A szerveres botlépések szándékosan lassítottak.
- Pontozás: befejezett játék 20 pont, győztes bónusz 100 pont.

## Fontos vizuális döntések

- Álló mobilnézet; a háttér minden kijelzőt sáv nélkül töltsön ki.
- A saját kártyák alul, enyhén fedve és ívesen jelennek meg.
- A középső lapok nem takarhatják a játékosokat; a kiválasztott lapok mérete egyezzen az asztali lapokéval.
- Kiválasztáskor a lap csússzon, de ne forogjon, és mozgás közben ne villanjon fel fehér keret.
- Bal felül vissza/főoldal, jobb felül beállítás gomb van.

## Titkok és gépenkénti fájlok

Ezek nincsenek Gitben, az új gépre külön kell átvinni:

- szerver `.env`
- `mobile/android/key.properties`
- Play upload `.jks` kulcs
- OAuth client-secret és szerveroldali titkok
- SSH privát kulcsok

A Play Store frissítésekhez mindig ugyanazt az upload kulcsot kell használni.

## Kiadás és munkafolyamat

- A Google Play alkalmazás létrejött, belső tesztelés megkezdődött.
- Új Play feltöltés előtt mindig növelni kell a `mobile/pubspec.yaml` build számát.
- Munka előtt `git pull --ff-only`; munka után teszt, kontextusfrissítés, commit és push.

## Ismert környezeti sajátosság

Windows alatt az ékezetet vagy szóközt tartalmazó projekt-/SDK-útvonal néhány Flutter AOT és Android Emulator műveletet megzavarhat. Ajánlott projektútvonal: `C:\dev\trio-cardgame`, Android SDK: `C:\AndroidSDK`.
