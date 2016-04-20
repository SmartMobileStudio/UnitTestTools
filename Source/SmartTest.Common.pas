unit SmartTest.Common;

interface

uses
  TestFramework, System.SysUtils, System.Classes,

  SmartTest.PipedExecution;

type
  TSmartMobileStudioCustomScriptTest = class(TTestCase)
  private
    FScriptFileName: TFileName;
    FCompiledFileName: TFileName;
    FPipedExecution: TPipedExecution;

    FExecutionOutput: string;
    procedure PipedExecutionExitHandler(Sender: TObject; ExitCode: Cardinal);
    procedure PipedExecutionNewLineHandler(Sender: TObject; const Text: string);
    procedure SetScriptFileName(const Value: TFileName);
  protected
    FMessageOutput: string;
    procedure Run;
    procedure Compile; virtual;
    procedure SetUp; override;
    procedure ScriptFileNameChanged; virtual;

    property ExecutionOutput: string read FExecutionOutput;
  public
    property ScriptFileName: TFileName read FScriptFileName write SetScriptFileName;
    property CompiledFileName: TFileName read FCompiledFileName;
    property MessageOutput: string read FMessageOutput;
  published
    procedure TestCompilation; virtual;
    procedure TestExecution; virtual;
  end;

  TSmartMobileStudioTestSuite = class(TTestSuite)
  private
    FScriptFileName: TFileName;
    procedure SetScriptFileName(const Value: TFileName);
  public
    {$IFDEF FPC}
    procedure AddTestSuiteFromClass(ATestClass: TClass); override;
    {$ELSE}
    procedure AddTests(ATestClass: TTestCaseClass); override;
    {$ENDIF}
  published
    property ScriptFileName: TFileName read FScriptFileName write SetScriptFileName;
  end;

const
  CUnitTestPath = '..\Tests\';

implementation

uses
  dwsXPlatform,

  SmartTest.SMSC;

resourcestring
  RStrMissingScript = 'Specified script does not exist: %s';

{ TSmartMobileStudioCustomScriptTest }
procedure TSmartMobileStudioCustomScriptTest.PipedExecutionExitHandler(Sender: TObject; ExitCode: Cardinal);
begin
  FPipedExecution := nil;
end;

procedure TSmartMobileStudioCustomScriptTest.PipedExecutionNewLineHandler(Sender: TObject; const Text: string);
begin
  FExecutionOutput := FExecutionOutput + Text + #10;
end;

procedure TSmartMobileStudioCustomScriptTest.Compile;
begin
  // eventually delete an existing compiled file (.js file)
  if FileExists(FCompiledFileName) then
    DeleteFile(PWideChar(FCompiledFileName));
end;

procedure TSmartMobileStudioCustomScriptTest.Run;
begin
  FPipedExecution := TPipedExecution.Create('node.exe ' + ExtractFileName(CompiledFileName),
    ExtractFileDir(ScriptFileName),
    PipedExecutionNewLineHandler, PipedExecutionExitHandler);

  while Assigned(FPipedExecution) do
    FPipedExecution.Peek;

  FPipedExecution.Free;
end;

procedure TSmartMobileStudioCustomScriptTest.SetScriptFileName(const Value: TFileName);
begin
  if not FileExists(Value) then
    raise Exception.CreateFmt(RStrMissingScript, [Value]);

  if FScriptFileName <> Value then
  begin
    FScriptFileName := Value;
    ScriptFileNameChanged;
  end
end;

procedure TSmartMobileStudioCustomScriptTest.SetUp;
begin
  inherited;

  // reset output
  FMessageOutput := '';
  FExecutionOutput := '';
end;

procedure TSmartMobileStudioCustomScriptTest.ScriptFileNameChanged;
begin
  // determine compiled file
  FCompiledFileName := ChangeFileExt(ScriptFileName, '.js');
end;

procedure TSmartMobileStudioCustomScriptTest.TestCompilation;
begin
  Compile;
end;

procedure TSmartMobileStudioCustomScriptTest.TestExecution;
var
  Output, Expected: string;
begin
  Run;

  // check if any command-line output is expected
  if FileExists(ScriptFileName + '.result') then
  begin
    Expected := LoadTextFromFile(ScriptFileName + '.result');
    Expected := Trim(StringReplace(Expected, #$D, '', [rfReplaceAll]));

    CheckEquals(Expected, Trim(FExecutionOutput),
      'The node.js output does not match!');
  end;
end;


{ TSmartMobileStudioTestSuite }

procedure TSmartMobileStudioTestSuite.SetScriptFileName(const Value: TFileName);
begin
  if not FileExists(Value) then
    raise Exception.CreateFmt(RStrMissingScript, [Value]);

  if FScriptFileName <> Value then
    FScriptFileName := Value;
end;

{$IFDEF FPC}
procedure TSmartMobileStudioTestSuite.AddTestSuiteFromClass(ATestClass: TClass);
var
  MethodList: TStringList;
  Index: Integer;
  TestCase: TTestCase;
begin
  MethodList := TStringList.Create;
  try
    GetMethodList(ATestClass, MethodList);

    // make sure we add each test case to the list of tests
    for Index := 0 to MethodList.Count - 1 do
    begin
      TestCase := TTestCaseClass(ATestClass).CreateWithName(MethodList[Index]);
      (TestCase as TSmartMobileStudioCustomScriptTest).ScriptFileName := FScriptFileName;
      Self.AddTest(TestCase);
    end;
  finally
    FreeAndNil(MethodList);
  end;
end;

{$ELSE}

procedure TSmartMobileStudioTestSuite.AddTests(ATestClass: TTestCaseClass);
var
  Index: Integer;
  NameOfMethod : string;
  MethodEnumerator: TMethodEnumerator;
  TestCase: TTestCase;
  TestSuite: TTestSuite;
begin
  // call on the method enumerator to get the names of the test cases in the testClass
  MethodEnumerator := nil;
  try
    MethodEnumerator := TMethodEnumerator.Create(ATestClass);

    // make sure we add each test case to the list of tests
    for Index := 0 to MethodEnumerator.Methodcount - 1 do
      begin
        NameOfMethod := MethodEnumerator.NameOfMethod[Index];

        // eventually exclude the execution test for 'fail' scripts
        if (NameOfMethod <> 'TestCompilation') and (Pos('Fail', Self.Name) = 1) then
          Continue;

        TestCase := ATestClass.Create(NameOfMethod);
        (TestCase as TSmartMobileStudioCustomScriptTest).ScriptFileName := FScriptFileName;
        Self.AddTest(TestCase as ITest);
      end;
  finally
    MethodEnumerator.Free;
  end;
end;
{$ENDIF}

procedure EnumerateTests(Dir: string; Extension: string = '.dws');
var
  SuiteScript: TSmartMobileStudioTestSuite;
  TestProjectFiles: TStringList;
  FileName: TFileName;
begin
  TestProjectFiles := TStringList.Create;
  try
    // set tesst project directory
    if not DirectoryExists(Dir) then
      raise Exception.CreateFmt('Directory does not exists (%s)', [Dir]);

    CollectFiles(Dir, '*' + Extension, TestProjectFiles);

    for FileName in TestProjectFiles do
    begin
      SuiteScript := TSmartMobileStudioTestSuite.Create(ExtractRelativePath(Dir, FileName));
      SuiteScript.ScriptFileName := FileName;

      {$IFDEF FPC}
      SuiteScript.AddTestSuiteFromClass(TSmartMobileStudioExternalCompiler);
      {$ELSE}
      SuiteScript.AddTests(TSmartMobileStudioExternalCompiler);
      RegisterTest(SuiteScript);
      {$ENDIF}
    end;
  finally
    TestProjectFiles.Free;
  end;
end;

procedure InitializeTests;
begin
  EnumerateTests(CUnitTestPath + 'Success', '.dws');
  EnumerateTests(CUnitTestPath + 'Success', '.sproj');
  EnumerateTests(CUnitTestPath + 'Fail');
end;

initialization
  InitializeTests;

end.
