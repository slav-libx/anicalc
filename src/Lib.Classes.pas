unit Lib.Classes;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.UIConsts,
  System.Classes,
  System.Generics.Collections,
  System.Math,
  FMX.Types,
  FMX.Ani,
  FMX.Graphics,
  FMX.Objects,
  Lib.Files;

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
    destructor Destroy; override;
    procedure SetBitmap(B: TBitmap);
    procedure ReleaseBitmap;
    function Empty: Boolean;
    function Loaded: Boolean;
    procedure Loading;
    function ToString: string; override;
    property OnRead: TNotifyEvent read FOnRead write FOnRead;
  end;

  TPictureQueue = TThreadedQueue<TPicture>;

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

  TPictureList = class(TObjectList<TPicture>)
  private const
    PICTURES_MARGIN = 10;
  private
    FFeedMode: Boolean;
    FSize: TPointF;
    Cache: TList<TPicture>;
    PictureReader: TPictureReader;
    procedure AddPicture(const PictureFileName: string);
    procedure ToCache(Picture: TPicture);
    procedure OnPictureRead(Sender: TObject);
    procedure OnPicturePaint(Sender: TObject; Canvas: TCanvas; const ARect: TRectF);
  public
    constructor Create;
    destructor Destroy; override;
    procedure ReadDirectory(const Directory: string);
    function PictureOf(PictureIndex: Integer): TPicture;
    function AtPoint(const Point: TPointF): TPicture;
    function IndexAtPoint(const Point: TPointF): Integer;
    procedure Placement(FeedMode: Boolean; const PaddingRect: TRectF; const PageSize: TPointF);
    property FeedMode: Boolean read FFeedMode;
    property Size: TPointF read FSize;
  end;

implementation

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

destructor TPicture.Destroy;
begin
  inherited;
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

  TThread.Synchronize(nil,procedure
  begin

    BeginUpdate;

    Opacity:=0;

    Fill.Bitmap.Bitmap:=B;
    Fill.Kind:=TBrushKind.Bitmap;

    State:=StateLoaded;

    TAnimator.AnimateFloat(Self,'Opacity',0.8);

    EndUpdate;

  end);

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

    Picture.SetBitmap(B);

    B.Free;

  end;

end;

{ TPictureList }

constructor TPictureList.Create;
begin
  inherited Create(True);
  Cache:=TList<TPicture>.Create;
  PictureReader:=TPictureReader.Create;
  PictureReader.Start;
end;

destructor TPictureList.Destroy;
begin
  PictureReader.DoShutDown;
  Cache.Free;
  inherited;
end;

function TPictureList.PictureOf(PictureIndex: Integer): TPicture;
begin
  if InRange(PictureIndex,0,Count-1) then
    Result:=Items[PictureIndex]
  else
    Result:=nil;
end;

function TPictureList.AtPoint(const Point: TPointF): TPicture;
begin

  Result:=nil;

  for var Picture in Self do
  if Picture.BoundsRect.Contains(Point) then Exit(Picture);

end;

function DistanceRect(const R: TRectF; const P: TPointF): Single;
begin
  if R.Contains(P) then
    Result:=0
  else
    Result:=R.CenterPoint.Distance(P)-R.Width/2;
end;

function TPictureList.IndexAtPoint(const Point: TPointF): Integer;
var D,Distance: Single;
begin

  Result:=-1;

  for var I:=0 to Count-1 do
  begin
    Distance:=DistanceRect(Items[I].BoundsRect,Point);
    if (I=0) or (Distance<D) then Result:=I;
    D:=Distance;
  end;

end;

procedure TPictureList.Placement(FeedMode: Boolean; const PaddingRect: TRectF; const PageSize: TPointF);
var PageRect,PageBounds,PictureRect: TRectF;
begin

  FFeedMode:=FeedMode;

  PageRect:=TRectF.Create(PaddingRect.TopLeft,PageSize.X,PageSize.Y-
    PaddingRect.Top-PaddingRect.Bottom);

  for var Picture in Self do
  begin

    PictureRect:=RectF(0,0,Picture.BitmapSize.X,Picture.BitmapSize.Y).
      PlaceInto(PageRect,THorzRectAlign.Center,TVertRectAlign.Center);

    if FeedMode then
    begin
      PictureRect.SetLocation(PageRect.Left,PictureRect.Top);
      PageBounds:=PageRect.CenterAt(PictureRect);
      PageRect.SetLocation(PictureRect.Right+PICTURES_MARGIN,PageRect.Top);
    end else begin
      PageBounds:=PageRect;
      PageRect.Offset(PageRect.Width+PICTURES_MARGIN,0)
    end;

    Picture.BoundsRect:=PictureRect.SnapToPixel(0);
    Picture.PageBounds:=PageBounds;

  end;

  FSize:=PointF(PageRect.Left-PICTURES_MARGIN,PageRect.Bottom)+PaddingRect.BottomRight;

end;

procedure TPictureList.ToCache(Picture: TPicture);
begin

  if (Picture=nil) or ((Cache.Count>0) and (Cache.Last=Picture)) then Exit;

  Cache.Remove(Picture);
  Cache.Add(Picture);

  while (Cache.Count>20) and Cache[0].Loaded do
  begin
    Cache[0].ReleaseBitmap;
    Cache.Delete(0);
  end;

end;

function ReadImageSize(const PictureFileName: string; out ImageSize: TPointF): Boolean;
begin

  ImageSize:=TBitmapCodecManager.GetImageSize(PictureFileName);

  Result:=(ImageSize.X>0) and (ImageSize.Y>0); // is valid picture file

end;

procedure TPictureList.AddPicture(const PictureFileName: string);
var
  P: TPicture;
  ImageSize: TPointF;
begin

  if ReadImageSize(PictureFileName,ImageSize) then
  begin

    P:=TPicture.Create(nil);

    P.BitmapSize:=ImageSize;
    P.PictureIndex:=Count;
    P.PictureFileName:=PictureFileName;
    //P.OnRead:=OnPictureRead;
    P.OnPaint:=OnPicturePaint;

    Add(P);

  end;

end;

procedure TPictureList.ReadDirectory(const Directory: string);
begin
  for var F in GetFiles(Directory,False) do AddPicture(F);
end;

procedure TPictureList.OnPictureRead(Sender: TObject);
begin

  var Picture:=TPicture(Sender);

  //PictureReader.Push(PictureOf(Picture.PictureIndex-1));
  PictureReader.Push(Picture);
  //PictureReader.Push(PictureOf(Picture.PictureIndex+1));

  ToCache(Picture);

end;

procedure TPictureList.OnPicturePaint(Sender: TObject; Canvas: TCanvas; const ARect: TRectF);
var R: TRectF;
begin

  var Picture:=TPicture(Sender);

  PictureReader.Push(Picture);
  //PictureReader.Push(PictureOf(Picture.PictureIndex-1));
  //PictureReader.Push(PictureOf(Picture.PictureIndex+1));

  ToCache(Picture);

end;

end.
