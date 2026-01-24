object frmOnScreenKeyboard: TfrmOnScreenKeyboard
  BorderStyle = bsToolWindow
  Caption = 'Vittix Indic Keyboard - On Screen'
  ClientHeight = 260
  ClientWidth = 520
  Position = poDesigned
  OnCreate = FormCreate
  Font.Charset = DEFAULT_CHARSET
  Font.Name = 'Segoe UI'
  Font.Size = 9
  Font.Style = []
  PixelsPerInch = 96
  TextHeight = 13

  object pnlHeader: TPanel
    Align = alTop
    Height = 40
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    object lblLayoutName: TLabel
      Left = 12
      Top = 12
      Caption = 'Layout'
      Font.Style = [fsBold]
      ParentFont = False
    end
  end

  object pnlFooter: TPanel
    Align = alBottom
    Height = 32
    BevelOuter = bvNone
    ParentBackground = False
    object lblKeyInfo: TLabel
      Left = 12
      Top = 8
      Caption = ''
    end
  end

  object pnlKeyboard: TScrollBox
    Align = alClient
    BorderStyle = bsNone
    VertScrollBar.Visible = False
    HorzScrollBar.Visible = True
  end
end
