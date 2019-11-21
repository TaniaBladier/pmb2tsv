:- module(parse2dep, [
    main/0]).

/** <module> Convert C&C-style CCG derivations to dependency trees
*/

:- use_module(cac, [
    cac_add_toknums/2,
    cac_cat/2,
    cac_index/2,
    cac_bind/1,
    cac_number/1,
    cac_pp/1,
    cac_top/2]).
:- use_module(cat, [
    arg_in/2,
    cat_dir/2,
    cat_id/2,
    res_in/2]).
:- use_module(dep, [
    t_depdirs/2]).
:- use_module(dir, [
    cac_annotate/1]).
:- use_module(slashes).
:- use_module(util, [
    argv/1,
    funsort/3,
    must/1,
    subsumed_sub_term/2,
    term_in_file/3]).

:- debug(snum).
:- debug(original_const).
%:- debug(const_with_toknums).
%:- debug(indexed_const).
%:- debug(bound_const).
:- debug(numbered_const).
:- debug(annotated_const).
%:- debug(cats).
%:- debug(depdirs).
:- debug(head).
:- debug(dep).

main :-
  argv([CacFile]),
  forall(
      ( term_in_file(ccg(N, Const), CacFile, [module(slashes)])
      ),
      ( cac2dep(N, Const)
      ) ),
  halt.
main :-
  format(user_error, 'USAGE: swipl -l parse2dep -g main CACFILE~n', []),
  halt(1).

cac2dep(N, Const0) :-
  debug(snum, '~w', [N]),
  debug(original_const, 'original: ~@', [cac_pp(Const0)]),
  cac_add_toknums(Const0, Const1),
  debug(const_with_toknums, 'with toknums: ~@', [cac_pp(Const1)]),
  cac_index(Const1, Const),
  debug(indexed_const, 'indexed: ~@', [cac_pp(Const)]),
  (  cac_bind(Const)
  -> debug(bound_const, 'bound: ~@', [cac_pp(Const)]),
     cac_number(Const),
     debug(numbered_const, 'numbered: ~@', [cac_pp(Const)]),
     cac_annotate(Const),
     debug(annotated_const, 'annotated: ~@', [cac_pp(Const)]),
     %( N = 8478 -> gtrace ; true ),
     cac2dep(Const)
  ;  format(user_error, 'WARNING: failed to preprocess derivation ~w, skipping~n', [N]),
     nl
  ).

cac2dep(Const) :-
  findall(t(Cat, Form, Atts),
      ( subsumed_sub_term(t(Cat, Form, Atts), Const)
      ), Tokens),
  cac_top(Const, Top),
  t2dep(Top, Tokens, _, Deps, []),
  forall(
      ( member(dep(D, H), Deps)
      ),
      ( debug(dep, '~@ <- ~@', [cac_pp(D), cac_pp(H)])
      ) ).
% FIXME this only extracts few dependencies.

t2dep(Token, Tokens, Head, Deps0, Deps) :-
  cac_cat(Token, Cat),
  cat2dep(Cat, Tokens, Token, Head, Deps0, Deps).

cat2dep(X/Y, Tokens, Head0, Head, [Dep|Deps0], Deps) :-
  cat_id(X, ID),
  cat_id(Y, ArgID),
  ID \= ArgID, % break cycle with type raising
  member(Arg, Tokens),
  cac_cat(Arg, ArgCat),
  cat_id(ArgCat, ArgID),
  !,
  cat_dir(ArgCat, Dir),
  (  Dir = noninv
  -> Dep = dep(Arg, Head0),
     cat2dep(X, Tokens, Head0, Head, Deps0, Deps)
   ; Dep = dep(Head0, Arg),
     t2dep(Arg, Tokens, Head1, Deps0, Deps1),
     cat2dep(X, Tokens, Head1, Head, Deps1, Deps)
  ).
cat2dep(X\Y, Tokens, Head0, Head, [Dep|Deps0], Deps) :-
  cat_id(X, ID),
  cat_id(Y, ArgID),
  ID \= ArgID, % break cycle with type raising
  member(Arg, Tokens),
  cac_cat(Arg, ArgCat),
  cat_id(ArgCat, ArgID),
  !,
  cat_dir(ArgCat, Dir),
  (  Dir = noninv
  -> Dep = dep(Arg, Head0),
     cat2dep(X, Tokens, Head0, Head, Deps0, Deps)
  ;  Dep = dep(Head0, Arg),
     t2dep(Arg, Tokens, Head1, Deps0, Deps1),
     cat2dep(X, Tokens, Head1, Head, Deps1, Deps)
  ).
cat2dep(_, _, Head, Head, Deps, Deps).




    %  find_root(Root0, Cat, Dirs, Tokens0, Tokens),
    %  cac2dep(Cat, Dirs, _, Root0, Root, Tokens, [], Deps, [dep(Root, _)]),
    %  include(real_dep, Deps, RealDeps),
    %  funsort(depnum, RealDeps, SortedDeps),
    %  maplist(dep_pp, SortedDeps),
    %  nl.

find_root(RootToken, RootCat, RootDirs, Tokens0, Tokens) :-
  select(RootToken, Tokens0, Tokens),
  cac_cat(RootToken, RootCat),
  \+ ( member(FunToken, Tokens),
       cac_cat(FunToken, FunCat),
       arg_in(Y0, FunCat),
       res_in(Y, Y0),
       res_in(Y, RootCat)
     ),
  t_depdirs(RootToken, RootDirs),
  debug(depdirs, '~W ~w', [RootToken, [module(slashes)], RootDirs]).

% functional category, consume argument
cac2dep(Cat, [Dir|Dirs0], Dirs, Head0, Head, Tokens0, Tokens, [Dep|Deps0], Deps) :-
  debug(depdirs, '~W ~w', [Cat, [module(slashes)], [Dir|Dirs0]]),
  member(Cat, [X\Y, X/Y]),
  find_arg(Y, ArgHead0, ArgCat, ArgDirs0, Tokens0, Tokens1),
  !,
  % process argument
  cac2dep(ArgCat, ArgDirs0, ArgDirs, ArgHead0, ArgHead, Tokens1, Tokens2, Deps0, Deps1),
  % determine dependency and head, depending on dependency direction
  (  Dir = noninv
  -> Head1 = Head0,
     Dep = dep(ArgHead, Head0),
     Dirs0 = Dirs1
  ;  Dir = inv
  -> Head1 = ArgHead,
     Dep = dep(Head0, ArgHead),
     Dirs0 = Dirs1
  ;  Dir = mod
  -> Head1 = ArgHead,
     Dep = dep(Head0, ArgHead),
     ArgDirs = Dirs1
  ),
  % process remaining arguments
  cac2dep(X, Dirs1, Dirs, Head1, Head, Tokens2, Tokens, Deps1, Deps).
% no argument to consume
cac2dep(_, Dirs, Dirs, Head, Head, Tokens, Tokens, Deps, Deps).

find_arg(Y0, ArgToken, ArgCat, ArgDirs, Tokens0, Tokens) :-
  res_in(Y, Y0), % n/(n/pp) n/n n/pp
  select(ArgToken, Tokens0, Tokens),
  cac_cat(ArgToken, ArgCat),
  res_in(Y, ArgCat),
  \+ ( member(BetterArgToken, Tokens),
       BetterArgToken = t(BetterArgCat, _, _),
       res_in(ArgCat, BetterArgCat)
     ),
  t_depdirs(ArgToken, ArgDirs),
  debug(depdirs, '~W ~w', [ArgToken, [module(slashes)], ArgDirs]).

real_dep(dep(t(_, Token, _), _)) :-
  Token \= ø.

depnum(dep(t(_, _, Atts), _), From) :-
  member(from:From, Atts).

dep_pp(dep(_, t(_, _, HeadAtts))) :-
  (  var(HeadAtts)
  -> HeadToknum = 0
  ;  member(toknum:HeadToknum, HeadAtts)
  ),
  format('~w~n', [HeadToknum]).
