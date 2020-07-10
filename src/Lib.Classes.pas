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
  FMX.Graphics,
  FMX.Objects,
  FMX.Ani,
  FMX.Utils,
  FMX.Controls,
  Lib.Ani;

type

  TView = class(TRectangle)
  protected
    State: (StateEmpty,StateLoading,StateLoaded);
  protected
    FOnRead: TNotifyEvent;
    procedure AfterPaint; override;
    procedure Animate(Time: Single);
  public
    StartBounds: TRectF;
    ViewBounds: TRectF;
    PageBounds: TRectF;
    SourceSize: TPointF;
    Group: string;
    ViewIndex: Integer;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function Empty: Boolean;
    function Loaded: Boolean;
    procedure Loading;
    function ToString: string; override;
    property OnRead: TNotifyEvent read FOnRead write FOnRead;
  end;

  TViewMode = (vmSingle,vmFeed,vmTumbs);

  TViewList = class(TObjectList<TView>)
  protected
    FViewMode: TViewMode;
    FSize: TPointF;
    FTick: TTickObject;
    procedure OnTickProcess(Sender: TObject);
  public
    constructor Create; virtual;
    destructor Destroy; override;
    function ViewOf(ViewIndex: Integer): TView;
    function AtPoint(const Point: TPointF): TView;
    function IndexAtPoint(const Point: TPointF): Integer;
    procedure Placement(const PaddingRect: TRectF; const PageSize,ViewSize: TPointF); virtual; abstract;
    procedure Save;
    procedure Apply(Animated: Boolean);
    property ViewMode: TViewMode read FViewMode write FViewMode;
    property Size: TPointF read FSize write FSize;
  end;

implementation

{ TView }

constructor TView.Create(AOwner: TComponent);
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

destructor TView.Destroy;
begin
  inherited;
end;

procedure TView.AfterPaint;
begin
  inherited;
  if Empty and Assigned(FOnRead) then FOnRead(Self);
end;

function TView.ToString: string;
begin
  Result:='View '+ViewIndex.ToString;
end;

function TView.Empty: Boolean;
begin
  Result:=State=StateEmpty;
end;

function TView.Loaded: Boolean;
begin
  Result:=State=StateLoaded;
end;

procedure TView.Loading;
begin
  State:=StateLoading;
end;

procedure TView.Animate(Time: Single);
var R: TRectF;
begin

  R.Left:=InterpolateSingle(StartBounds.Left,ViewBounds.Left,Time);
  R.Top:=InterpolateSingle(StartBounds.Top,ViewBounds.Top,Time);
  R.Right:=InterpolateSingle(StartBounds.Right,ViewBounds.Right,Time);
  R.Bottom:=InterpolateSingle(StartBounds.Bottom,ViewBounds.Bottom,Time);

  BoundsRect:=R;

end;

{ TViewList }

constructor TViewList.Create;
begin
  inherited Create(True);

  FTick:=TTickObject.Create(True);
  FTick.Duration:=1;//2.5;
  FTick.OnProcess:=OnTickProcess;
  FTick.StopOnEvent:=True;

end;

destructor TViewList.Destroy;
begin
  FTick.Free;
  inherited;
end;

procedure TViewList.OnTickProcess(Sender: TObject);
var Time: Single;
begin
  Time:=InterpolateLinear(Ftick.Time,0,1,FTick.Duration);
  for var View in Self do View.Animate(Time);
end;

function TViewList.ViewOf(ViewIndex: Integer): TView;
begin
  if InRange(ViewIndex,0,Count-1) then
    Result:=Items[ViewIndex]
  else
    Result:=nil;
end;

function TViewList.AtPoint(const Point: TPointF): TView;
begin

  Result:=nil;

  for var View in Self do
  if View.BoundsRect.Contains(Point) then Exit(View);

end;

function DistanceToRect(const R: TRectF; const P: TPointF): Single;
begin
  if R.Contains(P) then
    Result:=0
  else
    Result:=R.CenterPoint.Distance(P)-R.Width/2;
end;

function TViewList.IndexAtPoint(const Point: TPointF): Integer;
var D,Distance: Single;
begin

  Result:=-1;

  for var I:=0 to Count-1 do
  begin

    Distance:=DistanceToRect(Items[I].BoundsRect,Point);

    if Distance=0 then
      Exit(I)
    else

    if (I=0) or (Distance<D) then
    begin
      Result:=I;
      D:=Distance;
    end;

  end;

end;

function ToAbsoluteRect(const R: TRectF; Control: TControl): TRectF;
begin
  Result.Topleft:=Control.LocalToAbsolute(R.TopLeft);
  Result.BottomRight:=Control.LocalToAbsolute(R.BottomRight);
end;

function ToLocalRect(const R: TRectF; Control: TControl): TRectF;
begin
  Result.TopLeft:=Control.AbsoluteToLocal(R.TopLeft);
  Result.BottomRight:=Control.AbsoluteToLocal(R.BottomRight);
end;

procedure TViewList.Save;
begin
  for var View in Self do
  View.StartBounds:=ToAbsoluteRect(View.BoundsRect,View.ParentControl);
end;

procedure TViewList.Apply(Animated: Boolean);
begin

  if Animated then
  begin

    for var View in Self do View.StartBounds:=ToLocalRect(View.StartBounds,View.ParentControl);

    FTick.Restart(True);

  end else

    for var View in Self do View.BoundsRect:=View.ViewBounds;

end;

end.
