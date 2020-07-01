program anicalc;

uses
  System.StartUpCopy,
  FMX.Forms,
  FormMain in 'src\FormMain.pas' {MainForm},
  Lib.Classes in 'src\Lib.Classes.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown:=True;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
