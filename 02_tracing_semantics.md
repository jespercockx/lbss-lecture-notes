

Small-step Operational Semantics
=================



The overall goal of this course is to investigate language-based
countermeasures to security vulnerabilities. But before we can do
this, we first need to understand what a programming language _is_. In
particular, we need to understand how a language executes a
program. In this lecture, we study a simple yet formal model of
program execution, the small-step operational semantics (SOS). As
examples, we will study the SOS of three toy programming languages:
the Calc language, the Assign language, and the Compiled Assign
language.

**Learning objectives.** In this chapter you will learn:

- how to use the Extended Backus-Naur Form to define the syntax of programming languages.
- how to give formal meaning to programs using small-step operational
  semantics,
- how to write down the execution trace of a program,
- how to model programs with mutable variables,
- how to compile named variables to numeric heap indices.


## The Calc language

> "The establishment of formal standards for proofs about programs... and the
> proposal that the semantics of a programming language may be defined
> independently of all processors for that language, by establishing standards of
> rigor for proofs about programs in the language, appears to be novel."\footnote{
> From "Assigning Meanings to Programs" by Robert W. Floyd, published in
> "Proceedings of Symposium on Applied Mathematics", Volume 19 (pp. 19-20), 1967.}

To study security properties at the level of the programming language, ideally
we would study a real programming language to ensure that our findings apply
to the real world. However, there are some obstacles to this:

1. Real programming languages are *too large*, which makes them difficult to study.
2. Most programming languages used in practice *do not have a formal semantics*
   (though there are some exceptions, for example the Standard ML language).
3. With a real programming language, it is *hard to see how programs are executed*
   step-by step, since programs are either compiled to low-level machine code
   or are interpreted by a highly optimized virtual machine.

Instead, we start our investigation with a very simple language called Calc.
Calc consists of arithmetic expressions involving `+`, `-`, `*` and `/`,
Boolean expressions involving `&&`, `||`, `!` and `==`.

The **syntax** of a programming language determines the basic grammar
of the language, i.e. which programs are considered well-formed.
To define the syntax of
Calc, we use EBNF (Extended Backus-Naur Form)\footnote{See
\url{https://en.wikipedia.org/wiki/Extended_Backus\%E2\%80\%93Naur_form}.}:

    Expr    ::= Literal | Expr BinOp Expr | UnOp Expr
    BinOp   ::= '+' | '-' | '/' | '*' | '&&' | '||' | '=='
    UnOp    ::= '-' | '!'
    Literal ::= Number | 'true' | 'false'

EBNF is the standard syntax for defining the grammar of a programming
language (or more generally any context-free grammar). It consists of
\emph{terminal symbols} such as \tt{'true'} and \emph{non-terminal symbols} such
as \tt{Expr}. Each non-terminal symbol \tt{S} has a \emph{production rule} of
the form \tt{S ::= U1 | ... | Un} where \tt{U1}, ..., \tt{Un} are sequences of
terminal and non-terminal symbols.

To generate a valid expression in the grammar, we start with a
non-terminal symbol, e.g. Expr, and iteratively replace non-terminal
symbols by one of the alternatives in its production rule (and
removing the quote symbols around terminal symbols). For example, the
above syntax allows us to spell out simple programs such as

    (true || false) && (5 == 2+3)

by applying the production rules as follows:

        Expr
    ->  Expr BinOp Expr
    ->  Expr && Expr
    ->  (Expr BinOp Expr) && Expr
    ->  (Expr || Expr) && Expr
    ->  (Literal || Expr) && Expr
    ->  (true || Expr) && Expr
    ->  ...
    ->  (true || false) && (5 == 2+Number)
    ->  (true || false) && (5 == 2+3)

On the other hand, `(+ == 5) ! 44` is not a valid Calc program since
there is no way to construct `+ == 5` by applying the production rules.

**Exercise**: Write down 3 syntactically valid Calc programs, and
  indicate which production rules are used in the construction of
  these programs. Also write down one program that is not a valid Calc
  program.

**Exercise**: The rule for the non-terminal Number was omitted from
  the above grammar. Can you write down a production rule such that
  valid numbers such as 42, 9000, and 0 are accepted, but invalid
  strings such as 001 are not?

In the remainder of this text, we use the symbols $e,e_1,e_2,\ldots$
to represent expressions, $l,l_1,l_2,\ldots$ to represent literal
values, $\tt{bop}$ to represent binary operations, and $\tt{uop}$ to
represent unary operations.

But how does Calc execute such program? That is, what is the **semantics** of
Calc? We define the semantics of Calc as a reduction relation that evaluates a
program one step at a time. For example, we write $\true \tt{ \&\& } \false
\red \false$ to say that $\true \tt{ \&\& } \false$ evaluates to $\false$. To
define the reduction relation `$\red$' formally, we make use of *natural
deduction*. In natural deduction, we define logical predicates using *inference
rules* of the form

\begin{mathpar}
\inferrule{\mathit{hypothesis}_1 \\ \cdots \\ \mathit{hypothesis}_n}{\mathit{conclusion}}
\end{mathpar}

For example, the reduction behaviour of the boolean conjunction `&&`
is defined by the following inference rules (all of which have 0
hypotheses):

\begin{mathpar}
\inferrule{\ }{\true \tt{ \&\& } \true \red \true}

\inferrule{\ }{\true \tt{ \&\& } \false \red \false}

\inferrule{\ }{\false \tt{ \&\& } \true \red \false}

\inferrule{\ }{\false \tt{ \&\& } \false \red \false}
\end{mathpar}

Instead of enumerating a lot of simple rules like this, we assume a
pre-defined operator $\overline{\tt{op}}$ for each Boolean and
numeric operator `op`. Note that we assume pre-defined operators
$\overline{\tt{op}}$ only yield a result when both arguments are
literals of the appropriate type. We summarize the application of all
pre-defined operators in the following two inference rules:

\begin{mathpar}
\inferrule{\ }{l_1 \bop l_2 \red l_1 \sbop l_2}

\inferrule{\ }{\uop l_1 \red \suop l_1}
\end{mathpar}

In case the operator arguments are not literals yet, we have to reduce
them first. The following three inference rules take care of that by
recursively reducing one of the operands and reconstructing an
operator call with the reduced operand.

\begin{mathpar}
\inferrule{e_1 \red e_1'}{e_1 \bop e_2 \red e_1' \bop e_2}

\inferrule{e_2 \red e_2'}{l \bop e_2 \red l \bop e_2'}

\inferrule{e_1 \red e_1'}{\uop e_1 \red \uop e_1'}
\end{mathpar}

The previous five rules form the semantics of Calc. The formalism we
have been using is known as _small-step operational semantics (SOS)_,
where we reduce a program stepwise through a reduction relation $e_1
\red e_2$. For example, we can stepwise the reduce program `(1 + 2) ==
(3 * 4)` as follows:

$$
    \tt{(1 + 2) == (3 * 4)}
    \red \tt{3 == (3 * 4)}
    \red \tt{3 == 12}
    \red \tt{false}
$$

The advantages of small-step operational semantics over
other formalisms are:

 - It provided a simple syntactic formalism for studying programming
   languages.
 
 - It yields traces that allow us to observe every intermediate state
   of a program. For example, we can see in the reduction trace above that the
   addition was reduced before the multiplication.
 
 - It also works for non-terminating programs, yielding infinitely
   long traces.

**Exercise**: Write down the reduction traces of the following programs.

 - `(true || false) && (5 == 2+3)`
 - `(2 == 3) && (2 + 3)`

There is a bit of terminology associated with reduction relations that will become useful:

 - A *normal form* is an expression that cannot be further reduced,
    \ie an expression $e_1$ such that there is NO $e_2$ with $e_1 \red
    e_2$. For example, `5`, `true`, and `5 + true` are normal forms of Calc.
    
 - A *value* is a "good" normal forms, for Calc they are numeric and
   Boolean literals. For example, `5` and `true` are values of Calc.
   
 - A *stuck term* is a normal form that is not a value. For example,
   ill-typed terms such as `5 && true` are stuck terms in the Calc
   language.

We have defined the reduction semantics of Calc. But Calc programs are
boring and have no interesting intermediate states for us to
observe. So let's move on to a slightly more powerful language.

## The Assign language

To make our language more interesting, we extend it to support variable
assignments. For example, here is a program we want to support:

```
x := 1 + 1;
y := 2;
z := x == y;
```

We model assignments as statements, where we
assign the result of an expression to a named variable. A program then
is simply a sequence of statements:

    Prog       ::= Stmt ';' Prog | ''
    Stmt       ::= Identifier ':=' Expr
    Expr       ::= Identifier | Literal | Expr BinOp Expr | UnOp Expr
    BinOp      ::= '+' | '-' | '/' | '*' | '&&' | '||' | '=='
    UnOp       ::= '-' | '!'
    Literal    ::= Number | 'true' | 'false'
    Identifier ::= String

**Exercise**: Write down 2 syntactically valid and 2 syntactically
  invalid programs using statements.

Since we added variable assignments, we need a more complex semantic
model. In particular, we need to keep track of the current value of a
variable throughout program execution. These values are stored on the
*heap*, a part of the computer memory. We extend our model to include
an abstract representation of the heap as a list of entries of the
form `x = v` where `x` is a variable name and `v` is a value:

    Heap ::= '' | Identifier '=' Literal ';' Heap

For example, `x=2; y=2; ` is a valid heap. 

We index a heap by the names of the variables. We write $\hget{h}{x}$
for the value assigned to variable $x$ by heap $h$ (if there is such a
value in $h$) and $\hput{h}{x}{l}$ for the new heap $h'$ where the
value assigned to $x$ is overwritten by $l$. While a lookup does not
change the heap, a storage operation yields the updated heap as
output. We assume the following axioms hold for \tt{get} and \tt{put}:

 - $\hget{\hput{h}{x}{l}}{x} = l$
 - $\hget{\hput{h}{x}{l}}{y} = \hget{h}{y}$ if $x \neq y$

In the Assign language, expressions can read the current value of
variables, but expressions cannot modify variable values. Thus, we
need to modify our reduction relation $e_1 \red e_2$ for expressions
from above to provide access to the current heap. To this end we
define a new relation $e_1, h \red e_2$ for expressions that receives
an expression and a heap as input, and yields an expression as output.

\begin{mathpar}

\inferrule{\hget{h}{x} = l}{x,h \red l}

\inferrule{\ }{(l_1 \bop l_2) , h \red l_1 \sbop l_2}

\inferrule{\ }{(\uop l) , h \red \suop l}

\inferrule{e_1 , h \red e_1'}{(e_1 \bop e_2) , h \red e_1' \bop e_2}

\inferrule{e_2, h \red e_2'}{(l \bop e_2) , h \red l \bop e_2'}

\inferrule{e , h \red e'}{(\uop e) , h \red \uop e'}

\end{mathpar}

We made three changes. First, we added a case for variables, where we
look up the value of the variable in the heap. Second, we extended the
rules for evaluating operators $\sbop$ and $\suop$ to ignore the
heap. And third, when reducing an operand, we make sure to pass along
the current heap.

**Question**: Why do we not need to output a new heap for expressions?

With the reduction relation for expressions in place, we can now
define a reduction relation $p_1 , h_1 \red p_2 , h_2$ where $p_1$ and
$p_2$ are programs and $h_1$ and $h_2$ are heaps. Since programs
feature assignments, program reduction can change the heap. Initially,
we start reduction with an empty heap.

\begin{mathpar}

\inferrule{h' = \hput{h}{x}{l}}{(x \ass l; P), h \red P, h'}

\inferrule{e,h \red e'}{(x \ass e; P), h  \red  (x \ass e'; P), h}

\end{mathpar}

Since we employ small-step reduction semantics, we can inspect the
traces of programs. In our current language, this means we can also
inspect changes to the heap during the execution of the
program. Indeed, this is our main motivation for choosing a stepwise
program reduction regime.

**Exercise**: Write down the execution traces of the following programs:

- `x := 1 + 2; y := 3 * x; x := y - 2;`
- `x := 2; x := x * x; x := x * x;`
- `x := 2; y := 4; x := x * y; y := x * y;`

Are `x` and `y` different in the final heap? Were `x` and `y` equal at
any time?

Answer for the first program:

$$ \begin{array}{cl@{\ }l@{\ }l@{\ \ ,\ \ }r}
    &\tt{x := 1 + 2;}& \tt{y := 3 * x;}& \tt{x := y - 2;} & \tt{} \\
    \red &\tt{x := 3;}& \tt{y := 3 * x;}& \tt{x := y - 2;} & \tt{} \\
    \red &&\tt{y := 3 * x;}& \tt{x := y - 2;} & \tt{x=3;} \\
    \red &&\tt{y := 3 * 3;}& \tt{x := y - 2;} & \tt{x=3;} \\
    \red &&\tt{y := 9;}& \tt{x := y - 2;} & \tt{x=3;} \\
    \red &&&\tt{x := y - 2;} & \tt{y=9;x=3;} \\
    \red &&&\tt{x := 9 - 2;} & \tt{y=9;x=3;} \\
    \red &&&\tt{x := 7;}  & \tt{y=9;x=3;} \\
    \red &&&&\tt{y=9;x=7;} \\
\end{array} $$

The variables `x` and `y` are different in the final heap and were
never equal at any time.


## Compiled Assign language

One disadvantage of the semantic model we investigated so far is that
it is very high level. That is, our model conceals many technical
aspects of program execution. Unfortunately, it is exactly these
technical aspects that make up security vulnerabilities that are
exploited in practice. To study (and counter) such vulnerabilities, we
have to make these technical aspects explicit in our model. We will do
this by compiling our language to a more low-level language and use
stepwise reduction semantics there.

A *compiler* is a piece of software that translates code written in a
high-level programming language to low-level machine code that can be
executed by the computer. Famous examples of compilers are GCC and
LLVM (both compilers for the C language). A typical compiler consists
of many separate *compiler passes* that transform the code in a
particular way and together make up for the whole compilation process.

We define a compiler pass that translates the Assign language to a
more low-level language -- called Compiled Assign -- that has
instructions, a program counter, and numerically-indexed variables. In
the syntax, we have instructions Instr instead of statements and
memory location indexes Idx instead of variable names.

    Prog    ::= Instr ';' Prog | ''
    Instr   ::= Idx ':=' Expr
    Expr    ::= Idx | Literal | Expr BinOp Expr | UnOp Expr
    BinOp   ::= '+' | '-' | '/' | '*' | '&&' | '||' | '=='
    UnOp    ::= '-' | '!'
    Literal ::= Number | 'true' | 'false'
    Idx     ::= '#' Number

Note that expressions in Assign and Compiled Assign have the same
syntax, so the only difference is that variables are represented as
numbers instead of names. To compile an Assign program to a Compiled
Assign program, we can thus pick for each variable `x` in the program
a unique index `idx(x)`, and replace each occurrence of `x` with
`#idx(x)`.

**Exercise**: Compile the following Assign programs to Compiled
  Assign:

- `x := 1 + 2; y := 3 * x; x := y / 2;`
- `x := 2; x := x * x; x := x * x;`
- `x := 2; y := 4; x := x * y; y := x * y;`

**Answer** (for the third program):

    P  =  #0 := 2; #1 := 4; #0 := #0 * #1; #1 := #0 * #1;

Instead of a heap that associates values to variable names, we use a
more realistic model with numerically indexed memory cells.

    Heap ::= '' | Literal ';' Heap | '_' ';' Heap

We write underscores `_` in the
heap to denote that a cell is not initialized and we don't know what
value is stored inside it.

Finally, a program state consists of the program `P`, the program
counter `PC` that identifies next program instruction, and the heap:

    State ::= Prog ',' PC ',' Heap
    PC    ::= Number

A program state State describes the complete state of a running
program. Hence, we can define the reduction semantics of our language
as a reduction relation $s_1 \red s_2$ where $s_1$ and $s_2$ are
states.

Since the relation $e_1,h \red e_2$ does not affect the heap, it is
not really interesting to model it in detail. Therefore, from now on,
we evaluate expressions into normal forms in a single step $e,h \reds
l$ where $l$ is a literal (this is the _Big-step Operational
Semantics (BOS)_ of expressions).

\begin{mathpar}
\inferrule{\ }
  {l , h \reds l}

\inferrule{e , h \red e' \\ e' , h \reds l}
  {e , h \reds l}
\end{mathpar}

The semantics of the Compiled Assign language then is defined by the
following state transition relation:

\begin{mathpar}
\inferrule
  {P[\pc] = \#i \ass e; \\ e,h \reds l \\ h' = \hput{h}{i}{l}}
  {P,\pc,h \red P,\pc+1,h'}
\end{mathpar}

The lookup of numerically indexed variables in expressions is a simple
adoption of the rule we've seen above:

\begin{mathpar}
\inferrule{\hget{h}{i} = l}{i,h \red l}
\end{mathpar}

**Exercise**: For each of the programs you compiled in the previous
  exercise, write down the execution traces of the compiled programs.
  Are x and y different in the final heap? Were x and y equal at any
  time?

**Answer** (for third program): We need a heap with two cells #0 and
  #1 to execute this program, then we can compute the reduction trace
  of the program as follows:

      P , 0 , (_ ; _ )
    → P , 1 , (2 ; _ )
    → P , 2 , (2 ; 4 )
    → P , 3 , (8 ; 4 )
    → P , 4 , (8 ; 32)

**Question**: Can you already spot weaknesses in our model of Assign?
Are these weaknesses vulnerabilities? Why?

## Summary

- To reason about the behaviour of a program, we need to understand
  how programs are executed. *Program semantics* assign a formal
  meaning to each program.
- In this course we mainly study one particular semantics called the
  *small-step operational semantics* (SOS).
- SOS yields for each program a *trace* which is the sequence of all
  intermediate states of the program.
- The Calc language models simple arithmetic and boolean expressions.
- The Assign language extends Calc with mutable variables that are stored
  on a heap.
- Named variables can be compiled to numeric indices into the heap by
  assigning a unique index to each variable in advance.

## Further reading

- Plotkin. A Structural Approach to Operational Semantics. (\url{homepages.inf.ed.ac.uk/gdp/publications/sos_jlap.pdf})
- Chapter 3 of: Pierce. Types and Programming Languages. The MIT Press.
- Chapter 13 of: Pierce. Types and Programming Languages. The MIT Press.