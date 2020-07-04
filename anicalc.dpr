program anicalc;

uses
  System.StartUpCopy,
  FMX.Forms,
  Form.Main in 'src\Form.Main.pas' {MainForm},
  Lib.Classes in 'src\Lib.Classes.pas',
  Lib.Files in 'src\Lib.Files.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown:=True;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
