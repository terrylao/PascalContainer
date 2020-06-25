{
  publish with BSD Licence.
	Copyright (c) Terry Lao
}
unit genericCodaMinaSort;
{$mode ObjFPC}{$H+}
interface
uses Classes, SysUtils,math;
  const INSERTIONTHRESHOLD=33;// 33 is an magic number
TYPE
  CompPointerFunc = function(A,B:pbyte):integer;
  generic TCodaMinaArraySortFunction<T>=class
  type
    tCompFunc = function(A,B:T):integer;
    pt=^t;
    pthreadrec = ^Tthreadrec;
    Tthreadrec=record
    arr:pt;
    l,r:integer;
    cmp:tCompFunc;
    end;
  protected
    {for parallel sort}
    maxthreads:integer;
    part:integer;
    dataLength:integer;
    dataCmp:tCompFunc;
    threadedarray:pt;
    {end for parallel sort}
    function min(x,y:integer):integer;
    procedure merge(arr:pT; l, m, r:integer;cmp: tCompFunc);
		procedure mergeInPlace(arr:pt;l, m, r:integer;cmp: tCompFunc);
		procedure merge2(arr:pT; l, m, r:integer;cmp: tCompFunc);
    procedure swap(a,b:pt);
    function partition2(arr:pT;  l,  h:integer;cmp: tCompFunc):integer;
    function DualPivotpartition(arr:PT; low, high:integer;lp:pinteger;cmp:tCompFunc ):integer;
    procedure partition3way(arr:pT;  l,  h:integer; var i,j:integer;cmp: tCompFunc);
    function MedianOf3(a, b, c:pT;cmp:tCompFunc):T;
    function MedianOf5(arr:pt; l,r: integer;cmp:tCompFunc ):T;
    procedure radix_sort_pass(src, dst:pt; n, shift:integer; shrfunc:tCompFunc);
  public
    procedure insertionsort     (arr:pT; Left, Right :Integer; cmp:tCompFunc);
    Procedure QuickSort         (arr:pT; Left, Right :Integer; cmp:tCompFunc);
    Procedure DualPivotQuickSort(arr:pT; Left, Right : Integer;cmp:tCompFunc);
    procedure quicksort3PivotBasic(arr:pT; lo, hi : Integer;cmp:tCompFunc);
    Procedure ShellSort         (arr:pT; Left, Right :Integer; cmp:tCompFunc);
    procedure mergesort         (arr:pT; Left, Right :integer; cmp:tCompFunc);
    procedure IterativeQuickSort(arr:pT; Left, Right :integer; cmp:tCompFunc);
    procedure IterativemergeSort2(arr:pT; Left, Right :integer; cmp:tCompFunc);
    procedure quicksort3way(arr:pT;  l,  h:integer;cmp: tCompFunc);
    procedure threadQuickSort(p:pointer );  
    function parallelQuickSort (arr:pT; Left, Right,threadCount : Integer;cmp:tCompFunc;threadQuickSortCaller:TThreadFunc):integer;
    function  parallelMergeSortStart(arr:pT;  MAX,m:integer;cmp: tCompFunc):boolean;
    function parallelMergeSortForThread():integer;
    procedure parallelMergeSortEnd();
    procedure radix_sort(a, temp:pt;  n:integer; shrfunc:tCompFunc);
  end;

implementation

procedure TCodaMinaArraySortFunction.insertionsort(arr:pT;Left, Right : Integer;cmp:tCompFunc);
var
  i, j: integer;
  ch: T;
begin
  for i:= Left+1 to right do 
  begin
    ch:= arr[i];
    j:= i - 1;
    while (j >= Left) and (cmp(arr[j] , ch)>0) do 
    begin
      arr[j + 1]:= arr[j];
      dec(j);
    end;
    arr[j + 1]:= ch;
  end;
end;
function TCodaMinaArraySortFunction.MedianOf5(arr:pt; l,r: integer;cmp:tCompFunc ):T;
var
  i,n:integer;
  temp,temp1:array[0..4] of T;
  k:T;
begin 
	n:=(r-l+1) div 5;
	i:=0;
  temp[i]:=arr[l];
  temp1[i]:=arr[l];
  inc(i);
  temp[i]:=arr[l+n];
  temp1[i]:=arr[l+n];
  inc(i);
  temp[i]:=arr[l+n*2];
  temp1[i]:=arr[l+n*2];
  inc(i);
  temp[i]:=arr[l+n*3];
  temp1[i]:=arr[l+n*3];
  inc(i);
  temp[i]:=arr[r];
  temp1[i]:=arr[r];
  insertionSort(temp1,0,4,cmp);
  k:=temp1[3];
  i:=0;
  if cmp(temp[i],k)=0 then
  begin
    swap(@arr[l],@arr[r]);
    exit(k);
  end;
  inc(i);
  if cmp(temp[i],k)=0 then
  begin
    swap(@arr[l+n],@arr[r]);
    exit(k);
  end;
  inc(i);
  if cmp(temp[i],k)=0 then
  begin
    swap(@arr[l+n*2],@arr[r]);
    exit(k);
  end;
  inc(i);
  if cmp(temp[i],k)=0 then
  begin
    swap(@arr[l+n*3],@arr[r]);
    exit(k);
  end;
  result:=k;
end;
function TCodaMinaArraySortFunction.MedianOf3(a, b, c:pT;cmp:tCompFunc):T; 
begin
  
  if (cmp( a^ , b^ )<0) and (cmp( b^ , c^)<0) then
	begin 
		swap(b,c);
    exit (c^); 
  end;
  if (cmp(a^ , c^)<0) and (cmp(c^ , b^)<=0) then
	begin 
    exit (c^); 
  end;
  if (cmp(b^ , a^)<=0) and (cmp(a^ , c^)<0) then
	begin
		swap(a,c); 
    exit (c^); 
  end;
  if (cmp(b^ , c^)<0) and (cmp(c^ , a^)<=0) then
	begin 
    exit (c^); 
  end;
  if (cmp(c^ , a^)<=0) and (cmp(a^ , b^)<0) then
	begin
		swap(a,c); 
    exit (c^); 
  end;
  if (cmp(c^ , b^)<=0) and (cmp(b^ , a^)<=0) then
	begin
		swap(b,c); 
    exit (c^);
	end; 
end;
Procedure TCodaMinaArraySortFunction.threadQuickSort(p:pointer );
var
  threadrec:pthreadrec;
begin
  threadrec:=pthreadrec(p);
  QuickSort(threadrec^.arr,threadrec^.l,threadrec^.r,threadrec^.cmp);
  writeln(stdout,'threadQuickSort done');
end;
Procedure TCodaMinaArraySortFunction.QuickSort(arr:pT; Left, Right : Integer;cmp:tCompFunc );
Var 
  i, j:integer;
  tmp, pivot : T;
Begin
  i:=Left;
  j:=Right;
  if right-left+1 <INSERTIONTHRESHOLD then
  begin
    insertionsort(arr,Left, Right,cmp);
    exit;
  end;
  pivot :=MedianOf3(@arr[left],@arr[(Left + Right) shr 1],@arr[Right],cmp);
  //pivot :=MedianOf5(arr,Left,Right,cmp);

  Repeat
    While cmp(pivot , arr[i]) >0 Do inc(i);   // i:=i+1;
    While cmp(pivot , arr[j]) <0 Do dec(j);   // j:=j-1;
    If i<=j Then Begin
      tmp:=arr[i];
      arr[i]:=arr[j];
      arr[j]:=tmp;
      dec(j);   // j:=j-1;
      inc(i);   // i:=i+1;
    End;
  Until i>j;
  If Left<j Then QuickSort(arr,Left,j,cmp);
  If i<Right Then QuickSort(arr,i,Right,cmp);
End;
Procedure TCodaMinaArraySortFunction.DualPivotQuickSort(arr:pT; Left, Right : Integer;cmp:tCompFunc );
var
  lp, rp:integer;
begin
  if right-left+1 <INSERTIONTHRESHOLD then
  begin
    insertionsort(arr,Left, Right,cmp);
    exit;
  end;
  if (Left < Right) then
  begin
      // lp means left pivot, and rp means right pivot.  
      rp := DualPivotpartition(arr, Left, Right, @lp,cmp);  
      DualPivotQuickSort(arr, Left, lp - 1,cmp);  
      DualPivotQuickSort(arr, lp + 1, rp - 1,cmp);  
      DualPivotQuickSort(arr, rp + 1, Right,cmp);  
  end;
end;
//from integer to generic, with 10M integer array, increase more than 700ms with no optimize
procedure TCodaMinaArraySortFunction.quicksort3PivotBasic(arr:pT; lo, hi : Integer;cmp:tCompFunc );
var
  ilength,midpoint,a,b,c,d:integer;
  tmp,p,q,r:T;
begin
	ilength := hi - lo + 1;
	if (ilength < INSERTIONTHRESHOLD) then
	begin
    if (ilength > 1) then
    begin
	    insertionsort(arr, lo, hi,cmp);
    end;
    exit;
	end;

	midpoint := (lo + hi) shr 1;
	// insertion sort lo,mid,hi elements
	if cmp(arr[midpoint] , arr[lo])<0 then
	begin 
	  tmp := arr[midpoint]; 
	  arr[midpoint] := arr[lo]; 
	  arr[lo] := tmp; 
	end;
  if cmp(arr[hi] , arr[midpoint])<0 then
  begin 
    tmp := arr[hi]; 
    arr[hi] := arr[midpoint]; 
    arr[midpoint] := tmp;
    if cmp(tmp , arr[lo])<0 then
    begin 
      arr[midpoint] := arr[lo]; 
      arr[lo] := tmp; 
    end;
  end;
		
	p := arr[lo];
	q := arr[midpoint];
	r := arr[hi];
	// p,q & r are now sorted, place them at arr[lo], arr[lo+1] & arr[hi]
	swap(@arr[lo+1],  @arr[midpoint]);
		
	// Pointers a and b initially point to the first element of the array while c
	// and d initially point to the last element of the array.
	a := lo + 2;
	b := lo + 2;
	c := hi - 1;
	d := hi - 1;

	while (b <= c) do
	begin
    while (cmp(arr[b] , q)<0) and (b <= c) do
    begin
      if (cmp(arr[b] , p)<0) then
      begin
		    swap(@arr[a], @arr[b]);
		    inc(a);
      end;
      inc(b);
    end;
    while (cmp(arr[c] , q)>0) and (b <= c) do
    begin
      if cmp(arr[c] , r)>0 then
      begin
		    swap(@arr[c], @arr[d]);
		    dec(d);
		  end;
      dec(c);
    end;
    if (b <= c) then
    begin
      if cmp(arr[b] , r)>0 then
      begin
		    if cmp(arr[c] , p)<0 then
		    begin
          swap(@arr[b], @arr[a]); swap(@arr[a], @arr[c]);
          inc(a);
		    end 
		    else 
		    begin
          swap(@arr[b], @arr[c]);
		    end;
		    swap(@arr[c], @arr[d]);
		    inc(b); 
		    dec(c); 
		    dec(d);
      end 
      else 
      begin
        if cmp(arr[c] , p)<0 then
        begin
          swap(@arr[b], @arr[a]); 
          swap(@arr[a], @arr[c]);
          inc(a);
        end 
        else 
        begin
          swap(@arr[b], @arr[c]);
        end;
        inc(b); 
        dec(c);
      end;
    end;
	end;
	// swap the pivots to their correct positions
	dec(a); 
	dec(b); 
	inc(c); 
	inc(d);
	swap(@arr[lo + 1], @arr[a]); 
	swap(@arr[a], @arr[b]);
	dec(a);
	swap(@arr[lo], @arr[a]);
	swap(@arr[hi], @arr[d]);

	quicksort3PivotBasic(arr,lo , a-1,cmp);
	quicksort3PivotBasic(arr,a+1, b-1,cmp);
	quicksort3PivotBasic(arr,b+1, d-1,cmp);
	quicksort3PivotBasic(arr,d+1, hi ,cmp);	
end;

function TCodaMinaArraySortFunction.DualPivotpartition(arr:PT; low, high:integer;lp:pinteger;cmp:tCompFunc ):integer;
var
  j,g,k:integer; 
  p,q:T;
begin
    if cmp(arr[low] , arr[high])>0 then
        swap(@arr[low], @arr[high]);  
      
    // p is the left pivot, and q is the right pivot.  
    j := low + 1;  
    g := high - 1;
    k := low + 1;
    p := arr[low];
    q := arr[high];  
    while (k <= g) do
    begin
  
      // if elements are less than the left pivot  
      if cmp(arr[k] , p)<0 then  
      begin  
          swap(@arr[k], @arr[j]);  
          inc(j);  
      end  
      else 
      // if elements are greater than or equal  
      // to the right pivot
      if cmp(arr[k] , q)>=0 then  
      begin
        while (cmp(arr[g] , q)>0) and (k < g) do  
          dec(g);
        swap(@arr[k], @arr[g]);  
        dec(g);
        if cmp(arr[k] , p)<0 then
        begin  
          swap(@arr[k], @arr[j]);  
          inc(j); 
        end;  
      end;  
      inc(k);
    end;
    dec(j);  
    inc(g);  
  
    // bring pivots to their appropriate positions.  
    swap(@arr[low] , @arr[j]);  
    swap(@arr[high], @arr[g]);  
  
    // returning the indices of the pivots.  
    lp^ := j; // because we cannot return two elements  
            // from a function.  
  
    result := g;  
end;
Procedure TCodaMinaArraySortFunction.ShellSort( arr:pT; Left, Right : Integer; cmp:tCompFunc );
Var
  i, j, step,  n : Integer;
  tmp:T;
begin
  n:=right-left+1;
  step:= n div 2;  // step:=step shr 1
  while step>0 do 
  begin
    for i:=step+left to Right do 
    begin
      tmp:=arr[i];
      j:=i;
      while (j>=step) and (cmp(arr[j-step],tmp)>0) do 
      begin
        arr[j]:=arr[j-step];
        dec(j,step);
      end;
      arr[j]:=tmp;
    end;
    step:=step div 2;  // step:=step shr 1
  end;
End;
{ l is for left index and r is right index of the 
   sub-array of arr to be sorted }
procedure TCodaMinaArraySortFunction.mergeSort(arr:pT;left,right:integer;cmp: tCompFunc);
var
  m:integer;
begin
    //mixed with insertion sort, almost same as quicksort wiht insertion sort
    if right-left+1 <INSERTIONTHRESHOLD then 
    begin
      insertionsort(arr,Left, Right,cmp);
      exit;
    end;
    if (left < right) then 
    begin 
      // Same as (l+r)/2, but avoids overflow for 
      // large l and h 
      m := left+(right-left) div 2;
  
      // Sort first and second halves 
      mergeSort(arr, left, m,cmp); 
      mergeSort(arr, m+1, right,cmp); 
      merge(arr, left, m, right,cmp);//O(nlgn)

      //mergeInPlace(arr, left, m, right,cmp);//O(n^2)
    end;
end;
// Utility function to find minimum of two integers 
function TCodaMinaArraySortFunction.min(x,y:integer):integer;
begin
  if (x<y) then
   result := x
  else
   result := y; 
end; 
  
//===============Iterative Sort Function==============
procedure TCodaMinaArraySortFunction.IterativemergeSort2(arr:pT;left,right:integer;cmp: tCompFunc);
var
  k,l:integer;
begin
  k := 1;
  while k < right-left+1 do
  begin
    l := 0;
    while l < right-left+1 do
    begin
      merge2(arr, l, min(l + k, right-left+1), min(l + 2 * k, right-left+1),cmp);
      l :=l + 2 * k;
    end;
    k := 2 * k;
  end;
end;
// Merges two subarrays of arr[]. 
// First subarray is arr[l..m] 
// Second subarray is arr[m+1..r] 
// Inplace Implementation  -- O(n^2)
procedure TCodaMinaArraySortFunction.mergeInPlace(arr:pt;l, m, r:integer;cmp: tCompFunc);
var
  index,start2:integer;
	value:T;
begin
    start2 := m + 1; 
  
    // If the direct merge is already sorted 
    if (cmp(arr[m] , arr[start2])<=0) then
		begin 
        exit; 
    end;
  
    // Two pointers to maintain start 
    // of both arrays to merge 
    while (l <= m) and (start2 <= r) do
		begin 
  
      // If element 1 is in right place 
      if (cmp(arr[l] , arr[start2])<=0) then
			begin 
          inc(l); 
      end
      else
			begin
        value := arr[start2]; 
        index := start2; 
  
        // Shift all the elements between element 1 
        // element 2, right by 1. 
        while (index <> l) do
				begin
            arr[index] := arr[index - 1]; 
            dec(index); 
        end;
        arr[l] := value; 
  
        // Update all the pointers 
        inc(l); 
        inc(m); 
        inc(start2); 
      end;
    end;
end;

procedure TCodaMinaArraySortFunction.merge2(arr:pT; l, m, r:integer;cmp: tCompFunc);
var
  first,second,i:integer;
  work:array of T;
begin
  first  := l;
  second := m;
  setlength(work,r-l);

  for i := 0 to r - l -1 do
  begin
    if (first < m) and ((second >= r) or (cmp(arr[first] ,arr[second])<=0)) then
    begin
      work[i] := arr[first];
      inc(first);
    end
    else
    begin
      work[i] := arr[second];
      inc(second);
    end;
  end;
  move(work[0],arr[l],(r-l)*sizeof(T));
  setlength(work,0);
end;
//* Function to merge the two haves arr[l..m] and arr[m+1..r] of array arr[] */
procedure TCodaMinaArraySortFunction.merge(arr:pT; l, m, r:integer;cmp: tCompFunc);
var
   i, j, k, n1, n2:integer;
   bL,bR:array of T;
begin

  n1 := m - l + 1; 
  n2 :=  r - m ;

  //* create temp arrays */
  setlength(bL,n1);
  setlength(bR,n2); 
  
  //* Copy data to temp arrays bL[] and bR[] */
  for i := 0 to  n1 - 1 do 
      bL[i] := arr[l + i]; 
  for j := 0 to  n2 -1 do 
      bR[j] := arr[m + 1+ j]; 
  
  //* Merge the temp arrays back into arr[l..r]*/
  i := 0; 
  j := 0; 
  k := l; 
  while (i < n1) and (j < n2) do
  begin
      if (cmp(bL[i] , bR[j])<=0) then 
      begin
          arr[k] := bL[i]; 
          inc(i); 
      end
      else
      begin
          arr[k] := bR[j]; 
          inc(j); 
      end;
      inc(k); 
  end;
  
  //* Copy the remaining elements of bL[], if there are any */
  while (i < n1) do
  begin
      arr[k] := bL[i]; 
      inc(i); 
      inc(k); 
  end;
  
  //* Copy the remaining elements of bR[], if there are any */
  while (j < n2) do
  begin
      arr[k] := bR[j]; 
      inc(j); 
      inc(k); 
  end;
  setlength(bL,0);
  setlength(bR,0);
end;
// A utility function to swap two elements 
procedure TCodaMinaArraySortFunction.swap(a,b:pT);
var
  tmp:T; 
begin
   tmp := a^; 
  a^ := b^; 
  b^ := tmp; 
end;
  
function TCodaMinaArraySortFunction.partition2(arr:pT;  l,  h:integer;cmp: tCompFunc):integer;
var
  i,pIndex:integer;
  pivot:T;
begin
  if (h-l+1)>10 then
  begin
    pivot :=MedianOf3(@arr[l],@arr[(l + h) shr 1],@arr[h],cmp);
  end
  else
  begin
    pivot := arr[h];
  end; 
  //pivot  := arr[h]; //rightmost element is the pivot
  pIndex := l;  //Is to push elements less than pivot to left and greater than to right of pivot
  for  i := l  to h -1 do
  begin
    if (cmp(arr[i] , pivot)<=0) then
    begin
      swap(@arr[i],@arr[pIndex]);
      inc(pIndex);
    end;
  end;
  swap(@arr[pIndex], @arr[h]);
  result := pIndex;
end;
 
{ A[] --> Array to be sorted,  
   l  --> Starting index,  
   h  --> Ending index }
procedure TCodaMinaArraySortFunction.IterativequickSort(arr:pT; Left, Right:integer;cmp: tCompFunc);
var
  stack:array of Integer;
  p,top:integer;
begin 
  // Create an auxiliary stack 
  setlength(stack,Right - Left + 1); 
  
  // initialize top of stack 
  top := -1; 
  
  // push initial values of l and h to stack 
  inc(top);
  stack[top] := Left;
  inc(top); 
  stack[top] := Right; 
  
  // Keep popping from stack while is not empty 
  while (top >= 0) do
  begin 
    // Pop h and l 
    Right := stack[top];
    dec(top); 
    Left := stack[top]; 
    dec(top);
    // Set pivot element at its correct position 
    // in sorted array 
    p := partition2(arr, Left, Right,cmp); 
  
    // If there are elements on left side of pivot, 
    // then push left side to stack 
    if (p - 1 > Left) then
    begin
      inc(top);
      stack[top] := Left;
      inc(top); 
      stack[top] := p - 1; 
    end;
  
    // If there are elements on right side of pivot, 
    // then push right side to stack 
    if (p + 1 < Right) then
    begin
      inc(top); 
      stack[top] := p + 1;
      inc(top); 
      stack[top] := Right; 
    end;
  end;
  setlength(stack,0);
end;

{ 
This function partitions a[] in three parts 
a) a[l..i] contains all elements smaller than pivot 
b) a[i+1..j-1] contains all occurrences of pivot 
c) a[j..r] contains all elements greater than pivot 
}
  
//It uses Dutch National Flag Algorithm 
procedure TCodaMinaArraySortFunction.partition3way(arr:pT;  l,  h:integer; var i,j:integer;cmp: tCompFunc);
var
  mid:integer;
  pivot:T; 
begin
    // To handle 2 elements 
    if (h - l <= 1) then
    begin
      if (cmp(arr[h] , arr[l])<0) then
          swap(@arr[h], @arr[l]);
      i := l; 
      j := h;
      exit;
    end;
		
    mid   := l; 
		if h-l+1>10 then
		begin
		  pivot :=MedianOf3(@arr[l],@arr[(l + h) shr 1],@arr[h],cmp);
		end
		else
		begin
      pivot := arr[h];
		end;
    while (mid <= h) do
    begin
        if (cmp(arr[mid],pivot)<0)  then
        begin
          swap(@arr[l], @arr[mid]);
          inc(l);
          inc(mid);
        end 
        else 
        if (cmp(arr[mid],pivot)=0) then
        begin 
            inc(mid);
        end 
        else 
        if (cmp(arr[mid],pivot)>0) then
        begin
          swap(@arr[mid], @arr[h]);
          dec(h);
        end; 
    end;
  
    //update i and j 
    i := l-1; 
    j := mid ; //or h-1
end;
  
// 3-way partition based quick sort ** not faster than original quicksort **
procedure TCodaMinaArraySortFunction.quicksort3way(arr:pT;  l,  h:integer;cmp: tCompFunc);
var
  i,j:integer; 
begin
  if (l>=h) then//1 or 0 elements 
    exit; 
  if h-l+1 <INSERTIONTHRESHOLD then
  begin
    insertionsort(arr,l, h,cmp);
    exit;
  end;
  // Note that i and j are passed as reference 
  partition3way(arr, l, h, i, j,cmp); 
  
  // Recur two halves 
  quicksort3way(arr, l, i,cmp); 
  quicksort3way(arr, j, h,cmp); 
end;
function TCodaMinaArraySortFunction.parallelQuickSort(arr:pT; Left, Right,threadCount : Integer;cmp:tCompFunc;threadQuickSortCaller:TThreadFunc):integer;
Var 
  top,i, j,lleft,lright:integer;
  tmp, pivot : T;
  stack:array of tthreadrec;
  threadhandle:array of integer;
Begin
  if (right-left+1)<1000000 then
    exit(-1);

  setlength(stack,threadcount);
  setlength(threadhandle,threadcount);
  
  top:=-1;
  inc(top);
  stack[top].arr:=arr;
  stack[top].cmp:=cmp;
  stack[top].l:=left;
  stack[top].r:=right;
  while (top>=0) and (top<threadcount) do
  begin
    j:=stack[top].r;
    lright:=j;
    i:=stack[top].l;
    lleft:=i;
    dec(top);
    pivot :=MedianOf3(@arr[lLeft],@arr[(lLeft + lright) shr 1],@arr[lright],cmp);
    Repeat
      While cmp(pivot , arr[i]) >0 Do inc(i);   // i:=i+1;
      While cmp(pivot , arr[j]) <0 Do dec(j);   // j:=j-1;
      If i<=j Then Begin
        tmp:=arr[i];
        arr[i]:=arr[j];
        arr[j]:=tmp;
        dec(j);   // j:=j-1;
        inc(i);   // i:=i+1;
      End;
    Until i>j;
    If lLeft<j Then
    begin
      inc(top);
      stack[top].arr:=arr;
      stack[top].cmp:=cmp;
      stack[top].l:=lLeft;
      stack[top].r:=j;
      
    end;
    If i<lRight Then
    begin
      inc(top);
      stack[top].arr:=arr;
      stack[top].cmp:=cmp;
      stack[top].l:=i;
      stack[top].r:=lright;
      
    end;
  end;
  stack[top-1].r:=right;
 for i:=0 to high(threadhandle) do
     threadhandle[i]:=BeginThread(threadQuickSortCaller,@stack[i]);
 for i:=0 to high(threadhandle) do
     WaitForThreadTerminate(threadhandle[i],2000);
 writeln(stdout,'parallelQuickSort done'); 
 setlength(stack,0);
End;
// Ex: MAX=20, thread count = 4
function TCodaMinaArraySortFunction.parallelMergeSortStart(arr:pT;  MAX,m:integer;cmp: tCompFunc):boolean;
begin
  if MAX mod m <> 0 then
    exit(false);
  
  maxthreads:=m;
  part:=0;
  dataLength:=MAX;
  dataCmp:=cmp;
  threadedarray:=arr;
  writeln(stdout,'start: MAX:',dataLength,' threads:',maxthreads);
  result:=true;
end;
function TCodaMinaArraySortFunction.parallelMergeSortForThread():integer;
var
  thread_part,low,high,mid : integer;
begin
  // which part out of parts 
  thread_part := part;
  inc(part); 

  // calculating low and high 
  low  := thread_part * (dataLength div maxthreads);
  high := (thread_part + 1) * (dataLength div maxthreads) - 1;
  
  // evaluating mid point 
  mid := low + (high - low) div 2;
  if (low < high) then
  begin 
    //mergeSort(threadedarray,low, mid,dataCmp); 
    //mergeSort(threadedarray,mid + 1, high,dataCmp); 
    //merge(threadedarray,low, mid, high,dataCmp);
    
    //faster than above?
    IterativemergeSort2(threadedarray,low, mid,dataCmp); 
    IterativemergeSort2(threadedarray,mid + 1, high,dataCmp); 
    merge2(threadedarray,low, mid, high,dataCmp); 
  end;
  result := 0;
end;
procedure TCodaMinaArraySortFunction.parallelMergeSortEnd();
begin
  // merging the final parts 
  writeln(stdout,'dataLength:',dataLength);
  merge(threadedarray,0, (dataLength div 2 - 1) div 2, dataLength div 2 - 1,dataCmp); 
  merge(threadedarray,dataLength div 2, dataLength div 2 + (dataLength-1-dataLength div 2) div 2, dataLength - 1,dataCmp); 
  merge(threadedarray,0, (dataLength - 1) div 2, dataLength - 1,dataCmp); 
end;
// shrfunc(src[i],shift) = (src[i] shr shift) and $ff
procedure TCodaMinaArraySortFunction.radix_sort_pass(src, dst:pt; n, shift:integer;shrfunc: tCompFunc);
var
  i,next_index,count:integer;
  index:array [0..255] of integer;
begin
    next_index := 0;
    fillbyte(index[0],sizeof(index),0);
    for i := 0 to n-1 do 
      inc(index[shrfunc(src[i],shift)]);
    for i := 0 to 255 do
    begin
        count := index[i];
        index[i] := next_index;
        next_index :=next_index + count;
    end;
    for i := 0 to n-1 do 
    begin
      dst[index[shrfunc(src[i],shift)]] := src[i];
      inc(index[shrfunc(src[i],shift)]);
    end;
end;
//for integer only
procedure TCodaMinaArraySortFunction.radix_sort(a, temp:pt;  n:integer;shrfunc: tCompFunc);
var
  i:integer;
begin
  for i:=0 to sizeof(T) -1 do
  begin
    if i mod 2 = 0 then
    begin
      radix_sort_pass(a, temp, n, i*8,shrfunc);
    end
    else
    begin
      radix_sort_pass(temp, a, n, i*8,shrfunc);
    end;
  end;
  //radix_sort_pass(a, temp, n, 0*8,shrfunc);
  //radix_sort_pass(temp, a, n, 1*8,shrfunc);
  //radix_sort_pass(a, temp, n, 2*8,shrfunc);
  //radix_sort_pass(temp, a, n, 3*8,shrfunc);
end;

end.
