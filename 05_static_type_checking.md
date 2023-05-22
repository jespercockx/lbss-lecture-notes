

Static Type Checking
====================

In the previous two chapters, we have discussed dynamic analysis as a means
to prevented unwanted execution steps to occur in a trace. The main
advantage of dynamic analysis is that it has access to a program's
runtime state in order to detect violations. The main disadvantage is
that it can only detect violations at runtime, when it is too late for
the software developer to react.

In this lecture, we discuss static analysis as an alternative to dynamic
analysis. A static analysis checks program properties at compile time, that is,
without executing the program. A static analysis may only approve programs when
it can guarantee that the checked property holds for all possible traces of the
program. Examples of static analysis techniques are static type systems,
(static) data-flow analysis, symbolic execution, model checking, program logics
(e.g. separation logic), abstract interpretation, and formal verification using
a proof assistant.

A single program can have multiple traces, for example, due to I/O actions,
random number generators, arguments to main that are unknown at compile time,
or even part of the code that is unknown at compile time. While a dynamic
analysis can look at just one concrete execution trace, a static analysis has
to analyze all possible execution traces at once. In face of such
uncertainties, a static analysis must correctly approximate the actual program
behavior. Hence (almost) all static analysis techniques either have to give up
on archieving perfect precision or else lose soundness. An example of the
latter kind are many linting tools and IDE warnings that try to detect certain
problems without providing an absolute guarantee of soundness.

**Learning objectives.** In this chapter, we will focus on one of the most
common and simple static analysis techniques: static type checking. In
particular, you will learn:

- how a static type system can prevent runtime errors in a program
- how to model a simple static type system for an expression language
  consisting of integers and booleans
- how to extend this type system to a language with mutable variables,
  arrays, `if`- and `while`-statements, and function calls

Static type systems
-------------------

A type system is a way to assign a *type* to each program element
(statements, expressions, subexpressions). *Static type checking*
assigns these types at compile time and makes sure they match up,
in order to prevent illegal inputs at run time.

For example, consider the following two function definitions:

    fun f1(x: Int)  { return x + 1; }
    fun f2(x: Bool) { return x + 1; }

In neither function we know what value `x` will evaluate to at
runtime. But, in `f1` we assert that `x` will evaluate to some integer
value due to the type annotation `Int`. Thus, the operation `x + 1` is
well-typed (i.e., valid) and `f1` yields an integer result. In
contrast, the body of function `f2` is ill-typed (i.e., invalid)
because `+` requires both arguments to be integer values, but `x` is
asserted to be a Boolean value by the type annotation. And indeed,
this function would get stuck at runtime when called with a Boolean
argument.

As this example shows, a static type system allows us to distinguish
values of different types and ensure we consume these values
appropriately. In the example above, the static type system helped us
detect a stuck program at compile time by distinguishing `Bool` from
`Int` values. While important, in the context of software security,
distinguishing `Array` values from `Int` values is more important
still.

**Question**: Why is it important for software security to distinguish
  `Array` values from `Int` values?

**Answer**: Treating arrays as numbers exposes the heap location of
  the array to the user. Treating numbers as arrays allows for
  arbitrary memory manipulation, even when bounds checking is in
  place.

**Exercise**: Write a program that treats numbers as arrays in order
  to read data from memory inappropriately. Can you make it such that
  a dynamic bounds checker would not detect this security violation?

**Answer**: Consider the following two function definitions:

    fun g1(x: Bool[])  { return arlen x; }
    fun g2(x: Int)     { return arlen x; }

The second function will interpret the value of x as a memory location
and fetch the value stored there.

**Question**: Does the distinction of `Array` values and `Int` values
  also prevent stuck programs?

**Answer**: No, because `Array` values and `Int` values share the same
  literal representation `Number`. For example, `g2(5)` is not stuck.

There are other ways that type systems can help with enforcing security
properties of our programs. For example, *security type system* are used for
statically enforcing information flow control, and *substructural type systems
are used for enforcing memory safety (see the next two chapters for more
details).
 
Typing Expressions
------------------

But how can we define a static type system? We define it by means of
type rules over the typing judgement $\Gamma \vdash e : T$ (read: $e$
has type $T$ in the context $\Gamma$). Here, $e$ is an expression, $T$
is a type, and $\Gamma$ is a typing context that communicates context
information relevant to type checking the expression $e$ (statements
and other syntactic classes will be covered later). The precise shape
of $\Gamma$ and $T$ depend on which language we are trying to type
check. For this lecture, let us again use the Function language
extended with arrays from previous chapter. We also extend the language with
`if`- and `while`-statements, and with two binary operations `<` and
`>` for comparing integers.

    Prog       ::= Fun ';' Prog | Stmts
    Fun        ::= 'fun' FunName '(' FunArgs ')' '{' Stmts '}'
    FunName    ::= String
    FunArgs    ::= '' | Identifier ',' FunArgs
    Stmts      ::= '' | Stmt ';' Stmts
    Stmt       ::= Identifier ':=' Expr
                 | Identifier ':=' 'arnew' Expr
                 | Identifier ':=' 'arread' Identifier Expr
                 | 'arwrite' Identifier Expr Expr 
                 | Identifier ':=' FunName '(' Args ')'
                 | 'return' Expr
                 | 'if' Expr '{' Stmts '}' 'else' '{' Stmts '}'
                 | 'while' Expr '{' Stmts '}'
    Args       ::= '' | Expr ',' Args 
    Expr       ::= Identifier | Literal | Expr BinOp Expr | UnOp Expr
                 | 'arlen' Identifier
    BinOp      ::= '+' | '-' | '/' | '*' | '&&' | '||' | '=='
                 | '<' | '>'
    UnOp       ::= '-' | '!'
    Literal    ::= Number | 'true' | 'false'
    Identifier ::= String

For this language, we require types for Booleans, numbers, arrays, and
functions:

    Type ::= 'Bool' | 'Int' | Type '[]'

Example types include:

- `Bool`
- `Bool[]`
- `Int[][]`

Note that we allow arrays to contain values of a single type
only. That is, all elements of an array of type `T[]` will have type
`T`. This is because it is very complicated to define (and to use) a
type system with heterogeneous arrays that can store values of
different types.

Let's start with the type rules for Booleans (we discuss the context
$\Gamma$ below):

\begin{mathpar}
\inferrule{\ }{\Gamma \vdash \true : \Bool}

\inferrule{\ }{\Gamma \vdash \false : \Bool}

\inferrule{\Gamma \vdash e : \Bool}{\Gamma \vdash {!e} : \Bool}

\inferrule{
  \Gamma \vdash e_1 : \Bool \\
  \Gamma \vdash e_2 : \Bool \\
  \tt{bop} \in \{ \tt{\&\&} , \tt{||} , \tt{==} \} }{
  \Gamma \vdash e_1 \bop e_2 : \Bool
}
\end{mathpar}

The first rule stipulates that `true` has type `Bool` in any context
$\Gamma$. Similarly, the second rule defines that `false` has type
`Bool` in $\Gamma$. The third rule says that if $e$ has type $\Bool$
in context $\Gamma$, then so does $!e$. The final rule uses two
preconditions to ensure that expressions $e_1$ and $e_2$ have type
`Bool`. If this is the case, then the conjunction `&&`, disjunction
`||`, and equality `==` of $e_1$ and $e_2$ also have type `Bool`.

We can define rules for numbers and equality in the same style:

\begin{mathpar}
\inferrule{\ }{\Gamma \vdash \it{num} : \Int}

\inferrule{\Gamma \vdash e : \Int}{\Gamma \vdash {-e} : \Int}

\inferrule{
  \Gamma \vdash e_1 : \Int \\
  \Gamma \vdash e_2 : \Int \\
  \tt{bop} \in \{ + , - , / , * \} }{
  \Gamma \vdash e_1 \bop e_2 : \Int
}

\inferrule{
  \Gamma \vdash e_1 : T \\
  \Gamma \vdash e_2 : T \\
  \tt{bop} \in \{ \tt{==} , < , > \} }{
  \Gamma \vdash e_1 \bop e_2 : \Bool
}
\end{mathpar}

We can use the type rules defined so far to check if an expression
(without variables) is well-typed. An expression is well-typed if we
can construct a derivation tree using the type rules. For example, the
following derivation tree shows that expression `(7 == 2) && (-3 == 8)`
is well-typed.

\begin{mathpar}
\inferrule{
  \inferrule{
    \inferrule{\ }{\vdash 7 : \Int} \\
    \inferrule{\ }{\vdash 2 : \Int} 
  }{
    \vdash 7 \beq 2 : \Bool
  } \\
  \inferrule{
    \inferrule{
      \inferrule{\ }{\vdash 3 : \Int}
    }{
      \vdash -3 : \Int
    } \\
    \inferrule{\ }{\vdash 8 : \Int}
  }{
    \vdash -3 \beq 8 : \Bool
  } 
}{
  \vdash (7 \beq 2) \band (-3 \beq 8) : \Bool
}
\end{mathpar}

A derivation tree starts at the bottom with the expression we want
analyze and the type we expect. Each bar in the derivation tree
corresponds to an application of a typing rule, where we write the
instantiated preconditions of the rule above the bar. For example, at
the bottom of our derivation tree we used the type rule for binary
Boolean expressions, which has two preconditions (one for $e_1$ and
one for $e_2$). Thus, our derivation tree continues with two
instantiated preconditions. Now we recursively apply type rules until
there are no preconditions left to check. When that happens we know
for sure that the expression at the bottom of the derivation tree is
well-typed and has the denoted type.

Let's consider the expression `arlen x`. Clearly, the result of the
expression is a number, but only if the variable x stores a value that
represents an array. The content of a variable x is determined by the
context in which the expression occurs. For example, `arlen x` in `x
:= arnew 1; arlen x` is well-typed, whereas `arlen x` in `x := 3;
arlen x` is ill-typed because we disallow treating the numerical
literal 3 as an array.

We will use a typing context $\Gamma$ to keep track of the types of
variables. In our `arlen x` example above, the typing context tells us
what the type of `x` is, so that we can distinguish well-typed from
ill-typed usages of `arlen`. That is we use the typing context to
communicate information about the type of values stored in variables:

    Context ::= '' | Identifier ':' Type ';' Context

For example, a context `x:Bool; y:Int[];` stipulates that variables
`x` and `y` are bound and that `x` stores a value of type `Bool` and
`y` stores a value of type `Int[]`. We can use the typing context to
define the type rule for variable references `x`:

\begin{mathpar}
\inferrule{\cget \Gamma x = T}{\Gamma \vdash x : T}
\end{mathpar}

Here, $\cget \Gamma x$ is a (meta-level) partial function that looks
up the type assigned to $x$ by $\Gamma$, if there is an entry for $x$.

We can now also give a typing rule for `arlen`:

\begin{mathpar}
\inferrule{\cget \Gamma x = T[]}{\Gamma \vdash \arlen x : \Int}
\end{mathpar}

That is, if $\Gamma$ binds $x$ to have an array type $T[]$ for some
$T$, then $\arlen x$ has type $\Int$ in $\Gamma$. The second rule says
that a variable reference is only well-typed if the required variable
is bound, and the type of the variable reference is the type of the
variable in the current context.

This concludes the type rules for expressions and we can now construct
derivation trees for all well-typed expressions. For example, in a
context $\Gamma = \tt{x:Bool[];}$, the following derivation shows
that expression $(\arlen x) + 3 \beq 2$ is well-typed.

\begin{mathpar}
\inferrule{
  \inferrule{
    \inferrule{
      \inferrule{
        \inferrule{\ }{\cget \Gamma x = \Bool[]}
      }{
      \Gamma \vdash x : \Bool[]
      }
    }{
    \Gamma \vdash \arlen x : \Int
    } \\
    \inferrule{\ }{\Gamma \vdash 3 : \Int}
  }{
  \Gamma \vdash (\arlen x) + 3 : \Int
  } \\
  \inferrule{\ }{\Gamma \vdash 2 : \Int}
}{
\Gamma \vdash (\arlen x) + 3 \beq 2 : \Bool
}
\end{mathpar}

At every level, we used one of the rules introduced above to derive
that all subexpressions of $(\arlen x) + 3 \beq 2$ are well-typed and
the overall expression has type `Bool`.

**Exercise**: Try to construct a derivation of
  $(\arlen x) + 3 \beq 2 : \Bool$ in the context
  $\Gamma = \tt{x:Int;}$. Where can we see that
  the expression is ill-typed in $\Gamma$?

 
Typing Statements
-----------------

We can now define a second set of type rules for type checking
statements. In contrast to expressions, statements introduce variable
bindings and thus influence the typing context. For this, we use the
judgement $\Gamma \vdash s \cout \Gamma'$, where $\Gamma$ and $\Gamma'$
are a typing contexts and $s$ is a statement that we want to
check. Statements do not have a type, since they do not produce
values. However, a statement can introduce a new variable to the
context, so this judgement yields an updated typing context for a
sequence of statement.

Generally, we will require that a variable has a single type
throughout its scope. That is, a program `x := 1; x := true` is
ill-typed, because the two assignments disagree on the type of `x`. We
capture this property in an auxiliary function called `update`:

$$ \begin{array}{lll@{\qquad}l}
\cupdate \Gamma x T &=& \Gamma & \text{if } \cget \Gamma x = T \\
\cupdate \Gamma x T &=& \text{undefined} & \text{if } \cget \Gamma x = T' \neq T \\
\cupdate \Gamma x T &=& x:T;\Gamma & \text{if } \cget \Gamma x \text{ is undefined} \\
\end{array} $$

That is, if $x$ is bound in $\Gamma$ already, then $T$ must be equal
to the previous type of $x$ in $\Gamma$. If $T$ is different from the
previous type of $x$ in Γ, then $\cupdate \Gamma x T$ is undefined. If
instead $x$ is not yet bound in $\Gamma$, then we add $x:T$ to
$\Gamma$.

Equipped with this auxiliary function, we can define the typing rule
for variable assignments:

\begin{mathpar}
\inferrule{
  \Gamma \vdash e : T \\
  \cupdate \Gamma x T = \Gamma'
}{
  \Gamma \vdash x \ass e \cout \Gamma'
}
\end{mathpar}

An assignment $x \ass e$ is well-typed if $e$ is well-typed and $x$ is
either a new variable or the type of $e$ is compatible with the type
of $x$.

For `if`- and `while`-statements, the whole statement is well-typed if
the condition `e` has type `Bool` and the statements in the body are
well-typed (we define the type rules for statement sequences
below). Note how we ignore the (potentially) updated typing context
$\Gamma'$ from the body and yield the original typing context $\Gamma$
instead. This ensures that variables that are declared in the body of
an `if`- or `while`-statement cannot be used outside. This way, the
type checker can enforce lexical scoping, but note that the runtime
system needs changing to implement the same variable scoping (not
shown).

\begin{mathpar}
\inferrule{
  \Gamma \vdash e : \Bool \\
  \Gamma \vdash \it{ss}_1 \cout \Gamma' \\
  \Gamma \vdash \it{ss}_2 \cout \Gamma''
}{
  \Gamma \vdash \tt{if}\ e\ \{ \it{ss}_1 \}\ \tt{else}\ \{\it{ss}_2\} \cout \Gamma
}

\inferrule{
  \Gamma \vdash e : \Bool \\
  \Gamma \vdash \it{ss} \cout \Gamma'
}{
  \Gamma \vdash \tt{while}\ e\ \{\it{ss}\} \cout \Gamma
}
\end{mathpar}

Next, let us consider the allocation of a new array $x \ass \arnew
e$. As a first attempt, we can define the following type rule:

\begin{mathpar}
\inferrule{
  \Gamma \vdash e : \Int \\
  \cupdate \Gamma x {{\color{red}???}[]} \cout \Gamma'
}{
  \Gamma \vdash x \ass \arnew e \cout \Gamma'
}
\end{mathpar}

We first check that the size of the array is indeed given by an
expression of type `Int`. Then we bind $x$ in the context for the
subsequent statements. But, what is the type of $x$ precisely?
Clearly, $x$ must have an array type since it results from an array
allocation. But what is the element type of that array? Since the type
checker has not seen any elements of the array yet, we cannot infer
the element type. One solution would be to only determine the element
type later on, but that is fragile, for example, when different
conditional branches attempt to put elements of different types into
the array.

For this reason, we require the programmer to declare the element type
of a newly allocated array through a type annotation. That is, we
change the syntax for array allocation statements as follows:

    Stmt ::= ...
           | Identifier ':=' 'arnew' Type Expr

The type rule for array allocation then looks as follows, where we
adopt the annotated type as the element type of the array:

\begin{mathpar}
\inferrule{
  \Gamma \vdash e : \Int \\
  \cupdate \Gamma x {T[]} \cout \Gamma'
}{
  \Gamma \vdash x \ass \arnewt T e
} 
\end{mathpar}

**Exercise**: Define type rules for `arread` and `arwrite`.

Before moving on to functions, let us briefly consider how to assign a
type to a sequence of statements. To this end, we introduce another
typing judgement $\Gamma \vdash \it{ss} \cout \Gamma'$, defined by the
following rules. What is important here is that we propagate changes
made to the context by a statement to the subsequent statements:

\begin{mathpar}
\inferrule{\ }{\Gamma \vdash \tt{} \cout \Gamma}

\inferrule{
  \Gamma_1 \vdash s \cout \Gamma_2 \\
  \Gamma_2 \vdash \it{ss} \cout \Gamma_3
}{
  \Gamma_1 \vdash s;\it{ss} \cout \Gamma_3
} 
\end{mathpar}

Typing Functions
----------------

We still have to type check function calls and function
declarations. For this, we extend our typing judgement for statements
to add a global *signature* $\Sigma$. A signature is similar to a
context in that it consists of typing statements of the form `f : T`,
but it assigns types to top-level functions rather than to variables.

    Signature ::= '' | Identifier ':' Types '->' Type ';' Signature
    Types     ::= '' | Type ',' Types

When we are typechecking the body of a function definition, we also
need to keep track of the return type of the function. On the other
hand, in the main code there is no return type to keep track of. Hence
in the typing judgement for statements we have an optional return type
$R$:

    RetType   ::= '' | Type

Like for array allocation, we require the programmer to declare the
types of function parameters and return values through type
annotation. Thus, we change the syntax for function declarations as
follows:

    Fun     ::= 'fun' Type FunName '(' FunArgs ')' '{' Stmts '}'
    FunArgs ::= '' | Type Identifier ',' FunArgs

This makes it easy to fill $\Sigma$ initially by collecting the
signatures of all declared functions. We then extend the typing
judgement for statements to $\Sigma, \Gamma, R \vdash \it{ss} \cout
\Gamma'$, where $\Sigma$ is a global signature, $\Gamma$ is a typing
context, $R$ is the type that return statements must adhere to, $\it{ss}$
is the sequence of statements we want to check, and $\Gamma'$ is a
potentially updated typing context. We can use $R=\tt{''}$ for the main
code, where no return statements may occur.

We have to adapt all type rules for statements from above to pass
along $\Sigma$ and return type $R$ recursively (the type rules for
expressions remain unchanged). For example, we obtain the following
updated rule for variable assignment:

\begin{mathpar}
\inferrule{
  \Sigma, \Gamma, R \vdash e : T \\
  \cupdate \Gamma x T = \Gamma'
}{
  \Sigma, \Gamma, R \vdash x \ass e \cout \Gamma'
}
\end{mathpar}

Using the extended typing judgement for statements, we can now also
provide type rules for function calls and `return` statements. Return
statements are only well-typed when the return type is non-empty, that
is, $R \neq \tt{''}$. The expression then needs to produce a value of
that type $R$.

\begin{mathpar}
\inferrule{
  \Gamma \vdash e : T
}{
  \Sigma,\Gamma,T \vdash \return e \cout \Gamma
}
\end{mathpar}

For function calls, we fetch the type signature of the called function
from the global signature $\Sigma$. We then check all arguments and
ensure the argument types correspond to the parameter types of the
called function $f$. Finally, we yield an extended typing context,
where $x$ has the type that the function returns according to the
signature.

\begin{mathpar}
\inferrule{
  \cget \Sigma f = (T_1, \ldots, T_n) \to T \\
  \Gamma \vdash e_i : T_i \quad (i = 1\ldots n) \\
  \cupdate \Gamma x T = \Gamma'
}{
  \Sigma,\Gamma,R \vdash x \ass f {(e_1 \ldots e_n)} {} \cout \Gamma'
}
\end{mathpar}

The last missing piece in our type system is to check whole
programs. A program consists of a sequence of function definitions
followed by a main sequence of statements. We already know how to deal
with the main statements, so all that's left is to check the function
definitions.

To type check a function definition we use a new typing judgement
$\Sigma \vdash d \text{ ok}$, where $\Sigma$ is the global signature,
$d$ is a function definition, and 'ok' simply marks a function as
being well-typed. A function is well-typed if its body is well-typed
in a context where the parameters are bound and the return type is set
to the annotated return type $T$.

\begin{mathpar}
\inferrule{
  \Sigma, (x_1:T_1; \ldots; x_n: T_n), T \vdash \it{ss} \cout \Gamma'
}{
  \Sigma \vdash (\tt{fun}\ T\ f\ (T_1\ x_1, \ldots, T_n\ x_n)\ \{ \it{ss} \}) \text{ ok}
}
\end{mathpar}

**Question**: When type checking a function, we only take a global
  signature $\Sigma$ as input, but not a context $\Gamma$. Why is
  that? Why don't we need $\Gamma$?

**Exercise**: Define 2 well-typed and 2 ill-typed Fun programs, each
  featuring at least two function declarations.

Summary
-------

- Static type systems can be used to prevent runtime errors in
  programs, as well as security issues that arise from using an
  integer as (a pointer to) an array.

- A *context* $\Gamma$ is a list of variable typings of the form $x_i : T_i$.

- A *signature* $\Sigma$ is a list of top-level function typings of
  the form $f : T_1\ \ldots\ T_n \to T$.
  
- The typing judgement for expressions $\Sigma,\Gamma \vdash e : T$
  states that $e$ is an expression of type $T$ in the signature
  $\Sigma$ and context $\Gamma$.

- The typing judgement for statements $\Sigma,\Gamma,R \vdash s \cout
  \Gamma'$ states that $s$ is a well-typed statement in signature
  $\Sigma$, where $\Gamma$ and $\Gamma'$ are the contexts *before* and
  *after* executing the statement $s$, and $R$ is the (optional)
  return type.


Further reading
------------------

- Chapters 8, 9, and 11 of Pierce: *Types and Programming
  Languages*. The MIT Press.

- (optional) Stefan Hanenberg, Sebastian Kleinschmager, Romain Robbes,
  Éric Tanter, Andreas Stefik: *An empirical study on the impact of
  static typing on software maintainability*. Empirical Software
  Engineering 19(5): 1335-1382 (2014)
