unit Form.Main;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.UIConsts,
  System.Classes,
  System.Math,
  System.IOUtils,
  FMX.Types,
  FMX.Ani,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  FMX.Dialogs,
  FMX.InertialMovement,
  FMX.Objects,
  Lib.Log,
  Lib.Classes,
  Lib.Pictures,
  Lib.Files,
  Lib.Animated;

type
  TMainForm = class(TForm)
    Rectangle2: TRectangle;
    Rectangle1: TRectangle;
    Rectangle4: TRectangle;
    Rectangle5: TRectangle;
    Rectangle6: TRectangle;
    ScrollContent: TRectangle;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Rectangle2MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure Rectangle2MouseLeave(Sender: TObject);
    procedure Rectangle2MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Single);
    procedure Rectangle2MouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure Rectangle2Paint(Sender: TObject; Canvas: TCanvas;
      const ARect: TRectF);
    procedure Rectangle2Resized(Sender: TObject);
    procedure Rectangle2MouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; var Handled: Boolean);
    procedure Rectangle2Gesture(Sender: TObject;
      const EventInfo: TGestureEventInfo; var Handled: Boolean);
    procedure Rectangle2Click(Sender: TObject);
    procedure Rectangle5Painting(Sender: TObject; Canvas: TCanvas;
      const ARect: TRectF);
  private const
    PhysicsProcessingInterval = 8; // 8 ms for ~120 frames per second
    HasPhysicsStretchyScrolling = True;
    PICTURES_MARGIN = 10;
  private type
    TAniScroll = class(TAniCalculations);
  private
    Ani: TTouchAnimation;
    FAniCalc: TAniScroll;
    ContentSize: TPointF;
    Views: TPictureList;
    CurrentView: TView;
    TumbsView: TView;
    TumbsViewport: TPointF;
    FLeave: Boolean;
    FDownPoint: TPointF;
    FScrollType: (stNone,stHScroll,stVScroll,stBoth);
    procedure AniCalcChange(Sender: TObject);
    procedure AniCalcStart(Sender: TObject);
    procedure AniCalcStop(Sender: TObject);
    procedure DoUpdateScrollingLimits;
    procedure LoadPictures;
    function AbsoluteCenterPoint: TPointF;
    function AbsolutePressedPoint: TPointF;
    function ViewAtPoint(const AbsolutePoint: TPointF): TView;
    function TryViewAtPoint(const AbsolutePoint: TPointF; out View: TView): Boolean;
    function ViewIndexAtPoint(const AbsolutePoint: TPointF): Integer;
    procedure ShowText(const Text: string);
    procedure PlacementPictures(Animated: Boolean);
    procedure ScrollToView(View: TView; Immediately: Boolean=False); overload;
    procedure ScrollToView(ViewIndex: Integer; Immediately: Boolean=False); overload;
    function GetScrollPoint(X,Y: Single): TPointF;
  public
  end;

var
  MainForm: TMainForm;

implementation

{$R *.fmx}

procedure TMainForm.FormCreate(Sender: TObject);
begin

  {$IFDEF MSWINDOWS}
  InitLog(System.IOUtils.TPath.GetLibraryPath);
  {$ENDIF}

  FAniCalc:=TAniScroll.Create(nil);

  FAniCalc.TouchTracking:=[ttVertical,ttHorizontal];
  FAniCalc.Animation:=True;
  FAniCalc.OnChanged:=AniCalcChange;
  FAniCalc.Interval:=PhysicsProcessingInterval; // как часто обновлять позицию по таймеру
  FAniCalc.OnStart:=AniCalcStart;
  FAniCalc.OnStop:=AniCalcStop;
  FAniCalc.BoundsAnimation:=HasPhysicsStretchyScrolling; // возможен ли выход за границы min-max (если определены min-max)
  FAniCalc.Elasticity:=200; // как быстро возвращать позицию в пределы min-max при выходе за границы (при отпускании пальца/мыши)
  FAniCalc.DecelerationRate:=3;//15;//10; // скорость замедления прокрутки после отпускании пальца/мыши
  FAniCalc.Averaging:=True;

  FAniCalc.AutoShowing:=True;
  FAniCalc.Shown:=False;
//  TAniCalculationsAccess(FAniCalc).StorageTime:=0.1;//1000;
  FAniCalc.DeadZone:=10; // смещение после которого происходит инициация анимации, работает только для жестов (не для мыши) если Averaging=True

  Views:=TPictureList.Create;

  Views.ViewMode:=vmTumbs;

  TumbsView:=CurrentView;
  TumbsViewport:=FAniCalc.ViewportPositionF;

  Ani:=TTouchAnimation.Create(Self);
  Ani.StartColor:=claNull;
  Ani.SelectedColor:=MakeColor(0,0,0,60);

  RequestPermissionsExternalStorage(
  procedure(Granted: Boolean)
  begin
    if Granted then LoadPictures;
  end);

end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  Views.Free;
  FAniCalc.Free;
end;

procedure TMainForm.PlacementPictures(Animated: Boolean);
var PageSize,ViewSize: TPointF;
begin

  if Views=nil then Exit;

  Ani.Cancel;

  if Views.ViewMode in [vmSingle,vmFeed] then
  if Rectangle2.Width>Rectangle2.Height*1.5 then
    Views.ViewMode:=vmFeed
  else
    Views.ViewMode:=vmSingle;

  PageSize:=Rectangle2.BoundsRect.BottomRight;

  if Views.ViewMode=vmTumbs then
    ViewSize:=PointF(PageSize.X-ScrollContent.Padding.Rect.Left-ScrollContent.Padding.Rect.Right,Round(Max(PageSize.Y,PageSize.X)/5))
  else
    ViewSize:=PageSize;

  ScrollContent.BeginUpdate;

  if Animated then Views.Save;

  Views.Placement(ScrollContent.Padding.Rect,PageSize,ViewSize);

  for var View in Views do ScrollContent.AddObject(View);

  ScrollContent.Size.Size:=Views.Size;

  DoUpdateScrollingLimits;

  ScrollContent.EndUpdate;

  if (Views.ViewMode=vmTumbs) and (TumbsView=CurrentView) then
    FAniCalc.ViewportPositionF:=TumbsViewport
  else
  if Assigned(CurrentView) then
    FAniCalc.ViewportPositionF:=CurrentView.Viewport;

  AniCalcChange(nil);

  case Views.ViewMode of
  vmSingle: Views.SetViewsAnimationType(atStop);
  vmFeed: Views.SetViewsAnimationType(atProcess);//Animated:=False;
  vmTumbs: Views.SetViewsAnimationType(atStart);
  end;

  if Assigned(CurrentView) then CurrentView.AnimationType:=atProcess;

  Views.Apply(Animated);

end;

procedure TMainForm.LoadPictures;
begin

  Views.ReadDirectory(GetPicturesPath);

  Rectangle2.RecalcSize;

  ScrollToView(0);

end;

function TMainForm.AbsoluteCenterPoint: TPointF;
begin
  Result:=Rectangle2.LocalToAbsolute(Rectangle2.BoundsRect.CenterPoint);
end;

function TMainForm.AbsolutePressedPoint: TPointF;
begin
  Result:=Rectangle2.LocalToAbsolute(Rectangle2.PressedPosition);
end;

function TMainForm.ViewAtPoint(const AbsolutePoint: TPointF): TView;
begin
  Result:=Views.AtPoint(ScrollContent.AbsoluteToLocal(AbsolutePoint));
end;

function TMainForm.TryViewAtPoint(const AbsolutePoint: TPointF; out View: TView): Boolean;
begin
  View:=ViewAtPoint(AbsolutePoint);
  Result:=Assigned(View);
end;

function TMainForm.ViewIndexAtPoint(const AbsolutePoint: TPointF): Integer;
begin
  Result:=Views.IndexAtPoint(ScrollContent.AbsoluteToLocal(AbsolutePoint));
end;

procedure TMainForm.ScrollToView(View: TView; Immediately: Boolean);
var A: TAniCalculations.TTarget;
begin

  if View=nil then Exit;

  CurrentView:=View;

  A.TargetType:=TAniCalculations.TTargetType.Other;
  A.Point:=View.Viewport;

  if Immediately then
    FAniCalc.ViewportPosition:=A.Point
  else
    FAniCalc.MouseTarget:=A;

end;

procedure TMainForm.ScrollToView(ViewIndex: Integer; Immediately: Boolean);
begin
  ScrollToView(Views.ViewOf(ViewIndex),Immediately);
end;

procedure TMainForm.ShowText(const Text: string);
begin
  SetCaptured(nil); // fmx bug
  ShowMessage(Text);
end;

procedure TMainForm.Rectangle2Resized(Sender: TObject);
begin
  TumbsView:=nil;
  PlacementPictures(False);
end;

procedure TMainForm.Rectangle5Painting(Sender: TObject; Canvas: TCanvas;
  const ARect: TRectF);
begin
  Canvas.Fill.Color:=MakeColor($50353535,TControl(Sender).AbsoluteOpacity);
  Canvas.Fill.Kind:=TBrushKind.Solid;
  Canvas.FillRect(ARect,0,0,AllCorners,1);
end;

procedure TMainForm.Rectangle2Click(Sender: TObject);
var View: TView;
begin

  if not FAniCalc.Moved then
  //if FScrollType=stNone then
  if TryViewAtPoint(AbsolutePressedPoint,View) then
  begin

    CurrentView:=View;
    CurrentView.BringToFront;

    if Views.ViewMode=vmTumbs then
    begin
      TumbsView:=CurrentView;
      TumbsViewport:=FAniCalc.ViewportPositionF;
    end;

    if Views.ViewMode=vmTumbs then
      Views.ViewMode:=vmSingle
    else
      Views.ViewMode:=vmTumbs;

    PlacementPictures(True);

    FLeave:=True;

  end;

end;

procedure TMainForm.Rectangle2Gesture(Sender: TObject;
  const EventInfo: TGestureEventInfo; var Handled: Boolean);
var P: TPointF;
begin

//  if Assigned(FAniCalc) then
//  if EventInfo.GestureID=260 then
//  if TInteractiveGestureFlag.gfBegin in EventInfo.Flags then
//  begin
//    P:=Rectangle2.AbsoluteToLocal(EventInfo.Location);
//    FAniCalc.MouseDown(P.X,P.Y);
//    TAniCalculationsAccess(FAniCalc).Shown := True;
//    Handled:=True;
//  end;

end;

function TMainForm.GetScrollPoint(X,Y: Single): TPointF;
begin

  Result:=PointF(X,Y);

  case Views.ViewMode of

  vmTumbs:
    FScrollType:=stVScroll;

  vmFeed:
    FScrollType:=stHScroll;

  end;

  if FScrollType=stNone then
  if Abs(FDownPoint.Y-Y)>Abs(FDownPoint.X-X) then
    FScrollType:=stVScroll
  else
    FScrollType:=stHScroll;

  case FScrollType of
  stHScroll: Result.Y:=FDownPoint.Y;
  stVScroll: Result.X:=FDownPoint.X;
  end;

end;

procedure TMainForm.Rectangle2MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
var P: TPointF; V: TView;
begin

  Ani.Cancel;

  P:=PointF(X,Y);
  V:=ViewAtPoint(P);

  if Assigned(V) then
  begin
    P:=V.AbsoluteToLocal(P);
    Ani.Start(V,P);
  end;

  //DoUpdateScrollingLimits;
  //DoUpdateScrollingLimits2;

//  if (FAniCalc <> nil) and FAniCalc.Animation then
//  begin
//    FAniCalc.Averaging := ssTouch in Shift;
//    FAniCalc.MouseUp(X, Y);
//    FAniCalc.Animation := False;
//  end;


  if Assigned(FAniCalc) then
  begin
    FLeave:=False;
    FDownPoint:=PointF(X,Y);
    FScrollType:=stNone;
    //FAniCalc.Averaging := ssTouch in Shift;
    FAniCalc.MouseDown(X,Y);
    FAniCalc.Shown:=True;
  end;

end;

procedure TMainForm.Rectangle2MouseLeave(Sender: TObject);
begin

  if (FAniCalc<>nil) and FAniCalc.Down then
  begin

    FAniCalc.MouseLeave;

    FAniCalc.Shown:=False;

    if not FLeave then ScrollToView(ViewIndexAtPoint(AbsoluteCenterPoint));

    FLeave:=True;

  end;

end;

procedure TMainForm.Rectangle2MouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Single);
var P: TPointF;
begin

//          if FAniCalc <> nil then
//          begin
//            FAniCalc.Averaging := ssTouch in Shift;
//            FAniCalc.Animation := True;
//            FAniCalc.MouseDown(X, Y);
//          end;
//
//      if (FAniCalc <> nil) and FAniCalc.Animation then
//      begin
//        FAniCalc.Averaging := ssTouch in Shift;
//        FAniCalc.MouseUp(X, Y);
//        FAniCalc.Animation := False;
//      end;

  if (FAniCalc<>nil) and FAniCalc.Down then
  begin
    P:=GetScrollPoint(X,Y);
    FAniCalc.MouseMove(P.X,P.Y);
  end;

end;

procedure TMainForm.Rectangle2MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
var
  P: TPointF;
  ViewIndex: Integer;
  Velocity: TPointD;
begin

  Ani.Leave;

  if FAniCalc <> nil then
  begin

    P:=GetScrollPoint(X,Y);

    FAniCalc.MouseUp(P.X,P.Y);

    if not FLeave then
    if Views.ViewMode=vmSingle then
    begin

      Velocity:=FAniCalc.CurrentVelocity;

      case FScrollType of
      stHScroll: Velocity.Y:=0;
      stVScroll: Velocity.X:=0;
      end;

      if (Abs(Velocity.X)<100) and (Abs(Velocity.Y)<100) then
        ViewIndex:=ViewIndexAtPoint(AbsoluteCenterPoint)
      else
//      if Abs(Velocity.X)>2000 then
//        I:=PictureIndexAt(Rectangle2.LocalToAbsolute(PointF(X+Velocity.X/2,Y)))
//      else
      if Velocity.X<0 then
        ViewIndex:=CurrentView.ViewIndex-1
      else
        ViewIndex:=CurrentView.ViewIndex+1;

      ScrollToView(EnsureRange(ViewIndex,0,Views.Count-1));

    end;

  end;

end;

procedure TMainForm.Rectangle2MouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; var Handled: Boolean);
begin
  FAniCalc.Shown:=True;
  if Views.ViewMode=vmTumbs then
    FAniCalc.MouseWheel(0,-WheelDelta/2)
  else
    FAniCalc.MouseWheel(-WheelDelta/2,0);
  Handled:=True;
end;

procedure TMainForm.Rectangle2Paint(Sender: TObject; Canvas: TCanvas;
  const ARect: TRectF);
begin

  Canvas.Stroke.Kind:=TBrushKind.Solid;
  Canvas.Stroke.Thickness:=0.5;
  Canvas.Stroke.Color:=claRed;

  Canvas.DrawLine(PointF(ARect.CenterPoint.X,ARect.Top),PointF(ARect.CenterPoint.X,ARect.Bottom),0.5);

//
//  for var I:=1 to 20 do
//  Canvas.DrawLine(PointF(I*40-0.5,ARect.Top),PointF(I*40-0.5,ARect.Bottom),0.3);
//
//  for var I:=1 to 20 do
//  Canvas.DrawLine(PointF(ARect.Left,I*40-0.5),PointF(ARect.Right,I*40-0.5),0.3);

//  Canvas.DrawLine(Rectangle2.PressedPosition,Rectangle2.PressedPosition-FAniCalc.ViewportPositionF,1);

end;

procedure TMainForm.AniCalcChange(Sender: TObject);
var
  NewViewPos, MaxScrollViewPos: Single;
begin

//  NewViewPos := FAniCalc.ViewportPosition.Y;

  ScrollContent.Position.Point:=-FAniCalc.ViewportPositionF;

  if ContentSize.Y>0 then
  begin
    Rectangle4.Height:=Max(100,Rectangle1.Height*Rectangle2.Height/ScrollContent.Height);
    Rectangle4.Position.Y:=(Rectangle1.Height-Rectangle4.Height)*(FAniCalc.ViewportPositionF.Y/ContentSize.Y);
    Rectangle1.Opacity:=FAniCalc.Opacity;
  end else
    Rectangle1.Opacity:=0;

  if ContentSize.X>0 then
  begin
    Rectangle6.Width:=Max(100,Rectangle5.Width*Rectangle2.Width/ScrollContent.Width);
    Rectangle6.Position.X:=(Rectangle5.Width-Rectangle6.Width)*(FAniCalc.ViewportPositionF.X/ContentSize.X);
    Rectangle5.Opacity:=FAniCalc.Opacity;
  end else
    Rectangle5.Opacity:=0;

//  Rectangle2.InvalidateRect(TRectF.Create(Rectangle2.PressedPosition,Rectangle2.PressedPosition-FAniCalc.ViewportPositionF));

  //Rectangle2.Repaint;

//  MaxScrollViewPos := GetMaxScrollViewPos;
//
//  if NewViewPos < 0 then
//    UpdateScrollStretchStrength(NewViewPos)
//  else if NewViewPos > MaxScrollViewPos then
//    UpdateScrollStretchStrength(NewViewPos - MaxScrollViewPos)
//  else
//    UpdateScrollStretchStrength(0);
//
//  if not HasStretchyScrolling then
//    NewViewPos := EnsureRange(NewViewPos, 0, MaxScrollViewPos);
//
//  if (not SameValue(NewViewPos, FScrollViewPos, TEpsilon.Vector)) and
//    (TStateFlag.NeedsScrollBarDisplay in FStateFlags) then
//  begin
//    FScrollBar.StopPropertyAnimation('Opacity');
//    FScrollBar.Opacity := 1;
//
//    Exclude(FStateFlags, TStateFlag.NeedsScrollBarDisplay);
//  end;
//
//  if TStateFlag.ScrollingActive in FStateFlags then
//  begin
//    UpdateScrollViewPos(NewViewPos);
//    UpdateSearchEditPos;
//    UpdateDeleteButtonLayout;
//    UpdateScrollBar;
//  end;
end;

procedure TMainForm.AniCalcStart(Sender: TObject);
begin
//  if IsRunningOnDesktop then
//    DisableHitTestForControl(FScrollBar);
//

    (Self as IScene).ChangeScrollingState(Rectangle2,True);
//
//  FStateFlags := FStateFlags + [TStateFlag.NeedsScrollBarDisplay, TStateFlag.ScrollingActive];
end;

procedure TMainForm.AniCalcStop(Sender: TObject);
var
  ScrollPixelAlign: Boolean;
begin
//  ScrollPixelAlign := TStateFlag.ScrollingActive in FStateFlags;
//  Exclude(FStateFlags, TStateFlag.ScrollingActive);
//  TAnimator.AnimateFloat(FScrollBar, 'Opacity', 0, 0.2);
//

    if not FLeave and (Views.ViewMode=vmFeed) then
    CurrentView:=Views.ViewOf(ViewIndexAtPoint(AbsoluteCenterPoint));

    FAniCalc.Shown:=False;

    (Self as IScene).ChangeScrollingState(nil,False);
//
//  if ScrollPixelAlign and (FScrollScale > TEpsilon.Scale) then
//    SetScrollViewPos(Round(FScrollViewPos * FScrollScale) / FScrollScale);
end;

procedure TMainForm.DoUpdateScrollingLimits;
var Targets: array of TAniCalculations.TTarget;
begin

  if FAniCalc<>nil then
  begin

    SetLength(Targets,2);

    ContentSize.X:=Max(0,ScrollContent.Width-Rectangle2.Width);
    ContentSize.Y:=Max(0,ScrollContent.Height-Rectangle2.Height);

    Targets[0].TargetType:=TAniCalculations.TTargetType.Min;
    Targets[0].Point:=TPointD.Create(0,0);
    Targets[1].TargetType:=TAniCalculations.TTargetType.Max;
    Targets[1].Point:=ContentSize;

    FAniCalc.SetTargets(Targets);

  end;

end;

end.
