unit SmartTest.PipedExecution;

interface

uses
  (* Delphi *)
  System.SysUtils, System.Classes, System.Types, WinApi.Windows;

type
  TPipedExecution = class
  const
    CSizeReadBuffer = 1048576;  // 1 MB Buffer
  type
    TOnNewLine = procedure(Sender: TObject; const Text: string) of object;
    TOnExit = procedure(Sender: TObject; ExitCode: Cardinal) of object;
  private
    FOnExit: TOnExit;
    FOnNewLine: TOnNewLine;

    FPartialLine: string;
    FBuffer: PAnsiChar;
    FReadPipe: THandle;
    FWritePipe: THandle;
    FProcessInfo: TProcessInformation;
  public
    constructor Create(const CommandLine: string; const WorkDir: string;
      OnNewLine: TOnNewLine = nil; OnExit: TOnExit = nil);
    destructor Destroy; override;

    procedure Peek;

    property OnNewLine: TOnNewLine read FOnNewLine write FOnNewLine;
    property OnExit: TOnExit read FOnExit write FOnExit;
  end;

function RunExecutable(Executable: string): string;

implementation

type
  TPipedExecutionRunner = class
  private
    FPipedExecution: TPipedExecution;
    FExecutable: string;
    FOutput: string;
    FExitCode: Integer;
    procedure ExitHandler(Sender: TObject; ExitCode: Cardinal);
    procedure NewLineHandler(Sender: TObject; const Text: string);
  public
    constructor Create(const Executable: string);
    procedure Run;

    property ExitCode: Integer read FExitCode;
    property Output: string read FOutput;
  end;

constructor TPipedExecutionRunner.Create(const Executable: string);
begin
  FExecutable := Executable;
end;

procedure TPipedExecutionRunner.ExitHandler(Sender: TObject; ExitCode: Cardinal);
begin
  FPipedExecution := nil;
  FExitCode := ExitCode;
end;

procedure TPipedExecutionRunner.NewLineHandler(Sender: TObject; const Text: string);
begin
  FOutput := FOutput + Text + #10;
end;

procedure TPipedExecutionRunner.Run;
begin
  FPipedExecution := TPipedExecution.Create(FExecutable, '.',
    NewLineHandler, ExitHandler);

  while Assigned(FPipedExecution) do
    FPipedExecution.Peek;

  FPipedExecution.Free;
end;

function RunExecutable(Executable: string): string;
var
  Runner: TPipedExecutionRunner;
begin
  Runner := TPipedExecutionRunner.Create(Executable);
  try
    Runner.Run;
    Result := Runner.Output;
  finally
    Runner.Free;
  end;
end;


{ TPipedExecution }

constructor TPipedExecution.Create(const CommandLine, WorkDir: string;
  OnNewLine: TOnNewLine = nil; OnExit: TOnExit = nil);
var
  Security: TSecurityAttributes;
  Start: TStartUpInfo;
  UseWorkDir: string;
begin
  // initialize events
  FOnNewLine := OnNewLine;
  FOnExit := OnExit;

  // initialise string buffers
  FPartialLine := '';

  // setup security
  Security.nLength := SizeOf(TSecurityAttributes);
  Security.bInheritHandle := true;
  Security.lpSecurityDescriptor := nil;

  // create pipe
  if CreatePipe(FReadPipe, FWritePipe, @Security, 0) then
  begin
    FBuffer := AllocMem(CSizeReadBuffer + 1);
    FillChar(Start, Sizeof(Start),#0);
    Start.cb := SizeOf(Start);
    Start.hStdOutput := FWritePipe;
    Start.hStdInput := FReadPipe;
    Start.hStdError := FWritePipe;
    Start.dwFlags := STARTF_USESTDHANDLES + STARTF_USESHOWWINDOW;
    Start.wShowWindow := SW_HIDE;

    if WorkDir = '' then
      GetDir(0, UseWorkDir)
    else
      UseWorkDir := WorkDir;

    // create process
    if CreateProcess(nil, PChar(CommandLine), @Security, @Security, True,
         CREATE_NEW_CONSOLE + NORMAL_PRIORITY_CLASS, nil, PChar(UseWorkDir),
         Start, FProcessInfo) then
  end;
end;

destructor TPipedExecution.Destroy;
var
  ExitCode: Cardinal;
begin
  // check exit code
  ExitCode := 0;
  if WaitForSingleObject(FProcessInfo.hProcess, 10) = WAIT_TIMEOUT then
    TerminateProcess(FProcessInfo.hProcess, ExitCode)
  else
    GetExitCodeProcess(FProcessInfo.hProcess, ExitCode);

  // fire 'OnExit' event
  if Assigned(FOnExit) then
    FOnExit(Self, ExitCode);

  // free timer and buffers and close handles
  CloseHandle(FProcessInfo.hProcess);
  CloseHandle(FProcessInfo.hThread);
  CloseHandle(FReadPipe);
  CloseHandle(FWritePipe);
  FreeMem(FBuffer);

  // eventually process data which is still in the queue
  if (FPartialLine <> '') and Assigned(OnNewLine) then
    OnNewLine(Self, FPartialLine);

  inherited;
end;

procedure TPipedExecution.Peek;
var
  AppRunning: Cardinal;
  BytesRead: DWORD;
  TotalBytesAvail: Integer;
  BytesLeftThisMsg: Integer;
  LineBreakPos: Integer;
begin
  AppRunning := WaitForSingleObject(FProcessInfo.hProcess, 10);
  if not PeekNamedPipe(FReadPipe, @FBuffer[0], CSizeReadBuffer, @BytesRead,
    @TotalBytesAvail, @BytesLeftThisMsg) then
  begin
    Free;
    Exit;
  end;

  if BytesRead > 0 then
    ReadFile(FReadPipe, FBuffer[0], BytesRead, BytesRead, nil);
  FBuffer[BytesRead] := #0;

  if Assigned(OnNewLine) and (BytesRead > 0) then
  begin
    FPartialLine := FPartialLine + StrPas(FBuffer);
    repeat
      LineBreakPos := Pos(#10, FPartialLine);
      if LineBreakPos <= 0 then
        break; //repeat
      FOnNewLine(Self, Copy(FPartialLine, 1, LineBreakPos - 1));
      Delete(FPartialLine, 1, LineBreakPos);
    until false;
  end;

  if AppRunning <> WAIT_TIMEOUT then
    Free;
end;

end.
