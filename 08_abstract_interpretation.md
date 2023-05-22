

Abstract interpretation
=======================

In the previous three chapters, we studied different static type systems and
how they can prevent security issues before a program is even
started. However, static type systems are fundamentally limited by the
fact that each variable can only be assigned a single type. This makes
them well suited for enforcing certain properties of programs
(e.g. that a certain value should be an integer) but not others
(e.g. whether a counter is even or odd).

In this lecture, we will study *abstract interpretation*, a different
form of static analysis that assigns an *approximation* of each value
in the program and executes the program using these approximations.
Abstract interpretation describes alternative language semantics
(abstract semantics) and how they relate to the original concrete
language semantics. Abstract interpreters analyze the same expressions
as the concrete semantics. However, they return abstract values that
represent properties of concrete values such as their parity, their
sign or range.

**Learning objectives.** In this chapter you will learn:

- how to use abstract interpretation to do a static analysis of the
  parity of expressions and heap values,
- how to describe connections between abstract and concrete values in
  general using *Galois connections*,
- how to define abstract interpretation of `if`-statements and
  `while`-loops.


Parity Analysis for the Calc language
----------------------------------------------

To start, we will study the technique of abstract interpretation
through one example analyzing the \emph{parity} of numbers
(i.e. whether they are even or odd).  By calculating the abstract
interpretation of an expression, we can determine whether the result
of evaluating it will be always even, always odd, or be of unknown
parity. This is just one example to demonstrate the general idea of
abstract interpretation; other kinds can be used to study properties
that are important for security such as array bounds or
confidentiality as we will see later.

**Exercise.** What can you tell about the parity of the following expressions,
assuming you know the parity of `x` and `y`?

- `x + 2*y`
- `x*y + 1`
- `2 * (100/y)`

**Question.** Can you think of an example program where knowing the
  sign of a particular variable can help with detecting a security
  problem?

The abstract domain that represents the parity of numbers is modeled
by the following type:

    Parity := 'even' | 'odd'

These abstract values relate to *sets* of concrete values. The `even`
symbol represents all even numbers, and `odd` represents all odd
numbers. 

In the following, we sketch a parity analysis for the Calc
language. The abstract interpreter is defined over the same expression
language as the concrete interpreter:

    Expr    ::= Literal | Expr BinOp Expr | UnOp Expr
    BinOp   ::= '+' | '-' | '/' | '*' | '&&' | '||' | '=='
    UnOp    ::= '-' | '!'
    Literal ::= Number | 'true' | 'false'

The difference however is that the abstract interpreter will not
return a number but a *parity*. Formally, we describe the semantics of
the abstract interpreter as a *big-step*\footnote{In contrast to when
we looked at dynamic analysis techniques, for abstract interpretation
there is no need to see the intermediate states of the program
execution.} operational semantics $e \reds p$ where $p$ is an
*abstract value*:

    AbsValue ::= 'even' | 'odd' | 'true' | 'false' | ⊤ | ⊥

Apart from the abstract values `even` and `odd` and the booleans
`true` and `false` (which we do not abstract), we have the special
symbol ⊤ (pronounced 'top') that represents values we do not know
anything about (i.e. it could be any number or boolean). There is also
the symbol ⊥ (pronounced 'bottom') that represents an 'undefined
value' or an 'error state', which we will ignore for now (it will
become important later).

We start by definining the abstract interpretation of literals. As you
might expect, the abstract interpretation of a literal number $l$ is
`even` if the number is even, and `odd` if the number is odd. The
booleans `true` and `false` are interpreted as themselves.

\begin{mathpar}
\inferrule{l \text{ mod } 2 = 0}{l \reds \even}

\inferrule{l \text{ mod } 2 = 1}{l \reds \odd}

\inferrule{\ }{\true \reds \true}

\inferrule{\ }{\false \reds \false}
\end{mathpar}

We now define the basic arithmetic operations over parities. For each
operation $\tt{op}$, we will define a corresponding operation
$\abs{\tt{op}}$ on abstract values. For some operations, we know the
parity of the result when we know the parity of the arguments. For
example, if we calculate the sum of an odd and an even number, the
result is always an odd number. This way we derive the addition on
abstract values:

\begin{equation*}
\begin{array}{lclcl}
  \even & \abs{+} & \even &=& \even \\
  \even & \abs{+} & \odd &=& \odd \\
  \odd & \abs{+} & \even &=& \odd \\
  \odd & \abs{+} & \odd &=& \even \\
  \top & \abs{+} & p_2 &=& \top \\
  p_1 & \abs{+} & \top &=& \top \\
\end{array}
\end{equation*}

**Exercise.** Define subtraction and multiplication on abstract values.

**Exercise.** Define negation on abstract values.

However, there are cases where the information about the parity of a
number is not enough to precisely describe the behavior of the
concrete semantics. For example, for the equality operation `==`, just
because two numbers have the same parity does not mean that the
numbers are equal. Hence we make use of the constant $\top$ that
represents that we do not know anything about the parity of the
value. Using this symbol, we can define the abstract semantics of
`==`:

\begin{equation*}
\begin{array}{lclcl}
  \even & \abs{\tt{==}} & \even &=& \top \\
  \even & \abs{\tt{==}} & \odd &=& \false \\
  \odd & \abs{\tt{==}}  & \even &=& \false \\
  \odd & \abs{\tt{==}}  & \odd &=& \top \\
  \top & \abs{\tt{==}}  & p &=& \top \\
  p & \abs{\tt{==}}     & \top &=& \top \\
\end{array}
\end{equation*}

**Exercise.** Define the abstract semantics of division.

With these abstract operations $\abs{\tt{op}}$, we can now define the
abstract interpretation of binary and unary operations as follows:

\begin{mathpar}
\inferrule{e_1 \reds p_1 \\ e_2 \reds p_2}{e_1 \bop e_2 \reds p_1 \abs{\bop} p_2}

\inferrule{e \reds p}{\uop e \reds \abs{\uop} p}
\end{mathpar}



Abstract interpretation of statements
-------------------------------------

We now extend the scope of our abstract interpreter to the Assign
language with `if` and `while`-statements.


    Prog       ::= Stmt ';' Prog | Expr ';'
    Stmt       ::= Identifier ':=' Expr
                 | 'if' Expr '{' Stmts '}' 'else' '{' Stmts '}'
                 | 'while' Expr '{' Stmts '}'
    Stmts      ::= '' | Stmt ';' Stmts
    Expr       ::= Identifier | Literal | Expr BinOp Expr | UnOp Expr
    BinOp      ::= '+' | '-' | '/' | '*' | '&&' | '||' | '=='
    UnOp       ::= '-' | '!'
    Literal    ::= Number | 'true' | 'false'
    Identifier ::= String

To define the abstract semantics of this language, we will work with
an *abstract heap* that stores abstract values:

    AbsHeap ::= '' | Identifier '=' AbsValue ';' AbsHeap

With this abstract heap, the abstract semantics of the assign
statement is essentially unchanged from the concrete version:

\begin{mathpar}
\inferrule{e,h \reds l \\ h' = \hput{h}{x}{l}}{(x \ass e), h \red h'}
\end{mathpar}

### Parity analysis of `if`

Let's now consider the abstract semantics of the control statement
`if`. Let us first investigate how the parity analysis would work for
the example program:

    if (x == y) {
      z := x+y;
    } else {
      z := x*y;
    };



Here are the analysis results based on whether the inputs `x` and `y`
are initially even or odd.

`x`    `y`     `x == y`  `x + y` `x * y` `z`
------ ------  --------  ------- ------- ------
`even` `even`  ⊤         `even`  `even`  `even`
`even` `odd`   `false`   `odd`   `even`  `even`
`odd`  `even`  `false`   `odd`   `even`  `even`
`odd`  `odd`   ⊤         `even`  `odd`   ⊤

In the case both `x` and `y` are odd, the analysis is unsure if `x`
and `y` are equal. In this case we have to analyze both branches of
the `if` and combine their results. For the first branch, the analysis
of concludes that `z` is an even number and for the second branch it
concludes that `z` is an odd number, so after the `if` statement `z`
could be either even or odd. In this case we set the status of `z` to
`⊤`, expressing that we do not know the status of `z` after the `if`
statement.

In general, to combine two results coming from different branches we
make use of the operation `⊔` called the *join* or the *least upper
bound*. It is defined on parities as follows:

\begin{equation*}
\begin{array}{lclcl}
    \even &⊔& \even &=& \even \\
    \even &⊔& \odd  &=& ⊤ \\
    \odd  &⊔& \even &=& ⊤ \\
    \odd  &⊔& \odd  &=& \odd \\
    ⊤     &⊔& p     &=& ⊤ \\
    p     &⊔& ⊤     &=& ⊤ \\
\end{array}
\end{equation*}

We define the least upper bound of two heaps $h_1$ and $h_2$ as
follows:

\begin{equation*}
\begin{array}{lcl@{\hspace{2cm}}l}
\hget {h_1 \sqcup h_2} x &=& p_1 \sqcup p_2 & \text{if } \hget {h_1} x = p_1 \text{ and } \hget {h_2} x = p_2 \\
\hget {h_1 \sqcup h_2} x &=& ⊥ & \text{otherwise}
\end{array}
\end{equation*}

With these observations, we derive the abstract semantics of `if`
statements in general:

\begin{mathpar}
\inferrule{e,h \reds \true \\ \it{ss}_1,h \reds h'}{(\tt{if}(e)\ \{\it{ss}_1\}\ \tt{else}\ \{\it{ss}_2\}) , h \reds h'}

\inferrule{e,h \reds \false \\ \it{ss}_2,h \reds h'}{(\tt{if}(e)\ \{\it{ss}_1\}\ \tt{else}\ \{\it{ss}_2\}) , h \reds h'}

\inferrule{
  e,h \reds \top \\
  \it{ss}_1,h \reds h_1 \\
  \it{ss}_2,h \reds h_2 \\
  h' = h_1 \sqcup h_2
}{
  (\tt{if}(e)\ \{\it{ss}_1\}\ \tt{else}\ \{\it{ss}_2\}) , h \reds h'
}
\end{mathpar}


### Parity analysis of `while`

Let us now turn our attention to the abstract semantics of `while`
loops. Consider the analysis of the following code fragment:

    while (some_condition) {
      x := x+2;
    };

In case the parity of `x` is even before the execution of the loop,
the analysis of the loop body indicates that the parity of `x` does
not change:

iteration    `x`     `x+2`
---------    ----    ----
1            \even   \even
2            \even   \even
3            \even   \even
...          ...     ...
$n$          \even   \even

In case the parity of `x` initially is odd, the analysis likewise
determines `x` will always be odd. Although the parity of `x` gives us
no indication of how often the loop is executed, the body of the loop
preserves the parity of `x`. Hence, the analysis result for `x` after
the loop should be the same parity as before.

Let us investigate the analysis of another `while` loop:

    while (some_condition) {
      x := x+1;
    }

The parity of `x` alternates during each iteration:

iteration    `x`     `x+2`
---------    ----    ----
1            \even   \odd
2            \odd    \even
3            \even   \odd
...          ...     ...
$n$          ⊤       ⊤

Since the parity of `x` does not give us enough information if the
loop is executed 0, 1, 2, ... times, we do not know what the final
parity of `x` is and we have to over-approximate the parity of `x` by
⊤.

With these examples, we can now give the abstract semantics of a while
loop in general by analyzing the body of the loop repeatedly:

- If the analysis result does not change anymore, i.e. the analysis
  has reached a *fixed point*, we know that we have discovered the
  invariant that the loop body preserves.
\begin{mathpar}
\inferrule{
  \it{ss} , h \reds h' \\
  h = h' \\
}{
  (\tt{while}\ e\ \it{ss}), h \reds h
}
\end{mathpar}

- Otherwise, we unroll the loop once but we combine the result with
  the previous abstract heap to anticipate that the loop could be
  exited after each iteration.
\begin{mathpar}
\inferrule{
  e,h \reds \top \\
  (\it{ss}; \tt{while}\ e\ \it{ss}) , h \reds h' \\
  h'' = h \sqcup h' \\
}{
  (\tt{while}\ e\ \it{ss}) , h \reds h''
}
\end{mathpar}


**Exercise.** Write down a table for the abstract interpretation of
  the two example loops given above assuming the abstract
  interpretation of `some_condition` always returns ⊤. Would there be
  a difference if the abstract interpretetation of `some_condition`
  would instead be `true` or `false`?

**Question**: Does this analysis of loops using the `Parity` domain always
terminate? Or could we get stuck in an infinite loop?

**Answer**: The analysis will always terminate: there are only a finite number
of variables in the heap $h$, and the abstract value of each variable can only
change from `true` or `false` to `⊤`. So after applying the second rule a
number of times equal to the number of variables in the heap, we have reached a
fixed point and the first rule applies.

Note that these two rules for analyzing `while` loops we gave do not make use
of any information from the loop condition `e`. So even if we know that
`some_condition` is always `true` in the second example with loop body 
`x := x+1;`, we cannot conclude anything about the parity of `x`. To improve
the precision of the analysis in such cases, we can extend it with two 
additional rules:

- When we can determine statically that the condition of the
  `while`-loop is `false`, we can stop the iteration and take the
  current abstract heap as the final result.
\begin{mathpar}
\inferrule{
  e,h \reds \false
}{
  (\tt{while}\ e\ \it{ss}) , h \reds h
}
\end{mathpar}

- Meanwhile, if the condition is statically determined to be `true` we
  can unroll the loop once.
\begin{mathpar}
\inferrule{
  e,h \reds \true \\
  (\it{ss}; \tt{while}\ e\ \it{ss}) , h \reds h'
}{
  (\tt{while}\ e\ \it{ss}) , h \reds h'
}
\end{mathpar}

However, there is a price we have to pay for this improved precision: by using
the second rule, we lose the guarantee that our analysis always terminates. For
example, a `while` loop with condition `true` will be unfolded infinitely
often. To avoid this, we have to give up after a certain number of iterations
and set the analysis result of the changing values to ⊤:
\begin{mathpar}
\inferrule{
  \forall x.\ \hget {h'} x = \top
}{
  (\tt{while}\ e\ \it{ss}) , h \reds h'
}
\end{mathpar}

When using abstract interpretation with a different domain with an infinite
number of abstract values (such as the abstract domain of intervals used in
this chapter's assignment), the analysis might not terminate even if we only use
the first two rules. In those cases it is also necessary to use the rule above
to cut off the analysis after a given number of steps.


The lattice structure of abstract domains
-----------------------------------------

We now continue to study the framework of abstract interpretation in
more generality. At the core of every abstract interpretation lies an
*abstract domain* $P$ consisting of abstract values such as `even`,
`odd`, and ⊤. These abstract values are ordered to describe which
abstract property implies which other abstract property. We write $p_1
⊑ p_2$ if abstract property $p_1$ implies abstract property $p_2$. For
example, for parities we have $\even ⊑ \top$ and $\odd ⊑ \top$ as well
as $p ⊑ p$ for every property $p$. However, we have $\even
\not\sqsubseteq \odd$ nor $\odd \not\sqsubseteq \even$, so the order
is a *partial order*.

**Definition.** A relation $⊑$ on a set $D$ is a *partial order*
 if it satisfies the following properties:

  - It is *reflexive*: for all $x \in D$, we have $x ⊑ x$
  - It is *transitive*: for all $x,y,z \in D$, if $x ⊑ y$ and $y ⊑ z$ then $x ⊑ z$
  - It is *anti-symmetric*: for all $x,y \in D$, if $x ⊑ y$ and $y ⊑ x$ then $x = y$

We can visualize partial orders with a *Hasse
diagram*\footnote{\url{https://en.wikipedia.org/wiki/Hasse_diagram}} in which
elements that are greater appear higher up in the diagram:

\begin{center}
\begin{tikzpicture}[auto,node distance=1.5cm]
  \node (top) {$\top$};
  \node[below left=1cm of top] (even) {$\even$};
  \node[below right=1cm of top] (odd) {$\odd$};
  \node[below right=1cm of even] (bot) {$\bot$};
  \draw[-] (top) to (even);
  \draw[-] (top) to (odd);
  \draw[-] (even) to (bot);
  \draw[-] (odd) to (bot);
\end{tikzpicture}
\end{center}

**Question.** What other abstract domains can you think of? Draw a
  Hasse diagram for each of them. How can they be used to detect
  potential problems in a program?

**Answer.** Other examples of abstract domains are the following:

- The abstract domain $\{ \tt{null} , \tt{non-null} , \top , \bot
  \}$ can be used to keep track of whether a value has been initialized or
  not yet initialized. This can be used to avoid \tt{null} pointer
  dereferences.

\begin{center}
\begin{tikzpicture}[auto,node distance=1.5cm]
  \node (top) {$\top$};
  \node[below left=1cm of top] (defined) {$\tt{null}$};
  \node[below right=1cm of top] (undefined) {$\tt{non-null}$};
  \node[below right=1cm of defined] (bot) {$\bot$};
  \draw[-] (top) to (defined);
  \draw[-] (top) to (undefined);
  \draw[-] (defined) to (bot);
  \draw[-] (undefined) to (bot);
\end{tikzpicture}
\end{center}

- The abstract domain $\{ \tt{pos}, \tt{neg}, \tt{zero}, \tt{strictly-pos}, \tt{strictly-neg} , \tt{non-zero}, \top , \bot \}$ can be used to keep track of the sign of an integer
  and whether or not it is $0$. This can be used for example to
  prevent division by $0$, or to prevent strictly negative array indices.

\begin{center}
\begin{tikzpicture}[auto,node distance=1.5cm]
  \node (top) {$\top$};
  \node[below=1cm of top] (nonzero) {\tt{non-zero}};
  \node[left=1cm of nonzero] (pos) {$\tt{pos}$};
  \node[right=1cm of nonzero] (neg) {$\tt{neg}$};
  \node[below=1cm of nonzero] (zero) {$\tt{zero}$};
  \node[left=1cm of zero] (strpos) {$\tt{strictly-pos}$};
  \node[right=1cm of zero] (strneg) {$\tt{strictly-neg}$};
  \node[below=1cm of zero] (bot) {$\bot$};
  \draw[-] (top) to (pos);
  \draw[-] (top) to (nonzero);
  \draw[-] (top) to (neg);
  \draw[-] (pos) to (strpos);
  \draw[-] (pos) to (zero);
  \draw[-] (nonzero) to (strpos);
  \draw[-] (nonzero) to (strneg);
  \draw[-] (neg) to (strneg);
  \draw[-] (neg) to (zero);
  \draw[-] (strpos) to (bot);
  \draw[-] (strneg) to (bot);
  \draw[-] (zero) to (bot);
\end{tikzpicture}
\end{center}

- The abstract domain $\{ 0 , 1 , -1 , 2 , -2 , \ldots \} \cup \{ \top
  , \bot \}$ can be used to keep track of variables in the program of
  which the value is known statically.

\begin{center}
\begin{tikzpicture}[auto,node distance=1.5cm]
  \node (top) {$\top$};
  \node[below=.7cm of top] (zero) {$0$};
  \node[left=1cm of zero] (m1) {$-1$};
  \node[left=2cm of zero] (m2) {$-2$};
  \node[left=3cm of zero] (m3) {$\ldots$};
  \node[right=1cm of zero] (p1) {$1$};
  \node[right=2cm of zero] (p2) {$2$};
  \node[right=3cm of zero] (p3) {$\ldots$};
  \node[below=.7cm of zero] (bot) {$\bot$};
  \draw[-] (top) to (m1);
  \draw[-] (top) to (m2);
  \draw[-] (top) to (m3);
  \draw[-] (top) to (zero);
  \draw[-] (top) to (p1);
  \draw[-] (top) to (p2);
  \draw[-] (top) to (p3);
  \draw[-] (m1) to (bot);
  \draw[-] (m2) to (bot);
  \draw[-] (m3) to (bot);
  \draw[-] (zero) to (bot);
  \draw[-] (p1) to (bot);
  \draw[-] (p2) to (bot);
  \draw[-] (p3) to (bot);
\end{tikzpicture}
\end{center}

- The abstract domain of intervals $\{ [a,b] \ |\ a \leq b \} \cup \{
  \bot \}$ (where $a$ and $b$ are either integers or $-/+ \infty$) can
  be used to keep track of lower and upper bounds on variables in a
  program. This can be used to detect illegal array accesses (see this
  chapter's assignment on Weblab for more information).

\begin{center}
\includegraphics[width=.8\textwidth]{Interval-lattice.png} \\
(source: page 215 of \emph{Principles of Program Analysis})
\end{center}

Given two elements $p$ and $q$ of an abstract domain, the *join* or
the *least upper bound* $p ⊔ q$ is the smallest element $r$ such that
both $p ⊑ r$ and $q ⊑ r$. Meanwhile, the *top* or the *maximal
element* ⊤ of an abstract domain is the element such that $p ⊑ ⊤$ for
any $p$. Together, these make the abstract domain into a mathematical
structure called a *semi-lattice*.

**Definition.** A (bounded) *semi-lattice* is a 4-tuple $(D,⊑,⊤,⊔)$
  such that the following properties are satisfied:

* $⊑$ is a partial order on $D$
* $⊤$ is a *maximal element*, i.e. for all $x \in D$ we have $x ⊑ ⊤$.
* $⊔$ is a *least upper bound*, i.e. for all $x,y \in D$, $x ⊔ y$ is 
  the smallest element of $D$ such that $x ⊑ x ⊔ y$ and $y ⊑ x ⊔ y$.

Likewise, a *bottom* or a *minimal element* ⊥ is an element such that
$⊥ ⊑ p$ for all $p$, and a *meet* or a *greatest lower bound* $p ⊓ q$
is the biggest element $r$ such that $r ⊑ p$ and $r ⊑ q$.

**Definition.** A (bounded) *lattice* is a 6-tuple $(D,⊑,⊤,⊥,⊔,⊓)$
  such that $(D,⊑,⊤,⊔)$ is a semi-lattice, and moreover the following 
  properties are satisfied:

* $⊥$ is a *minimal element*, i.e. for all $x \in D$ we have $⊥ ⊑ x$
* $⊓$ is a *greatest lower bound*, i.e. for all $x,y \in D$, $x ⊔ y$ is 
  the smallest element of $D$ such that $x ⊓ y ⊑ x$ and $x ⊓ y ⊑ y$.

Lattice structures are the basis of the theoretical study of abstract
interpretation, and are also used in several other areas of
mathematics\footnote{\url{https://en.wikipedia.org/wiki/Lattice_(order)}}.

**Exercise.** Verify that all the examples of abstract domains we saw
  above are indeed lattices.

Galois connections
------------------

In the previous section, we have defined several domains of abstract
interpretation as lattices, but how are these abstract domains
connected to the concrete values used by the actual program? The
mathematical tool to describe such a connection is called a *Galois
connection*, which we will discuss here.

> **Side note.** Évariste Galois (1811-1832) was one of the most famous
> mathematicians of all time. He gave the first complete criterion for solving
> polynomial equations, solving a 350-year old problem. He also worked in
> abstract algebra, founding the subjects of Galois theory and Galois
> connections. He died at age 20 from wounds suffered in a duel.\footnote{\url{https://en.wikipedia.org/wiki/Evariste_Galois}}

Associated to each abstract domain $D$, we have a function γ that
return the set of all values represented by a symbol. For example, for
`Parity` we have:

\begin{equation*}
\begin{array}{lcl}
γ(\even) &=& \{0, 2, 4, \ldots\} \\
γ(\odd)  &=& \{1, 3, 5, \ldots\} \\
γ(⊤)     &=& \{0, 1, 2, 3, 4, \ldots\} \\
γ(⊥)     &=& \{\} \\
\end{array}
\end{equation*}

Likewise, we can also define a function α that takes a set of values
and returns the symbol that gives the best approximation of this
set. For example,

\begin{equation*}
\begin{array}{lcl}
    α(\{1,5\})   &=& \odd \\
    α(\{2,10\})  &=& \even \\
    α(\{1,2,3\}) &=& ⊤ \\
    α(\{\})      &=& ⊥ \\
\end{array}
\end{equation*}

Together, the functions γ and α form what we call a *Galois
Connection*. The function α that maps a property of concrete values to
abstract values is called the *abstraction function* and the function
γ that maps abstract values to sets of concrete values is called the
*concretization function*.

For α and γ to form a proper Galois connection, they have to satisfy four
properties:

1. First, if we give a bigger set of elements to the abstraction function α,
   we should also get a bigger element of the abstract domain (according to
   the order ⊑ on the lattice). For example, since $\{1\} ⊆ \{1,2\}$, we should 
   also have $α(\{1\}) ⊑ α(\{1,2\})$ (which is true since 
   $α(\{1\}) = \odd ⊑ \top = α(\{1,2\})$). We say that 
   **the abstraction function α should be monotone**.

2. Second, if we give a bigger element of the abstract domain to the
   concretization function γ, we should also get a bigger set of concrete values.
   For example, since $⊥ ⊑ \even$, we should also have $γ(⊥) ⊆ γ(\even)$
   (which is true because $γ(⊥) = \{ \}$ is a subset of any set). We say that
   **the concretization function γ should be monotone**.

3. Third, the abstraction function α should return an abstract value that
   correctly describes all the values in the given set. For example, it would be
   wrong to say that $α(\{1,2\}) = \even$, since $γ(\even) = \{0, 2, 4, \ldots\}$
   which does not contain the number $1$. In general, we can express this property
   by saying that 
   **for any set of concrete values $X$, we have that $X ⊆ γ(α(X))$**.

4. Finally, the abstraction function α should return the *best* possible
   approximation that still satisfies the first point. For example, it would be 
   wrong to say that $α(\{1,5\}) = ⊤$, since there is a better approximation 
   \odd{} with the property that both $1$ and $5$ are in $γ(\odd) = \{1,3,5,\ldots\}$.
   In general, we can express this property by saying that 
   **for any abstract value $y$, we have that $α(γ(y)) ⊑ y$**.

There is a nice way to reformulate the last two properties: for any set of
concrete values $X$ and any abstract value $y$, we have that 
**$α(X) ⊑ y$ if and only if $X ⊆ γ(y)$**. To see why this follows from the
four properties above, we can reason as follows:

- From left to right, we assume $α(X) ⊑ y$, and we want to prove that $X ⊆ γ(y)$.
  From the third property, we get that $X ⊆ α(γ(X))$. Additionally, since $γ$ is
  monotone, $α(X) ⊑ y$ implies that $γ(α(X)) ⊆ γ(y)$. By transitivity of $⊆$, we
  can conclude that $X ⊆ γ(y)$.

- In the other direction, assume $X ⊆ γ(y)$, and we want to prove $α(X) ⊑ y$.
  From the fourth property, we get that $α(γ(y)) ⊑ y$. Additionally, since $α$ is
  monotone, $X ⊆ γ(y)$ implies that $α(X) ⊑ α(γ(y))$. By transitivity of $⊑$, we
  can conclude that $α(X) ⊑ y$.

This leads us to the following definition of a Galois connection:

**Definition.** Let α and γ be a pair of *monotone* functions back and forth
between sets of concrete values and elements of a lattice of abstract values.
We say that the pair (α,γ) forms a *Galois connection* if **$α(X) ⊑ y
\Leftrightarrow X ⊆ γ(y)$** for any set of concrete values $X$ and any abstract
value $y$.

**Exercise**: Show that this definition implies the four properties we
identified before.


We can see Galois connections as a kind of recipe for constructing new
static program analyses. This recipe follows the following steps:

1. Choose an abstract domain that represents the properties you want to analyze
   (parity, definedness, lower and upper bounds, ...)

2. Define the concretisation function γ that defines for each element $y$ of
   the abstract domain the set of elements $γ(y)$.

3. Define the lattice ordering ⊑ on the abstract domain such that
   γ is monotone, i.e. if $y_1 ⊑ y_2$ then $γ(y_1) ⊆ γ(y_2)$.

4. Define the abstraction function α by letting $α(X)$ be the smallest
   abstract value such that all elements of $X$ are in $γ(α(X))$.

To run the program analysis, we simply execute the program on values of the
abstract domain until a fixed point is reached. If the domain contains infinite
chains $y_1 ⊑ y_2 ⊑ y_3 ⊑ ...$, it is also necessary to stop the analysis after
a fixed number of steps and replace the result by ⊤.

**Exercise**: Define the functions γ and α for the abstract domain $\{
\tt{pos},$ $\tt{neg},$ $\tt{zero},$ $\tt{strictly-pos},$ $\tt{strictly-neg},$ $\top ,
\bot \}$, and verify that they satisfy the definition of a Galois connection.
Then, apply the static analysis derived from this Galois connection to verify
that the following program will never do a division by zero:

```
x := 0;
y := -1;
z := 1000;
while (x * y + z > 0) {
  x := x + 1;
  y := y - x;
  z := z + y;
}
result := z / (x - y);
```

Would the analysis still succeed if the final statement was `result := z / x`
instead?


Soundness of abstract interpretations
-------------------------------------

For any kind of program analysis, an important question is whether it
is *sound*. We say that an analysis is sound if it can detect all
errors that it claims to detect. For example, the dynamic taint
analysis we studied earlier was *unsound* because it does not rule out
implicit flows of secure data.

To ensure the soundness of a program analysis, we have to give a
formal mathematical proof that it ensures the desired result. However,
giving soundness proofs of sophisticated analyses for practical
languages is a challenging task and often designers of program
analyses do not even attempt to prove soundness. One of the important
use cases of abstract interpretation and Galois connections is that
they can be used to build a static analysis that is sound by design.

As an example, consider the parity analysis of the Calc language defined above.
To show that this analysis is sound, we need to prove that whenever the
abstract interpreter evaluates an expression to `even` or `odd`, the result of
the concrete interpreter is indeed an even or odd number, respectively.

More formally, for any expression $e$ we need to show the following
property:

**Soundness of the abstract interpretation (expressions).** 
Assume $\mathit{ah}$ is an abstract heap and $h$ is a concrete instantiation of it:
for all variables $x$, we have $\hget h x \in \gamma(\hget {\mathit{ah}} x)$.
If $e , \mathit{ah} \reds p$ according
to the abstract interpreter and $e , h \reds l$ according to the concrete
interpreter, then $l \in \gamma(p)$.

For a language with statements such as our Assign language, the formulation of
the soundness property needs to be changed slightly: instead of talking about
individual abstract values, we now need to talk about an *abstract heap*
holding an abstract value for each variable of the program.

**Soundness of the abstract interpretation (statements).** 
Assume $\mathit{ah}$ is an abstract heap and $h$ is a concrete instantiation of it:
for all variables $x$, we have $\hget h x \in \gamma(\hget {\mathit{ah}} x)$.
If $s , \textit{ah} \reds \textit{ah}'$ according to the abstract interpreter and $s , h \reds h'$ according to the concrete
interpreter, then $h' \in \gamma(\textit{ah'})$.

To show that this property holds for our abstract interpretation, we just need
to make sure that the abstract interpreter is a valid approximation of the
concrete interpreter. For example, for the rule saying that $e_1 + e_2 \reds
\even$ when $e_1 \reds \even$ and $e_2 \reds \even$, we need to convince
ourselves that when $e_1$ evaluates to a number in $\gamma(\even)$ and $e_2$
also evaluates to a number in $\gamma(\even)$, then $e_1 + e_2$ also evaluates
to a number in $\gamma(\even)$. But $\gamma(\even)$ is just the set of all even
integers $\{0 , 2 , -2 , 4 , -4, \ldots \}$, so this follows directly from the
fact that the sum of two even numbers is always even.

**Exercise.** Convince yourself that our abstract interpretation of
  the Calc language is indeed sound, by going over all the rules of
  $\reds$ individually.

As long as we make sure that all the individual steps of the abstract
interpreter are correct, the framework of abstract interpretation will ensure
*automatically* that the resulting analysis is sound.

**Question.** Are static type systems also a form of abstract interpretation?
If your answer is yes, what abstract domain do they use? If your answer is no,
what exactly is the difference?



Summary
-------

* An *abstract domain* is a set of abstract values that each describe
  a property of concrete values. We write $\top$ ('top') for the
  abstract value representing the set of all values, and $\bot$
  ('bottom') for the empty set. We write $p \sqsubseteq q$ if the
  property described by $p$ implies the property described by $q$.

* An *abstract interpretation* is a big-step evaluation relation where
  concrete values are replaced by values in the abstract domain.

* The abstract interpretation of an `if`-statement (with an unknown
  condition) is given by interpreting both branches and taking the
  *least upper bound* of the results.

* The abstract interpretation of a `while`-loop (with an unknown
  condition) is given by continuously interpreting the loop body using
  the abstract interpretation until a *fixed point* is reached.

* A *Galois connection* gives the connection between an abstract
  domain and the set of concrete values. It consists of a
  *concretization function* γ mapping abstract values to the set of
  concrete values they represent, and an *abstraction function* α
  mapping a set of concrete values to its best approximation in the
  abstract domain.

* Abstract interpretation and Galois connections can be used to
  design new kinds of static analyses that are *sound by design*.


Further reading
-------------------

- Chapter 4 of: Nielson, Nielson, and Hankin. _Principles of Program
  Analysis_. Springer.





\begin{comment}
Soundness and precision
---------

TODO: discuss sondness vs (full) precision

Example: Flow-insensitive vs flow sensitive vs flow sensitive + lattice analysis of uninitialized read

    public void test () {
      Object var1;
      Object var2 = new Object();
      Object var3;
      if ( Math.random() > 0.5) {
        var1 = null ;
        var3 = new Object();
      } else {
        var1 = new Object();
        var3 = new Object();
      }
      System.out.println(var1.toString() + var2.toString() + var3.toString());
    }

In this course, we have investigated dynamic and static program
analyses:

 - Dynamic bounds checking
 - Dynamic taint analysis
 - Static type checking
 - Substructural type checking

The dynamic analyses augment the default language semantics to prevent
insecure behavior at runtime. The static analysis predicts insecure
behavior of the analyzed program without running it.

However, what if the analysis does not find an error? Does the lack of
found errors entail that there are not errors in the analyzed program?
Well, that depends on whether the analysis is sound or not. Let us
examine soundness at the example of static type systems. For example,
take a look at the following Java program.

```java
    String[] strs = new String[3];
    Object[] objs = strs;
    objs[0] = 42;
    String one = strs[0];
```

The program allocates an array of strings and stores it in a object
array variable. The program then assigns a number to the first element
of the object array and reads out the first element from the string
array variable. The program successfully type checks, but crashes at
runtime with a dynamic type error in line 4, because we cannot store
an integer in an array of strings. The memory is incompatible. This
program is an example for the unsoundness of the Java type checker.

Conversely, a sound type checker prevents dynamic type errors. More
precisely, if a program is type correct, then the program execution
does not get stuck. It is important that we ensure the soundness of a
program analysis, because otherwise the analysis results might lead us
to false conclusions.

**Questions**: What are the implications of an unsound analysis on the
  security of a program?

To ensure the soundness of a program analysis, we have to prove this
property. However, soundness proofs of sophisticated analyses for
practical languages is a challenging task and many designers of
program analyses do not even attempt an prove. To this end, we require
a systematic approach for designing sound analyses. *Abstract
interpretation* is such an approach.
\end{comment}