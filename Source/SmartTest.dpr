program SmartTest;

{$IFDEF CONSOLE_TESTRUNNER}
{$APPTYPE CONSOLE}
{$ENDIF}

uses
  DUnitTestRunner,
  System.Classes,
  System.SysUtils,
  {$IFNDEF CONSOLE_TESTRUNNER}
  System.UITypes,
  VCL.Dialogs,
  {$ENDIF}
  SmartTest.Common in 'SmartTest.Common.pas',
  SmartTest.PipedExecution in 'SmartTest.PipedExecution.pas',
  SmartTest.SMSC in 'SmartTest.SMSC.pas';

{$R *.RES}

begin
  {$IFDEF CONSOLE_TESTRUNNER}
  // check whether the command-line compiler is available
  if not FileExists('smsc.exe') then
  begin
    Writeln('SMSC.EXE is missing!');
    Exit;
  end;

  // check whether node.js is present
  if not (Pos('v', RunExecutable('node -v')) = 1) then
  begin
    Writeln('Node.js does not seem to be available!')
    Exit;
  end;

  {$ELSE}

  // continously check for the availability of the command-line compiler
  while not FileExists('smsc.exe') do
    if MessageDlg('The command-line compiler ''smsc.exe'' is missing in the ' +
      'current directory!', mtError, [mbAbort, mbRetry], 0) = mrAbort then
        Exit;

  // check whether node.js is present
  if not (Pos('v', RunExecutable('node.exe -v')) = 1)  then
    if MessageDlg('Node.js does not seem to be available. Most probably the ' +
      'execution tests won''t work as expected', mtError, [mbAbort, mbOK], 0) = mrAbort then
        Exit;
  {$ENDIF}

  DUnitTestRunner.RunRegisteredTests;
end.
