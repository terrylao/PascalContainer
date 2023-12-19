{
  publish with BSD Licence.
	Copyright (c) Terry Lao
}
unit CodaMinaMTree;
{$mode objfpc}{$H+}
interface
uses
  Types,strutils,SysUtils,Classes,CodaMinaVector,math,CodaMinaQueue;

type
  NODEEnum=(BASE_NODE,INTERNAL_NODE,LEAF_NODE);
	
  KeyObject=class
	private
  	key:uint64;
	public
  	constructor create(const akey:uint64);
  	function  distance(const other:KeyObject):int64;
  end;

	generic Entry<T>=class
	private
		id:int64;
		key:T;
	public
		constructor create(const aid:int64;const akey:T);
		constructor create(const other:Entry);
    //class operator :=(const other:Entry) r : Entry;
	end;
	
	generic RoutingObject<T>=class
		class var n_build_ops:uint64;
		private
  		id:int64;
      key:T;
      subtree:pointer;
      cover_radius:int64;
      d:int64;
		public
  		//constructor create();
      constructor create(const aid:int64; const akey:T);
      constructor create(const other:RoutingObject);
      //class operator:=(const other:RoutingObject) r:RoutingObject;
      function distance(const other:T):int64;
  end;
  generic DBEntry<T>=class
		class var n_query_ops:uint64;
		private
  		id:int64;
  		key:T;
  		d:int64;
		public
  		constructor create(const aid:int64; const akey:T; const ad:int64);
  		constructor create(const other:DBEntry);
  		//class operator:=(const other:DBEntry) r:DBEntry;
  		function distance(const other:T):int64;
  end;
	{*
	 * template parameters: NROUTES - no. routes to store in internal nodes
	 *                      LEAFCAP - no. dbentries to store in leaf nodes
	 *}
  generic TPrintFunction<T> = procedure(const v:T);
	generic MNode<T> = class
	type
	PrintNode=specialize TPrintFunction<T>;
	protected
		p:MNode;   // parent node
		rindex:integer; // route_entry index to parent node from this node
	public
	  nodetype:NODEEnum;
		constructor create();
		destructor destroy();virtual;abstract;
		function size():integer;virtual;abstract;
		function isfull():boolean;virtual;abstract;
		function isroot():boolean;
		function GetParentNode(var rdx:integer):MNode;
		procedure SetParentNode(pnode:MNode; const rdx:integer);
    procedure SetChildNode(child:MNode; const rdx:integer);virtual;abstract;
		function GetChildNode(const rdx:integer):MNode;virtual;abstract;
		procedure Clear();virtual;abstract;
		procedure print(print:PrintNode);virtual;abstract;
	end;
      
	generic MInternal<T> = class(specialize MNode<T>)
	type
	  TMNode = specialize MNode<T>;
		TRoute =specialize RoutingObject<T>;
		TVecRoute=specialize TCodaMinaVector<TRoute>;
		TQMNode = specialize TCodaMinaQueue<TMNode>;
	protected
		n_routes:integer;
    myNROUTES:integer;
		routes:array of TRoute ;
	public
		constructor create(NROUTES:integer);
		destructor destroy();override ;
		function size():integer;override ;
		function isfull():boolean;override;
		// return all the routing objects for this node 
		procedure GetRoutes(aroutes:TVecRoute);
		// select routing object to follow for insert
		// modify cover radius in routing object as appropriate
		function SelectRoute(const nobj:T;var robj:TRoute; insert:boolean):integer;
		procedure SelectRoutes(const query:T; const radius:int64;nodes:TQMNode);
		function StoreRoute(const robj:TRoute):integer;
		procedure ConfirmRoute(const robj:TRoute; const rdx:integer);
		procedure GetRoute(const rdx:integer;var route:TRoute);
		procedure SetChildNode(child:TMNode; const rdx:integer);override;
		function GetChildNode(const rdx:integer):TMNode;override;
		procedure Clear();override;
		procedure print(print:PrintNode);override;
	end;
		
	generic MLeaf<T> = class(specialize MNode<T>)
	type
	  TMNode = specialize MNode<T>;
	  TDBEntry=specialize DBEntry<T>;
		TEntry=specialize Entry<T>;
		TVecEntry=specialize TCodaMinaVector<TEntry>;
		TVecDBEntry=specialize TCodaMinaVector<TDBEntry>;
		TRoute =specialize RoutingObject<T>;
    TMInternal=specialize MInternal<T>;
	protected
		entries:TVecDBEntry;
		myLEAFCAP:integer;
	public
		constructor create(LEAFCAP:integer);
		destructor destroy();override;
		function size():integer;override;
		function isfull():boolean;override;
		function StoreEntry(const nobj:TDBEntry):integer;
		procedure GetEntries(dbentries:TVecDBEntry);
		procedure SelectEntries(const query:T; const radius:int64; results:TVecEntry);
		function DeleteEntry(const entry:T):integer;
		procedure SetChildNode(child:TMNode; const rdx:integer);override;
		function GetChildNode(const rdx:integer):TMNode;override;
		procedure Clear();override;
		procedure print(print:PrintNode);override;
	end;
			
  generic TCodaMinaMTree<T> = class
	type
	  TEntry=specialize Entry<T>;
		TMLeaf=specialize MLeaf<T>;
    TMNode = specialize MNode<T>;
    TDBEntry=specialize DBEntry<T>;
    TVecDBEntry=specialize TCodaMinaVector<TDBEntry>;
		PRoute =^TRoute;
    TRoute =specialize RoutingObject<T>;
    TVecEntry=specialize TCodaMinaVector<TEntry>;
    TMInternal=specialize MInternal<T>;
		TQMNode = specialize TCodaMinaQueue<TMNode>;
	private
		m_count:size_t;
		m_top:TMNode;
  	myNROUTES :integer;
  	myLEAFCAP :integer;
		procedure promote(entries:TVecDBEntry; robj1, robj2:TRoute);
		procedure partition(entries:TVecDBEntry; robj1, robj2:TRoute; entries1, entries2:TVecDBEntry);
		function split(node:TMNode; const nobj:TEntry):TMNode;
		procedure StoreEntries(leaf:TMLeaf; entries:TVecDBEntry);
	public
		constructor create( NROUTES, LEAFCAP:integer);
		procedure Insert(const entry:TEntry);
		function DeleteEntry(const entry:TEntry):integer;
		procedure Clear();
		function RangeQuery(query:T; const radius:int64 ):TVecEntry;
		function size():size_t;
		function memory_usage():size_t;
		procedure PrintTree(aprint:TMNode.PrintNode);
	end;

procedure tesTCodaMinaMTree();

implementation

constructor Entry.create(const aid:int64;const akey:T);
begin
  id:=aid;
	key:=akey;
end;
constructor Entry.create(const other:Entry);
begin
	id  := other.id;
	key := other.key;
end;
{
class operator Entry.:= (const other: Entry) z: Entry;
begin
	z.id  := other.id;
	z.key := other.key; 
end;
}
{
constructor RoutingObject.create();
begin
  id:=0;
	subtree:=nil;
end;
}
constructor RoutingObject.create(const aid:int64; const akey:T);
begin
  id:=aid;
	key:=akey;
	subtree:=nil;
	cover_radius:=0;
	d:=0;
end;
constructor RoutingObject.create(const other:RoutingObject);
begin
	id           := other.id;
	key          := other.key;
	subtree      := other.subtree;
	cover_radius := other.cover_radius;
	d            := other.d;
end;
{
class operator RoutingObject.:=(const other:RoutingObject) z:RoutingObject;
begin
	r.id := other.id;
	r.key := other.key;
	r.subtree := other.subtree;
	r.cover_radius := other.cover_radius;
	r.d := other.d;
end;
}
function RoutingObject.distance(const other:T):int64;
begin
	inc(RoutingObject.n_build_ops);
	result := key.distance(other);
end;
constructor DBEntry.create(const aid:int64; const akey:T; const ad:int64);
begin
  id:=aid;
	key:=akey;
	d:=ad;
end;
constructor DBEntry.create(const other:DBEntry);
begin
	id  := other.id;
	key := other.key;
	d   := other.d;
end;
{
class operator DBEntry.=(const other:DBEntry) r:DBEntry;
begin
	r.id  = other.id;
	r.key = other.key;
	r.d   = other.d;
end;
}
function DBEntry.distance(const other:T):int64;
begin
	inc(DBEntry.n_query_ops);
	result := key.distance(other);
end;
constructor MNode.create();
begin
  p:=nil;
	nodetype:=BASE_NODE;
end;


{*
 *  MNode base class implementation 
 *
 *}

function MNode.isroot():boolean;
begin
	result := (p = nil);
end;

function MNode.GetParentNode(var rdx:integer):MNode;
begin
	rdx := rindex;
	result := p;
end;

procedure  MNode.SetParentNode(pnode:MNode; const rdx:integer);
begin
	//assert((rdx >= 0) and (rdx < NROUTES));
	p := pnode;
	rindex := rdx;
end;

{*
 *
 *  MInternal Node implementation
 *
 *}

constructor MInternal.create(NROUTES:integer);
var
  i:integer;
begin
  nodetype:=INTERNAL_NODE;
	n_routes := 0;
	setlength(routes,NROUTES);
	myNROUTES:=NROUTES;
	for i:=0 to NROUTES-1 do
	begin
	  routes[i]:=TRoute.create(0,default(T));
		routes[i].subtree := nil;
	end;
end;

destructor MInternal.destroy();
begin
end;

function MInternal.size():integer;
begin
	result := n_routes;
end;

function MInternal.isfull():boolean;
begin
	result := (n_routes >= myNROUTES);
end;

procedure MInternal.GetRoutes(aroutes:TVecRoute);
var
  i:integer;
begin
	for i:=0 to myNROUTES-1 do
	begin
		if (aroutes.get(i).subtree <> nil) then
			aroutes.push_back(routes[i]);
	end;
end;


function MInternal.SelectRoute(const nobj:T;var robj:TRoute; insert:boolean):integer;
var
  min_pos:integer;
	min_dist,d:int64;
	i:integer;
begin
	min_pos := -1;
	min_dist := HIGH(Int64) ;//DBL_MAX;
	for i:=0 to myNROUTES-1 do
	begin
		if (routes[i].subtree <> nil) then
		begin
			d := routes[i].distance(nobj); //distance(routes[i].key, nobj.key);
			if (d < min_dist) then
			begin
				min_pos := i;
				min_dist := d;
			end;
		end;
	end;

	if (min_pos < 0) then
    raise Exception.Create('unable to find route entry');

	if (insert) and (min_dist > routes[min_pos].cover_radius) then
		routes[min_pos].cover_radius := min_dist;
	
	robj := routes[min_pos];
	
	result := min_pos;
end;

procedure MInternal.SelectRoutes(const query:T; const radius:int64;nodes:TQMNode);
var
  d:int64;
	pobj:TRoute;
	i:integer;
begin
	d := 0;
	if (p <> nil) then
	begin
		MInternal(p).GetRoute(rindex, pobj);
		d := pobj.distance(query);
	end;

	for i:=0 to myNROUTES-1 do
	begin
		if (routes[i].subtree <> nil) then
		begin
			if (abs(d -  routes[i].d) <= radius + routes[i].cover_radius) then
			begin
				if (routes[i].distance(query) <= radius + routes[i].cover_radius) then
				begin   //distance(routes[i].key, query)
					nodes.push(TMNode(routes[i].subtree));
				end;
			end;
		end;
	end;
	
end;

function MInternal.StoreRoute(const robj:TRoute):integer;
var
  index,i:integer;
begin
	assert(n_routes < myNROUTES);

	index := -1;
	for i:=0 to myNROUTES-1 do
	begin
		if (routes[i].subtree = nil) then
		begin
			routes[i] := robj;
			index := i;
			inc(n_routes);
			break;
		end;
	end;
	result := index;
end;
//robj need copy
procedure MInternal.ConfirmRoute(const robj:TRoute; const rdx:integer);
begin
	assert((rdx >= 0) and (rdx < myNROUTES) and (robj.subtree <> nil));
	routes[rdx] := robj;
end;

procedure MInternal.GetRoute(const rdx:integer;var route:TRoute);
begin
	assert((rdx >= 0) and (rdx < myNROUTES));
	route := routes[rdx];
end;

procedure MInternal.SetChildNode(child:TMNode; const rdx:integer);
begin
	assert((rdx >= 0) and (rdx < myNROUTES));
	routes[rdx].subtree := child;
	child.SetParentNode(self, rdx);
end;

function MInternal.GetChildNode(const rdx:integer):TMNode;
begin
	assert((rdx >= 0) and (rdx < myNROUTES));
	result := TMNode(routes[rdx].subtree);
end;

procedure MInternal.Clear();
begin
	n_routes := 0;
end;
procedure MInternal.print(print:PrintNode);
var
  i:integer;
begin
	for i:=0 to n_routes-1 do
	begin
	  write(stdout,'internal id:',routes[i].id,' distance:',routes[i].d);
		print(routes[i].key);
	end;
end;
{*
 *
 * MLeaf<T> node implementation
 *
 *}

constructor MLeaf.create(LEAFCAP:integer);
begin
  nodetype:=LEAF_NODE;
  myLEAFCAP:=LEAFCAP;
	entries:=TVecDBEntry.create;
end;
destructor MLeaf.destroy();
begin
	entries.clear();
end;


function MLeaf.size():integer;
begin
	result:= entries.size();
end;


function MLeaf.isfull():boolean;
begin
	result:= (entries.size() >= myLEAFCAP);
end;


function MLeaf.StoreEntry(const nobj:TDBEntry):integer;
var
  i:integer;
  sample:TDBEntry;
begin
	if (entries.size() >= myLEAFCAP) then
    raise Exception.Create('full leaf node');
	result := entries.size();
	entries.push_back(nobj);
end;


procedure MLeaf.GetEntries(dbentries:TVecDBEntry);
var
  i:integer;
begin
  for i := 0 to entries.size-1 do
	begin
		dbentries.push_back(entries.get(i));
	end;
end;

procedure MLeaf.print(print:PrintNode);
var
  i:integer;
begin
  for i := 0 to entries.size-1 do
	begin
	  write(stdout,'leaf id:',entries.get(i).id,' distance:',entries.get(i).d);
		print(entries.get(i).key);
	end;
end;

procedure MLeaf.SelectEntries(const query:T; const radius:int64; results:TVecEntry);

var
  d:int64;
	pobj:TRoute;
	j:integer;
begin
	d := 0;
	if (p <> nil) then
	begin
		TMInternal(p).GetRoute(rindex, pobj);
		d := pobj.distance(query);               //distance(pobj.key, query);
	end;
	
	for j:=0 to entries.size()-1 do
	begin
		if (abs(d -  entries.get(j).d) <= radius) then
		begin
			if (entries.get(j).distance(query) <= radius) then
			begin
				results.push_back(TEntry.create(entries.get(j).id, entries.get(j).key));
			end;
		end;
	end;
end;


function MLeaf.DeleteEntry(const entry:T):integer;
var
  count:integer;
	d:int64;
	j:integer;
	pobj:TRoute;
begin
	count := 0;

	d := 0;
	if (p <> nil) then
	begin
		TMInternal(p).GetRoute(rindex, pobj);
		//d := pobj.key.distance(entry.key);
    d := pobj.key.distance(entry);
	end;

	for j:=0 to entries.size()-1 do
	begin
		if (d = entries.get(j).d) then
		begin
			if (entry.distance(entries.get(j).key) = 0) then
			begin
				entries.setValue(j,entries.back());
				entries.pop_back();
				inc(count);
			end;
		end;
	end;
	
	result := count;
end;


procedure MLeaf.SetChildNode(child:TMNode; const rdx:integer);
begin
	exit;
end;


function MLeaf.GetChildNode(const rdx:integer):TMNode;
begin
	result := nil;
end;


procedure MLeaf.Clear();
begin
	entries.clear();
end;
{*
 *  TCodaMinaMTree implementation code 
 *
 *}
constructor TCodaMinaMTree.create( NROUTES, LEAFCAP:integer);
begin
  m_count:=0;
	m_top:=nil;
	myNROUTES := NROUTES;
	myLEAFCAP := LEAFCAP;
end;



procedure TCodaMinaMTree.promote(entries:TVecDBEntry; robj1, robj2:TRoute);
var
  routes:array[0..1] of TRoute;
	current,n_iters,i,j,maxpos,slimit:integer;
	maxd,d:int64;
begin
	current := 0;
	routes[0] := TRoute.create(0,Default(T));
	routes[1] := TRoute.create(0,Default(T));
	routes[0].key := entries.get(0).key;
  
	n_iters := 5;
	for i:=0 to n_iters-1 do
	begin
		maxpos := -1;
		maxd := -1;
		slimit := entries.size();
		for j:=0 to slimit-1 do
		begin
			d := routes[current mod 2].distance(entries.get(j).key);
			if (d > maxd) then
			begin
				maxpos := j;
				maxd := d;
			end;
		end;
		inc(current);
		routes[current mod 2].key := entries.get(maxpos).key;
	end;
	
	robj1.key := routes[0].key;
	robj2.key := routes[1].key;
	robj1.d := 0;
	robj2.d := 0;
	routes[0].free;
	routes[1].free;
end;

procedure TCodaMinaMTree.partition(entries:TVecDBEntry; robj1, robj2:TRoute; entries1, entries2:TVecDBEntry);
var
  radius1,radius2,d1,d2:int64;
	i:integer;
begin
	radius1 := 0;
	radius2 := 0;
	for i:=0 to entries.size()-1 do
	begin
		d1 := robj1.distance(entries.get(i).key);
		d2 := robj2.distance(entries.get(i).key);
		if (d1 < d2) then
		begin
			entries1.push_back(TDBEntry.create(entries.get(i).id, entries.get(i).key, d1));
			if (d1 > radius1) then
			  radius1 := d1;
		end
		else
		begin
			entries2.push_back(TDBEntry.create(entries.get(i).id, entries.get(i).key, d2));
			if (d2 > radius2) then
			  radius2 := d2;
		end;
	end;
	
	robj1.cover_radius := radius1;
	robj2.cover_radius := radius2;
	entries.clear();
end;

procedure TCodaMinaMTree.StoreEntries(leaf:TMLeaf; entries:TVecDBEntry);
begin
	while (not entries.empty()) do
	begin
		leaf.StoreEntry(entries.back());
		entries.pop_back();
	end;
end;


function TCodaMinaMTree.split(node:TMNode; const nobj:TEntry):TMNode;
var
  leaf,leaf2:TMLeaf;
	entries,entries1, entries2:TVecDBEntry;
	pobj, robj1, robj2:TRoute;
	pnode,qnode,gnode:TMInternal;
	rdx,rdx1,rdx2,gdx:integer;
begin
	assert(node.nodetype = LEAF_NODE);

	leaf  := TMLeaf(node);
	leaf2 := TMLeaf.create(myLEAFCAP);
  entries :=TVecDBEntry.create;
	entries1:=TVecDBEntry.create;
	entries2:=TVecDBEntry.create;
	leaf.GetEntries(entries);

	entries.push_back(TDBEntry.create(nobj.id, nobj.key, 0));
	robj1:=TRoute.create(0,default(T));
	robj2:=TRoute.create(0,default(T));
	promote(entries, robj1, robj2);

	partition(entries, robj1, robj2, entries1, entries2);
	robj1.subtree := leaf;
	robj2.subtree := leaf2;

	leaf.Clear();
	StoreEntries(leaf, entries1);
	StoreEntries(leaf2, entries2);

	if (node.isroot()) then
	begin // root level
		qnode := TMInternal.create(myNROUTES);

		rdx := qnode.StoreRoute(robj1);
		qnode.SetChildNode(leaf, rdx);

		rdx := qnode.StoreRoute(robj2);
		qnode.SetChildNode(leaf2, rdx);

		pnode := qnode;
	end
	else
	begin  // not root  
		pnode := TMInternal(node.GetParentNode(rdx));
		if (pnode.isfull()) then
		begin // parent node overflows
			qnode := TMInternal.create(myNROUTES);
			pnode.GetRoute(rdx, pobj);
			robj1.d := pobj.distance(robj1.key); //  distance(robj1.key, pobj.key);
			rdx1 := qnode.StoreRoute(robj1);
			qnode.SetChildNode(leaf, rdx1);
			robj2.d := pobj.distance(robj2.key); // distance(robj2.key, pobj.key);
			rdx2 := qnode.StoreRoute(robj2);
			qnode.SetChildNode(leaf2, rdx2);
			pnode.SetChildNode(qnode, rdx);
		end
		else
		begin // still room in parent node
			gnode := TMInternal(pnode.GetParentNode(gdx));
			if (gnode <> nil) then
			begin
				gnode.GetRoute(gdx, pobj);
				robj1.d := pobj.distance(robj1.key); // distance(robj1.key, pobj.key);
				robj2.d := pobj.distance(robj2.key); // distance(robj2.key, pobj.key);
			end;
			
			pnode.ConfirmRoute(robj1, rdx);
			pnode.SetChildNode(leaf, rdx);

			rdx2 := pnode.StoreRoute(robj2);
			pnode.SetChildNode(leaf2, rdx2);
		end;
	end;
  
	result := pnode;
	entries.free;
	entries1.free;
	entries2.free;
end;


procedure TCodaMinaMTree.Insert(const entry:TEntry);
var
  node:TMNode;
	leaf:TMLeaf;
	dentry:TDBEntry;
	d:int64;
	robj:TRoute;
begin
	node := m_top;
	if (node = nil) then
	begin // add first entry to empty tree
    leaf := TMLeaf.create(myLEAFCAP);
		dentry:=TDBEntry.create(entry.id, entry.key, 0);
		leaf.StoreEntry(dentry);
		m_top := leaf;
	end
	else
	begin
		d := 0;
		repeat
			//if (TypeInfo(node) = TypeInfo(TMInternal)) then
      if node.NodeType=INTERNAL_NODE then
			begin
				TMInternal(node).SelectRoute(entry.key, robj, true);
				node := TMNode(robj.subtree);
				d := robj.key.distance(entry.key);  // distance(robj.key, entry.key);
			end
			else
			//if (TypeInfo(node) = TypeInfo(TMLeaf)) then
      if node.NodeType=LEAF_NODE then
			begin
			  leaf:=TMLeaf(node);
				if (not leaf.isfull()) then
				begin
				  dentry:=TDBEntry.create(entry.id, entry.key, d);
					leaf.StoreEntry(dentry);
				end
				else
				begin
					node := split(leaf, entry);
					if (node.isroot()) then
					begin
						m_top := node;
					end;
				end;
				node := nil;
			end
			else
			begin
				raise Exception.Create('no such node type');
			end;
		until (node = nil);
	end;

	m_count :=m_count + 1;
	
end;


function TCodaMinaMTree.DeleteEntry(const entry:TEntry):integer;
var
  node:TMNode;
	count:integer;
	robj:TRoute;
	leaf:TMLeaf;
begin
	node := m_top;

	count := 0;
	while (node <> nil) do
	begin
		if node.NodeType=INTERNAL_NODE then
		begin
			TMInternal(node).SelectRoute(entry.key, robj, false);
			node := TMNode(robj.subtree);
		end
		else
		if node.NodeType=LEAF_NODE then
		begin
			leaf := TMLeaf(node);
			count := leaf.DeleteEntry(entry.key);
			node := nil;
		end
		else
		begin
			raise Exception.Create('no such node type');
		end;
	end;;

	m_count :=m_count - count;
	result := count;
end;


procedure TCodaMinaMTree.Clear();
var
  nodes:TQMNode;
	current,child:TMNode;
	internal:TMInternal;
	i:integer;
	leaf:TMLeaf;
begin
  nodes:=TQMNode.create;
	if (m_top <> nil) then
		nodes.Push(m_top);

	while (not nodes.IsEmpty()) do
	begin
		current := nodes.Front();
		if current.NodeType=INTERNAL_NODE then
		begin
			internal := TMInternal(current);
			for i:=0 to myNROUTES-1 do
			begin
				child := internal.GetChildNode(i);
				if (child<>nil) then
				  nodes.push(child);
			end;
			internal.free;		
		end
		else
		if current.NodeType=LEAF_NODE then
    begin
			leaf := TMLeaf(current);
			leaf.free;
		end
		else
		begin
			raise Exception.Create('no such node type');
		end;
		nodes.pop();
	end;
	nodes.free;
	m_count := 0;
end;


function TCodaMinaMTree.RangeQuery(query:T; const radius:int64 ):TVecEntry;
var
  results:TVecEntry;
	nodes:TQMNode;
	current,child:TMNode;
	internal:TMInternal;
	leaf:TMLeaf;
begin
  nodes:=TQMNode.create;
	results:=TVecEntry.create;
	if (m_top <> nil) then
		nodes.push(m_top);

	while (not nodes.isempty()) do
	begin
		current := nodes.Front();
		if current.NodeType=INTERNAL_NODE then
		begin
			internal := TMInternal(current);
			internal.SelectRoutes(query, radius, nodes);
		end
		else
		if current.NodeType=LEAF_NODE then
		begin
			leaf := TMLeaf(current);
			leaf.SelectEntries(query, radius, results);
		end
		else
		begin
			raise Exception.Create('no such node type');
		end;
		nodes.pop();
	end;
	nodes.free;
	result := results;
end;


function TCodaMinaMTree.size():size_t;
begin
	result := m_count;
end;


function TCodaMinaMTree.memory_usage():size_t;
var
	nodes:TQMNode;
	node,child:TMNode;
	i,n_internal,n_leaf,n_entry:integer;
begin
  nodes:=TQMNode.create;
	if (m_top <> nil) then
		nodes.push(m_top);

	n_internal := 0;
	n_leaf := 0;
	n_entry := 0;
	while (not nodes.isempty()) do
	begin
		node := nodes.Front();
		if node.NodeType=INTERNAL_NODE then
		begin
				inc(n_internal);
				for i:=0 to myNROUTES-1 do
				begin
					child := node.GetChildNode(i);
					if (child<>nil) then
					 nodes.push(child);
				end;
		end
		else
		if node.NodeType=LEAF_NODE then
		begin
			inc(n_leaf);
			n_entry :=n_entry + node.size();
		end;
		nodes.pop();
	end;
  nodes.free;
	result := (n_internal*sizeof(TMInternal) + n_leaf*sizeof(TMLeaf)
			+ m_count*sizeof(TDBEntry) + sizeof(TCodaMinaMTree));
end;
procedure TCodaMinaMTree.PrintTree(aprint:TMNode.PrintNode);
var
  nodes:TQMNode;
	current,child:TMNode;
	internal:TMInternal;
	i,depth:integer;
	leaf:TMLeaf;
begin
  depth:=0;
  nodes:=TQMNode.create;
	if (m_top <> nil) then
		nodes.Push(m_top);
	while (not nodes.IsEmpty()) do
	begin
		current := nodes.Front();
		if current.NodeType=INTERNAL_NODE then
		begin
			internal := TMInternal(current);
			internal.print(aprint);
			for i:=0 to internal.size-1 do
			begin
				child := internal.GetChildNode(i);
				if (child<>nil) then
				  nodes.push(child);
			end;		
		end
		else
		if current.NodeType=LEAF_NODE then
    begin
			leaf := TMLeaf(current);
			leaf.print(aprint);
		end
		else
		begin
			raise Exception.Create('no such node type');
		end;
		nodes.pop();
	end;
	m_count := 0;
end;

constructor KeyObject.create(const akey:uint64);
begin
  key:=akey;
end;
function KeyObject.distance(const other:KeyObject):int64;
begin
	result := PopCnt(key xor other.key);
end;

procedure print(const v:KeyObject);
begin
  writeln(stdout,' KeyObject:',v.key);
end;
procedure tesTCodaMinaMTree();
const nroutes:integer = 2;
      LEAFCAP:integer  = 10;
type
  TEntryKey=specialize Entry<KeyObject>;
  TVecEntryKeyObject=specialize TCodaMinaVector<TEntryKey>;
  myMTree=specialize TCodaMinaMTree<KeyObject>;
  myRoute=specialize RoutingObject<KeyObject>;
  myDBEntry=specialize DBEntry<KeyObject>;

  function generate_data(entries:TVecEntryKeyObject; const N:integer):integer;
  var
    i,j:integer;
    entry:TEntryKey;
  begin

  	for i:=0 to N -1 do
    begin
  		entry:=TEntryKey.create(i+1, KeyObject.create(i+100000));
  		entries.push_back(entry);
  	end;

  	result := entries.size();
  end;
var
  entries:TVecEntryKeyObject;
	results:TVecEntryKeyObject;
  mtree:myMTree;
  i:integer;
begin
  myRoute.n_build_ops:=0;

  mtree:=myMTree.create(2,10);
  entries:=TVecEntryKeyObject.Create;
  i:=generate_data(entries, 500);
  writeln(stdout,'entries size:',i);
  for i:=0 to entries.Size()-1 do
  begin
  	mtree.Insert(entries.get(i));
  end;
	//mtree.printTree(@print);
  writeln(stdout,'n_build_ops:',myRoute.n_build_ops);
  myDBEntry.n_query_ops := 0;
	results := mtree.RangeQuery(entries.get(13).key, 3);
	writeln(stdout,'=>Found: ' ,  results.size() ,' entries');;
	for i:=0 to results.size()-1 do
	begin
		writeln(stdout,'  (' ,results.get(i).id ,') ', results.get(i).key.key);
	end;
end;


end.
