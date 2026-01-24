object frmSequenceEditor: TfrmSequenceEditor
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Sequence Editor'
  ClientHeight = 360
  ClientWidth = 520
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = True
  Position = poScreenCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 15
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 520
    Height = 48
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    ExplicitWidth = 185
    object lblInfo: TLabel
      Left = 12
      Top = 16
      Width = 146
      Height = 15
      Caption = 'Define multi-key sequences'
    end
  end
  object grdSequences: TStringGrid
    Left = 0
    Top = 48
    Width = 520
    Height = 312
    Align = alClient
    ColCount = 2
    Options = [goColSizing, goEditing, goRowSelect]
    TabOrder = 1
    ExplicitTop = 0
    ExplicitWidth = 320
    ExplicitHeight = 120
  end
  object btnOK: TButton
    Left = 336
    Top = 320
    Width = 80
    Height = 25
    Caption = 'OK'
    TabOrder = 2
    OnClick = btnOKClick
  end
  object btnCancel: TButton
    Left = 424
    Top = 320
    Width = 80
    Height = 25
    Caption = 'Cancel'
    TabOrder = 3
    OnClick = btnCancelClick
  end
end
