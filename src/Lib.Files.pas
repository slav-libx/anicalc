unit Lib.Files;

interface

uses
  System.SysUtils,
  System.IOUtils,
  System.Permissions;

function GetPicturesPath: string;
procedure RequestPermissionsExternalStorage(Proc: TProc<Boolean>);
function GetFiles(const RootDirectory: string; IncludeHiddenDirectories: Boolean): TArray<string>;

implementation

{$IFDEF ANDROID}

uses
  Androidapi.Helpers, Androidapi.JNI.Os;

function GetPicturesPath: string;
begin
  Result:=System.IOUtils.TPath.GetSharedPicturesPath;
end;

{$ELSE}

function GetPicturesPath: string;
begin
  Result:=System.IOUtils.TPath.GetPicturesPath;
end;

{$ENDIF}

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

function GetFiles(const RootDirectory: string; IncludeHiddenDirectories: Boolean): TArray<string>;
begin

  Result:=TDirectory.GetFiles(RootDirectory);

  for var Directory in TDirectory.GetDirectories(RootDirectory,
  function(const Path: string; const SearchRec: TSearchRec): Boolean
  begin
    Result:=IncludeHiddenDirectories or not string(SearchRec.Name).StartsWith('.');
  end)

  do Result:=Result+GetFiles(Directory,IncludeHiddenDirectories);

end;

end.
