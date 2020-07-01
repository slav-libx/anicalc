unit Lib.Classes;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.UIConsts,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  System.Permissions,
  FMX.Types,
  FMX.Ani,
  FMX.Graphics,
  FMX.Objects;

type
  TPicture = class(TRectangle)
  private
    State: (StateEmpty,StateLoading,StateLoaded);
  protected
    FOnRead: TNotifyEvent;
    procedure AfterPaint; override;
  public
    BitmapSize: TPointF;
    PageBounds: TRectF;
    PictureFileName: string;
    PictureIndex: Integer;
    constructor Create(AOwner: TComponent); override;
    procedure SetBitmap(B: TBitmap);
    procedure ReleaseBitmap;
    function Empty: Boolean;
    function Loaded: Boolean;
    procedure Loading;
    function ToString: string; override;
    property OnRead: TNotifyEvent read FOnRead write FOnRead;
  end;

  TPictureQueue = TThreadedQueue<TPicture>;

  TPictureList = TList<TPicture>;

  TPictureReader = class(TThread)
  private
    Queue: TPictureQueue;
  protected
    procedure Execute; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure DoShutDown;
    procedure Push(Picture: TPicture);
  end;

procedure RequestPermissionsExternalStorage(Proc: TProc<Boolean>);

implementation

{$IFDEF ANDROID}

uses
  Androidapi.Helpers, Androidapi.JNI.Os;

{$ENDIF}

{ TPicture }

constructor TPicture.Create(AOwner: TComponent);
begin
  inherited;

  Fill.Bitmap.WrapMode:=TWrapMode.TileStretch;
  Fill.Kind:=TBrushKind.None;
  Fill.Color:=claSilver;

  Stroke.Kind:=TBrushKind.None;
  Stroke.Thickness:=0;

  HitTest:=False;
  Opacity:=0.8;

end;

procedure TPicture.AfterPaint;
begin
  inherited;
  if Empty and Assigned(FOnRead) then FOnRead(Self);
end;

function TPicture.ToString: string;
begin
  Result:=PictureFilename+' ('+
    Fill.Bitmap.Bitmap.Width.ToString+' x '+
    Fill.Bitmap.Bitmap.Height.ToString+')';
end;

function TPicture.Empty: Boolean;
begin
  Result:=State=StateEmpty;
end;

function TPicture.Loaded: Boolean;
begin
  Result:=State=StateLoaded;
end;

procedure TPicture.Loading;
begin
  State:=StateLoading;
end;

procedure TPicture.SetBitmap(B: TBitmap);
begin

  BeginUpdate;

  Opacity:=0;

  Fill.Bitmap.Bitmap:=B;
  Fill.Kind:=TBrushKind.Bitmap;
  State:=StateLoaded;

  EndUpdate;

  TAnimator.AnimateFloat(Self,'Opacity',0.8);

end;

procedure TPicture.ReleaseBitmap;
begin

  BeginUpdate;

  Fill.Kind:=TBrushKind.None;
  Fill.Bitmap.Bitmap:=nil;
  State:=StateEmpty;

  EndUpdate;

end;

{ TPictureReader }

constructor TPictureReader.Create;
begin
  Queue:=TPictureQueue.Create;
  inherited Create(True);
  FreeOnTerminate:=True;
end;

destructor TPictureReader.Destroy;
begin
  Queue.Free;
end;

procedure TPictureReader.DoShutDown;
begin
  Queue.DoShutDown;
end;

procedure TPictureReader.Push(Picture: TPicture);
begin
  if Assigned(Picture) and Picture.Empty then
  begin
    Picture.Loading;
    Queue.PushItem(Picture);
  end;
end;

procedure TPictureReader.Execute;
begin

  while not Terminated do
  begin

    var Picture:=Queue.PopItem;

    if Queue.ShutDown then Break;

    var B:=TBitmap.CreateFromFile(Picture.PictureFileName);

    Synchronize(procedure
    begin
      Picture.SetBitmap(B);
    end);

    B.Free;

  end;

end;

procedure RequestPermissionsExternalStorage(Proc: TProc<Boolean>);
begin

  {$IFDEF ANDROID}

  var WRITE_EXTERNAL_STORAGE:=JStringToString(TJManifest_permission.JavaClass.WRITE_EXTERNAL_STORAGE);

  {$ELSE}

  var WRITE_EXTERNAL_STORAGE:='';

  {$ENDIF}

  PermissionsService.DefaultService.RequestPermissions([WRITE_EXTERNAL_STORAGE],
  procedure(const APermissions: TArray<string>; const AGrantResults: TArray<TPermissionStatus>)
  begin
    Proc((Length(AGrantResults)=1) and (AGrantResults[0]=TPermissionStatus.Granted));
  end);

end;

end.
