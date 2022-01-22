unit Lib.OperationQueue;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections;

type

  TOperation = class;

  TExecuteProc = TProc<TOperation>;
  TCompletionProc = TProc<TOperation>;

  TOperation = class
  private
    [weak] FException: Exception;
  public
    Main: TExecuteProc;
    Completion: TCompletionProc;
    function IsCompleted: Boolean;
    constructor Create; overload;
    constructor Create(Main: TExecuteProc; Completion: TCompletionProc); overload;
    property Exception: Exception read FException;
  end;

  TOperationQueue = class sealed
  private type

    TOperationThread = class(TThread)
    private
      [weak] QueueEvent: TCountdownEvent;
      FOnDestroy: TNotifyEvent;
      Operation: TOperation;
      procedure CallOnCompletion;
    protected
      procedure Execute; override;
      procedure DoTerminate; override;
      procedure TerminatedSet; override;
      procedure DoDestroy;
      property OnDestroy: TNotifyEvent write FOnDestroy;
    public
      constructor Create(Operation: TOperation; Event: TCountdownEvent);
      destructor Destroy; override;
    end;

  private type
    TThreads = TList<TOperationThread>;
    TOperations = TObjectQueue<TOperation>;
  private
    Event: TCountdownEvent;
    FMaxConcurrentOperationCount: Integer;
    Threads: TThreads;
    Operations: TOperations;
    procedure OnDestroyThread(Thread: TObject);
    procedure EnqueueOperation(Operation: TOperation);
    procedure DoOperation(Operation: TOperation);
    function AvailableConcurrent: Boolean;
    function GetOperationCount: Integer;
    procedure WaitThreads;
  public
    constructor Create(MaxConcurrentOperationCount: Integer=4);
    destructor Destroy; override;
    procedure Cancel;
    procedure AddOperation(Operation: TOperation); overload;
    procedure AddOperation(Main: TExecuteProc; Completion: TCompletionProc); overload;
    property OperationCount: Integer read GetOperationCount;
    property MaxConcurrentOperationCount: Integer read FMaxConcurrentOperationCount write FMaxConcurrentOperationCount;
  end;

implementation

{ TOperation }

constructor TOperation.Create;
begin
end;

constructor TOperation.Create(Main: TExecuteProc; Completion: TCompletionProc);
begin
  Self.Main:=Main;
  Self.Completion:=Completion;
end;

function TOperation.IsCompleted: Boolean;
begin
  Result:=not Assigned(FException);
end;

{ TOperationQueue.TOperationThread }

constructor TOperationQueue.TOperationThread.Create(Operation: TOperation; Event: TCountdownEvent);
begin
  inherited Create(False);
  Self.QueueEvent:=Event;
  Self.Operation:=Operation;
  FreeOnTerminate:=True;
end;

procedure TOperationQueue.TOperationThread.TerminatedSet;
begin
  Operation.Completion:=nil;
end;

procedure TOperationQueue.TOperationThread.DoDestroy;
begin
  if Assigned(FOnDestroy) then FOnDestroy(Self);
end;

destructor TOperationQueue.TOperationThread.Destroy;
begin
  Operation.Free;
  DoDestroy;
  inherited;
end;

procedure TOperationQueue.TOperationThread.Execute;
begin
  Operation.Main(Operation);
end;

procedure TOperationQueue.TOperationThread.DoTerminate;
begin

  QueueEvent.Signal;

  if not Terminated and Assigned(Operation.Completion) then
    Self.Synchronize(CallOnCompletion);

end;

procedure TOperationQueue.TOperationThread.CallOnCompletion;
begin
  if Assigned(Operation.Completion) then
  begin
    Operation.FException:=FatalException as Exception;
    Operation.Completion(Operation);
  end;
end;

{ TOperationQueue }

constructor TOperationQueue.Create(MaxConcurrentOperationCount: Integer=4);
begin
  Event:=TCountdownEvent.Create;
  FMaxConcurrentOperationCount:=MaxConcurrentOperationCount;
  Threads:=TThreads.Create;
  Operations:=TOperations.Create(True);
end;

destructor TOperationQueue.Destroy;
begin
  Cancel;
  WaitThreads;
  Event.Free;
  Threads.Free;
  Operations.Free;
  inherited;
end;

function TOperationQueue.GetOperationCount: Integer;
begin
  Result:=Operations.Count+Threads.Count;
end;

procedure TOperationQueue.Cancel;
begin
  Operations.Clear;
  for var Thread in Threads.ToArray do Thread.Terminate;
end;

procedure TOperationQueue.WaitThreads;
begin
  Event.Signal;
  Event.WaitFor;
  Event.Reset;
end;

function TOperationQueue.AvailableConcurrent: Boolean;
begin
  Result:=Event.CurrentCount<MaxConcurrentOperationCount+1;
end;

procedure TOperationQueue.EnqueueOperation(Operation: TOperation);
begin
  Operations.Enqueue(Operation);
end;

procedure TOperationQueue.DoOperation(Operation: TOperation);
begin

  Event.AddCount;

  var Thread:=TOperationThread.Create(Operation,Event);

  Thread.OnDestroy:=OnDestroyThread;
  Threads.Add(Thread);

end;

procedure TOperationQueue.OnDestroyThread(Thread: TObject);
begin

  // executing in concurrent thread

  Threads.Remove(TOperationThread(Thread));

  if (Operations.Count>0) and AvailableConcurrent then
    DoOperation(Operations.Extract);

end;

procedure TOperationQueue.AddOperation(Operation: TOperation);
begin
  if AvailableConcurrent then
    DoOperation(Operation)
  else
    EnqueueOperation(Operation);
end;

procedure TOperationQueue.AddOperation(Main: TExecuteProc; Completion: TCompletionProc);
begin
  AddOperation(TOperation.Create(Main,Completion));
end;

end.
