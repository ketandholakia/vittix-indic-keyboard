unit LayoutReload;

{ Item 9.5: the detach / reload / re-attach decision used by the tray's
  settings-apply and reload paths, extracted from frmTray so it can be unit
  tested. The invariant: whatever happens, the engine ends up attached to a
  live layout — the exact same active layout when a reload fails — and the
  error travels to the caller for reporting exactly once. }

interface

uses
  System.SysUtils,
  LayoutModel,
  LayoutManager,
  ShreeLipi.Engine;

// Detach the engine, reload all layouts from ALayoutsPath, activate
// APreferredLayoutID ('' = the sorted default) and attach the engine to the
// manager's active layout.
//
// On failure: the layout set that was live before the call stays in the
// manager, the previously active layout is re-activated and re-attached to
// the engine, and the ORIGINAL exception propagates to the caller for
// reporting (Notify / MessageBox). The caller must not re-attach the engine
// itself — that is this routine's job in both paths.
procedure ReloadLayoutsAndActivate(const ALayoutsPath, APreferredLayoutID: string);

implementation

procedure ReloadLayoutsAndActivate(const ALayoutsPath, APreferredLayoutID: string);
var
  PreviousID: string;
begin
  PreviousID := '';
  if gLayoutManager.ActiveLayout <> nil then
    PreviousID := gLayoutManager.ActiveLayout.LayoutID;

  // Detach first: SetActiveLayout(nil) flushes any pending prebase/reph
  // through the still-valid old layout (item 1) and drops the engine's
  // pointer, so nothing below can flush through a freed layout object.
  SetActiveLayout(nil);
  try
    gLayoutManager.Initialize(ALayoutsPath);
  except
    // The manager keeps the previous layout set on a failed reload (item 1).
    // Re-activate the previously active layout and re-attach the engine so
    // typing continues, then let the original error travel to the caller.
    if PreviousID <> '' then
      gLayoutManager.SetActiveLayoutByID(PreviousID);
    SetActiveLayout(gLayoutManager.ActiveLayout);
    raise;
  end;

  if APreferredLayoutID <> '' then
    gLayoutManager.SetActiveLayoutByID(APreferredLayoutID);
  SetActiveLayout(gLayoutManager.ActiveLayout);
end;

end.
