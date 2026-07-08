--!strict
-- Public API types. camelCase is the documented surface; PascalCase keys still work.

export type Theme = string | { [string]: any }

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
    configuration: WindowConfiguration?,
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

export type GroupProps = {
    direction: string?, -- "row" | "column" (default row); "horizontal"/"vertical" also work
}
export type StackProps = GroupProps -- legacy alias

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
    callback: ((value: number) -> ())?,
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
    callback: ((key: EnumItem) -> ())?, -- fires when the bound key is pressed
    onChanged: ((key: EnumItem) -> ())?, -- fires when the binding is changed
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
    changeBaseline: string?,
    numberEasing: boolean?,
    callback: ((value: number) -> ())?,
}

export type NotifyProps = {
    title: string?,
    content: string?,
    icon: (string | number)?,
    duration: number?,
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

export type Button = Moveable & {}

export type Toggle = Moveable & {
    value: boolean,
    Set: (self: Toggle, value: boolean, skipCallback: boolean?) -> (),
}

export type Slider = Moveable & {
    value: number,
    Set: (self: Slider, value: number, skipCallback: boolean?) -> (),
}

export type Dropdown = Moveable & {
    value: string | { string },
    Set: (self: Dropdown, value: string | { string }, skipCallback: boolean?) -> (),
}

export type Input = Moveable & {
    value: string,
    Set: (self: Input, value: string, skipCallback: boolean?) -> (),
}

export type Keybind = Moveable & {
    value: EnumItem,
    Set: (self: Keybind, value: EnumItem | string, skipChanged: boolean?) -> (),
}

export type Stat = Moveable & {
    value: number,
    Set: (self: Stat, value: number) -> (),
    ResetBaseline: (self: Stat) -> (),
}

export type Section = Moveable & {}

-- A group lays elements along one axis and nests, so a row of columns builds a grid.
-- A row accepts the compact elements + slider; a column accepts anything.
export type Group = Moveable & {
    CreateButton: (self: Group, props: ButtonProps) -> Button,
    CreateToggle: (self: Group, props: ToggleProps) -> Toggle,
    CreateSwitch: (self: Group, props: ToggleProps) -> Toggle,
    CreateStat: (self: Group, props: StatProps) -> Stat,
    CreateSlider: (self: Group, props: SliderProps) -> Slider,
    CreateDropdown: (self: Group, props: DropdownProps) -> Dropdown,
    CreateSection: (self: Group, props: SectionProps) -> Section,
    CreateGroup: (self: Group, props: GroupProps?) -> Group,
    CreateHStack: (self: Group, props: GroupProps?) -> Group,
    CreateVStack: (self: Group, props: GroupProps?) -> Group,
}
export type Stack = Group -- legacy alias

export type Tab = {
    CreateButton: (self: Tab, props: ButtonProps) -> Button,
    CreateToggle: (self: Tab, props: ToggleProps) -> Toggle,
    CreateSwitch: (self: Tab, props: ToggleProps) -> Toggle,
    CreateSlider: (self: Tab, props: SliderProps) -> Slider,
    CreateDropdown: (self: Tab, props: DropdownProps) -> Dropdown,
    CreateInput: (self: Tab, props: InputProps) -> Input,
    CreateKeybind: (self: Tab, props: KeybindProps) -> Keybind,
    CreateStat: (self: Tab, props: StatProps) -> Stat,
    CreateSection: (self: Tab, props: SectionProps) -> Section,
    CreateGroup: (self: Tab, props: GroupProps?) -> Group,
    CreateHStack: (self: Tab, props: GroupProps?) -> Group,
    CreateVStack: (self: Tab, props: GroupProps?) -> Group,
}

export type Window = {
    CreateTab: (self: Window, props: TabProps) -> Tab,
    CreateTag: (self: Window, props: TagProps) -> any,
    Notify: (self: Window, props: NotifyProps) -> (),
    Show: (self: Window) -> (),
    Hide: (self: Window) -> (),
    ToggleHide: (self: Window) -> (),
    ToggleMinimise: (self: Window) -> (),
    Navigate: (self: Window, tab: string | Tab) -> (),
    ChangeTheme: (self: Window, theme: Theme) -> (),
    Save: (self: Window) -> boolean,
    Load: (self: Window) -> boolean,
    Unload: (self: Window) -> (),
}

export type Rayfield = {
    CreateWindow: (self: Rayfield, props: WindowProps) -> Window,
}

return {}
