unit Lib.Log;

interface

uses
  System.IOUtils,
  System.SysUtils,
  System.SyncObjs,
  System.Classes,
  System.DateUtils;

procedure InitLog(const LogDirectory: string);
procedure ToLog(const LogName,Text: string); overload;
procedure ToLog(const Text: string); overload;

implementation

const
  LOG_EXT = '.log';

var
  Lock: TCriticalSection;
  Directory: string='';

function DateTimeToString(DateTime: TDateTime): string; inline;
begin
  Result:=FormatDateTime('dd.mm.yyyy hh:nn:ss.zzz',DateTime);
end;

procedure AppendAllText(const Path,Contents: string);
begin
  TFile.AppendAllText(Path,Contents+#13#10,TEncoding.UTF8);
end;

procedure InitLog(const LogDirectory: string);
begin
  Directory:=LogDirectory;
  if Directory<>'' then TDirectory.CreateDirectory(Directory);
end;

procedure ToLog(const LogName,Text: string);
begin

  if Directory='' then Exit;

  Lock.Enter;
  try
    AppendAllText(TPath.Combine(Directory,LogName+LOG_EXT),'['+DateTimeToString(Now)+'] '+Text);
  finally
    Lock.Leave;
  end;

end;

procedure ToLog(const Text: string);
begin
  ToLog('app',Text);
end;


initialization

  Lock:=TCriticalSection.Create;

finalization

  Lock.Free;

end.
