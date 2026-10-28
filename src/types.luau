--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Public API types. camelCase is the documented surface; PascalCase keys still work.

export type Theme = string | { [string]: any }

-- Optional dev hook: given a source string (the English copy, which doubles as its key) and the
-- active locale id, return the translation, or nil/"" to fall through to the built-in tables.
export type Translator = (source: string, localeId: string) -> string?

-- Translation tables keyed by locale id, each mapping a source string to its translation, e.g.
-- { fr = { ["Close"] = "Fermer" }, ["pt-br"] = { ["Close"] = "Fechar" } }.
export type Translations = { [string]: { [string]: string } }

export type WindowConfiguration = {
    autoSave: boolean?,
    autoLoad: boolean?,
    fileName: string?,
    customFolder: string?,
}

export type WindowProps = {
    name: string?,
    subtitle: string?,
    theme: Theme?,
    icon: (string | number)?,
    showName: string?,
    showIcon: (string | number)?,
    showIconOnly: boolean?, -- collapse to a round icon badge instead of an icon-and-label pill
    sidebarLayout: boolean?, -- tabs down the left instead of across the top
    profile: string?, -- the line under the player's name in the sidebar; empty leaves the name alone
    configuration: WindowConfiguration?,
    fallbackFont: (Font | Enum.Font)?, -- built-in stand-in shown in secure mode while the brand font downloads
    locale: string?, -- pin the UI language; defaults to the player's Roblox locale
    translations: Translations?, -- language tables keyed by locale id; the easy, table-first path
    translator: Translator?, -- resolve copy yourself; falls back to the built-in tables
    heartbeat: string?, -- a Sentivel ping URL or token, pinged while the window is up
}

export type TabProps = {
    name: string?,
    icon: (string | number)?,
}

export type TagProps = {
    text: string?,
    title: string?,
    icon: (string | number)?,
    color: Color3?,
    order: number?,
}

export type SectionProps = {
    name: string?,
    icon: (string | number)?,
}

export type TextProps = {
    name: string?, -- the title above the body; either half can be left out
    text: string?, -- the body
    icon: (string | number)?,
}

export type DividerProps = {
    text: string?, -- an optional word in the middle of the rule
    spacing: number?, -- room above and below, in pixels
    line: boolean?, -- false draws no rule, leaving only the room
}

export type GroupProps = {
    direction: string?, -- "row" | "column" (default row); "horizontal"/"vertical" also work
}

export type ButtonProps = {
    name: string?,
    description: string?,
    icon: (string | number)?,
    callback: (() -> ())?,
}

export type ToggleProps = {
    name: string?,
    description: string?,
    icon: (string | number)?,
    flag: string?,
    value: boolean?,
    forgetState: boolean?,
    callback: ((value: boolean) -> ())?,
}

export type SliderProps = {
    name: string?,
    description: string?,
    icon: (string | number)?,
    flag: string?,
    range: { number }?, -- { min, max }
    increment: number?,
    value: number?,
    suffix: string?,
    minimal: boolean?, -- track only, no name/value (for dense rows)
    forgetState: boolean?,
    -- dragging is true from the moment the handle is grabbed until it's let go
    callback: ((value: number, dragging: boolean) -> ())?,
}

export type DropdownProps = {
    name: string?,
    description: string?,
    icon: (string | number)?,
    flag: string?,
    options: { string }?,
    value: (string | { string })?,
    multiSelect: boolean?,
    placeholder: string?,
    forgetState: boolean?,
    callback: ((value: any) -> ())?,
}

export type InputProps = {
    name: string?,
    description: string?,
    icon: (string | number)?,
    flag: string?,
    value: string?,
    placeholder: string?,
    numeric: boolean?,
    clearOnFocus: boolean?,
    forgetState: boolean?,
    callback: ((value: string) -> ())?,
}

export type KeybindProps = {
    name: string?,
    description: string?,
    icon: (string | number)?,
    flag: string?,
    value: (EnumItem | string)?, -- an Enum.KeyCode / mouse button, or a KeyCode name
    forgetState: boolean?,
    isMenuToggle: boolean?, -- internal: the settings menu-toggle keybind, clash check runs in reverse
    hold: boolean?, -- fire callback(true) once held, callback(false) on release
    holdThreshold: number?, -- seconds to hold before it counts (default 0.2)
    callback: ((value: EnumItem | boolean) -> ())?, -- bound key on press, or true/false in hold mode
    onChanged: ((key: EnumItem) -> ())?, -- fires when the binding is changed
}

export type ColorPickerProps = {
    name: string?,
    description: string?,
    icon: (string | number)?,
    flag: string?,
    color: Color3?, -- initial colour (accepts a hex string too)
    alpha: number?, -- initial alpha 0..1 (default 1)
    forgetState: boolean?,
    callback: ((value: Color3, alpha: number) -> ())?,
}

export type StatProps = {
    name: string?,
    description: string?,
    icon: (string | number)?,
    prefix: string?,
    suffix: string?,
    value: number?,
    display: string?, -- "value" | "change"
    compact: boolean?,
    changeMode: string?, -- "percentage" | "absolute"
    changeBaseline: string?, -- "previous" | "initial"
    numberEasing: boolean?,
}

export type ProgressProps = {
    name: string?,
    description: string?,
    icon: (string | number)?,
    range: { number }?, -- { min, max }, defaulting to { 0, 1 } (or { 0, steps })
    value: number?,
    steps: number?, -- draw the track as this many segments instead of one continuous fill
    text: string?, -- a fixed readout beside the title
    format: ((value: number, min: number, max: number) -> string)?, -- build the readout yourself
    showValue: boolean?, -- false hides the readout entirely (default true)
    indeterminate: boolean?, -- a sweep instead of a value, for work of unknown length
}

export type ConsoleProps = {
    name: string?,
    description: string?,
    text: string?, -- the body
    height: number?, -- how tall the block stands, in pixels (default 120)
    follow: boolean?, -- jump to the newest line on Append, the way a console does
    maxLines: number?, -- how many lines to keep; past this the oldest roll off (default 200)
}

export type NotifyProps = {
    title: string?,
    content: string?,
    icon: (string | number)?,
    duration: number?,
}

export type ToastProps = {
    title: string?,
    subtitle: string?, -- optional second line
    subtitleAbove: boolean?, -- render the subtitle above the title (label-over-value)
    icon: (string | number)?, -- optional; asset id or ready image string (rbxthumb works)
    avatar: number?, -- optional user id; shows that user's headshot as a larger avatar
    minWidth: number?, -- floor the pill width; slack becomes right-hand room (content is left-aligned)
    duration: number?,
    position: "Top" | "Bottom"?,
}

export type PopupBox = {
    title: string?,
    description: string?,
    icon: (string | number)?,
}

export type PopupOption = {
    text: string?,
    style: string?, -- "neutral" (default) | "primary" | "danger"
    callback: (() -> ())?,
}

export type PopupProps = {
    title: string?,
    subtitle: string?,
    icon: (string | number)?,
    content: string?, -- a body paragraph
    boxes: { PopupBox }?, -- a list of cards (the changelog layout)
    options: { PopupOption }?, -- footer buttons; defaults to a single dismiss button
    dismissable: boolean?, -- click the dim or press Escape to close (default true)
}

-- Handles ------------------------------------------------------------------
-- Every element can be reordered within its tab.
export type Moveable = {
    MoveTo: (self: any, index: number) -> (),
    MoveToTop: (self: any) -> (),
    MoveToBottom: (self: any) -> (),
    MoveUp: (self: any) -> (),
    MoveDown: (self: any) -> (),
}

-- Every element you can operate takes a lock: it dims, stops taking input, and its callback
-- wont fire. Display-only elements dont have one.
export type Lockable = {
    Lock: (self: any, reason: string?) -> (),
    Unlock: (self: any) -> (),
    IsLocked: (self: any) -> boolean,
}

export type Button = Moveable & Lockable & {}

export type Toggle = Moveable & Lockable & {
    value: boolean,
    Set: (self: Toggle, value: boolean, skipCallback: boolean?) -> (),
}

export type Slider = Moveable & Lockable & {
    value: number,
    Set: (self: Slider, value: number, skipCallback: boolean?) -> (),
}

export type Dropdown = Moveable & Lockable & {
    value: { string }, -- always stored pruned to the current options, even single-select
    Set: (self: Dropdown, value: string | { string }, skipCallback: boolean?) -> (),
    Refresh: (self: Dropdown, options: { string }) -> (),
    Add: (self: Dropdown, option: string) -> (),
    Remove: (self: Dropdown, option: string) -> (),
}

export type Input = Moveable & Lockable & {
    value: string,
    Set: (self: Input, value: string, skipCallback: boolean?) -> (),
}

export type Keybind = Moveable & Lockable & {
    value: EnumItem,
    Set: (self: Keybind, value: EnumItem | string, skipChanged: boolean?) -> (),
}

export type ColorPicker = Moveable & Lockable & {
    value: Color3,
    alpha: number,
    Set: (self: ColorPicker, value: Color3 | string, skipCallback: boolean?) -> (),
    SetAlpha: (self: ColorPicker, alpha: number, skipCallback: boolean?) -> (),
}

export type Stat = Moveable & {
    value: number,
    Set: (self: Stat, value: number) -> (),
    ResetBaseline: (self: Stat, value: number?) -> (),
}

export type Progress = Moveable & {
    value: number,
    Set: (self: Progress, value: number) -> (),
    Get: (self: Progress) -> number,
    GetPercentage: (self: Progress) -> number, -- where the value sits in its range, 0 to 1
    SetRange: (self: Progress, min: number, max: number) -> (),
    SetText: (self: Progress, text: string?) -> (), -- nothing goes back to the formatter
    SetIndeterminate: (self: Progress, state: boolean) -> (),
    Remove: (self: Progress) -> (),
}

export type Console = Moveable & {
    Set: (self: Console, text: string) -> (),
    Append: (self: Console, line: string) -> (), -- multi-line splits, so the cap still counts
    Clear: (self: Console) -> (),
    Get: (self: Console) -> string,
    Copy: (self: Console) -> boolean, -- false where the executor has no setclipboard
    SetHeight: (self: Console, height: number) -> (),
    Remove: (self: Console) -> (),
}

export type Section = Moveable & {}

-- A heading in the sidebar rail rather than in a tab's element list. Not Moveable: the rail
-- orders itself by the order tabs and sections are created, the way tabs themselves do.
export type TabSection = {
    Remove: (self: TabSection) -> (),
}

export type Text = Moveable & {
    name: string, -- the title
    text: string, -- the body
    Set: (self: Text, text: string) -> (),
    SetTitle: (self: Text, title: string) -> (),
}

export type Divider = Moveable & {
    text: string, -- "" when the rule carries no word
    Set: (self: Divider, text: string?) -> (),
}

-- Tags sit in the window's title bar and order themselves, so they aren't Moveable.
export type Tag = {
    Set: (self: Tag, props: TagProps) -> (),
    SetColor: (self: Tag, color: Color3) -> (),
    SetText: (self: Tag, text: string?) -> (),
    SetIcon: (self: Tag, icon: (string | number)?) -> (),
    Remove: (self: Tag) -> (),
}

export type Popup = {
    Close: (self: Popup) -> (),
}

-- A group lays elements along one axis and nests, so a row of columns builds a grid.
-- A row accepts the compact elements (button/toggle/stat) + slider; a column also takes
-- dropdown, section, text and divider. Input, keybind and colorpicker stay tab-level for now.
export type Group = Moveable & {
    CreateButton: (self: Group, props: ButtonProps) -> Button,
    CreateToggle: (self: Group, props: ToggleProps) -> Toggle,
    CreateSwitch: (self: Group, props: ToggleProps) -> Toggle,
    CreateStat: (self: Group, props: StatProps) -> Stat,
    CreateSlider: (self: Group, props: SliderProps) -> Slider,
    -- nil on a row: only columns take these
    CreateDropdown: (self: Group, props: DropdownProps) -> Dropdown?,
    CreateSection: (self: Group, props: SectionProps) -> Section?,
    CreateText: (self: Group, props: TextProps) -> Text?,
    CreateDivider: (self: Group, props: DividerProps?) -> Divider?,
    CreateGroup: (self: Group, props: GroupProps?) -> Group,
}

export type Tab = {
    Select: (self: Tab, noAnimation: boolean?) -> (),
    Deselect: (self: Tab, noAnimation: boolean?) -> (),
    Remove: (self: Tab) -> (),
    CreateButton: (self: Tab, props: ButtonProps) -> Button,
    CreateToggle: (self: Tab, props: ToggleProps) -> Toggle,
    CreateSwitch: (self: Tab, props: ToggleProps) -> Toggle,
    CreateSlider: (self: Tab, props: SliderProps) -> Slider,
    CreateDropdown: (self: Tab, props: DropdownProps) -> Dropdown,
    CreateInput: (self: Tab, props: InputProps) -> Input,
    CreateKeybind: (self: Tab, props: KeybindProps) -> Keybind,
    CreateColorPicker: (self: Tab, props: ColorPickerProps) -> ColorPicker,
    CreateStat: (self: Tab, props: StatProps) -> Stat,
    CreateProgress: (self: Tab, props: ProgressProps) -> Progress,
    CreateConsole: (self: Tab, props: ConsoleProps) -> Console,
    CreateSection: (self: Tab, props: SectionProps) -> Section,
    CreateText: (self: Tab, props: TextProps) -> Text,
    CreateDivider: (self: Tab, props: DividerProps?) -> Divider,
    CreateGroup: (self: Tab, props: GroupProps?) -> Group,
}

export type Window = {
    unloaded: boolean, -- true once Unload has run; the handle is spent
    -- always-live view of every saved control, keyed by flag; reads give the current value,
    -- writes route through the control's Set
    Flags: { [string]: any },
    CreateTab: (self: Window, props: TabProps) -> Tab,
    -- sidebar layout only; does nothing under the top strip
    CreateSection: (self: Window, props: SectionProps) -> TabSection,
    CreateTag: (self: Window, props: TagProps) -> Tag,
    Notify: (self: Window, props: NotifyProps) -> (),
    Toast: (self: Window, props: ToastProps) -> (),
    Popup: (self: Window, props: PopupProps) -> Popup?, -- nil once the window is unloaded
    Show: (self: Window) -> (),
    Hide: (self: Window) -> (),
    ToggleHide: (self: Window) -> (),
    ToggleMinimise: (self: Window) -> (),
    Navigate: (self: Window, tab: string | Tab) -> (),
    ChangeTheme: (self: Window, theme: Theme) -> (),
    SetLocale: (self: Window, localeId: string) -> (),
    SetTranslator: (self: Window, translator: Translator?) -> (),
    RegisterTranslations: (self: Window, translations: Translations) -> (),
    Save: (self: Window, name: string?) -> boolean,
    Load: (self: Window, name: string?) -> boolean,
    ListConfigs: (self: Window) -> { string },
    DeleteConfig: (self: Window, name: string) -> boolean,
    GetPath: (self: Window) -> (string, string),
    Get: (self: Window, flag: string) -> any,
    Set: (self: Window, flag: string, value: any) -> boolean,
    Unload: (self: Window) -> (),
}

export type Rayfield = {
    CreateWindow: (self: Rayfield, props: WindowProps) -> Window,
}

return {}
