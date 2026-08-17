object frmSettings: TfrmSettings
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Settings'
  ClientHeight = 214
  ClientWidth = 420
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  TextHeight = 15
  object lblToggleHotkey: TLabel
    Left = 24
    Top = 24
    Width = 121
    Height = 15
    Caption = 'Toggle keyboard hotkey'
  end
  object lblActionHotkey: TLabel
    Left = 24
    Top = 80
    Width = 114
    Height = 15
    Caption = 'Action hotkey (optional)'
  end
  object lblTargetProcess: TLabel
    Left = 24
    Top = 136
    Width = 143
    Height = 15
    Caption = 'Primary app process name'
  end
  object lblAllowedApps: TLabel
    Left = 24
    Top = 192
    Width = 143
    Height = 15
    Caption = 'Allowed apps/processes (empty disables interception)'
  end
  object memAllowedApps: TMemo
    Left = 24
    Top = 213
    Width = 372
    Height = 68
    ScrollBars = ssVertical
    TabOrder = 3
  end
  object lblHotkeyHelp: TLabel
    Left = 24
    Top = 291
    Width = 372
    Height = 45
    AutoSize = False
    Caption = 
      'Click a field, then press the shortcut you want to use. Press Backspace ' +
      'or Delete to clear the optional action hotkey. Leaving allowed apps empty ' +
      'disables interception except for the primary target process.'
    WordWrap = True
  end
  object edtToggleHotkey: TEdit
    Left = 24
    Top = 45
    Width = 372
    Height = 23
    ReadOnly = True
    TabOrder = 0
    OnKeyDown = edtToggleHotkeyKeyDown
  end
  object edtActionHotkey: TEdit
    Left = 24
    Top = 101
    Width = 372
    Height = 23
    ReadOnly = True
    TabOrder = 1
    OnKeyDown = edtActionHotkeyKeyDown
  end
  object edtTargetProcess: TEdit
    Left = 24
    Top = 157
    Width = 372
    Height = 23
    TabOrder = 2
  end
  object btnOK: TButton
    Left = 236
    Top = 336
    Width = 75
    Height = 25
    Caption = 'OK'
    Default = True
    TabOrder = 4
    OnClick = btnOKClick
  end
  object btnCancel: TButton
    Left = 321
    Top = 336
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 5
  end
end
