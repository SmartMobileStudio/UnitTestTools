unit SmartTest.SMSC;

interface

uses
  TestFramework, System.SysUtils,

  SmartTest.PipedExecution, SmartTest.Common;

type
  TSmartMobileStudioExternalCompiler = class(TSmartMobileStudioCustomScriptTest)
  strict private
    FPipedExecution: TPipedExecution;
    procedure PipedExecutionExitHandler(Sender: TObject; ExitCode: Cardinal);
    procedure PipedExecutionNewLineHandler(Sender: TObject; const Text: string);
  protected
    procedure Compile; override;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestCompilation; override;
  end;

implementation

uses
  System.Classes, Winapi.Windows, Winapi.ShellAPI, Winapi.Messages,

  dwsXPlatform;

{ TSmartMobileStudioExternalCompiler }

procedure TSmartMobileStudioExternalCompiler.SetUp;
begin
  inherited;

  FPipedExecution := TPipedExecution.Create('smsc.exe ' +
    ExtractFileName(ScriptFileName), ExtractFileDir(ScriptFileName),
    PipedExecutionNewLineHandler, PipedExecutionExitHandler);
end;

procedure TSmartMobileStudioExternalCompiler.TearDown;
begin
  inherited;

  // eventually free any existing piped execution
  FPipedExecution.Free;
end;

procedure TSmartMobileStudioExternalCompiler.PipedExecutionExitHandler(Sender: TObject; ExitCode: Cardinal);
begin
  FPipedExecution := nil;
end;

procedure TSmartMobileStudioExternalCompiler.PipedExecutionNewLineHandler(Sender: TObject; const Text: string);
begin
  FMessageOutput := FMessageOutput + Text;
end;

procedure TSmartMobileStudioExternalCompiler.Compile;
begin
  inherited;

  while Assigned(FPipedExecution) do
    FPipedExecution.Peek;
end;

procedure TSmartMobileStudioExternalCompiler.TestCompilation;
var
  Output, Expected: string;
  InputFile: string;
begin
  inherited;

  // check if any command-line output is expected
  if FileExists(ScriptFileName + '.out') then
  begin
    Expected := LoadTextFromFile(ScriptFileName + '.out');
    Expected := StringReplace(Expected, #$A, '', [rfReplaceAll]);

    CheckEquals(Expected, FMessageOutput,
      'The compiler output does not match!');
  end;

  // check if any JS output is expected
  if FileExists(ScriptFileName + '.js') then
  begin
    // now check for the reference
    Check(FileExists(CompiledFileName));

    Expected := LoadTextFromFile(ScriptFileName + '.js');
    Output := LoadTextFromFile(CompiledFileName);
    CheckEquals(Expected, Output,
      'The error message does not match!');
  end
  else
  begin
    // check for error log
    if FileExists(ScriptFileName + '.error') then
    begin
      // load expected message
      Expected := LoadTextFromFile(ScriptFileName + '.error');

      // get relative input file
      InputFile := ExtractRelativePath(GetCurrentDir + '\', ExpandFileName(ScriptFileName));

      // replace the ScriptFileName variable with the actual ScriptFileName
      Expected := StringReplace(Expected, '%FileName%',
        InputFile, [rfReplaceAll, rfIgnoreCase]);

      // skip carriage returns
      Expected := Trim(StringReplace(Expected, #$A, '', [rfReplaceAll]));

      // compare with actual message
      CheckEquals(Expected, Trim(MessageOutput),
        'Message output does not match!');
    end;
  end;
end;

end.
