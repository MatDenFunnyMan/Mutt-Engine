# Translations

Translations work like in Psych Engine. A language is a `.lang` text file, plus translated images if you need them. The player picks the language in **Options > Language**.

## FILE DIRECTORY

```
my-mod/
  content/
    translations/
      it-IT/
        data/
          it-IT.lang
        images/
          ...translated images
```

The folder name and the file name are the language code, like `it-IT` or `pt-BR`. The old Psych place, `data/it-IT.lang`, still works.

## .lang files

The first line is the name shown in the language menu. Every other line is `key: "text"`. Lines starting with `//` are comments.

```
Italiano

// Main menu
my_mod_welcome: "Benvenuto!"
score_text: "Punti: {1} | Errori: {2} | Valutazione: {3}"
```

- `{1}`, `{2}`... are values the game puts in by itself.
- `\n` makes a new line.
- A mod can translate its own texts and also replace the engine's ones. The full list of engine keys is in `assets/translations/pt-BR/data/pt-BR.lang`.

## TRANSLATED IMAGES

To use another image for a language, add a line with the image path as the key:

```
images/mainmenu/menu_credits: "translations/it-IT/images/mainmenu/menu_credits"
```

Now the game loads the Italian image every time it asks for `images/mainmenu/menu_credits`.

## SCRIPTING

```lua
local text = getTranslationPhrase('my_mod_welcome', 'Welcome!')
```

The second value is used when the current language has no translation for that key.

| Function | Description |
|---|---|
| `getTranslationPhrase(key, ?default, ?values)` | Translated text. `values` fills `{1}`, `{2}`... |
| `setTranslationPhrase(key, text)` | Changes a translation while the game runs. |
| `getFileTranslation(path)` | Path of the translated file, or the same path if there is none. |
| `setFileTranslation(path, newPath)` | Changes a translated file while the game runs. |
