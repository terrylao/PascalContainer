{
  publish with BSD Licence.
	Copyright (c) Terry Lao
}
Unit CodaMinaQuadtree;
interface

uses
  Classes, SysUtils, math;

type
  generic TCodaMinaQuadtree<T>=class
    type
      valuefreefunc=procedure (value:T); //void(* key_free)(value:T);

      ppoint=^tpoint;
      Tpoint = record
        x,y:double;
      end; 
      pbounds = ^tbounds;
      Tbounds = record
        nw,se:ppoint;
        width,height:double;
      end; 
      pnode =^tnode;
      Tnode = record
        ne,nw,se,sw:pnode;
        bounds:pbounds;
        point:ppoint;
        value:T;
      end;
      xscentfunc=procedure (node:pnode);//void (*ascent)(node:pnode )
      pquadtree = ^tquadtree;
      Tquadtree = record
        root:pnode ;
        kf:valuefreefunc;
        length:cardinal;
      end;
    private
      tree:pquadtree;
      function  node_contains(outer:pnode ; it:ppoint ):boolean;
      function  get_quadrant(root:pnode; point:ppoint ):pnode;
      function  split_node(node:pnode ):integer;
      function  find(node:pnode; x,y:double):T;
      function  add(root:pnode ;point:ppoint; value:T):integer;
      procedure reset_node( node:pnode );
      function  bounds_new():pbounds;
      function  node_ispointer(node:pnode ):boolean;
      function  node_isempty(node:pnode ):boolean;
      function  node_new():pnode;
      function  node_with_bounds( minx, miny, maxx, maxy:double):pnode;
      function  point_new(x,y:double):ppoint;
      function  node_isleaf(node:pnode ):boolean;
      procedure bounds_extend(bounds:pbounds; x,y:double);
      procedure bounds_free(bounds:pbounds );
      procedure node_reset(node:pnode; kf:valuefreefunc);
      procedure node_free(node:pnode; kf:valuefreefunc);
      procedure point_free(point:ppoint);
      procedure printTreeNode(root:pnode);
    public

      constructor  create( minx,  miny,  maxx,  maxy:double;const kff:valuefreefunc=nil);
      function  insert( x,y:double; value:T):integer;
      function  search( x,y:double):T;
      procedure free();
      procedure printtree();
      
      function  getLength():Integer;
  end;

implementation

procedure TCodaMinaQuadtree.bounds_extend(bounds:pbounds; x,y:double);
begin
  bounds^.nw^.x  := min(x, bounds^.nw^.x);
  bounds^.nw^.y  := max(y, bounds^.nw^.y);
  bounds^.se^.x  := max(x, bounds^.se^.x);
  bounds^.se^.y  := min(y, bounds^.se^.y);
  bounds^.width  := abs(bounds^.nw^.x - bounds^.se^.x);
  bounds^.height := abs(bounds^.nw^.y - bounds^.se^.y);
end;

procedure TCodaMinaQuadtree.bounds_free(bounds:pbounds );
begin
  point_free(bounds^.nw);
  point_free(bounds^.se);
  freemem(bounds);
end;


function TCodaMinaQuadtree.bounds_new():pbounds;
var
  bounds:pbounds;
begin
  bounds := allocmem(sizeof(Tbounds));
  if(bounds = nil) then 
    exit(nil);
  bounds^.nw     := point_new(INFINITY, -INFINITY);
  bounds^.se     := point_new(-INFINITY, INFINITY);
  bounds^.width  := 0;
  bounds^.height := 0;
  result := bounds;
end;

{ helpers }

function TCodaMinaQuadtree.node_ispointer(node:pnode ):boolean;
begin
  result := (node^.nw <> nil)
      and (node^.ne <> nil)
      and (node^.sw <> nil)
      and (node^.se <> nil)
      and (not node_isleaf(node));
end;

function TCodaMinaQuadtree.node_isempty(node:pnode ):boolean;
begin
  result := (node^.nw = nil)
      and (node^.ne = nil)
      and (node^.sw = nil)
      and (node^.se = nil)
      and (not node_isleaf(node));
end;

function TCodaMinaQuadtree.node_isleaf(node:pnode ):boolean;
begin
  result :=  node^.point <> nil;
end;

procedure TCodaMinaQuadtree.node_reset(node:pnode; kf:valuefreefunc);
begin
  point_free(node^.point);
  if kf<>nil then
    kf(node^.value);
end;

{ api }
function TCodaMinaQuadtree.node_new():pnode;
var
  node:pnode ;
begin
  node := allocmem(sizeof(Tnode));
  if( node = nil ) then
    exit(nil);
  node^.ne     := nil;
  node^.nw     := nil;
  node^.se     := nil;
  node^.sw     := nil;
  node^.point  := nil;
  node^.bounds := nil;
  node^.value    := default(T);
  result := node;
end;

function TCodaMinaQuadtree.node_with_bounds( minx, miny, maxx, maxy:double):pnode;
var
  node:pnode;
begin
  node := node_new();
  if( node = nil ) then exit(nil);
  node^.bounds := bounds_new();
  if(node^.bounds = nil) then exit(nil);
  bounds_extend(node^.bounds, maxx, maxy);
  bounds_extend(node^.bounds, minx, miny);
  result := node;
end;

procedure TCodaMinaQuadtree.node_free(node:pnode; kf:valuefreefunc);
begin
  if(node^.nw <> nil) then node_free(node^.nw, kf);
  if(node^.ne <> nil) then node_free(node^.ne, kf);
  if(node^.sw <> nil) then node_free(node^.sw, kf);
  if(node^.se <> nil) then node_free(node^.se, kf);

  bounds_free(node^.bounds);
  node_reset(node, kf);
  freemem(node);
end;

function TCodaMinaQuadtree.point_new(x,y:double):ppoint;
var
  point:ppoint;
begin
  point := allocmem(sizeof(tpoint));
  if( point = nil) then
    exit(nil);
  point^.x := x;
  point^.y := y;
  result := point;
end;

procedure TCodaMinaQuadtree.point_free(point:ppoint);
begin
  freemem(point);
end;


{ private implementations }
function TCodaMinaQuadtree.node_contains(outer:pnode ; it:ppoint ):boolean;
begin
  result := (outer^.bounds <> nil)
      and (outer^.bounds^.nw^.x <= it^.x)
      and (outer^.bounds^.nw^.y >= it^.y)
      and (outer^.bounds^.se^.x >= it^.x)
      and (outer^.bounds^.se^.y <= it^.y);
end;

procedure TCodaMinaQuadtree.reset_node( node:pnode );
begin
  node_reset(node, tree^.kf);
end;

function TCodaMinaQuadtree.get_quadrant(root:pnode; point:ppoint ):pnode;
begin
  if(node_contains(root^.nw, point)) then exit(root^.nw);
  if(node_contains(root^.ne, point)) then exit(root^.ne);
  if(node_contains(root^.sw, point)) then exit(root^.sw);
  if(node_contains(root^.se, point)) then exit(root^.se);
  exit(nil);
end;


function TCodaMinaQuadtree.split_node(node:pnode ):integer;
var
  nw,ne,sw,se:pnode;
  old:ppoint;
  value:T;
  x,y,hw,hh:double;
begin

  x  := node^.bounds^.nw^.x;
  y  := node^.bounds^.nw^.y;
  hw := node^.bounds^.width / 2;
  hh := node^.bounds^.height / 2;

                      //minx,   miny,       maxx,       maxy
  nw := node_with_bounds(x,      y - hh,     x + hw,     y);
  if ( nw=nil) then exit(0);
  ne := node_with_bounds(x + hw, y - hh,     x + hw * 2, y);
  if ( ne=nil) then exit(0);
  sw := node_with_bounds(x,      y - hh * 2, x + hw,     y - hh);
  if ( sw=nil) then exit(0);
  se := node_with_bounds(x + hw, y - hh * 2, x + hw * 2, y - hh);
  if ( se=nil) then exit(0);

  node^.nw := nw;
  node^.ne := ne;
  node^.sw := sw;
  node^.se := se;

  old := node^.point;
  value := node^.value;
  node^.point := nil;
  node^.value   := default(T);

  result := add( node, old, value);
end;


function TCodaMinaQuadtree.find(node:pnode; x,y:double):T;
var
  test:tpoint;
begin
  if( node=nil ) then 
  begin
    exit(default(T));
  end;
  if(node_isleaf(node)) then 
  begin
    if(node^.point^.x = x) and (node^.point^.y = y) then
      exit(node^.value);
  end 
  else 
  if(node_ispointer(node)) then 
  begin
    test.x := x;
    test.y := y;
    exit(find(get_quadrant(node, @test), x, y));
  end;

  exit(default(T));
end;

{ cribbed from the google closure library. }
function TCodaMinaQuadtree.add(root:pnode ;point:ppoint; value:T):integer;
var
  quadrant:pnode;
begin
  if(node_isempty(root)) then 
  begin
    root^.point := point;
    root^.value   := value;
    exit(1); { normal insertion flag }
  end 
  else 
  if(node_isleaf(root)) then 
  begin
    if (root^.point^.x = point^.x) and (root^.point^.y = point^.y) then 
    begin
      reset_node( root);
      root^.point := point;
      root^.value   := value;
      exit(2); { replace insertion flag }
    end 
    else
    begin 
      if( split_node( root) = 0 ) then
      begin
        exit(0); { failed insertion flag }
      end;
      exit( add( root, point, value));
    end;
  end 
  else 
  if(node_ispointer(root)) then 
  begin
    quadrant := get_quadrant(root, point);
    if quadrant = nil then
    result := 0 
    else
    exit(add( quadrant, point, value));
  end;
  exit(0);
end;


{ public }
constructor TCodaMinaQuadtree.create( minx,  miny,  maxx,  maxy:double;const kff:valuefreefunc=nil);
begin
  tree := allocmem(sizeof(tquadtree)) ;
  tree^.root := node_with_bounds(minx, miny, maxx, maxy);
  tree^.kf := kff;
  tree^.length := 0;
end;

function TCodaMinaQuadtree.insert( x,y:double; value:T):integer;
var
  point:ppoint;
  insertstatus:integer;
begin
  point := point_new(x, y);
  if( point =nil )  then exit(0);
  if( not node_contains(tree^.root, point)) then 
  begin
    point_free(point);
    exit(0);
  end;
  insertstatus := add( tree^.root, point, value);
  if( insertstatus=0 ) then 
  begin
    point_free(point);
    exit(0);
  end;
  if (insertstatus = 1) then  inc(tree^.length);
  result := insertstatus;
end;

function TCodaMinaQuadtree.search( x,y:double):T;
begin
  result := find(tree^.root, x, y);
end;

procedure TCodaMinaQuadtree.free();
begin
  if(tree^.kf <> nil) then
  begin
    node_free(tree^.root, tree^.kf);
  end 
  else 
  begin
    //node_free(tree^.root, elision_);//怪
  end;
  freemem(tree);
end;

procedure TCodaMinaQuadtree.printTreeNode(root:pnode);
begin
  if(root^.bounds <> nil) then
  begin
    writeln(stdout,'{ nw.x:',root^.bounds^.nw^.x,' nw.y:',root^.bounds^.nw^.y,' se.x:',root^.bounds^.se^.x,' se.y:',root^.bounds^.se^.y,' }: ');
  end;
  if(root^.nw <> nil) then printTreeNode(root^.nw);
  if(root^.ne <> nil) then printTreeNode(root^.ne);
  if(root^.sw <> nil) then printTreeNode(root^.sw);
  if(root^.se <> nil) then printTreeNode(root^.se);
  writeln(stdout,'');
end;
procedure TCodaMinaQuadtree.printtree;
begin
  printTreeNode(tree^.root);
end;
function  TCodaMinaQuadtree.getLength():Integer;
begin
  result:=tree^.length;
end;
initialization

finalization

end.
