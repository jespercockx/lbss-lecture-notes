

Dynamic taint analysis
======================

What do the following security vulnerabilities have in common?

- Secret data is leaked to an unauthorized user
- Malicious SQL query in user input is executed
- A number given by user input is used as an array index, leading to a buffer overflow

The answer is that they are all concerned with the *information flow* of the program:
in particular, they can be prevented by restricting certain flow of information.

In this chapter, we study
a dynamic analysis that can prevent these types of security vulnerabilities,
namely **dynamic taint analysis**. 
Taint analysis tracks the flow of sensitive or tainted
information through a program and detects unprivileged access to such data.
To study the flow of information through a program, we will extend our
previous language with top-level function definitions and function
calls.

**Learning objectives.** In this chapter you will learn:

- how to model a programming language with top-level function
  definitions and function calls,
- how stack frames are used to execute programs with recursive
  functions,
- how to formulate the general security property of *non-interference*,
  and how to apply it to specific cases of security properties,
- how to model a language with simple security primitives for
  producing, consuming, and declassifying secret or 'tainted'
  information,
- how to enforce these security primitives through dynamic taint
  analysis, 
- how to assess the soundness and completeness of this analysis.

The Function language
---------------------

As basis for our study of taint analysis, we extend the Assign language
language with top-level (first-order) function definitions:

    Prog       ::= Fun ';' Prog | Stmts
    Fun        ::= 'fun' FunName '(' FunArgs ')' '{' Stmts '}'
    FunName    ::= String
    FunArgs    ::= '' | FunArgs1
    FunArgs1   ::= Identifier | Identifier ',' FunArgs1
    Stmts      ::= '' | Stmt ';' Stmts
    Stmt       ::= Identifier ':=' Expr
                 | Identifier ':=' FunName '(' Args ')'
                 | 'return' Expr
    Args       ::= '' | Args1
    Args1      ::= Expr | Expr ',' Args1
    Expr       ::= Identifier | Literal | Expr BinOp Expr | UnOp Expr
    BinOp      ::= '+' | '-' | '/' | '*' | '&&' | '||' | '=='
    UnOp       ::= '-' | '!'
    Literal    ::= Number | 'true' | 'false'
    Identifier ::= String

A program consists of a list of top-level function definitions and a
main program that gets executed upon startup of the program. We added
two new syntactic forms for statements. The statement `x := f(e1,...,en)` is
used to call an existing function definition, passing along argument
values to the function. The `return` statement can only be used within
a function body to end the function execution and to yield a return
value to the caller.

Note that we can combine the Function language with other extensions
of the Assign language, for example with arrays from the Array
language or with `if`- and `while`-statements from the While language
(from the first assignment). In the examples, we will freely make use
of these other features to make them a bit more interesting.

**Exercise**: Write down a syntactically well-formed program that
  make use of the new syntactic forms.

**Answer**: Here is a Function program that makes use of all the new
  constructs:

    fun twice(x) {
      return x*2;
    };
    fun concat(a,b) {
      c := arnew (arlen a + arlen b);
      i := 0;
      while (i < arlen a) {
        x := arread a i;
        arwrite c i x;
        i := i + 1;
      }
      i := 0;
      while (i < arlen b) {
        x := arread b i;
        arwrite c (arlen a + i) x;
        i := i + 1;
      }
      return c;
    };
    x := twice(3);
    a := arnew x;
    c := concat(a,a);

Introducing functions requires us to make a number of important design
decisions. We need to decide which function can call which other
function, whether a function is allowed to call itself recursively,
and we have to decide when and in which order function arguments get
evaluated. For this course, we decide that functions must adhere to
the following specification:

- Functions can be recursive.
- Functions can call all other functions, including functions that
  are only defined later.
- Functions are call-by-value, that is, the arguments are evaluated
  prior to executing the function body.
- Function calls can only appear in statements of the form `x := f(e1, ...,en)`, they cannot appear inside expressions.

As for the Array language, we do not give a semantics to the Function language
directly, but instead compile it down to a more low-level langauge for which it
is easier to specify the semantics.

Compiled Function language
--------------------------

We compile the Function language to a more low-level language that
features instructions for calling and returning. In particular, the
functions and main program compile to a single list of instructions
where functions do not have an explicit beginning or end.

    Prog    ::= '' | Instr ';' Prog
    Instr   ::= Idx ':=' Expr
              | Idx ':=' 'call' PC FS Exprs
              | 'return' Expr
    Exprs   ::= '' | Expr Exprs
    Expr    ::= Idx | Literal | Expr BinOp Expr | UnOp Expr
    BinOp   ::= '+' | '-' | '/' | '*' | '&&' | '||' | '=='
    UnOp    ::= '-' | '!'
    Literal ::= Number | 'true' | 'false'
    Idx     ::= '#' Number

The machinery for executing function calls is somewhat more involved
than what we have dealt with before. In particular, to ensure proper
scoping of local variables and function parameters, we need to keep
track of function calls on the *stack*. The stack is another part of
the computer memory (distinct from the heap) that contains information
about all function calls that are currently being executed. In
particular, each function call is stored in a *stack frame*.  The
stack frame contains the values of all function arguments, as well as
the local variables of the function we are calling. To this end, we
require the compiler to analyze the source code of the program in
order to generate `call` instructions that know (i) where the
function's instructions reside and (ii) how large the stack frame for
the function needs to be.


For the purpose of the Function language, we represent the stack in 
the same way as the heap. It can thus be accessed in the same way as the
heap using the operations `get`, `put`, and `alloc`. However, in order
to look up variable values in the stack frame, we need to keep track
of where to find the current stack frame. Therefore, we introduce three new *registers*.
So far we have used a single register `PC` for storing the program counter, i.e. the number of the instruction that is currently being executed. To this, we add 
new registers that store the beginning of the current frame on the
stack (`FP` = frame pointer), the current frame size (`FS`
= frame size), and the location where the return value of the function is supposed
to be stored (`RT` = return target). Just like the program counter,
these registers are part of the current state of a program being
executed.

    Registers ::= PC ',' FP ',' FS ',' RT
    State     ::= Prog ',' Registers ',' Stack
    PC        ::= Number      // Program Counter
    FP        ::= Number      // Frame Pointer
    FS        ::= Number      // Frame Size
    RT        ::= Number      // Return Target
    Stack     ::= '' | Literal ';' Stack | '_' ';' Stack

**Question**: Do you spot a potential security vulnerability?

**Answer**: All the registers are plain numbers. One potential
  security vulnerability of our language is that an attacker may try
  to use calculated values for the registers, and thus read or write
  to parts of the memory that should not be accessed (by changing the
  frame pointer or frame size), or change the control flow of the
  program in unintended ways (by changing the program counter or the
  return target).

We extend the reduction relation for expressions to $e_1 , \fp , s
\red e_2$ to pass along the frame pointer $\fp$ and the stack $s$. We
need this index because all interaction with local variables now is
relative to the current stack frame:

\begin{mathpar}
\inferrule{
  \hget{s}{\fp+x} = l }{
  \# x , \fp , s \red l
}
\end{mathpar}

For all other expressions, the frame pointer $\fp$ is simply ignored.

**Question**: What would happen if we did not use separate stack
  frames for each function call?

**Answer**: A recursive function would overwrite its own local
  variables accidentally. This was actually the case in early
  programming languages such as Fortran
  77\footnote{\url{http://www.ibiblio.org/pub/languages/fortran/ch1-12.html}},
  and is still the case on modern GPU programming languages such as
  OpenCL.

In addition to the operations \tt{get}, \tt{put}, and \tt{alloc}, we
will require one more operation $\hfree h f t$ to discard stack frames
after their use. The semantics of the Function language then is
defined by the state transition relation $P, (\pc,\fp,\fs,\rt), s \red
P, (\pc',\fp',\fs',\rt'), s'$. We start with the assignment
instruction:

\begin{mathpar}
\inferrule{
  P[\pc] = (\#i \ass e) \\
  e,\fp,s \reds l \\
  \hput s {\fp+i} l = s' }{
  P, (\pc,\fp,\fs,\rt), s \red P, (\pc+1,\fp,\fs,\rt), s'
}
\end{mathpar}


Now follow the rules for the new instructions \tt{call} and
\tt{return}. To evaluate $\call {\pc'} {\fs'} {(e_1\ \ldots\ e_n)}$,
it first evaluates all of the arguments (i.e. Function is a
\emph{call-by-value} language). It then allocates a new stack frame for the
function being called, reserving 4 additional slots for storing the
registers \pc, \fp, \fs, and \rt. Finally, it stores the results of
evaluating the function arguments in the newly allocated stack frame
(``hiding'' the stored registers), and continues the execution at the
body of the called function.

\begin{mathpar}
\inferrule{
  P[\pc] = (\#\rt' \ass \call {\pc'} {\fs'} {(e_1\ \ldots\ e_n)}) \\
  e_i, \fp, s \reds l_i \ \ (i=1\ldots n) \\
  \halloc {s_0} {\fs'+4} = (s_1 , l) \\
  \hput {s_1} {l} {\pc} = s_2 \\
  \hput {s_2} {l+1} {\fp} = s_3 \\
  \hput {s_3} {l+2} {\fs} = s_4 \\
  \hput {s_4} {l+3} {\rt} = s_5 \\
  \fp' = l + 4 \\
  \hput {s_{4+i}} {\fp'+i-1} {l_i} = s_{5+i} \ \  (i=1\ldots n) }{
  P , (\pc,\fp,\fs,\rt), s_0 \red P,(\pc',\fp',\fs',\rt'), s_{5+n}
} 
\end{mathpar}

The execution of a \tt{return} statement essentially undoes the
effects of the function call. It first evaluates the return value, and
then restores the registers to their original values from before the
function call. It then stores the result of evaluating the return
value in the old stack frame, and cleans up the stack frame of the
function call by freeing all allocated memory.

\begin{mathpar}
\inferrule{
  P[\pc] = (\return e) \\
  e,\fp,s_0 \reds l \\
  \hget {s_0} {\fp-4} = \pc' \\
  \hget {s_0} {\fp-3} = \fp' \\
  \hget {s_0} {\fp-2} = \fs' \\
  \hget {s_0} {\fp-1} = \rt' \\
  \hput {s_0} {\fp'+\rt} l = s_1 \\
  \hfree {s_1} {\fp-4} {\fp + \fs - 1} = s_2 }{
  P , (\pc,\fp,\fs,\rt), s_0 \red P , (\pc'+1, \fp', \fs', \rt'), s_2
}
\end{mathpar}

**Exercise**: Compile the following program, and write down the
  execution trace of the compiled program:

    fun f(x) {
      y := x + 1;
      x := g(y);
      return x;
    }
    fun g(x) {
      return x*2;
    }
    z := f(4);

**Question.** What happens during the execution of the program when a function does not have a \tt{return} statement? Can this cause a security issue, and how could this be prevented?

Dynamic Taint Analysis
----------------------

> One group of users, using a certain set of commands, is *noninterfering* with
> another group of users if what the first group does with those commands has no
> effect on what the second group of users can see. [...] In this approach,
> security verification consists of showing that a given policy is satisfied by a
> given model. Taking this abstract view considerably simplifies many aspects of
> the problem.\footnote{From "Security Policies and Security Models" by J. A. Goguen and J. Meseguer (1982).}

Taint analysis is a form of **information flow control** (IFC), i.e. it tracks
the flow of sensitive data through a program and detects unprivileged access to
such data. Taint analysis can be used for many purposes. For example, we can
use taint analysis to prevent non-privileged functions to access sensitive
data. But we can also use taint analysis to prevent user-provided data to be
submitted to an SQL engine without prior sanitation. It all depends on how we
define "sensitive data" and how we want to restrict the access or use of such
data. To abstract from how "sensitive" is defined, in the context of taint
analysis it is customary to call the data to be tracked "tainted".

For example, many phone apps send the phone's unique device ID to
tracking companies. These companies can use the ID to create a profile
of the phone user, including the person's location and other
data. With taint analysis, we can mark the device ID as tainted and
control where it may flow.

The general goal of taint analysis is to enforce a property known
as *non-interference*:

--------------------
**Non-interference**: Changing the value of a *tainted* (a.k.a. 
*privileged* or *high*) input does not change the value of an
 *exposed* (a.k.a. *unprivileged* or *low*) output.
--------------------

\begin{figure} \centering
\includegraphics[width=.7\textwidth]{Non-interference.png}
\caption{If non-interference is satisfied, the value of privileged (or `high') inputs cannot influence the value of non-privileged outputs.}
\end{figure}

The precise terminology used often differs, but the goal is always the same:
certain inputs should not be allowed to influence certain outputs.
It is important to note that non-interference is a very strict property
and can be difficult to enforce 100%, in particular due to the presence
of indirect or covert channels. We will give an example of this later in this chapter.

**Question.** Taint tracking can also be applied to prevent buffer overflow
attacks, in a way that is somewhat different from the methods we
studied in the previous chapter. Can you explain how?

As preliminary for taint analysis for our Function language, we need to
identify three kind of special function calls:

- *Sources* of tainted information. 

- *Sinks* of non-privileged information sinks that may not get hold of tainted
  data. 

- Declassification renders sensitive information harmless and removes
  taint from it. For example, this could be some kind of 
  hash function that produces an anonymous fingerprint from private user data, or
  a function that sanitizes user input to prevent SQL injection.

The goal is to prevent the flow of tainted data from tainted sources to
non-privileged sinks, unless it has passed through a declassification function
first.

Based on this terminology, we can define the following example:

    main() {
      // phone is tainted
      phone := phoneID();
      // msg is tainted because it is derived from phone
      msg := concat("Hello there. ", phone);
      // the call is illegal because sendText may not access msg
      sendText(msg);
      // hash is not tainted because stringHash declassifies it
      hash := stringHash(msg);
      // the call is legal because hash is not tainted
      sendText(hash);
      return 0;
    }

We aim to define an analysis that prevents the first call of
`sendText` and allows the second one. Taint analysis is an
information-flow analysis that tracks the flow of tainted (dangerous,
sensitive) information throughout a program's execution. Here we
consider dynamic taint analysis, that is, we track the flow of tainted
information during a program's runtime. Specifically, we will define
the analysis in terms of runtime monitoring.

First of all, we need a place to store which data is currently
tainted. We really only need to store a single bit for each memory
location to define whether the data at that location is tainted or
not. The easiest approach is to maintain a set of all tainted memory
locations somewhere in the computer memory. Alternatively, sometimes
there is space available in the header of the data stored on in
memory. For example, we could add a flag to the array header (if we
wanted to treat all array elements uniformly). Languages with objects
also often have a little spare space available in the object header.

Here, we will maintain a set of all tainted memory locations. We
assume that this set is maintained by the run-time system on a separate part of the computer
memory that is normally inaccessible. The only way to access the
information is through the following basic operations:

- `isTainted(s, loc)`
- `markTainted(s, loc)`
- `unmarkTainted(s, loc)`

With these operations available, we can now define our dynamic taint
analysis through runtime monitoring.

First, we change the reduction relation for expressions to track taint
to $e, \fp, s \reds l , b$ where the boolean $b$ is `true` when any
tainted variables were used in the expression and `false`
otherwise. Here we show a few exemplary reduction rules only. The
parts that are changed are marked in \new{red}.

\begin{mathpar}
\inferrule{
  \hget{s} {\fp + i} = l \\
  \new{b = \istainted h {\fp+i}} }{
  i,\fp,h \reds l , \new{b}
}

\inferrule{
  e_1, \fp, s \reds l_1 , \new{b_1} \\
  e_2, \fp, s \reds l_2 , \new{b_2} \\
  \new{b = b_1 \lor b_2} }{
  e_1 \bop e_2 , \fp , s \reds l_1 \sbop l_2 , \new{b}
}
\end{mathpar}

**Exercise**: Give the rules for reducing literals and unary
  operations.

Using this reduction relation for expressions, we can adopt the state
transition relation. Note that the signature of this relation remains
unchanged. We use the auxiliary meta-function $\putsafe s i l b$ in
place of \tt{put} to update the taint set when writing to memory (this
function is part of our runtime system, not part of the program):

    putSafe(s, loc, lit, true)  = markTainted(put(s, loc, lit), loc)
    putSafe(s, loc, lit, false) = unmarkTainted(put(s, loc, lit), loc)

Now for the assignment operation:

\begin{mathpar}
\inferrule{
  P[\pc] = \#i \ass e \\
  e , \fp, s \reds l , \new{b} \\
  \new{\putsafe s {\fp+i} l {\new{b}} = s'} }{
  P, (\pc,\fp,\fs,\rt), s \red P, (\pc+1,\fp,\fs,\rt), s'
}
\end{mathpar}

If the value we assign to the variable is tainted, we mark the
corresponding memory location as tainted, otherwise the existing mark
(if any) is removed.

And finally the instructions for `call` and `return`. These are especially
interesting because they handle our special functions that are marked as
tainted sources, exposed sinks, or declassification ('untaint') functions. To
define these rules, we make use of three more auxiliary meta-functions
$\tt{isTaintedCall}(\pc)$, $\tt{isExposedCall}(\pc)$, and
$\tt{isUntaintCall}(\pc)$ that return `true` when the name of the function
called at position \pc{} has been marked as tainted, exposed, or untaint
respectively (and `false` otherwise).

Compared to the previous rules for executing `call` and `return`, we
make the following changes:

- Before executing a call to an exposed function, it is first checked
  that none of the arguments are tainted.
  
- All the values of the function call are placed on the stack frame
  using \tt{putSafe} with their taint flags.

- When the function call returns, the result is marked as tainted if
  either the function itself is tainted or if the return value is
  tainted and the function is not marked as `untaint`.

\begin{mathpar}

\inferrule{
  P[\pc] = \#\rt' \ass \call {\pc'} {\fs'} {(e_1\ \ldots\ e_n)} \\
  e_i, \fp, s \reds l_i , \new{b_i} \ \ (i=1\ldots n) \\
  \new{\lnot \tt{isExposedCall}(\pc')
       \lor \lnot (b_1 \lor \ldots \lor b_n)} \\
  \halloc {s_0} {\fs'+4} = (s_1 , l) \\
  \putsafe {s_1} {l} {\pc} {\new{\false}} = s_2 \\
  \putsafe {s_2} {l+1} {\fp} {\new{\false}} = s_3 \\
  \putsafe {s_3} {l+2} {\fs} {\new{\false}} = s_4 \\
  \putsafe {s_4} {l+3} {\rt} {\new{\false}} = s_5 \\
  \fp' = l + 4 \\
  \putsafe {s_{4+i}} {\fp'+i-1} {l_i} {\new{b_i}} = s_{5+i} \ \  (i=1\ldots n) }{
  P , (\pc,\fp,\fs,\rt), s_0 \red P,(\pc',\fp',\fs',\rt'), s_{5+n}
}

\inferrule{
  P[\pc] = \return e \\
  e,\fp,s_0 \reds l , \new{b_1} \\
  \hget {s_0} {\fp-4} = \pc' \\
  \hget {s_0} {\fp-3} = \fp' \\
  \hget {s_0} {\fp-2} = \fs' \\
  \hget {s_0} {\fp-1} = \rt' \\
  \new{b = \texttt{isTaintedCall}(\pc') \lor
           (b_1 \land \lnot \tt{isUntaintCall}(\pc'))} \\
  \putsafe {s_0} {\fp'+\rt} l {\new{b}} = s_1 \\
  \hfree {s_1} {\fp-4} {\fp + \fs} = s_2 }{
  P , (\pc,\fp,\fs,\rt), s_0 \red P , (\pc'+1, \fp', \fs', \rt'), s_2
}

\end{mathpar}

As in previous lecture, the rules do not specify what happens when an illegal
operation occurs, i.e. when an exposed function is called with a tainted
argument. So the behaviour of the program is *undefined* in such situation. A
concrete implementation is free to make a choice that does not expose the
tainted information, such as skipping the tainted function call or ending the
program execution with an error message.

**Exercise**: Convince yourself that our dynamic taint analysis
  prevents the first call of `sendText` and allows the second
  one:

    main() {
      // phone is tainted
      phone := phoneID();
      // msg is tainted because it is derived from phone
      msg := concat("Hello there. ", phone);
      // the call is illegal because sendText may not access msg
      sendText(msg);
      // hash is not tainted because stringHash declassifies it
      hash := stringHash(msg);
      // the call is legal because hash is not tainted
      sendText(hash);
      return 0;
    }

As shown by the example, our dynamic taint analysis is effective at
preventing classified information from being exposed in a direct
manner. However, there is still the possibility of *indirect
information flows* where a tainted value is exposed through indirect
means. This can happen for example when a program makes a decision
based on a tainted value (e.g. as the condition of an `if` or a
`while`).

**Exercise**: Write an example program in Function extended with `if` and
`while` (from the first assignment) that exposes tainted information in
a way that is not detected by the above analysis.

**Answer**: Here is a function that converts a tainted boolean value to
an identical value that is not marked as tainted:

    fun launderBool(myBool) {
      if (myBool) {
        return true;
      } else {
        return false;
      };
    }



In the next section we see a different example of indirect information flows
using arrays.

Taint analysis for mutable arrays
---------------------------------

When we combine two language features, there can always be new
security issues that are created by the interaction between different
features. As an example, we will combine the Function language with
the Array language in a naive way and discuss two problems that arise
from this combination.

Rather than keeping a separate stack and heap, we will simply store
stack frames on the heap directly. So arrays and stack frames are
mixed together into a single heap structure.

Since arrays are stored on the heap rather than the stack, the offset
\fp{} does not apply to operations on arrays. This also means that
arrays created in one function call can be accessed from another (as
long as the pointer to the array is passed somehow).

Here are the evaluation rules for the array operations extended with additional
checks for taint tracking:

\begin{mathpar}
\inferrule{
  \hget h {\fp+i} = s \\
  \hget h s = l \\
  \new{b = \istainted h {\fp+i} \lor \istainted h s} }{
  \arlen i,\fp,h \reds l,\new{b}
}

\inferrule{
  P[\pc] = \#a \ass \arnew e \\
  e, \fp , h \reds l , \new{b} \\
  \halloc {h_0} {l+1} = (h_1,s) \\
  \putsafe {h_1} s l {\new{b}} = h_2 \\
  \putsafe {h_2} {\fp+a} s {\new{\false}} = h_3 }{
  P, (\pc,\fp,\fs,\rt), h_0 \red P, (\pc+1,\fp,\fs,\rt), h_3
}

\inferrule{
  P[\pc] = \#x \ass \arread a e \\
  e,\fp,h \reds l, \new{b_1} \\
  \hget h {\fp+a} = s \\
  \hget h {s + 1 + l} = l_2 \\
  \new{\istainted h {s+1+l} = b_2} \\
  \putsafe h {\fp + x} {l_2} {\new{b_1 \lor b_2}} = h' }{
  P , (\pc,\fp,\fs,\rt), h \red P, (\pc+1,\fp,\fs,\rt),h'
}

\inferrule{
  P[\pc] = \arwrite a {e_1} {e_2} \\
  e_1,\fp,h \reds l_1 , \new{b_1} \\
  e_2,\fp,h \reds l_2 , \new{b_2} \\
  \hget h {\fp+a} = s \\
  \putsafe h {s + 1 + l_1} {l_2} {\new{b_1 \lor b_2}} = h' }{
  P , (\pc,\fp,\fs,\rt), h \red P, (\pc+1,\fp,\fs,\rt),h'
}
\end{mathpar}

Note that each element stored in an array has its own flag for being tainted or
untainted. The result of reading from an array is tainted if either the
position or the stored value is tainted, and likewise values that are written
in an array are marked as tainted if either the position or the stored value
are tainted.

With this taint analysis, there are at least two indirect ways in
which classified information can leak to exposed functions, i.e.
ways in which the analysis is not sound:

- When creating a new array where the length of the array is tainted,
  it becomes possible for an attacker to determine the length of the
  array indirectly by allocating another array of length 1 immediately 
  after allocating the first. By comparing the values of
  the pointers to the two arrays (which are not marked as tainted), 
  it is possible to determine the
  length of the array. For example, the following program converts a tainted value `n`
  to an untainted copy `m`:
  
    n := ...;  // tainted value
    a := arnew n;
    b := arnew 1;
    m := b - a;
  
  This method can be abused to
  determine the value of *any* tainted number by simply creating a new
  array with the tainted number as its length.

- If calls to exposed functions with a tainted argument are skipped
  silently, then it becomes possible for an attacker to determine
  whether a given value is tainted
  or not. To do so, the attacker can define the following functions:

      isTainted(x) {
        result := true;
        result := testTaint(x);
        return result;

      exposedTestTaint(x) {
        return false;
      }

  When called with a normal (non-tainted) argument, the function
  `isTainted` will always return `false`. However, when called with a
  tainted argument, the call to `exposedTestTaint` will be skipped and
  the result will be `true`. By making use of the function `isTainted`
  above, an attacker can again determine the value of any tainted
  number by first creating a (sufficiently large) array, writing to
  the array using the tainted value as the position, and testing each
  position in the array until a tainted value is encountered.

These are two examples that show that the analysis is *unsound*, i.e.
it does not detect all violations of non-interference. 

**Exercise**: Can you think of a way to extend our dynamic taint
  analysis to also deal with the backdoors described above? Is is
  possible to ensure that there are *no* backdoors in the analysis?

**Exercise**: Next to soundness, the other important property of a program
analysis for security is *completeness*: it should not raise any false alarms.
Is the taint analysis we described complete? If not, is there a way to make it
complete?

## Summary

- The Function language extends the Assign language with global
  function definitions and function calls.

- We can compile Function programs to Compiled Function code, where
  functions are identified by their position in the program rather
  than their name. Each function call in the Compiled Function
  language has a *stack frame* that stores the values of the
  function's arguments and local variables.

- *Non-interference* is the property of a program that the values of tainted or
  'low' inputs do not influence the values of exposed or 'high' outputs.

- Dynamic taint analysis can be used to enforce non-interference by detecting
  unprivileged access to
  sensitive or 'tainted' data. For this purpose, it identifies three
  classes of functions: 'tainted' functions that produce tainted data,
  'exposed' functions that may not have tainted data as input, and
  'untaint' functions that remove taint from data.

- Combining two language features can introduce new security
  vulnerabilities. For example, adding arrays to the Function language
  renders our dynamic taint analysis unsound.

## Further reading

- Haldar, Chandra, and Franz (2005): *Dynamic Taint Propagation for
  Java* (\url{https://www.acsac.org/2005/papers/45.pdf})