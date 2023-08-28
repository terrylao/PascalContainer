# PascalContainer
contributor: gcarreno  at github <br/>
generic pascal data structure with <br/>
B-Tree,<br/>
B+-Tree,<br/>
B*-Tree,<br/>
T-Tree,<br/>
HashMap,<br/>
priority queue, <br/>
red-black-Tree,<br/>
AVL-tree,<br/>
Quad-Tree,<br/>
SkipList,<br/>
Sortable Single Linklist,<br/>
Sort Function,<br/>
LockFreeQueue.<br/>
2023/08/28 加入: nth_element.<br/>
一個C++ 的類 STL nth_element, 有用到的人有用囉。 <br/>

基本上都夠用的。<br/>
Sort function 的測試：<br/>
測試參數： -O3<br/>
測試量：10M integer<br/> 
測試結果：DualPivotQuickSort 1680ms > quicksort3PivotBasic 1700ms > quicksort 1770ms > IterativequickSort 1800ms > mergesort 2260ms >  Iterativemergesort 3120ms。<br/>
generic QuickSort 與非 generic 的慢約500ms ，<br/>
非generic Quicksort 的 FPC 與 GCC 同樣開 -O3 ，FPC 慢約100ms。<br/>




源碼以BSD LICENSE 發佈：<br/>
BSD開源協議是一個給於使用者很大自由的協議。基本上使用者可以"為所欲為",可以自由的使用，修改源代碼，也可以將修改後的代碼作為開源或者專有軟件再發佈。<br/>

但"為所欲為"的前提當你發佈使用了BSD協議的代碼，或則以BSD協議代碼為基礎做二次開發自己的產品時，需要滿足三個條件：<br/>

如果再發佈的產品中包含源代碼，則在源代碼中必須帶有原來代碼中的BSD協議。<br/>
如果再發佈的只是二進制類庫/軟件，則需要在類庫/軟件的文檔和版權聲明中包含原來代碼中的BSD協議。<br/>
不可以用開源代碼的作者/機構名字和原來產品的名字做市場推廣。<br/>
BSD 代碼鼓勵代碼共享，但需要尊重代碼作者的著作權。BSD由於允許使用者修改和重新發佈代碼，也允許使用或在BSD代碼上開發商業軟件發佈和銷售，因此是對 商業集成很友好的協議。<br/>而很多的公司企業在選用開源產品的時候都首選BSD協議，因為可以完全控制這些第三方的代碼，在必要的時候可以修改或者二次開發。<br/>
