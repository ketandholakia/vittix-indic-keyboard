object frmEditorMain: TfrmEditorMain
  Left = 0
  Top = 0
  Caption = 'Vittix Indic Keyboard Layout Editor'
  ClientHeight = 714
  ClientWidth = 980
  Color = clWhite
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Menu = MainMenu1
  Position = poScreenCenter
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  TextHeight = 17
  object pnlMain: TPanel
    Left = 0
    Top = 33
    Width = 980
    Height = 681
    Align = alClient
    BevelOuter = bvNone
    Color = 15790320
    ParentBackground = False
    TabOrder = 1
    ExplicitTop = 52
    ExplicitHeight = 568
    object splitterVert: TSplitter
      Left = 620
      Top = 0
      Width = 6
      Height = 681
      Align = alRight
      Color = clGainsboro
      ParentColor = False
      ExplicitHeight = 568
    end
    object panelstringgrid: TPanel
      Left = 0
      Top = 0
      Width = 620
      Height = 681
      Align = alClient
      BevelOuter = bvNone
      Color = clWhite
      TabOrder = 0
      ExplicitHeight = 568
      object lblEmptyState: TLabel
        Left = 200
        Top = 270
        Width = 189
        Height = 34
        Alignment = taCenter
        Caption = 'Open or create a layout to start editing'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 10395294
        Font.Height = -13
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        WordWrap = True
      end
      object PageControl: TPageControl
        Left = 0
        Top = 0
        Width = 620
        Height = 681
        ActivePage = tabDirect
        Align = alClient
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        TabOrder = 0
        ExplicitHeight = 568
        object tabDirect: TTabSheet
          Caption = '  Direct  '
          object pnlSearchDirect: TPanel
            Left = 0
            Top = 0
            Width = 612
            Height = 40
            Align = alTop
            BevelOuter = bvNone
            Color = 16316664
            TabOrder = 0
            object edtSearchDirect: TEdit
              Left = 12
              Top = 8
              Width = 496
              Height = 23
              Anchors = [akLeft, akTop, akRight]
              Hint = 'Search Direct Key Mappings...'
              ParentShowHint = False
              ShowHint = True
              TabOrder = 0
              TextHint = 'Search mappings...'
              OnChange = edtSearchDirectChange
            end
            object btnAddDirect: TButton
              Left = 516
              Top = 7
              Width = 84
              Height = 25
              Anchors = [akTop, akRight]
              Caption = '+ Add'
              TabOrder = 1
              Tag = 0
              OnClick = btnAddRowClick
            end
          end
          object grdDirect: TStringGrid
            Left = 0
            Top = 40
            Width = 612
            Height = 611
            Align = alClient
            ColCount = 4
            ColWidths = (
              60
              100
              100
              120)
            DefaultColWidth = 180
            DefaultRowHeight = 26
            FixedCols = 0
            RowCount = 2
            FixedRows = 1
            PopupMenu = pmGridContext
            TabOrder = 1
            ExplicitHeight = 498
          end
        end
        object tabPrebase: TTabSheet
          Caption = '  Prebase  '
          object pnlSearchPrebase: TPanel
            Left = 0
            Top = 0
            Width = 612
            Height = 40
            Align = alTop
            BevelOuter = bvNone
            Color = 16316664
            TabOrder = 0
            object edtSearchPrebase: TEdit
              Left = 12
              Top = 8
              Width = 496
              Height = 23
              Anchors = [akLeft, akTop, akRight]
              Hint = 'Search Prebase Matras...'
              ParentShowHint = False
              ShowHint = True
              TabOrder = 0
              TextHint = 'Search matras...'
              OnChange = edtSearchPrebaseChange
            end
            object btnAddPrebase: TButton
              Left = 516
              Top = 7
              Width = 84
              Height = 25
              Anchors = [akTop, akRight]
              Caption = '+ Add'
              TabOrder = 1
              Tag = 1
              OnClick = btnAddRowClick
            end
          end
          object grdPrebase: TStringGrid
            Left = 0
            Top = 40
            Width = 612
            Height = 611
            Align = alClient
            ColCount = 2
            DefaultColWidth = 180
            DefaultRowHeight = 26
            PopupMenu = pmGridContext
            TabOrder = 1
            ExplicitHeight = 498
          end
        end
        object tabPostbase: TTabSheet
          Caption = '  Postbase  '
          object pnlSearchPostbase: TPanel
            Left = 0
            Top = 0
            Width = 612
            Height = 40
            Align = alTop
            BevelOuter = bvNone
            Color = 16316664
            TabOrder = 0
            object edtSearchPostbase: TEdit
              Left = 12
              Top = 8
              Width = 496
              Height = 23
              Anchors = [akLeft, akTop, akRight]
              Hint = 'Search Postbase Matras...'
              ParentShowHint = False
              ShowHint = True
              TabOrder = 0
              TextHint = 'Search matras...'
              OnChange = edtSearchPostbaseChange
            end
            object btnAddPostbase: TButton
              Left = 516
              Top = 7
              Width = 84
              Height = 25
              Anchors = [akTop, akRight]
              Caption = '+ Add'
              TabOrder = 1
              Tag = 2
              OnClick = btnAddRowClick
            end
          end
          object grdPostbase: TStringGrid
            Left = 0
            Top = 40
            Width = 612
            Height = 611
            Align = alClient
            ColCount = 2
            DefaultColWidth = 180
            DefaultRowHeight = 26
            PopupMenu = pmGridContext
            TabOrder = 1
            ExplicitHeight = 498
          end
        end
        object tabSequences: TTabSheet
          Caption = '  Sequences (legacy)  '
          object pnlSearchSequences: TPanel
            Left = 0
            Top = 0
            Width = 612
            Height = 58
            Align = alTop
            BevelOuter = bvNone
            Color = 16316664
            TabOrder = 0
            object edtSearchSequences: TEdit
              Left = 12
              Top = 8
              Width = 590
              Height = 23
              Hint = 'Search Sequences...'
              ParentShowHint = False
              ShowHint = True
              TabOrder = 0
              TextHint = 'Search sequences...'
              OnChange = edtSearchSequencesChange
            end
            object lblSequencesNotice: TLabel
              Left = 12
              Top = 37
              Width = 590
              Height = 15
              AutoSize = False
              Caption =
                'Deprecated: the engine does not execute multi-key sequences. Use halant-based conjunct input instead (e.g. k \ s for ksha).'
              ParentColor = False
              Transparent = True
            end
          end
          object grdSequences: TStringGrid
            Left = 0
            Top = 58
            Width = 612
            Height = 593
            Align = alClient
            ColCount = 2
            DefaultColWidth = 180
            DefaultRowHeight = 26
            PopupMenu = pmGridContext
            TabOrder = 1
            ExplicitHeight = 498
          end
        end
        object tabModifiers: TTabSheet
          Caption = '  Modifiers  '
          object pnlSearchModifiers: TPanel
            Left = 0
            Top = 0
            Width = 612
            Height = 40
            Align = alTop
            BevelOuter = bvNone
            Color = 16316664
            TabOrder = 0
            object edtSearchModifiers: TEdit
              Left = 12
              Top = 8
              Width = 496
              Height = 23
              Anchors = [akLeft, akTop, akRight]
              Hint = 'Search Modifiers...'
              ParentShowHint = False
              ShowHint = True
              TabOrder = 0
              TextHint = 'Search modifiers...'
              OnChange = edtSearchModifiersChange
            end
            object btnAddModifiers: TButton
              Left = 516
              Top = 7
              Width = 84
              Height = 25
              Anchors = [akTop, akRight]
              Caption = '+ Add'
              TabOrder = 1
              Tag = 3
              OnClick = btnAddRowClick
            end
          end
          object grdModifiers: TStringGrid
            Left = 0
            Top = 40
            Width = 612
            Height = 611
            Align = alClient
            ColCount = 2
            DefaultColWidth = 180
            DefaultRowHeight = 26
            PopupMenu = pmGridContext
            TabOrder = 1
            ExplicitHeight = 498
          end
        end
        object tabKeyboard: TTabSheet
          Caption = '  Keyboard  '
          object pnlKeyboardHeader: TPanel
            Left = 0
            Top = 0
            Width = 612
            Height = 32
            Align = alTop
            BevelOuter = bvNone
            Color = 16316664
            TabOrder = 0
            object lblKeyboardHint: TLabel
              Left = 12
              Top = 13
              Width = 344
              Height = 17
              Caption = 'Click a key below to see and assign its mapping.'
              Font.Charset = DEFAULT_CHARSET
              Font.Color = 5658198
              Font.Height = -12
              Font.Name = 'Segoe UI'
              Font.Style = []
              ParentFont = False
            end
          end
          object vkvKeyboard: TVittixKeyboardView
            Left = 0
            Top = 80
            Width = 612
            Height = 571
            Align = alClient
            Color = clWhite
            ParentColor = False
            TabOrder = 2
			 ScaleToFit = True
            ExplicitHeight = 458
          end
        end
        object tabPreview: TTabSheet
          Caption = '  Preview  '
          object pnlPreview: TPanel
            Left = 0
            Top = 0
            Width = 612
            Height = 651
            Align = alClient
            BevelOuter = bvNone
            Color = 16448250
            TabOrder = 0
            ExplicitHeight = 538
            object lblPreviewHint: TLabel
              Left = 14
              Top = 14
              Width = 580
              Height = 16
              AutoSize = False
              Caption = 'Open a layout to preview its output.'
            end
            object edtPreviewInput: TEdit
              Left = 14
              Top = 36
              Width = 584
              Height = 25
              Anchors = [akLeft, akTop, akRight]
              TabOrder = 0
              TextHint = 'Type here to preview this layout...'
            end
            object lblPreviewOutput: TLabel
              Left = 14
              Top = 74
              Width = 584
              Height = 96
              AutoSize = False
              Caption = ''
              WordWrap = True
            end
            object lblPreviewSourcesCaption: TLabel
              Left = 14
              Top = 182
              Width = 200
              Height = 15
              Caption = 'Resolved from'
            end
            object lstPreviewSources: TListBox
              Left = 14
              Top = 202
              Width = 584
              Height = 300
              Anchors = [akLeft, akTop, akRight, akBottom]
              ItemHeight = 16
              TabOrder = 1
            end
          end
        end
      end
    end
    object Panel2: TPanel
      Left = 626
      Top = 0
      Width = 354
      Height = 681
      Align = alRight
      BevelOuter = bvNone
      Color = 16448250
      TabOrder = 1
      ExplicitHeight = 568
      object pnlSideScroll: TScrollBox
        Left = 0
        Top = 0
        Width = 354
        Height = 681
        Align = alClient
        BorderStyle = bsNone
        Color = 16448250
        ParentColor = False
        TabOrder = 0
        ExplicitHeight = 568
        object pnlLayoutInfo: TPanel
          Left = 0
          Top = 0
          Width = 338
          Height = 185
          Align = alTop
          BevelOuter = bvNone
          Color = clWhite
          TabOrder = 0
          object lblSectionLayout: TLabel
            Left = 14
            Top = 12
            Width = 71
            Height = 13
            Caption = 'LAYOUT INFO'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 8092539
            Font.Height = -11
            Font.Name = 'Segoe UI'
            Font.Style = [fsBold]
            ParentFont = False
          end
          object lblDivider1: TLabel
            Left = 14
            Top = 30
            Width = 310
            Height = 1
            AutoSize = False
            Color = 14737632
            ParentColor = False
          end
          object lblLayoutName: TLabel
            Left = 14
            Top = 44
            Width = 71
            Height = 15
            Caption = 'Layout Name'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 5592405
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
          end
          object lblScript: TLabel
            Left = 14
            Top = 98
            Width = 93
            Height = 15
            Caption = 'Script / Language'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 5592405
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
          end
          object Label1: TLabel
            Left = 14
            Top = 150
            Width = 68
            Height = 15
            Caption = 'Preview Font'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 5592405
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
          end
          object edtLayoutName: TEdit
            Left = 14
            Top = 62
            Width = 312
            Height = 25
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -13
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            TabOrder = 0
          end
          object ComboBoxScript: TComboBox
            Left = 14
            Top = 116
            Width = 312
            Height = 25
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -13
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            TabOrder = 1
            Text = 'Select Script / Language'
          end
          object ComboBoxFonts: TComboBox
            Left = 14
            Top = 168
            Width = 312
            Height = 25
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -13
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            TabOrder = 2
            Text = 'Select Font for Preview'
          end
        end
        object pnlProperties: TPanel
          Left = 0
          Top = 185
          Width = 338
          Height = 158
          Align = alTop
          BevelOuter = bvNone
          Color = clWhite
          TabOrder = 1
          object lblSectionProps: TLabel
            Left = 14
            Top = 12
            Width = 103
            Height = 13
            Caption = 'LAYOUT METADATA'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 8092539
            Font.Height = -11
            Font.Name = 'Segoe UI'
            Font.Style = [fsBold]
            ParentFont = False
          end
          object lblDivider2: TLabel
            Left = 14
            Top = 30
            Width = 310
            Height = 1
            AutoSize = False
            Color = 14737632
            ParentColor = False
          end
          object btnAddKeyMap: TButton
            Left = 210
            Top = 8
            Width = 116
            Height = 26
            Hint = 'Add a new key map type to this layout'
            Caption = '+ Add Key Map'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            ParentShowHint = False
            ShowHint = True
            TabOrder = 0
          end
          object grdProperties: TStringGrid
            Left = 14
            Top = 36
            Width = 312
            Height = 114
            Hint = 'Edit layout metadata properties here.'
            ColCount = 2
            FixedCols = 0
            RowCount = 2
            Options = [goEditing, goAlwaysShowEditor]
            ParentShowHint = False
            ShowHint = True
            TabOrder = 1
          end
        end
        object pnlHotkeys: TPanel
          Left = 0
          Top = 343
          Width = 338
          Height = 108
          Align = alTop
          BevelOuter = bvNone
          Color = clWhite
          TabOrder = 2
          object lblSectionHotkeys: TLabel
            Left = 14
            Top = 12
            Width = 134
            Height = 13
            Caption = 'HOTKEY CUSTOMIZATION'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 8092539
            Font.Height = -11
            Font.Name = 'Segoe UI'
            Font.Style = [fsBold]
            ParentFont = False
          end
          object lblDivider3: TLabel
            Left = 14
            Top = 30
            Width = 310
            Height = 1
            AutoSize = False
            Color = 14737632
            ParentColor = False
          end
          object lblHotkeySwitch: TLabel
            Left = 14
            Top = 42
            Width = 115
            Height = 15
            Caption = 'Switch Layout Hotkey'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 5592405
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
          end
          object lblHotkeyAction: TLabel
            Left = 14
            Top = 74
            Width = 116
            Height = 15
            Caption = 'Special Action Hotkey'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 5592405
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
          end
          object edtHotkeySwitch: TEdit
            Left = 170
            Top = 40
            Width = 156
            Height = 25
            Hint = 'Set hotkey for switching layouts'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -13
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            ParentShowHint = False
            ShowHint = True
            TabOrder = 0
          end
          object edtHotkeyAction: TEdit
            Left = 170
            Top = 72
            Width = 156
            Height = 25
            Hint = 'Set hotkey for special action'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -13
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            ParentShowHint = False
            ShowHint = True
            TabOrder = 1
          end
        end
        object pnlAppSettings: TPanel
          Left = 0
          Top = 451
          Width = 338
          Height = 104
          Align = alTop
          BevelOuter = bvNone
          Color = clWhite
          TabOrder = 4
          object lblSectionAppSettings: TLabel
            Left = 14
            Top = 10
            Width = 142
            Height = 13
            Caption = 'APPLICATION SETTINGS'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 8092539
            Font.Height = -11
            Font.Name = 'Segoe UI'
            Font.Style = [fsBold]
            ParentFont = False
          end
          object lblDivider5: TLabel
            Left = 14
            Top = 28
            Width = 310
            Height = 1
            AutoSize = False
            Color = 14737632
            ParentColor = False
          end
          object lblKeyFontSize: TLabel
            Left = 14
            Top = 42
            Width = 73
            Height = 15
            Caption = 'Key Font Size'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 5592405
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
          end
          object ComboBoxKeyFontSize: TComboBox
            Left = 170
            Top = 40
            Width = 156
            Height = 25
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -13
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            TabOrder = 0
          end
          object chkHighContrast: TCheckBox
            Left = 14
            Top = 72
            Width = 160
            Height = 24
            Hint = 'Toggle high-contrast colours for accessibility'
            Caption = 'High Contrast Mode'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -13
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            ParentShowHint = False
            ShowHint = True
            TabOrder = 1
          end
          object btnHelp: TButton
            Left = 206
            Top = 70
            Width = 108
            Height = 28
            Hint = 'Show help, user guide and about'
            Caption = 'Help / About'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            ParentShowHint = False
            ShowHint = True
            TabOrder = 2
          end
        end
        object pnlDiagnostics: TPanel
          Left = 0
          Top = 725
          Width = 338
          Height = 82
          Align = alTop
          BevelOuter = bvNone
          Color = 16053492
          TabOrder = 3
          object lblSectionDiag: TLabel
            Left = 14
            Top = 10
            Width = 72
            Height = 13
            Caption = 'DIAGNOSTICS'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 8092539
            Font.Height = -11
            Font.Name = 'Segoe UI'
            Font.Style = [fsBold]
            ParentFont = False
          end
          object lblDivider4: TLabel
            Left = 14
            Top = 28
            Width = 310
            Height = 1
            AutoSize = False
            Color = 14737632
            ParentColor = False
          end
          object lblDiagInfo: TLabel
            Left = 14
            Top = 36
            Width = 310
            Height = 40
            AutoSize = False
            Caption = 'Open a layout to see diagnostics.'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 6710886
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            WordWrap = True
          end
        end
        object pnlMappingInspector: TPanel
          Left = 0
          Top = 555
          Width = 338
          Height = 170
          Align = alTop
          BevelOuter = bvNone
          Color = clWhite
          TabOrder = 3
          object lblInspectorTitle: TLabel
            Left = 14
            Top = 12
            Width = 126
            Height = 13
            Caption = 'Mapping Inspector'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 8092539
            Font.Height = -11
            Font.Name = 'Segoe UI'
            Font.Style = [fsBold]
            ParentFont = False
          end
          object lblInspectorGrid: TLabel
            Left = 14
            Top = 34
            Width = 65
            Height = 15
            Caption = 'Grid: -'
          end
          object lblInspectorKey: TLabel
            Left = 14
            Top = 60
            Width = 23
            Height = 15
            Caption = 'Key'
          end
          object lblInspectorValue: TLabel
            Left = 14
            Top = 96
            Width = 37
            Height = 15
            Caption = 'Value'
          end
          object edtInspectorKey: TEdit
            Left = 72
            Top = 56
            Width = 256
            Height = 23
            TabOrder = 0
          end
          object edtInspectorValue: TEdit
            Left = 72
            Top = 92
            Width = 256
            Height = 23
            TabOrder = 1
          end
          object btnInspectorApply: TButton
            Left = 14
            Top = 128
            Width = 75
            Height = 25
            Caption = 'Apply'
            TabOrder = 2
          end
          object btnInspectorClear: TButton
            Left = 95
            Top = 128
            Width = 75
            Height = 25
            Caption = 'Clear'
            TabOrder = 3
          end
          object btnInspectorAdd: TButton
            Left = 256
            Top = 128
            Width = 72
            Height = 25
            Caption = '+ Add'
            TabOrder = 4
          end
        end
      end
    end
    object pnlProblems: TPanel
      Left = 0
      Top = 549
      Width = 980
      Height = 132
      Align = alBottom
      BevelOuter = bvNone
      Color = clWhite
      ParentBackground = False
      TabOrder = 9
      Visible = False
      object lblProblemsSummary: TLabel
        Left = 12
        Top = 8
        Width = 400
        Height = 15
        Caption = 'Problems'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object btnProblemsClose: TButton
        Left = 900
        Top = 6
        Width = 68
        Height = 24
        Anchors = [akTop, akRight]
        Caption = 'Close'
        TabOrder = 0
        OnClick = btnProblemsCloseClick
      end
      object lstProblems: TListBox
        Left = 12
        Top = 30
        Width = 956
        Height = 94
        Anchors = [akLeft, akTop, akRight, akBottom]
        ItemHeight = 16
        TabOrder = 1
        OnDblClick = lstProblemsDblClick
      end
    end
  end
  object pnlCommandBar: TPanel
    Left = 0
    Top = 0
    Width = 980
    Height = 40
    Align = alTop
    BevelOuter = bvNone
    Color = clWhite
    ParentBackground = False
    TabOrder = 2
    object btnBarNew: TButton
      Left = 8
      Top = 6
      Width = 52
      Height = 26
      Caption = 'New'
      TabOrder = 0
      OnClick = btnNewLayoutClick
    end
    object btnBarOpen: TButton
      Left = 66
      Top = 6
      Width = 56
      Height = 26
      Caption = 'Open'
      TabOrder = 1
      OnClick = btnOpenClick
    end
    object btnBarSave: TButton
      Left = 128
      Top = 6
      Width = 56
      Height = 26
      Caption = 'Save'
      TabOrder = 2
      OnClick = btnSaveClick
    end
    object btnBarSaveAs: TButton
      Left = 190
      Top = 6
      Width = 70
      Height = 26
      Caption = 'Save As'
      TabOrder = 3
      OnClick = btnSaveAsClick
    end
    object btnBarUndo: TButton
      Left = 266
      Top = 6
      Width = 56
      Height = 26
      Caption = 'Undo'
      TabOrder = 4
      OnClick = btnUndoClick
    end
    object btnBarRedo: TButton
      Left = 328
      Top = 6
      Width = 56
      Height = 26
      Caption = 'Redo'
      TabOrder = 5
      OnClick = btnRedoClick
    end
    object btnBarValidate: TButton
      Left = 390
      Top = 6
      Width = 68
      Height = 26
      Caption = 'Validate'
      TabOrder = 6
    end
  end
  object pmGridContext: TPopupMenu
    Left = 452
    Top = 180
    object miAddKey: TMenuItem
      Caption = 'Add Key'
    end
    object miRemoveKey: TMenuItem
      Caption = 'Remove Key'
    end
    object miCopy: TMenuItem
      Caption = 'Copy'
    end
    object miPaste: TMenuItem
      Caption = 'Paste'
    end
    object miValidate: TMenuItem
      Caption = 'Validate'
    end
  end
  object OpenDialog: TOpenDialog
    Filter = 'Keyboard Layout (*.json)|*.json'
    Left = 200
    Top = 160
  end
  object SaveDialog: TSaveDialog
    Filter = 'Keyboard Layout (*.json)|*.json'
    Left = 80
    Top = 296
  end
  object MainMenu1: TMainMenu
    Left = 300
    Top = 160
    object miFile: TMenuItem
      Caption = '&File'
      object miNew: TMenuItem
        Caption = '&New Layout'
        ShortCut = 16462
        OnClick = btnNewLayoutClick
      end
      object miOpen: TMenuItem
        Caption = '&Open...'
        ShortCut = 16463
        OnClick = btnOpenClick
      end
      object miSave: TMenuItem
        Caption = '&Save'
        ShortCut = 16467
        OnClick = btnSaveClick
      end
      object miSaveAs: TMenuItem
        Caption = 'Save &As...'
        ShortCut = 24659
        OnClick = btnSaveAsClick
      end
      object miSep1: TMenuItem
        Caption = '-'
      end
      object miSep2: TMenuItem
        Caption = '-'
      end
      object miExit: TMenuItem
        Caption = 'E&xit'
        ShortCut = 32883
        OnClick = miExitClick
      end
    end
    object miEdit: TMenuItem
      Caption = '&Edit'
      object miUndo: TMenuItem
        Caption = '&Undo'
        ShortCut = 16474
        OnClick = btnUndoClick
      end
      object miRedo: TMenuItem
        Caption = '&Redo'
        ShortCut = 16473
        OnClick = btnRedoClick
      end
    end
    object miHelpMenu: TMenuItem
      Caption = '&Help'
      object miAbout: TMenuItem
        Caption = '&About / Help'
        OnClick = btnHelpClick
      end
    end
    object miTools: TMenuItem
      Caption = '&Tools'
      object miValidateLayout: TMenuItem
        Caption = '&Validate Layout'
        ShortCut = 118
      end
    end
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 694
    Width = 980
    Height = 20
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Segoe UI'
    Font.Style = []
    Panels = <
      item
        Text = 'Ready'
        Width = 120
      end
      item
        Text = '(untitled)'
        Width = 300
      end
      item
        Text = 'Keys: 0'
        Width = 100
      end
      item
        Width = 170
      end>
    UseSystemFont = False
  end
end
