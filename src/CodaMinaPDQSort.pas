unit CodaMinaPDQSort4;
//要改成一般的T, 比 object 較快
{$INLINE ON}
{$MODESWITCH NESTEDPROCVARS}
{$mode objfpc}{$H+}
{$MODESWITCH ADVANCEDRECORDS}
interface

uses
  Classes, SysUtils;
const
  BLOCK_SIZE                   = 128;
  CACHE_LINE_SIZE              = 64;
  PARTIAL_INSERTION_SORT_LIMIT = 12;
  NINTHER_THRESHOLD            = 128;
  HEAP_INSERTION_SORT_CUTOFF  = 63;
  QUICK_INSERTION_SORT_CUTOFF = 47;
type
    generic TGTuple2<T1, T2> = record
      F1: T1;
      F2: T2;
      constructor Create(const v1: T1; const v2: T2);
    end;
    generic TCodaMinaPDQSort4<TItem> = class
    type
      PItem             = ^TItem;
      TPart = specialize TGTuple2<PItem, Boolean>;
      //to supress unnecessary refcounting
      TItemArray = array of TItem;
			Tcmp_func3  = function (const a, b:PItem):integer;
    private
      FOffsetsLStorage, FOffsetsRStorage: array[0..Pred(BLOCK_SIZE + CACHE_LINE_SIZE)] of Byte;
      procedure SwapOffsets(aFirst, aLast: PItem; aOffsetsL, aOffsetsR: PByte;
                                  aNum: SizeInt; aUseSwaps: Boolean);
      procedure Sort3(A, B, C: PItem;cmp3:Tcmp_func3); inline;
      function  PartitionRight(aStart, aFinish: PItem;cmp3:Tcmp_func3): TPart;
      procedure DoPDQSort(aStart, aFinish: PItem; aBadAllowed: SizeInt; aLeftMost: Boolean;cmp3:Tcmp_func3);
      function  PartialInsertionSort(aStart, aFinish: PItem;cmp3:Tcmp_func3): Boolean;
      function  PartitionLeft(aStart, aFinish: PItem;cmp3:Tcmp_func3): PItem;
      procedure InsertionSort(A: PItem; R: SizeInt;cmp3:Tcmp_func3);
      procedure UnguardInsertionSort(A: PItem; R: SizeInt;cmp3:Tcmp_func3);
      procedure DoHeapSort(A: PItem; R: SizeInt;cmp3:Tcmp_func3);
      function NSB(aValue: SizeUInt): SizeInt;
			function BsrSizeUInt(aValue: SizeUInt): ShortInt;
    public
      procedure PDQSort(aStart, aFinish: PItem;cmp3:Tcmp_func3);
      { Pascal translation of Orson Peters' PDQSort algorithm, in-place }
      procedure PDQSort(var A: array of TItem;cmp3:Tcmp_func3);
			constructor create;
    end;
implementation
constructor TGTuple2.Create(const v1: T1; const v2: T2);
begin
  F1 := v1;
  F2 := v2;
end;
constructor TCodaMinaPDQSort4.create;
begin
  fillbyte(FOffsetsLStorage[0],length(FOffsetsLStorage),0);
  fillbyte(FOffsetsRStorage[0],length(FOffsetsLStorage),0);
end;
procedure TCodaMinaPDQSort4.SwapOffsets(aFirst, aLast: PItem; aOffsetsL, aOffsetsR: PByte;
  aNum: SizeInt; aUseSwaps: Boolean);
var
  L, R: PItem;
  I: SizeInt;
  v: TItem;
begin
  if aUseSwaps then
    for I := 0 to Pred(aNum) do
      begin
        v := (aFirst + SizeInt(aOffsetsL[I]))^;
        (aFirst + SizeInt(aOffsetsL[I]))^ := (aLast - SizeInt(aOffsetsR[I]))^;
        (aLast - SizeInt(aOffsetsR[I]))^ := v;
      end
  else
    if aNum > 0 then
      begin
        L := aFirst + SizeInt(aOffsetsL[0]);
        R := aLast - SizeInt(aOffsetsR[0]);
        v := L^;
        L^ := R^;
        for I := 1 to Pred(aNum) do
          begin
            L := aFirst + SizeInt(aOffsetsL[I]);
            R^ := L^;
            R := aLast - SizeInt(aOffsetsR[I]);
            L^ := R^;
          end;
        R^ := v;
      end;
end;

procedure TCodaMinaPDQSort4.Sort3(A, B, C: PItem;cmp3:Tcmp_func3);
var
  v: TItem;
begin
  if cmp3(B, A)<0 then
    begin
      v := A^;
      A^ := B^;
      B^ := v;
    end;
  if cmp3(C, B)<0 then
    begin
      v := B^;
      B^ := C^;
      C^ := v;
    end;
  if cmp3(B, A)<0 then
    begin
      v := A^;
      A^ := B^;
      B^ := v;
    end;
end;

function TCodaMinaPDQSort4.PartitionRight(aStart, aFinish: PItem;cmp3:Tcmp_func3): TPart;
var
  Pivot: TItem;
  v: TItem;
  First, Last, It, PivotPos: PItem;
  Num, NumL, NumR, StartL, StartR, LSize, RSize, UnknownLeft: SizeInt;
  OffsetsL, OffsetsR: PByte;
  I: Byte;
  AlreadyPartitioned: Boolean;
begin
  Pivot := aStart^;
  First := aStart;
  Last := aFinish;
  repeat Inc(First) until not cmp3(First, @Pivot)<0;
  if First - 1 = aStart then
    while First < Last do
      begin
        Dec(Last);
        if cmp3(Last, @Pivot)<0 then
          break;
      end
  else
    repeat Dec(Last) until cmp3(Last, @Pivot)<0;

  AlreadyPartitioned := First >= Last;

  if not AlreadyPartitioned then
    begin
      v := First^;
      First^ :=  Last^;
      Last^ := v;
      Inc(First);
    end;

  OffsetsL := Align(@FOffsetsLStorage[0], CACHE_LINE_SIZE);
  OffsetsR := Align(@FOffsetsRStorage[0], CACHE_LINE_SIZE);

  NumL := 0;
  NumR := 0;
  StartL := 0;
  StartR := 0;
  while Last - First > 2 * BLOCK_SIZE do
    begin
      if NumL = 0 then
        begin
          StartL := 0;
          It := First;
          I := 0;
          while I < BLOCK_SIZE do
            begin
              (OffsetsL + NumL)^ := I;
              NumL += SizeInt(not cmp3(It, @Pivot)<0);
              (OffsetsL + NumL)^ := I + 1;
              NumL += SizeInt(not cmp3((It + 1), @Pivot)<0);
              (OffsetsL + NumL)^ := I + 2;
              NumL += SizeInt(not cmp3((It + 2), @Pivot)<0);
              (OffsetsL + NumL)^ := I + 3;
              NumL += SizeInt(not cmp3((It + 3), @Pivot)<0);
              (OffsetsL + NumL)^ := I + 4;
              NumL += SizeInt(not cmp3((It + 4), @Pivot)<0);
              (OffsetsL + NumL)^ := I + 5;
              NumL += SizeInt(not cmp3((It + 5), @Pivot)<0);
              (OffsetsL + NumL)^ := I + 6;
              NumL += SizeInt(not cmp3((It + 6), @Pivot)<0);
              (OffsetsL + NumL)^ := I + 7;
              NumL += SizeInt(not cmp3((It + 7), @Pivot)<0);
              I += 8;
              It += 8;
            end;
        end;
      if NumR = 0 then
        begin
          StartR := 0;
          It := Last;
          I := 0;
          while I < BLOCK_SIZE do
            begin
              (OffsetsR + NumR)^ := I + 1;
              NumR += SizeInt(cmp3((It - 1), @Pivot)<0);
              (OffsetsR + NumR)^ := I + 2;
              NumR += SizeInt(cmp3((It - 2), @Pivot)<0);
              (OffsetsR + NumR)^ := I + 3;
              NumR += SizeInt(cmp3((It - 3), @Pivot)<0);
              (OffsetsR + NumR)^ := I + 4;
              NumR += SizeInt(cmp3((It - 4), @Pivot)<0);
              (OffsetsR + NumR)^ := I + 5;
              NumR += SizeInt(cmp3((It - 5), @Pivot)<0);
              (OffsetsR + NumR)^ := I + 6;
              NumR += SizeInt(cmp3((It - 6), @Pivot)<0);
              (OffsetsR + NumR)^ := I + 7;
              NumR += SizeInt(cmp3((It - 7), @Pivot)<0);
              (OffsetsR + NumR)^ := I + 8;
              NumR += SizeInt(cmp3((It - 8), @Pivot)<0);
              I += 8;
              It -= 8;
            end;
        end;
      Num := NumL;
      if NumR < NumL then
        Num := NumR;
      SwapOffsets(First, Last, OffsetsL + StartL, OffsetsR + StartR, Num, NumL = NumR);
      NumL -= Num;
      NumR -= Num;
      StartL += Num;
      StartR += Num;
      if NumL = 0 then
        First += BLOCK_SIZE;
      if NumR = 0 then
        Last -= BLOCK_SIZE;
    end;
  LSize := 0;
  RSize := 0;
  if (NumR or NumL) <> 0 then
    UnknownLeft := (Last - First) - BLOCK_SIZE
  else
    UnknownLeft := Last - First;
  if NumR <> 0 then
    begin
      LSize := UnknownLeft;
      RSize := BLOCK_SIZE;
    end
  else
    if NumL <> 0 then
      begin
        LSize := BLOCK_SIZE;
        RSize := UnknownLeft;
      end
    else
      begin
        LSize := UnknownLeft div 2;
        RSize := UnknownLeft - LSize;
      end;
  if (UnknownLeft <> 0) and (NumL = 0) then
    begin
      StartL := 0;
      It := First;
      I := 0;
      while I < LSize do
        begin
          (OffsetsL + NumL)^ := I;
          NumL += SizeInt(not cmp3(It, @Pivot)<0);
          Inc(I);
          Inc(It);
        end;
    end;
  if (UnknownLeft <> 0) and (NumR = 0) then
    begin
      StartR := 0;
      It := Last;
      I := 0;
      while I < RSize do
        begin
          Inc(I);
          Dec(It);
          (OffsetsR + NumR)^ := I;
          NumR += SizeInt(cmp3(It, @Pivot)<0);
        end;
    end;
  Num := NumL;
  if NumR < NumL then
    Num := NumR;
  SwapOffsets(First, Last, OffsetsL + StartL, OffsetsR + StartR, Num, NumL = NumR);
  NumL -= Num;
  NumR -= Num;
  StartL += Num;
  StartR += Num;
  if NumL = 0 then
    First += LSize;
  if NumR = 0 then
    Last -= RSize;
  if NumL <> 0 then
    begin
      OffsetsL += StartL;
      while NumL <> 0 do
        begin
          Dec(NumL);
          Dec(Last);
          v := (First + (OffsetsL + NumL)^)^;
          (First + (OffsetsL + NumL)^)^ := Last^;
          Last^ := v;
        end;
      First := Last;
    end;
  if NumR <> 0 then
    begin
      OffsetsR += StartR;
      while NumR <> 0 do
        begin
          Dec(NumR);
          v := (Last - (OffsetsR + NumR)^)^;
          (Last - (OffsetsR + NumR)^)^ := First^;
          First^ := v;
          Inc(First);
        end;
      Last := First;
    end;
  PivotPos := First - 1;
  aStart^ := PivotPos^;
  PivotPos^ := Pivot;
  Result := TPart.Create(PivotPos, AlreadyPartitioned);
end;

procedure TCodaMinaPDQSort4.DoPDQSort(aStart, aFinish: PItem; aBadAllowed: SizeInt; aLeftMost: Boolean;cmp3:Tcmp_func3);
var
  PivotPos: PItem;
  v: TItem;
  Size, S2, LSize, LSizeDiv, RSize, RSizeDiv: SizeInt;
  PartResult: TPart;
begin
  while True do
    begin
      Size := aFinish - aStart;
      if Size <= QUICK_INSERTION_SORT_CUTOFF then
        begin
          if aLeftMost then
            InsertionSort(aStart, (aFinish - aStart),cmp3)
          else
            UnguardInsertionSort(aStart, (aFinish - aStart),cmp3);
          exit;
        end;
      S2 := Size div 2;
      if Size > NINTHER_THRESHOLD then
        begin
          Sort3(aStart, aStart + S2, aFinish - 1,cmp3);
          Sort3(aStart + 1, aStart + (S2 - 1), aFinish - 2,cmp3);
          Sort3(aStart + 2, aStart + (S2 + 1), aFinish - 3,cmp3);
          Sort3(aStart + (S2 - 1), aStart + S2, aStart + (S2 + 1),cmp3);
          v := aStart^;
          aStart^ := (aStart + S2)^;
          (aStart + S2)^ := v;
        end
      else
        Sort3(aStart + S2, aStart, aFinish - 1,cmp3);
      if not aLeftMost and (not cmp3((aStart - 1), aStart)<0) then
        begin
          aStart := PartitionLeft(aStart, aFinish,cmp3) + 1;
          continue;
        end;

      PartResult := PartitionRight(aStart, aFinish,cmp3);

      PivotPos := PartResult.F1;
      LSize := PivotPos - aStart;
      RSize := aFinish - (PivotPos + 1);
      if (LSize < Size div 8) or (RSize < Size div 8) then
        begin
          Dec(aBadAllowed);
          if aBadAllowed = 0 then
            begin
              DoHeapSort(aStart, Pred(aFinish - aStart),cmp3);
              exit;
            end;
          if LSize > QUICK_INSERTION_SORT_CUTOFF then
            begin
              LSizeDiv := LSize div 4;
              v := aStart^;
              aStart^ := (aStart + LSizeDiv)^;
              (aStart + LSizeDiv)^ := v;
              v := (PivotPos - 1)^;
              (PivotPos - 1)^ := (PivotPos - LSizeDiv)^;
              (PivotPos - LSizeDiv)^ := v;
              if LSize > NINTHER_THRESHOLD then
                begin
                  v := (aStart + 1)^;
                  (aStart + 1)^ := (aStart + (LSizeDiv + 1))^;
                  (aStart + (LSizeDiv + 1))^ := v;
                  v := (aStart + 2)^;
                  (aStart + 2)^ := (aStart + (LSizeDiv + 2))^;
                  (aStart + (LSizeDiv + 2))^ := v;
                  v := (PivotPos - 2)^;
                  (PivotPos - 2)^ := (PivotPos - (LSizeDiv + 1))^;
                  (PivotPos - (LSizeDiv + 1))^ := v;
                  v := (PivotPos - 3)^;
                  (PivotPos - 3)^ := (PivotPos - (LSizeDiv + 2))^;
                  (PivotPos - (LSizeDiv + 2))^ := v;
                end;
            end;
          if RSize > QUICK_INSERTION_SORT_CUTOFF then
            begin
              RSizeDiv := RSize div 4;
              v := (PivotPos + 1)^;
              (PivotPos + 1)^ := (PivotPos + (1 + RSizeDiv))^;
              (PivotPos + (1 + RSizeDiv))^ := v;
              v := (aFinish - 1)^;
              (aFinish - 1)^ := (aFinish - RSizeDiv)^;
              (aFinish - RSizeDiv)^ := v;
              if RSize > NINTHER_THRESHOLD then
                begin
                  v := (PivotPos + 2)^;
                  (PivotPos + 2)^ := (PivotPos + (2 + RSizeDiv))^;
                  (PivotPos + (2 + RSizeDiv))^ := v;
                  v := (PivotPos + 3)^;
                  (PivotPos + 3)^ := (PivotPos + (3 + RSizeDiv))^;
                  (PivotPos + (3 + RSizeDiv))^ := v;
                  v := (aFinish - 2)^;
                  (aFinish - 2)^ := (aFinish - (1 + RSizeDiv))^;
                  (aFinish - (1 + RSizeDiv))^ := v;
                  v := (aFinish - 3)^;
                  (aFinish - 3)^ := (aFinish - (2 + RSizeDiv))^;
                  (aFinish - (2 + RSizeDiv))^ := v;
                end;
            end;
        end
      else
        if PartResult.F2 and PartialInsertionSort(aStart, PivotPos,cmp3) and
           PartialInsertionSort(PivotPos + 1, aFinish,cmp3) then exit;
      DoPDQSort(aStart, PivotPos, aBadAllowed, aLeftMost,cmp3);
      aStart := PivotPos + 1;
      aLeftMost := False;
    end;
end;

function TCodaMinaPDQSort4.PartialInsertionSort(aStart, aFinish: PItem;cmp3:Tcmp_func3): Boolean;
var
  Limit: SizeInt;
  Curr, Sift: PItem;
  v: TItem;
begin
  if aStart = aFinish then exit(True);
  Limit := 0;
  Curr := aStart + 1;
  while Curr <> aFinish do
    begin
      if Limit > PARTIAL_INSERTION_SORT_LIMIT then exit(False);
      Sift := Curr;
      if cmp3(Sift, (Sift - 1))<0 then
        begin
          v := Sift^;
          repeat
            Sift^ := (Sift - 1)^;
            Dec(Sift);
          until (Sift = aStart) or (not cmp3(@v, (Sift - 1))<0);
          Sift^ := v;
          Limit += Curr - Sift;
        end;
      Inc(Curr);
    end;
  Result := True;
end;

function TCodaMinaPDQSort4.PartitionLeft(aStart, aFinish: PItem;cmp3:Tcmp_func3): PItem;
var
  Pivot: TItem;
  v: TItem;
  First, Last, PivotPos: PItem;
begin
  Pivot := aStart^;
  First := aStart;
  Last := aFinish;
  repeat Dec(Last) until (not cmp3(@Pivot, Last)<0);
  if Last + 1 = aFinish then
    while First < Last do
      begin
        Inc(First);
        if cmp3(@Pivot, First)<0 then
          break;
      end
  else
    repeat Inc(First) until cmp3(@Pivot, First)<0;

  while First < Last do
    begin
      v := First^;
      First^ := Last^;
      Last^ := v;
      repeat Dec(Last) until (not cmp3(@Pivot, Last)<0);
      repeat Inc(First) until cmp3(@Pivot, First)<0;
    end;
  PivotPos := Last;
  aStart^ := PivotPos^;
  PivotPos^ := Pivot;
  Result := PivotPos;
end;
function TCodaMinaPDQSort4.BsrSizeUInt(aValue: SizeUInt): ShortInt;
begin
{$IF DEFINED(CPU64)}
  Result := ShortInt(BsrQWord(aValue));
{$ELSEIF DEFINED(CPU32)}
  Result := ShortInt(BsrDWord(aValue));
{$ELSE}
  Result := ShortInt(BsrWord(aValue));
{$ENDIF}
end;
function TCodaMinaPDQSort4.NSB(aValue: SizeUInt): SizeInt;
begin
  Result := Succ(BsrSizeUInt(aValue));
end;
procedure TCodaMinaPDQSort4.PDQSort(aStart, aFinish: PItem;cmp3:Tcmp_func3);
begin
  DoPDQSort(aStart, aFinish, Succ(NSB(aFinish - aStart)), True,cmp3);
end;
procedure TCodaMinaPDQSort4.InsertionSort(A: PItem; R: SizeInt;cmp3:Tcmp_func3);
var
  I, J: SizeInt;
  v: TItem;
begin
  for I := 1 to R do
    if cmp3(@A[I], @A[I-1])<0 then
      begin
        J := I;
        v := A[I];
        repeat
          A[J] := A[J-1];
          Dec(J);
        until (J = 0) or (not cmp3(@v, @A[J-1])<0);
        A[J] := v;
      end;
end;

procedure TCodaMinaPDQSort4.UnguardInsertionSort(A: PItem; R: SizeInt;cmp3:Tcmp_func3);
var
  I, J: SizeInt;
  v: TItem;
begin
  for I := 1 to R do
    if cmp3(@A[I], @A[I-1])<0 then
      begin
        J := I;
        v := A[I];
        repeat
          A[J] := A[J-1];
          Dec(J);
        until (not cmp3(@v, @A[J-1])<0);
        A[J] := v;
      end;
end;

procedure TCodaMinaPDQSort4.DoHeapSort(A: PItem; R: SizeInt;cmp3:Tcmp_func3);
var
  I, Curr, Next: SizeInt;
  v: TItem;
begin
  if R > HEAP_INSERTION_SORT_CUTOFF then
    begin
      for I := Pred(Succ(R) shr 1) downto 0 do
        begin
          Curr := I;
          Next := Succ(I shl 1);
          v := A[Curr];
          while Next <= R do
            begin
              if(Next < R) and (cmp3(@A[Next], @A[Succ(Next)])<0) then
                Inc(Next);
              if not (cmp3(@v, @A[Next])<0) then
                break;
              A[Curr] := A[Next];
              Curr := Next;
              Next := Succ(Next shl 1);
            end;
          A[Curr] := v;
        end;
      for I := R downto 1 do
        begin
          Curr := 0;
          Next := 1;
          v := A[I];
          A[I] := A[0];
          while Next < I do
            begin
              if(Succ(Next) < I) and (cmp3(@A[Next], @A[Succ(Next)])<0) then
                Inc(Next);
              A[Curr] := A[Next];
              Curr := Next;
              Next := Succ(Next shl 1);
            end;
          Next := Pred(Curr) shr 1;
          while (Curr > 0) and (cmp3(@A[Next], @v)<0) do
            begin
              A[Curr] := A[Next];
              Curr := Next;
              Next := Pred(Next) shr 1;
            end;
          A[Curr] := v;
        end;
    end
  else
    InsertionSort(A, R,cmp3);
end;
procedure TCodaMinaPDQSort4.PDQSort(var A: array of TItem;cmp3:Tcmp_func3);
var
  R: SizeInt;
begin
  R := System.High(A);
  PDQSort(@A[0], (@A[R]),cmp3);
end;
end.

