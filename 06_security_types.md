

Security Type Systems
=====================

Type systems are often used to ensure that functions are called with
arguments of the right shape. But this is not the only thing that
type systems are useful for. We already saw one example before:
by distinguishing between integers and memory pointers, we can avoid
(some) illegal memory accesses. Next, we will look at another example
that will require more drastic changes to our type system: statically
enforcing information flow control using a type system. Type systems
for enforcing information flow are known as *security type systems*.

**Learning objectives.** In this chapter you will learn

* how to design a type system for enforcing information flow policies such as non-interference
* how to detect implicit information flows in programs using a security type system

## Security types

In a security type system, each part of a program is assigned a *security
type*, which is a label that determines the confidentiality (or "taintedness")
of the data produced by that component. The ultimate goal of a security type
system is to ensure that the program satisfies non-interference, i.e. that the
value of highly confidential/tainted data does not influence the values of
non-confidential/untainted data.

As usual, the big benefit of a static type system over a dynamic technique such
as taint tracking is that is does not introduce any run-time overhead. In
addition, security type systems are inherently compositional: once we have
checked that a part of the program (e.g. a library) is type correct, all the
information we need is available in the type signature and we never need to
re-analyze the code.

In the simplest case, a security type system has just two types: `H` (high
security) and `L` (low security):

    Type ::= 'H' | 'L'

In a more realistic implementation of a security type system, we can combine
these labels with the usual types such as `Bool` and `Int`, resulting in types
such as $\tt{Bool}_L$ or $\tt{Int}_H$. For simplicity we focus here on just the
security labels themselves.

Once again, we will work with a context $\Gamma$ that assigns a type to each
variable that is in scope:


    Context ::= '' | Identifier ':' Type ';' Context

For example, a context might be `x : H; y : L; z : H`, indicating that the
values of `x` and `z` are of high security, while the value of `y` is low
security.


## Security types for the Assign language

The typing rules for expressions are straightforward: constants such as `true`
and `false` are low security, while operations such as `+` or `&&` produce a
high security output if at least one of their inputs is high security, and a
low security output otherwise. Finally, variables just take the security label
that is assigned to them by the context.

To avoid having to duplicate rules, we introduce a new (meta-)operation $\lor$
on security types that computes the security level on the output of a binary
operation. It is simply defined as follows:

$$\begin{array}{lcl}
H \lor H &=& H \\
H \lor L &=& H \\
L \lor H &=& H \\
L \lor L &=& L \\
\end{array}$$

The rules for typing expressions are as follows:

\begin{mathpar}
\inferrule{\ }{\Gamma \vdash \true : L}

\inferrule{\ }{\Gamma \vdash \false : L}

\inferrule{\ }{\Gamma \vdash n : L}

\inferrule{\Gamma \vdash e : T \\ \tt{uop} \in \{ ! , - \} }{\Gamma \vdash {\tt{uop}\ e} : T}

\inferrule{
  \Gamma \vdash e_1 : T_1 \\
  \Gamma \vdash e_2 : T_2 \\
  \tt{bop} \in \{ \tt{\&\&} , \tt{||} , \tt{==}, + , - , / , * , < , > \} }{
  \Gamma \vdash e_1 \bop e_2 : T_1 \lor T_2
}
\end{mathpar}

We also require one additional rule for expressions that allows us to re-label
low security data as being high security. This corresponds to the rule of
non-interference that low security inputs are allowed to influence high
security outputs, but not vice versa. This is called the *relabeling rule*.

\begin{mathpar}
\inferrule{
  \Gamma \vdash e : L }{
  \Gamma \vdash e : H  
}
\end{mathpar}

For variable assignments, we give the following rule, which is unchanged from
before:

\begin{mathpar}
\inferrule{
  \Gamma \vdash e : T \\
  \cupdate \Gamma x T = \Gamma'
}{
  \Gamma \vdash x \ass e \cout \Gamma'
}
\end{mathpar}

Once we add other statements such as `if` and `while`, this rule will need to
be updated.

**Exercise.** Write down the typing derivation for the following program with the initial context `x : H; y : L`:

```
x := y + 4;
y := y - 5;
z := x + y;
```

**Exercise.** The security type system that we just designed enforces
*confidentiality* of secure data: high security data cannot leak to low
security outputs. Another property that is important in some applications is
*integrity*: the values of high security 'trusted' outputs cannot be influenced
by low security 'untrusted' inputs. How would you change the security type
system so it can be used to enforce integrity?

**Answer.** We can construct a different security type system with two types
`T` (trusted) and `U` (untrusted) and the following rules:

$$\begin{array}{lcl}
U \lor U &=& U \\
U \lor T &=& U \\
T \lor U &=& U \\
T \lor T &=& T \\
\end{array}$$

The relabeling rule now allows us to reclassify a trusted input as an untrusted input:

\begin{mathpar}
\inferrule{
  \Gamma \vdash e : T }{
  \Gamma \vdash e : U  
}
\end{mathpar}

## Soundness and precision of security types

As for any program analysis we define, we should investigate the soundness and
precision of our analysis. First, let's define soundness of our security type
system.

--------------------------
**Soundness of security typing.** A security type system is sound if
well-typedness implies non-interference, i.e. if $\Gamma \vdash e : L$
and $x : H \in \Gamma$, then the final result of evaluating $e$ is
independent of the (initial) value of $x$.
--------------------------

Proving soundness of our security type system is outside of the scope of this
course. However, in chapter 8 we will study the technique of *abstract
interpretation*, which is often used to prove soundness of static type systems.

Regarding precision, we can observe that our security type system is
unfortunately not very precise. For example, when a low-security value is
relabeled as a high-security value, then a program that uses it to compute a
low security output is rejected even though it does not violate
non-interference.

**Exercise.** Can you think of other situations where the security type system
we described loses precision?

## Detecting implicit information flows

An important problem when trying to enforce non-interference is how to detect
so-called *implicit flows* where the value of a low security output is
influenced by a high security input not directly but through the control flow
of the program. A typical example is a program that uses `if` to branch on the
value of a high security input:

```
h := ...  // h : H is a high-security value
x := 0
if (h == 0) then {
  x := 1
} else {
  x := 2
}
```

To detect such implicit flows, we make use of an additional security label on
the *program counter* that keeps track of whether we have branched on a
high-security input:

\begin{mathpar}
\inferrule{
  \Gamma \vdash e : T \\
  \Gamma , (P \lor T) \vdash \it{ss}_1 \cout \Gamma' \\
  \Gamma , (P \lor T) \vdash \it{ss}_2 \cout \Gamma''
}{
  \Gamma , P \vdash \tt{if}\ e\ \{ \it{ss}_1 \}\ \tt{else}\ \{\it{ss}_2\} \cout \Gamma
}

\inferrule{
  \Gamma \vdash e : T \\
  \Gamma , (P \lor T) \vdash \it{ss} \cout \Gamma'
}{
  \Gamma , P \vdash \tt{while}\ e\ \{\it{ss}\} \cout \Gamma
}
\end{mathpar}

In the judgement $\Gamma , P \vdash s \cout \Gamma'$, the security type $P$ is
$H$ if we have branched on a high security value, and $L$ otherwise. When
assigning a new value to a variable, we must take this label into account:

\begin{mathpar}
\inferrule{
  \Gamma \vdash e : T \\
  \cupdate \Gamma x {(T \lor P)} = \Gamma'
}{
  \Gamma , P \vdash x \ass e \cout \Gamma'
}
\end{mathpar}

When we assign to a variable, this rule will set its security type to `H` if
either the value depends on a high security input directly (i.e. $T$ is `H`)
or if we are inside an `if` or a `while` with a high security condition (i.e. $P$ is `H`).

**Exercise.** Draw the derivation tree for the example program that was given
above. Where does the typing algorithm get stuck?

**Question.** Does the same trick work for (dynamic) taint analysis? That is,
can we introduce an additional label that keeps track of whether we have
branched on a secure input, and use that to detect implicit flows?

**Answer.** This is possible and in fact it is often done in the literature,
where this label is called the "process sensitivity label". However, such an
approach is not sufficient to detect all implicit flows. Consider the following
example:

```
h := ...  // h : H is a high-security value
x := 0
if (h == 0) then {
  x := 1
} else {
  // do nothing
}
```

In the case where `h` is not `0`, there is no assignment and thus dynamic
analysis will not detect any violation of the taint property. However, the
final value of `x` still depends on the value of `h`, so non-interference is
violated. This is another advantage of static analysis over dynamic analysis:
by looking at all program traces at once instead of just a single one, it can
detect violations of properties that talk about multiple executions of the same
program (such as non-interference).

Security types for functions
----------------------------

For applying security types to function definitions and function calls, we
again work with a global signature $\Sigma$, which assigns a security type to
each defined function. We also again require a return type to keep track of the
type of `return` statements.

The typing judgement for statements now becomes $\Sigma, \Gamma, P, R \vdash
\it{ss} \cout \Gamma'$, where $T$ is the label of the program counter and $R$
is the type that return statements must adhere to.

When we return from a function, we have to make sure that the current security
level on the program counter is not higher than the return type:

\begin{mathpar}
\inferrule{
  \Gamma \vdash e : R \\
  T \leq R
}{
  \Sigma,\Gamma,P, R \vdash \return e \cout \Gamma
}
\end{mathpar}

Without this restriction, a function could leak confidential information by
conditionally executing an early return in an `if` or `while` statement.

**Exercise.** Give an example of this behaviour that would be accepted if we
omitted the condition $T \leq R$.

The rule for function calls is essentially unchanged:

\begin{mathpar}
\inferrule{
  \cget \Sigma f = (T_1, \ldots, T_n) \to T \\
  \Gamma \vdash e_i : T_i \quad (i = 1\ldots n) \\
  \cupdate \Gamma x T = \Gamma'
}{
  \Sigma,\Gamma,P,R \vdash x \ass f {(e_1 \ldots e_n)} {} \cout \Gamma'
}
\end{mathpar}

To make the typing system a bit more flexible, we can also allow any function to
be called with arguments at a high security level, as long as we also require the
function output to be at a high security level:

\begin{mathpar}
\inferrule{
  \cget \Sigma f = (T_1, \ldots, T_n) \to T \\
  \Gamma \vdash e_i : \tt{H} \quad (i = 1\ldots n) \\
  \cupdate \Gamma x \tt{H} = \Gamma'
}{
  \Sigma,\Gamma,P,R \vdash x \ass f {(e_1 \ldots e_n)} {} \cout \Gamma'
}
\end{mathpar}

When checking a function definition, we set the initial value of the type $T$
to the low security level `L`:

\begin{mathpar}
\inferrule{
  \Sigma, (x_1:T_1; \ldots; x_n: T_n), L , T \vdash \it{ss} \cout \Gamma'
}{
  \Sigma \vdash (\tt{fun}\ T\ f\ (T_1\ x_1, \ldots, T_n\ x_n)\ \{ \it{ss} \}) \text{ ok}
}
\end{mathpar}

**Exercise.** Write down the typing rules for arrays. Which possible implicit flows of information does this create, and how can these be prevented?

Summary
-------

- A *security type system* is a type system where the types do not constrain
the set of possible values, but instead the level of confidentiality.

- The goal of a security type system enforces non-interference: the value of
high-security inputs cannot influence the value of low-security outputs.

- The advantages of a security type system over dynamic taint analysis is that
it does not have a runtime overhead, and it can detect implicit flows more reliably.

- The disadvantage of a security type system compared to dynamic taint analysis
is that it is less precise, since it does not have access to runtime data.

- When adding new features such as if/while statements and functions, we should
be careful to avoid introducing implicit flows through which secure information
can leak.

Further reading
------------------

- Dennis M. Volpano, Cynthia E. Irvine, Geoffrey Smith: *A Sound Type
  System for Secure Flow Analysis*. Journal of Computer Security,
  4(2/3):167-188 (1996).

- Andrei Sabelfeld, Andrew C. Myers. *Language-based information-flow security*.
  IEEE Journal on Selected Areas in Communications, 21(1):5-19, 2003.