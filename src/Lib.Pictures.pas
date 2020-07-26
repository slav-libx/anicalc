unit Lib.Pictures;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.UIConsts,
  System.Classes,
  System.Generics.Collections,
  System.Math,
  System.IOUtils,
  FMX.Types,
  FMX.Graphics,
  FMX.Objects,
  Lib.Log,
  Lib.Files,
  Lib.Classes;

type

  TPicture = class(TView)
  public
    PictureFileName: string;
    procedure SetBitmap(B: TBitmap);
    procedure ReleaseBitmap;
    function ToString: string; override;
  end;

  TTextView = class(TView)
  private
    Text: TText;
  public
    constructor Create(AOwner: TComponent); override;
    function ToString: string; override;
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

  TPictureList = class(TViewList)
  private const
    PICTURES_MARGIN = 10;
  protected
    Headers: TObjectList<TTextView>;
    Cache: TList<TPicture>;
    PictureReader: TPictureReader;
    procedure AddPicture(const PictureFileName: string);
    procedure ToCache(Picture: TPicture);
    procedure OnPictureRead(Sender: TObject);
    procedure OnPicturePaint(Sender: TObject; Canvas: TCanvas; const ARect: TRectF);
    procedure PlacementSingle(const PaddingRect: TRectF; const PageSize,ViewSize: TPointF);
    procedure PlacementFeed(const PaddingRect: TRectF; const PageSize,ViewSize: TPointF);
    procedure PlacementTumbs(const PaddingRect: TRectF; const PageSize,ViewSize: TPointF);
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure ReadDirectory(const Directory: string);
    procedure Placement(const PaddingRect: TRectF; const PageSize,ViewSize: TPointF); override;
  end;

implementation

{ TPicture }

procedure TPicture.SetBitmap(B: TBitmap);
begin

  TThread.Synchronize(nil,procedure
  begin

    BeginUpdate;

    Opacity:=0;

    Fill.Bitmap.Bitmap:=B;

    State:=StateLoaded;

    Fill.Kind:=TBrushKind.Bitmap;

    ShowAnimated;

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

function TPicture.ToString: string;
begin
  Result:=PictureFilename+' ('+
    Fill.Bitmap.Bitmap.Width.ToString+' x '+
    Fill.Bitmap.Bitmap.Height.ToString+')';
end;

{ TTextView }

constructor TTextView.Create(AOwner: TComponent);
begin
  inherited;
  Text:=TText.Create(Self);
  Text.Parent:=Self;
  Text.Align:=TAlignLayout.Client;
end;

function TTextView.ToString: string;
begin
  Result:=Text.Text;
end;

{ TPictureReader }

constructor TPictureReader.Create;
begin
  Queue:=TPictureQueue.Create(1000);
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
    ToLog('push '+Picture.PictureFileName);
    Picture.Loading;
    Queue.PushItem(Picture);
    ToLog('pushed '+Picture.PictureFileName);
  end;
end;

procedure TPictureReader.Execute;
begin

  while not Terminated do
  begin

    var Picture:=Queue.PopItem;

    if Queue.ShutDown then Break;

    ToLog('read '+Picture.PictureFileName);

    var B:=TBitmap.CreateFromFile(Picture.PictureFileName);

    ToLog('set bitmap '+Picture.PictureFileName);

    Picture.SetBitmap(B);

    B.Free;

  end;

end;

{ TPictureList }

function MaxPoint(const P1,P2: TPointF): TPointF;
begin
  Result.X:=Max(P1.X,P2.X);
  Result.Y:=Max(P1.Y,P2.Y);
end;

constructor TPictureList.Create;
begin
  inherited;
  Headers:=TObjectList<TTextView>.Create(False);
  Cache:=TList<TPicture>.Create;
  PictureReader:=TPictureReader.Create;
  PictureReader.Start;
end;

destructor TPictureList.Destroy;
begin
  Headers.Free;
  PictureReader.DoShutDown;
  Cache.Free;
  inherited;
end;

procedure TPictureList.PlacementSingle(const PaddingRect: TRectF; const PageSize,ViewSize: TPointF);
var PageRect,ViewRect: TRectF;
begin

  PageRect:=TRectF.Create(PaddingRect.TopLeft,PageSize.X,PageSize.Y-
    PaddingRect.Top-PaddingRect.Bottom);

  FSize:=PageRect.BottomRight;

  for var View in Self do
  begin

    ViewRect:=RectF(0,0,View.SourceSize.X,View.SourceSize.Y).
      PlaceInto(PageRect,THorzRectAlign.Center,TVertRectAlign.Center);

    View.ViewBounds:=ViewRect.SnapToPixel(0);
    View.PageBounds:=PageRect;
    View.PageBounds.Inflate(0,PaddingRect.Top,0,PaddingRect.Bottom);
    View.Viewport:=MaxPoint(View.PageBounds.TopLeft,TPointF.Zero);

    FSize.X:=Max(FSize.X,PageRect.Right);
    FSize.Y:=Max(FSize.Y,PageRect.Bottom);

    PageRect.Offset(PageRect.Width+PICTURES_MARGIN,0);

  end;

  FSize:=FSize+PaddingRect.BottomRight;

end;

procedure TPictureList.PlacementFeed(const PaddingRect: TRectF; const PageSize,ViewSize: TPointF);
var
  PageRect,PageBounds,PictureRect,ViewRect: TRectF;
begin

  PageRect:=TRectF.Create(PaddingRect.TopLeft,PageSize.X,PageSize.Y-
    PaddingRect.Top-PaddingRect.Bottom);

  FSize:=PageRect.BottomRight;

  for var View in Self do
  begin

    ViewRect:=RectF(0,0,ViewSize.X,ViewSize.Y).
      PlaceInto(PageRect,THorzRectAlign.Center,TVertRectAlign.Center);

    PictureRect:=RectF(0,0,View.SourceSize.X,View.SourceSize.Y).
      PlaceInto(ViewRect,THorzRectAlign.Center,TVertRectAlign.Center);

    PictureRect.SetLocation(PageRect.Left,PictureRect.Top);
    PageBounds:=PageRect.CenterAt(PictureRect);
    PageRect.SetLocation(PictureRect.Right,PageRect.Top);

    View.ViewBounds:=PictureRect.SnapToPixel(0);
    View.PageBounds:=PageBounds;
    View.PageBounds.Inflate(0,PaddingRect.Top,0,PaddingRect.Bottom);
    View.Viewport:=MaxPoint(View.PageBounds.TopLeft,TPointF.Zero);

    FSize.X:=Max(FSize.X,PageRect.Left);
    FSize.Y:=Max(FSize.Y,PageBounds.Bottom);

    PageRect.Offset(PICTURES_MARGIN,0);

  end;

  FSize:=FSize+PaddingRect.BottomRight;

  for var View in Self do
  if View is TPicture then
    View.Viewport.X:=Min(View.Viewport.X,FSize.X-PageSize.X);

end;

procedure TPictureList.PlacementTumbs(const PaddingRect: TRectF; const PageSize,ViewSize: TPointF);
var
  PageRect,ShowRect,ViewRect: TRectF;
  Group: string;
  Text: TTextView;
begin

  PageRect:=TRectF.Create(PointF(0,0),PageSize.X,PageSize.Y);

  ViewRect:=TRectF.Create(PaddingRect.TopLeft,ViewSize.X,ViewSize.Y);

  ViewRect.Offset(0,-ViewRect.Height);

  FSize:=PageRect.BottomRight-PaddingRect.BottomRight;

  Group:='';

  for var View in Self do
  if View is TPicture then
  begin

    if Group<>View.Group then
    begin
//      Text:=TTextView.Create(nil);
//      Text.Text.Text:=View.Group;
//      Text.BoundsRect:=TRectF.Create(PointF(PaddingRect.Left,ViewRect.Bottom),PageSize.X-PaddingRect.Right-PaddingRect.Left,30);
//      Headers.Add(Text);
      ViewRect.SetLocation(PaddingRect.Left,ViewRect.Bottom+30);
    end;

    Group:=View.Group;

    ShowRect:=RectF(0,0,View.SourceSize.X,View.SourceSize.Y).
      PlaceInto(ViewRect,THorzRectAlign.Left,TVertRectAlign.Center);

    if ShowRect.Right+PaddingRect.Right>PageSize.X then
    begin
      ViewRect.SetLocation(PaddingRect.Left,ViewRect.Bottom+PICTURES_MARGIN);
      ShowRect:=ShowRect.PlaceInto(ViewRect,THorzRectAlign.Left,TVertRectAlign.Center);
    end;

    View.ViewBounds:=ShowRect.SnapToPixel(0);
    View.PageBounds:=PageRect.CenterAt(ShowRect);
    View.Viewport:=PointF(0,Max(0,View.PageBounds.Top));

    FSize.X:=Max(FSize.X,ShowRect.Right);
    FSize.Y:=Max(FSize.Y,ViewRect.Bottom);

    ViewRect.SetLocation(ShowRect.Right+PICTURES_MARGIN,ViewRect.Top);

  end;

  FSize:=FSize+PaddingRect.BottomRight;

  for var View in Self do
  if View is TPicture then
    View.Viewport.Y:=Min(View.Viewport.Y,FSize.Y-PageSize.Y);

end;

procedure TPictureList.Placement(const PaddingRect: TRectF; const PageSize,ViewSize: TPointF);
begin

  Headers.Clear;

  case ViewMode of
  vmSingle: PlacementSingle(PaddingRect,PageSize,ViewSize);
  vmFeed: PlacementFeed(PaddingRect,PageSize,ViewSize);
  vmTumbs: PlacementTumbs(PaddingRect,PageSize,ViewSize);
  end;

  for var Header in Headers do Add(Header);

end;

procedure TPictureList.ToCache(Picture: TPicture);
var CacheSize: Integer;
begin

  if (Picture=nil) or ((Cache.Count>0) and (Cache.Last=Picture)) then Exit;

  if ViewMode=vmTumbs then
    CacheSize:=100
  else
    CacheSize:=100;//20;

  Cache.Remove(Picture);
  Cache.Add(Picture);

  while (Cache.Count>CacheSize) and Cache[0].Loaded do
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

    P.SourceSize:=ImageSize;
    P.ViewIndex:=Count;
    P.PictureFileName:=PictureFileName;
    P.Group:=System.IOUtils.TPath.GetDirectoryName(PictureFileName);
    P.OnRead:=OnPictureRead;
    //P.OnPaint:=OnPicturePaint;

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
begin

  var Picture:=TPicture(Sender);

  PictureReader.Push(Picture);
  //PictureReader.Push(PictureOf(Picture.PictureIndex-1));
  //PictureReader.Push(PictureOf(Picture.PictureIndex+1));

  ToCache(Picture);

end;

end.
