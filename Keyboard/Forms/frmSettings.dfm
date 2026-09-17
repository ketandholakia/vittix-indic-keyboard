object frmSettings: TfrmSettings
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Settings'
  ClientHeight = 420
  ClientWidth = 460
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  Constraints.MinHeight = 420
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
  object lblHotkeyHelp: TLabel
    Left = 20
    Top = 305
    Width = 420
    Height = 60
    AutoSize = False
    Caption = 'Click a hotkey field, then press the shortcut you want to use. Backspace or Delete clears the optional action hotkey. Allowed apps take one process name per line; an empty list disables interception except for the primary app process above.'
    WordWrap = True
  end
  object btnOK: TButton
    Left = 284
    Top = 375
    Width = 75
    Height = 25
    Caption = 'OK'
    Default = True
    TabOrder = 4
    OnClick = btnOKClick
  end
  object btnCancel: TButton
    Left = 365
    Top = 375
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 5
  end
end
