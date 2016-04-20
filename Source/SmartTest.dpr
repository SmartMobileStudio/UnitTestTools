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
  if not FileExists('smsc.exe') then
  begin
    Writeln('SMSC.EXE is missing!');
    Exit;
  end;
  {$ELSE}
  while not FileExists('smsc.exe') do
    if MessageDlg('The command-line compiler ''smsc.exe'' is missing in the ' +
      'current directory!', mtError, [mbAbort, mbRetry], 0) = mrAbort then
        Exit;
  {$ENDIF}

  DUnitTestRunner.RunRegisteredTests;
end.
