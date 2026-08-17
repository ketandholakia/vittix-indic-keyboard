object frmOnScreenKeyboard: TfrmOnScreenKeyboard
  Left = 0
  Top = 0
  BorderStyle = bsToolWindow
  Caption = 'Vittix Indic Keyboard - On Screen'
  ClientHeight = 260
  ClientWidth = 520
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poDesigned
  OnCreate = FormCreate
  TextHeight = 15
  object pnlHeader: TPanel
    Left = 0
    Top = 0
    Width = 520
    Height = 40
    Align = alTop
    BevelOuter = bvNone
    ParentBackground = False
    TabOrder = 0
    ExplicitWidth = 185
    object lblLayoutName: TLabel
      Left = 12
      Top = 12
      Width = 37
      Height = 15
      Caption = 'Layout'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 228
    Width = 520
    Height = 32
    Align = alBottom
    BevelOuter = bvNone
    ParentBackground = False
    TabOrder = 1
    ExplicitTop = 0
    ExplicitWidth = 185
    object lblKeyInfo: TLabel
      Left = 12
      Top = 8
      Width = 3
      Height = 15
    end
  end
  object pnlKeyboard: TScrollBox
    Left = 0
    Top = 40
    Width = 520
    Height = 188
    VertScrollBar.Visible = False
    Align = alClient
    BorderStyle = bsNone
    TabOrder = 2
    ExplicitTop = 0
    ExplicitWidth = 185
    ExplicitHeight = 41
  end
end
