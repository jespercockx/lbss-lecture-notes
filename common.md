---
title: Language-Based Software Security
date: version of \today
author: Jesper Cockx (based on lecture notes by Sebastian Erdweg)
documentclass: scrartcl
header-includes:
  - \usepackage{mathpartir}
  - \usepackage{unicode-math}
  - \usepackage{newunicodechar}
  - \usepackage{comment}
  - \usepackage{tikz}
  - \usetikzlibrary{positioning}
  - \usepackage{sectsty}
  - \newunicodechar{⊤}{\ensuremath{\top}}
  - \newunicodechar{⊥}{\ensuremath{\bot}}
  - \newunicodechar{γ}{\ensuremath{\gamma}}
  - \newunicodechar{α}{\ensuremath{\alpha}}
  - \newunicodechar{℘}{\ensuremath{\mathcal{P}}}
  - \newunicodechar{∀}{\ensuremath{\forall}}
  - \newunicodechar{∈}{\ensuremath{\in}}
  - \newunicodechar{⊆}{\ensuremath{\subseteq}}
  - \newunicodechar{⊑}{\ensuremath{\sqsubseteq}}
  - \newunicodechar{⊔}{\ensuremath{\sqcup}}
---


\renewcommand\tt[1]{\texttt{#1}}
\renewcommand\it[1]{\textit{#1}}

\newcommand\ie{i.e.}
\newcommand\eg{e.g.}

\newcommand\new[1]{{\color{red}#1}}

\newcommand\true{\tt{true}}
\newcommand\false{\tt{false}}
\newcommand\band{\ \tt{\&\&}\ }
\newcommand\bor{\ \tt{||}\ }
\newcommand\beq{\ \tt{==}\ }
\newcommand\Bool{\tt{Bool}}

\newcommand\Int{\tt{Int}}
\newcommand\Pair[2]{\tt{Pair}\ #1\ #2}

\newcommand\ass{\ \tt{:=}\ }
\newcommand\bop{\ \tt{bop}\ }
\newcommand\sbop{\ \overline{\tt{bop}}\ }
\newcommand\uop{\tt{uop}\ }
\newcommand\suop{\overline{\tt{uop}}\ }
\newcommand\red{\,\longrightarrow\,}
\newcommand\reds{\,\Longrightarrow\,}
\newcommand\hget[2]{\tt{get}(#1,#2)}
\newcommand\hput[3]{\tt{put}(#1,#2,#3)}
\newcommand\halloc[2]{\tt{alloc}(#1,#2)}
\newcommand\hfree[3]{\tt{free}(#1,#2,#3)}
\newcommand\pc{\textit{pc}}
\newcommand\fp{\textit{fp}}
\newcommand\fs{\textit{fs}}
\newcommand\rt{\textit{rt}}
\newcommand\arnew[1]{\tt{arnew}\ #1}
\newcommand\arnewt[2]{\tt{arnew}\ #1\ #2}
\newcommand\arread[2]{\tt{arread}\ #1\ #2}
\newcommand\arwrite[3]{\tt{arwrite}\ #1\ #2\ #3}
\newcommand\jumpif[2]{\tt{jumpif}\ #1\ #2}
\newcommand\abort[0]{\tt{abort}}
\newcommand\arswap[3]{\tt{arswap}\ #1\ #2\ #3}
\newcommand\arlen[1]{\tt{arlen}\ #1}
\newcommand\call[3]{\tt{call}\ #1\ #2\ #3}
\newcommand\return[1]{\tt{return}\ #1}
\newcommand\istainted[2]{\tt{isTainted}(#1, #2)}
\newcommand\marktainted[2]{\tt{markTainted}(#1, #2)}
\newcommand\unmarktainted[2]{\tt{unmarkTainted}(#1, #2)}
\newcommand\putsafe[4]{\tt{putSafe}(#1,#2,#3,#4)}

\newcommand\cget[2]{\tt{get}(#1,#2)}
\newcommand\cupdate[3]{\tt{update}(#1,#2,#3)}
\newcommand\cout{\leadsto}
\newcommand\cmeet[2]{\tt{meet}(#1,#2)}

\newcommand\even{\tt{even}}
\newcommand\odd{\tt{odd}}

\newcommand\abs[1]{\widetilde{{#1}}}

\tableofcontents

\sectionfont{\clearpage}
