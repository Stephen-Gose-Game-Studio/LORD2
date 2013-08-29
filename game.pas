unit Game;

interface

uses
  Struct, SysUtils, RTGlobal, MannDoor, mAnsi, Crt, RTReader;

var
  CurrentMap: MapDatRecord;
  ENEMY: String = '';
  IsNewDay: Boolean = false;
  ItemsDat: ItemsDatCollection;
  LastX: Integer;
  LastY: Integer;
  MapDat: Array of MapDatRecord;
  Player: TraderDatRecord;
  PlayerNum: Integer = -1;
  RESPONSE: String = '';
  STime: Integer;
  Time: Integer = 1;
  WorldDat: WorldDatRecord;

  MapDatFileName: String;
  ItemsDatFileName: String;
  STimeDatFileName: String;
  TimeDatFileName: String;
  TraderDatFileName: String;
  UpdateTmpFileName: String;
  WorldDatFileName: String;

procedure DrawMap;
function GetSafeAbsolutePath(AFileName: String): String;
function LoadDataFiles: Boolean;
procedure LoadMap(AMapNumber: Integer);
function LoadPlayerByRealName(ARealName: String; var ARecord: TraderDatRecord): Integer;
procedure MoveBack;
procedure Start;
function TotalAccounts: Integer;
procedure Update;

implementation

var
  FLastTotalAccounts: LongInt;
  FTotalAccounts: Integer = 0;

function LoadItemsDat: Boolean; forward;
function LoadMapDat: Boolean; forward;
function LoadSTimeDat: Boolean; forward;
function LoadTimeDat: Boolean; forward;
function LoadWorldDat: Boolean; forward;
procedure MovePlayer(AXOffset, AYOffset: Integer); forward;

procedure DrawMap;
var
  BG: Integer;
  FG: Integer;
  MI: map_info;
  ToSend: String;
  X, Y: Integer;
begin
  // Draw the map
  BG := 0;
  FG := 7;
  mTextAttr(FG);
  mClrScr;

  for Y := 1 to 20 do
  begin
    ToSend := '';

    for X := 1 to 80 do
    begin
      MI := CurrentMap.MapInfo[X][Y];

      if (BG <> MI.BackColour) then
      begin
        ToSend := ToSend + mAnsi.aTextBackground(MI.BackColour);
        Crt.TextBackground(MI.BackColour); // Gotta do this to ensure calls to Ansi.* work right
        BG := MI.BackColour;
      end;

      if (FG <> MI.ForeColour) then
      begin
        ToSend := ToSend + mAnsi.aTextColor(MI.ForeColour);
        Crt.TextColor(MI.ForeColour); // Gotta do this to ensure calls to Ansi.* work right
        FG := MI.ForeColour;
      end;

      GotoXY(1, Y);
      ToSend := ToSend + MI.Ch;
    end;

    mWrite(ToSend);
  end;
end;

function GetSafeAbsolutePath(AFileName: String): String;
var
  S: AnsiString;
begin
  S := AFileName;
  DoDirSeparators(S); // Ensure \ and / are used appropriately
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + S;
end;

function LoadDataFiles: Boolean;
begin
  Result := true;
  Result := Result AND LoadItemsDat;
  Result := Result AND LoadMapDat;
  Result := Result AND LoadSTimeDat;
  Result := Result AND LoadTimeDat;
  Result := Result AND LoadWorldDat;
end;

function LoadItemsDat: Boolean;
var
  F: File of ItemsDatCollection;
begin
  // TODO Retry if IOError
  Assign(F, ItemsDatFileName);
  {$I-}Reset(F);{$I+}
  if (IOResult = 0) then
  begin
    Read(F, ItemsDat);
    Result := true;
  end else
  begin
    mWriteLn('Unable to open ' + ItemsDatFileName);
    Result := false;
  end;
  Close(F);
end;

procedure LoadMap(AMapNumber: Integer);
begin
  CurrentMap := MapDat[WorldDat.MapDatIndex[AMapNumber]];
end;

function LoadMapDat: Boolean;
var
  F: File of MapDatRecord;
  I: Integer;
begin
  // TODO Retry if IOError
  Assign(F, MapDatFileName);
  {$I-}Reset(F);{$I+}
  if (IOResult = 0) then
  begin
    SetLength(MapDat, FileSize(F) + 1); // + 1 since we want a 1-based MapDat
    I := 0;
    repeat
      I := I + 1;
      Read(F, MapDat[I]);
    until EOF(F);
    Result := true;
  end else
  begin
    mWriteLn('Unable to open ' + MapDatFileName);
    Result := false;
  end;
  Close(F);
end;

function LoadPlayerByRealName(ARealName: String; var ARecord: TraderDatRecord): Integer;
var
  F: File of TraderDatRecord;
  I: Integer;
  Rec: TraderDatRecord;
begin
  Result := -1;

  // TODO Retry if IOError
  Assign(F, TraderDatFileName);
  {$I-}Reset(F);{$I+}
  if (IOResult = 0) then
  begin
    I := 0;
    repeat
      I := I + 1;
      Read(F, Rec);
      if (UpperCase(Rec.RealName) = UpperCase(ARealName)) then
      begin
        ARecord := Rec;
        Result := I;
        break;
      end;
    until EOF(F);
  end;
  Close(F);
end;

function LoadSTimeDat: Boolean;
var
  F: Text;
  S: String;
  Y, M, D: Word;
begin
  DecodeDate(Date, Y, M, D);
  STime := Y + M + D;

  if (FileExists(STimeDatFileName)) then
  begin
    // TODO Retry if IOError
    Assign(F, STimeDatFileName);
    {$I-}Reset(F);{$I+}
    if (IOResult = 0) then
    begin
      ReadLn(F, S);
      if (StrToInt(S) <> STime) then
      begin
        IsNewDay := true;
      end;
    end;
    Close(F);
  end else
  begin
    IsNewDay := true;
  end;

  if (IsNewDay) then
  begin
    // TODO Retry if IOError
    Assign(F, STimeDatFileName);
    {$I-}ReWrite(F);{$I+}
    if (IOResult = 0) then
    begin
      WriteLn(F, STime);
    end;
    Close(F);
  end;

  Result := true;
end;

function LoadTimeDat: Boolean;
var
  F: Text;
  S: String;
begin
  if (FileExists(TimeDatFileName)) then
  begin
    // TODO Retry if IOError
    Assign(F, TimeDatFileName);
    {$I-}Reset(F);{$I+}
    if (IOResult = 0) then
    begin
      ReadLn(F, S);
      Time := StrToInt(S);
    end;
    Close(F);
  end else
  begin
    Time := 0;
  end;

  if (IsNewDay) then
  begin
    Time := Time + 1;

    // TODO Retry if IOError
    Assign(F, TimeDatFileName);
    {$I-}ReWrite(F);{$I+}
    if (IOResult = 0) then
    begin
      WriteLn(F, IntToStr(Time));
    end;
    Close(F);
  end;

  Result := true;
end;

function LoadWorldDat: Boolean;
var
  F: File of WorldDatRecord;
begin
  if Not(FileExists(WorldDatFileName)) then
  begin
    // TODO Generate the file
  end;

  // TODO Retry if IOError
  Assign(F, WorldDatFileName);
  {$I-}Reset(F);{$I+}
  if (IOResult = 0) then
  begin
    Read(F, WorldDat);
    Result := true;
  end else
  begin
    mWriteLn('Unable to open ' + WorldDatFileName);
    Result := false;
  end;
  Close(F);
end;

procedure MoveBack;
begin
  // Erase player
  mTextBackground(CurrentMap.MapInfo[Player.x][Player.y].BackColour);
  mTextColor(CurrentMap.MapInfo[Player.x][Player.y].ForeColour);
  mGotoXY(Player.x, Player.y);
  mWrite(CurrentMap.MapInfo[Player.x][Player.y].Ch);

  // Update position and draw player
  Player.X := LastX;
  Player.Y := LastY;
  Update;
end;

procedure MovePlayer(AXOffset, AYOffset: Integer);
var
  i, x, y: Integer;
begin
  x := Player.x + AXOffset;
  y := Player.y + AYOffset;

  // Check for movement to new screen
  if (x = 0) then
  begin
    Player.LastMap := Player.Map; // TODO Only if map was visible, according to 3rdparty.doc
    Player.Map -= 1;
    Player.X := 80;

    LoadMap(Player.Map);
    DrawMap;
    Update;
  end else
  if (x = 81) then
  begin
    Player.LastMap := Player.Map; // TODO Only if map was visible, according to 3rdparty.doc
    Player.Map += 1;
    Player.X := 1;

    LoadMap(Player.Map);
    DrawMap;
    Update;
  end else
  if (y = 0) then
  begin
    Player.LastMap := Player.Map; // TODO Only if map was visible, according to 3rdparty.doc
    Player.Map -= 80;
    Player.Y := 20;

    LoadMap(Player.Map);
    DrawMap;
    Update;
  end else
  if (y = 21) then
  begin
    Player.LastMap := Player.Map; // TODO Only if map was visible, according to 3rdparty.doc
    Player.Map += 80;
    Player.Y := 1;

    LoadMap(Player.Map);
    DrawMap;
    Update;
  end else
  begin
    if (CurrentMap.MapInfo[x][y].Terrain = 1) then
    begin
      // Erase player
      mTextBackground(CurrentMap.MapInfo[Player.x][Player.y].BackColour);
      mTextColor(CurrentMap.MapInfo[Player.x][Player.y].ForeColour);
      mGotoXY(Player.x, Player.y);
      mWrite(CurrentMap.MapInfo[Player.x][Player.y].Ch);

      // Update position and draw player
      LastX := Player.X;
      LastY := Player.Y;
      Player.X := x;
      Player.Y := y;
      Update;
    end;
  end;

  // Check for special
  for I := Low(CurrentMap.HotSpots) to High(CurrentMap.HotSpots) do
  begin
    if (CurrentMap.HotSpots[I].HotSpotX = x) AND (CurrentMap.HotSpots[I].HotSpotY = y) then
    begin
      if (CurrentMap.HotSpots[I].WarpToMap > 0) AND (CurrentMap.HotSpots[I].WarpToX > 0) AND (CurrentMap.HotSpots[I].WarpToY > 0) then
      begin
        Player.LastMap := Player.Map; // TODO Only if map was visible, according to 3rdparty.doc
        Player.Map := CurrentMap.HotSpots[I].WarpToMap;
        Player.X := CurrentMap.HotSpots[I].WarpToX;
        Player.Y := CurrentMap.HotSpots[I].WarpToY;

        LoadMap(Player.Map);
        DrawMap;
        Update;
      end else
      if (CurrentMap.HotSpots[I].RefFile <> '') AND (CurrentMap.HotSpots[I].RefSection <> '') then
      begin
        RTReader.Execute(CurrentMap.HotSpots[I].RefFile, CurrentMap.HotSpots[I].RefSection);
      end;
    end;
  end;
end;

procedure Start;
var
  Ch: Char;
begin
  LoadMap(Player.map);
  DrawMap;
  Update;

  repeat
    Ch := UpCase(mReadKey);
    case Ch of
      '8': MovePlayer(0, -1);
      '4': MovePlayer(-1, 0);
      '6': MovePlayer(1, 0);
      '2': MovePlayer(0, 1);
    end;
  until (Ch = 'Q');
end;

function TotalAccounts: Integer;
begin
  // TODO This should see if X number of seconds have elapsed since the last check
  // TODO If so, then re-check the TRADER.DAT to get an updated count
  FLastTotalAccounts := 0;
  FTotalAccounts := 0;
  Result := FTotalAccounts;
end;

procedure Update;
begin
  // Draw the Player
  mTextBackground(CurrentMap.MapInfo[Player.x][Player.y].BackColour);
  mTextColor(Crt.White);
  mGotoXY(Player.x, Player.y);
  mWrite(#02);

  // TODO Draw the other players
end;

begin
  ItemsDatFileName := GetSafeAbsolutePath('ITEMS.DAT');
  MapDatFileName := GetSafeAbsolutePath('MAP.DAT');
  STimeDatFileName := GetSafeAbsolutePath('STIME.DAT');
  TimeDatFileName := GetSafeAbsolutePath('TIME.DAT');
  TraderDatFileName := GetSafeAbsolutePath('TRADER.DAT');
  UpdateTmpFileName := GetSafeAbsolutePath('UPDATE.TMP');
  WorldDatFileName := GetSafeAbsolutePath('WORLD.DAT');
end.
