
Introduction to the course
==========================

These are the lecture notes for the course Language Based Software Security (CS4280) at TU Delft. *Language-based software security* is the
collective name for programming language features and tools that can
be used to write secure applications. Here, the term "security"
includes basic guarantees such as memory safety and the absence of
undefined behaviour, but also language mechanisms to enforce access
control and information flow control. In this course we will study
both dynamic and static techniques for enforcing these security
properties.

At the start of each chapter, there will be a list of learning objectives for
that chapter, and at the end there will be a summary of the most important
points and concepts covered in that chapter. Apart from these lecture notes,
there will also be a series of assignments on Weblab, which consist of reading
assignments, theoretical questions, and practical implementation exercises.


**Learning objectives.** In this chapter you will learn:

- which classes of properties can be enforced at the level of the programming language to rule out security vulnerabilities,

- which different styles of programming language semantics exist,

- what is the difference between a dynamic and static program analysis,

- what is meant with soundness and completeness of a program analysis.


## Course overview

In the following chapters, we will study and compare the following
techniques for ensuring security properties at the level of the
programming language:

- **Chapter 1** looks at the different kinds of security vulnerabilities,
    and how they can be prevented at the level of the programming language
    by enforcing certain security properties.

- **Chapter 2** discusses programming language semantics, in particular
    *small-step operational semantics* (SOS), which will be used in the formal
    description of the techniques in the later chapters.

- **Chapter 3** discusses and compares two different dynamic analysis
    methods for ensuring memory safety: *compile-time instrumentation*
    and *run-time monitoring*.

- **Chapter 4** applies dynamic analysis techniques to the problem
    of information flow control, using a *taint analysis*.

- **Chapter 5** introduces to static analysis techniques and in
    particular *static type checking* for preventing program crashes
    or undefined behaviour that could be exploited by an attacker.

- **Chapter 6** discusses *security types*, a static type system for
    enforcing information flow control policies.

- **Chapter 7** discusses *linear type systems*, a kind of type
    system that can be used to ensure memory safety in the presence of
    manual memory management.

- **Chapter 8** discusses *abstract interpretation*, a different
    form of static analysis that can be used to verify more
    fine-grained (security) properties of programs.

Each chapter will be covered with one or two lectures, a reading assignment, and
a programming assignment (except the first and last chapters). You will find
these assignments and the deadlines for them on Weblab.



## Why care about software security?

Software form a big pillar of modern society. It is used heavily in
areas as varied and critical as medicine, communication,
transportation, and finance. It affects virtually all aspects of our
lives, and controls what data about us is produced and who has access
to it. Yet, most software applications are vulnerable in one way or
another. We define a **security vulnerability** as any kind of
software defect that leads to security issues. Security
vulnerabilities often arise due to programming errors in the source
code of an application, allowing programs to crash, secret data to
leak, or hostile actors to take over control of the system. In recent
  years we have seen many spectacular examples of security
vulnerabilities:

- In 2012, a security bug in the OpenSSL cryptography library was
  introduced.  It was discovered in 2014 and soon became known as
  Heartbleed. It allowed a remote user without any credentials to read
  up to 64KB of protected
  memory.\footnote{\url{https://heartbleed.com/},
  \url{https://web.archive.org/web/20140505213314/http://blog.existentialize.com/diagnosis-of-the-openssl-heartbleed-bug.html}}

- In 2014, the Shellshock family of security bugs in the Unix Bash
  shell was disclosed. It enabled attackers to execute arbitrary code
  and gain full control over web servers that use Bash to process
  requests.\footnote{\url{https://en.wikipedia.org/wiki/Shellshock_\%28software_bug\%29}}

- Also in 2014, Apple released an update fixing a security
  vulnerability known as Goto-fail. This bug was caused by a badly
  formatted piece of assembly code, causing several security checks to
  be skipped when connecting to websites using SSL. This allowed
  attackers to use a man-in-the-middle attack to intercept private
  data.\footnote{\url{https://nakedsecurity.sophos.com/2014/02/24/anatomy-of-a-goto-fail-apples-ssl-bug-explained-plus-an-unofficial-patch/}}

- Over the last 10 years, large scale data breaches have become
  increasingly common. Here are some prominent examples:

  - In 2012, nearly 6.5 million user accounts and passwords were stolen
    from
    LinkedIn.\footnote{\url{https://en.wikipedia.org/wiki/2012_LinkedIn_hack}}

  - Also in 2012, over 68 million Dropbox accounts and passwords were
    leaked.\footnote{https://www.theguardian.com/technology/2016/aug/31/dropbox-hack-passwords-68m-data-breach}

  - In late 2014, data of over 500 million Yahoo user accounts was
    stolen.\footnote{\url{https://money.cnn.com/2016/09/22/technology/yahoo-data-breach}}

  - In 2018, personal and financial details (including credit card
    numbers) of around 380,000 customers were stolen from British
    Airways, resulting in a 183 million pound
    fine.\footnote{\url{https://en.wikipedia.org/wiki/2018_British_Airways_cyberattack}}

  - In 2018, the private data of 533 million Facebook account was
    stolen. In early 2021, all of this data was made available for
    free on the
    internet.\footnote{\url{https://www.bleepingcomputer.com/news/security/533-million-facebook-users-phone-numbers-leaked-on-hacker-forum/}}

  On the website \url{https://haveibeenpwned.com/}, you can check if one
  of your own accounts was involved in one of the leaks above or others.

- In the same period, ransomware has also become widely
  spread. Ransomware makes use of security vulnerabilities to encrypt
  the victim's data, only decrypting it again after a (often large)
  payment.

  - In 2015, TeslaCrypt (a new variant of the CryptoLocker ransomware)
    started targeting gamers to make them pay to unlock their personal
    data.\footnote{\url{https://www.zdnet.com/article/
    new-cryptolocker-ransomware-targets-gamers/}}

  - In 2017, the WannaCry ransomware infected over 300,000 computers
    running
    Windows.\footnote{\url{https://en.wikipedia.org/wiki/WannaCry_ransomware_attack}}

  - In 2019, a hospital in New York was the victim of a ransomware
    attack and permanently lost patient
    records.\footnote{\url{https://cybersecuritynews.com/ransomware-attack-brooklyn-hospital/}}

  - In 2020, the university of Maastricht paid 197.000 euro ransom to
    unlock their data after an attack on their
    servers.\footnote{\url{https://tweakers.net/nieuws/163140/ }}

Programming languages can help developers to prevent programming
errors like the ones above by defining coding principles and detecting
violations of those principles through dynamic and static code
analysis. Such **language-based countermeasures** relieve software
developers of part of the burden of ensuring software security. But
how to select and apply language-based countermeasures? This is the
fundamental question we will try to answer in this course.

**Question:** What different examples of security vulnerabilities are there?

**Answer:** Here is a partial list:

- *Buffer overflow* (also known as *buffer overrun*) attacks can
   happen when a program writes data outside of its allocated memory
   boundaries and overwrites a protected part of memory.

- *Buffer overread* is a variant of buffer overflow where data outside
   of the allocated bounds is read (rather than written).

- *Dangling pointers* are pointers to a piece of memory that has been
deallocated. If this piece of memory is later reused, the dangling pointer
could be used to get unauthorized access to the data there.

- *Code injection* makes use of input fields with untrusted data that
   is sent to an interpreter. An attacker can insert malicious code
   into the input field that is then executed on the target system. Common examples of code injection are *SQL injection* and *cross-site scripting* (XSS).

- *API misuse* makes use of an API (application programmer interface) that does
not (sufficiently) check that the user has the authority to access or modify a
given piece of data. Examples include using a password hash that is not salted
(so it becomes easier to crack many passwords at the same time), or use of SSL
without CA validation (allowing one website to impersonate another one).

- *Race conditions* occur when several software components access the same data or resource concurrently, leading to an illegal program state that

- *Side-channel attacks* happen when supposedly secret data can be obtained through an alternative channel. Examples of side channels include timing channels (based on the time certain operations take), termination channels (based on whether or not an operation terminates), caching channels (based on what data has been cached), power channels (based on power usage), ...

For more examples of software security risks, you can take a look at
the following sources:

- The OWASP Top Ten Web Application Security
  Risks\footnote{\url{https://owasp.org/www-project-top-ten/}}

- The CWE Top 25 Most Dangerous Software
  Weaknesses\footnote{\url{http://cwe.mitre.org/top25/archive/2020/2020_cwe_top25.html}}

- The book \emph{24 Deadly Sins of Software
  Security}\footnote{\url{https://dl.acm.org/doi/book/10.5555/1594832}}

In this course we are not so much interested in all the different
kinds of security vulnerabilities that exist out there, but rather in
general properties that we can enforce at the level of the programming
language in order to rule out large classes of vulnerabilities at
once. In particular, we will study the following properties:

- *Memory safety* ensures that software components can only access the
  part of memory that is allocated to them. Memory safety is a crucial
  property both because it prevents common attacks such as buffer
  overflows and overruns, but also because without memory safety it is
  almost impossible to enforce other more advanced properties.

- *Information flow control* ensures that certain pieces of data
  cannot be accessed and/or modified by unauthorized users. This has
  obvious applications to managing confidential data, but is also
  crucial for protecting against code injection attacks such as SQL
  injection.

- *Type safety* ensures that functions are always called with
  arguments of the correct type. Traditionally type systems have been
  used for preventing program crashes or undefined behaviour, but as
  we will see it is also possible to design type systems to enforce
  memory safety or information secrecy.

- *Thread safety* ensures that different software components do not
   behave in unexpected ways when they are executed in a concurrent
   setting.


## Language-based software security

It is possible to write insecure software in any programming language. Still,
the programming language that we use can make a difference in how easy or hard
it is to write secure software, either by omitting certain unsafe features
(e.g. no manual memory management) or by providing automated analysis of
certain properties (e.g. static type checking). A *language-based
countermeasure* is any technique that operates at the level of the programming
language to ensure a certain security property is satisfied. The goal of this
course is hence to investigate and compare these different language-based countermeasures.

A programming language is built up from many different parts:

- The compiler (e.g. the `gcc` compiler)
- The runtime system (e.g. the Java Virtual Machine)
- IDEs and other editors (e.g. IntelliJ, VS Code, ...)
- Libraries (both standard libraries and third-party libraries)
- User community (StackOverflow, github pull issues and requests, ...)
- Coding conventions and style guides
- Testing frameworks (e.g. JUnit, QuickCheck, ...)
- Profiling and debugging tools
- Program analysis tools (e.g. linters, type checkers)
- Program verification tools (e.g. Coq or Agda)
- ...

In principle, all these aspects of a programming language can and do contribute
to improving the security of software written in that language in some way or
another. However, it is often hard to tell which security vulnerabilities they
prevent exactly, and how effective they are in doing so. In this course we are
interested in techniques for which we can make a formal assessment of what
class of vulnerabilities they prevent. In particular, we will focus on
language-based countermeasures that are either implemented in the *compiler* or
the *runtime system* itself or as external *program analysis tools*.

Language-based countermeasures can be (roughly) classified
into three categories:

- A *dynamic program analysis* is a program analysis that is executed at
run-time (i.e. during execution of the program) and prevents issues as they
occur. Examples of dynamic analyses include automatic checking of memory
violations, file permissions, or network protocols.

- A *static program analysis* is a program analysis that is executed at compile
time (i.e. before the program is executed) and prevents issues before the
program is even started. Examples of static analyses include type checkers, IDE
warning, and formal verification techniques (as discussed in more detail in the
course CS4135 Software Verification).

- *Language design* can also prevent issues by making it impossible to write
certain programs in the first place. Examples of ways to design a language to
prevent security issues are the absence of manual memory management
(e.g. Java), the absence of null pointers (e.g. Haskell), and the absence of
arbitrary loops (e.g. SQL). Taken to its logical extreme, this leads to the
concept of domain-specific languages (DSLs) that only include the features
needed for a specific application.

Each kind of language-based countermeasure has its own advantages and
disadvantages, which we will study in detail during this course.


**Side note: sofware security vs software correctness.** Many security
vulnerabilities arise from bugs in software, allowing an attacker to
misuse an application. So there is a lot of overlap between language
techniques to prevent security vulnerabilities and techniques to
prevent software bugs in general. However, there is a big difference
between the two: for a software bug, the negative impact depends on
how often the bug is triggered during normal usage of the software. So
the impact of a serious bug might still be small if it is only
triggered one out of a million cases. On the other hand, a security
vulnerability usually does not come up during normal operation, but
can be triggered by an active attacker. For example, an SQL injection
is extremely unlikely to happen "by accident", yet can consistently be
exploited by an attacker who knows of the vulnerability. So typical
techniques for preventing software bugs such as testing and code
audits are insufficient to prevent serious security
vulnerabilities. Instead, we will have to use techniques that
consistently detect all problems in a given class.

## Programming language semantics

In order to build language-based countermeasures that work reliably and are effective at preventing security issues, we need to understand how they function at a deep level. In particular, two important questions are whether a given technique is *sound* and *complete*:

- We say that a technique is *sound* if it can detect all errors that it claims
to detect. In other words, a sound analysis is one that produces no false
negatives. For example, we would say that a type checker is sound if once a
program has passed type checking, there can be no type errors at run-time.

- We say that an analysis is *complete* if it does not detect errors unless
there is an actual problem. In other words, a complete analysis is one that
does not raise false alarms. For example, a software monitor that checks access
violations is complete if it only raises an issue when there was an actual violation of the protocol.

Checking whether a given program analysis is sound and/or complete is
a tricky business, and often techniques that were originally claimed
to be sound or complete are later shown not to be.  To really ensure
the soundness and/or completeness of a program analysis, we need to have a formal model of the programming language we are working with as well as the analysis itself.

The *semantics* of a programming language give a formal definition of the
meaning of programs written in that language. There are three main styles of
specifying programming language semantics:

- In *denotational semantics*, syntactic constructs of the language are
   interpreted as a *denotation*, i.e. an abstract object in some
   model.

- In *operational semantics*, syntactic constructs are not translated
  but given meaning directly by evaluating them, i.e. defining an
  interpreter for the language.

- In *axiomatic semantics*, syntactic constructs are given meaning by
  a given set of *axioms*, i.e. logical formulas that describe what we
  know about the program.

Sometimes the distinction between the different styles is somewhat
vague, and there are other kinds of semantics that lie in between
these forms. Other kinds of semantics that exist are: categorical
semantics, game semantics, ...

Operational semantics can be further divided into two subcategories:

- *Small-step operational semantics* are given by specifying how to
   evaluate each expression by one step. For example:
   $$
   \tt{add(add(1,2),3)} \red \tt{add(3,3)} \red \tt{6}
   $$

- *Big-step operational semantics* are given by specifying how to
   evaluate each expression to its final result (the "normal form" of
   the expression). For example:
   $$
   \tt{add(add(1,2),3))} \Longrightarrow \tt{6}
   $$

Large-step operational semantics are generally more compact and easier
to specify, but they can sometimes lose crucial information about the
intermediate state of the program. In this course we will mainly focus
on *small-step operational semantics* as our way of giving meaning to
programs and analyses on them.



## Summary

- A *security vulnerability* is a software defect that leads to security
  issues.

- We can rule out broad classes of security vulnerabilities by
  enforcing certain properties such as memory safety, information flow
  control, type safety, and thread safety.

- A *language-based countermeasure* is a techniques that can
   be used to detect security vulnerabilities at the level of the
   programming language. This includes *dynamic analysis* (= executed at run-time), *static analysis* (= executed at
  compile time), and *language design* (= omitting unsafe features from the language).

- We call a program analysis *sound* if it produces no false
  negatives, and *complete* if it produces no false positives.

- The *semantics* of a programming language give a formal meaning to
  programs written in this language. Different styles of semantics
  include denotational semantics, operational semantics, and axiomatic
  semantics. In this course we mainly use *small-step operational
  semantics* (SOS).


## Further reading

- *The 24 Deadly Sins of Software Security* (2009) by Howard, LeBlanc, and Viega (\url{https://dl.acm.org/doi/book/10.5555/1594832}).

- *Lecture Notes of Language-Based Security* by Erik Poll
   (\url{https://cs.ru.nl/E.Poll/papers/language_based_security.pdf}).