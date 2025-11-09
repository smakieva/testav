unit Unit1;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.Threading, System.SyncObjs,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation, FMX.StdCtrls;

type
  TForm1 = class(TForm)
    Popup1: TPopup;
    bOpenFile: TButton;
    bShowPopup: TButton;
    OpenDialog1: TOpenDialog;
    procedure bOpenFileClick(Sender: TObject);
    procedure bShowPopupClick(Sender: TObject);
  private
    FLck: TObject;
    FStop: Boolean;
    FSize: array[0..1000] of Integer;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  Form1: TForm1;
  p: array[0..1000] of Pointer;
  TaskFill: TThread = nil;
  TaskClear: TThread = nil;

implementation

{$R *.fmx}

constructor TForm1.Create(AOwner: TComponent);
begin
  inherited;
  FLck := TObject.Create;
  FStop := False;
  Randomize;
  for var k := 0 to High(p) do
  begin
    p[k] := nil;
    FSize[k] := 0;
  end;
end;

destructor TForm1.Destroy;
begin
  FStop := True;

  if Assigned(TaskFill) then
  begin
    TaskFill.WaitFor;
    TaskFill.Free;
    TaskFill := nil;
  end;

  if Assigned(TaskClear) then
  begin
    TaskClear.WaitFor;
    TaskClear.Free;
    TaskClear := nil;
  end;

  TMonitor.Enter(FLck);
  try
    for var k := 0 to High(p) do
      if p[k] <> nil then
      begin
        FreeMem(p[k]);
        p[k] := nil;
        FSize[k] := 0;
      end;
  finally
    TMonitor.Exit(FLck);
  end;

  FLck.Free;
  inherited;
end;

procedure TForm1.bOpenFileClick(Sender: TObject);
begin
  // Сначала диалог; при отмене — выходим и ничего не запускаем
  if (OpenDialog1 = nil) or (not OpenDialog1.Execute) then
    Exit;

  // Поток заполнения
  if not Assigned(TaskFill) then
  begin
    TaskFill := TThread.CreateAnonymousThread(
      procedure
      begin
        while not FStop do
        begin
          TMonitor.Enter(FLck);
          try
            for var k := 0 to High(p) do
              if p[k] = nil then
              begin
                var N := 1 + Random(10000);
                GetMem(p[k], N);
                FSize[k] := N;
                FillChar(p[k]^, FSize[k], Byte(Random(256)));
              end;
          finally
            TMonitor.Exit(FLck);
          end;
          TThread.Sleep(10);
        end;
      end
    );
    TaskFill.FreeOnTerminate := False;
    TaskFill.Start;
  end;

  // Поток очистки
  if not Assigned(TaskClear) then
  begin
    TaskClear := TThread.CreateAnonymousThread(
      procedure
      begin
        while not FStop do
        begin
          TThread.Sleep(10);
          TMonitor.Enter(FLck);
          try
            for var k := 0 to High(p) do
              if p[k] <> nil then
              begin
                FreeMem(p[k]);
                p[k] := nil;
                FSize[k] := 0;
              end;
          finally
            TMonitor.Exit(FLck);
          end;
        end;
      end
    );
    TaskClear.FreeOnTerminate := False;
    TaskClear.Start;
  end;
end;

procedure TForm1.bShowPopupClick(Sender: TObject);
begin
  Popup1.IsOpen := True;
end;

end.
