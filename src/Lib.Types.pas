unit Lib.Types;

interface

uses
  System.SysUtils;

const
  PANIC_STOP = 0;
  PANIC_CONTINUE = 1;
  PANIC_CORRUPTED = 2;
  PANIC_INVALID_NETWORK = 3;
  PANIC_CANNOT_START_SERVER = 4;

type

  TBoolean = record
    Valid: Boolean;
    ErrorMessage: string;
    ErrorCode: Integer;
    constructor Create(Valid: Boolean; const ErrorMessage: string=''; ErrorCode: Integer=0);
    class operator Implicit(const R: TBoolean): Boolean;
    class operator LogicalNot(const R: TBoolean): Boolean;
  end;

  ERequireException = class(Exception)
  private
    FCode: Integer;
  public
    constructor Create(const Msg: string; Code: Integer);
    property Code: Integer read FCode;
  end;

  EPanicException = class(Exception)
  private
    FCode: Integer;
  public
    constructor Create(const Msg: string; Code: Integer);
    property Code: Integer read FCode;
  end;

procedure ObjectDispose(Obj: TObject);
procedure Require(Condition: Boolean; const ExceptMessage: string; Code: Integer=0); overload;
procedure Require(Condition: Boolean; const ExceptMessage: string; const Args: array of const; Code: Integer=0); overload;
procedure Require(const Result: TBoolean); overload;
procedure Corrupted(Condition: Boolean; const ExceptMessage: string);
procedure Panic(Proc: TProc; Code: Integer=PANIC_STOP); overload;
procedure Panic(Condition: Boolean; const ExceptMessage: string; Code: Integer=PANIC_STOP); overload;
procedure Panic(Condition: Boolean; const ExceptMessage: string; const Args: array of const; Code: Integer=PANIC_STOP); overload;
procedure Stop(const ExceptMessage: string); overload;
procedure Stop(const ExceptMessage: string; const Args: array of const); overload;

function AddRelease(Obj: TObject): IInterface;
function AddFinally(Proc: TProc): IInterface;

implementation

procedure ObjectDispose(Obj: TObject);
begin
  Obj.DisposeOf;
end;

constructor TBoolean.Create(Valid: Boolean; const ErrorMessage: string=''; ErrorCode: Integer=0);
begin
  Self:=Default(TBoolean);
  Self.Valid:=Valid;
  if not Self then
  begin
    Self.ErrorCode:=ErrorCode;
    if ErrorMessage.IsEmpty then
      Self.ErrorMessage:='unknown error'
    else
      Self.ErrorMessage:=ErrorMessage;
  end;
end;

class operator TBoolean.Implicit(const R: TBoolean): Boolean;
begin
  Result:=R.Valid;
end;

class operator TBoolean.LogicalNot(const R: TBoolean): Boolean;
begin
  Result:=not R.Valid;
end;

constructor ERequireException.Create(const Msg: string; Code: Integer);
begin
  inherited Create(Msg);
  FCode:=Code;
end;

constructor EPanicException.Create(const Msg: string; Code: Integer);
begin
  inherited Create(Msg);
  FCode:=Code;
end;

procedure Require(Condition: Boolean; const ExceptMessage: string; Code: Integer);
begin
  if not Condition then raise ERequireException.Create(ExceptMessage,Code);
end;

procedure Require(Condition: Boolean; const ExceptMessage: string;
  const Args: array of const; Code: Integer=0);
begin
  Require(Condition,Format(ExceptMessage,Args),Code);
end;

procedure Require(const Result: TBoolean);
begin
  Require(Result,Result.ErrorMessage,Result.ErrorCode);
end;

procedure Corrupted(Condition: Boolean; const ExceptMessage: string);
begin
  Panic(Condition,ExceptMessage,PANIC_CORRUPTED);
end;

procedure Panic(Proc: TProc; Code: Integer=PANIC_STOP);
begin
  try
    Proc;
  except
    on E: Exception do Panic(True,E.Message,Code);
  end;
end;

procedure Panic(Condition: Boolean; const ExceptMessage: string; Code: Integer=PANIC_STOP);
begin
  if Condition then raise EPanicException.Create(ExceptMessage,Code);
end;

procedure Panic(Condition: Boolean; const ExceptMessage: string; const Args: array of const; Code: Integer=PANIC_STOP);
begin
  Panic(Condition,Format(ExceptMessage,Args),Code);
end;

procedure Stop(const ExceptMessage: string);
begin
  raise Exception.Create(ExceptMessage);
end;

procedure Stop(const ExceptMessage: string; const Args: array of const);
begin
  Stop(Format(ExceptMessage,Args));
end;

type
  TDefer = class(TInterfacedObject)
  private
    FReleaseObject: TObject;
    FFinallyProc: TProc;
  public
    constructor Create(ReleaseObject: TObject); overload;
    constructor Create(FinallyProc: TProc); overload;
    destructor Destroy; override;
  end;

constructor TDefer.Create(ReleaseObject: TObject);
begin
  FReleaseObject:=ReleaseObject;
end;

constructor TDefer.Create(FinallyProc: TProc);
begin
  FFinallyProc:=FinallyProc;
end;

destructor TDefer.Destroy;
begin
  FReleaseObject.Free;
  if Assigned(FFinallyProc) then FFinallyProc;
end;

function AddRelease(Obj: TObject): IInterface;
begin
  Result:=TDefer.Create(Obj);
end;

function AddFinally(Proc: TProc): IInterface;
begin
  Result:=TDefer.Create(Proc);
end;

end.
