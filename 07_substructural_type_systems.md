

Substructural Type Systems
==========================

Last chapter we have seen how a static type system can help us to
distinguish values of different types. In particular, it allowed us to
distinguish arrays from integers, even though both share the same
run-time representation. We also designed a *security type system*
for tracking the flow of secure information through a program and
ensuring non-interference.

Static type systems can do evn more for us than this. This chapter we will study
how a static type system can help us ensure memory safety. As you might
remember from the homework assignments of chapter 2, *memory safety* means the
prevention of three issues:

 - **use after free**: dynamically allocated memory is read from or written to after the memory was freed

 - **double free**: dynamically allocated memory is freed twice

 - **memory leak**: dynamically allocated memory is never freed

As it turns out, it is possible to design a static type system that
can prevent all three issues. In fact, such type system can ensure
more than that, it can also ensure there are no *data races*. Data
races happen when two concurrent threads of a multi-threaded program
access the same memory location. If this happens, one of the following
issues can arise:

 - **write-write conflict**: Two concurrent threads write to the same
     memory location. Depending on the scheduling of the threads, one
     result will be overwritten by the other.

 - **read-write conflict**: Two concurrent threads access the same
     memory location, one reading and one writing. The reading thread
     may see either the data before or after writing, depending on
     thread scheduling.

**Learning objectives.** In this chapter you will learn:

- how the type system of the Rust programming language ensures memory
  safety and prevents data races

- how to distinguish between the different substructural type systems:
  affine, linear, and ordered

- how to extend the Function language with an affine or linear type
  system


Memory and data-race safety in Rust
-----------------------------------

Rust is a programming language with a unique type system that can
ensure memory safety statically. In contrast to most programming
languages does not rely on garbage collection (like Java or Scala) to
clean up unused memory, nor does it require memory to be deallocated
explicitly (like C). Instead, the memory taken by a variable is
automatically deallocated at the end of its lifetime, which is usually
when the variable goes out of scope.

**Question.** What are the limitations or disadvantages of using a garbage collector?

Sections 4.1 and 4.2 of the Rust
book\footnote{\url{https://doc.rust-lang.org/stable/book/ch04-00-understanding-ownership.html}}
explain the details of Rust's central notion of *ownership*:

> "Rust’s central feature is ownership. Although the feature is straightforward to explain, it has deep implications for the rest of the language."
>
> "All programs have to manage the way they use a computer’s memory while running. Some languages have garbage collection that constantly looks for no longer used memory as the program runs; in other languages, the programmer must explicitly allocate and free the memory. Rust uses a third approach: memory is managed through a system of ownership with a set of rules that the compiler checks at compile time. None of the ownership features slow down your program while it’s running."
>
> "In languages with a garbage collector (GC), the GC keeps track and cleans up memory that isn’t being used anymore, and we don’t need to think about it. Without a GC, it’s our responsibility to identify when memory is no longer being used and call code to explicitly return it, just as we did to request it. Doing this correctly has historically been a difficult programming problem. If we forget, we’ll waste memory. If we do it too early, we’ll have an invalid variable. If we do it twice, that’s a bug too. We need to pair exactly one allocate with exactly one free."
>
> "Rust takes a different path: the memory is automatically returned once the variable that owns it goes out of scope."
>
> "Rust’s memory safety guarantees make it difficult, but not impossible, to accidentally create memory that is never cleaned up (known as a memory leak). Preventing memory leaks entirely is not one of Rust’s guarantees in the same way that disallowing data races at compile time is, meaning memory leaks are memory safe in Rust. We can see that Rust allows memory leaks by using Rc<T> and RefCell<T>: it’s possible to create references where items refer to each other in a cycle. This creates memory leaks because the reference count of each item in the cycle will never reach 0, and the values will never be dropped."

Following are a few examples of ownership and borrowing in Rust. If you want to
play with these examples yourself, you can try out Rust online at
\url{https://play.rust-lang.org/}.

Rust distinguished mutable variables from immutable variables. By
default, variables are considered to be immutable unless specified
explicitly with the `mut` keyword. In the code below, we are not
allowed to assign to the immutable variable `s` twice. Note that Rust
`String`s are stored on the heap, so the variable `s` contains a
pointer that resides on the stack and points to data that resides on
the heap.

```rust
    fn main() {
        let s = String::from("Delft");
        println!("Hello {}", s);

        s = String::from("TU Delft");
        println!("Hello {}", s);
    }
```

This causes Rust to raise the following error:

```
error[E0384]: cannot assign twice to immutable variable `s`
 --> src/main.rs:5:2
  |
2 |     let s = String::from("Delft");
  |         -
  |         |
  |         first assignment to `s`
  |         help: make this binding mutable: `mut s`
...
5 |     s = String::from("TU Delft");
  |     ^ cannot assign twice to immutable variable
```

Mutable variables can be reassigned. The old value is freed during the
reassignment, because it becomes inaccessible. The new value is freed
as the variable reaches the end of its scope (the end of the function
body here), because it becomes inaccessible. This essentially prevents
memory leaks. For example, the following program is accepted:

```rust
    fn main() {
        let mut s = String::from("Delft");
        println!("Hello {}", s);
        s = String::from("TU Delft");
        println!("Hello {}", s);
    }
```

What happens when we assign a pointer to another variable? You might
think that both `s` and `s2` now point to the dynamically allocated
String on the heap.  But that would lead to a double free when both
variables move out of scope.  Instead, the pointer stored in `s` is
marked as "inaccessible" when it is assigned to `s2`.  In Rust lingo:
the value (the pointer stored in `s`) was moved to `s2`. This
essentially prevents double frees and use after free.

```rust
    fn main() {
        let s = String::from("Delft");
        let s2 = s;
        do_print(s);
        do_print(s2);
    }

    fn do_print(s: String) {
        println!("Hello {}", s);
    }
```

```
error[E0382]: use of moved value: `s`
 --> src/main.rs:4:14
  |
2 |     let s = String::from("Delft");
  |         - move occurs because `s` has type `String`, which does not
  |           implement the `Copy` trait
3 |     let s2 = s;
  |              - value moved here
4 |     do_print(s);
  |              ^ value used here after move
```

Values are not only moved during variable assignment, but also when
calling a function:

```rust
fn main() {
    let s1 = String::from("Delft");
    let len = calculate_length(s1);
    do_print(s1, len)
}
fn calculate_length(s: String) -> usize {
    s.len()
}
fn do_print(s: String, len: usize) {
    println!("The length of '{}' is {}.", s, len);
}
```

```
error[E0382]: use of moved value: `s1`
 --> src/main.rs:4:14
  |
2 |     let s1 = String::from("Delft");
  |         -- move occurs because `s1` has type `String`, which does not
  |            implement the `Copy` trait
3 |     let len = calculate_length(s1);
  |                                -- value moved here
4 |     do_print(s1, len)
  |              ^^ value used here after move
```

One way to deal with moved values is to move them back when the
function returns.

```rust
    fn main() {
        let s1 = String::from("Delft");
        let (len, s2) = calculate_length(s1);
        do_print(s2, len)
    }
    fn calculate_length(s: String) -> (usize, String) {
        (s.len(), s)
    }
    fn do_print(s: String, len: usize) {
        println!("The length of '{}' is {}.", s, len);
    }
```

To circumvent variable moving altogether, we use the ampersand
operator `&`. The `&` operator behaves similarly to C and creates a
reference to a variable. When passing a reference, the actual value is
not moved at all. Instead, the function "borrows" usage rights of the
variable temporarily.

```rust
    fn main() {
        let s = String::from("Delft");
        let len = length(&s);
        do_print(s,len);
    }
    fn length(s: &String) -> usize {
        s.len()
    }
    fn do_print(s: String, len: usize) {
        println!("The length of '{}' is {}.", s, len);
    }
```

Note that the `&` operator is used both when *creating* a reference to a value
and also on the type of the function argument when *passing around* a
reference.

By default, borrows are immutable, that is, they disallow changes to
the dynamically allocated data. This is crucial for concurrent
applications, where want to prevent data races.

```rust
    fn main() {
        let s = String::from("Hello");
        let len = length(&s);
        println!("The length of '{}' is {}.", s, len);
    }
    fn length(s: &String) -> usize {
        s.push_str(", Delft!");
        s.len()
    }
```

Here Rust prevents us from accidentally modifying the string `s` in
the `length` function:

```
error[E0596]: cannot borrow `*s` as mutable, as it is behind a `&` reference
 --> src/main.rs:7:5
  |
6 | fn length(s: &String) -> usize {
  |              ------- help: consider changing this to be a mutable
  |                      reference: `&mut String`
7 |     s.push_str(", Delft!");
  |     ^ `s` is a `&` reference, so the data it refers to cannot be
  |       borrowed as mutable
```

If we do want the function `length` to be able to modify the string,
we can pass it a mutable reference using the `&mut` syntax. When
calling the `length` function, we then also need to pass it a mutable
reference to `s`, which we can create using the `&mut` operator.

```rust
fn main() {
    let mut s = String::from("Hello");
    change(&mut s);
    println!("{}", s);
}
fn change(s: &mut String) {
    s.push_str(", Delft!");
}
```

However, mutable borrows are more restricted in the sense that there
can only ever be a single mutable borrow of the same object:

```rust
fn main() {
    let mut s = String::from("Hello");
    let x = &mut s;
    let y = &mut s;
    println!("{}", x);
}
```
Error message:

```
error[E0499]: cannot borrow `s` as mutable more than once at a time
   --> src/main.rs:179:13
    |
178 |     let x = &mut s;
    |             ------ first mutable borrow occurs here
179 |     let y = &mut s;
    |             ^^^^^^ second mutable borrow occurs here
180 |     println!("{}", x);
    |                    - first borrow later used here
```

By disallowing multiple mutable borrows, Rust prevents concurrent updates to
the same object, thus avoiding race conditions where the outcome of the program
becomes unpredictable.

Finally, Rust will also ensure there are no dangling references, by checking
that there are no more borrows of a variable when it goes out of scope.

```rust
fn main() {
    let reference_to_nothing = dangle();
    println!("{}",reference_to_nothing);
}
fn dangle() -> & String {
    let s = String::from("hello");
    &s
}
```

Error message:

```
error[E0106]: missing lifetime specifier
 --> src/main.rs:5:16
  |
5 | fn dangle() -> & String {
  |                ^ expected named lifetime parameter
  |
  = help: this function's return type contains a borrowed value, but
  | there is no value for it to be borrowed from
```

In summary, Rust's type system enforces memory safety by preventing
the three main causes of errors:

 - Variables are automatically deallocated when they go out of scope, so there
   are no memory leaks.

 - Variables are considered "moved" after being used, so use-after-free
   and double frees are prevented become impossible.

To support concurrent programming, Rust's type system prevents data
races. In Rust, exactly one of the following is true for any variable:

 - There is no reference to it, which means the data has a single
   owner that has solitary access.

 - There are any number of immutable references to it, which means all
   of them can simultaneously read the data but none can modify it.

 - There is a single mutable reference to it, which is the sole way to
   modify or read the data.

Rust's type system is a specific instance of what are known as
*substructural type systems*. To understand how Rust's (and similar)
type systems work, we have to understand the key concepts of
substructural type systems.


Substructural type systems
--------------------------

In what follows, we design (two variants of) a substructural type system for
our Function language. To learn more about substructural type systems in
general, you can read the chapter "Substructural Type
Systems"\footnote{\url{https://mitpress-request.mit.edu/sites/default/files/titles/content/9780262162289_sch_0001.pdf}}
by David Walker (from the book "Advanced Topics in Types and Programming
Languages").

The type systems we studied last two chapters enjoy three basic properties
called the *structural properties*:

- **Exchange** allows swapping the position of two variables in the context:

$$ \inferrule{ \Gamma; x_1 : T_1; x_2 : T_2; \Gamma' \vdash e : T \\ x_1 \neq x_2 }
  { \Gamma; x_2 : T_2; x_1 : T_1; \Gamma' \vdash e : T }
$$

- **Weakening** allows adding new (unused) variables to the context:

$$ \inferrule{
  \Gamma_1;\Gamma_2 \vdash e : T \\
  x_1 \not\in \Gamma_1;\Gamma_2
  }{
  \Gamma_1;x_1:T_1;\Gamma_2 \vdash e : T
}$$

- **Contraction** allows merging two variables of the same type into one:

$$ \inferrule{
  \Gamma_1;x_2:T_1;x_3:T_1;\Gamma_2 \vdash e : T
  }{
  \Gamma_1;x_1:T_1;\Gamma_2 \vdash [x_2 \mapsto x_1][x_3 \mapsto x_1]e : T
}$$

A *structural type system* is a type system in which these three structural
rules are admissible, i.e. adding them to the type system does not change what
expressions can be typed.

A *substructural type system* is a type system that lacks one or more
of these structural properties. The book chapter identifies the
following substructural type systems:

- An *unrestricted* type system has all three rules (exchange,
  weakening, and contraction). This means variables can be used any
  number of times and in any order. This includes most type systems,
  including the ones we studied last two chapters for the Function language.

- An *affine* type system has the exchange and weakening rules, but
  not the contraction rule. This means variables can be used *at most
  once*. An affine type system can be used to ensure memory safety and
  avoid data races in concurrent programs (as in the Rust language).

- A *relevant* type system has the exchange and contraction rules, but
  not the weakening rule. This means variables must be used *at least
  once*.

- A *linear* type system has the exchange rule but not the weakening
  or contraction rules. This means variables must be used *exactly
  once*. This can be used to enforce proper usage of certain resources
  such as file handles, to ensure it can only be accessed by one part
  of the program at a time and is properly closed in the end.

- An *ordered* type system has none of the rules exchange, weakening,
  or contraction. This means variables must be used exactly once *in
  the same order as they were introduced* (last introduced variable
  must be used first). This can be used to enforce proper usage of
  certain data structures such as stacks.

As an example, consider the following interface for working with file handles
in a linearly typed language:

```
fun open (f : FileName) -> FileHandle
fun read (h : FileHandle) -> (String, FileHandle)
fun append (s : String, h : FileHandle) -> FileHandle
fun write (s : String, h : FileHandle) -> FileHandle
fun close (h : FileHandle) -> Void
```

Here is an example of a program that uses this interface:

```
x := open("myfile.txt");
y := write("Hello, world!", x);  // x goes out of scope here
close(y);                        // y goes out of scope here
```

Before we can use any other operation, we first have to call `open` to create a
file handle. Each function that uses a file handle (`read`, `append`, and
`write`) also returns a new file handle. The reason for this is that each
handle can be used only once, so we need to return the handle again if we want
to continue working with it. Finally, the function `close` does not return
anything, so after it is called we can be sure that no further operations on
the same file handle are performed.

Affine/Linear Function language
-------------------------------

We can transform any type system into a substructural one. To explore
how, we will change the structural type system from chapter 5 into one
where we require it is affine or linear. The goal of this type system
is to ensure that each variable is used *at most once* for the affine
type system, or *exactly once* for the linear type system.

### Substructural rules for expressions

Compared to last chapter, we need a new judgment $\Gamma \vdash e : T
\cout \Gamma'$. The idea is that the resulting context only contains
those variables that have not been used in $e$. In most type rules, we
simply propagate the context, but in the rule for variable references,
we remove binding of the resolved variable from it. We write $\Gamma -
x$ for the context $\Gamma$ with the variable $x$ removed. This way,
we prevent any subsequent expression to resolve the same variable
again.

\begin{mathpar}
\inferrule{
  \cget \Gamma x = T \\
  \Gamma' = \Gamma - x
}{
  \Gamma \vdash x : T \cout \Gamma'
}

\inferrule{\ }{\Gamma \vdash \true : \Bool \cout \Gamma}

\inferrule{\ }{\Gamma \vdash \false : \Bool \cout \Gamma}

\inferrule{\Gamma \vdash e : \Bool \cout \Gamma'}
  {\Gamma \vdash {!e} : \Bool \cout \Gamma'}

\inferrule{
  \Gamma_0 \vdash e_1 : \Bool \cout \Gamma_1 \\
  \Gamma_1 \vdash e_2 : \Bool \cout \Gamma_2 \\
  \tt{bop} \in \{ \tt{\&\&} , \tt{||} , \tt{==} \} }{
  \Gamma_0 \vdash e_1 \bop e_2 : \Bool \cout \Gamma_2
}

\inferrule{\ }{\Gamma \vdash \mathit{num} : \Int \cout \Gamma}

\inferrule{\Gamma \vdash e : \Int \cout \Gamma'}{\Gamma \vdash {-e} : \Int \cout \Gamma'}

\inferrule{
  \Gamma_0 \vdash e_1 : \Int \cout \Gamma_1 \\
  \Gamma_1 \vdash e_2 : \Int \cout \Gamma_2 \\
  \tt{bop} \in \{ + , - , / , * \} }{
  \Gamma_0 \vdash e_1 \bop e_2 : \Int \cout \Gamma_2
}

\inferrule{
  \Gamma_0 \vdash e_1 : \Int \cout \Gamma_1 \\
  \Gamma_1 \vdash e_2 : \Int \cout \Gamma_2 \\
  \tt{bop} \in \{ \tt{==} , < , > \} }{
  \Gamma_0 \vdash e_1 \bop e_2 : \Bool \cout \Gamma_2
}
\end{mathpar}

We get a linear type system if we require the context with unused
variables to be empty after type checking:

$$ \Gamma \vdash e : T \cout \tt{} $$

Conversely, we get an affine type system if we allow non-empty
contexts to remain:

$$ \Gamma \vdash e : T \cout \Gamma'$$

**Exercise**: Draw a typing derivation for $x : \Int \vdash x + x :
  \Int$. Is the expression well-typed in an affine type system? Is it
  well-typed in a linear type system?

**Exercise**: Draw a typing derivation for $x : \Int; y : \Bool \vdash
  x + 1 : \Int$. Is the expression well-typed in an affine type
  system? Is it well-typed in a linear type system?

### Substructural rules for statements

We can use the same judgment form as last chapter for expressions, but we
need to be more restrictive about what variables to allow. Let us
start with assignments. Last chapter, we have this rule:


\begin{mathpar}
\inferrule{
  \Gamma \vdash e : T \\
  \cupdate \Gamma x T = \Gamma'
}{
  \Gamma \vdash x \ass e \cout \Gamma'
}
\end{mathpar}

We need to make multiple changes. First, our new expression judgment
gives us back an updated context that we have to use.

\begin{mathpar}
\inferrule{
  \Gamma_0 \vdash e : T \cout \Gamma_1 \\
  \cupdate {\Gamma_1} x T = \Gamma_2
}{
  \Gamma_0 \vdash x \ass e \cout \Gamma_2
}
\end{mathpar}

Second, for a linear type system, we must ensure that each variable is
used exactly once. However, our assignment adds variable $x$ to the
context, which might overwrite a previous binding of $x$. This is fine
in an affine system (access at most once), but not in a linear one
(access exactly once). To this end, we need to modify the definition
of `update` as follows:

$$ \begin{array}{lll@{\qquad}l}
\cupdate \Gamma x T &=& \Gamma & \text{if not linear and } \cget \Gamma x = T \\
\cupdate \Gamma x T &=& x:t;\Gamma & \text{if } \cget \Gamma x \text{ is undefined} \\
\cupdate \Gamma x T &=& \text{undefined} & \text{otherwise} \\
\end{array} $$

Let us look at `if`-statements next. Our rule last chapter was this:

$$\inferrule{
  \Gamma \vdash e : \Bool \\
  \Gamma \vdash \mathit{ss}_1 \cout \Gamma' \\
  \Gamma \vdash \mathit{ss}_2 \cout \Gamma''
}{
  \Gamma \vdash \tt{if}\ (e)\ \{\mathit{ss}_1\}\ \tt{else}\ \{\mathit{ss}_2\} \cout \Gamma
}$$

That rule is not acceptable for an affine or linear type system. The
problem is that even though a branch might access a variable (so it
would be removed from $\Gamma'$ and/or $\Gamma''$), this rule would
allow further access to those variables by statements following the
`if` since it returns the original context $\Gamma$. To avoid that, we
must avoid reusing the input context $\Gamma$ as output context of the
`if` statement. Instead, the output context needs to be a combination
of what comes out of the two branches.

$$\inferrule{
  \Gamma_0 \vdash e : \Bool \cout \Gamma_1 \\
  \Gamma_1 \vdash \mathit{ss}_1 \cout \Gamma_2 \\
  \Gamma_1 \vdash \mathit{ss}_2 \cout \Gamma_3 \\
  {\Gamma_2} \sqcap {\Gamma_3} = \Gamma_4 \\
}{
  \Gamma_0 \vdash \tt{if}\ (e)\ \{\mathit{ss}_1\}\ \tt{else}\ \{\mathit{ss}_2\} \cout \Gamma_4
}$$

We have yet to define the operation $\sqcap$ (called the 'meet'),
which combines the two contexts. How to combine them depends on
whether we want to realize an affine or a linear type system. It is
useful to inspect the following example program to see what is needed:

    x := 5;
    b := randBool();
    if (b) {
      y := x;
    } else {
      y := 0;
    }

What should be in the context after the if statement besides variable
`y`? In both affine and linear systems, we may only allow access to a
variable at most once. Variable `b` occurs in the condition, so this
variable may not be accessible afterwards. But what about variable
`x`?  Only one of the two branches accesses `x`, while the other one
uses a numeric literal. But since we cannot predict which branch
executes at runtime, our type system must somehow govern this
situation. The specific rule depends on whether the type system is
affine or linear:

- For affine type systems: We can ensure variables are accessed at
  most once by only keeping the variables that are still available at
  the end of *both* branches. We can achieve this by only keeping the
  variables that are in the output contexts of both branches, i.e. by
  taking their intersection.

- For linear type systems: We must ensure each variable is accessed
  exactly once, which is only possible if both branches access exactly
  the same variables. So we must enforce that the output contexts of
  the two branches are identical.

Now we can define the $\sqcap$ operation:

$$ \begin{array}{lll@{\qquad}l}
{\Gamma_1} \sqcap {\Gamma_2} &=& \Gamma_1 & \text{if } \Gamma_1 = \Gamma_2 \\
{\Gamma_1} \sqcap {\Gamma_2} &=& \Gamma_1 \cap \Gamma_2 & \text{if affine} \\
{\Gamma_1} \sqcap {\Gamma_2} &=& \text{undefined} & \text{otherwise}
\end{array} $$


**Exercise**: Give a possible substructural typing rule for
  `while`-loops. Think about in which order different parts of the
  loop are executed. In particular, investigate when the condition is
  evaluated.

**Answer**: We have to ensure that the output context $\Gamma_3$ does still
contain all the variables that are used in both the condition and the body of
the `while` loop. For the linear variant of the type system, we also need to
ensure that there are no additional variables that are defined in the body but
not used. Here is a possible typing rule that accomplishes these two
requirements:

$$\inferrule{
  \Gamma_0 \vdash e : \Bool \cout \Gamma_1 \\
  \Gamma_1 \vdash \mathit{ss} \cout \Gamma_2 \\
  {\Gamma_0} \sqcap {\Gamma_2} = \Gamma_0
}{
  \Gamma_0 \vdash \tt{while}\ (e)\ \{\mathit{ss}\} \cout \Gamma_0
}$$


In an affine type system, it is allowed to have some variables that
are unused, but this is not the case in a linear type system. To make
the linearly typed variant into a usable language, we can add a
statement for *explicitly* forgetting about a certain variable. For
this purpose, we add a new `delete` statement (see also the Weblab
assignment for chapter 3):

    Stmt ::= ... | 'delete' Expr

This operation has no effect in the type system, it simply consumes
all variables that were used in the expression.

\begin{mathpar}
  \inferrule{\Gamma \vdash e : T \cout \Gamma'}{\Gamma \vdash \tt{delete}\ e \cout \Gamma'}
\end{mathpar}

Depending on what property we want to enforce with the linear type
system, this rule may be restricted to only work on certain types
$T$. For example, if we are using a linear type system to enforce
proper usage of file handles (see the chapter by Walker), all files
must be closed using the `close` operation. As a consequence, we would
only allow `delete` to be used for simple types such as \Int{} and not
for any type that contains a file handle.

### Substructural rules for functions

Next, we will extend our substructural type systems to top-level
function definitions. This is a straightforward adaptation of the
rules we saw last chapter. The only thing we have to keep in mind is that
for the linear variant of our type system, the context must be empty
when returning from a function.


\begin{mathpar}
\inferrule{
  \Gamma \vdash e : T \new{\cout \Gamma'} \\
  \new{\Gamma' = \tt{empty} \text{ (if linear)}}
}{
  \Sigma,\Gamma,T \vdash \return e \cout \Gamma'
}

\inferrule{
  \cget \Sigma f = (T_1, \ldots, T_n) \to T \\
  \Gamma_{i-1} \vdash e_i : T_i \new{\cout \Gamma_i} \quad (i = 1\ldots n) \\
  \cupdate {\Gamma_n} x T = \Gamma_{n+1}
}{
  \Sigma,\Gamma_0,R \vdash x \ass f {(e_1 \ldots e_n)} {} \cout \Gamma_{n+1}
}

\inferrule{
  \Sigma, (x_1:T_1; \ldots; x_n: T_n), T \vdash \it{ss} \cout \Gamma' \\
  \new{\Gamma' = \tt{empty} \text{ (if linear)}}
}{
  \Sigma \vdash (\tt{fun}\ T\ f\ (T_1\ x_1, \ldots, T_n\ x_n)\ \{ \it{ss} \}) \text{ ok}
}
\end{mathpar}

**Question.** Are the following two functions well-typed according to the rules above?

```
fun Int f(x : Int, y : Int) {
  return x;
  return y;
}

fun Int g(x : Int) {
  if (false) {
    return x;
  } else {

  }
}
```

**Exercise.** Design a *relevant* type system for the Function language, i.e.
one where each variable has to be used at least once.

**Solution outline.** We need to keep track of the *usage* of each variable in
the context (either `used` or `unused`). At first, each variable is marked as
`unused` when it is added to the context, and marked as `used` when it is used.
For joining two context (e.g. for an `if` statement) a variable is marked as
`used` if it is used in *both* branches of the `if`. Finally, at the end of
each function body we need to check that there are no unused variables left in
the context.

### Substructural rules for pairs and arrays

The final feature we will add to our substructural type systems are
arrays. However, since they are rather tricky to handle correctly in a
substructural type system, we will start with the simpler case of
*pair types*. A pair type $\Pair {T_1} {T_2}$ is the type of pairs
$(e_1,e_2)$. You can think of a pair as an array of length 2, except
that the types of the two elements can be different.

Usually, this type would come together with two operations `first` and
`second` for getting the first and the second element of a pair,
respectively. However, this does not work well in the context of a
substructural type system. To see why, consider an example function
that takes a pair of two integers and returns their sum:

    fun Int sum(p : Pair Int Int) {
      x := first p;
      y := second p;
      return (x + y);

With a linear or affine type system, this function would not typecheck
because the variable `p` is "consumed" by the statement `x := first
p`, so it is no longer available for the second statement.

To fix this problem, we instead introduce a new statement `(x , y) :=
split e` that 'splits' the pair `e` into its two components `x` and
`y`. By getting both components at the same time, we avoid the problem
we had before. With this operation, we can define the `sum` function
as follows:

    fun Int sum(p : Pair Int Int) {
      (x,y) := split p;
      return (x + y);


Formally, we extend the syntax of the language as follows:

    Type ::= ... | 'Pair' Type Type

    Expr ::= ... | '(' Expr ',' Expr ')'

    Stmt ::= ... | '(' Identifier ',' Identifier ')' '=' 'split' Expr

We have the following substructural typing rules for pairs:

\begin{mathpar}
\inferrule{
  \Gamma_0 \vdash e_1 : T_1 \cout \Gamma_1 \\
  \Gamma_1 \vdash e_2 : T_2 \cout \Gamma_2
}{
  \Gamma_0 \vdash (e_1,e_2) : \Pair {T_1} {T_2} \cout \Gamma_2
}

\inferrule{
  \Gamma_0 \vdash e : \Pair {T_1} {T_2} \cout \Gamma_1 \\
  \cupdate {\Gamma_1} {x} {T_1} = \Gamma_2 \\
  \cupdate {\Gamma_2} {y} {T_2} = \Gamma_3
}{
  \Gamma_0 \vdash (x,y) := \tt{split}\ e \cout \Gamma_3
}
\end{mathpar}


**Exercise.** Define the functions `first` and `second` by making use
  of `split`, assuming you are working in an affine type system. Do
  these definitions still typecheck in a linear type system? Why
  (not)?


Let us now turn our attention to the operations on arrays. We could
use the following rule for `arlen`:

\begin{mathpar}
\inferrule{
  \cget \Gamma x = T[] \\
  \Gamma' = \Gamma - x
}{
  \Gamma \vdash \arlen x : \Int \cout \Gamma'
}
\end{mathpar}


However, this would mean the `arlen` operation would "consume" the
array; we would not be able to refer to variable $x$
afterwards. Instead, we assume that taking the length of an array is
always allowed and does not remove it from the context:

\begin{mathpar}
\inferrule{
  \cget \Gamma x = T[]
}{
  \Gamma \vdash \arlen x : \Int \cout \Gamma
}
\end{mathpar}

The typing of array lookup is more tricky to define in a substructural
type system. Again we have to avoid removing the whole array from the
context just because we read a single value from it. However, let us
see what goes wrong when we keep working with the same context:

\begin{mathpar}
\inferrule{
  \cget {\Gamma} x = T[] \\
  \Gamma \vdash e : \Int \cout \Gamma'
}{
  \Gamma \vdash y \ass \arread x e \cout y:T; \Gamma'
} \end{mathpar}

This rule seems to make sense at first: it returns the element from
the array at the given position, and keeps the array `x` in the context so
we do not lose access to it. However, it is not quite correct because
it allows multiple reads of the same array element:

    y := arread x 5;
    z := arread x 5;
    return y + z;

Here, both `y` and `z` refer to the 5th element of the same array,
which should not be allowed in an affine or linear type system.

Unfortunately, we cannot apply the same technique we did for pair
types directly, as the length of an array can be unknown. Another
approach one might try is to keep track of which array elements have
been read already, but this goes beyond the expressiveness of our
current type system. Instead, we replace the two operations `arread`
and `arwrite` with a single `arswap` operation that reads an array
element and simultaneously replaces it with a new value, returning
the old value. This way, all elements of the array remain accessible as before.
Note that this operation does not remove the reference `a` to the array itself
from the context, so the array remains accessible.

    Stmt ::= ... (remove 'arread' and 'arwrite')
           | Identifier ':=' 'arswap' Identifier Expr Expr

The typing rule for `arswap` is a combination of the rules for `arread` and
`arwrite`:

\begin{mathpar}
\inferrule{
  \cget {\Gamma_0} a = T[] \\
  \Gamma_0 \vdash e_1 : \Int \cout \Gamma_1 \\
  \Gamma_1 \vdash e_2 : T \cout \Gamma_2 \\
  \cupdate {\Gamma_2} y T = \Gamma_3
}{
  \Gamma_0 \vdash y \ass \arswap a {e_1} {e_2} \cout \Gamma_3
} \end{mathpar}

That is, `arswap` is an atomic operation that can be compiled as
follows (note that here `arread` and `arwrite` are now considered to
be low-level instructions that should not be used directly and do not
adhere to substructural type checking):

    compile(y := arswap x e1 e2) = [|
      y := arread x i
      arwrite x e1 e2
    |]


Summary
-------

- A *substructural type system* is a type checking that rejects at
  least one of the rules of exchange, weakening, and contraction.

- Substructural type systems include affine (no contraction), relevant
  (no weakening), linear (no contraction or weakening), and ordered
  (no structural rules).

- The Rust programming langauge uses a refined version of an affine
  type system to prevent memory leaks, use-after-free, and double free
  errors, as well as write-write and read-write conflicts in
  concurrent programs.

Further reading
------------------

- Chapter on *Substructural Type Systems* of David Walker: *Advanced
  Topics in Types and Programming Languages*
  (\url{https://mitpress-request.mit.edu/sites/default/files/titles/content/9780262162289_sch_0001.pdf}).

- Chapter 4 of the Rust Book on *Understanding Ownership*
  (\url{https://doc.rust-lang.org/stable/book/ch04-00-understanding-ownership.html}).