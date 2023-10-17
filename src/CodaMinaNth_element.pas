{
  publish with BSD Licence.
	Copyright (c) Terry Lao
}
unit CodaMinaNth_element;
{$mode objfpc}{$H+}
interface
uses
  Types,math,testtype;
type
  generic TCodaMinaNth_element<T> = class
  type
	  PT = ^T;
    TCMP = function (T1,T2:PT):integer of object;
		TCHK = function (T2:PT):integer of object;
    public
      procedure nth_element(inputArray: PT; nth_el: int64;  left: int64;  right: int64; cmp: TCMP);
    private
      
  end;

implementation

procedure TCodaMinaNth_element.nth_element(inputArray: PT; nth_el: int64;  left: int64;  right: int64; cmp: TCMP);
var
  i,j:int64;
  ll,rr:int64;
	t1,t2:T;
	n64,i64,z64,s64,sn64,sd64,isn64,inner64:double;
        itest:integer;
begin
  while right > left do
	begin
    if right - left > 600 then
		begin
      // Use recursion on a sample of size s to get an estimate
      // for the (nth_el - left + 1 )-th smallest elementh into a[nth_el],
      // biased slightly so that the (nth_el - left + 1)-th element is expected
      // to lie in the smallest set after partitioning.
      n64  := (right - left + 1);
      i64  := (nth_el - left + 1);
      z64  := ln(n64);
      s64  := exp(0.5 * (z64 * (2.0 / 3.0)));
      sn64 := s64 / n64;
			if (i64 - n64 * 0.5) > 0 then
			begin
        sd64 := 0.5 * sqrt((z64 * s64 * (1.0 - sn64)));
      end
			else
			begin
				sd64 := 0.5 * sqrt((z64 * s64 * (1.0 - sn64)))*-1;
			end;
      isn64   := i64 * s64 / n64;
      inner64 := nth_el - isn64 + sd64;
      ll:= max(left, floor(inner64));
      rr:= min(right, floor(inner64 + s64));
      nth_element(inputArray, nth_el, ll, rr, cmp);
    end;
    // The following code partitions a[l : r] about t, it is similar to Hoare's
    // algorithm but it'll run faster on most machines since the subscript range
    // checking on i and j has been removed.
    i := left;
    j := right;
		t2 := inputArray[nth_el];
    inputArray[nth_el] := inputArray[left];
		inputArray[left] := t2;

    if cmp(@inputArray[right], @t2) > 0  then
		begin
  		t1 := inputArray[left];
  		inputArray[left] := inputArray[right];
  		inputArray[right] := t1;
    end;
    while i < j do
    begin
  		t1 := inputArray[i];
  		inputArray[i] := inputArray[j];
  		inputArray[j] := t1;
      inc(i);
      dec(j);
      while (cmp(@inputArray[i], @t2) < 0 ) do
      begin
        inc(i);
      end;
      while (cmp(@inputArray[j], @t2) > 0)  do
      begin
        dec(j);
      end;
    end;
    if cmp(@inputArray[left], @t2) = 0 then
		begin
  		t1 := inputArray[left];
  		inputArray[left] := inputArray[j];
  		inputArray[j] := t1;
    end
		else
		begin
      inc(j);
  		t1 := inputArray[right];
  		inputArray[right] := inputArray[j];
  		inputArray[j] := t1;
    end;
    // Now we adjust left and right so that they
    // surround the subset containing the
    // (k - left + 1)-th smallest element.
    if j <= nth_el then
		begin
      left := j + 1;
    end;
    if nth_el <= j then
		begin
      right := j - 1 ;
    end;
  end;
end;

end.
