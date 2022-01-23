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

  TView = class(TControl)
  protected
    State: (StateEmpty,StateLoading,StateLoaded);
  protected
    FOnRead: TNotifyEvent;
    procedure AfterPaint; override;
    procedure Animate(Time: Single);
    procedure StartAnimation;
    procedure StopAnimation;
    procedure ShowAnimated;
  public type
    TAnimationType = (atProcess,atStart,atStop);
  public
    Viewport: TPointF;
    StartBounds: TRectF;
    ViewBounds: TRectF;
    PageBounds: TRectF;
    SourceSize: TPointF;
    Group: string;
    ViewIndex: Integer;
    AnimationType: TAnimationType;
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
    FAnimation: TTickObject;
    procedure OnAnimationProcess(Sender: TObject);
    procedure OnAnimationEvent(Sender: TObject);
  public
    constructor Create; virtual;
    destructor Destroy; override;
    function ViewOf(ViewIndex: Integer): TView;
    function AtPoint(const Point: TPointF): TView;
    function IndexAtPoint(const Point: TPointF): Integer;
    procedure Placement(const PaddingRect: TRectF; const PageSize,ViewSize: TPointF); virtual; abstract;
    procedure SetViewsAnimationType(AnimationType: TView.TAnimationType);
    procedure Save;
    procedure Apply(Animated: Boolean);
    property ViewMode: TViewMode read FViewMode write FViewMode;
    property Size: TPointF read FSize write FSize;
  end;

implementation

const
  VIEW_OPACITY = 0.8;

{ TView }

constructor TView.Create(AOwner: TComponent);
begin
  inherited;

//  Fill.Bitmap.WrapMode:=TWrapMode.TileStretch;
//  Fill.Kind:=TBrushKind.None;
//  Fill.Color:=claSilver;
//
//  Stroke.Kind:=TBrushKind.None;
//  Stroke.Thickness:=0;

//  HitTest:=False;
  Opacity:=VIEW_OPACITY;

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

function InterpolateRect(const StartRect,StopRect: TRectF; Time: Single): TRectF;
begin
  Result.Left:=InterpolateSingle(StartRect.Left,StopRect.Left,Time);
  Result.Top:=InterpolateSingle(StartRect.Top,StopRect.Top,Time);
  Result.Right:=InterpolateSingle(StartRect.Right,StopRect.Right,Time);
  Result.Bottom:=InterpolateSingle(StartRect.Bottom,StopRect.Bottom,Time);
end;

function Animating(Target: TFmxObject): Boolean;
begin
  for var I:=0 to Target.ChildrenCount-1 do
  if Target.Children[I] is TCustomPropertyAnimation then Exit(True);
  Result:=False;
end;

procedure TView.StartAnimation;
begin
  case AnimationType of
  atStart: BoundsRect:=ViewBounds;
  atStop: BoundsRect:=StartBounds;
  end;
end;

procedure TView.StopAnimation;
begin
  BoundsRect:=ViewBounds;
  if Loaded and not Animating(Self) then Opacity:=VIEW_OPACITY;
end;

procedure TView.Animate(Time: Single);
begin

  case AnimationType of
  atProcess:
    BoundsRect:=InterpolateRect(StartBounds,ViewBounds,Time);
  atStop:
    if Loaded and not Animating(Self) then
      Opacity:=InterpolateSingle(VIEW_OPACITY,0,Time);
  atStart:
    if Loaded and not Animating(Self) then
      Opacity:=InterpolateSingle(0,VIEW_OPACITY,Time);
  end;

end;

procedure TView.ShowAnimated;
begin
  TAnimator.AnimateFloat(Self,'Opacity',VIEW_OPACITY);
end;

{ TViewList }

constructor TViewList.Create;
begin
  inherited Create(True);

  FAnimation:=TTickObject.Create(True);
  FAnimation.Duration:=0.2;//2.5;
  FAnimation.OnProcess:=OnAnimationProcess;
  FAnimation.OnEvent:=OnAnimationEvent;
  FAnimation.StopOnEvent:=True;

end;

destructor TViewList.Destroy;
begin
  FAnimation.Free;
  inherited;
end;

procedure TViewList.OnAnimationProcess(Sender: TObject);
var Time: Single;
begin

  Time:=InterpolateLinear(FAnimation.Time,0,1,FAnimation.Duration);

  for var View in Self do View.Animate(Time);

end;

procedure TViewList.OnAnimationEvent(Sender: TObject);
begin
  for var View in Self do View.StopAnimation;
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

    for var View in Self do
    begin

      View.StartBounds:=ToLocalRect(View.StartBounds,View.ParentControl);

//      if ViewMode=vmFeed then
//      if View.AnimationType=atProcess then
//      View.StartBounds.SetLocation(0,0);
      View.StartAnimation;
    end;

    FAnimation.Restart(True);

  end else

    for var View in Self do View.StopAnimation;

end;

procedure TViewList.SetViewsAnimationType(AnimationType: TView.TAnimationType);
begin
  for var View in Self do View.AnimationType:=AnimationType;
end;

end.
