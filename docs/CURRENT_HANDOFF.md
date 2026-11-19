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
