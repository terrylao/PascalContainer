
unit CodaMinaRBTree;
{$mode objfpc}{$H+}
interface

uses
  Types, Sysutils;
  
Type 
  TColor = (clRed, clBlack);
 
  generic TCodaMinaRBTree<T> = class
  Type
    TClearFunc = procedure (AValue: TValue);
    TCompareFunc = function( a, b: T): Integer;
    PRBNode = ^TRBNode;
    TRBNode = record
      k: T;
      left, right, parent: PRBNode;
      color: TColor;
    end;
  Var
    private
      root: PRBNode;
      leftmost: PRBNode;
      rightmost: PRBNode;
      compareFunc: TCompareFunc;
      freehead,freetail:PRBNode;
      Scavenger:TClearFunc;
      procedure RotateLeft(var x: PRBNode);
      procedure RotateRight(var x: PRBNode);
      function Minimum(var x: PRBNode): PRBNode;
      function Maximum(var x: PRBNode): PRBNode;
      procedure fast_erase(x: PRBNode);
      procedure freeNode(x: PRBNode);
      function NewNode():PRBNode;
      procedure printTreeNode(n:PRBNode; offs:integer);
    public
      constructor Create(Compare: TCompareFunc=nil;lScavenger:TClearFunc=nil);
      destructor Destroy(); override;
      
      procedure Clear();

      function Find(const key: T): PRBNode;
      function Add(key: T): PRBNode;
      procedure Delete(z: PRBNode);
      
      property First: PRBNode read leftmost;
      property Last: PRBNode read rightmost;
      procedure RBInc(var x: PRBNode);
      procedure RBDec(var x: PRBNode);
      procedure printTree();
end; 
{ TCodaMinaRBTree }


implementation
constructor TCodaMinaRBTree.Create(Compare: TCompareFunc=nil;lScavenger:TClearFunc=nil);
begin
  inherited Create;
  compareFunc := Compare;
	Scavenger := lScavenger;
  root := nil;
  leftmost := nil;
  rightmost := nil;
  freehead:=nil;
  freetail:=nil;
end;

destructor TCodaMinaRBTree.Destroy();
begin
  Clear();
  inherited Destroy;
end;
procedure TCodaMinaRBTree.freeNode(x: PRBNode);
begin
  x^.parent:=nil;
  x^.left:=nil;
  x^.color:=clBlack;
	if Scavenger<>nil then
	begin
	  Scavenger(x^.K);
	end;
  if freehead=nil then
  begin
    freehead:=x;
  end
  else
  begin
    freetail^.right:=x;
  end;
  freetail:=x;
end;
function TCodaMinaRBTree.NewNode():PRBNode;
begin
  if freehead=nil then
  begin
    result:=new(PRBNode);
  end
  else
  begin
    result:=freehead;
    freehead:=freehead^.right;
  end;
end;
procedure TCodaMinaRBTree.fast_erase(x: PRBNode);
begin
  if (x^.left <> nil) then  
    fast_erase(x^.left);
  if (x^.right <> nil) then 
    fast_erase(x^.right);
  freeNode(x);
end;

procedure TCodaMinaRBTree.Clear();
begin
  if (root <> nil) then
    fast_erase(root);
  root := nil;
  leftmost := nil;
  rightmost := nil;
end;

function TCodaMinaRBTree.Find(const key: T): PRBNode;
var
  cmp: integer;
begin
  Result := root;
  while (Result <> nil) do begin
    cmp := compareFunc(Result^.k, key);
    if cmp < 0 then 
    begin
      Result := Result^.right;
    end 
    else 
    if cmp > 0 then 
    begin
      Result := Result^.left;
    end 
    else 
    begin
      break;
    end;
  end;
end;

procedure TCodaMinaRBTree.RotateLeft(var x: PRBNode);
var
  y: PRBNode;
begin
  y := x^.right;
  x^.right := y^.left;
  if (y^.left <> nil) then 
  begin
    y^.left^.parent := x;
  end;
  y^.parent := x^.parent;
  if (x = root) then 
  begin
    root := y;
  end 
  else 
  if (x = x^.parent^.left) then 
  begin
    x^.parent^.left := y;
  end 
  else 
  begin
    x^.parent^.right := y;
  end;
  y^.left := x;
  x^.parent := y;
end;

procedure TCodaMinaRBTree.RotateRight(var x: PRBNode);
var
  y: PRBNode;
begin
  y := x^.left;
  x^.left := y^.right;
  if (y^.right <> nil) then 
  begin
    y^.right^.parent := x;
  end;
  y^.parent := x^.parent;
  if (x = root) then 
  begin
    root := y;
  end 
  else 
  if (x = x^.parent^.right) then 
  begin
    x^.parent^.right := y;
  end 
  else 
  begin
    x^.parent^.left := y;
  end;
  y^.right := x;
  x^.parent := y;
end;

function TCodaMinaRBTree.Minimum(var x: PRBNode): PRBNode;
begin
  Result := x;
  while (Result^.left <> nil) do
    Result := Result^.left;
end;

function TCodaMinaRBTree.Maximum(var x: PRBNode): PRBNode;
begin
  Result := x;
  while (Result^.right <> nil) do
    Result := Result^.right;
end;

function TCodaMinaRBTree.Add(key: T): PRBNode;
var
  x, y, z, zpp: PRBNode;
  cmp: Integer;
begin
  z := NewNode();
  { Initialize fields in new node z }
  z^.k := key;
  z^.left := nil;
  z^.right := nil;
  z^.color := clRed;
  
  Result := z;
  
  { Maintain leftmost and rightmost nodes }
  if ((leftmost = nil) or (compareFunc(key, leftmost^.k) < 0)) then 
  begin
    leftmost := z;
  end;
  if ((rightmost = nil) or (compareFunc(rightmost^.k, key) < 0)) then 
  begin
    rightmost := z;
  end;
  
  { Insert node z }
  y := nil;
  x := root;
  while (x <> nil) do 
  begin
    y := x;
    cmp := compareFunc(key, x^.k);
    if (cmp < 0) then 
    begin
      x := x^.left;
    end 
    else 
    if (cmp > 0) then 
    begin
      x := x^.right;
    end 
    else 
    begin
      { Value already exists in tree. }
      Result := x;
      freeNode(z); //a jzombi: memory leak: if we don't put it in the tree, we shouldn't hold it in the memory
      exit;
    end;
  end;
  z^.parent := y;
  if (y = nil) then 
  begin
    root := z;
  end 
  else 
  if (compareFunc(key, y^.k) < 0) then 
  begin
    y^.left := z;
  end 
  else 
  begin
    y^.right := z;
  end;

  { Rebalance tree }
  while ((z <> root) and (z^.parent^.color = clRed)) do 
  begin
    zpp := z^.parent^.parent;
    if (z^.parent = zpp^.left) then 
    begin
      y := zpp^.right;
      if ((y <> nil) and (y^.color = clRed)) then 
      begin
        z^.parent^.color := clBlack;
        y^.color := clBlack;
        zpp^.color := clRed;
        z := zpp;
      end 
      else 
      begin
        if (z = z^.parent^.right) then 
        begin
          z := z^.parent;
          rotateLeft(z);
        end;
        z^.parent^.color := clBlack;
        zpp^.color := clRed;
        rotateRight(zpp);
      end;
    end 
    else 
    begin
      y := zpp^.left;
      if ((y <> nil) and (y^.color = clRed)) then 
      begin
        z^.parent^.color := clBlack;
        y^.color := clBlack;
        zpp^.color := clRed; //c jzombi: zpp.color := clRed;
        z := zpp;
      end 
      else 
      begin
        if (z = z^.parent^.left) then 
        begin
          z := z^.parent;
          rotateRight(z);
        end;
        z^.parent^.color := clBlack;
        zpp^.color := clRed; //c jzombi: zpp.color := clRed;
        rotateLeft(zpp);
      end;
    end;
  end;
  root^.color := clBlack;
end;


procedure TCodaMinaRBTree.Delete(z: PRBNode);
var
  w, x, y, x_parent: PRBNode;
  tmpcol: TColor;
begin
  y := z;
  x := nil;
  x_parent := nil;

  if (y^.left = nil) then 
  begin    { z has at most one non-null child. y = z. }
    x := y^.right;     { x might be null. }
  end 
  else 
  begin
    if (y^.right = nil) then 
    begin { z has exactly one non-null child. y = z. }
      x := y^.left;    { x is not null. }
    end 
    else 
    begin
      { z has two non-null children.  Set y to }
      y := y^.right;   {   z's successor.  x might be null. }
      while (y^.left <> nil) do 
      begin
        y := y^.left;
      end;
      x := y^.right;
    end;
  end;
  
  if (y <> z) then 
  begin
    { "copy y's sattelite data into z" }
    { relink y in place of z.  y is z's successor }
    z^.left^.parent := y; 
    y^.left := z^.left;
    if (y <> z^.right) then 
    begin
      x_parent := y^.parent;
      if (x <> nil) then 
      begin
        x^.parent := y^.parent;
      end;
      y^.parent^.left := x;   { y must be a child of left }
      y^.right := z^.right;
      z^.right^.parent := y;
    end 
    else 
    begin
      x_parent := y;
    end;
    if (root = z) then 
    begin
      root := y;
    end 
    else 
    if (z^.parent^.left = z) then 
    begin
      z^.parent^.left := y;
    end 
    else 
    begin
      z^.parent^.right := y;
    end;
    y^.parent := z^.parent;
    tmpcol := y^.color;
    y^.color := z^.color;
    z^.color := tmpcol;
    y := z;
    { y now points to node to be actually deleted }
  end 
  else 
  begin                        { y = z }
    x_parent := y^.parent;
    if (x <> nil)  then 
    begin
      x^.parent := y^.parent;
    end;   
    if (root = z) then 
    begin
      root := x;
    end 
    else 
    begin
      if (z^.parent^.left = z) then 
      begin
        z^.parent^.left := x;
      end 
      else 
      begin
        z^.parent^.right := x;
      end;
    end;
    if (leftmost = z) then 
    begin
      if (z^.right = nil) then 
      begin      { z^.left must be null also }
        leftmost := z^.parent;
      end 
      else 
      begin
        leftmost := minimum(x);
      end;
    end;
    if (rightmost = z) then 
    begin
      if (z^.left = nil) then 
      begin       { z^.right must be null also }
        rightmost := z^.parent;  
      end 
      else 
      begin                     { x == z^.left }
        rightmost := maximum(x);
      end;
    end;
  end;
  
  { Rebalance tree }
  if (y^.color = clBlack)  then 
  begin 
    while ((x <> root) and ((x = nil) or (x^.color = clBlack))) do 
    begin
      if (x = x_parent^.left)  then 
      begin
          w := x_parent^.right;
          if (w^.color = clRed)  then 
          begin
            w^.color := clBlack;
            x_parent^.color := clRed;
            rotateLeft(x_parent);
            w := x_parent^.right;
          end;
          if (((w^.left = nil) or 
               (w^.left^.color = clBlack)) and
              ((w^.right = nil) or 
               (w^.right^.color = clBlack)))  then 
          begin
            w^.color := clRed;
            x := x_parent;
            x_parent := x_parent^.parent;
          end 
          else 
          begin
            if ((w^.right = nil) or (w^.right^.color = clBlack)) then 
            begin
              w^.left^.color := clBlack;
              w^.color := clRed;
              rotateRight(w);
              w := x_parent^.right;
            end;
            w^.color := x_parent^.color;
            x_parent^.color := clBlack;
            if (w^.right <> nil)  then 
            begin
              w^.right^.color := clBlack;
            end;
            rotateLeft(x_parent);
            x := root; { break; }
         end
      end 
      else 
      begin   
        { same as above, with right <^. left. }
        w := x_parent^.left;
        if (w^.color = clRed)  then 
        begin
          w^.color := clBlack;
          x_parent^.color := clRed;
          rotateRight(x_parent);
          w := x_parent^.left;
        end;
        if (((w^.right = nil) or 
             (w^.right^.color = clBlack)) and
            ((w^.left = nil) or 
             (w^.left^.color = clBlack)))  then 
        begin
          w^.color := clRed;
          x := x_parent;
          x_parent := x_parent^.parent;
        end 
        else 
        begin
          if ((w^.left = nil) or (w^.left^.color = clBlack)) then 
          begin
            w^.right^.color := clBlack;
            w^.color := clRed;
            rotateLeft(w);
            w := x_parent^.left;
          end;
          w^.color := x_parent^.color;
          x_parent^.color := clBlack;
          if (w^.left <> nil) then 
          begin
            w^.left^.color := clBlack;
          end;
          rotateRight(x_parent);
          x := root; { break; }
        end;
      end;
    end;
    if (x <> nil) then 
    begin
      x^.color := clBlack;
    end;
  end;
  freeNode(y);
end;

{ Pre: x <> last }
procedure TCodaMinaRBTree.RBInc(var x: PRBNode);
var
  y: PRBNode;
begin
  if (x^.right <> nil) then 
  begin
    x := x^.right;
    while (x^.left <> nil) do 
    begin
      x := x^.left;
    end;
  end 
  else 
  begin
    y := x^.parent;
    while (x = y^.right) do 
    begin
      x := y;
      y := y^.parent;
    end;
    if (x^.right <> y) then
      x := y;
  end;
end;

{ Pre: x <> first }
procedure TCodaMinaRBTree.RBDec(var x: PRBNode);
var
  y: PRBNode;
begin
  if (x^.left <> nil)  then 
  begin
    y := x^.left;
    while (y^.right <> nil) do 
    begin
      y := y^.right;
    end;
    x := y;
  end 
  else 
  begin
    y := x^.parent;
    while (x = y^.left) do 
    begin
      x := y;
      y := y^.parent;
    end;
    x := y;
  end;
end;
procedure TCodaMinaRBTree.printTreeNode(n:PRBNode; offs:integer);
var
  i:integer;
begin
    for i := 0 to offs-1  do
      write(stdout,' ');
    
    if n=nil then
    begin
      writeln(stdout,'(nil)');
      exit;
    end;
    if offs=0 then
      write(stdout,'[*] ',integer(n),'=',n^.k,' color=',ord(n^.color))
    else
    if (n^.Left = nil) and (n^.Right = nil) then
      write(stdout,'[L] ',integer(n),'=',n^.k,' color=',ord(n^.color))
    else 
      write(stdout,'[I] ',integer(n),'=',n^.k,' color=',ord(n^.color));

    writeln(stdout);
    for i := 0 to   offs  do
        write(stdout,' ');

    printTreeNode(n^.Left, offs + 1);
    for i := 0 to   offs  do
        write(stdout,' ');
    printTreeNode(n^.Right, offs + 1);
end;
procedure TCodaMinaRBTree.printtree();
begin
  printTreeNode(root, 0);
end;

end.

