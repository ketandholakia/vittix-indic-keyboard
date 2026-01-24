object frmEditorMain: TfrmEditorMain
  Left = 0
  Top = 0
  Caption = 'Vittix Indic Keyboard '#226#8364#8220' Layout Editor'
  ClientHeight = 520
  ClientWidth = 760
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
    Width = 760
    Height = 48
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
  end
  object pnlMain: TPanel
    Left = 0
    Top = 48
    Width = 760
    Height = 472
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object Panel2: TPanel
      Left = 400
      Top = 0
      Width = 360
      Height = 472
      Align = alRight
      TabOrder = 0
      ExplicitLeft = 402
      ExplicitTop = 6
      object lblLayoutName: TLabel
        Left = 12
        Top = 16
        Width = 71
        Height = 15
        Caption = 'Layout Name'
      end
      object Label1: TLabel
        Left = 14
        Top = 57
        Width = 68
        Height = 15
        Caption = 'Preview Font'
      end
      object edtLayoutName: TEdit
        Left = 90
        Top = 12
        Width = 260
        Height = 23
        TabOrder = 0
      end
      object ComboBoxFonts: TComboBox
        Left = 91
        Top = 54
        Width = 262
        Height = 23
        TabOrder = 1
        Text = 'Select Fonts For Key Preview'
      end
      object btnOpen: TButton
        Left = 258
        Top = 429
        Width = 80
        Height = 25
        Caption = 'Open'
        TabOrder = 2
        OnClick = btnOpenClick
      end
      object btnSave: TButton
        Left = 22
        Top = 429
        Width = 80
        Height = 25
        Caption = 'Save'
        TabOrder = 3
        OnClick = btnSaveClick
      end
      object btnSaveAs: TButton
        Left = 141
        Top = 428
        Width = 80
        Height = 25
        Caption = 'Save'
        TabOrder = 4
        OnClick = btnSaveClick
      end
    end
    object panelstringgrid: TPanel
      Left = 0
      Top = 0
      Width = 400
      Height = 472
      Align = alClient
      Caption = 'Open a layout file to start editing'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabOrder = 1
      ExplicitLeft = -104
      ExplicitTop = 160
      ExplicitWidth = 465
      ExplicitHeight = 225
      object lblEmptyState: TLabel
        Left = 184
        Top = 232
        Width = 79
        Height = 17
        Caption = 'lblEmptyState'
      end
      object PageControl: TPageControl
        Left = 1
        Top = 1
        Width = 398
        Height = 470
        ActivePage = tabDirect
        Align = alClient
        TabOrder = 0
        object tabDirect: TTabSheet
          Caption = 'Direct'
          object Panel1: TPanel
            Left = 0
            Top = 0
            Width = 390
            Height = 438
            Align = alClient
            Caption = 'Panel1'
            TabOrder = 1
            ExplicitWidth = 455
            ExplicitHeight = 193
          end
          object grdDirect: TStringGrid
            Left = 0
            Top = 0
            Width = 390
            Height = 438
            Align = alClient
            ColCount = 2
            TabOrder = 0
            ExplicitWidth = 455
            ExplicitHeight = 193
          end
        end
        object tabPrebase: TTabSheet
          Caption = 'Prebase'
          object grdPrebase: TStringGrid
            Left = 0
            Top = 0
            Width = 390
            Height = 438
            Align = alClient
            ColCount = 2
            TabOrder = 0
            ExplicitHeight = 440
          end
        end
        object tabPostbase: TTabSheet
          Caption = 'Postbase'
          object grdPostbase: TStringGrid
            Left = 0
            Top = 0
            Width = 390
            Height = 438
            Align = alClient
            ColCount = 2
            TabOrder = 0
            ExplicitHeight = 440
          end
        end
        object tabSequences: TTabSheet
          Caption = 'Sequences'
          object grdSequences: TStringGrid
            Left = 0
            Top = 0
            Width = 390
            Height = 438
            Align = alClient
            ColCount = 2
            TabOrder = 0
            ExplicitHeight = 440
          end
        end
        object tabModifiers: TTabSheet
          Caption = 'Modifiers'
          object grdModifiers: TStringGrid
            Left = 0
            Top = 0
            Width = 390
            Height = 438
            Align = alClient
            ColCount = 3
            TabOrder = 0
            ExplicitHeight = 440
          end
        end
      end
    end
  end
  object OpenDialog: TOpenDialog
    Filter = 'Keyboard Layout (*.json)|*.json'
  end
  object SaveDialog: TSaveDialog
    Filter = 'Keyboard Layout (*.json)|*.json'
    Left = 80
    Top = 296
  end
end
