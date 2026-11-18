object frmSettings: TfrmSettings
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Settings'
  ClientHeight = 537
  ClientWidth = 460
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  Constraints.MinHeight = 537
  Constraints.MinWidth = 460
  TextHeight = 15
  object lblToggleHotkey: TLabel
    Left = 20
    Top = 20
    Width = 121
    Height = 15
    Caption = 'Toggle keyboard hotkey'
  end
  object lblActionHotkey: TLabel
    Left = 20
    Top = 80
    Width = 114
    Height = 15
    Caption = 'Action hotkey (optional)'
  end
  object lblTargetProcess: TLabel
    Left = 20
    Top = 140
    Width = 143
    Height = 15
    Caption = 'Primary app process name'
  end
  object lblAllowedApps: TLabel
    Left = 20
    Top = 200
    Width = 129
    Height = 15
    Caption = 'Allowed apps and processes'
  end
  object edtToggleHotkey: TEdit
    Left = 20
    Top = 41
    Width = 420
    Height = 23
    Hint = 'Click here, then press the shortcut you want to use'
    ParentShowHint = False
    ReadOnly = True
    ShowHint = True
    TabOrder = 0
    OnKeyDown = edtToggleHotkeyKeyDown
  end
  object edtActionHotkey: TEdit
    Left = 20
    Top = 101
    Width = 420
    Height = 23
    Hint = 'Click here, then press the shortcut you want to use'
    ParentShowHint = False
    ReadOnly = True
    ShowHint = True
    TabOrder = 1
    OnKeyDown = edtActionHotkeyKeyDown
  end
  object edtTargetProcess: TEdit
    Left = 20
    Top = 161
    Width = 420
    Height = 23
    Hint = 'Process name of the app that should always receive interception'
    ParentShowHint = False
    ShowHint = True
    TabOrder = 2
  end
  object memAllowedApps: TMemo
    Left = 20
    Top = 221
    Width = 420
    Height = 76
    Hint = 'One process name per line'
    ParentShowHint = False
    ScrollBars = ssBoth
    ShowHint = True
    TabOrder = 3
    WordWrap = False
  end
  object lblLayoutsFolder: TLabel
    Left = 20
    Top = 303
    Width = 78
    Height = 15
    Caption = 'Layouts folder'
  end
  object edtLayoutsPath: TEdit
    Left = 20
    Top = 324
    Width = 320
    Height = 23
    Hint = 'Folder the keyboard loads layouts from; a missing folder falls back to the per-user copy'
    ParentShowHint = False
    ShowHint = True
    TabOrder = 4
  end
  object btnBrowseLayouts: TButton
    Left = 345
    Top = 324
    Width = 95
    Height = 23
    Caption = 'Browse...'
    TabOrder = 5
    OnClick = btnBrowseLayoutsClick
  end
  object lblCycleHotkey: TLabel
    Left = 20
    Top = 357
    Width = 124
    Height = 15
    Caption = 'Cycle layout hotkey (optional)'
  end
  object edtCycleHotkey: TEdit
    Left = 20
    Top = 378
    Width = 420
    Height = 23
    Hint = 'Click here, then press the shortcut you want to use'
    ParentShowHint = False
    ReadOnly = True
    ShowHint = True
    TabOrder = 6
    OnKeyDown = edtCycleHotkeyKeyDown
  end
  object chkIgnoreInjectedInput: TCheckBox
    Left = 20
    Top = 409
    Width = 420
    Height = 24
    Hint = 'Uncheck only if you type through remote desktop or macro tools whose keystrokes must drive the mapping'
    Caption = 'Ignore injected keystrokes (recommended)'
    ParentShowHint = False
    ShowHint = True
    TabOrder = 7
  end
  object lblHotkeyHelp: TLabel
    Left = 20
    Top = 440
    Width = 420
    Height = 60
    AutoSize = False
    Caption = 'Click a hotkey field, then press the shortcut you want to use. Backspace or Delete clears the optional action hotkey. Allowed apps take one process name per line; an empty list disables interception except for the primary app process above.'
    WordWrap = True
  end
  object btnOK: TButton
    Left = 284
    Top = 506
    Width = 75
    Height = 25
    Caption = 'OK'
    Default = True
    TabOrder = 8
    OnClick = btnOKClick
  end
  object btnCancel: TButton
    Left = 365
    Top = 506
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 9
  end
end
