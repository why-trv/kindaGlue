# kindaGlue

**kindaGlue** is an experimental background macOS app that acts a bit like a glue layer between [kindaVim](https://github.com/godbout/kindaVim.blahblah), [Karabiner-Elements](https://github.com/pqrs-org/Karabiner-Elements) and a bit of [Homerow](https://github.com/nchudleigh/homerow). I hacked this together for my own use, but it seemed a bit too cool not to share.

## Why?

- kindaVim lets you move through tables and lists using `j`, `k`, `gg`, `G`, and even delete items with `dd` or `x`, or undo with `u`, which is absolutely amazing. However, for any app-specific actions — like replying to a selected email or pinning a selected note — you still have to use the shortcuts, such as `⌘R`. In the case of pinning a note, the Notes app doesn't even have a shortcut. Wouldn't it be nice if you could just press `r` to reply, `U` to mark as unread, or `p`/`P` to pin, and so on?

- Some apps let you use `Tab`/`Shift-Tab`, or `←`/`→`, or some other keys to move between UI elements or sections, but it can take too many steps to get where you want. Sure, you can also use Homerow or Wooshy to jump to your target, but what if you could, for instance, press `gf` to focus the list of folders, `gl` to go to the list of notes, `o` to start scrolling a long email, or maybe `'a` to go directly to a particular folder or item you need most often?

- In many apps, you end up navigating quite a bit before you actually need to type something (if at all), yet you still have to perform modifier-key gymnastics to carry out the most common actions. Does it really have to be this way?

## Demo

I'd love to do a demo, but I don't see a way to screen-cast key presses **before** they are modified by Karabiner-Elements. If you have an idea on how this can be done, please let me know.

## What It Does

- Observes windows and UI elements using accessibility (*AX*) APIs and sets variables for Karabiner-Elements to use, such as:
   - The frontmost application. (Although Karabiner-Elements has `frontmost_application_if` and `frontmost_application_unless` conditions, they don't work if the app is an overlay like Alfred or Spotlight.)
   - The AX role and subrole of the currently focused element.
   - The AX identifier of the current window.
   - ...and more.
- Displays a color overlay over the menubar to indicate the current mode. (This includes both kindaVim modes and kindaGlue 'meta' modes.)
- Remembers and restores the mode that an app was in when switching between apps.
- Observes the Homerow overlay window to aid seamless return to normal mode when it's dismissed.
- Provides a CLI utility to focus, select, or press UI elements and menu items (to be used from KE).

## Configuration

### kindaGlue
For now, if you want to change the config like the normal mode shortcut to use for kindaVim, or the colors of the menubar overlay, you'll have to modify the source and build it yourself, sorry. (Look into `kindaGlue/Config.swift`)

By default, the normal mode shortcut is `Ctrl-[`.

### kindaVim
Karabiner-Elements integration must be enabled in kindaVim settings.

### Karabiner-Elements
The actual key mappings are to be handled by Karabiner-Elements. Look into [this repo](https://github.com/why-trv/kindaGlue-karabiner.ts-config) for an example config.

## Usage

1. Grant kindaGlue accessibility permissions by adding it in *System Settings > Privacy & Security > Accessibility*.
2. Run the app.
3. Use the **Variables** tab in **Karabiner-EventViewer** to verify that the `kG.*` variables are properly updated when switching between and clicking around apps.
4. Tweak your Karabiner-Elements configuration to your heart's content and (hopefully) enjoy the ride!