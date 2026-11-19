# TRIO mobil kliens

Flutter Android alkalmazás a TRIO kártyajátékhoz.

## Fejlesztői indítás

```powershell
flutter pub get
flutter test
flutter run
```

Az API alapértelmezett címe a `lib/trio_api.dart` fájlban található.

## Android aláírás

A Play-kiadáshoz szükséges fájlok nincsenek a Git-repóban:

- `android/key.properties`
- a hivatkozott `.jks` upload kulcs

Ezek nélkül debug build készíthető. Play-re feltöltés előtt a build
számát növelni kell a `pubspec.yaml` fájlban.
