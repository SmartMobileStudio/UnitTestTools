unit SmartTest.SMSC;

interface

uses
  TestFramework, System.SysUtils,

  SmartTest.PipedExecution, SmartTest.Common;

type
  TSmartMobileStudioExternalCompiler = class(TSmartMobileStudioCustomScriptTest)
  strict private
    FPipedExecution: TPipedExecution;
    FExitCode: Integer;
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

resourcestring
  RStrOutputMessageMismatch = 'Message output does not match!';
  RStrFileDoesNotExist = 'File %s does not exist!';
  RStrCompilerOutputMismatch = 'The compiler output does not match!';
  RStrErrorMessageMismatch = 'The error message does not match!';
  RStrCompilationFailed = 'Compilation failed with exit code %d '#10 +
    'and error log: %s';

{ TSmartMobileStudioExternalCompiler }

procedure TSmartMobileStudioExternalCompiler.SetUp;
begin
  inherited;

  FExitCode := 0;

  FPipedExecution := TPipedExecution.Create('smsc.exe -unit-path=.\RTL\ ' +
    ScriptFileName, '.', PipedExecutionNewLineHandler, PipedExecutionExitHandler);
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
  FExitCode := ExitCode;
end;

procedure TSmartMobileStudioExternalCompiler.PipedExecutionNewLineHandler(Sender: TObject; const Text: string);
begin
  FMessageOutput := FMessageOutput + Text;
end;

procedure TSmartMobileStudioExternalCompiler.Compile;
begin
  inherited;

  // peek command-line output
  while Assigned(FPipedExecution) do
    FPipedExecution.Peek;
end;

procedure TSmartMobileStudioExternalCompiler.TestCompilation;
var
  Output, Expected: string;
  InputFile: string;
begin
  inherited;
  
  // eventually compile script
  if not FileExists(CompiledFileName) then
    Compile; 

  // check if any command-line output is expected
  if FileExists(ScriptFileName + '.out') then
  begin
    // load expected output and preprocess
    Expected := LoadTextFromFile(ScriptFileName + '.out');
    Expected := StringReplace(Expected, #$A, '', [rfReplaceAll]);

    // compare the message output with expected output
    CheckEquals(Expected, FMessageOutput, RStrCompilerOutputMismatch);
  end;

  // check if any JS output is expected
  if FileExists(ScriptFileName + '.js') then
  begin
    // now check for the reference
    Check(FileExists(CompiledFileName), Format(RStrFileDoesNotExist, [CompiledFileName]));

    // load expected and actual JavaScript code
    Expected := LoadTextFromFile(ScriptFileName + '.js');
    Output := LoadTextFromFile(CompiledFileName);

    // check if both are identical
    CheckEquals(Expected, Output, RStrErrorMessageMismatch);
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
      CheckEquals(Expected, Trim(MessageOutput), RStrOutputMessageMismatch);
    end
    else
    begin
      // check the exit code of the command-line compiler
      Check(FExitCode = 0, Format(RStrCompilationFailed, [FExitCode, MessageOutput]));
    end;
  end;
end;

end.
