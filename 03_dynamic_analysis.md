

Dynamic analysis of array bounds
================================

In the previous chapter we discussed how a tracing semantics allows us to observe
the execution of a program. In particular, tracing exposes the
intermediate states of the execution, which contains information
neither available before or after execution. We also studied the
Assign language which has mutable variables. For this language, it is
possible to calculate in advance exactly how much memory is needed on
the heap: for each variable in the program, there must be space for
one number or boolean.

However, most real-world programs need to allocate memory dynamically so the
maximum size of the heap cannot be computed in advance. The memory locations
they access is often also unpredictable, such as an array index that is given
by user input. Both these features -- dynamic memory allocation and
unrestricted memory access -- open the door to new security vulnerabilities,
such as accessing unititialized memory, buffer over- and underflows, and
forging of pointers. For example, the Heartbleed vulnerability in
OpenSSL\footnote{\url{https://heartbleed.com/}} was only possible because the
program was reading a part of the memory that should have been kept secret.

To study this class of security vulnerabilities, we will extend the
Assign language with mutable arrays and dynamic memory allocation. We
will then use the trace semantics to build and understand
error-detection mechanisms that allow us to prevent these security
vulnerabilities.

**Learning objectives.** In this chapter you will learn:

- how to model a programming language with mutable arrays and dynamic memory allocation,
- what security vulnerabilities can arise from unrestricted memory access,
- how to apply two different dynamic analysis techniques -- *monitoring* and *instrumentation* -- to perform array index bounds checking,
- what distinguishes monitoring from instrumentation and when you should apply one or the other.

The Array language
------------------

As basis for our study of error detection, we extend our previous
language with statements for creating, reading, and writing arrays. We
also add an expression for obtaining the length of an array.

    Prog       ::= Stmt ';' Prog | ''
    Stmt       ::= Identifier ':=' Expr
                 | Identifier ':=' 'arnew' Expr                // x[n];
                 | Identifier ':=' 'arread' Identifier Expr    // y = x[i];
                 | 'arwrite' Identifier Expr Expr              // x[i] = e;
    Expr       ::= Identifier | Literal | Expr BinOp Expr | UnOp Expr
                 | 'arlen' Identifier
    BinOp      ::= '+' | '-' | '/' | '*' | '&&' | '||' | '=='
    UnOp       ::= '-' | '!'
    Literal    ::= Number | 'true' | 'false'
    Identifier ::= String

The language now includes statements for allocating an new array of a
given size (`x := arnew e`), reading a value of a given array at a given
index (`x := arread x e`), and writing a given array at a given index
with a given value (`arwrite x e1 e2`). It also includes an expression
for getting the length of a given array (`arlen x`).

**Exercise**: Write down 2 syntactically well-formed programs that
  include all the new syntactic forms.

**Answer**: Here's one example Array program:

    a := arnew 5;
    arwrite a 0 0;
    y := arread x 0;
    z := arread y 0;

Each time a new array is created with `arnew`, the computer needs to allocate a
new part of the memory for storing this array. Aside from the contents of the
array itself, we will also store the *length* of the array for the
implementation of the `arlen` operation. Hence, an array of length $n$ will
take up $n+1$ locations in memory. For example, during the execution of the
Array program given above, the memory evolves as follows:

          x   y   z
    0   [ _ , _ , _ ]
    1   [ 3 , _ , _ , 5 , _ , _ , _ , _ , _ ]
    2   [ 3 , _ , _ , 5 , 0 , _ , _ , _ , _ ]
    3   [ 3 , 0 , _ , 5 , 0 , _ , _ , _ , _ ]
    4   [ 3 , 0 , 0 , 5 , 0 , _ , _ , _ , _ ]

**Question**: Can we give an operational semantics to Array directly? Or is
there anything that makes this difficult?

**Answer**: Consider the following program:

    x := arnew 2;
    y := x;
    arwrite y 0 42;
    z := arread x 0;

While executing this program, the memory evolves as follows:

          x   y   z  
    0   [ _ , _ , _  ]   
    1   [ 3 , _ , _  , 2 , _  , _ ]
    2   [ 3 , 3 , _  , 2 , _  , _ ]
    3   [ 3 , 3 , _  , 2 , 42 , _ ]
    4   [ 3 , 3 , 42 , 2 , 42 , _ ]

From step 2 onwards, the variables `x` and `y` both point to the array at
location `3` in the memory. This is called **aliasing**: the variables x and y
are aliases to the same location in memory. Without an explicit model of the
memory of the program, aliasing can be tricky to model correctly.

For this reason, we refrain here from giving an operational semantics to the Array
language. Instead, we will give meaning to Array programs by compiling
them to a lower-level language that uses numeric indices in place of
variable names.

\begin{comment} TODO: This small-step operational semantics below is
inaccurate as it ignores the possibility of aliasing.

We will now give a small-step operational semantics (SOS) to the Array
language. Compared to the Assign language, the main thing that needs
to be changed is that the heap should now be able to store not just
single values but also entire arrays. So we update the syntax for
`Heap` as follows:

    Heap  ::= '' | Identifier '=' Literal ';' Heap
            | Identifier '=' 'array' Array ';' Heap
    Array ::= '' | Literal ';' Array | '_' ';' Array

The heap can still contain entries of the form `x = l` (for normal
variables) but now also contains entries of the form `x = array
a`. Here `a` is a list of the values stored in the array, some of
which may be uninitialized ('_').

To define the reduction relation $\red$, we only give the rules for
the new constructs of the Array language. The only new kind of
expression is `arlen x`:

\begin{mathpar}
\inferrule{\hget h x = \tt{array}\ a}
  {\arlen x , h \red \textit{length}(\tt{ls})}
\end{mathpar}

Here $\textit{length}(a)$ is (as you might have guessed) the length of
the array $a$.

We also have three new kinds of statements: \tt{arnew}, \tt{arread},
and \tt{arwrite}.

* To execute $x \ass \tt{arnew} e$, we first evaluate $e$ to a
  literal $l$ and then add $x = \textit{emptyArray}(l)$, where
  $\textit{emptyArray}(l)$ is a new array of length $l$ consisting of
  repeated underscores (`_`).
  \begin{mathpar}
  \inferrule{
    e , h \reds l \\
    h' = \hput h x {\tt{array}\ \textit{emptyArray}(l)} \\
  }{
    (x \ass \arnew e; P) , h \red P , h'
  }
  \end{mathpar}

* To execute $x \ass \arread y e$ we first look an entry $y =
  \tt{array}\ a$ on the heap. We then evaluate $e$ to a literal $l_1$
  and take the $l_1$-th element of the array $a$, which we store in
  the variable $x$.
  \begin{mathpar}
  \inferrule{
    \hget h y = \tt{array}\ a \\
    e , h \reds l_1 \\
    \hget a l_1 = l_2 \\
    h' = \hput h x {l_2}
  }{
    (x \ass \arread y e; P) , h \red P , h'
  }
  \end{mathpar}

* To execute $\arwrite x {e_1} {e_2}$, we again start by looking for
  an entry $x = \tt{array}\ a$ on the heap. We evaluate both $e_1$ and
  $e_2$ to $l_1$ and $l_2$ respectively. Finally, we update the array
  $a$ by replacing the entry at position $l_1$ with the value $l_2$.
  \begin{mathpar}
  \inferrule{
    \hget h x = \tt{array}\ a \\
    e_1 , h \reds l_1 \\
    e_2 , h \reds l_2 \\
    \hput a {l_1} {l_2} = a' \\
    \hput h x {a'} = h'
  }{
    (\arwrite x {e_1} {e_2}; P) , h \red P , h'
  }
  \end{mathpar}

\end{comment}


Compiled Array language
-----------------------

\begin{comment}
The heap model of the Array language we have just studied is
convenient for giving a precise semantics to the language, but it is
not very realistic. In particular, arrays that are stored on the heap
each are a `mini-heap' of their own, while a real computer uses one big heap that stores everything in memory.
\end{comment}

To model accurately how an Array program would be executed on a real
machine, we compile it to a more low-level language called Compiled
Array that features instructions and numerically-indexed variables.

**Syntax**

    Prog    ::= '' | Instr ';' Prog
    Instr   ::= Idx ':=' Expr
              | Idx ':=' 'arnew' Expr
              | Idx ':=' 'arread' Idx Expr
              | 'arwrite' Idx Expr Expr
    Expr    ::= Idx | Literal | Expr BinOp Expr | UnOp Expr
              | 'arlen' Idx
    BinOp   ::= '+' | '-' | '/' | '*' | '&&' | '||' | '=='
    UnOp    ::= '-' | '!'
    Literal ::= Number | 'true' | 'false'
    Idx     ::= '#' Number

**Question**: Do we need \tt{arlen} in our Compiled Array language or can we
  emulate it through other language constructs? If we can emulate it, why then
  did we include \tt{arlen}?

**Answer**: No, it is not strictly required. An alternative design
  would be to look up the array value as position `-1`, as the length
  is always stored immediately before the array itself. It is
  typically considered bad language design to introduce duplicate
  features. However, in this situation treating \tt{arlen} as an
  explicit feature allows us to change the layout of the array header
  later on (to add more information to the array header). Thus,
  treating \tt{arlen} as a separate feature decouples the layout of
  the array header from variable lookup. That is, \tt{arlen} is part
  of the array abstraction.

To compile an Array program to a Compiled Array program, we assume
again that each variable name is assigned a unique index `idx(x)`. The
compilation of expressions is straightforward: every variable `x` is
replaced by its index `idx(x)`. Likewise, we compile statements of the
Array language to instructions of the Compiled Array language as
follows:

    compile(x := e) =
      [|
        idx(x) := compile(e);
      |]

    compile(x := arnew e) =
      [|
        idx(x) := arnew compile(e);
      |]

    compile(x := arread y e) =
      [|
        idx(x) := arread idx(y) compile(e);
      |]

    compile(arwrite x e1 e2) =
      [|
        arwrite idx(x) compile(e1) compile(e2);
      |]

**Exercise**: Compile the following programs:

    a := arnew 2; arwrite a 0 42; arwrite a 1 (arlen a);

    x := arnew 2; y := x; arwrite y 0 42; z := arread x 0;

    a := arnew 2; arwrite a 1 (21 + 21); b := arread a 0; 

    x := 0; a := arnew 2; arwrite a (-3) 1;

We define the semantics of the compiled language as a transition
relation $s_1 \red s_2$ on machine states $s$. A machine state is the
same in the Assign language:

    State ::= Prog ',' PC ',' Heap
    PC    ::= Number
    Heap  ::= '' | Literal ';' Heap | '_' ';' Heap

In addition to the heap operations \tt{get} and \tt{put}, we will also
need a heap operation $\halloc{h}{n}$ for allocating new memory when
creating a new array. The allocation operation extends the heap with
$n$ new memory cells. The result of allocation is a pair $(h,i)$ where
$h$ is the updated heap and $i$ is the index where the allocated heap
region begins.

**Question**: We designed the Array language such that all array
  operations (except \tt{arlen}) occur as statements, and we compiled
  the array language such that all array operations (except
  \tt{arlen}) occur as instructions. What do you think was the reason
  for having these operations as statements/instructions?

**Answer**: Expressions are not observable in the trace because we
  evaluate them in big step. Thus, if we want to reason about or
  affect array operations, we need to make them instructions in the
  compiled code.

The semantics of the Array language then is defined by the state
transition relation $s_1 \red s_2$. Each of the rules starts by
looking at the current instruction $P[\pc]$ and does something based
on which instruction is encountered.

* To execute $\#i \ass e$, we evaluate $e$, put the result on the heap
  at position $i$, and continue with the next instruction.

  $$ \inferrule{
    P[\pc] = i \ass e \\
    e,h \reds l \\
    \hput{h}{i}{l} = h' }{
    P,\pc,h \red P,\pc+1,h'
  } $$

* To execute $i \ass \arnew e$, we evaluate $e$ to get the length $l$ of
  the new array, then allocate space for that many elements plus one
  cell for storing the array header. Next, we store the length of the
  array at the beginning of the allocated memory region, and finally
  store the location $j$ of the new array in the variable $i$.

  $$ \inferrule{
    P[\pc] = i \ass \arnew e \\
    e,h_0 \reds l \\  
    \halloc{h_0}{l+1} = (h_1,j) \\
    \hput{h_1}{j}{l} = h_2 \\
    \hput{h_2}{i}{j} = h_3 }{
    P,\pc,h_0 \red P,\pc+1,h_3
  } $$

* To execute $\#i \ass \arread j e$, we evaluate $e$ to get the
  position $l$ and get the starting position $s$ of the array $j$. We
  then get the content $l_2$ of the array at position $l$, skipping
  one cell containing the array header. Finally, we store $l_2$ in
  variable $i$.

  $$ \inferrule{
    P[\pc] = \#i \ass \arread j e \\
    e, h \reds l \\
    \hget h j = s \\
    \hget h {s + 1 + l} = l_2 \\
    \hput h i {l_2} = h' }{
    P, \pc, h \red P, \pc+1, h'
  } $$

* The \tt{arlen} expression looks up the array length in the array
  header:

  $$ \inferrule{
    \hget h i = s \\
    \hget h s = l }{
    \arlen i, h \red l
  } $$

**Exercise**: Define the reduction rule for \tt{arwrite} before
  reading on.

* To evaluate $\arwrite i {e_1} {e_2}$, we first evaluate $e_1$ and
  $e_2$ to $l_1$ and $l_2$ respectively, then retrieve the start
  position $s$ of the array $i$ and finally store the value $l_2$ at
  index $l_1$, skipping one position for the array header.

  $$ \inferrule{
    P[\pc] = \arwrite i {e_1} {e_2} \\
    e_1, h \reds l_1 \\
    e_2, h \reds l_2 \\
    \hget h i = s \\
    \hput h {s + l_1 + 1} {l_2} = h' }{
    P, \pc, h \red P, \pc+1, h'
  } $$

**Exercise**: Write down the execution traces of the following
  programs after compilation.

    a := arnew 2; arwrite a 0 42; arwrite a 1 (arlen a);

    x := arnew 2; y := x; arwrite y 0 42; z := arread x 0;

    a := arnew 2; arwrite a 1 (21 + 21); b := arread a 0; 

    x := 0; a := arnew 2; arwrite a (-3) 1;

**Answer**: The first program compiles to 

    #0 := arnew 2; arwrite #0 0 42; arwrite #0 1 (arlen #0);

and reduces as follows:

$$ \begin{array}{ll@{\ ,\ }l@{\ ,\ }l}
       & P & 0 & (\_) \\
  \red & P & 1 & (1; 2; \_; \_) \\
  \red & P & 2 & (1; 2; 42; \_) \\
  \red & P & 3 & (1; 2; 42; 2 ) \\
\end{array} $$

The third program compiles to

    #0 := arnew 2; arwrite #0 1 (21 + 21); #1 := arread a 0; 

and reduces as follows:

$$ \begin{array}{ll@{\ ,\ }l@{\ ,\ }l}
       & P & 0 & (\_;\_) \\
  \red & P & 1 & (2;\_; 2; \_; \_) \\
  \red & P & 2 & (2;\_; 2; \_; 42) \\
\end{array} $$

Here, we cannot reduce any further since the value of the array at position 0
is undefined, hence the program gets stuck.

The fourth program compiles to 

    #0 := 0; #1 := arnew 2; arwrite #1 (-3) 1;

and reduces as follows:

$$ \begin{array}{ll@{\ ,\ }l@{\ ,\ }l}
       & P & 0 & (\_;\_) \\
  \red & P & 1 & (0;\_) \\
  \red & P & 2 & (0; 2; 2; \_; \_) \\
  \red & P & 3 & (1; 2; 2; \_; \_) \\
\end{array} $$

In the last reduction step, we look up the start address of the array referred
to by index `#1` (which is 2) and compute the address for the write as $(2 + 1
+ (-3)) = 0$. Thus, we overwrite the value of variable `x`.

As these examples illustrate, there are two issues at hand: we can
read uninitialized memory (causing the program to crash), and we can
read and write data outside the bounds of the array. In this
chapter, we will ignore reading uninitialized memory and instead
assume that such reads yield some default value like $0$. This
decision makes sense because reading uninitialized memory by and large
does not pose a security vulnerability.

However, we want to prevent the reading and writing of data outside
the bounds of an array, because this poses a security vulnerability.

**Question**: How could one exploit this vulnerability?

**Answer**: By using indices outside of the bounds of the array, we
  can read sensitive data elsewhere in the heap. We can also overwrite
  data, for example to disable access-control flags to annihilate
  protective measures that are in place.

To detect and prevent access to data outside the bounds of an array,
we are going to use a technique known as dynamic analysis.

Dynamic analysis
----------------

A dynamic analysis checks a program property during the runtime of a
program, that is, while the program is executing. That is, dynamic
analysis prevents certain reduction steps to occur in a reduction
trace. The main advantage of dynamic analysis is that it can access
the runtime state of a program in order to identify violations of the
checked property. Conversely, the main disadvantage of dynamic
analysis is that it only detects violations at runtime (rather than
during development before deploying the code to a customer). Being
executed at runtime, dynamic analysis always has a certain overhead
cost.

To understand how dynamic analysis works, let us define a dynamic
analysis that checks the following program property:

--------------------
**Array index bounds checking**: All array reads and writes are within
the bounds of the array.
--------------------

**Question**: Array index out of bounds checking is a typical dynamic
  analysis. What languages do you know that check array access:
  dynamically, statically (at compile time), not at all?

**Answer**: C does not check array access. Java checks array access
dynamically. Rust uses regions in order to enforce statically that array
accesses are within bounds when the bounds are known statically, while
dependently-typed languages such as Coq and Agda can perform compile-time
bounds checking even when the bounds are only determined at runtime.

There are two common techniques for implementing a dynamic analysis: *runtime
monitoring* and *compile-time instrumentation*. For monitoring, we need to
extend the language's runtime to detect property violations. For
instrumentation, we need to extend the language's compiler to generate code
that detects property violations when executed. Since monitoring is somewhat
simpler, we investigate that technique first.

### Dynamic analysis through runtime monitoring

The basic idea of monitoring is to extend the runtime to detect
illegal state transitions. We can then abort the program execution or
handle the detected violation in other ways (e.g., raising a catchable
exception, or skipping the instruction that triggered the
violation). To detect out-of-bounds array indexes, we have to augment
the state transition relation from above. The rules for assignments
and array allocation remain unchanged, however we change the rules for
array reads and writes.

First, we add an extra condition to the rule for executing $\#i \ass
\arread {\#j} e$ to check that the index $l$ is within the bounds $0$ and
$s$. If the index is not within bounds, the behaviour of the program
is not specified. It might stop execution, or it might continue with a
default value such as $0$. The parts that are changed are marked in \new{red}.

$$ \inferrule{
  P[\pc] = \#i \ass \arread {\#j} e \\
  e, h \reds l \\
  \new{\hget h j = s} \\
  \new{0 \leq l < s} \\
  \hget h {s + 1 + l} = l_2 \\
  \hput h i {l_2} = h' }{
  P, \pc, h \red P, \pc+1, h'
} $$

Likewise, we add an extra condition for the bounds check to the
execution of $\arwrite {\#i} {e_1} {e_2}$. Again, the behaviour for bound
violations is not specified: possible behaviours could be to stop
execution, or to silently ignore the write operation and continue
running the program.

$$ \inferrule{
  P[\pc] = \arwrite {\#i} {e_1} {e_2} \\
  e_1, h \reds l_1 \\
  e_2, h \reds l_2 \\
  \new{\hget h i = s} \\
  \new{0 \leq l_1 < s} \\
  \hput h {s + l_1 + 1} {l_2} = h' }{
  P, \pc, h \red P, \pc+1, h'
} $$

**Exercise**: Write down the execution traces of the following program.

    #0 := 0; #1 := arnew 2; arwrite #1 (-3) 1;

Advantages of monitoring:

- The bounds check is guaranteed to be executed no matter what.
- It does not require changing the compiler or the compiled code in any way, and hence works even with precompiled code.
- It is easy to implement.

Disadvantages of monitoring:

- It requires a run-time system, so does not work for languages without one.
- There is a performance overhead for retrieving array size and bounds checking.
- It checks bounds even when the check is trivially satisfied.

### Dynamic analysis through compile-time instrumentation

The basic idea of instrumentation is that the compiler generates
additional instructions for detecting property violations and for
handling those violations. Thus, instrumentation does not require
support from the runtime system because the error detection code uses
language features that are already available.

To detect out-of-bounds array indexes, we augment the way array read
and write statements are compiled to instructions. Specifically, we
add checks to ensure the index is within the array bounds.

The generated code makes use of two new instructions `jumpif` and `abort`. The
former changes the current value of the program counter if the condition
evaluates to `true` (and does nothing if it is `false`), while the latter
aborts the execution of the program.

    Instr   ::= ... | jumpif Expr Label | abort     
    Label   ::= Number

$$ \inferrule{
  P[\pc] = \jumpif {e} {\pc'} \\
  e,h \reds \true
}{
  P,\pc,h \red P, \pc',h
} \qquad
\inferrule{
  P[\pc] = \jumpif {e} {\pc'} \\
  e,h \reds \false
}{
  P,\pc,h \red P, \pc+1,h
}$$

There are no evaluation rules for the `abort` instruction: if it is ever
reached during execution, we assume that execution stops immediately and hence
there are no subsequent states in the program trace.

We also require additional binary operations for comparing numbers:

    BinOp  ::= ... | '<' | '<=' | '>' | '>='

These operations are evaluated in the obvious way.

The following code illustrates what instructions the compile function would
generate for array read and write statements. The memory location `#tmp` is
considered a reserved location on the heap that is not used in the rest of the
program. For the `jumpif` instruction, we use the label "continue" as jump
target. When implementing this compile function, we would have to compute the
actual numeric program location instead (or rely on a separate compiler pass
that replaces labels by program locations).

    compile( x := arread y e ) =
      [|
        // compute array index
        #tmp := compile(e);
        // jump to 'continue' label if index is within bounds
        jumpif (#tmp >= 0 && #tmp < (arlen #idx(y))) continue;
        // otherwise, abort
        abort "Error: array index out of bounds";
      continue:    
        #idx(x) := arread #idx(y) #tmp;
      |]

    compile( arwrite x e1 e2 ) =
      [|
        // compute array index
        #tmp := compile(e1);
        // jump to 'continue' label if index is within bounds
        jumpif (#tmp >= 0 && (#tmp < (arlen #idx(y)))) continue;
        // otherwise, abort
        abort "Error: array index out of bounds";
      continue: 
        arwrite #idx(x) #tmp compile(e2);
      |]

For other instructions, the compilation is left unchanged.

**Exercise**: Compile and trace the following example:

    x := 0; a := arnew 2; arwrite a (-3) 1;

Our compiler is very simple. However, it wouldn't be too difficult to
extend the compiler to avoid bounds checking when we can guarantee
well-boundness at compile time. In particular, when both the array
size and the array index are known at compile time, we can eliminate
bounds checks. For example, we could compile the following program
more efficiently:

    compile(a := arnew 2; arwrite a 0 true) = 
     [|
       #i := arnew 2;
       arrwrite #i 0 true
     |]

Advantages of instrumentation:

- It works with any runtime system, as well as with languages without one.
- It can avoid unnecessary checks when the checked property can be ensured at compile time.

Disadvantages of instrumentation:

- It requires runtime instructions that are expressive enough and provide
  access to the relevant parts of the program state as long as the
  require data is accessible. (In particular, we required two new instructions `jumpif` and `abort`, and comparison operators `<` and `>=`)
- Code that was compiled with another compiler misses the checking
  instructions and may thus violate the property we wanted to check.
- The size of the compiled code grows due to the introduction of
  additional instructions.

## Summary

- The Array language extends the Assign language with mutable arrays.

- We can compile Array code to Compiled Array code, which uses dynamic
  memory allocation to add new arrays to the heap at run-time.

- Unrestricted memory access allows a program to read and write from
  any part of the memory, leading to potential security
  vulnerabilities.

- Runtime monitoring of array bounds extends the runtime of a
  programming language with array bound check.

- Compile-time instrumentation can insert additional instructions for
  checking array bounds at runtime.

## Further reading

- Cowan, Wagle, Pu, Beattie, and Walpole (2000): *Buffer Overflows:
  Attacks and Defenses for the Vulnerability of the Decade*
  (\url{https://css.csail.mit.edu/6.858/2010/readings/buffer-overflows.pdf})

- Chapter 13 of: Pierce. Types and Programming Languages. The MIT Press.