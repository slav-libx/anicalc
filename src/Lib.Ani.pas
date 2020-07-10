unit Lib.Ani;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Math,
  System.Generics.Collections,
  FMX.Types;

type

  TTickObject = class
  public class var
    FrameRate: Integer;
  private class var
    FTimer: TTimer;
  private
    FName: string;
    FDelay: Single;
    FDelayTime: Single;
    FDuration: Single;
    FTime: Single;
    FPaused: Boolean;
    FStarted: Boolean;
    FStopOnEvent: Boolean;
    FOnProcess: TNotifyEvent;
    FOnEvent: TNotifyEvent;
    class constructor Create;
    class destructor Destroy;
    class procedure CreateTimer;
  protected
    procedure ProcessTick(DeltaTime: Single); virtual;
    procedure DoProcess;
    procedure DoEvent;
    procedure DoStart; virtual;
    procedure SetStarted(Value: Boolean);
  public
    constructor Create(Suspended: Boolean);
    destructor Destroy; override;
    procedure Restart(StartStopped: Boolean=False);
    property OnProcess: TNotifyEvent read FOnProcess write FOnProcess;
    property OnEvent: TNotifyEvent read FOnEvent write FOnEvent;
    property Time: Single read FTime write FTime;
    property Duration: Single read FDuration write FDuration nodefault;
    property Delay: Single read FDelay write FDelay nodefault;
    property Paused: Boolean read FPaused write FPaused;
    property Started: Boolean read FStarted write SetStarted;
    property StopOnEvent: Boolean read FStopOnEvent write FStopOnEvent;
    property Name: string read FName write FName;
  end;

implementation

uses FMX.Platform;

type
  TTimerThread = class(TTimer)
  private
    FAniList: TList<TTickObject>;
    FTime: Extended;
    FTimerService: IFMXTimerService;
    procedure OneStep;
    procedure DoSyncTimer(Sender: TObject);
    procedure CalcInterval;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    procedure Add(const Ani: TTickObject);
    procedure Remove(const Ani: TTickObject);
  end;

procedure TTimerThread.CalcInterval;
begin
  if TTickObject.FrameRate < 5 then
    TTickObject.FrameRate := 5;
  if TTickObject.FrameRate > 100 then
    TTickObject.FrameRate := 100;
  Interval := Trunc(1000 / TTickObject.FrameRate / 10) * 10;
  if (Interval <= 0) then Interval := 1;
end;

constructor TTimerThread.Create;
begin
  inherited Create(nil);

  if not TPlatformServices.Current.SupportsPlatformService(IFMXTimerService,FTimerService) then
    raise EUnsupportedPlatformService.Create('IFMXTimerService');

  CalcInterval;

  OnTimer:=DoSyncTimer;
  FAniList:=TList<TTickObject>.Create;
  FTime:=FTimerService.GetTick;

  Enabled:=False;

end;

destructor TTimerThread.Destroy;
begin
  FreeAndNil(FAniList);
  FTimerService:=nil;
  inherited;
end;

procedure TTimerThread.Add(const Ani: TTickObject);
begin
  if FAniList.IndexOf(Ani)<0 then
    FAniList.Add(Ani);
  if not Enabled and (FAniList.Count>0) then
    FTime:=FTimerService.GetTick;
  Enabled:=FAniList.Count>0;
end;

procedure TTimerThread.Remove(const Ani: TTickObject);
begin
  FAniList.Remove(Ani);
  Enabled:=FAniList.Count>0;
end;

procedure TTimerThread.DoSyncTimer(Sender: TObject);
begin
  OneStep;
  CalcInterval;
end;

procedure TTimerThread.OneStep;
var
  I: Integer;
  DeltaTime: Extended;
begin

  DeltaTime:=FTime;
  FTime:=FTimerService.GetTick;
  DeltaTime:=FTime-DeltaTime;

  if DeltaTime<=0 then Exit;

  I:=FAniList.Count-1;

  while I>=0 do
  begin
    if FAniList[I].FDelayTime<FAniList[I].Delay then
      FAniList[I].FDelayTime:=FAniList[I].FDelayTime+DeltaTime
    else
    if FAniList[I].Started and not FAniList[I].Paused then
      FAniList[I].ProcessTick(DeltaTime);
    Dec(I);
    if I>=FAniList.Count then
      I:=FAniList.Count-1;
  end;

end;

function GetAniTime: Extended;
begin
  TTickObject.CreateTimer;
  Result:=TTimerThread(TTickObject.FTimer).FTime;
end;

class constructor TTickObject.Create;
begin
  FrameRate:=60;
end;

class destructor TTickObject.Destroy;
begin
  FreeAndNil(FTimer);
end;

class procedure TTickObject.CreateTimer;
begin
  if FTimer=nil then
    FTimer:=TTimerThread.Create;
end;

constructor TTickObject.Create(Suspended: Boolean);
begin
  FDelay:=0;
  FPaused:=False;
  FStopOnEvent:=False;
  FStarted:=not Suspended;
  CreateTimer;
  TTimerThread(FTimer).Add(Self);
end;

destructor TTickObject.Destroy;
begin
  if FTimer<>nil then
    TTimerThread(FTimer).Remove(Self);
  inherited;
end;

procedure TTickObject.SetStarted(Value: Boolean);
begin
  if FStarted<>Value then
  begin
    FStarted:=Value;
    if Started then
    begin
      Paused:=False;
      DoStart;
    end;
  end;
end;

procedure TTickObject.DoStart;
begin
  FDelayTime:=0;
  FTime:=0;
end;

procedure TTickObject.DoProcess;
begin
  if Assigned(FOnProcess) then FOnProcess(Self);
end;

procedure TTickObject.DoEvent;
begin
  if Assigned(FOnEvent) then FOnEvent(Self);
end;

procedure TTickObject.ProcessTick(DeltaTime: Single);
begin

  FTime:=FTime+DeltaTime;

  if FTime>=FDuration then
  begin
    FTime:=FDuration;
    DoProcess;
    if StopOnEvent then Started:=False;
    DoEvent;
    if Started then FTime:=0;
  end else
    DoProcess;

end;

procedure TTickObject.Restart(StartStopped: Boolean=False);
begin
  if Started then DoStart
  else Started:=StartStopped
end;

end.

