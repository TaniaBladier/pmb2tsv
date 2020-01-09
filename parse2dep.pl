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
    cat_is_pseudo/1,
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

%:- debug(snum).
%:- debug(original_const).
%:- debug(const_with_toknums).
%:- debug(indexed_const).
%:- debug(bound_const).
%:- debug(numbered_const).
%:- debug(annotated_const).
%:- debug(cats).
%:- debug(depdirs).
%:- debug(head).
%:- debug(dep).

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
     %( N = 1 -> gtrace ; true ),
     cac2dep(Const)
  ;  format(user_error, 'WARNING: failed to preprocess derivation ~w, skipping~n', [N]),
     nl
  ).

cac2dep(Const) :-
  findall(t(Cat, Form, Atts),
      ( subsumed_sub_term(t(Cat, Form, Atts), Const)
      ), Tokens),
  find_top(Const, Tokens, Top),
  debug(top, 'top: ~w', [Top]),
  t2dep(Top, Tokens, _, Deps, []),
  forall(
      ( member(dep(D, H), Deps)
      ),
      ( debug(dep, '~@ <- ~@', [cac_pp(D), cac_pp(H)])
      ) ),
  include(real_dep, Deps, RealDeps),
  add_root_dep(RealDeps, RootedDeps),
  funsort(depfrom, RootedDeps, SortedDeps),
  maplist(dep_pp, SortedDeps),
  nl.

%%	add_dep_to_root(+Deps, +Top, -RootedDeps)
%
%	Above the highest node in the dependency tree Deps, add another
%	dependency to an artificial root node, represented by an unbound
%	variable.
add_root_dep(Deps0, Deps) :-
  select_highest_dep(dep(D, H), Deps0, Deps1),
  (  cat_is_pseudo(H)
  -> Deps = [dep(D, _)|Deps1] % drop H, attach D to root
  ;  Deps = [dep(H, _)|Deps0] % attach H to root
  ).

select_highest_dep(dep(D, H), Deps0, Deps) :-
  select(dep(D, H), Deps0, Deps),
  \+ member(dep(H, _), Deps0).

add_dep_to_root(Deps0, Top, [dep(Dep, _)|Deps]) :-
  cac_cat(Top, Cat),
  cat_is_pseudo(Cat),
  !,
  select(dep(Dep, Top), Deps0, Deps).
/* case 2: use Top as root */
add_dep_to_root(Deps, Top, [dep(Top, _)|Deps]).


t2dep(Token, Tokens, Head, Deps0, Deps) :-
  cac_cat(Token, Cat),
  cat2dep(Cat, Tokens, Token, Head, Deps0, Deps).

% Find a token whose top category does not appear as an argument.
% Prefer real tokens, but return a pseudotoken if no other exists.
find_top(Const, Tokens, Top) :-
  cac_top(Const, Top0),
  cac_cat(Top0, Cat0),
  cat_id(Cat0, ID),
  (  member(Top, Tokens),
     cac_cat(Top, Cat),
     \+ cat_is_pseudo(Cat),
     cat_id(Cat, ID)
  -> true
  ;  Top = Top0
  ).

% Find the argument corresponding to the given category Y.
% Prefer real tokens, but return a pseudotoken if no other exists.
find_arg(Y, Tokens, Arg, ArgCat) :-
  cat_id(Y, ArgID),
  member(Arg, Tokens),
  cac_cat(Arg, ArgCat),
  cat_id(ArgCat, ArgID),
  \+ cat_is_pseudo(ArgCat),
  !.
find_arg(Y, Tokens, Arg, ArgCat) :-
  cat_id(Y, ArgID),
  member(Arg, Tokens),
  cac_cat(Arg, ArgCat),
  cat_id(ArgCat, ArgID),
  !.

% forward type-raising pseudo-slash
cat2dep((X/(X\Y))/Y, Tokens, Head0, ArgHead, [dep(Head0, ArgHead)|Deps0], Deps) :-
  find_arg(Y, Tokens, Arg, _),
  !,
  t2dep(Arg, Tokens, ArgHead, Deps0, Deps).
% backward type-raising pseudo-slash
cat2dep((X\(X/Y))/Y, Tokens, Head0, ArgHead, [dep(Head0, ArgHead)|Deps0], Deps) :-
  find_arg(Y, Tokens, Arg, _),
  !,
  t2dep(Arg, Tokens, ArgHead, Deps0, Deps).
% forward slash
cat2dep(X/Y, Tokens, Head0, Head, [Dep|Deps0], Deps) :-
  find_arg(Y, Tokens, Arg, ArgCat),
  !,
  t2dep(Arg, Tokens, ArgHead, Deps0, Deps1),
  cat_dir(ArgCat, Dir),
  (  Dir = noninv
  -> Dep = dep(ArgHead, Head0),
     cat2dep(X, Tokens, Head0, Head, Deps1, Deps)
  ;  Dep = dep(Head0, ArgHead),
     cat2dep(X, Tokens, ArgHead, Head, Deps1, Deps)
  ).
cat2dep(X/Y, Tokens, Head0, Head, Deps0, Deps) :-
  \+ cat_is_pseudo(X/Y),
  !,
  cat2dep(X, Tokens, Head0, Head, Deps0, Deps).
% backward slash
cat2dep(X\Y, Tokens, Head0, Head, [Dep|Deps0], Deps) :-
  find_arg(Y, Tokens, Arg, ArgCat),
  !,
  t2dep(Arg, Tokens, ArgHead, Deps0, Deps1),
  cat_dir(ArgCat, Dir),
  (  Dir = noninv
  -> Dep = dep(ArgHead, Head0),
     cat2dep(X, Tokens, Head0, Head, Deps1, Deps)
  ;  Dep = dep(Head0, ArgHead),
     cat2dep(X, Tokens, ArgHead, Head, Deps1, Deps)
  ).
cat2dep(X\_, Tokens, Head0, Head, Deps0, Deps) :-
  !,
  cat2dep(X, Tokens, Head0, Head, Deps0, Deps).
% no slash
cat2dep(_, _, Head, Head, Deps, Deps).

real_dep(dep(t(_, Token, _), _)) :-
  Token \= ø.

depfrom(dep(t(_, _, Atts), _), From) :-
  member(from:From, Atts).

dep_pp(dep(_, t(_, _, HeadAtts))) :-
  (  var(HeadAtts)
  -> HeadToknum = 0
  ;  member(toknum:HeadToknum, HeadAtts)
  ),
  format('~w~n', [HeadToknum]).
