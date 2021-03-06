unit FarCry2MFL_FormMain;

interface

uses
  Classes,
  Controls,
  Dialogs,
  Forms,
  Messages,
  StdCtrls,
  ShellAPI,
  SysUtils,
  Windows,
  ExtCtrls;

type
  TForm1 = class(TForm)
    Memo1: TMemo;
    OpenDialogExe: TOpenDialog;
    ButtonBrowseExe: TButton;
    EditExe: TEdit;
    ButtonStart: TButton;
    LabelExe: TLabel;
    ButtonShortcut: TButton;
    LabelVersion: TLabel;
    SaveDialogLnk: TSaveDialog;
    LabelAuthor: TLabel;
    LabelGitHub: TLabel;
    LabelDebug: TLabel;
    Timer1: TTimer;
    ButtonOptions: TButton;
    procedure ButtonBrowseExeClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure ButtonStartClick(Sender: TObject);
    procedure ButtonShortcutClick(Sender: TObject);
    procedure LabelGitHubClick(Sender: TObject);
    procedure LabelDebugClick(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure ButtonOptionsClick(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    MessagesCounter: Integer;
    StringMessage: string;
    DebugLayout: Boolean;
    procedure OnMessage(var MSG: TMessage); message WM_APP + 1;
    procedure AdjustFormToDebug();
    procedure AdjustFormLayout();
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

  //--------------------------------------------------------------------------------------------------
implementation
//--------------------------------------------------------------------------------------------------

uses
  ActiveX,
  FarCry2MFL_Proc;

{$R *.dfm}

//--------------------------------------------------------------------------------------------------
//    TForm1
//--------------------------------------------------------------------------------------------------

procedure TForm1.ButtonBrowseExeClick(Sender: TObject);
begin
  if OpenDialogExe.Execute then
  begin
    FarCry2ExeName := OpenDialogExe.FileName;
    EditExe.Text := FarCry2ExeName;
    SetDuniaDllName();
  end;
end;

procedure TForm1.OnMessage(var MSG: TMessage);
begin
  Inc(MessagesCounter);

  if (MSG.WParam = 1) then
  begin
    if (MSG.LParam = 0) then
    begin
      Log(IntToStr(MessagesCounter) + '. Recieved string message: ' + StringMessage);
      StringMessage := '';
    end
    else
    begin
      StringMessage := StringMessage + Chr(MSG.LParam);
    end;
    Exit;
  end;

  Log(IntToStr(MessagesCounter) + '. Recieved message: wParam = ' + IntToHex(MSG.WParam, 4) + ', lParam = ' + IntToHex(MSG.LParam, 4));
  if DllLoadingState = dlsLoading then
  begin
    if (MSG.WParam = 0) and (MSG.LParam = 0) then
      DllLoadingState := dlsOK;
    if (MSG.WParam = -1) and (MSG.LParam = -1) then
      DllLoadingState := dlsError;
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  Terminating: Boolean;
begin
  Terminating := False;
  EditExe.Text := FarCry2ExeName;
  LogMemo := Memo1;

  if IsSilentLaunch() then
  begin
    Visible := False;
    Terminating := CheckLaunchClose();
  end;
  if not Terminating then
  begin
    Visible := True;
    Application.ShowMainForm := True;
    LabelVersion.Caption := 'Version ' + CurrentFileInfo(Application.ExeName);
    AdjustFormToDebug();
  end;
end;

procedure TForm1.ButtonStartClick(Sender: TObject);
var
  FarCry2ProcessId: THandle;
  FarCry2Process: THandle;
begin
  if GameIsRunning() then
  begin
    FarCry2ProcessId := GetProcessHandle('FarCry2.exe');
    if FarCry2ProcessId > 0 then
    begin
      FarCry2Process := OpenProcess(PROCESS_TERMINATE, False, FarCry2ProcessId);
      TerminateProcess(FarCry2Process, 1);
    end;
  end
  else
  begin
    Self.Enabled := False;
    if not CheckLaunchClose() then
    begin
      Self.Enabled := True;
      AdjustFormLayout();
    end;
  end;
end;

procedure TForm1.ButtonShortcutClick(Sender: TObject);
var
  Arguments: string;
begin
  if SaveDialogLnk.Execute() then
  begin
    Arguments := '-play -exe "' + FarCry2ExeName + '" -dll "' + DllName + '"';
    if DebugEnabled then
      Arguments := '-debug ' + Arguments;
    CreateLnk(SaveDialogLnk.FileName, Application.ExeName, ExtractFilePath(FarCry2ExeName), 'Play Far Cry 2 with Multi Fixer', Arguments);
  end;
end;

procedure TForm1.LabelGitHubClick(Sender: TObject);
begin
  ShellExecute(Application.Handle, 'open', 'https://github.com/FoxAhead/Far-Cry-2-Multi-Fixer', nil, nil, SW_SHOW);
end;

procedure TForm1.LabelDebugClick(Sender: TObject);
begin
  DebugEnabled := not DebugEnabled;
  AdjustFormToDebug();
  Log('DebugEnabled: ' + BoolToStr(DebugEnabled, True));
end;

procedure TForm1.AdjustFormToDebug;
begin
  LabelVersion.Enabled := DebugEnabled;
  if DebugEnabled then
    FormStyle := fsStayOnTop
  else
    FormStyle := fsNormal;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  AdjustFormLayout();
end;

procedure TForm1.AdjustFormLayout;
const
  HiddenElementsHeight: Integer = 28;
  HeightDelta: Integer = 96;
var
  FarCry2Running: Boolean;
  I: Integer;
  NewDebugLayout: Bool;
begin
  FarCry2Running := GameIsRunning();
  if FarCry2Running then
    ButtonStart.Caption := 'Stop'
  else
    ButtonStart.Caption := 'Play';

  NewDebugLayout := DebugEnabled and FarCry2Running;
  if NewDebugLayout <> DebugLayout then
  begin
    DebugLayout := NewDebugLayout;
    for I := 0 to ComponentCount - 1 do
      if Components[I].Tag = 1 then
      begin
        LabelExe.Visible := not DebugLayout;
        EditExe.Visible := not DebugLayout;
        ButtonBrowseExe.Visible := not DebugLayout;
      end;
    if DebugLayout then
    begin
      ClientHeight := ClientHeight - HeightDelta;
      Memo1.Top := Memo1.Top - HiddenElementsHeight;
      Memo1.Height := Memo1.Height + HiddenElementsHeight;
      Left := 0;
      Top := Monitor.Height - Height;
    end
    else
    begin
      ClientHeight := ClientHeight + HeightDelta;
      Memo1.Top := Memo1.Top + HiddenElementsHeight;
      Memo1.Height := Memo1.Height - HiddenElementsHeight;
      if Left < 0 then
        Left := 0;
      if Top < 0 then
        Top := 0;
      if (Left + Width) > Monitor.Width then
        Left := Monitor.Width - Width;
      if (Top + Height) > Monitor.Height then
        Top := Monitor.Height - Height;
    end;
  end;
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  CoUninitialize();
end;

procedure TForm1.ButtonOptionsClick(Sender: TObject);
begin
  ShowOptionsDialog();
end;

procedure TForm1.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
    Close;
end;

end.

