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
  Lib.Classes,
  Lib.Files;

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
  private const
    PhysicsProcessingInterval = 8; // 8 ms for ~120 frames per second
    HasPhysicsStretchyScrolling = True;
    PICTURES_MARGIN = 10;
  private
    FAniCalc: TAniCalculations;
    ContentSize: TPointF;
    Pictures: TPictureList;
    CurrentPicture: TPicture;
    FLeave: Boolean;
    procedure AniCalcChange(Sender: TObject);
    procedure AniCalcStart(Sender: TObject);
    procedure AniCalcStop(Sender: TObject);
    procedure DoUpdateScrollingLimits;
    procedure LoadPictures;
    function AbsoluteCenterPoint: TPointF;
    function AbsolutePressedPoint: TPointF;
    function PictureAtPoint(const AbsolutePoint: TPointF): TPicture;
    function TryPictureAtPoint(const AbsolutePoint: TPointF; out Picture: TPicture): Boolean;
    function PictureIndexAt(const AbsolutePoint: TPointF): Integer;
    procedure ShowText(const Text: string);
    procedure PlacementPictures;
    procedure ScrollToPicture(Picture: TPicture; Immediately: Boolean=False); overload;
    procedure ScrollToPicture(PictureIndex: Integer; Immediately: Boolean=False); overload;
  public
  end;

var
  MainForm: TMainForm;

implementation

{$R *.fmx}

type
  TAniCalculationsAccess = class(TAniCalculations);

procedure TMainForm.FormCreate(Sender: TObject);
begin

  FAniCalc:=TAniCalculations.Create(nil);

  FAniCalc.TouchTracking:=[{ttVertical,}ttHorizontal];
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
  TAniCalculationsAccess(FAniCalc).Shown:=False;
//  TAniCalculationsAccess(FAniCalc).StorageTime:=0.1;//1000;
  TAniCalculationsAccess(FAniCalc).DeadZone:=10; // смещение после которого происходит инициация анимации, работает только если Averaging=True

  Pictures:=TPictureList.Create;

  RequestPermissionsExternalStorage(
  procedure(Granted: Boolean)
  begin
    if Granted then LoadPictures;
  end);

end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  Pictures.Free;
  FAniCalc.Free;
end;

procedure TMainForm.PlacementPictures;
var FeedMode: Boolean;
begin

  if Pictures=nil then Exit;

  FeedMode:=Rectangle2.Width>Rectangle2.Height*1.5;

  ScrollContent.BeginUpdate;

  Pictures.Placement(FeedMode,ScrollContent.Padding.Rect,Rectangle2.BoundsRect.BottomRight);

  for var Picture in Pictures do ScrollContent.AddObject(Picture);

  ScrollContent.Size.Size:=Pictures.Size;

  ScrollContent.EndUpdate;

  DoUpdateScrollingLimits;

  AniCalcChange(nil);

end;

procedure TMainForm.LoadPictures;
begin

  Pictures.ReadDirectory(GetPicturesPath);

  Rectangle2.RecalcSize;

  ScrollToPicture(0);

end;

function TMainForm.AbsoluteCenterPoint: TPointF;
begin
  Result:=Rectangle2.LocalToAbsolute(Rectangle2.BoundsRect.CenterPoint);
end;

function TMainForm.AbsolutePressedPoint: TPointF;
begin
  Result:=Rectangle2.LocalToAbsolute(Rectangle2.PressedPosition);
end;

function TMainForm.PictureAtPoint(const AbsolutePoint: TPointF): TPicture;
begin
  Result:=Pictures.AtPoint(ScrollContent.AbsoluteToLocal(AbsolutePoint));
end;

function TMainForm.TryPictureAtPoint(const AbsolutePoint: TPointF; out Picture: TPicture): Boolean;
begin
  Picture:=PictureAtPoint(AbsolutePoint);
  Result:=Assigned(Picture);
end;

function TMainForm.PictureIndexAt(const AbsolutePoint: TPointF): Integer;
begin
  Result:=Pictures.IndexAtPoint(ScrollContent.AbsoluteToLocal(AbsolutePoint));
end;

procedure TMainForm.ScrollToPicture(Picture: TPicture; Immediately: Boolean);
var A: TAniCalculations.TTarget;
begin

  if Picture=nil then Exit;

  CurrentPicture:=Picture;

  A.TargetType:=TAniCalculations.TTargetType.Other;
  A.Point:=Picture.PageBounds.TopLeft;

  TAniCalculationsAccess(FAniCalc).MouseTarget:=A;

  if Immediately then FAniCalc.UpdatePosImmediately(True);

end;

procedure TMainForm.ScrollToPicture(PictureIndex: Integer; Immediately: Boolean);
begin
  ScrollToPicture(Pictures.PictureOf(PictureIndex),Immediately);
end;

procedure TMainForm.ShowText(const Text: string);
begin
  SetCaptured(nil); // fmx bug
  ShowMessage(Text);
end;

procedure TMainForm.Rectangle2Resized(Sender: TObject);
begin
  PlacementPictures;
  ScrollToPicture(CurrentPicture,True);
end;

procedure TMainForm.Rectangle2Click(Sender: TObject);
var Picture: TPicture;
begin
  if not FAniCalc.Moved then
  if TryPictureAtPoint(AbsolutePressedPoint,Picture) then
  begin
    ScrollToPicture(Picture);
    FLeave:=True;
    ShowText(Picture.ToString);
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

procedure TMainForm.Rectangle2MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
begin

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
    //FAniCalc.Averaging := ssTouch in Shift;
    FAniCalc.MouseDown(X,Y);
    TAniCalculationsAccess(FAniCalc).Shown:=True;
  end;

end;

procedure TMainForm.Rectangle2MouseLeave(Sender: TObject);
begin

  if (FAniCalc<>nil) and FAniCalc.Down then
  begin

    FAniCalc.MouseLeave;

    TAniCalculationsAccess(FAniCalc).Shown:=False;

    if not FLeave then ScrollToPicture(PictureIndexAt(AbsoluteCenterPoint));

    FLeave:=True;

  end;

end;

procedure TMainForm.Rectangle2MouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Single);
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
    FAniCalc.MouseMove(X,Y);

end;

procedure TMainForm.Rectangle2MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
var PictureIndex: Integer;
begin

  if FAniCalc <> nil then
  begin

    FAniCalc.MouseUp(X, Y);

    if not Pictures.FeedMode then
    begin

      if Abs(FAniCalc.CurrentVelocity.X)<100 then
        PictureIndex:=PictureIndexAt(AbsoluteCenterPoint)
      else
//      if Abs(FAniCalc.CurrentVelocity.X)>2000 then
//        I:=PictureIndexAt(Rectangle2.LocalToAbsolute(PointF(X+FAniCalc.CurrentVelocity.X/2,Y)))
//      else
      if FAniCalc.CurrentVelocity.X<0 then
        PictureIndex:=CurrentPicture.PictureIndex-1
      else
        PictureIndex:=CurrentPicture.PictureIndex+1;

      ScrollToPicture(EnsureRange(PictureIndex,0,Pictures.Count-1));

    end;

  end;

end;

procedure TMainForm.Rectangle2MouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; var Handled: Boolean);
begin
  TAniCalculationsAccess(FAniCalc).Shown:=True;
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

  Rectangle4.Height:=Max(100,Rectangle1.Height*Rectangle2.Height/ScrollContent.Height);
  Rectangle4.Position.Y:=(Rectangle1.Height-Rectangle4.Height)*(FAniCalc.ViewportPositionF.Y/ContentSize.Y);

  Rectangle1.Opacity:=FAniCalc.Opacity;

  Rectangle6.Width:=Max(100,Rectangle5.Width*Rectangle2.Width/ScrollContent.Width);
  Rectangle6.Position.X:=(Rectangle5.Width-Rectangle6.Width)*(FAniCalc.ViewportPositionF.X/ContentSize.X);

  Rectangle5.Opacity:=FAniCalc.Opacity;

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

    (Self as IScene).ChangeScrollingState(Rectangle2, True);
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

    if not FLeave and Pictures.FeedMode then
    CurrentPicture:=Pictures.PictureOf(PictureIndexAt(AbsoluteCenterPoint));

    TAniCalculationsAccess(FAniCalc).Shown:=False;

    (Self as IScene).ChangeScrollingState(nil,False);
//
//  if ScrollPixelAlign and (FScrollScale > TEpsilon.Scale) then
//    SetScrollViewPos(Round(FScrollViewPos * FScrollScale) / FScrollScale);
end;

procedure TMainForm.DoUpdateScrollingLimits;
var Targets: array of TAniCalculations.TTarget;
begin

  if FAniCalc <> nil then
  begin

    SetLength(Targets, 2);

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
